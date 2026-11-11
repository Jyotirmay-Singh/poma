import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/planner.dart';

import 'calendar_read_test.dart' show settleCalendar;
import 'planner_support.dart';
import 'support.dart';

Future<PlannerRig> savedPlanner({bool recurring = false}) async {
  final rig = await plannerRig();
  final draft = await rig.draft();
  if (recurring) {
    draft.addAll({'repeat': 'daily', 'ending': 'count', 'count': '3'});
  }
  expect(await rig.planner.saveDraft(draft), isTrue);
  await rig.planner.sync();
  return rig;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'deletion uses the event version fetched for the deletion intent',
    () async {
      final rig = await savedPlanner();
      addTearDown(rig.dispose);
      final schedule = rig.planner.data.schedules.values.single;
      final event = rig.planner.eventsFor(rig.planner.dayRange).single;
      rig.google.events[schedule.eventId]!.addAll({
        'etag': '"new-instance-version"',
        'summary': 'Refreshed event',
      });
      expect(await rig.planner.deleteEvent(event), isTrue);
      final deletion = rig.planner.data.operations.values.last;
      expect(deletion.baseEtag, '"new-instance-version"');
      await rig.creation.scheduler.advance(const Duration(seconds: 11));
      await rig.planner.sync();
      expect(rig.google.deletes, 1);
      expect(
        rig.planner.data.operations[deletion.id]!.state,
        PlannerOperationState.saved,
      );
    },
  );

  test('Undo after repeated deletion retains an earlier queued edit', () async {
    final rig = await savedPlanner();
    addTearDown(rig.dispose);
    rig.google.offline = true;
    final taskId = rig.app.tasks.single.id;
    await rig.planner.renameTask(taskId, 'Queued title');
    await rig.planner.sync();
    final edit = rig.planner.data.operations.values.last;
    expect(edit.attempted, isFalse);
    final schedule = rig.planner.taskSchedule(taskId)!;
    await rig.planner.deleteTask(taskId);
    await rig.planner.removeSchedule(schedule, deleteTask: true);
    final deletions = rig.planner.data.operations.values.where(
      (op) => op.kind == PlannerOperationKind.delete,
    );
    expect(deletions, hasLength(1));
    expect(deletions.single.dependsOn, edit.id);
    expect(rig.planner.data.operations.containsKey(edit.id), isTrue);
    await rig.planner.undoDelete(schedule.id);
    expect(rig.app.tasks.single.title, 'Queued title');
    rig.google.offline = false;
    await rig.planner.retry(edit.id);
    await rig.planner.sync();
    await rig.creation.scheduler.advance(const Duration(seconds: 11));
    expect(rig.google.events.values.single['summary'], 'Queued title');
    expect(rig.google.patches, 1);
    expect(rig.google.deletes, 0);
    expect(rig.planner.pendingFor(schedule.id), isNull);
  });

  for (final lostResponse in [false, true]) {
    test(
      'an edit during creation updates the same event after response loss $lostResponse',
      () async {
        final rig = await plannerRig();
        addTearDown(rig.dispose);
        final gate = Completer<void>();
        rig.google.postGate = gate;
        rig.google.loseResponse = lostResponse;
        await rig.planner.saveDraft(await rig.draft());
        await settleCalendar();
        expect(rig.google.inserts, 1);
        final original = rig.planner.data.operations.values.single;
        expect(original.attempted, isTrue);
        await rig.planner.renameTask(
          rig.app.tasks.single.id,
          'Edited while saving',
        );
        expect(rig.planner.data.operations, hasLength(2));
        expect(
          rig.planner.data.operations.values.first.fields,
          original.fields,
        );
        gate.complete();
        await rig.planner.sync();
        if (lostResponse) {
          await rig.planner.retry(original.id);
          await rig.planner.sync();
        }
        expect(rig.google.inserts, 1);
        expect(rig.google.patches, 1);
        expect(rig.google.events.keys.single, original.eventId);
        expect(
          rig.google.events.values.single['summary'],
          'Edited while saving',
        );
        expect(rig.app.tasks.single.title, 'Edited while saving');
        expect(
          rig.planner.data.operations.values.every((op) => op.terminal),
          isTrue,
        );
      },
    );
  }

  test(
    'title editing preserves second-precision endpoints and unrelated Google arrays',
    () async {
      final rig = await savedPlanner();
      addTearDown(rig.dispose);
      final schedule = rig.planner.data.schedules.values.single;
      final raw = rig.google.events[schedule.eventId]!;
      raw.addAll({
        'start': {
          'dateTime': '2026-11-10T16:30:37Z',
          'timeZone': 'Asia/Kolkata',
        },
        'end': {'dateTime': '2026-11-10T17:30:42Z', 'timeZone': 'Asia/Kolkata'},
        'attendees': [
          {'email': 'fictional@example.invalid', 'responseStatus': 'accepted'},
        ],
        'attachments': [
          {
            'title': 'Fictional attachment',
            'fileUrl': 'https://example.invalid/file',
          },
        ],
        'etag': '"seconds"',
      });
      await rig.creation.reader.refresh();
      await settleCalendar();
      final event = rig.planner.eventsFor(rig.planner.dayRange).first;
      final draft = await rig.planner.editEvent(event);
      draft!['title'] = 'Only the title changed';
      await rig.planner.saveDraft(draft);
      await rig.planner.sync();
      final request = rig.google.requests.lastWhere(
        (request) => request.method == 'PATCH',
      );
      final payload = jsonDecode(request.body) as Map;
      expect(payload.containsKey('start'), isFalse);
      expect(payload.containsKey('end'), isFalse);
      expect(payload.containsKey('attendees'), isFalse);
      expect(payload.containsKey('attachments'), isFalse);
      expect(request.url.queryParameters['sendUpdates'], 'all');
      expect(
        (rig.google.events[schedule.eventId]!['start'] as Map)['dateTime'],
        '2026-11-10T16:30:37Z',
      );
    },
  );

  test(
    'resaving after a failed local commit retains task, schedule and event identities',
    () async {
      final storage = MemoryRepository();
      final rig = await plannerRig(repository: storage);
      addTearDown(rig.dispose);
      final draft = await rig.draft();
      storage.failWrites = true;
      expect(await rig.planner.saveDraft(draft), isFalse);
      final before = rig.planner.data.operations.values.single;
      storage.failWrites = false;
      expect(await rig.planner.saveDraft(draft), isTrue);
      await rig.planner.sync();
      expect(rig.app.tasks, hasLength(1));
      expect(rig.planner.data.schedules, hasLength(1));
      expect(rig.planner.data.operations.values.single.id, before.id);
      expect(rig.google.events.keys.single, before.eventId);
      expect(rig.google.inserts, 1);
    },
  );

  test(
    'lost PATCH and DELETE responses reconcile their original operations',
    () async {
      final rig = await savedPlanner();
      addTearDown(rig.dispose);
      final schedule = rig.planner.data.schedules.values.single;
      rig.google.losePatchResponse = true;
      await rig.planner.renameTask(schedule.taskId!, 'Recovered title');
      await rig.planner.sync();
      var operation = rig.planner.data.operations.values.last;
      expect(operation.state, PlannerOperationState.checking);
      await rig.planner.retry(operation.id);
      await rig.planner.sync();
      expect(rig.google.patches, 1);
      expect(
        rig.planner.data.operations[operation.id]!.state,
        PlannerOperationState.saved,
      );
      rig.google.loseDeleteResponse = true;
      await rig.planner.deleteTask(schedule.taskId!);
      await rig.creation.scheduler.advance(const Duration(seconds: 11));
      await rig.planner.sync();
      operation = rig.planner.data.operations.values.last;
      expect(operation.state, PlannerOperationState.checking);
      await rig.planner.retry(operation.id);
      await rig.planner.sync();
      expect(rig.google.deletes, 1);
      expect(
        rig.planner.data.operations[operation.id]!.state,
        PlannerOperationState.saved,
      );
      await rig.planner.undoDelete(schedule.id);
      expect(rig.app.tasks, isEmpty);
      expect(rig.planner.data.schedules[schedule.id]!.removed, isTrue);
    },
  );

  test('a 412 refetches and merges a non-overlapping Google change', () async {
    final rig = await savedPlanner();
    addTearDown(rig.dispose);
    rig.google.beforePatch = (event) {
      rig.google.beforePatch = null;
      event['description'] = 'A concurrent Google description';
      event['etag'] = '"concurrent"';
    };
    await rig.planner.renameTask(rig.app.tasks.single.id, 'My title');
    await rig.planner.sync();
    expect(rig.google.patches, 1);
    expect(
      rig.google.requests.where((request) => request.method == 'PATCH'),
      hasLength(2),
    );
    expect(
      rig.google.events.values.single['description'],
      'A concurrent Google description',
    );
    expect(rig.google.events.values.single['summary'], 'My title');
    expect(
      rig.planner.data.operations.values.last.state,
      PlannerOperationState.saved,
    );
  });

  test(
    'failed coverage verification hides confirmed gaps while retaining stale events',
    () async {
      final rig = await savedPlanner();
      addTearDown(rig.dispose);
      final range = rig.planner.dayRange;
      expect(
        rig.creation.reader.rangeVerified(range, availability: true),
        isTrue,
      );
      rig.google.failList = true;
      await rig.creation.reader.ensureRange(range, force: true);
      expect(
        rig.creation.reader.rangeVerified(range, availability: true),
        isFalse,
      );
      expect(rig.planner.gaps(range), isEmpty);
      expect(rig.planner.eventsFor(range), isNotEmpty);
      rig.google.failList = false;
      await rig.creation.reader.ensureRange(range, force: true);
      expect(
        rig.creation.reader.rangeVerified(range, availability: true),
        isTrue,
      );
    },
  );

  test(
    'external renames are adopted and external deletion retains an unscheduled task',
    () async {
      final rig = await savedPlanner();
      addTearDown(rig.dispose);
      final schedule = rig.planner.data.schedules.values.single;
      rig.google.events[schedule.eventId]!.addAll({
        'summary': 'Renamed in Google',
        'etag': '"external-rename"',
      });
      await rig.creation.reader.refresh();
      await settleCalendar();
      expect(rig.app.tasks.single.title, 'Renamed in Google');
      rig.google.events.remove(schedule.eventId);
      await rig.creation.reader.refresh();
      await settleCalendar();
      expect(rig.app.tasks, hasLength(1));
      expect(rig.planner.taskSchedule(schedule.taskId!), isNull);
      await rig.planner.sync();
      expect(rig.google.inserts, 1);
      final rescheduled = await rig.planner.beginDraft(
        task: rig.app.tasks.single,
      );
      rescheduled.addAll({
        'start': '10:00 PM',
        'end': '11:00 PM',
        'date': '2026-11-10',
        'endDate': '2026-11-10',
      });
      expect(await rig.planner.saveDraft(rescheduled), isTrue);
      await rig.planner.sync();
      expect(rig.google.inserts, 2);
      expect(rig.google.events.keys.single, isNot(schedule.eventId));
    },
  );

  test(
    'permission loss keeps the original destination and input without sending',
    () async {
      final rig = await plannerRig();
      addTearDown(rig.dispose);
      rig.google.destinationOwned = false;
      final draft = await rig.draft();
      expect(await rig.planner.saveDraft(draft), isTrue);
      await rig.planner.sync();
      final operation = rig.planner.data.operations.values.single;
      expect(operation.state, PlannerOperationState.failed);
      expect(operation.calendarId, 'synthetic-primary');
      expect(rig.app.tasks.single.title, draft['title']);
      expect(rig.google.inserts, 0);
    },
  );

  test(
    'locking cancels an in-flight create and retry checks the same identity',
    () async {
      final rig = await plannerRig();
      addTearDown(rig.dispose);
      rig.google.afterCommit = () => rig.planner.setUnlocked(false);
      await rig.planner.saveDraft(await rig.draft());
      await rig.planner.sync();
      final operation = rig.planner.data.operations.values.single;
      expect(rig.google.inserts, 1);
      expect(operation.state, PlannerOperationState.sending);
      rig.google.afterCommit = null;
      rig.planner.setUnlocked(true);
      await rig.planner.sync();
      expect(rig.google.inserts, 1);
      expect(
        rig.planner.data.operations[operation.id]!.state,
        PlannerOperationState.saved,
      );
    },
  );

  test(
    'recurring occurrence edits and deletions retain the master and other occurrences',
    () async {
      final rig = await savedPlanner(recurring: true);
      addTearDown(rig.dispose);
      final master = rig.planner.data.schedules.values.single;
      final window = rig.planner.range(
        CalendarDate(2026, 11, 10),
        CalendarDate(2026, 11, 14),
      );
      await rig.creation.reader.ensureRange(window);
      var occurrences = rig.planner
          .eventsFor(window)
          .where((event) => event.recurringEventId == master.eventId)
          .toList();
      expect(occurrences, hasLength(3));
      final first = occurrences.first;
      final original = first.originalStart;
      expect(
        await rig.planner.moveEvent(
          first,
          first.startUtc!.add(const Duration(minutes: 30)),
          first.endUtc!.add(const Duration(minutes: 30)),
        ),
        isTrue,
      );
      await rig.planner.sync();
      await rig.creation.reader.ensureRange(window, force: true);
      occurrences = rig.planner
          .eventsFor(window)
          .where((event) => event.recurringEventId == master.eventId)
          .toList();
      final moved = occurrences.firstWhere((event) => event.id == first.id);
      expect(moved.originalStart, original);
      expect(moved.startUtc, first.startUtc!.add(const Duration(minutes: 30)));
      expect(rig.google.events[master.eventId]!['summary'], master.title);
      expect(await rig.planner.deleteEvent(moved), isTrue);
      await rig.creation.scheduler.advance(const Duration(seconds: 11));
      await rig.planner.sync();
      await rig.creation.reader.ensureRange(window, force: true);
      expect(
        rig.planner
            .eventsFor(window)
            .where((event) => event.recurringEventId == master.eventId),
        hasLength(2),
      );
      expect(rig.google.events.containsKey(master.eventId), isTrue);
    },
  );

  test(
    'whole-series edits target the master and invalidate its old instances',
    () async {
      final rig = await savedPlanner(recurring: true);
      addTearDown(rig.dispose);
      final master = rig.planner.data.schedules.values.single;
      var first = rig.planner.eventsFor(rig.planner.dayRange).first;
      final value = await rig.planner.editEvent(first, series: true);
      value!['title'] = 'Entire routine';
      expect(await rig.planner.saveDraft(value), isTrue);
      await rig.planner.sync();
      final patch = rig.google.requests.lastWhere(
        (request) => request.method == 'PATCH',
      );
      expect(patch.url.pathSegments.last, master.eventId);
      expect(
        rig.planner
            .eventsFor(rig.planner.dayRange)
            .every((event) => event.title == 'Entire routine'),
        isTrue,
      );
      first = rig.planner.eventsFor(rig.planner.dayRange).first;
      expect(await rig.planner.deleteEvent(first, series: true), isTrue);
      await rig.creation.scheduler.advance(const Duration(seconds: 11));
      await rig.planner.sync();
      expect(rig.google.events, isEmpty);
      expect(rig.planner.eventsFor(rig.planner.dayRange), isEmpty);
    },
  );

  test(
    'local recurring exceptions preserve occurrence completion identity after a move',
    () async {
      final rig = await plannerRig(sync: false);
      addTearDown(rig.dispose);
      final draft = await rig.draft(local: true);
      draft.addAll({'repeat': 'daily', 'ending': 'count', 'count': '3'});
      await rig.planner.saveDraft(draft);
      final task = rig.app.tasks.single;
      final original = rig.planner.taskOccurrence(task.id)!;
      await rig.planner.completeTask(task.id);
      expect(rig.planner.taskDone(task), isTrue);
      expect(
        await rig.planner.moveEvent(
          original,
          original.startUtc!.add(const Duration(hours: 1)),
          original.endUtc!.add(const Duration(hours: 1)),
        ),
        isTrue,
      );
      expect(
        rig.planner.taskOccurrence(task.id)!.originalStart,
        original.originalStart,
      );
      expect(
        rig.planner.taskOccurrence(task.id)!.startUtc,
        original.startUtc!.add(const Duration(hours: 1)),
      );
      expect(rig.planner.taskDone(task), isTrue);
      expect(rig.google.inserts, 0);
    },
  );

  test(
    'legacy import preserves the original payload receipt and requires explicit retry',
    () async {
      final rig = await plannerRig(sync: false);
      addTearDown(rig.dispose);
      final legacy = rig.creation.controller;
      final draft = rig.creation.draft()..title = 'Legacy fictional event';
      rig.google.loseResponse = true;
      await legacy.submit(draft, rig.creation.intent(draft));
      final old = legacy.journal!.operations.values.single;
      await rig.planner.importLegacy(legacy.journal!);
      final imported = rig.planner.data.operations[old.operationId]!;
      expect(imported.fields, old.intent.fields);
      expect(imported.legacyReceipt!['payloadHash'], old.intent.hash);
      expect(imported.legacyReceipt!['clientId'], old.clientId);
      expect(imported.legacyReceipt!['generation'], old.generation);
      expect(rig.planner.preferences.syncEnabled, isFalse);
      final inserts = rig.google.inserts;
      await rig.planner.sync();
      expect(rig.google.inserts, inserts);
      expect(rig.app.tasks, isEmpty);
      await rig.planner.retry(imported.id);
      await rig.planner.sync();
      expect(rig.google.inserts, inserts);
      expect(
        rig.planner.data.operations[imported.id]!.state,
        PlannerOperationState.saved,
      );
      expect(jsonEncode(imported.legacyReceipt), contains(old.intent.hash));
    },
  );
}
