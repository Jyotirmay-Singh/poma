import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/planner_controller.dart';
import 'package:poma/data/google_planner_writer.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/planner_time.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:poma/domain/planner.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_read_test.dart' show settleCalendar;
import 'planner_support.dart';
import 'support.dart';

CalendarWindow utcRange(int month, int first, int until) => CalendarWindow(
  first: CalendarDate(2026, month, first),
  until: CalendarDate(2026, month, until),
  startUtc: DateTime.utc(2026, month, first),
  endUtc: DateTime.utc(2026, month, until),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    tz_data.initializeTimeZones();
    sqfliteFfiInit();
  });

  test(
    'every Windows timezone mapping resolves in the pinned database',
    () async {
      await PlannerTime().initialize();
      final mappings =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/timezones/windows-zones.json',
                ),
              )
              as Map;
      for (final entry in mappings.entries) {
        expect(
          tz.getLocation(entry.value as String).name,
          entry.value,
          reason: entry.key as String,
        );
      }
    },
  );

  test('the Windows India timezone opens 10 PM as 22:00', () async {
    const channel = MethodChannel('poma/planner-time-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'focusTimeZone');
          return {'zone': 'India Standard Time', 'daylightDisabled': true};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final time = PlannerTime(channel: channel);
    expect(await time.deviceZone(), 'Asia/Kolkata');
    final rig = await plannerRig(time: time);
    addTearDown(rig.dispose);
    final value = await rig.planner.beginDraft(
      startUtc: DateTime.utc(2026, 11, 10, 16, 30),
    );
    expect(value['start'], '22:00');
    expect(value['end'], '23:00');
    expect(value['zone'], 'Asia/Kolkata');
    expect(rig.google.inserts, 0);
  });

  test(
    'a missing device mapping preserves inspected local time for explicit zone selection',
    () async {
      const channel = MethodChannel('poma/missing-planner-time-test');
      final rig = await plannerRig(time: PlannerTime(channel: channel));
      addTearDown(rig.dispose);
      final value = await rig.planner.beginDraft(
        startUtc: DateTime(2026, 11, 10, 22).toUtc(),
      );
      expect(value['start'], '22:00');
      expect(value['end'], '23:00');
      expect(value['zone'], isNull);
      value['title'] = 'Fictional local time';
      expect(rig.planner.validate(value), isNull);
      expect(rig.planner.errors, contains('zone'));
      expect(rig.google.inserts, 0);
    },
  );

  test(
    'provisional events, previews and gaps use the device local DateTime conversion',
    () async {
      final rig = await plannerRig(sync: false);
      addTearDown(rig.dispose);
      final draft = await rig.draft(local: true);
      final preview = rig.planner.preview(draft)!;
      expect(preview.startUtc, isNot(isA<tz.TZDateTime>()));
      expect(preview.endUtc, isNot(isA<tz.TZDateTime>()));
      expect(await rig.planner.saveDraft(draft), isTrue);
      final event = rig.planner.eventsFor(rig.planner.dayRange).single;
      expect(event.startUtc, isNot(isA<tz.TZDateTime>()));
      expect(event.endUtc, isNot(isA<tz.TZDateTime>()));
      expect(
        event.startUtc!.toLocal(),
        DateTime.utc(2026, 11, 10, 16, 30).toLocal(),
      );
      final gap = PlannerGap(
        tz.TZDateTime(tz.getLocation('Asia/Kolkata'), 2026, 11, 10, 22),
        tz.TZDateTime(tz.getLocation('Asia/Kolkata'), 2026, 11, 10, 23),
      );
      expect(gap.startUtc, isNot(isA<tz.TZDateTime>()));
      expect(gap.endUtc, isNot(isA<tz.TZDateTime>()));
      expect(gap.duration, const Duration(hours: 1));
      expect(gap.startUtc.toLocal(), event.startUtc!.toLocal());
    },
  );

  test(
    'weekday, selected-weekday, inclusive endings and leap-date routines expand as labelled',
    () {
      final zone = tz.getLocation('Etc/UTC');
      PlannerSchedule routine(String first, PlannerRecurrence recurrence) =>
          PlannerSchedule(
            id: newPlannerId(),
            fields: {
              'summary': 'Fictional routine',
              'start': {
                'dateTime': '${first}T09:00:00Z',
                'timeZone': zone.name,
              },
              'end': {'dateTime': '${first}T10:00:00Z', 'timeZone': zone.name},
              'recurrence': recurrence.rule(zone),
            },
          );
      final weekdays = routine(
        '2026-11-08',
        const PlannerRecurrence(repeat: PlannerRepeat.weekdays, count: 3),
      );
      expect(
        plannerOccurrences(
          weekdays,
          utcRange(11, 8, 14),
        ).map((event) => event.startUtc!.day),
        [9, 10, 11],
      );
      final selected = routine(
        '2026-11-09',
        const PlannerRecurrence(
          repeat: PlannerRepeat.weekly,
          interval: 2,
          weekdays: [2, 4],
          count: 4,
        ),
      );
      expect(
        plannerOccurrences(
          selected,
          utcRange(11, 9, 30),
        ).map((event) => event.startUtc!.day),
        [10, 12, 24, 26],
      );
      final ending = routine(
        '2026-11-09',
        PlannerRecurrence(
          repeat: PlannerRepeat.daily,
          until: CalendarDate(2026, 11, 11),
        ),
      );
      expect(
        plannerOccurrences(
          ending,
          utcRange(11, 9, 14),
        ).map((event) => event.startUtc!.day),
        [9, 10, 11],
      );
      final leap = routine(
        '2028-02-29',
        const PlannerRecurrence(
          repeat: PlannerRepeat.monthly,
          interval: 12,
          count: 2,
        ),
      );
      final window = CalendarWindow(
        first: CalendarDate(2028, 2, 1),
        until: CalendarDate(2033, 3, 1),
        startUtc: DateTime.utc(2028, 2),
        endUtc: DateTime.utc(2033, 3),
      );
      expect(
        plannerOccurrences(leap, window).map((event) => event.startUtc!.year),
        [2028, 2032],
      );
      expect(
        PlannerRecurrence.parse([
          'RRULE:FREQ=DAILY;UNTIL=20261201',
        ], tz.getLocation('America/New_York'))!.until.toString(),
        '2026-12-01',
      );
    },
  );

  test(
    'five-minute snapping is nearest and preserves a selected date at midnight',
    () {
      expect(plannerSnapMinute(22 * 60), 1320);
      expect(plannerSnapMinute(1322), 1320);
      expect(plannerSnapMinute(1323), 1325);
      expect(plannerSnapMinute(1439), 1435);
    },
  );

  test(
    'strict wall resolution distinguishes skipped and repeated DST times',
    () {
      final zone = tz.getLocation('America/New_York');
      expect(
        plannerResolveWall(zone, DateTime.utc(2026, 3, 8, 2, 30)),
        isEmpty,
      );
      final fold = plannerResolveWall(zone, DateTime.utc(2026, 11, 1, 1, 30));
      expect(fold.map((t) => t.toUtc()), [
        DateTime.utc(2026, 11, 1, 5, 30),
        DateTime.utc(2026, 11, 1, 6, 30),
      ]);
    },
  );

  test('daily routines preserve 9 AM while their UTC offset changes', () {
    final zone = tz.getLocation('America/New_York');
    final schedule = PlannerSchedule(
      id: newPlannerId(),
      fields: {
        'summary': 'Morning routine',
        'start': {'dateTime': '2026-03-07T14:00:00Z', 'timeZone': zone.name},
        'end': {'dateTime': '2026-03-07T15:00:00Z', 'timeZone': zone.name},
        'recurrence': const PlannerRecurrence(
          repeat: PlannerRepeat.daily,
          count: 3,
        ).rule(zone),
      },
    );
    final events = plannerOccurrences(schedule, utcRange(3, 7, 11)).toList();
    expect(events.map((e) => e.startUtc), [
      DateTime.utc(2026, 3, 7, 14),
      DateTime.utc(2026, 3, 8, 13),
      DateTime.utc(2026, 3, 9, 13),
    ]);
    expect(
      events.every((e) => tz.TZDateTime.from(e.startUtc!, zone).hour == 9),
      isTrue,
    );
  });

  test(
    'monthly day 31 skips shorter months and COUNT counts actual occurrences',
    () {
      final schedule = PlannerSchedule(
        id: newPlannerId(),
        fields: {
          'summary': 'Monthly routine',
          'start': {'dateTime': '2026-01-31T09:00:00Z', 'timeZone': 'Etc/UTC'},
          'end': {'dateTime': '2026-01-31T10:00:00Z', 'timeZone': 'Etc/UTC'},
          'recurrence': ['RRULE:FREQ=MONTHLY;COUNT=3'],
        },
      );
      final window = CalendarWindow(
        first: CalendarDate(2026, 1, 1),
        until: CalendarDate(2026, 7, 1),
        startUtc: DateTime.utc(2026),
        endUtc: DateTime.utc(2026, 7),
      );
      expect(plannerOccurrences(schedule, window).map((e) => e.startUtc), [
        DateTime.utc(2026, 1, 31, 9),
        DateTime.utc(2026, 3, 31, 9),
        DateTime.utc(2026, 5, 31, 9),
      ]);
    },
  );

  test(
    'gap calculations merge touching busy events and ignore transparent time',
    () {
      CalendarEvent event(
        String id,
        int start,
        int end, {
        String busy = 'opaque',
      }) => CalendarEvent(
        id: id,
        calendarId: 'fictional',
        title: id,
        status: 'confirmed',
        selfResponse: 'accepted',
        startUtc: DateTime.utc(2026, 11, 10, start),
        endUtc: DateTime.utc(2026, 11, 10, end),
        transparency: busy,
      );
      final window = CalendarWindow(
        first: CalendarDate(2026, 11, 10),
        until: CalendarDate(2026, 11, 11),
        startUtc: DateTime.utc(2026, 11, 10, 9),
        endUtc: DateTime.utc(2026, 11, 10, 17),
      );
      final events = [
        event('a', 10, 12),
        event('b', 11, 13),
        event('c', 13, 14),
        event('free', 15, 17, busy: 'transparent'),
      ];
      expect(
        plannerGaps(
          events,
          window,
          verified: true,
        ).map((g) => [g.startUtc.hour, g.endUtc.hour]),
        [
          [9, 10],
          [14, 17],
        ],
      );
      expect(plannerGaps(events, window, verified: false), isEmpty);
      final allDay = CalendarEvent(
        id: 'day',
        calendarId: 'fictional',
        title: 'Busy day',
        status: 'confirmed',
        selfResponse: 'accepted',
        startDate: CalendarDate(2026, 11, 10),
        endDate: CalendarDate(2026, 11, 11),
        transparency: 'opaque',
      );
      expect(
        plannerGaps(
          [allDay],
          window,
          verified: true,
          midnight: (d) => DateTime.utc(d.year, d.month, d.day),
        ),
        isEmpty,
      );
    },
  );

  test(
    'merge preserves unrelated Google edits and treats endpoints as one change',
    () {
      final base = {'summary': 'Original', 'start': '10', 'end': '11'};
      expect(
        plannerMergePatch(
          base,
          {...base, 'summary': 'Mine'},
          {...base, 'end': '12'},
        ),
        {'summary': 'Mine'},
      );
      expect(
        plannerMergePatch(
          base,
          {...base, 'start': '9'},
          {...base, 'end': '12'},
        ),
        isNull,
      );
    },
  );

  test('24-hour and zoomed projections use the same exact UTC intervals', () {
    final day = utcRange(11, 10, 11);
    final event = CalendarEvent(
      id: 'evening',
      calendarId: 'fictional',
      title: 'Evening',
      status: 'confirmed',
      selfResponse: 'accepted',
      startUtc: DateTime.utc(2026, 11, 10, 22),
      endUtc: DateTime.utc(2026, 11, 10, 23),
    );
    for (final spec in [
      (0, 1440, 660.0, 690.0),
      (21 * 60, 180, 240.0, 480.0),
    ]) {
      final window = DayClockWindow.build(
        date: day.first,
        half: DayClockHalf.pm,
        day: day,
        localize: (t) => t.toUtc(),
        startMinute: spec.$1,
        spanMinutes: spec.$2,
      );
      final projection = DayClockProjection.project(
        window: window,
        events: [event],
        nowUtc: DateTime.utc(2026, 11, 10, 22, 30),
      );
      expect(projection.sectors.single.startMinute, spec.$3);
      expect(projection.sectors.single.endMinute, spec.$4);
      expect(
        projection.sectors.single.endUtc.difference(
          projection.sectors.single.startUtc,
        ),
        const Duration(hours: 1),
      );
    }
  });

  test(
    'one Save creates a task and one Google event despite concurrent clicks',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      final draft = await r.draft();
      final saves = await Future.wait([
        r.planner.saveDraft(draft),
        r.planner.saveDraft(draft),
      ]);
      await r.planner.sync();
      expect(saves.where((s) => s), hasLength(1));
      expect(r.app.tasks, hasLength(1));
      expect(r.google.events, hasLength(1));
      expect(r.google.inserts, 1);
      final schedule = r.planner.data.schedules.values.single;
      expect(schedule.startUtc, DateTime.utc(2026, 11, 10, 16, 30));
      expect(schedule.endUtc, DateTime.utc(2026, 11, 10, 17, 30));
      expect(r.planner.status(schedule), 'Saved');
      expect(
        r.planner
            .eventsFor(r.planner.dayRange)
            .where((e) => e.id == schedule.eventId),
        hasLength(1),
      );
    },
  );

  test(
    'a lost insert response checks the same event and never creates a replacement',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      r.google.loseResponse = true;
      await r.planner.saveDraft(await r.draft());
      await r.planner.sync();
      final operation = r.planner.data.operations.values.single;
      expect(operation.state, PlannerOperationState.checking);
      await r.planner.retry(operation.id);
      await r.planner.sync();
      expect(r.google.inserts, 1);
      expect(r.google.events, hasLength(1));
      expect(
        r.planner.data.operations[operation.id]!.state,
        PlannerOperationState.saved,
      );
    },
  );

  test(
    'local saves and unscheduled tasks stay local after syncing is enabled',
    () async {
      final r = await plannerRig(sync: false);
      addTearDown(r.dispose);
      await r.planner.saveDraft(await r.draft(local: true));
      final unscheduled = await r.planner.beginDraft(scheduled: false)
        ..['title'] = 'Local checklist';
      await r.planner.saveDraft(unscheduled);
      await r.planner.setPreferences(
        r.planner.preferences.copyWith(syncEnabled: true),
      );
      await r.planner.sync();
      expect(r.app.tasks, hasLength(2));
      expect(r.google.inserts, 0);
      expect(r.planner.data.operations, isEmpty);
    },
  );

  test(
    'rename, movement and completion retain the linked ID and unrelated fields',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      await r.planner.saveDraft(await r.draft());
      await r.planner.sync();
      final id = r.google.events.keys.single, taskId = r.app.tasks.single.id;
      r.google.events[id]!.addAll({
        'description': 'Keep this description',
        'reminders': {
          'useDefault': false,
          'overrides': [
            {'method': 'popup', 'minutes': 10},
          ],
        },
      });
      await r.planner.renameTask(taskId, 'Renamed task');
      await r.planner.sync();
      var event = r.planner
          .eventsFor(r.planner.dayRange)
          .firstWhere((e) => e.id == id);
      await r.planner.moveEvent(
        event,
        event.startUtc!.add(const Duration(minutes: 15)),
        event.endUtc!.add(const Duration(minutes: 15)),
      );
      await r.planner.sync();
      await r.planner.completeTask(taskId);
      expect(r.google.inserts, 1);
      expect(r.google.events.keys.single, id);
      expect(r.google.patches, 2);
      expect(r.google.events[id]!['description'], 'Keep this description');
      expect((r.google.events[id]!['reminders'] as Map)['useDefault'], false);
      expect(r.app.tasks.single.done, isTrue);
      expect(r.google.deletes, 0);
      final patches = r.google.requests.where((q) => q.method == 'PATCH');
      expect(
        patches.every(
          (q) => !((jsonDecode(q.body) as Map).containsKey('reminders')),
        ),
        isTrue,
      );
    },
  );

  test(
    'offline queued work survives restart and resumes under its original account',
    () async {
      final storage = MemoryRepository();
      final r = await plannerRig(repository: storage);
      r.google.offline = true;
      await r.planner.saveDraft(await r.draft());
      await r.planner.sync();
      final id = r.planner.data.operations.values.single.eventId;
      r.planner.dispose();
      r.app.dispose();
      final app = await AppController.create(
        storage,
        clock: FakeClock(r.creation.clock.time),
      );
      final writer = GooglePlannerWriter(
        r.creation.connection,
        clientFactory: r.google.client,
        now: r.creation.clock.nowUtc,
      );
      final planner = PlannerController(
        app: app,
        reader: r.creation.reader,
        writer: writer,
        time: PlannerTime(fixedZone: 'Asia/Kolkata'),
      );
      writer.mutationAllowed = () => planner.unlocked;
      await planner.initialize();
      r.google.offline = false;
      await planner.retry(planner.data.operations.values.single.id);
      await planner.sync();
      expect(r.google.events.keys.single, id);
      expect(r.google.inserts, 1);
      expect(app.tasks, hasLength(1));
      planner.dispose();
      app.dispose();
      r.creation.dispose();
    },
  );

  test(
    'delete waits ten seconds and Undo restores a deleted local task',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      await r.planner.saveDraft(await r.draft());
      await r.planner.sync();
      final schedule = r.planner.data.schedules.values.single;
      await r.planner.deleteTask(r.app.tasks.single.id);
      await r.planner.sync();
      expect(r.app.tasks, isEmpty);
      expect(r.google.deletes, 0);
      await r.planner.undoDelete(schedule.id);
      await r.creation.scheduler.advance(const Duration(seconds: 11));
      await r.planner.sync();
      expect(r.app.tasks.single.id, schedule.taskId);
      expect(r.google.deletes, 0);
      await r.planner.deleteTask(r.app.tasks.single.id);
      await r.creation.scheduler.advance(const Duration(seconds: 11));
      await r.planner.sync();
      expect(r.google.deletes, 1);
      expect(r.google.events, isEmpty);
    },
  );

  test(
    'a Google conflict retains the draft until the user saves the reviewed change',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      await r.planner.saveDraft(await r.draft());
      await r.planner.sync();
      final id = r.google.events.keys.single;
      final draft = r.planner.editSchedule(
        r.planner.data.schedules.values.single,
      )..['title'] = 'My change';
      r.google.events[id]!['summary'] = 'Google change';
      r.google.events[id]!['etag'] = '"external"';
      await r.planner.saveDraft(draft);
      await r.planner.sync();
      final operation = r.planner.data.operations.values.last;
      expect(operation.state, PlannerOperationState.conflict);
      expect(r.google.patches, 0);
      final reviewed = await r.planner.reviewConflict(operation.id);
      await r.planner.sync();
      expect(r.google.patches, 0);
      expect(reviewed!['title'], 'My change');
      await r.planner.saveDraft(reviewed);
      await r.planner.sync();
      expect(r.google.events[id]!['summary'], 'My change');
      expect(r.google.patches, 1);
    },
  );

  test(
    'range browsing loads a past month without changing the resident seven dates',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      final resident = r.creation.reader.window.key;
      r.planner.browse(CalendarDate(2025, 4, 15));
      final range = r.planner.monthRange();
      await r.creation.reader.ensureRange(range);
      expect(r.creation.reader.window.key, resident);
      expect(
        r.creation.reader.rangeVerified(range, availability: true),
        isTrue,
      );
      expect(r.planner.monthRange().first.toString(), '2025-03-31');
      expect(r.planner.monthRange().until.toString(), '2025-05-12');
    },
  );

  test(
    'validation handles noon, midnight, overnight dates, and a DST choice',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      final draft = await r.draft();
      draft.addAll({
        'start': '12:00 PM',
        'end': '12:00 AM',
        'endDate': '2026-11-11',
      });
      var fields = r.planner.validate(draft)!;
      expect(
        DateTime.parse((fields['end'] as Map)['dateTime'] as String).difference(
          DateTime.parse((fields['start'] as Map)['dateTime'] as String),
        ),
        const Duration(hours: 12),
      );
      draft.addAll({
        'date': '2026-11-01',
        'endDate': '2026-11-01',
        'start': '01:30',
        'end': '02:30',
        'zone': 'America/New_York',
      });
      expect(r.planner.validate(draft), isNull);
      draft['startChoice'] = DateTime.utc(2026, 11, 1, 6, 30).toIso8601String();
      fields = r.planner.validate(draft)!;
      expect((fields['start'] as Map)['dateTime'], '2026-11-01T06:30:00.000Z');
    },
  );

  test(
    'SQLite commits a task, link, and outbox together and retains them on reopen',
    () async {
      final dir = await Directory.systemTemp.createTemp('poma-planner-');
      addTearDown(() async {
        if (await dir.exists()) await dir.delete(recursive: true);
      });
      final path = '${dir.path}/poma.db';
      final repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final r = await plannerRig(repository: repository);
      r.google.offline = true;
      await r.planner.saveDraft(await r.draft());
      await r.planner.sync();
      final first = await repository.loadInitial();
      expect(first.tasks, hasLength(1));
      expect(first.planner.schedules, hasLength(1));
      expect(first.planner.operations, hasLength(1));
      r.dispose();
      await repository.close();
      final reopened = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final next = await reopened.loadInitial();
      expect(next.tasks.single.id, first.tasks.single.id);
      expect(
        next.planner.operations.values.single.eventId,
        first.planner.operations.values.single.eventId,
      );
      await reopened.close();
    },
  );

  test('a failed local transaction sends no Google request', () async {
    final storage = MemoryRepository();
    final r = await plannerRig(repository: storage);
    addTearDown(r.dispose);
    final draft = await r.draft();
    storage.failWrites = true;
    expect(await r.planner.saveDraft(draft), isFalse);
    await r.planner.sync();
    expect(r.google.inserts, 0);
    expect(storage.state.planner.operations, isEmpty);
    storage.failWrites = false;
    await r.app.retrySave();
    await r.planner.sync();
    expect(r.google.inserts, 1);
    expect(r.app.tasks, hasLength(1));
  });

  test(
    'disabling sync pauses a queued operation and keeps its stable ID',
    () async {
      final r = await plannerRig();
      addTearDown(r.dispose);
      r.google.offline = true;
      await r.planner.saveDraft(await r.draft());
      await r.planner.sync();
      final operation = r.planner.data.operations.values.single;
      await r.planner.setPreferences(
        r.planner.preferences.copyWith(syncEnabled: false),
      );
      r.google.offline = false;
      await r.planner.retry(operation.id);
      await r.planner.sync();
      expect(r.google.inserts, 0);
      await r.planner.setPreferences(
        r.planner.preferences.copyWith(syncEnabled: true),
      );
      await r.planner.sync();
      expect(r.google.events.keys.single, operation.eventId);
      await settleCalendar();
    },
  );
}
