import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../application/calendar_connection_controller.dart';
import '../application/focus_block_ports.dart';
import '../domain/focus_blocks.dart';

/// No arbitrary event editor. Each mutation freshly proves the app/calendar boundary.
class GoogleFocusWriter implements FocusBlockWriter {
  GoogleFocusWriter(
    this.connection, {
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 30),
    this.verifyTime,
    DateTime Function()? now,
  }) : _factory = clientFactory ?? http.Client.new,
       _now = now ?? DateTime.now;
  final CalendarConnectionController connection;
  final http.Client Function() _factory;
  void _target(FocusCalendarBinding b, FocusBlockOperation op) {
    if (op.target?.id != b.id ||
        op.target?.calendarKey != b.calendarKey ||
        op.target?.provisioningId != b.provisioningId ||
        op.target?.accountKey != b.accountKey ||
        op.target?.clientId != b.clientId) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
  }

  final Duration timeout;
  final DateTime Function() _now;
  Future<void> Function(FocusPayload)? verifyTime;
  final Set<http.Client> _clients = {};
  final Map<String, Future<Map<String, dynamic>?>> _reads = {};
  final Set<Timer> _timers = {};
  final Map<Timer, Completer<void>> _waiting = {};
  DateTime? _retryAt;
  int _epoch = 0;
  void _check(int epoch) {
    if (epoch != _epoch) throw const FocusFailure(FocusFailureKind.cancelled);
  }

  Uri _uri(List<String> path, [Map<String, dynamic>? query]) => Uri(
    scheme: 'https',
    host: 'www.googleapis.com',
    pathSegments: ['calendar', 'v3', ...path],
    queryParameters: query,
  );
  Future<Map<String, dynamic>?> _request(
    String method,
    List<String> path, {
    Map<String, dynamic>? query,
    Map<String, Object?>? body,
    String? etag,
    bool missing = false,
    DateTime? futureStart,
  }) {
    final uri = _uri(path, query), epoch = _epoch;
    final key = '$epoch/$uri';
    if (method == 'GET') {
      return _reads.putIfAbsent(
        key,
        () => _send(method, uri, epoch, missing: missing).whenComplete(() {
          _reads.remove(key);
        }),
      );
    }
    return _send(
      method,
      uri,
      epoch,
      body: body,
      etag: etag,
      missing: missing,
      futureStart: futureStart,
    );
  }

  Future<void> _delay(Duration delay, int epoch) async {
    final done = Completer<void>();
    late Timer timer;
    timer = Timer(delay, () {
      _timers.remove(timer);
      _waiting.remove(timer);
      done.complete();
    });
    _timers.add(timer);
    _waiting[timer] = done;
    await done.future;
    _check(epoch);
  }

  Future<Map<String, dynamic>?> _send(
    String method,
    Uri uri,
    int epoch, {
    Map<String, Object?>? body,
    String? etag,
    bool missing = false,
    DateTime? futureStart,
  }) async {
    final mutation = method != 'GET';
    for (var attempt = 0; attempt < 3; attempt++) {
      _check(epoch);
      if (_retryAt?.isAfter(DateTime.now()) == true) {
        if (mutation) throw const FocusFailure(FocusFailureKind.throttled);
        await _delay(_retryAt!.difference(DateTime.now()), epoch);
      }
      final client = _factory();
      _clients.add(client);
      try {
        final response = await connection.withAccess((token) async {
          _check(epoch);
          if (mutation && !connection.focusWriteEnabled) {
            throw const FocusFailure(FocusFailureKind.permission);
          }
          final request = http.Request(method, uri)
            ..followRedirects = false
            ..headers['Authorization'] = 'Bearer $token';
          if (body != null) {
            request.headers['Content-Type'] = 'application/json; charset=utf-8';
            request.body = jsonEncode(body);
          }
          if (etag != null) request.headers['If-Match'] = etag;
          if (mutation &&
              futureStart != null &&
              !futureStart.isAfter(_now().toUtc())) {
            throw const FocusFailure(FocusFailureKind.invalidTime);
          }
          final stream = await client.send(request).timeout(timeout);
          final bytes = <int>[];
          await for (final chunk in stream.stream.timeout(timeout)) {
            if (bytes.length + chunk.length > 4 * 1024 * 1024) {
              throw const FocusFailure(FocusFailureKind.response);
            }
            bytes.addAll(chunk);
          }
          return (
            http.Response.bytes(
              bytes,
              stream.statusCode,
              headers: stream.headers,
            ),
            token,
          );
        });
        _check(epoch);
        if (response == null) {
          throw const FocusFailure(FocusFailureKind.cancelled);
        }
        final r = response.$1;
        if (r.statusCode == 401) {
          await connection.refreshRejectedAccess(response.$2);
          _check(epoch);
          if (!mutation && attempt == 0) continue;
          throw const FocusFailure(FocusFailureKind.network);
        }
        if (r.statusCode == 410 && missing) {
          return {'id': uri.pathSegments.last, 'status': 'cancelled'};
        }
        if (r.statusCode == 404 && missing) {
          return null;
        }
        if (r.statusCode == 409) {
          throw const FocusFailure(FocusFailureKind.conflict);
        }
        if (r.statusCode == 412) {
          throw const FocusFailure(FocusFailureKind.precondition);
        }
        var limited = r.statusCode == 429;
        if (r.statusCode == 403) {
          try {
            final error = jsonDecode(r.body) as Map;
            final reasons = (((error['error'] as Map)['errors'] as List?) ?? [])
                .whereType<Map>()
                .map((e) => e['reason']);
            limited = reasons.any(
              (v) => const {
                'rateLimitExceeded',
                'userRateLimitExceeded',
                'quotaExceeded',
              }.contains(v),
            );
          } catch (_) {}
          if (!limited) {
            connection.blockFocusWrites();
            throw const FocusFailure(FocusFailureKind.permission);
          }
        }
        if (limited || r.statusCode >= 500) {
          var delay = Duration(
            milliseconds:
                min(60000, 1000 * (1 << attempt)) + Random().nextInt(500),
          );
          final header = r.headers['retry-after'];
          if (header != null) {
            final seconds = int.tryParse(header);
            DateTime? date;
            try {
              date = HttpDate.parse(header);
            } catch (_) {}
            final requested = seconds == null
                ? date?.difference(DateTime.now())
                : Duration(seconds: seconds);
            if (requested != null && requested > delay) delay = requested;
          }
          _retryAt = DateTime.now().add(delay);
          if (!mutation && attempt < 2) continue;
          throw FocusFailure(
            limited ? FocusFailureKind.throttled : FocusFailureKind.network,
            retryAfter: delay,
          );
        }
        if (r.statusCode == 404 || r.statusCode == 410) {
          throw const FocusFailure(FocusFailureKind.missing);
        }
        if (r.statusCode < 200 || r.statusCode >= 300) {
          throw const FocusFailure(FocusFailureKind.response);
        }
        if (r.statusCode == 204) return <String, dynamic>{};
        final value = jsonDecode(r.body);
        if (value is! Map<String, dynamic>) {
          throw const FocusFailure(FocusFailureKind.response);
        }
        return value;
      } on FocusFailure {
        rethrow;
      } catch (_) {
        throw const FocusFailure(FocusFailureKind.network);
      } finally {
        client.close();
        _clients.remove(client);
      }
    }
    throw const FocusFailure(FocusFailureKind.network);
  }

  Future<List<Map<String, dynamic>>> _pages(
    List<String> path,
    Map<String, dynamic> query,
  ) async {
    final epoch = _epoch, seen = <String>{};
    String? page;
    final rows = <Map<String, dynamic>>[];
    final ids = <String>{};
    do {
      final m = (await _request(
        'GET',
        path,
        query: {...query, 'pageToken': ?page},
      ))!;
      _check(epoch);
      if (m['items'] != null && m['items'] is! List) {
        throw const FocusFailure(FocusFailureKind.response);
      }
      for (final item in (m['items'] as List?) ?? []) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            !ids.add(item['id'] as String) ||
            rows.length >= 100000) {
          throw const FocusFailure(FocusFailureKind.response);
        }
        rows.add(item);
      }
      final next = m['nextPageToken'];
      if (next != null &&
          (next is! String || next.isEmpty || !seen.add(next))) {
        throw const FocusFailure(FocusFailureKind.response);
      }
      page = next as String?;
    } while (page != null);
    return rows;
  }

  static final _marker = RegExp(
    r'^Poma-Focus-v1 calendarKey=([0-9a-f-]+) provisioningId=([0-9a-f-]+)$',
    multiLine: true,
  );
  FocusCalendarBinding? _parse(
    Map<String, dynamic> m,
    String account,
    String client,
  ) {
    final description = m['description'];
    if (description is! String) return null;
    final matches = _marker.allMatches(description).toList();
    if (matches.length != 1) return null;
    try {
      return FocusCalendarBinding(
        accountKey: account,
        clientId: client,
        id: m['id'] as String,
        calendarKey: matches.single[1]!,
        provisioningId: matches.single[2]!,
        name: m['summary'] as String? ?? 'Poma Focus',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FocusCalendarBinding>> discover(
    String accountKey,
    String clientId,
  ) async {
    final all = await _pages(
      ['users', 'me', 'calendarList'],
      {
        'showHidden': 'true',
        'maxResults': '250',
        'fields':
            'nextPageToken,items(id,summary,description,primary,accessRole)',
      },
    );
    final result = <FocusCalendarBinding>[];
    for (final row in all) {
      final b = _parse(row, accountKey, clientId);
      if (b == null) continue;
      if (row['primary'] == true || row['accessRole'] != 'owner') {
        throw const FocusFailure(FocusFailureKind.permission);
      }
      result.add(await validate(b));
    }
    return result;
  }

  @override
  Future<FocusCalendarBinding> provision(FocusCalendarBinding intent) async {
    if (intent.accountKey != connection.verifiedAccountKey ||
        intent.clientId != connection.focusClientId) {
      throw const FocusFailure(FocusFailureKind.permission);
    }
    final result = (await _request(
      'POST',
      ['calendars'],
      body: {
        'summary': 'Poma Focus',
        'description':
            'Created by Poma for explicitly scheduled focus blocks.\n${intent.marker}',
      },
    ))!;
    final b = _parse(result, intent.accountKey, intent.clientId);
    if (b == null ||
        b.calendarKey != intent.calendarKey ||
        b.provisioningId != intent.provisioningId) {
      throw const FocusFailure(FocusFailureKind.response);
    }
    return validate(b);
  }

  @override
  Future<FocusCalendarBinding> validate(FocusCalendarBinding binding) async {
    if (binding.accountKey != connection.verifiedAccountKey ||
        binding.clientId != connection.focusClientId ||
        binding.id == 'primary') {
      throw const FocusFailure(FocusFailureKind.permission);
    }
    final list = (await _request(
      'GET',
      ['users', 'me', 'calendarList', binding.id],
      query: {'fields': 'id,primary,accessRole'},
    ))!;
    if (list['id'] != binding.id ||
        list['primary'] == true ||
        list['accessRole'] != 'owner') {
      throw const FocusFailure(FocusFailureKind.permission);
    }
    final metadata = (await _request(
      'GET',
      ['calendars', binding.id],
      query: {'fields': 'id,summary,description,timeZone'},
    ))!;
    final b = _parse(metadata, binding.accountKey, binding.clientId);
    if (b == null ||
        b.id != binding.id ||
        b.calendarKey != binding.calendarKey ||
        b.provisioningId != binding.provisioningId) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    return b;
  }

  @override
  Future<FocusRemoteBlock?> get(
    FocusCalendarBinding binding,
    String eventId,
  ) async {
    await validate(binding);
    final m = await _request('GET', [
      'calendars',
      binding.id,
      'events',
      eventId,
    ], missing: true);
    return m == null ? null : FocusRemoteBlock(m);
  }

  Map<String, Object?> _markers(
    FocusCalendarBinding b,
    FocusBlockOperation o,
  ) => {...o.markers, 'pomaCalendarKey': b.calendarKey};
  @override
  Future<FocusRemoteBlock> create(
    FocusCalendarBinding binding,
    FocusBlockOperation operation,
  ) async {
    final epoch = _epoch;
    _target(binding, operation);
    await validate(binding);
    await verifyTime?.call(operation.payload);
    _check(epoch);
    if (operation.kind != FocusOperationKind.create ||
        operation.id != operation.blockId) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    return FocusRemoteBlock(
      (await _request(
        'POST',
        ['calendars', binding.id, 'events'],
        futureStart: operation.payload.start,
        query: {'sendUpdates': 'none'},
        body: {
          ...operation.payload.fields,
          'id': operation.eventId,
          'eventType': 'default',
          'visibility': 'private',
          'reminders': {'useDefault': false, 'overrides': <Object>[]},
          'extendedProperties': {'private': _markers(binding, operation)},
        },
      ))!,
    );
  }

  @override
  Future<FocusRemoteBlock> edit(
    FocusCalendarBinding binding,
    FocusBlockOperation operation,
    FocusRemoteBlock current,
  ) async {
    final epoch = _epoch;
    _target(binding, operation);
    final fresh = await get(binding, operation.eventId);
    if (operation.kind != FocusOperationKind.edit ||
        fresh == null ||
        !fresh.owned(binding) ||
        fresh.etag != operation.etag ||
        fresh.actualHash != current.actualHash) {
      throw const FocusFailure(FocusFailureKind.precondition);
    }
    await verifyTime?.call(operation.payload);
    _check(epoch);
    return FocusRemoteBlock(
      (await _request(
        'PATCH',
        ['calendars', binding.id, 'events', operation.eventId],
        query: {'sendUpdates': 'none'},
        etag: operation.etag,
        futureStart: operation.payload.start,
        body: {
          ...operation.payload.fields,
          'extendedProperties': {
            'private': {...fresh.properties, ..._markers(binding, operation)},
          },
        },
      ))!,
    );
  }

  @override
  Future<void> delete(
    FocusCalendarBinding binding,
    FocusBlockOperation operation,
  ) async {
    _target(binding, operation);
    final fresh = await get(binding, operation.eventId);
    if (operation.kind != FocusOperationKind.delete ||
        fresh == null ||
        !fresh.owned(binding) ||
        fresh.etag != operation.etag) {
      throw const FocusFailure(FocusFailureKind.precondition);
    }
    await _request(
      'DELETE',
      ['calendars', binding.id, 'events', operation.eventId],
      query: {'sendUpdates': 'none'},
      etag: operation.etag,
    );
  }

  @override
  Future<List<FocusRemoteBlock>> recover(
    FocusCalendarBinding binding,
    DateTime start,
    DateTime end,
  ) async {
    await validate(binding);
    final all = await _pages(
      ['calendars', binding.id, 'events'],
      {
        'timeMin': focusUtc(start),
        'timeMax': focusUtc(end),
        'singleEvents': 'false',
        'showDeleted': 'true',
        'maxResults': '2500',
        'privateExtendedProperty': [
          'pomaOwner=poma.windows',
          'pomaCalendarKey=${binding.calendarKey}',
        ],
      },
    );
    return all
        .map(FocusRemoteBlock.new)
        .where((b) => b.owned(binding))
        .toList();
  }

  @override
  void cancel() {
    ++_epoch;
    for (final c in _clients.toList()) {
      c.close();
    }
    _clients.clear();
    for (final t in _timers) {
      t.cancel();
      _waiting[t]?.complete();
    }
    _timers.clear();
    _waiting.clear();
    _reads.clear();
    _retryAt = null;
  }
}
