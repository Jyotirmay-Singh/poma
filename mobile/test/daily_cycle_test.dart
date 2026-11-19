import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'package:poma/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'alert_support.dart';
import 'support.dart';

const _settings = TimerSettings(rounds: 3);
const _readyCycle = TimerSnapshot(
  phase: FocusPhase.focus,
  status: RunStatus.ready,
  totalSeconds: 1500,
  remainingMicros: 1500000000,
  completedRounds: 2,
  cycleLocalDate: '2026-10-20',
);

DateTime _utc(DateTime value) => value;

Future<AppController> _open(
  LocalRepository repository,
  FakeClock clock, {
  FakeAlerts? alerts,
}) => AppController.create(
  repository,
  clock: clock,
  alerts: alerts,
  toLocal: _utc,
  dayRange: (date) => DayRange(
    date,
    DateTime.utc(date.year, date.month, date.day),
    DateTime.utc(date.year, date.month, date.day + 1),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    sqfliteFfiInit();
    tz_data.initializeTimeZones();
  });

  test('cycle date round-trips and older snapshots remain readable', () {
    expect(
      TimerSnapshot.fromJson(_readyCycle.toJson()).cycleLocalDate,
      '2026-10-20',
    );
    final legacy = _readyCycle.toJson()..remove('cycleLocalDate');
    expect(TimerSnapshot.fromJson(legacy).cycleLocalDate, isNull);
    expect(
      TimerSnapshot.fromJson({
        ...legacy,
        'cycleLocalDate': '2028-02-29',
      }).cycleLocalDate,
      '2028-02-29',
    );
  });

  for (final invalid in [
    '2026-02-29',
    '2026-02-30',
    '2026-00-01',
    '2026-13-01',
    '2026-1-01',
    '2026-10-20T00:00:00Z',
    '',
    42,
  ]) {
    test('invalid cycle date $invalid fails validation', () {
      expect(
        () => TimerSnapshot.fromJson({
          ..._readyCycle.toJson(),
          'cycleLocalDate': invalid,
        }),
        throwsFormatException,
      );
    });
  }

  group('daily timer state', () {
    late FakeClock clock;
    late TimerEngine timer;

    setUp(() {
      clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
      timer = TimerEngine(
        settings: _settings,
        now: clock.reading,
        restored: _readyCycle,
        toLocal: _utc,
      );
    });

    test('same-day reconciliation keeps the cycle and needs no save', () {
      final original = timer.snapshot().toJson();
      clock.advance(const Duration(minutes: 5));
      expect(timer.reconcile(clock.reading).changed, isFalse);
      expect(timer.snapshot().toJson(), original);
    });

    for (final phase in FocusPhase.values) {
      test('ready $phase resets to the first Focus at midnight', () {
        timer.apply(
          TimerAction.selectPhase,
          clock.reading,
          selectedPhase: phase,
        );
        final revision = timer.revision;
        clock.advance(const Duration(minutes: 10));
        final transition = timer.reconcile(clock.reading);
        expect(transition.dayReset, isTrue);
        expect(transition.changed, isTrue);
        expect(transition.completion, isNull);
        expect(timer.revision, greaterThan(revision));
        expect(timer.completedRounds, 0);
        expect(timer.phase, FocusPhase.focus);
        expect(timer.status, RunStatus.ready);
        expect(timer.remainingSeconds, 1500);
        expect(timer.snapshot().cycleLocalDate, '2026-10-21');
        expect(timer.reconcile(clock.reading).changed, isFalse);
      });

      test('paused $phase is discarded on the next date', () {
        timer.apply(
          TimerAction.selectPhase,
          clock.reading,
          selectedPhase: phase,
        );
        timer.apply(
          TimerAction.start,
          clock.reading,
          task: const FocusTask(id: 'task', title: 'Captured task'),
        );
        clock.advance(const Duration(minutes: 1));
        timer.apply(TimerAction.pause, clock.reading);
        clock.advance(const Duration(days: 1));
        final transition = timer.reconcile(clock.reading);
        expect(transition.dayReset, isTrue);
        expect(transition.completedPhase, isFalse);
        expect(transition.completion, isNull);
        expect(timer.phase, FocusPhase.focus);
        expect(timer.status, RunStatus.ready);
        expect(timer.completedRounds, 0);
        expect(timer.remainingSeconds, 1500);
        expect(timer.runId, isNull);
        expect(timer.snapshot().taskId, isNull);
      });
    }

    test('overnight strict Focus finishes as the new day first round', () {
      timer.apply(
        TimerAction.updateSettings,
        clock.reading,
        nextSettings: _settings.copyWith(strictMode: true),
      );
      timer.apply(
        TimerAction.start,
        clock.reading,
        task: const FocusTask(id: 'task', title: 'Captured task'),
      );
      final running = timer.snapshot();
      clock.advance(const Duration(minutes: 10));
      final midnight = timer.reconcile(clock.reading);
      expect(midnight.changed, isTrue);
      expect(midnight.completedPhase, isFalse);
      expect(timer.status, RunStatus.running);
      expect(timer.remainingSeconds, 900);
      expect(timer.completedRounds, 0);
      expect(timer.runId, running.runId);
      expect(timer.snapshot().deadline, running.deadline);
      expect(
        timer.snapshot().elapsedDeadlineMicros,
        running.elapsedDeadlineMicros,
      );
      expect(timer.snapshot().taskTitle, 'Captured task');
      expect(
        timer.apply(TimerAction.pause, clock.reading).outcome,
        TimerCommandOutcome.blocked,
      );
      clock.advance(const Duration(minutes: 15));
      final completion = timer.reconcile(clock.reading).completion!;
      expect(completion.id, running.runId);
      expect(completion.endedAt, running.deadline);
      expect(completion.focusSeconds, 1500);
      expect(completion.taskTitle, 'Captured task');
      expect(timer.completedRounds, 1);
      expect(timer.phase, FocusPhase.shortBreak);
      expect(timer.status, RunStatus.ready);
      expect(timer.reconcile(clock.reading).completion, isNull);
    });

    for (final phase in [FocusPhase.shortBreak, FocusPhase.longBreak]) {
      test('overnight running $phase finishes before the first Focus', () {
        clock.advance(const Duration(minutes: 8));
        timer.apply(
          TimerAction.selectPhase,
          clock.reading,
          selectedPhase: phase,
        );
        timer.apply(TimerAction.start, clock.reading);
        final running = timer.snapshot();
        clock.advance(const Duration(minutes: 2));
        expect(timer.reconcile(clock.reading).completedPhase, isFalse);
        expect(timer.phase, phase);
        expect(timer.runId, running.runId);
        expect(timer.completedRounds, 0);
        clock.advance(Duration(seconds: timer.remainingSeconds));
        final completed = timer.reconcile(clock.reading);
        expect(completed.completedPhase, isTrue);
        expect(completed.completion, isNull);
        expect(timer.phase, FocusPhase.focus);
        expect(timer.status, RunStatus.ready);
        expect(timer.completedRounds, 0);
      });
    }

    test(
      'completion recovered days later is recorded before resetting today',
      () {
        timer.apply(TimerAction.start, clock.reading);
        final running = timer.snapshot();
        clock.advance(const Duration(days: 3));
        final result = timer.reconcile(clock.reading);
        expect(result.completion!.id, running.runId);
        expect(result.completion!.endedAt, running.deadline);
        expect(result.dayReset, isTrue);
        expect(timer.phase, FocusPhase.focus);
        expect(timer.status, RunStatus.ready);
        expect(timer.completedRounds, 0);
        expect(timer.snapshot().cycleLocalDate, '2026-10-23');
        expect(timer.reconcile(clock.reading).changed, isFalse);
      },
    );

    test(
      'an overnight completion recovered on its end date earns round one',
      () {
        timer.apply(TimerAction.start, clock.reading);
        clock.advance(const Duration(minutes: 30));
        final result = timer.reconcile(clock.reading);
        expect(result.completion, isNotNull);
        expect(result.dayReset, isFalse);
        expect(timer.completedRounds, 1);
        expect(timer.phase, FocusPhase.shortBreak);
        expect(timer.snapshot().cycleLocalDate, '2026-10-21');
      },
    );

    test('a delayed Resume cannot operate on a discarded paused run', () {
      timer.apply(TimerAction.start, clock.reading);
      timer.apply(TimerAction.pause, clock.reading);
      final runId = timer.runId;
      final revision = timer.revision;
      clock.advance(const Duration(days: 1));
      final result = timer.apply(
        TimerAction.resume,
        clock.reading,
        expectedRunId: runId,
        expectedRevision: revision,
      );
      expect(result.outcome, TimerCommandOutcome.stale);
      expect(result.dayReset, isTrue);
      expect(timer.status, RunStatus.ready);
      expect(timer.runId, isNull);
      expect(timer.completedRounds, 0);
    });

    for (final status in RunStatus.values) {
      test('undated $status save adopts the daily rule once', () {
        if (status != RunStatus.ready) {
          timer.apply(TimerAction.start, clock.reading);
        }
        if (status == RunStatus.paused) {
          timer.apply(TimerAction.pause, clock.reading);
        }
        final original = timer.snapshot();
        final legacy = original.toJson()..remove('cycleLocalDate');
        final restored = TimerEngine(
          settings: _settings,
          now: clock.reading,
          restored: TimerSnapshot.fromJson(legacy),
          toLocal: _utc,
        );
        expect(restored.reconcile(clock.reading).changed, isTrue);
        expect(restored.completedRounds, 0);
        expect(restored.snapshot().cycleLocalDate, '2026-10-20');
        expect(restored.reconcile(clock.reading).changed, isFalse);
        if (status == RunStatus.running) {
          expect(restored.status, RunStatus.running);
          expect(restored.runId, original.runId);
          expect(restored.snapshot().deadline, original.deadline);
          expect(restored.remainingMicros, original.remainingMicros);
        } else {
          expect(restored.status, RunStatus.ready);
          expect(restored.phase, FocusPhase.focus);
          expect(restored.runId, isNull);
        }
      });
    }

    test('full data reset initializes the current local cycle date', () {
      clock.advance(const Duration(days: 2));
      timer.deleteLocalData(clock.reading);
      expect(timer.snapshot().cycleLocalDate, '2026-10-22');
      expect(timer.reconcile(clock.reading).changed, isFalse);
    });
  });

  for (final midnight in [
    DateTime.utc(2026, 10, 21),
    DateTime.utc(2026, 11),
    DateTime.utc(2027),
    DateTime.utc(2028, 2, 29),
    DateTime.utc(2028, 3),
  ]) {
    test('calendar boundary $midnight resets exactly once', () {
      final clock = FakeClock(midnight.subtract(const Duration(minutes: 1)));
      final timer = TimerEngine(
        settings: _settings,
        now: clock.reading,
        restored: TimerSnapshot.fromJson({
          ..._readyCycle.toJson(),
          'cycleLocalDate': clock.utcNow.toIso8601String().substring(0, 10),
        }),
        toLocal: _utc,
      );
      clock.advance(const Duration(minutes: 1));
      expect(timer.reconcile(clock.reading).dayReset, isTrue);
      expect(timer.completedRounds, 0);
      expect(timer.reconcile(clock.reading).changed, isFalse);
    });
  }

  test('local midnight resets while the UTC date stays the same', () {
    final clock = FakeClock(DateTime.utc(2026, 10, 20, 18, 29));
    final timer = TimerEngine(
      settings: _settings,
      now: clock.reading,
      restored: _readyCycle,
      toLocal: (value) => value.add(const Duration(hours: 5, minutes: 30)),
    );
    clock.advance(const Duration(minutes: 1));
    expect(timer.reconcile(clock.reading).dayReset, isTrue);
    expect(timer.snapshot().cycleLocalDate, '2026-10-21');
    expect(clock.utcNow.day, 20);
    expect(timer.completedRounds, 0);
  });

  test('UTC midnight within the same local day retains cycle progress', () {
    final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 59));
    final timer = TimerEngine(
      settings: _settings,
      now: clock.reading,
      restored: TimerSnapshot.fromJson({
        ..._readyCycle.toJson(),
        'cycleLocalDate': '2026-10-21',
      }),
      toLocal: (value) => value.add(const Duration(hours: 5, minutes: 30)),
    );
    clock.advance(const Duration(minutes: 1));
    expect(timer.reconcile(clock.reading).changed, isFalse);
    expect(timer.completedRounds, 2);
  });

  test('PC timezone and backward date changes reset the local cycle', () {
    var offset = Duration.zero;
    final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
    final timer = TimerEngine(
      settings: _settings,
      now: clock.reading,
      restored: _readyCycle,
      toLocal: (value) => value.add(offset),
    );
    offset = const Duration(hours: 1);
    expect(timer.reconcile(clock.reading).dayReset, isTrue);
    expect(timer.snapshot().cycleLocalDate, '2026-10-21');
    expect(timer.reconcile(clock.reading).changed, isFalse);
    clock.utcNow = clock.utcNow.subtract(const Duration(days: 1));
    expect(timer.reconcile(clock.reading).dayReset, isTrue);
    expect(timer.snapshot().cycleLocalDate, '2026-10-20');
  });

  for (final boundary in [
    (DateTime.utc(2026, 3, 8, 5), const Duration(hours: 23)),
    (DateTime.utc(2026, 11, 1, 4), const Duration(hours: 25)),
  ]) {
    test(
      'a ${boundary.$2.inHours}-hour local day resets at its next midnight',
      () {
        final zone = tz.getLocation('America/New_York');
        final clock = FakeClock(boundary.$1);
        DateTime local(DateTime value) => tz.TZDateTime.from(value, zone);
        final timer = TimerEngine(
          settings: _settings,
          now: clock.reading,
          restored: TimerSnapshot.fromJson({
            ..._readyCycle.toJson(),
            'cycleLocalDate': local(
              clock.utcNow,
            ).toIso8601String().substring(0, 10),
          }),
          toLocal: local,
        );
        clock.advance(boundary.$2 - const Duration(seconds: 1));
        expect(timer.reconcile(clock.reading).changed, isFalse);
        clock.advance(const Duration(seconds: 1));
        expect(timer.reconcile(clock.reading).dayReset, isTrue);
        expect(timer.completedRounds, 0);
      },
    );
  }

  group('daily controller persistence', () {
    late FakeClock clock;
    late MemoryRepository repository;
    late AppController app;

    setUp(() async {
      clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
      repository = MemoryRepository(
        SavedState(settings: _settings, timer: _readyCycle),
      );
      app = await _open(repository, clock);
    });
    tearDown(() => app.dispose());

    test('reopening on the next date saves a fresh cycle once', () async {
      app.dispose();
      clock.advance(const Duration(minutes: 10));
      app = await _open(repository, clock);
      expect(app.timer.phase, FocusPhase.focus);
      expect(app.timer.status, RunStatus.ready);
      expect(app.timer.completedRounds, 0);
      expect(repository.state.timer!.cycleLocalDate, '2026-10-21');
      final writes = repository.writes;
      app.dispose();
      app = await _open(repository, clock);
      expect(repository.writes, writes);
      expect(app.timer.completedRounds, 0);
      await app.toggleTimer();
      clock.advance(const Duration(minutes: 25));
      await app.reconcile();
      expect(app.timer.completedRounds, 1);
      expect(repository.state.sessions, hasLength(1));
    });

    test('returning from background applies a missed day change', () async {
      await app.setForeground(true);
      await app.setForeground(false);
      clock.advance(const Duration(days: 3));
      await app.setForeground(true);
      expect(app.timer.completedRounds, 0);
      expect(app.timer.phase, FocusPhase.focus);
      expect(repository.state.timer!.cycleLocalDate, '2026-10-23');
    });

    test('a failed daily save retries the date and timer together', () async {
      repository.failWrites = true;
      clock.advance(const Duration(minutes: 10));
      final result = await app.reconcile();
      expect(result.persistence, PersistenceOutcome.failed);
      expect(app.saveError, isNotNull);
      expect(app.timer.completedRounds, 0);
      expect(repository.state.timer!.completedRounds, 2);
      expect(repository.state.timer!.cycleLocalDate, '2026-10-20');
      final writes = repository.writes;
      await app.reconcile();
      expect(repository.writes, writes);
      repository.failWrites = false;
      await app.retrySave();
      await app.flush();
      expect(app.saveError, isNull);
      expect(repository.state.timer!.completedRounds, 0);
      expect(repository.state.timer!.cycleLocalDate, '2026-10-21');
    });

    test('a daily reset clears the previous completion notice', () async {
      clock.utcNow = DateTime.utc(2026, 10, 20, 12);
      await app.toggleTimer();
      clock.advance(const Duration(minutes: 25));
      await app.reconcile();
      expect(app.lastPhaseCompletion, isNotNull);
      clock.advance(const Duration(days: 1));
      await app.reconcile();
      expect(app.lastPhaseCompletion, isNull);
      expect(app.timer.phase, FocusPhase.focus);
      expect(repository.state.sessions, hasLength(1));
    });
  });

  for (final paused in [false, true]) {
    testWidgets('midnight callback resets an idle cycle, paused $paused', (
      tester,
    ) async {
      final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
      final repository = MemoryRepository(
        SavedState(settings: _settings, timer: _readyCycle),
      );
      final app = await _open(repository, clock);
      addTearDown(app.dispose);
      if (paused) {
        await app.toggleTimer();
        await app.toggleTimer();
      }
      await app.setForeground(true);
      final writes = repository.writes;
      final hostNow = DateTime.now();
      final untilMidnight = DateTime(
        hostNow.year,
        hostNow.month,
        hostNow.day + 1,
      ).difference(hostNow);
      clock.advance(const Duration(minutes: 10));
      await tester.pump(untilMidnight + const Duration(seconds: 1));
      await app.flush();
      expect(app.timer.status, RunStatus.ready);
      expect(app.timer.phase, FocusPhase.focus);
      expect(app.timer.completedRounds, 0);
      expect(repository.state.timer!.cycleLocalDate, '2026-10-21');
      expect(repository.writes, writes + 1);
      expect(app.tickerActive, isFalse);
      app.dispose();
    });
  }

  testWidgets('the existing Focus screen displays the fresh daily cycle', (
    tester,
  ) async {
    final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
    final repository = MemoryRepository(
      SavedState(settings: _settings, timer: _readyCycle),
    );
    final app = await _open(repository, clock);
    addTearDown(app.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(PomaApp(controller: app));
    await tester.pumpAndSettle();
    clock.advance(const Duration(minutes: 10));
    await app.reconcile();
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Start focus'), findsOneWidget);
    expect(find.text('0 of 3 focus rounds completed'), findsOneWidget);
    expect(app.timer.completedRounds, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });

  test(
    'running alert identity survives midnight and retains natural delivery until cancellation',
    () async {
      final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
      final repository = MemoryRepository(
        SavedState(settings: _settings, timer: _readyCycle),
      );
      final alerts = FakeAlerts();
      final app = await _open(repository, clock, alerts: alerts);
      addTearDown(app.dispose);
      await app.toggleTimer();
      final request = repository.state.alerts.current!.toJson();
      clock.advance(const Duration(minutes: 10));
      await app.reconcile();
      expect(repository.state.alerts.current!.toJson(), request);
      expect(alerts.pending, hasLength(1));
      expect(app.timer.completedRounds, 0);
      clock.advance(const Duration(minutes: 15));
      await app.reconcile();
      expect(alerts.pending.values.single.runId, request['runId']);
      expect(
        repository.state.alerts.pendingCompletion?.runId,
        request['runId'],
      );
      expect(repository.state.alerts.current, isNull);
      expect(repository.state.sessions, hasLength(1));
      expect(app.timer.completedRounds, 1);
      await app.resetTimer();
      expect(alerts.pending, isEmpty);
      expect(repository.state.alerts.pendingCompletion, isNull);
    },
  );

  test('SQLite daily progress and history survive close and reopen', () async {
    final directory = Directory.systemTemp.createTempSync('poma-daily-cycle-');
    final path = '${directory.path}/poma.db';
    SqliteRepository repository() =>
        SqliteRepository(factory: databaseFactoryFfi, databasePath: path);
    var repo = repository();
    AppController? app;
    final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
    try {
      await repo.save(
        SavedState(
          settings: _settings,
          timer: _readyCycle,
          tasks: const [FocusTask(id: 'task', title: 'Keep task')],
          selectedTaskId: 'task',
          sessions: [
            for (var i = 0; i < 2; i++)
              FocusSession(
                id: 'old-$i',
                startedAt: DateTime.utc(2026, 10, 20, 10 + i),
                endedAt: DateTime.utc(2026, 10, 20, 10 + i, 25),
                focusSeconds: 1500,
              ),
          ],
        ),
      );
      app = await _open(repo, clock);
      expect(app.timer.completedRounds, 2);
      app.dispose();
      await repo.close();
      repo = repository();
      clock.advance(const Duration(minutes: 10));
      app = await _open(repo, clock);
      expect(app.timer.completedRounds, 0);
      expect(app.timer.remainingSeconds, 1500);
      expect(app.selectedTask!.title, 'Keep task');
      expect(app.settings.rounds, 3);
      await app.toggleTimer();
      clock.advance(const Duration(minutes: 25));
      await app.reconcile();
      app.dispose();
      await repo.close();
      repo = repository();
      app = await _open(repo, clock);
      await app.loadHistory();
      expect(app.timer.completedRounds, 1);
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.sessions, hasLength(3));
      expect(app.sessions.first.taskTitle, 'Keep task');
      expect((await repo.loadInitial()).timer!.cycleLocalDate, '2026-10-21');
    } finally {
      app?.dispose();
      await repo.close();
      directory.deleteSync(recursive: true);
    }
  });
}
