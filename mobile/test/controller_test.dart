import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'support.dart';

void main() {
  test(
    'unchanged reconciliation reports an outstanding failed save honestly',
    () async {
      final repo = MemoryRepository()..failWrites = true;
      final app = await AppController.create(repo, clock: FakeClock());
      expect((await app.toggleTimer()).persistence, PersistenceOutcome.failed);
      final writes = repo.writes;
      expect((await app.reconcile()).persistence, PersistenceOutcome.failed);
      expect(repo.writes, writes);
      repo.failWrites = false;
      app.retrySave();
      await app.flush();
      expect(
        (await app.reconcile()).persistence,
        PersistenceOutcome.notRequired,
      );
      app.dispose();
    },
  );

  test(
    'backward-clock recovery checkpoints its capped deadline once',
    () async {
      final originalClock = FakeClock();
      final timer = TimerEngine(
        settings: const TimerSettings(),
        now: originalClock.reading,
      )..apply(TimerAction.start, originalClock.reading);
      final repo = MemoryRepository(SavedState(timer: timer.snapshot()));
      final clock = FakeClock(
        originalClock.utcNow.subtract(const Duration(days: 1)),
      );
      final app = await AppController.create(repo, clock: clock);
      expect(repo.writes, 1);
      expect(
        repo.state.timer!.deadline,
        clock.utcNow.add(const Duration(minutes: 25)),
      );
      await app.reconcile();
      expect(repo.writes, 1);
      app.dispose();
      final next = await AppController.create(
        repo,
        clock: FakeClock(clock.utcNow.add(const Duration(minutes: 10))),
      );
      expect(next.timer.remainingSeconds, 900);
      next.dispose();
    },
  );

  test('a control at the deadline cannot act on two phases', () async {
    for (final action in ['toggle', 'skip', 'reset', 'select']) {
      final clock = FakeClock();
      final app = await AppController.create(MemoryRepository(), clock: clock);
      await app.toggleTimer();
      clock.advance(const Duration(minutes: 25));
      switch (action) {
        case 'toggle':
          await app.toggleTimer();
        case 'skip':
          await app.skipTimer();
        case 'reset':
          await app.resetTimer();
        case 'select':
          await app.selectPhase(FocusPhase.longBreak);
      }
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.ready);
      expect(app.sessions, hasLength(1));
      await app.flush();
      app.dispose();
    }
  });
  test('task actions and selected focus task persist across startup', () async {
    final repo = MemoryRepository();
    final app = await AppController.create(repo, clock: FakeClock());
    app.addTask('  Read one chapter  ');
    app.addTask('Write notes');
    final id = app.tasks.first.id;
    app.editTask(id, 'Read chapter 2');
    app.toggleTask(app.tasks.last.id);
    await app.flush();
    app.dispose();
    final restored = await AppController.create(repo, clock: FakeClock());
    expect(restored.tasks.first.title, 'Read chapter 2');
    expect(restored.selectedTask?.id, id);
    expect(restored.tasks.last.done, isTrue);
    restored.deleteTask(id);
    await restored.flush();
    expect(repo.state.selectedTaskId, isNull);
    restored.dispose();
  });
  test(
    'overdue recovery saves one completion and an advanced timer atomically',
    () async {
      final repo = MemoryRepository();
      final firstClock = FakeClock();
      final first = await AppController.create(repo, clock: firstClock);
      await first.toggleTimer();
      await first.flush();
      first.dispose();
      final second = await AppController.create(
        repo,
        clock: FakeClock(DateTime.utc(2026, 10, 23)),
      );
      expect(second.sessions, hasLength(1));
      expect(second.timer.phase, FocusPhase.shortBreak);
      expect(second.sessionsOn(DateTime(2026, 10, 23)), isEmpty);
      await second.flush();
      second.dispose();
      final third = await AppController.create(
        repo,
        clock: FakeClock(DateTime.utc(2026, 10, 23)),
      );
      expect(third.sessions, hasLength(1));
      third.dispose();
    },
  );
  test('failed saves are visible and retry writes the newest state', () async {
    final repo = MemoryRepository()..failWrites = true;
    final app = await AppController.create(repo, clock: FakeClock());
    app.addTask('Keep this task');
    await app.flush();
    expect(app.saveError, isNotNull);
    repo.failWrites = false;
    app.retrySave();
    await app.flush();
    expect(app.saveError, isNull);
    expect(repo.state.tasks.single.title, 'Keep this task');
    app.dispose();
  });

  test(
    'rapid queued toggles cannot start then immediately pause a new session',
    () async {
      final clock = GatedClock();
      final repo = MemoryRepository();
      final app = await AppController.create(repo, clock: clock);
      final gate = Completer<ClockReading>();
      clock.gate = gate;
      final first = app.toggleTimer();
      final duplicate = app.toggleTimer();
      gate.complete(clock.reading);
      expect((await first).transition.outcome, TimerCommandOutcome.applied);
      expect((await duplicate).transition.outcome, TimerCommandOutcome.stale);
      expect(app.timer.status, RunStatus.running);
      expect(repo.writes, 1);
      app.dispose();
    },
  );

  test(
    'refresh queued before a control consumes the old phase revision',
    () async {
      final clock = FakeClock();
      final app = await AppController.create(MemoryRepository(), clock: clock);
      await app.toggleTimer();
      clock.advance(const Duration(minutes: 25));
      final refresh = app.reconcile();
      final selection = app.selectPhase(FocusPhase.longBreak);
      expect((await refresh).transition.completion, isNotNull);
      expect((await selection).transition.outcome, TimerCommandOutcome.stale);
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.ready);
      app.dispose();
    },
  );

  test(
    'session-targeted actions are explicit, repeatable and reject stale IDs',
    () async {
      final clock = FakeClock();
      final repo = MemoryRepository();
      final app = await AppController.create(repo, clock: clock);
      final start = await app.toggleTimer();
      final id = start.snapshot.runId!;
      expect(start.persistence, PersistenceOutcome.saved);
      expect(start.alert!.runId, id);
      clock.advance(const Duration(microseconds: 123456));
      final pause = await app.handleTimerAction(TimerAction.pause, runId: id);
      expect(pause.alert, isNull);
      expect(pause.snapshot.remainingMicros, 1499876544);
      final writes = repo.writes;
      expect(
        (await app.handleTimerAction(
          TimerAction.pause,
          runId: id,
        )).transition.outcome,
        TimerCommandOutcome.unchanged,
      );
      expect(repo.writes, writes);
      await app.handleTimerAction(TimerAction.resume, runId: id);
      await app.handleTimerAction(TimerAction.skip, runId: id);
      await app.toggleTimer();
      final current = app.timer.runId;
      final stale = await app.handleTimerAction(TimerAction.skip, runId: id);
      expect(stale.transition.outcome, TimerCommandOutcome.stale);
      expect(app.timer.runId, current);
      expect(app.timer.status, RunStatus.running);
      app.dispose();
    },
  );

  test(
    'task changes during delayed start and paused recovery retain captured task',
    () async {
      final clock = GatedClock();
      final repo = MemoryRepository();
      final app = await AppController.create(repo, clock: clock);
      app.addTask('Original');
      final taskId = app.selectedTaskId!;
      clock.gate = Completer<ClockReading>();
      final gate = clock.gate!;
      final start = app.toggleTimer();
      app.editTask(taskId, 'Renamed');
      gate.complete(clock.reading);
      final id = (await start).snapshot.runId;
      clock.advance(const Duration(seconds: 5, microseconds: 99));
      await app.toggleTimer();
      app.deleteTask(taskId);
      await app.updateSettings(const TimerSettings(focusMinutes: 50));
      await app.flush();
      app.dispose();
      final nextClock = FakeClock(clock.utcNow.add(const Duration(days: 1)));
      final restored = await AppController.create(repo, clock: nextClock);
      expect(restored.timer.runId, id);
      expect(restored.timer.totalSeconds, 1500);
      expect(restored.timer.remainingMicros, 1494999901);
      await restored.toggleTimer();
      nextClock.advance(const Duration(microseconds: 1494999901));
      await restored.reconcile();
      expect(restored.sessions.single.taskId, taskId);
      expect(restored.sessions.single.taskTitle, 'Original');
      expect(restored.sessions.single.focusSeconds, 1500);
      restored.dispose();
    },
  );

  test(
    'strict controls also apply to direct application and notification actions',
    () async {
      final repo = MemoryRepository();
      final clock = FakeClock();
      final app = await AppController.create(repo, clock: clock);
      await app.selectPhase(FocusPhase.shortBreak);
      await app.toggleTimer();
      await app.updateSettings(const TimerSettings(strictMode: true));
      final original = app.timer.snapshot().toJson();
      final writes = repo.writes;
      for (final action in [
        app.toggleTimer,
        app.resetTimer,
        app.skipTimer,
        () => app.selectPhase(FocusPhase.focus),
        () => app.handleTimerAction(TimerAction.pause, runId: app.timer.runId!),
      ]) {
        expect(
          (await action()).transition.outcome,
          TimerCommandOutcome.blocked,
        );
      }
      await app.updateSettings(
        const TimerSettings(focusMinutes: 40, rounds: 1),
      );
      expect(repo.writes, writes);
      expect(app.timer.snapshot().toJson(), original);
      expect(app.settings.strictMode, isTrue);
      expect(app.settings.focusMinutes, 25);
      expect(app.settings.rounds, 4);
      await app.updateSettings(app.settings.copyWith(appearance: 'dark'));
      expect(app.settings.appearance, 'dark');
      clock.advance(const Duration(minutes: 5));
      await app.reconcile();
      await app.updateSettings(app.settings.copyWith(strictMode: false));
      expect(app.settings.strictMode, isFalse);
      app.dispose();
    },
  );

  test(
    'midnight completion and timezone regrouping use completion instant, not reopening',
    () async {
      final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 50));
      final repo = MemoryRepository();
      final first = await AppController.create(repo, clock: clock);
      await first.toggleTimer();
      first.dispose();
      final restored = await AppController.create(
        repo,
        clock: FakeClock(DateTime.utc(2026, 10, 23)),
      );
      expect(
        restored.sessions.single.endedAt,
        DateTime.utc(2026, 10, 21, 0, 15),
      );
      DateTime utc(DateTime instant) => instant;
      DateTime west(DateTime instant) =>
          instant.subtract(const Duration(hours: 5));
      expect(
        restored.sessionsOn(DateTime(2026, 10, 21), toLocal: utc),
        hasLength(1),
      );
      expect(
        restored.sessionsOn(DateTime(2026, 10, 20), toLocal: west),
        hasLength(1),
      );
      expect(
        restored.sessionsOn(DateTime(2026, 10, 21), toLocal: west),
        isEmpty,
      );
      expect(
        restored.sessionsOn(DateTime(2026, 10, 23), toLocal: utc),
        isEmpty,
      );
      restored.dispose();
    },
  );

  test(
    'clock failure preserves state, stops ticker and can be reconciled on retry',
    () async {
      final clock = FakeClock();
      final repo = MemoryRepository();
      final app = await AppController.create(repo, clock: clock);
      await app.setForeground(true);
      await app.toggleTimer();
      expect(app.tickerActive, isTrue);
      final snapshot = app.timer.snapshot().toJson();
      final writes = repo.writes;
      clock.failReads = true;
      final result = await app.resetTimer();
      expect(result.clockSucceeded, isFalse);
      expect(result.alert, isNull);
      expect(app.clockError, isNotNull);
      expect(app.tickerActive, isFalse);
      expect(app.timer.snapshot().toJson(), snapshot);
      expect(repo.writes, writes);
      clock.advance(const Duration(hours: 1));
      clock.failReads = false;
      await app.reconcile();
      expect(app.clockError, isNull);
      expect(app.sessions, hasLength(1));
      expect(app.timer.status, RunStatus.ready);
      expect(app.tickerActive, isFalse);
      app.dispose();
    },
  );

  test(
    'a failed completion save reports failure and retry keeps the same identity',
    () async {
      final clock = FakeClock();
      final repo = MemoryRepository();
      final app = await AppController.create(repo, clock: clock);
      final id = (await app.toggleTimer()).snapshot.runId;
      repo.failWrites = true;
      clock.advance(const Duration(minutes: 25));
      final result = await app.reconcile();
      expect(result.persistence, PersistenceOutcome.failed);
      expect(result.snapshot.status, RunStatus.ready);
      expect(app.sessions.single.id, id);
      expect(repo.state.timer!.runId, id);
      repo.failWrites = false;
      app.retrySave();
      await app.flush();
      app.dispose();
      final restored = await AppController.create(repo, clock: clock);
      expect(restored.sessions.single.id, id);
      expect(restored.timer.completedRounds, 1);
      restored.dispose();
    },
  );

  testWidgets(
    'rendering has no saves and ticker is cancelled while idle or inactive',
    (tester) async {
      final clock = FakeClock();
      final repo = MemoryRepository();
      final app = await AppController.create(repo, clock: clock);
      await app.setForeground(true);
      expect(app.tickerActive, isFalse);
      expect(repo.writes, 0);
      await app.toggleTimer();
      expect(app.tickerActive, isTrue);
      final writes = repo.writes;
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        await app.flush();
      }
      expect(app.timer.remainingSeconds, 1495);
      expect(repo.writes, writes);
      final leaving = app.setForeground(false);
      expect(app.tickerActive, isFalse);
      await leaving;
      final checkpointWrites = repo.writes;
      await app.setForeground(false);
      clock.advance(const Duration(minutes: 30));
      await tester.pump(const Duration(minutes: 30));
      expect(repo.writes, checkpointWrites);
      await app.setForeground(true);
      expect(app.sessions, hasLength(1));
      expect(app.tickerActive, isFalse);
      await app.toggleTimer();
      expect(app.tickerActive, isTrue);
      await app.toggleTimer();
      expect(app.tickerActive, isFalse);
      await app.toggleTimer();
      app.dispose();
      expect(app.tickerActive, isFalse);
    },
  );

  test(
    'a delayed clock response cannot restart an inactive or disposed ticker',
    () async {
      final clock = GatedClock();
      final app = await AppController.create(MemoryRepository(), clock: clock);
      await app.setForeground(true);
      await app.toggleTimer();
      final gate = Completer<ClockReading>();
      clock.gate = gate;
      final refresh = app.refresh();
      final background = app.setForeground(false);
      expect(app.tickerActive, isFalse);
      gate.complete(clock.reading);
      await refresh;
      await background;
      expect(app.tickerActive, isFalse);
      final disposedGate = Completer<ClockReading>();
      clock.gate = disposedGate;
      final foreground = app.setForeground(true);
      await Future<void>.delayed(Duration.zero);
      app.dispose();
      disposedGate.complete(clock.reading);
      await foreground;
      expect(app.tickerActive, isFalse);
    },
  );
}

class GatedClock extends FakeClock {
  Completer<ClockReading>? gate;
  @override
  Future<ClockReading> sample() {
    final pending = gate;
    gate = null;
    return pending?.future ?? super.sample();
  }
}
