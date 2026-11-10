import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../application/calendar_connection_controller.dart';
import '../domain/calendar_data.dart';
import '../domain/calendar_event_creation.dart';

/// Creation only. Focus ownership, provisioning, editing and deletion are absent.
class GoogleCalendarEventWriter implements CalendarEventCreationWriter {
  GoogleCalendarEventWriter(
    this.connection, {
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _factory = clientFactory ?? http.Client.new,
       _now = now ?? DateTime.now;
  final CalendarConnectionController connection;
  final http.Client Function() _factory;
  final DateTime Function() _now;
  final Duration timeout;
  bool Function()? mutationAllowed;
  Future<void> Function(CalendarCreateIntent)? verifyTime;
  final Set<http.Client> _clients = {};
  final Map<Timer, Completer<void>> _waits = {};
  DateTime? _retryAt;
  int _epoch = 0;
  void _guard(int epoch, String account) {
    if (_epoch != epoch || connection.verifiedAccountKey != account) {
      throw const _CreationTransport('cancelled');
    }
  }

  Future<void> _wait(Duration duration, int epoch, String account) async {
    final c = Completer<void>();
    late Timer timer;
    timer = Timer(duration, () {
      _waits.remove(timer);
      c.complete();
    });
    _waits[timer] = c;
    await c.future;
    _guard(epoch, account);
  }

  Future<Map<String, dynamic>?> _request(
    String method,
    List<String> path,
    String account, {
    Map<String, Object?>? body,
    CalendarCreateOperation? operation,
  }) async {
    final epoch = _epoch;
    final mutation = method == 'POST';
    for (var attempt = 0; attempt < 3; attempt++) {
      _guard(epoch, account);
      if (_retryAt?.isAfter(_now()) == true) {
        if (mutation) throw const _CreationTransport('throttled');
        await _wait(_retryAt!.difference(_now()), epoch, account);
      }
      final client = _factory();
      _clients.add(client);
      try {
        final response = await connection.withAccess((token) async {
          _guard(epoch, account);
          if (mutation &&
              (!connection.creationEnabled ||
                  connection.creationUpgradeActive ||
                  mutationAllowed?.call() == false ||
                  operation == null ||
                  operation.clientId != connection.configuration.clientId ||
                  !operation.intent.startUtc.isAfter(_now().toUtc()))) {
            throw const _CreationTransport('permission');
          }
          final request =
              http.Request(
                  method,
                  Uri(
                    scheme: 'https',
                    host: 'www.googleapis.com',
                    pathSegments: ['calendar', 'v3', ...path],
                    queryParameters: mutation
                        ? {'eventLabelVersion': '0', 'sendUpdates': 'none'}
                        : null,
                  ),
                )
                ..followRedirects = false
                ..headers['Authorization'] = 'Bearer $token';
          if (body != null) {
            request.headers['Content-Type'] = 'application/json; charset=utf-8';
            request.body = jsonEncode(body);
          }
          if (mutation) {
            await verifyTime?.call(operation!.intent);
            _guard(epoch, account);
            if (!connection.creationEnabled ||
                mutationAllowed?.call() == false ||
                !operation!.intent.startUtc.isAfter(_now().toUtc())) {
              throw const _CreationTransport('permission');
            }
          }
          final stream = await client.send(request).timeout(timeout);
          final bytes = <int>[];
          await for (final chunk in stream.stream.timeout(timeout)) {
            if (bytes.length + chunk.length > 4 * 1024 * 1024) {
              throw const _CreationTransport('response');
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
        _guard(epoch, account);
        if (response == null) throw const _CreationTransport('cancelled');
        final r = response.$1;
        if (r.statusCode == 401) {
          await connection.refreshRejectedAccess(response.$2);
          if (!mutation && attempt == 0) continue;
          throw const _CreationTransport('unknown');
        }
        if (r.statusCode == 410) throw const _CreationTransport('deleted');
        if (r.statusCode == 404) return null;
        if (r.statusCode == 409) throw const _CreationTransport('unknown');
        if (r.statusCode == 200 || r.statusCode == 201) {
          final decoded = jsonDecode(r.body);
          if (decoded is! Map<String, dynamic>) {
            throw const _CreationTransport('response');
          }
          _retryAt = null;
          return decoded;
        }
        var throttled = r.statusCode == 429;
        if (r.statusCode == 403) {
          try {
            final errors = (jsonDecode(r.body) as Map)['error'] as Map;
            throttled = (errors['errors'] as List? ?? []).any(
              (e) => const {
                'rateLimitExceeded',
                'userRateLimitExceeded',
              }.contains((e as Map)['reason']),
            );
          } catch (_) {
            /* Only safe error categories leave this adapter. */
          }
          if (!throttled) {
            if (mutation) connection.blockCreation();
            throw const _CreationTransport('permission');
          }
        }
        if (throttled || r.statusCode >= 500) {
          var delay = Duration(
            milliseconds: (1000 * (1 << attempt) * (1 + Random().nextDouble()))
                .round(),
          );
          final header = r.headers['retry-after'];
          if (header != null) {
            try {
              final seconds = int.tryParse(header);
              final requested = seconds == null
                  ? HttpDate.parse(header).difference(_now())
                  : Duration(seconds: seconds);
              if (requested > delay) delay = requested;
            } catch (_) {
              /* Ignore malformed retry guidance. */
            }
          }
          _retryAt = _now().add(delay);
          if (!mutation && attempt < 2) continue;
          throw const _CreationTransport('unknown');
        }
        throw const _CreationTransport('rejected');
      } finally {
        _clients.remove(client);
        client.close();
      }
    }
    throw const _CreationTransport('unknown');
  }

  @override
  Future<bool> validateDestination(String accountKey, String calendarId) async {
    final m = await _request('GET', [
      'users',
      'me',
      'calendarList',
      calendarId,
    ], accountKey);
    return m != null && m['id'] == calendarId && m['accessRole'] == 'owner';
  }

  CalendarCreateResult _verified(
    CalendarCreateOperation op,
    Map<String, dynamic> m,
  ) {
    try {
      final p = (m['extendedProperties'] as Map?)?['private'] as Map? ?? {};
      final start = DateTime.parse(
        (m['start'] as Map)['dateTime'] as String,
      ).toUtc();
      final end = DateTime.parse(
        (m['end'] as Map)['dateTime'] as String,
      ).toUtc();
      if (m['id'] != op.eventId ||
          m['status'] == 'cancelled' ||
          m['eventType'] != 'default' ||
          m['summary'] != op.intent.title ||
          start != op.intent.startUtc ||
          end != op.intent.endUtc ||
          (m['transparency'] != 'transparent') != op.intent.busy ||
          m['colorId'] != op.intent.colorId ||
          (m['attendees'] as List? ?? []).isNotEmpty ||
          (m['recurrence'] as List? ?? []).isNotEmpty ||
          m['recurringEventId'] != null ||
          m['originalStartTime'] != null ||
          op.markers.entries.any((e) => p[e.key] != e.value)) {
        throw const FormatException('Mismatched event.');
      }
      return CalendarCreateResult(
        CalendarCreationState.saved,
        event: CalendarEvent(
          id: op.eventId,
          calendarId: op.intent.calendarId,
          title: op.intent.title,
          status: 'confirmed',
          selfResponse: 'accepted',
          startUtc: start,
          endUtc: end,
          colorId: op.intent.colorId,
          eventUrl: safeCalendarUrl(m['htmlLink'] as String?, meeting: false),
        ),
        message: 'Saved to Google Calendar.',
      );
    } catch (_) {
      return const CalendarCreateResult(
        CalendarCreationState.failed,
        message:
            'The event at this identity was deleted or differs from the reviewed task. Review it in Google; it will not be overwritten or recreated.',
      );
    }
  }

  @override
  Future<CalendarCreateResult> create(CalendarCreateOperation operation) async {
    final epoch = _epoch;
    try {
      if (operation.eventId != creationEventId(operation.operationId) ||
          operation.clientId != connection.configuration.clientId ||
          !await validateDestination(
            operation.intent.accountKey,
            operation.intent.calendarId,
          )) {
        return const CalendarCreateResult(
          CalendarCreationState.failed,
          message:
              'The original owned calendar is no longer available. Your draft is kept.',
        );
      }
      _guard(epoch, operation.intent.accountKey);
      final m = await _request(
        'POST',
        ['calendars', operation.intent.calendarId, 'events'],
        operation.intent.accountKey,
        operation: operation,
        body: {
          ...operation.intent.fields,
          'id': operation.eventId,
          'extendedProperties': {'private': operation.markers},
        },
      );
      return m == null
          ? const CalendarCreateResult(
              CalendarCreationState.checking,
              message: 'Check the original event before retrying.',
            )
          : _verified(operation, m);
    } on _CreationTransport catch (e) {
      return CalendarCreateResult(
        e.kind == 'rejected' || e.kind == 'permission'
            ? CalendarCreationState.failed
            : CalendarCreationState.checking,
        message: e.kind == 'permission'
            ? 'Creation access changed. Review access before retrying.'
            : 'The save outcome needs checking. The original event ID is retained.',
      );
    } catch (_) {
      return const CalendarCreateResult(
        CalendarCreationState.checking,
        message:
            'The save outcome needs checking. The original event ID is retained.',
      );
    }
  }

  @override
  Future<CalendarCreateResult> readBack(
    CalendarCreateOperation operation,
  ) async {
    try {
      if (operation.clientId != connection.configuration.clientId ||
          !await validateDestination(
            operation.intent.accountKey,
            operation.intent.calendarId,
          )) {
        return const CalendarCreateResult(
          CalendarCreationState.checking,
          message:
              'The original calendar access could not be verified. Absence is not established.',
        );
      }
      final m = await _request('GET', [
        'calendars',
        operation.intent.calendarId,
        'events',
        operation.eventId,
      ], operation.intent.accountKey);
      return m == null
          ? const CalendarCreateResult(
              CalendarCreationState.checking,
              retryAllowed: true,
              message:
                  'No event was found on the verified original calendar. Review the original future times before Retry.',
            )
          : _verified(operation, m);
    } on _CreationTransport catch (error) {
      if (error.kind == 'deleted') {
        return const CalendarCreateResult(
          CalendarCreationState.failed,
          message:
              'Google reports this event was deleted. It will not be recreated.',
        );
      }
      return const CalendarCreateResult(
        CalendarCreationState.checking,
        message:
            'Google could not confirm the outcome. Check again when access is available.',
      );
    } catch (_) {
      return const CalendarCreateResult(
        CalendarCreationState.checking,
        message:
            'Google could not confirm the outcome. Check again when access is available.',
      );
    }
  }

  @override
  void cancel() {
    _epoch++;
    for (final c in _clients.toList()) {
      c.close();
    }
    for (final e in _waits.entries.toList()) {
      e.key.cancel();
      e.value.complete();
    }
    _waits.clear();
  }
}

class _CreationTransport implements Exception {
  const _CreationTransport(this.kind);
  final String kind;
}
