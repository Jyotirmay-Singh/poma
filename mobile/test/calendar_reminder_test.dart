import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/calendar_reminder_controller.dart';
import 'package:poma/application/calendar_reminder_ports.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/domain/calendar_reminders.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart' show PomaApp;
import 'calendar_read_test.dart' as f;
import 'calendar_agenda_test.dart' show meeting;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

class ReminderAdapter
    implements CalendarReminderStore, CalendarReminderPlatform {
  final documents = <String, Map<String, Object?>>{};
  final shown = <String>[];
  final queue = <Map<String, Object?>>[];
  Set<String> tokens = {};
  int generation = 0, writes = 0, arms = 0;
  DateTime? armed;
  bool fail = false;
  Completer<void>? gate;
  String status = 'ready';
  @override
  Future<Map<String, Object?>?> read(CalendarCacheLease lease) async =>
      documents[lease.accountKey];
  @override
  Future<void> write(
    CalendarCacheLease lease,
    Map<String, Object?> document,
  ) async {
    await gate?.future;
    if (fail) throw StateError('synthetic disk failure');
    writes++;
    documents[lease.accountKey] = Map<String, Object?>.from(
      jsonDecode(jsonEncode(document)) as Map,
    );
  }

  @override
  Future<String> availability() async => status;
  @override
  Future<void> replace(int value, Set<String> next) async {
    if (value < generation) return;
    generation = value;
    tokens = next;
    armed = null;
  }

  @override
  Future<void> arm(int value, DateTime? deadline) async {
    if (value == generation) {
      armed = deadline;
      arms++;
    }
  }

  @override
  Future<void> show(int value, String token, DateTime expires) async {
    if (value == generation && tokens.contains(token)) shown.add(token);
  }

  @override
  Future<List<Map<String, Object?>>> responses() async => List.of(queue);
  @override
  Future<void> acknowledge(String token, String action) async =>
      queue.removeWhere((e) => e['token'] == token && e['action'] == action);
}

Future<void> drain(CalendarReminderController c) async {
  await f.settleCalendar();
  await c.settled;
  await f.settleCalendar();
  await c.settled;
}

void main() {
  test(
    'defaults are off, five minute lead, no implicit calendar inclusion',
    () {
      const p = CalendarReminderPreferences();
      expect(p.enabled, false);
      expect(p.leadMinutes, 5);
      expect(p.calendars, isEmpty);
      expect(
        () => CalendarReminderPreferences.fromJson({
          'enabled': true,
          'leadMinutes': 2,
          'calendars': [],
        }),
        throwsFormatException,
      );
    },
  );
  Future<(f.CalendarRig, ReminderAdapter, CalendarReminderController)> setup({
    int minutes = 6,
  }) async {
    final r = await f.rig();
    final now = r.clock.nowUtc();
    r.provider.items[f.work.id] = [
      meeting(
        'one',
        now.add(Duration(minutes: minutes)),
        now.add(Duration(minutes: minutes + 30)),
      ),
    ];
    await r.reader.select({f.work.id});
    final adapter = ReminderAdapter();
    final controller = CalendarReminderController(
      reader: r.reader,
      store: adapter,
      platform: adapter,
      openAgenda: () async {},
    )..unlocked = true;
    addTearDown(controller.dispose);
    await drain(controller);
    return (r, adapter, controller);
  }

  Future<void> enable(CalendarReminderController c) async {
    await c.update(
      const CalendarReminderPreferences(
        enabled: true,
        calendars: {'work/@example'},
      ),
    );
    await drain(c);
  }

  test(
    'one-shot delivery is post-receipt, generic, duplicate-safe across restart',
    () async {
      final (r, a, c) = await setup();
      expect(a.armed, isNull);
      await enable(c);
      final generation = a.generation;
      expect(a.armed, r.clock.nowUtc().add(const Duration(minutes: 1)));
      r.clock.time = a.armed!;
      await c.deadline(generation);
      await c.deadline(generation);
      expect(a.shown, hasLength(1));
      expect(jsonEncode(a.documents), isNot(contains('Fictional design')));
      expect((a.documents.values.single['attempts'] as Map), hasLength(1));
      c.dispose();
      final reopened = CalendarReminderController(
        reader: r.reader,
        store: a,
        platform: a,
        openAgenda: () async {},
      );
      addTearDown(reopened.dispose);
      await drain(reopened);
      expect(reopened.preferences.enabled, true);
      expect(a.armed, isNull);
      expect(a.shown, hasLength(1));
    },
  );
  test(
    'enable, lead changes and wake never produce missed reminders',
    () async {
      final (r, a, c) = await setup(minutes: 4);
      await enable(c);
      expect(a.armed, isNull);
      await c.update(c.preferences.copyWith(leadMinutes: 1));
      await drain(c);
      final old = a.generation;
      expect(a.armed, r.clock.nowUtc().add(const Duration(minutes: 3)));
      c.lifecycle(suspended: true);
      await drain(c);
      r.clock.time = r.clock.time.add(const Duration(minutes: 3, seconds: 10));
      c.lifecycle();
      await drain(c);
      await c.deadline(old);
      await c.deadline(a.generation);
      expect(a.armed, isNull);
      expect(a.shown, isEmpty);
    },
  );
  test(
    'move, cancellation, deselection and disconnect revoke old callbacks',
    () async {
      final (r, a, c) = await setup();
      await enable(c);
      final old = a.generation;
      final now = r.clock.nowUtc();
      r.provider.items[f.work.id] = [
        meeting(
          'one',
          now.add(const Duration(minutes: 8)),
          now.add(const Duration(hours: 1)),
        ),
      ];
      await r.reader.refresh();
      await drain(c);
      await c.deadline(old);
      expect(a.shown, isEmpty);
      expect(a.armed, now.add(const Duration(minutes: 3)));
      r.provider.items[f.work.id] = [];
      await r.reader.refresh();
      await drain(c);
      expect(a.armed, isNull);
      await r.reader.select({});
      await drain(c);
      expect(c.preferences.calendars, isEmpty);
      await r.connection.disconnect();
      await drain(c);
      expect(a.tokens, isEmpty);
      expect(c.preferences.enabled, false);
    },
  );
  test(
    'source failure and stale cache suppress reminders without timer IO',
    () async {
      final (r, a, c) = await setup();
      await enable(c);
      final writes = a.writes, reads = r.provider.lists;
      await drain(c);
      expect(a.writes, writes);
      expect(r.provider.lists, reads);
      r.clock.time = r.clock.time.add(const Duration(minutes: 6));
      c.lifecycle();
      await drain(c);
      expect(a.armed, isNull);
      expect(a.tokens, isEmpty);
    },
  );
  test(
    'failure before receipt stops presentation and exposes recovery',
    () async {
      final (r, a, c) = await setup();
      await enable(c);
      r.clock.time = a.armed!;
      a.fail = true;
      await c.deadline(a.generation);
      expect(a.shown, isEmpty);
      expect(c.error, isNotNull);
      expect(a.tokens, isEmpty);
    },
  );
  test(
    'Retry persists the latest enable and disable choices after failed saves',
    () async {
      final (_, a, c) = await setup();
      a.fail = true;
      await enable(c);
      expect(c.error, isNotNull);
      expect(a.armed, isNull);
      a.fail = false;
      await c.retry();
      await drain(c);
      expect(c.preferences.enabled, true);
      expect(
        (a.documents.values.single['preferences'] as Map)['enabled'],
        true,
      );
      expect(a.armed, isNotNull);
      a.fail = true;
      await c.update(c.preferences.copyWith(enabled: false));
      await drain(c);
      expect(c.error, isNotNull);
      expect(a.armed, isNull);
      a.fail = false;
      await c.retry();
      await drain(c);
      expect(c.preferences.enabled, false);
      expect(
        (a.documents.values.single['preferences'] as Map)['enabled'],
        false,
      );
      expect(a.armed, isNull);
    },
  );
  test('late receipt completion after disconnect cannot present', () async {
    final (r, a, c) = await setup();
    await enable(c);
    r.clock.time = a.armed!;
    a.gate = Completer<void>();
    final pending = c.deadline(a.generation);
    await f.settleCalendar();
    await r.connection.disconnect();
    a.gate!.complete();
    await pending;
    await drain(c);
    expect(a.shown, isEmpty);
    expect(a.tokens, isEmpty);
  });
  test(
    'repeated, locked and stale actions are acknowledged without side effects',
    () async {
      final (r, a, initial) = await setup();
      initial.dispose();
      var opens = 0;
      final c = CalendarReminderController(
        reader: r.reader,
        store: a,
        platform: a,
        openAgenda: () async {
          opens++;
        },
      )..unlocked = true;
      addTearDown(c.dispose);
      await drain(c);
      await enable(c);
      r.clock.time = a.armed!;
      await c.deadline(a.generation);
      final response = {
        'token': a.shown.single,
        'action': 'open',
        'generation': a.generation,
      };
      a.queue.addAll([response, response]);
      await c.handleResponses();
      expect(opens, 1);
      c.unlocked = false;
      a.queue.add(response);
      await c.handleResponses();
      expect(opens, 1);
      c.unlocked = true;
      await c.update(c.preferences.copyWith(leadMinutes: 1));
      await drain(c);
      a.queue.add(response);
      await c.handleResponses();
      expect(opens, 1);
      expect(a.queue, isEmpty);
    },
  );
  test(
    'declined, cancelled, all-day and unincluded calendars never arm',
    () async {
      final (r, a, c) = await setup();
      final now = r.clock.nowUtc();
      r.provider.items[f.work.id] = [
        meeting(
          'cancelled',
          now.add(const Duration(minutes: 6)),
          now.add(const Duration(hours: 1)),
          status: 'cancelled',
        ),
        meeting(
          'declined',
          now.add(const Duration(minutes: 6)),
          now.add(const Duration(hours: 1)),
          response: 'declined',
        ),
        CalendarEvent(
          id: 'day',
          calendarId: f.work.id,
          title: 'Private day',
          status: 'confirmed',
          selfResponse: 'accepted',
          startDate: r.reader.window.first,
          endDate: r.reader.window.first.plusDays(1),
        ),
      ];
      await r.reader.refresh();
      await enable(c);
      expect(a.armed, isNull);
    },
  );

  test(
    'shared focus path confirms full duration, cancels, and revalidates changing conflicts',
    () async {
      final (r, _, c) = await setup();
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final desktop = DesktopController(
        app,
        FakeShell(),
        const DesktopEnvironment(
          dataDirectory: 'test',
          version: 'test',
          packaged: true,
          sessionState: 'unlocked',
        ),
        calendarData: r.reader,
      );
      addTearDown(() {
        desktop.dispose();
        app.dispose();
      });
      var prompts = 0;
      desktop.confirmFocusConflict = (_) async {
        prompts++;
        return false;
      };
      await desktop.requestTimerAction(
        action: 'start',
        revision: app.timer.revision,
        runId: null,
      );
      expect(prompts, 1);
      expect(app.timer.status, RunStatus.ready);
      desktop.confirmFocusConflict = (_) async {
        prompts++;
        if (prompts == 2) {
          final now = r.clock.nowUtc();
          r.provider.items[f.work.id] = [
            meeting(
              'changed',
              now.add(const Duration(minutes: 10)),
              now.add(const Duration(hours: 1)),
            ),
          ];
          await r.reader.refresh();
          await drain(c);
        }
        return true;
      };
      await desktop.requestTimerAction(
        action: 'start',
        revision: app.timer.revision,
        runId: null,
      );
      expect(prompts, 3);
      expect(app.timer.status, RunStatus.running);
      expect(app.timer.totalSeconds, 1500);
      expect(app.timer.snapshot().taskTitle, isNull);
    },
  );
  test(
    'an attempted occurrence moved later gets one new future reminder',
    () async {
      final (r, a, c) = await setup();
      await enable(c);
      r.clock.time = a.armed!;
      await c.deadline(a.generation);
      expect(a.shown, hasLength(1));
      final now = r.clock.nowUtc();
      r.provider.items[f.work.id] = [
        meeting(
          'one',
          now.add(const Duration(minutes: 7)),
          now.add(const Duration(hours: 1)),
        ),
      ];
      await r.reader.refresh();
      await drain(c);
      expect(a.armed, now.add(const Duration(minutes: 2)));
      r.clock.time = a.armed!;
      await c.deadline(a.generation);
      await c.deadline(a.generation);
      expect(a.shown, hasLength(2));
      await c.update(c.preferences.copyWith(leadMinutes: 1));
      await drain(c);
      expect(a.armed, isNull);
    },
  );
  test(
    'permission failure cancels a fresh source and denied capability does not arm',
    () async {
      final (r, a, c) = await setup();
      await enable(c);
      r.provider.errors[f.work.id] = const CalendarReadFailure(
        CalendarReadFailureKind.forbidden,
      );
      await r.reader.refresh();
      await drain(c);
      expect(a.armed, isNull);
      expect(a.tokens, isEmpty);
      r.provider.errors.clear();
      await r.reader.refresh(manual: true);
      await drain(c);
      expect(a.armed, isNotNull);
      a.status = 'denied';
      c.lifecycle();
      await drain(c);
      expect(c.availability, 'denied');
      expect(a.armed, isNull);
    },
  );
  test(
    'touching focus endpoint is not overlap; Resume and strict controls retain policy',
    () async {
      final (r, _, _) = await setup();
      final now = r.clock.nowUtc();
      r.provider.items[f.work.id] = [
        meeting(
          'boundary',
          now.add(const Duration(minutes: 25)),
          now.add(const Duration(hours: 1)),
        ),
      ];
      await r.reader.refresh();
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final desktop = DesktopController(
        app,
        FakeShell(),
        const DesktopEnvironment(
          dataDirectory: 'test',
          version: 'test',
          packaged: true,
          sessionState: 'unlocked',
        ),
        calendarData: r.reader,
      );
      addTearDown(() {
        desktop.dispose();
        app.dispose();
      });
      var prompts = 0;
      desktop.confirmFocusConflict = (_) async {
        prompts++;
        return false;
      };
      await desktop.requestTimerAction(
        action: 'start',
        revision: app.timer.revision,
        runId: null,
      );
      expect(prompts, 0);
      expect(app.timer.status, RunStatus.running);
      final run = app.timer.runId;
      await desktop.requestTimerAction(
        action: 'pause',
        revision: app.timer.revision,
        runId: run,
      );
      await desktop.requestTimerAction(
        action: 'resume',
        revision: app.timer.revision,
        runId: run,
      );
      expect(prompts, 0);
      expect(app.timer.runId, run);
      await app.updateSettings(app.settings.copyWith(strictMode: true));
      for (final action in ['pause', 'reset', 'skip']) {
        await desktop.requestTimerAction(
          action: action,
          revision: app.timer.revision,
          runId: run,
        );
      }
      expect(app.timer.status, RunStatus.running);
      expect(app.timer.runId, run);
      expect(app.sessions, isEmpty);
    },
  );
  testWidgets(
    'main Start opens the shared warning and lock removes private dialog text',
    (tester) async {
      final (r, _, _) = (await tester.runAsync(() => setup()))!;
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final desktop = DesktopController(
        app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'test',
          version: 'test',
          packaged: true,
          sessionState: 'unlocked',
        ),
        calendarData: r.reader,
      );
      await desktop.initialize();
      await tester.pumpWidget(PomaApp(controller: app, desktop: desktop));
      await tester.pumpAndSettle();
      expect(r.reader.events, hasLength(1));
      await tester.tap(find.byKey(const Key('timer-toggle')));
      await tester.pumpAndSettle();
      expect(desktop.error, isNull);
      expect(find.text('Focus overlaps a meeting'), findsOneWidget);
      expect(find.textContaining('Fictional design'), findsOneWidget);
      await shell.onEvent!('sessionState', {'state': 'locked'});
      await tester.pumpAndSettle();
      expect(find.textContaining('Fictional design'), findsNothing);
      expect(app.timer.status, RunStatus.ready);
      await tester.pumpWidget(const SizedBox());
      desktop.dispose();
      app.dispose();
    },
  );
  test(
    'lock and timer changes while conflict dialog is pending cancel Start',
    () async {
      final (r, _, _) = await setup();
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final desktop = DesktopController(
        app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'test',
          version: 'test',
          packaged: true,
          sessionState: 'unlocked',
        ),
        calendarData: r.reader,
      );
      await desktop.initialize();
      addTearDown(() {
        desktop.dispose();
        app.dispose();
      });
      final pending = Completer<bool>();
      desktop.confirmFocusConflict = (_) => pending.future;
      final starting = desktop.requestTimerAction(
        action: 'start',
        revision: app.timer.revision,
        runId: null,
      );
      await f.settleCalendar();
      await shell.send('sessionState', {'state': 'locked'});
      pending.complete(true);
      await starting;
      expect(app.timer.status, RunStatus.ready);
    },
  );
}
