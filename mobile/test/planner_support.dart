import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/application/planner_controller.dart';
import 'package:poma/data/google_planner_writer.dart';
import 'package:poma/data/planner_time.dart';
import 'package:poma/domain/planner.dart';
import 'package:poma/domain/calendar_data.dart';

import 'calendar_creation_support.dart';
import 'calendar_read_test.dart' show TestCalendarClock;
import 'support.dart';

class PlannerGoogle extends CreationGoogle {
  bool offline = false, losePatchResponse = false, loseDeleteResponse = false;
  int patches = 0, deletes = 0, serial = 0;
  void Function(Map<String, dynamic>)? beforePatch;

  List<Map<String, dynamic>> expanded(
    String calendar,
    DateTime first,
    DateTime until,
  ) {
    final result = <String, Map<String, dynamic>>{};
    final range = CalendarWindow(
      first: CalendarDate(first.year, first.month, first.day),
      until: CalendarDate(until.year, until.month, until.day),
      startUtc: first,
      endUtc: until,
    );
    for (final event in events.values.where(
      (event) => event['calendarId'] == calendar,
    )) {
      if ((event['recurrence'] as List? ?? []).isEmpty) continue;
      final schedule = PlannerSchedule(
        id: event['id'] as String,
        eventId: event['id'] as String,
        calendarId: calendar,
        fields: plannerJsonCopy(event),
      );
      for (final occurrence in plannerOccurrences(schedule, range)) {
        final original = occurrence.startUtc!.toIso8601String();
        final suffix =
            '${original.replaceAll(RegExp('[-:]'), '').split('.').first}Z';
        final id = '${event['id']}_$suffix';
        result[id] = {
          ...event,
          'id': id,
          'recurrence': <String>[],
          'recurringEventId': event['id'],
          'originalStartTime': {'dateTime': original},
          'start': {'dateTime': original, 'timeZone': schedule.zone},
          'end': {
            'dateTime': occurrence.endUtc!.toIso8601String(),
            'timeZone': schedule.zone,
          },
          'etag': '${event['etag']}/$suffix',
        };
      }
    }
    for (final event in events.values.where(
      (event) =>
          event['calendarId'] == calendar &&
          (event['recurrence'] as List? ?? []).isEmpty,
    )) {
      result[event['id'] as String] = event;
    }
    return result.values.toList();
  }

  Map<String, dynamic>? instance(String calendar, String id) {
    final split = id.lastIndexOf('_');
    if (split < 0) return null;
    final original = DateTime.tryParse(id.substring(split + 1));
    if (original == null) return null;
    return expanded(
      calendar,
      original.subtract(const Duration(days: 1)),
      original.add(const Duration(days: 1)),
    ).where((event) => event['id'] == id).firstOrNull;
  }

  void decorate() {
    for (final event in events.values) {
      event.putIfAbsent('etag', () => '"planner-${++serial}"');
      event.putIfAbsent('organizer', () => {'self': true});
      event.putIfAbsent('eventType', () => 'default');
      event.putIfAbsent('transparency', () => 'opaque');
    }
  }

  @override
  Future<http.Response> send(http.Request request) async {
    if (offline) throw const SocketException('Fictional offline connection');
    decorate();
    final id = request.url.pathSegments.last;
    final parts = request.url.pathSegments;
    if (parts.contains('events') && id == 'events' && request.method == 'GET') {
      requests.add(request);
      lists++;
      final snapshot = expanded(
        parts[3],
        DateTime.parse(request.url.queryParameters['timeMin']!),
        DateTime.parse(request.url.queryParameters['timeMax']!),
      );
      final gate = listGate;
      listGate = null;
      await gate?.future;
      if (failList) return reply({}, 403);
      return reply({'items': snapshot});
    }
    if (parts.contains('events') && id != 'events' && request.method == 'GET') {
      requests.add(request);
      gets++;
      await getGate?.future;
      if (gone) return reply({}, 410);
      final event = events[id] ?? instance(parts[3], id);
      return event == null ? reply({}, 404) : reply(event);
    }
    if (request.method == 'PATCH' || request.method == 'DELETE') {
      requests.add(request);
      final event = events[id] ?? instance(parts[3], id);
      if (event == null) return reply({}, 404);
      if (request.method == 'PATCH') beforePatch?.call(event);
      if (request.headers['If-Match'] != event['etag']) return reply({}, 412);
      if (request.method == 'DELETE') {
        deletes++;
        if (event['recurringEventId'] != null) {
          events[id] = {...event, 'status': 'cancelled'};
        } else {
          events.remove(id);
          events.removeWhere((_, child) => child['recurringEventId'] == id);
        }
        if (loseDeleteResponse) {
          throw TimeoutException('Fictional lost delete response');
        }
        return http.Response('', 204);
      }
      patches++;
      event.addAll(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
      event['etag'] = '"planner-${++serial}"';
      events[id] = event;
      if (losePatchResponse) {
        throw TimeoutException('Fictional lost patch response');
      }
      return reply(event);
    }
    try {
      final response = await super.send(request);
      decorate();
      if (request.method == 'POST' && response.statusCode == 201) {
        final body = jsonDecode(request.body) as Map;
        return reply(events[body['id']]!, 201);
      }
      return response;
    } finally {
      decorate();
    }
  }
}

class PlannerRig {
  PlannerRig(
    this.creation,
    this.app,
    this.planner,
    this.google,
    this.repository,
  );
  final CreationRig creation;
  final AppController app;
  final PlannerController planner;
  final PlannerGoogle google;
  final LocalRepository repository;

  Future<Map<String, dynamic>> draft({
    String title = 'Fictional evening task',
    bool local = false,
  }) async {
    final value = await planner.beginDraft();
    value.addAll({
      'title': title,
      'date': '2026-11-10',
      'endDate': '2026-11-10',
      'start': '10:00 PM',
      'end': '11:00 PM',
      'zone': 'Asia/Kolkata',
      'calendarId': 'synthetic-primary',
      'localOnly': local,
    });
    return value;
  }

  void dispose() {
    planner.dispose();
    app.dispose();
    creation.dispose();
  }
}

Future<PlannerRig> plannerRig({
  LocalRepository? repository,
  bool sync = true,
  PlannerGoogle? google,
  TestCalendarClock? calendarClock,
  PlannerTime? time,
}) async {
  final server = google ?? PlannerGoogle();
  final creation = await creationRig(
    google: server,
    calendarClock: calendarClock,
  );
  final storage = repository ?? MemoryRepository();
  final app = await AppController.create(
    storage,
    clock: FakeClock(creation.clock.time),
  );
  final writer = GooglePlannerWriter(
    creation.connection,
    clientFactory: server.client,
    now: creation.clock.nowUtc,
  );
  final planner = PlannerController(
    app: app,
    reader: creation.reader,
    writer: writer,
    time: time ?? PlannerTime(fixedZone: 'Asia/Kolkata'),
  );
  writer.mutationAllowed = () => planner.unlocked && !app.cleanupPending;
  await planner.initialize();
  await planner.setPreferences(
    PlannerPreferences(syncEnabled: sync, calendarId: 'synthetic-primary'),
  );
  return PlannerRig(creation, app, planner, server, storage);
}
