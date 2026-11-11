import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/day_clock_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/calendar_event_creation.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:timezone/timezone.dart' as tz;

import 'calendar_creation_support.dart';
import 'calendar_read_test.dart' show settleCalendar;

Future<CalendarCreateOperation> saveExisting(CreationRig r) async {
  final d = r.draft();
  final result = await r.controller.submit(d, r.intent(d));
  expect(result.state, CalendarCreationState.saved);
  return r.controller.journal!.operations[d.id]!;
}

void main() {
  test(
    'a manual view change while saving prevents the later automatic reveal',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      await r.reader.select({});
      r.day.draft = r.draft();
      await r.day.validateDraft();
      final gate = Completer<void>();
      r.google.postGate = gate;
      final saving = r.day.submitReviewed();
      await settleCalendar();
      r.day.browse(CalendarDate(2026, 11, 12), DayClockHalf.am);
      gate.complete();
      expect((await saving).state, CalendarCreationState.saved);
      expect(r.day.date.toString(), '2026-11-12');
      expect(r.day.half, DayClockHalf.am);
      expect(r.reader.selected, isEmpty);
      expect(r.day.revealRevision, 0);
      expect(r.day.savedReceipt, isNotNull);
      expect(r.google.inserts, 1);
    },
  );
  test(
    'reveal includes the hidden destination, preserves another selection and never creates again',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      await r.reader.select({'owned-secondary'});
      final op = await saveExisting(r);
      r.day.browse(CalendarDate(2026, 11, 9), DayClockHalf.am);
      expect(await r.day.revealSaved(op), true);
      expect(r.reader.selected, {'owned-secondary', 'synthetic-primary'});
      expect(r.day.date.toString(), '2026-11-10');
      expect(r.day.half, DayClockHalf.pm);
      expect(r.day.projection.sectors, hasLength(1));
      expect(r.day.projection.agenda, hasLength(1));
      expect(r.day.selectedEvent!.id, op.eventId);
      expect(r.day.savedDisplayState(op), DayClockDisplayState.selected);
      expect(await r.day.revealSaved(op), true);
      expect(r.google.inserts, 1);
      expect(r.google.events, hasLength(1));
    },
  );

  test(
    'rapid repeated Show actions share one pending reconciliation',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      final gate = Completer<void>();
      r.google.listGate = gate;
      final first = r.day.revealSaved(op);
      final second = r.day.revealSaved(op);
      expect(identical(first, second), true);
      await settleCalendar();
      expect(r.day.savedDisplayState(op), DayClockDisplayState.refreshing);
      gate.complete();
      expect(await first, true);
      expect(r.day.revealRevision, 1);
      expect(r.google.inserts, 1);
    },
  );

  test(
    'Show waits for an older refresh and reads the actual moved start afterwards',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      final gate = Completer<void>();
      r.google.listGate = gate;
      final old = r.reader.refresh();
      await settleCalendar();
      final original = r.google.events[op.eventId]!;
      r.google.events[op.eventId] = {
        ...original,
        'start': {'dateTime': '2026-11-11T09:00:00+05:30'},
        'end': {'dateTime': '2026-11-11T10:00:00+05:30'},
      };
      final lists = r.google.lists;
      final revealing = r.day.revealSaved(op);
      gate.complete();
      await old;
      expect(await revealing, true);
      expect(r.google.lists, greaterThan(lists));
      expect(r.day.date.toString(), '2026-11-11');
      expect(r.day.half, DayClockHalf.am);
      expect(r.day.projection.sectors.single.startMinute, 540);
      expect(r.google.inserts, 1);
    },
  );

  test(
    'failed refresh after verified saving stays Saved and recovers through Show',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      await r.reader.select({});
      r.google.failList = true;
      r.day.draft = r.draft();
      await r.day.validateDraft();
      final result = await r.day.submitReviewed();
      final op = r.day.savedReceipt!;
      expect(result.state, CalendarCreationState.saved);
      expect(op.state, CalendarCreationState.saved);
      expect(r.day.savedDisplayState(op), DayClockDisplayState.refreshNeeded);
      expect(r.day.projection.sectors, isEmpty);
      expect(op.event!.eventUrl, isNotEmpty);
      r.google.failList = false;
      expect(await r.day.revealSaved(op), true);
      expect(r.day.savedDisplayState(op), DayClockDisplayState.selected);
      expect(r.day.projection.sectors, hasLength(1));
      expect(r.google.inserts, 1);
    },
  );

  test(
    'manual date selection while Show is pending supersedes the late view transition',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      final gate = Completer<void>();
      r.google.listGate = gate;
      final pending = r.day.revealSaved(op);
      await settleCalendar();
      r.day.browse(CalendarDate(2026, 11, 12), DayClockHalf.am);
      gate.complete();
      expect(await pending, false);
      expect(r.day.date.toString(), '2026-11-12');
      expect(r.day.half, DayClockHalf.am);
      expect(r.day.selectedIdentity, isNull);
    },
  );

  test(
    'manual calendar changes during Show are not replaced by its older union',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      final gate = Completer<void>();
      r.google.listGate = gate;
      final pending = r.day.revealSaved(op);
      await settleCalendar();
      await r.reader.select({'owned-secondary'});
      gate.complete();
      expect(await pending, false);
      expect(r.reader.selected, {'owned-secondary'});
      expect(r.day.selectedIdentity, isNull);
      expect(r.google.inserts, 1);
    },
  );

  test(
    'account change during Show cannot carry selection, receipt or navigation into another account',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      final gate = Completer<void>();
      r.google.listGate = gate;
      final pending = r.day.revealSaved(op);
      await settleCalendar();
      await r.connection.disconnect();
      r.auth.onAuthorize = () async => CalendarAuthorization(
        accountId: 'other-fictional-account',
        accessToken: 'other-access',
        refreshToken: 'other-refresh',
        scopes: calendarReadScopes,
        expiresAt: r.clock.time.add(const Duration(days: 2)),
      );
      await r.connection.connect();
      await settleCalendar();
      gate.complete();
      expect(await pending, false);
      expect(await r.day.revealSaved(op), false);
      expect(r.day.savedReceipt, isNull);
      expect(r.reader.selected, isEmpty);
      expect(r.day.selectedIdentity, isNull);
      expect(r.google.inserts, 1);
    },
  );

  test('lock during Show prevents a delayed selection', () async {
    final r = await creationRig();
    addTearDown(r.dispose);
    final op = await saveExisting(r);
    final gate = Completer<void>();
    r.google.listGate = gate;
    final pending = r.day.revealSaved(op);
    await settleCalendar();
    r.day.setUnlocked(false);
    gate.complete();
    expect(await pending, false);
    expect(r.day.selectedIdentity, isNull);
    expect(r.day.savedReceipt, isNull);
  });

  test(
    'removed events and inaccessible calendars never fabricate a sector',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      r.google.events.clear();
      expect(await r.day.revealSaved(op), false);
      expect(r.day.savedDisplayState(op), DayClockDisplayState.missing);
      expect(r.day.projection.sectors, isEmpty);
      // The refreshed catalog, rather than a persisted draft destination, owns access.
      r.google.missingCatalogCalendar = 'synthetic-primary';
      expect(await r.day.revealSaved(op), false);
      expect(r.day.savedDisplayState(op), DayClockDisplayState.inaccessible);
      expect(r.day.projection.sectors, isEmpty);
      expect(r.google.inserts, 1);
    },
  );

  test(
    'outside-window saving retains Saved and its link without changing the browsed date',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      r.day.draft = r.draft()
        ..startDate = '2026-12-01'
        ..endDate = '2026-12-01';
      await r.day.validateDraft();
      expect((await r.day.submitReviewed()).state, CalendarCreationState.saved);
      final op = r.day.savedReceipt!;
      expect(r.day.savedDisplayState(op), DayClockDisplayState.outsideCoverage);
      expect(r.day.projection.sectors, isEmpty);
      expect(r.day.date.toString(), '2026-11-10');
      expect(op.event!.eventUrl, isNotEmpty);
      expect(r.google.inserts, 1);
    },
  );

  test(
    'completed reveal never overrides later browsing, calendar choices or minute ticks',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      expect(await r.day.revealSaved(op), true);
      final revision = r.day.revealRevision;
      r.day.browse(CalendarDate(2026, 11, 12), DayClockHalf.am);
      await r.reader.select({'owned-secondary'});
      await r.scheduler.advance(const Duration(minutes: 6));
      expect(r.day.date.toString(), '2026-11-12');
      expect(r.day.half, DayClockHalf.am);
      expect(r.reader.selected, {'owned-secondary'});
      expect(r.day.revealRevision, revision);
      expect(r.day.selectedIdentity, isNull);
      // Restoring a journal produces a receipt, never an automatic view transition.
      await r.controller.initialize();
      expect(r.day.date.toString(), '2026-11-12');
      expect(r.day.savedReceipt!.eventId, op.eventId);
      expect(r.google.inserts, 1);
    },
  );

  for (final spec in [
    (
      '2026-11-10T12:00:00+05:30',
      '2026-11-10T13:00:00+05:30',
      '2026-11-10',
      DayClockHalf.pm,
      0.0,
    ),
    (
      '2026-11-11T00:00:00+05:30',
      '2026-11-11T01:00:00+05:30',
      '2026-11-11',
      DayClockHalf.am,
      0.0,
    ),
    (
      '2026-11-10T23:00:00+05:30',
      '2026-11-11T01:00:00+05:30',
      '2026-11-10',
      DayClockHalf.pm,
      660.0,
    ),
  ]) {
    test(
      'reveal resolves noon, midnight or overnight from actual local start ${spec.$1}',
      () async {
        final r = await creationRig();
        addTearDown(r.dispose);
        final op = await saveExisting(r);
        r.google.events[op.eventId] = {
          ...r.google.events[op.eventId]!,
          'start': {'dateTime': spec.$1},
          'end': {'dateTime': spec.$2},
        };
        expect(await r.day.revealSaved(op), true);
        expect(r.day.date.toString(), spec.$3);
        expect(r.day.half, spec.$4);
        expect(r.day.projection.sectors.single.startMinute, spec.$5);
      },
    );
  }

  test(
    'timezone change resolves the current device-local start instead of frozen creation offsets',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final op = await saveExisting(r);
      r.clock.location = tz.getLocation('America/Los_Angeles');
      r.day.timeContextChanged();
      await settleCalendar();
      expect(await r.day.revealSaved(op), true);
      expect(r.day.date.toString(), '2026-11-10');
      expect(r.day.half, DayClockHalf.am);
      expect(r.day.projection.sectors.single.startMinute, 510);
      expect(r.google.inserts, 1);
    },
  );

  test(
    'view preference is backward compatible and does not alter the reviewed Google payload',
    () async {
      final r = await creationRig();
      addTearDown(r.dispose);
      final d = r.draft();
      final hash = r.intent(d).hash;
      final old = d.toJson()..remove('showOnDayClock');
      expect(CalendarEventDraft.fromJson(old).showOnDayClock, true);
      d.showOnDayClock = false;
      expect(CalendarEventDraft.fromJson(d.toJson()).showOnDayClock, false);
      expect(r.intent(d).hash, hash);
      r.day.draft = d;
      r.day.browse(CalendarDate(2026, 11, 9), DayClockHalf.am);
      await r.day.validateDraft();
      expect((await r.day.submitReviewed()).state, CalendarCreationState.saved);
      expect(r.day.date.toString(), '2026-11-09');
      expect(r.day.half, DayClockHalf.am);
      expect(r.day.revealRevision, 0);
      expect(r.day.savedReceipt, isNotNull);
    },
  );
}
