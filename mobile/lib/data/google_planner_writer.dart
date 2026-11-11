import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../application/calendar_connection_controller.dart';
import '../application/planner_ports.dart';
import '../domain/planner.dart';
import '../domain/calendar_event_creation.dart';

/// Ordinary owned-calendar mutations. Focus blocks retain their own writer.
class GooglePlannerWriter implements PlannerEventWriter {
  GooglePlannerWriter(
    this.connection, {
    http.Client Function()? clientFactory,
    this.timeout = const Duration(seconds: 30),
    DateTime Function()? now,
  }) : _factory = clientFactory ?? http.Client.new,
       _now = now ?? DateTime.now;
  final CalendarConnectionController connection;
  final http.Client Function() _factory;
  final Duration timeout;
  final DateTime Function() _now;
  bool Function()? mutationAllowed;
  final Set<http.Client> _clients = {};
  int _generation = 0;
  DateTime? _retryAt;

  void _guard(int generation, String account, bool mutation) {
    if (generation != _generation || account != connection.verifiedAccountKey) {
      throw const PlannerFailure(
        PlannerFailureKind.cancelled,
        'Calendar access changed. Your changes are kept.',
      );
    }
    if (mutation &&
        (!connection.creationEnabled ||
            connection.creationUpgradeActive ||
            mutationAllowed?.call() == false)) {
      throw const PlannerFailure(
        PlannerFailureKind.permission,
        'Enable calendar editing or reconnect Google. Your changes are kept.',
      );
    }
  }

  Future<Map<String, dynamic>?> _request(
    String method,
    List<String> path,
    String account, {
    Map<String, dynamic>? body,
    String? etag,
    bool notifyGuests = false,
  }) async {
    final generation = _generation;
    final mutation = method != 'GET';
    if (_retryAt?.isAfter(_now()) == true) {
      throw PlannerFailure(
        PlannerFailureKind.network,
        'Waiting to sync. Google requested a pause.',
        retryAt: _retryAt,
      );
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      _guard(generation, account, mutation);
      final client = _factory();
      _clients.add(client);
      var dispatched = false;
      try {
        final result = await connection.withAccess((token) async {
          _guard(generation, account, mutation);
          final request =
              http.Request(
                  method,
                  Uri(
                    scheme: 'https',
                    host: 'www.googleapis.com',
                    pathSegments: ['calendar', 'v3', ...path],
                    queryParameters: mutation
                        ? {
                            'eventLabelVersion': '0',
                            'sendUpdates': notifyGuests ? 'all' : 'none',
                          }
                        : null,
                  ),
                )
                ..followRedirects = false
                ..headers['Authorization'] = 'Bearer $token';
          if (etag != null) request.headers['If-Match'] = etag;
          if (body != null) {
            request.headers['Content-Type'] = 'application/json; charset=utf-8';
            request.body = jsonEncode(body);
          }
          _guard(generation, account, mutation);
          dispatched = true;
          final stream = await client.send(request).timeout(timeout);
          final bytes = <int>[];
          await for (final chunk in stream.stream.timeout(timeout)) {
            if (bytes.length + chunk.length > 4 * 1024 * 1024) {
              throw PlannerFailure(
                PlannerFailureKind.network,
                'Google returned an incomplete response. Retry to check the save.',
                uncertain: mutation,
              );
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
        _guard(generation, account, false);
        if (result == null) {
          throw const PlannerFailure(
            PlannerFailureKind.permission,
            'Reconnect Google to resume syncing.',
          );
        }
        final response = result.$1;
        if (response.statusCode == 401) {
          await connection.refreshRejectedAccess(result.$2);
          if (!mutation && attempt == 0) continue;
          throw PlannerFailure(
            PlannerFailureKind.network,
            'Checking the original save before retrying.',
            uncertain: mutation,
          );
        }
        if (response.statusCode == 404) return null;
        if (response.statusCode == 410) {
          throw const PlannerFailure(
            PlannerFailureKind.deleted,
            'This event was removed in Google Calendar.',
          );
        }
        if (response.statusCode == 409) {
          throw const PlannerFailure(
            PlannerFailureKind.network,
            'Checking the original event.',
            uncertain: true,
          );
        }
        if (response.statusCode == 412) {
          throw const PlannerFailure(
            PlannerFailureKind.precondition,
            'Changed in Google Calendar. Review your changes.',
          );
        }
        if (response.statusCode == 204) return <String, dynamic>{};
        if (response.statusCode == 200 || response.statusCode == 201) {
          final value = jsonDecode(response.body);
          if (value is! Map<String, dynamic>) {
            throw const FormatException('Invalid Google response.');
          }
          _retryAt = null;
          return value;
        }
        final rateLimited =
            response.statusCode == 429 ||
            response.statusCode == 403 &&
                (response.body.contains('rateLimitExceeded') ||
                    response.body.contains('userRateLimitExceeded'));
        if (rateLimited || response.statusCode >= 500) {
          var delay = Duration(seconds: 2 + Random().nextInt(4));
          final retry = response.headers['retry-after'];
          if (retry != null) {
            final seconds = int.tryParse(retry);
            final requested = seconds == null
                ? HttpDate.parse(retry).difference(_now())
                : Duration(seconds: seconds);
            if (requested > delay) delay = requested;
          }
          _retryAt = _now().add(delay);
          throw PlannerFailure(
            PlannerFailureKind.network,
            'Waiting to sync. Google could not complete the request.',
            retryAt: _retryAt,
            uncertain: mutation,
          );
        }
        if (response.statusCode == 403) {
          throw const PlannerFailure(
            PlannerFailureKind.permission,
            'This event or calendar cannot be changed with your current access.',
          );
        }
        throw const PlannerFailure(
          PlannerFailureKind.invalid,
          'Google could not save these fields. Review the task and retry.',
        );
      } on PlannerFailure {
        rethrow;
      } catch (_) {
        throw PlannerFailure(
          PlannerFailureKind.network,
          'Waiting to sync. Your changes are kept.',
          uncertain: mutation && dispatched,
        );
      } finally {
        _clients.remove(client);
        client.close();
      }
    }
    throw const PlannerFailure(
      PlannerFailureKind.permission,
      'Reconnect Google to resume syncing.',
    );
  }

  @override
  Future<bool> validateDestination(String accountKey, String calendarId) async {
    final value = await _request('GET', [
      'users',
      'me',
      'calendarList',
      calendarId,
    ], accountKey);
    return value != null &&
        value['id'] == calendarId &&
        value['accessRole'] == 'owner';
  }

  @override
  Future<PlannerRemoteEvent?> get(
    String accountKey,
    String calendarId,
    String eventId,
  ) async {
    try {
      final value = await _request('GET', [
        'calendars',
        calendarId,
        'events',
        eventId,
      ], accountKey);
      return value == null ? null : PlannerRemoteEvent(calendarId, value);
    } on PlannerFailure catch (failure) {
      if (failure.kind == PlannerFailureKind.deleted) return null;
      rethrow;
    }
  }

  Map<String, dynamic> _properties(
    PlannerOperation operation, [
    PlannerRemoteEvent? latest,
  ]) => {
    ...?latest?.privateProperties.map((k, v) => MapEntry(k as String, v)),
    'pomaPlannerSchema': '1',
    'pomaPlannerSchedule': operation.scheduleId,
    'pomaPlannerOperation': operation.id,
  };

  @override
  Future<PlannerRemoteEvent> create(PlannerOperation operation) async {
    if (operation.eventId != plannerEventId(operation.scheduleId)) {
      throw const PlannerFailure(
        PlannerFailureKind.invalid,
        'The original event identity needs attention.',
      );
    }
    final legacy = operation.legacyReceipt == null
        ? null
        : CalendarCreateOperation.fromJson(operation.legacyReceipt!);
    if (operation.legacy &&
        (legacy == null ||
            legacy.operationId != operation.id ||
            legacy.eventId != operation.eventId ||
            legacy.clientId != connection.configuration.clientId ||
            legacy.generation != connection.creationGeneration)) {
      throw const PlannerFailure(
        PlannerFailureKind.permission,
        'This earlier save belongs to its original calendar authorization. Reconnect that account to check it.',
      );
    }
    final value = await _request(
      'POST',
      ['calendars', operation.calendarId, 'events'],
      operation.accountKey,
      body: {
        ...?legacy?.intent.fields,
        if (legacy == null) ...operation.fields,
        'id': operation.eventId,
        'eventType': 'default',
        'extendedProperties': {
          'private': legacy?.markers ?? _properties(operation),
        },
      },
    );
    if (value == null) {
      throw const PlannerFailure(
        PlannerFailureKind.network,
        'Check the original event before retrying.',
        uncertain: true,
      );
    }
    return PlannerRemoteEvent(operation.calendarId, value);
  }

  void _editable(PlannerRemoteEvent latest) {
    if (!latest.editable || latest.etag.isEmpty) {
      throw const PlannerFailure(
        PlannerFailureKind.permission,
        'This event is read-only in Poma. Use its calendar or Focus blocks to manage it.',
      );
    }
  }

  @override
  Future<PlannerRemoteEvent> update(
    PlannerOperation operation,
    PlannerRemoteEvent latest,
    Map<String, dynamic> patch,
  ) async {
    _editable(latest);
    final value = await _request(
      'PATCH',
      ['calendars', operation.calendarId, 'events', operation.eventId],
      operation.accountKey,
      etag: latest.etag,
      notifyGuests:
          (latest.value['attendees'] as List? ?? []).isNotEmpty &&
          patch.keys.any(
            (k) => const {'summary', 'start', 'end', 'recurrence'}.contains(k),
          ),
      body: {
        ...patch,
        'extendedProperties': {'private': _properties(operation, latest)},
      },
    );
    if (value == null) {
      throw const PlannerFailure(
        PlannerFailureKind.deleted,
        'This event was removed in Google Calendar.',
      );
    }
    return PlannerRemoteEvent(operation.calendarId, value);
  }

  @override
  Future<void> delete(
    PlannerOperation operation,
    PlannerRemoteEvent latest,
  ) async {
    _editable(latest);
    await _request(
      'DELETE',
      ['calendars', operation.calendarId, 'events', operation.eventId],
      operation.accountKey,
      etag: latest.etag,
      notifyGuests: (latest.value['attendees'] as List? ?? []).isNotEmpty,
    );
  }

  @override
  void cancel() {
    _generation++;
    for (final client in _clients.toList()) {
      client.close();
    }
    _clients.clear();
  }
}
