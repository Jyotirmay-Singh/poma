import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/domain/calendar_event_creation.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/data/windows_calendar_creation_store.dart';
import 'package:flutter/services.dart';
import 'calendar_creation_support.dart';
import 'calendar_read_test.dart' show settleCalendar;

void main() {
  test(
    'late checking cannot apply its outcome to a replacement account draft',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      r.google.omitCommit = true;
      final draft = r.draft();
      r.day.draft = draft;
      await r.controller.submit(draft, r.intent(draft));
      final op = r.controller.journal!.operations[draft.id]!;
      final gate = Completer<void>();
      r.google.getGate = gate;
      final checking = r.day.reconcile(op);
      await settleCalendar();
      await r.connection.disconnect();
      r.auth.onAuthorize = () async => CalendarAuthorization(
        accountId: 'other-fictional-account',
        accessToken: 'other-fictional-access',
        refreshToken: 'other-fictional-refresh',
        scopes: calendarReadScopes,
        expiresAt: r.clock.time.add(const Duration(days: 2)),
      );
      await r.connection.connect();
      await settleCalendar();
      final next = r.day.beginDraft()..title = 'Other account draft';
      r.day.touchDraft();
      gate.complete();
      await checking;
      expect(r.day.draft, same(next));
      expect(r.day.validationMessage, isNull);
      expect(r.day.creationState, CalendarCreationState.draft);
      expect(r.google.inserts, 1);
      expect(r.google.events, isEmpty);
    },
  );
  test(
    'no-longer-accessible destination cannot establish absence or authorize retry',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      r.google.omitCommit = true;
      final draft = r.draft();
      await r.controller.submit(draft, r.intent(draft));
      r.google.destinationMissing = true;
      final op = r.controller.journal!.operations[draft.id]!;
      final result = await r.controller.check(op);
      expect(result.state, CalendarCreationState.checking);
      expect(result.retryAllowed, false);
      await r.controller.submit(draft, r.intent(draft), retry: true);
      expect(r.google.inserts, 1);
    },
  );
  test(
    'moved recurrence exception replaces its original position and omits cancelled and declined instances',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final draft = r.draft();
      await r.controller.submit(draft, r.intent(draft));
      final event = r.google.events.values.single;
      event['recurringEventId'] = 'fictional-series';
      event['originalStartTime'] = {'dateTime': '2026-11-10T22:00:00+05:30'};
      await r.reader.refresh();
      final identity = calendarEventIdentity(r.day.projection.agenda.single);
      event['start'] = {'dateTime': '2026-11-10T23:00:00+05:30'};
      event['end'] = {'dateTime': '2026-11-10T23:30:00+05:30'};
      r.google.events['cancelled-instance'] = {
        ...event,
        'id': 'cancelled-instance',
        'status': 'cancelled',
      };
      r.google.events['declined-instance'] = {
        ...event,
        'id': 'declined-instance',
        'attendees': [
          {'self': true, 'responseStatus': 'declined'},
        ],
      };
      await r.reader.refresh();
      final p = r.day.projection;
      expect(p.sectors.length, 1);
      expect(p.agenda.length, 1);
      expect(calendarEventIdentity(p.agenda.single), identity);
      expect(p.sectors.single.startMinute, 660);
      expect(p.sectors.single.endMinute, 690);
      expect(p.scheduled, const Duration(minutes: 30));
    },
  );
  test(
    'time-context change during final provider preflight blocks transmission',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft(), i = r.intent(r.draft());
      var validations = 0;
      r.google.onValidate = () {
        if (++validations == 2) {
          r.times.zoneFingerprint = 'changed-during-preflight';
        }
      };
      await r.controller.submit(d, i);
      expect(r.google.inserts, 0);
    },
  );
  test(
    'lost acknowledgement with unreadable storage recovers Saved from reopened durable record',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft();
      r.store.onSaved = (value) {
        final m = jsonDecode(value) as Map;
        if (((m['operations'] as Map)[d.id] as Map?)?['state'] == 'saved') {
          r.store.lostAck = true;
          r.store.failOpen = true;
        }
      };
      expect(
        (await r.controller.submit(d, r.intent(d))).state,
        CalendarCreationState.checking,
      );
      expect(r.google.inserts, 1);
      expect(r.google.events.length, 1);
      r.store.onSaved = null;
      r.store.lostAck = false;
      r.store.failOpen = false;
      await r.controller.initialize();
      expect(
        r.controller.journal!.operations[d.id]!.state,
        CalendarCreationState.saved,
      );
      await r.controller.submit(d, r.intent(d));
      expect(r.google.inserts, 1);
    },
  );
  test(
    'disconnect after transmission preserves remote event and rejects late local acknowledgement',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final gate = Completer<void>();
      r.google.postGate = gate;
      final d = r.draft();
      final save = r.controller.submit(d, r.intent(d));
      await settleCalendar();
      expect(r.google.inserts, 1);
      await r.connection.disconnect();
      gate.complete();
      await save;
      await settleCalendar();
      expect(r.google.events.length, 1);
      expect(r.controller.journal, isNull);
      expect(r.store.document, isNull);
      expect(r.connection.creationEnabled, false);
      expect(r.google.requests.any((q) => q.method == 'DELETE'), false);
    },
  );
  test('HTTP Gone is a tombstone and cannot authorize resurrection', () async {
    final r = await creationRig();
    addTearDown(r.dispose);
    r.google.omitCommit = true;
    final d = r.draft();
    await r.controller.submit(d, r.intent(d));
    r.google.gone = true;
    final result = await r.controller.check(
      r.controller.journal!.operations[d.id]!,
    );
    expect(result.state, CalendarCreationState.failed);
    expect(result.retryAllowed, false);
    r.google.omitCommit = false;
    await r.controller.submit(d, r.intent(d), retry: true);
    expect(r.google.inserts, 1);
    expect(r.google.events, isEmpty);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'future 10–11 PM creates one ordinary event and one matching shared sector/agenda item',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft();
      r.day.draft = d;
      await r.day.validateDraft();
      expect(r.day.review!.startUtc, DateTime.utc(2026, 11, 10, 16, 30));
      final result = await r.day.submitReviewed();
      expect(result.state, CalendarCreationState.saved);
      expect(r.google.inserts, 1);
      expect(r.google.events.length, 1);
      final event = r.google.events.values.single;
      expect(event['eventType'], 'default');
      expect(
        (event['start'] as Map)['dateTime'],
        '2026-11-10T22:00:00.000+05:30',
      );
      expect(
        (event['end'] as Map)['dateTime'],
        '2026-11-10T23:00:00.000+05:30',
      );
      expect(event['colorId'], '2');
      expect(event['transparency'], 'opaque');
      expect(event.containsKey('attendees'), false);
      expect(event.containsKey('recurrence'), false);
      expect(event.containsKey('reminders'), false);
      expect(event.containsKey('visibility'), false);
      expect(
        (event['extendedProperties'] as Map)['private'],
        isNot(contains('pomaOwner')),
      );
      final post = r.google.requests.singleWhere((q) => q.method == 'POST');
      expect(post.url.queryParameters['eventLabelVersion'], '0');
      expect(r.day.projection.agenda.length, 1);
      expect(r.day.projection.sectors.length, 1);
      expect(r.day.projection.sectors.single.startMinute, 600);
      expect(r.day.projection.sectors.single.endMinute, 660);
      expect(r.reader.events.single.id, result.event!.id);
      expect(r.day.date.toString(), '2026-11-10');
    },
  );
  test(
    'double submit and repeated confirmed action retain one operation and one event',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft(), gate = Completer<void>();
      r.google.postGate = gate;
      final first = r.controller.submit(d, r.intent(d));
      await settleCalendar();
      final second = await r.controller.submit(d, r.intent(d));
      expect(second.state, isNot(CalendarCreationState.saved));
      gate.complete();
      await first;
      await r.controller.submit(d, r.intent(d));
      expect(r.google.inserts, 1);
      expect(r.google.events.length, 1);
      expect(r.controller.journal!.operations.keys, [d.id]);
    },
  );
  test(
    'storage rejection sends zero mutations; lost local acknowledgement is read back',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft();
      r.store.failSave = true;
      expect(
        (await r.controller.submit(d, r.intent(d))).state,
        CalendarCreationState.failed,
      );
      expect(r.google.inserts, 0);
      r.store.failSave = false;
      r.store.lostAck = true;
      expect(
        (await r.controller.submit(d, r.intent(d))).state,
        CalendarCreationState.saved,
      );
      expect(r.google.events.length, 1);
      expect(
        CalendarCreationJournal.decode(
          r.store.document!,
          d.accountKey!,
        ).operations[d.id]!.state,
        CalendarCreationState.saved,
      );
    },
  );
  test(
    'server commit before timeout checks original identity without a second insert',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      r.google.loseResponse = true;
      final d = r.draft();
      final result = await r.controller.submit(d, r.intent(d));
      expect(result.state, CalendarCreationState.saved);
      expect(r.google.inserts, 1);
      expect(r.google.gets, 1);
      expect(r.google.events.keys.single, creationEventId(d.id));
    },
  );
  test(
    'absent uncertain operation requires explicit same-ID retry and rechecks first',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      r.google.omitCommit = true;
      final d = r.draft();
      final first = await r.controller.submit(d, r.intent(d));
      expect(first.state, CalendarCreationState.checking);
      expect(first.retryAllowed, true);
      final id = r.controller.journal!.operations[d.id]!.eventId;
      await r.controller.initialize();
      expect(r.google.inserts, 1); // Restart/restore is not a command.
      r.google.omitCommit = false;
      final second = await r.controller.submit(d, r.intent(d), retry: true);
      expect(second.state, CalendarCreationState.saved);
      expect(r.google.events.keys.single, id);
      expect(r.google.inserts, 2);
      expect(r.google.gets, 2);
    },
  );
  for (final fault in [
    'foreign',
    'changed title',
    'changed time',
    'changed colour',
    'deleted',
  ]) {
    test('$fault identity is never adopted, overwritten or replaced', () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft(), i = r.intent(r.draft());
      final event = <String, dynamic>{
        ...i.fields,
        'id': creationEventId(d.id),
        'calendarId': d.calendarId,
        'status': 'confirmed',
        'extendedProperties': {
          'private': {
            'pomaDayClockSchema': '1',
            'pomaDayClockOperation': d.id,
            'pomaDayClockPayloadHash': i.hash,
          },
        },
      };
      if (fault == 'foreign') {
        event['extendedProperties'] = {'private': {}};
      }
      if (fault == 'changed title') {
        event['summary'] = 'Someone else changed it';
      }
      if (fault == 'changed time') {
        event['start'] = {'dateTime': '2026-11-10T21:00:00+05:30'};
      }
      if (fault == 'changed colour') {
        event['colorId'] = '5';
      }
      if (fault == 'deleted') {
        event['status'] = 'cancelled';
      }
      r.google.events[creationEventId(d.id)] = event;
      final result = await r.controller.submit(d, r.intent(d));
      expect(result.state, CalendarCreationState.failed);
      expect(result.retryAllowed, false);
      expect(r.google.inserts, 1);
      expect(r.google.events.length, 1);
      expect(r.google.events.values.single, event);
      expect(
        r.google.requests.where(
          (q) => q.method == 'PATCH' || q.method == 'DELETE',
        ),
        isEmpty,
      );
    });
  }
  test(
    'shared/read-only destination and lost ownership reject before insert',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft(calendar: 'shared');
      expect(
        (await r.controller.submit(d, r.intent(d))).state,
        CalendarCreationState.failed,
      );
      r.google.destinationOwned = false;
      final owned = r.draft();
      await r.controller.submit(owned, r.intent(owned));
      expect(r.google.inserts, 0);
    },
  );
  test(
    'refresh failure after successful save remains Saved with Google link',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      r.google.failList = true;
      final d = r.draft();
      final result = await r.controller.submit(d, r.intent(d));
      expect(result.state, CalendarCreationState.saved);
      expect(result.message, contains('could not yet be refreshed'));
      expect(
        result.event!.eventUrl,
        startsWith('https://calendar.google.com/'),
      );
      expect(
        r.controller.journal!.operations[d.id]!.state,
        CalendarCreationState.saved,
      );
      expect(r.day.projection.sectors, isEmpty); // No optimistic sector.
      final op = r.controller.journal!.operations[d.id]!;
      r.google.failList = false;
      await r.reader.retry();
      expect(r.controller.describe(op), 'Saved to Google Calendar.');
      expect(r.google.inserts, 1);
    },
  );
  test(
    'hidden target offers explicit selection without changing other selected calendars',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft(calendar: 'owned-secondary');
      final result = await r.controller.submit(d, r.intent(d));
      expect(result.message, contains('calendar is hidden'));
      expect(r.reader.selected, {'synthetic-primary'});
      expect(r.reader.events, isEmpty);
      await r.controller.showCalendar(r.controller.journal!.operations[d.id]!);
      expect(r.reader.selected, {'synthetic-primary', 'owned-secondary'});
      expect(r.reader.events.length, 1);
      expect(
        r.controller.describe(r.controller.journal!.operations[d.id]!),
        'Saved to Google Calendar.',
      );
    },
  );
  test(
    'outside coverage is Saved with a link and no fabricated sector',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft();
      final m = r.intent(d).toJson()
        ..['startUtc'] = '2026-12-10T16:30:00Z'
        ..['endUtc'] = '2026-12-10T17:30:00Z';
      final i = CalendarCreateIntent.fromJson(m);
      final result = await r.controller.submit(d, i);
      expect(result.state, CalendarCreationState.saved);
      expect(result.message, contains('outside the retained'));
      expect(r.reader.events, isEmpty);
      expect(result.event!.eventUrl, isNotNull);
    },
  );
  test(
    'post-save refresh runs after a pre-insert refresh already in flight',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final gate = Completer<void>();
      r.google.listGate = gate;
      final refreshing = r.reader.refresh();
      await settleCalendar();
      final before = r.google.lists;
      final d = r.draft();
      final save = r.controller.submit(d, r.intent(d));
      await settleCalendar();
      expect(r.google.events.length, 1);
      gate.complete();
      await refreshing;
      await save;
      expect(r.google.lists, greaterThan(before));
      expect(r.reader.events.single.id, creationEventId(d.id));
    },
  );
  test(
    'lock during durable save invalidates authority before any insert',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final gate = Completer<void>();
      r.store.saveGate = gate;
      final d = r.draft();
      final save = r.controller.submit(d, r.intent(d));
      await settleCalendar();
      r.controller.setUnlocked(false);
      gate.complete();
      await save;
      expect(r.google.inserts, 0);
      r.store.saveGate = null;
      r.controller.setUnlocked(true);
      await r.controller.initialize();
      expect(r.google.inserts, 0);
    },
  );
  test(
    'timezone changes, invalid local resolution and expired starts send nothing',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft(), i = r.intent(r.draft());
      r.times.zoneFingerprint = 'changed';
      await r.controller.submit(d, i);
      r.times.zoneFingerprint = 'synthetic-IST';
      r.times.reject = true;
      await r.controller.submit(d, i);
      r.times.reject = false;
      r.clock.time = i.startUtc;
      await r.controller.submit(d, i);
      expect(r.google.inserts, 0);
    },
  );
  test(
    'kept raw draft survives invalid values and offline restore without sending',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft()
        ..startTime = 'not yet valid'
        ..title = 'Retained Unicode 日本語';
      expect(await r.controller.keepDraft(d), true);
      await r.controller.initialize();
      expect(r.controller.journal!.drafts[d.id]!.startTime, 'not yet valid');
      expect(r.google.inserts, 0);
      r.auth.onRefresh = () =>
          throw const CalendarConnectionFailure(CalendarFailureKind.network);
      await r.connection.refreshRejectedAccess('synthetic-access');
      expect(await r.controller.keepDraft(d), true);
      expect(
        (await r.controller.submit(d, r.intent(d))).state,
        CalendarCreationState.failed,
      );
      expect(r.google.inserts, 0);
    },
  );
  test(
    'explicit overnight dates are required and noon/midnight resolve exactly',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft()
        ..startTime = '11:00'
        ..endTime = '1:00'
        ..endPm = false;
      r.day.draft = d;
      await r.day.validateDraft();
      expect(r.day.errors['end'], isNotNull);
      d.endDate = '2026-11-11';
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(
        r.day.review!.endUtc.difference(r.day.review!.startUtc).inHours,
        2,
      );
      d.startTime = '12:00';
      d.startPm = true;
      d.endTime = '12:00';
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.review!.startUtc, DateTime.utc(2026, 11, 10, 6, 30));
      expect(r.day.review!.endUtc, DateTime.utc(2026, 11, 10, 18, 30));
    },
  );
  test(
    'creation disable persists independently and preserves focus/read capability',
    () async {
      final r = await creationRig(focus: true);
      addTearDown(r.dispose);
      await r.controller.disable();
      expect(r.connection.creationEnabled, false);
      expect(r.connection.focusWriteEnabled, true);
      expect(r.connection.operationsEnabled, true);
      expect(r.store.disabled, true);
      final reloaded = CalendarCredential.fromJson(r.disk.value!.toJson());
      expect(reloaded.creationReceipt!.enabled, false);
      expect(reloaded.focusReceipt!.enabled, true);
    },
  );
  test(
    'corrupt journal blocks creation without deleting or inferring an operation',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      r.store.document = '{broken';
      await r.controller.initialize();
      expect(r.controller.ready, false);
      expect(r.store.document, '{broken');
      final d = r.draft();
      await r.controller.submit(d, r.intent(d));
      expect(r.google.inserts, 0);
    },
  );
  test(
    'native creation adapter uses a separate journal namespace and carries leases',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      const channel = MethodChannel('creation-test');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'creationJournalOpen') {
              return {
                'generation': 7,
                'revision': 0,
                'document': null,
                'disabled': false,
              };
            }
            if (call.method == 'creationJournalSave') return 1;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final store = WindowsCalendarCreationStore(channel, r.connection);
      final opened = await store.open(r.connection.verifiedAccountKey!);
      final lease = await store.save(
        opened.lease,
        jsonEncode({'fictional': true}),
      );
      expect(lease.revision, 1);
      await store.setDisabled(true);
      await store.stop(purge: true);
      expect(calls.map((c) => c.method), [
        'creationJournalOpen',
        'creationJournalSave',
        'creationJournalDisable',
        'creationJournalStop',
      ]);
      expect((calls[1].arguments as Map)['generation'], 7);
      expect(
        (calls[1].arguments as Map)['credentialRevision'],
        r.connection.storageRevision,
      );
    },
  );
}
