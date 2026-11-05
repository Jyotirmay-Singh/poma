import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../application/calendar_connection_controller.dart';
import '../application/calendar_read_ports.dart';
import '../domain/calendar_data.dart';

class GoogleCalendarReader implements CalendarReadProvider {
  GoogleCalendarReader({
    required this.access,
    required this.clock,
    required this.scheduler,
    http.Client Function()? clientFactory,
    double Function()? jitter,
    this.timeout = const Duration(seconds: 30),
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _jitter = jitter ?? Random().nextDouble;
  final CalendarReadAccess access;
  final CalendarClock clock;
  final CalendarScheduler scheduler;
  final http.Client Function() _clientFactory;
  final double Function() _jitter;
  final Duration timeout;
  final Set<http.Client> _clients = {};
  final Map<Completer<void>, CalendarScheduledJob> _waits = {};
  DateTime? _cooldown;
  int _epoch = 0;
  bool _disposed = false;
  static bool _zonesReady = false;
  void _check(int epoch) {
    if (_disposed || epoch != _epoch) {
      throw const CalendarReadFailure(CalendarReadFailureKind.cancelled);
    }
  }

  @override
  Future<List<CalendarSource>> calendars() async {
    final epoch = _epoch;
    final result = <String, CalendarSource>{};
    await _pages(
      ['calendar', 'v3', 'users', 'me', 'calendarList'],
      {
        'maxResults': '250',
        'showHidden': 'true',
        'showDeleted': 'false',
        'fields':
            'nextPageToken,items(id,summary,summaryOverride,accessRole,timeZone,colorId,backgroundColor,foregroundColor,primary)',
      },
      epoch,
      (item) {
        final id = _required(item, 'id');
        if (result.containsKey(id)) {
          throw const FormatException('Duplicate calendar identity.');
        }
        result[id] = CalendarSource(
          id: id,
          name:
              item['summaryOverride'] as String? ??
              item['summary'] as String? ??
              'Unnamed calendar',
          accessRole: _required(item, 'accessRole'),
          timeZone: item['timeZone'] as String? ?? '',
          colorId: item['colorId'] as String?,
          backgroundColor: safeCalendarColor(item['backgroundColor']),
          foregroundColor: safeCalendarColor(item['foregroundColor']),
          primary: item['primary'] == true,
        );
      },
    );
    return List.unmodifiable(result.values);
  }

  static String _required(Map value, String key) {
    final result = value[key];
    if (result is! String || result.isEmpty) {
      throw const FormatException('Missing calendar field.');
    }
    return result;
  }

  @override
  Future<List<CalendarEvent>> events(
    CalendarSource source,
    CalendarWindow window,
  ) async {
    final epoch = _epoch;
    if (!source.readable) {
      throw const CalendarReadFailure(CalendarReadFailureKind.forbidden);
    }
    try {
      if (!_zonesReady) {
        tz_data.initializeTimeZones();
        _zonesReady = true;
      }
      final zone =
          const {'UTC', 'Etc/UTC', 'GMT', 'Etc/GMT'}.contains(source.timeZone)
          ? tz.UTC
          : tz.getLocation(source.timeZone);
      final calendarStart = tz.TZDateTime(
        zone,
        window.first.year,
        window.first.month,
        window.first.day,
      ).toUtc();
      final calendarEnd = tz.TZDateTime(
        zone,
        window.until.year,
        window.until.month,
        window.until.day,
      ).toUtc();
      final start = calendarStart.isBefore(window.startUtc)
          ? calendarStart
          : window.startUtc;
      final end = calendarEnd.isAfter(window.endUtc)
          ? calendarEnd
          : window.endUtc;
      final result = <String, CalendarEvent>{};
      await _pages(
        ['calendar', 'v3', 'calendars', source.id, 'events'],
        {
          'timeMin': start.toIso8601String(),
          'timeMax': end.toIso8601String(),
          'singleEvents': 'true',
          'showDeleted': 'false',
          'timeZone': 'UTC',
          'maxResults': '2500',
          'maxAttendees': '1',
          'fields':
              'nextPageToken,items(id,status,summary,start,end,recurringEventId,originalStartTime,attendees(self,responseStatus),hangoutLink,conferenceData(entryPoints(entryPointType,uri)),htmlLink,location,description)',
        },
        epoch,
        (item) {
          final event = _event(item, source);
          if (event != null && event.eligible && event.overlaps(window)) {
            if (result.containsKey(event.id)) {
              throw const FormatException('Duplicate event instance.');
            }
            result[event.id] = event;
          }
        },
      );
      return List.unmodifiable(result.values);
    } on CalendarReadFailure {
      rethrow;
    } catch (_) {
      throw const CalendarReadFailure(CalendarReadFailureKind.response);
    }
  }

  CalendarEvent? _event(Map map, CalendarSource source) {
    final id = _required(map, 'id');
    final status = map['status'] as String? ?? 'confirmed';
    if (status == 'cancelled') {
      return null; // Tombstones need not contain intervals.
    }
    var response = 'unknown';
    for (final item in map['attendees'] as List? ?? const []) {
      if ((item as Map)['self'] == true) {
        response = item['responseStatus'] as String? ?? 'unknown';
      }
    }
    final start = map['start'] as Map;
    final end = map['end'] as Map;
    final allDay = start['date'] != null;
    String? meeting;
    final conference = map['conferenceData'] as Map?;
    for (final point in conference?['entryPoints'] as List? ?? const []) {
      if ((point as Map)['entryPointType'] == 'video') {
        meeting ??= safeCalendarUrl(point['uri'] as String?, meeting: true);
      }
    }
    meeting ??= safeCalendarUrl(map['hangoutLink'] as String?, meeting: true);
    meeting ??= calendarMeetingFromText(map['location'] as String?);
    meeting ??= calendarMeetingFromText(map['description'] as String?);
    final original = map['originalStartTime'] as Map?;
    // Round-trip through the same strict allowlisted cache representation.
    return CalendarEvent.fromJson({
      'id': id,
      'calendarId': source.id,
      'title': map['summary'] as String? ?? 'Busy',
      'status': status,
      'selfResponse': response,
      'startUtc': allDay ? null : _instant(_required(start, 'dateTime')),
      'endUtc': allDay ? null : _instant(_required(end, 'dateTime')),
      'startDate': start['date'],
      'endDate': end['date'],
      'startZone': start['timeZone'],
      'endZone': end['timeZone'],
      'recurringEventId': map['recurringEventId'],
      'originalStart': original?['dateTime'] ?? original?['date'],
      'meetingUrl': meeting,
      'eventUrl': map['htmlLink'],
    });
  }

  String _instant(String value) {
    if (value.length < 20 || value[10] != 'T') {
      throw const FormatException('Invalid event instant.');
    }
    CalendarDate.parse(value.substring(0, 10));
    if (!RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
      throw const FormatException('Missing instant offset.');
    }
    return DateTime.parse(value).toUtc().toIso8601String();
  }

  Future<void> _pages(
    List<String> path,
    Map<String, String> parameters,
    int epoch,
    void Function(Map) consume,
  ) async {
    final tokens = <String>{};
    var stagedBytes = 0;
    String? page;
    try {
      do {
        _check(epoch);
        final uri = Uri(
          scheme: 'https',
          host: 'www.googleapis.com',
          pathSegments: path,
          queryParameters: {...parameters, 'pageToken': ?page},
        );
        final map = await _get(uri, epoch);
        _check(epoch);
        if (map['items'] != null && map['items'] is! List) {
          throw const FormatException('Invalid page.');
        }
        for (final item in map['items'] as List? ?? const []) {
          stagedBytes += utf8.encode(jsonEncode(item)).length;
          if (stagedBytes > 16 * 1024 * 1024) {
            throw const FormatException(
              'Calendar snapshot exceeds the staging limit.',
            );
          }
          consume(item as Map);
        }
        final next = map['nextPageToken'];
        if (next != null && (next is! String || next.isEmpty)) {
          throw const FormatException('Invalid page token.');
        }
        page = next as String?;
        if (page != null && !tokens.add(page)) {
          throw const FormatException('Repeated page token.');
        }
      } while (page != null);
    } on CalendarReadFailure {
      rethrow;
    } catch (_) {
      throw const CalendarReadFailure(CalendarReadFailureKind.response);
    }
  }

  Future<Map> _get(Uri uri, int epoch) async {
    if (_cooldown?.isAfter(clock.nowUtc()) == true) {
      throw CalendarReadFailure(
        CalendarReadFailureKind.throttled,
        retryAt: _cooldown,
      );
    }
    for (var attempt = 0; attempt < 3; attempt++) {
      _check(epoch);
      if (attempt > 0) {
        await _wait(_cooldown!.difference(clock.nowUtc()), epoch);
      }
      try {
        var retriedAuthentication = false;
        while (true) {
          final response = await access.withAccess((token) async {
            _check(epoch);
            final client = _clientFactory();
            _clients.add(client);
            try {
              final request = http.Request('GET', uri)
                ..followRedirects = false
                ..headers['Authorization'] = 'Bearer $token';
              final reply = await client
                  .send(request)
                  .then((stream) async {
                    final bytes = <int>[];
                    await for (final chunk in stream.stream) {
                      bytes.addAll(chunk);
                      if (bytes.length > 4 * 1024 * 1024) {
                        throw const CalendarReadFailure(
                          CalendarReadFailureKind.response,
                        );
                      }
                    }
                    return http.Response.bytes(
                      bytes,
                      stream.statusCode,
                      headers: stream.headers,
                    );
                  })
                  .timeout(timeout);
              _check(epoch);
              return (reply, token);
            } finally {
              _clients.remove(client);
              client.close();
            }
          });
          _check(epoch);
          if (response == null) {
            throw const CalendarReadFailure(
              CalendarReadFailureKind.authorization,
            );
          }
          final (reply, token) = response;
          if (reply.statusCode == 401) {
            if (!retriedAuthentication) {
              retriedAuthentication = true;
              if (await access.refreshRejectedAccess(token)) continue;
            } else {
              access.requireReconnect();
            }
            throw const CalendarReadFailure(
              CalendarReadFailureKind.authorization,
            );
          }
          if (reply.statusCode == 200) {
            final decoded = jsonDecode(reply.body);
            if (decoded is! Map) {
              throw const CalendarReadFailure(CalendarReadFailureKind.response);
            }
            _cooldown = null;
            return decoded;
          }
          var rateLimited = reply.statusCode == 429;
          if (reply.statusCode == 403) {
            try {
              final errors = (jsonDecode(reply.body) as Map)['error'] as Map;
              rateLimited = (errors['errors'] as List? ?? const []).any(
                (e) => const {
                  'rateLimitExceeded',
                  'userRateLimitExceeded',
                }.contains((e as Map)['reason']),
              );
            } catch (_) {
              /* A malformed error body never becomes display text. */
            }
            if (!rateLimited) {
              throw const CalendarReadFailure(
                CalendarReadFailureKind.forbidden,
              );
            }
          }
          if (!rateLimited && reply.statusCode < 500) {
            throw const CalendarReadFailure(CalendarReadFailureKind.response);
          }
          final delay = Duration(
            milliseconds: (1000 * (1 << attempt) * (1 + _jitter())).round(),
          );
          var retryAt = clock.nowUtc().add(delay);
          final header = reply.headers['retry-after'];
          if (header != null) {
            DateTime? requested;
            final seconds = int.tryParse(header);
            try {
              requested = seconds == null
                  ? HttpDate.parse(header).toUtc()
                  : clock.nowUtc().add(Duration(seconds: max(0, seconds)));
            } catch (_) {
              /* Ignore invalid header. */
            }
            if (requested != null && requested.isAfter(retryAt)) {
              retryAt = requested;
            }
          }
          _cooldown = retryAt;
          if (attempt == 2) {
            throw CalendarReadFailure(
              rateLimited
                  ? CalendarReadFailureKind.throttled
                  : CalendarReadFailureKind.network,
              retryAt: retryAt,
            );
          }
          break;
        }
      } on CalendarReadFailure {
        rethrow;
      } on FormatException {
        throw const CalendarReadFailure(CalendarReadFailureKind.response);
      } catch (_) {
        _check(epoch);
        _cooldown = clock.nowUtc().add(
          Duration(
            milliseconds: (1000 * (1 << attempt) * (1 + _jitter())).round(),
          ),
        );
        if (attempt == 2) {
          throw CalendarReadFailure(
            CalendarReadFailureKind.network,
            retryAt: _cooldown,
          );
        }
      }
    }
    throw const CalendarReadFailure(CalendarReadFailureKind.network);
  }

  Future<void> _wait(Duration duration, int epoch) async {
    _check(epoch);
    final completion = Completer<void>();
    final job = scheduler.after(duration, () {
      if (!completion.isCompleted) completion.complete();
    });
    _waits[completion] = job;
    try {
      await completion.future;
      _check(epoch);
    } finally {
      job.cancel();
      _waits.remove(completion);
    }
  }

  @override
  void cancel() {
    _epoch++;
    for (final client in _clients.toList()) {
      client.close();
    }
    for (final entry in _waits.entries.toList()) {
      entry.value.cancel();
      if (!entry.key.isCompleted) {
        entry.key.completeError(
          const CalendarReadFailure(CalendarReadFailureKind.cancelled),
        );
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
  }
}
