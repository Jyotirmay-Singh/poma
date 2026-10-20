import 'package:flutter_test/flutter_test.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'support.dart';

void main() {
  late FakeClock clock;
  late TimerEngine timer;
  setUp(() {
    clock = FakeClock();
    timer = TimerEngine(settings: const TimerSettings(), now: clock.reading);
  });
  TimerTransition act(
    TimerAction action, {
    FocusPhase? phase,
    FocusTask? task,
    TimerSettings? settings,
  }) => timer.apply(
    action,
    clock.reading,
    selectedPhase: phase,
    task: task,
    nextSettings: settings,
  );
  TimerEngine restore(TimerSnapshot snapshot, FakeClock nextClock) =>
      TimerEngine(
        settings: timer.settings,
        now: nextClock.reading,
        restored: TimerSnapshot.fromJson(snapshot.toJson()),
      );

  test(
    'delayed callbacks and repeated refresh never count callback frequency',
    () {
      act(TimerAction.start);
      clock.advance(const Duration(minutes: 2, milliseconds: 250));
      act(TimerAction.reconcile);
      expect(timer.remainingSeconds, 1380);
      expect(timer.remainingMicros, 1379750000);
      for (var i = 0; i < 100; i++) {
        act(TimerAction.reconcile);
      }
      expect(timer.remainingMicros, 1379750000);
      clock.advance(const Duration(days: 2));
      final completed = act(TimerAction.reconcile).completion!;
      expect(completed.endedAt, DateTime.utc(2026, 10, 20, 9, 25));
      expect(timer.phase, FocusPhase.shortBreak);
      expect(timer.status, RunStatus.ready);
      expect(timer.completedRounds, 1);
      expect(act(TimerAction.reconcile).changed, isFalse);
    },
  );

  test(
    'pause, reset and skip one microsecond before expiry never count a completion',
    () {
      for (final action in [
        TimerAction.pause,
        TimerAction.reset,
        TimerAction.skip,
      ]) {
        act(TimerAction.selectPhase, phase: FocusPhase.focus);
        act(TimerAction.start);
        clock.advance(const Duration(microseconds: 1499999999));
        expect(act(action).completion, isNull);
        clock.advance(const Duration(days: 1));
        expect(act(TimerAction.reconcile).completion, isNull);
        expect(timer.completedRounds, 0);
      }
    },
  );

  test(
    'fractional expiry rounds display upward and completes at zero only',
    () {
      act(TimerAction.start);
      clock.advance(const Duration(microseconds: 1499999999));
      expect(act(TimerAction.reconcile).completion, isNull);
      expect(timer.remainingSeconds, 1);
      expect(timer.remainingMicros, 1);
      clock.advance(const Duration(microseconds: 1));
      expect(act(TimerAction.reconcile).completion, isNotNull);
    },
  );

  test(
    'repeated fractional pauses preserve identity, task and exact remaining',
    () {
      act(
        TimerAction.start,
        task: const FocusTask(id: 'task', title: 'Original'),
      );
      final original = timer.snapshot();
      for (var i = 0; i < 10; i++) {
        clock.advance(const Duration(microseconds: 123456));
        act(TimerAction.pause);
        clock.advance(const Duration(hours: 1));
        act(
          TimerAction.resume,
          task: const FocusTask(id: 'other', title: 'Changed'),
        );
      }
      expect(timer.remainingMicros, 1500000000 - 1234560);
      expect(timer.snapshot().runId, original.runId);
      expect(timer.snapshot().startedAt, original.startedAt);
      clock.advance(Duration(microseconds: timer.remainingMicros));
      final session = act(TimerAction.reconcile).completion!;
      expect(session.taskId, 'task');
      expect(session.taskTitle, 'Original');
      expect(session.focusSeconds, 1500);
      expect(
        session.endedAt,
        original.startedAt!.add(const Duration(hours: 10, minutes: 25)),
      );
    },
  );

  for (final adjustment in [
    const Duration(hours: 3),
    const Duration(hours: -3),
  ]) {
    test(
      'live countdown and completion deadline ignore wall jump $adjustment',
      () {
        act(TimerAction.start);
        final deadline = timer.snapshot().deadline;
        clock.utcNow = clock.utcNow.add(adjustment);
        clock.advance(const Duration(minutes: 25));
        expect(act(TimerAction.reconcile).completion!.endedAt, deadline);
      },
    );
  }

  test(
    'continuous elapsed time completes a sleeping live process without callbacks',
    () {
      act(TimerAction.start);
      // Simulate an OS boot clock advancing while Dart never executes.
      clock.elapsed += const Duration(hours: 2);
      clock.utcNow = clock.utcNow.add(const Duration(hours: 2));
      expect(act(TimerAction.reconcile).completion, isNotNull);
      expect(timer.status, RunStatus.ready);
      expect(act(TimerAction.reconcile).completion, isNull);
    },
  );

  test('a regressing live elapsed clock fails before changing state', () {
    act(TimerAction.start);
    clock.advance(const Duration(seconds: 10));
    act(TimerAction.reconcile);
    final snapshot = timer.snapshot().toJson();
    clock.elapsed = Duration.zero;
    expect(() => act(TimerAction.skip), throwsA(isA<TimerClockException>()));
    expect(timer.snapshot().toJson(), snapshot);
  });

  for (final phase in FocusPhase.values) {
    test(
      'running $phase restores deadline and completes only its started phase',
      () {
        act(TimerAction.selectPhase, phase: phase);
        act(TimerAction.start);
        clock.advance(const Duration(seconds: 17, microseconds: 123));
        act(TimerAction.reconcile);
        final saved = timer.snapshot();
        final nextClock = FakeClock(
          clock.utcNow.add(const Duration(seconds: 23)),
        );
        final restored = restore(saved, nextClock);
        expect(
          restored.remainingMicros,
          (timer.totalSeconds - 40) * 1000000 - 123,
        );
        nextClock.advance(const Duration(days: 3));
        final result = restored.reconcile(nextClock.reading);
        expect(result.completedPhase, isTrue);
        expect(result.previousRunId, saved.runId);
        expect(
          result.completion?.id,
          phase == FocusPhase.focus ? saved.runId : null,
        );
        expect(
          result.completion?.endedAt,
          phase == FocusPhase.focus ? saved.deadline : null,
        );
        expect(restored.status, RunStatus.ready);
        expect(restored.reconcile(nextClock.reading).changed, isFalse);
        final again = restore(restored.snapshot(), nextClock);
        expect(again.reconcile(nextClock.reading).completion, isNull);
      },
    );

    test(
      'paused $phase recovery excludes days closed and preserves metadata',
      () {
        act(TimerAction.selectPhase, phase: phase);
        act(
          TimerAction.start,
          task: const FocusTask(id: 't', title: 'Keep'),
        );
        clock.advance(const Duration(seconds: 12, microseconds: 345));
        act(TimerAction.pause);
        final saved = timer.snapshot();
        final nextClock = FakeClock(clock.utcNow.add(const Duration(days: 3)));
        final restored = restore(saved, nextClock);
        expect(restored.snapshot().toJson(), saved.toJson());
        restored.apply(TimerAction.resume, nextClock.reading);
        expect(restored.runId, saved.runId);
        expect(restored.snapshot().taskTitle, 'Keep');
        nextClock.advance(Duration(microseconds: saved.remainingMicros));
        expect(restored.reconcile(nextClock.reading).completedPhase, isTrue);
      },
    );
  }

  test(
    'restart with a backward wall clock caps remaining to original duration',
    () {
      act(TimerAction.start);
      final saved = timer.snapshot();
      final nextClock = FakeClock(
        clock.utcNow.subtract(const Duration(days: 1)),
      );
      final restored = restore(saved, nextClock);
      expect(restored.remainingMicros, 1500000000);
      nextClock.advance(const Duration(minutes: 25));
      expect(
        restored.reconcile(nextClock.reading).completion!.endedAt,
        nextClock.utcNow,
      );
    },
  );

  for (final phase in FocusPhase.values) {
    for (final action in [
      TimerAction.start,
      TimerAction.resume,
      TimerAction.pause,
      TimerAction.reset,
      TimerAction.skip,
      TimerAction.selectPhase,
    ]) {
      test('$action at expiry of $phase consumes only the original phase', () {
        act(TimerAction.selectPhase, phase: phase);
        act(TimerAction.start);
        clock.advance(Duration(seconds: timer.totalSeconds));
        final result = act(action, phase: FocusPhase.longBreak);
        expect(result.outcome, TimerCommandOutcome.completionConsumed);
        expect(
          timer.phase,
          phase == FocusPhase.focus ? FocusPhase.shortBreak : FocusPhase.focus,
        );
        expect(timer.status, RunStatus.ready);
        expect(timer.completedRounds, phase == FocusPhase.focus ? 1 : 0);
      });
    }
  }

  test('reset, skip and same-phase selection abandon without counting', () {
    for (final action in [
      TimerAction.reset,
      TimerAction.skip,
      TimerAction.selectPhase,
    ]) {
      act(TimerAction.selectPhase, phase: FocusPhase.focus);
      act(TimerAction.start);
      final id = timer.runId;
      clock.advance(const Duration(seconds: 12));
      expect(act(action, phase: FocusPhase.focus).completion, isNull);
      expect(timer.completedRounds, 0);
      expect(timer.status, RunStatus.ready);
      expect(timer.runId, isNull);
      act(TimerAction.start);
      expect(timer.runId, isNot(id));
    }
  });

  test('cycle target changes preserve earned progress and current phase', () {
    for (var i = 0; i < 3; i++) {
      act(TimerAction.selectPhase, phase: FocusPhase.focus);
      act(TimerAction.start);
      clock.advance(const Duration(minutes: 25));
      act(TimerAction.reconcile);
    }
    act(TimerAction.updateSettings, settings: const TimerSettings(rounds: 2));
    expect(timer.phase, FocusPhase.shortBreak);
    expect(timer.completedRounds, 3);
    expect(timer.displayedRounds, 2);
    act(TimerAction.updateSettings, settings: const TimerSettings(rounds: 5));
    expect(timer.displayedRounds, 3);
    act(TimerAction.selectPhase, phase: FocusPhase.focus);
    act(TimerAction.start);
    clock.advance(const Duration(minutes: 25));
    act(TimerAction.reconcile);
    expect(timer.phase, FocusPhase.shortBreak);
    act(TimerAction.skip);
    act(TimerAction.start);
    clock.advance(const Duration(minutes: 25));
    act(TimerAction.reconcile);
    expect(timer.phase, FocusPhase.longBreak);
    act(TimerAction.reset);
    expect(timer.completedRounds, 5);
    act(TimerAction.skip);
    expect(timer.completedRounds, 0);
    expect(timer.phase, FocusPhase.focus);
  });

  test(
    'four completed focus rounds and long break finish the default cycle',
    () {
      for (var i = 1; i <= 4; i++) {
        act(TimerAction.start);
        clock.advance(const Duration(minutes: 25));
        expect(act(TimerAction.reconcile).completion, isNotNull);
        expect(
          timer.phase,
          i == 4 ? FocusPhase.longBreak : FocusPhase.shortBreak,
        );
        act(TimerAction.start);
        clock.advance(Duration(minutes: i == 4 ? 15 : 5));
        expect(act(TimerAction.reconcile).completion, isNull);
      }
      expect(timer.completedRounds, 0);
    },
  );

  test('duration edits preserve running and paused duration until reset', () {
    act(TimerAction.start);
    final original = timer.snapshot();
    act(
      TimerAction.updateSettings,
      settings: const TimerSettings(focusMinutes: 45),
    );
    expect(timer.totalSeconds, 1500);
    expect(timer.snapshot().deadline, original.deadline);
    clock.advance(const Duration(microseconds: 123456));
    act(TimerAction.pause);
    act(
      TimerAction.updateSettings,
      settings: const TimerSettings(focusMinutes: 50),
    );
    expect(timer.totalSeconds, 1500);
    expect(timer.remainingMicros, 1499876544);
    act(TimerAction.reset);
    expect(timer.totalSeconds, 3000);
  });

  test(
    'settings at expiry apply after completion without selecting another phase',
    () {
      act(TimerAction.start);
      clock.advance(const Duration(minutes: 25));
      final result = act(
        TimerAction.updateSettings,
        settings: const TimerSettings(rounds: 1, shortBreakMinutes: 7),
      );
      expect(result.completion, isNotNull);
      expect(timer.phase, FocusPhase.shortBreak);
      expect(timer.totalSeconds, 420);
      expect(timer.status, RunStatus.ready);
    },
  );

  for (final phase in FocusPhase.values) {
    test(
      'strict $phase locks controls and timing settings but permits appearance',
      () {
        act(TimerAction.selectPhase, phase: phase);
        act(TimerAction.start);
        act(
          TimerAction.updateSettings,
          settings: const TimerSettings(strictMode: true),
        );
        final original = timer.snapshot().toJson();
        for (final action in [
          TimerAction.pause,
          TimerAction.reset,
          TimerAction.skip,
          TimerAction.selectPhase,
        ]) {
          expect(
            act(action, phase: FocusPhase.longBreak).outcome,
            TimerCommandOutcome.blocked,
          );
        }
        act(
          TimerAction.updateSettings,
          settings: const TimerSettings(
            focusMinutes: 50,
            rounds: 2,
            strictMode: false,
            appearance: 'dark',
          ),
        );
        expect(timer.snapshot().toJson(), original);
        expect(timer.settings.focusMinutes, 25);
        expect(timer.settings.rounds, 4);
        expect(timer.settings.strictMode, isTrue);
        expect(timer.settings.appearance, 'dark');
        clock.advance(Duration(seconds: timer.totalSeconds));
        act(TimerAction.reconcile);
        expect(timer.controlsLocked, isFalse);
      },
    );
  }

  test(
    'snapshot parser rejects corruption instead of clamping or erasing it',
    () {
      act(
        TimerAction.start,
        task: const FocusTask(id: 't', title: 'Original'),
      );
      final valid = timer.snapshot().toJson();
      final corruptions = <Map<String, Object?>>[
        {'phase': 'unknown'},
        {'status': 'unknown'},
        {'totalSeconds': 0},
        {'totalSeconds': 7201},
        {'remainingMicros': -1},
        {'remainingMicros': 1500000001},
        {'remainingMicros': 2.5},
        {'completedRounds': 9},
        {'completedRounds': -1},
        {'runId': '  '},
        {'runId': null},
        {'startedAt': null},
        {'deadline': null},
        {'deadline': 'bad'},
        {'deadline': '2026-02-30T12:00:00.000Z'},
        {'deadline': '2026-13-20T12:00:00.000Z'},
        {'deadline': '2026-10-20T24:00:00.000Z'},
        {'deadline': '2026-10-20T12:00:00.000+24:00'},
        {'deadline': '2026-10-20T12:00:00'},
        {'taskTitle': null},
        {'taskId': null},
        {'status': 'ready'},
        {'status': 'paused'},
      ];
      for (final corruption in corruptions) {
        expect(
          () => TimerSnapshot.fromJson({...valid, ...corruption}),
          throwsFormatException,
          reason: corruption.toString(),
        );
      }
      expect(TimerSnapshot.fromJson(valid).toJson(), valid);
      act(TimerAction.pause);
      final paused = timer.snapshot().toJson();
      expect(
        () => TimerSnapshot.fromJson({...paused, 'remainingMicros': 0}),
        throwsFormatException,
      );
      expect(
        () => TimerEngine(
          settings: timer.settings,
          now: clock.reading,
          restored: const TimerSnapshot(
            phase: FocusPhase.focus,
            status: RunStatus.paused,
            totalSeconds: 1500,
            remainingMicros: 1200000000,
            completedRounds: 0,
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
