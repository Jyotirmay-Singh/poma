import 'package:flutter_test/flutter_test.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'support.dart';

void main() {
  late FakeClock clock;
  late TimerEngine timer;
  setUp(() {
    clock = FakeClock();
    timer = TimerEngine(settings: const TimerSettings(), clock: clock);
  });

  test('starts with 25/5/15 and a four-session cycle', () {
    expect(timer.remainingSeconds, 1500);
    expect(timer.status, RunStatus.ready);
    expect(timer.settings.secondsFor(FocusPhase.shortBreak), 300);
    expect(timer.settings.secondsFor(FocusPhase.longBreak), 900);
    expect(timer.settings.rounds, 4);
  });
  test('a delayed callback does not make the countdown drift', () {
    timer.start();
    clock.advance(const Duration(minutes: 2, milliseconds: 250));
    timer.tick();
    expect(timer.remainingSeconds, 1380);
    for (var i = 0; i < 100; i++) {
      timer.tick();
    }
    expect(timer.remainingSeconds, 1380);
  });
  test('foreground countdown ignores wall-clock adjustments', () {
    timer.start();
    clock.utcNow = clock.utcNow.add(const Duration(hours: 3));
    expect(timer.remainingSeconds, 1500);
    clock.advance(const Duration(seconds: 12));
    expect(timer.remainingSeconds, 1488);
  });
  test(
    'pause and resume preserve exact remaining time and session identity',
    () {
      timer.start(
        task: const FocusTask(id: 'task', title: 'Read one chapter'),
      );
      final id = timer.snapshot().runId;
      clock.advance(const Duration(seconds: 67, milliseconds: 250));
      timer.pause();
      clock.advance(const Duration(hours: 1));
      expect(timer.remainingSeconds, 1433);
      timer.start(
        task: const FocusTask(id: 'other', title: 'Another task'),
      );
      expect(timer.snapshot().runId, id);
      expect(timer.snapshot().taskId, 'task');
      clock.advance(const Duration(microseconds: 1432750000));
      expect(timer.tick()?.taskTitle, 'Read one chapter');
    },
  );
  test(
    'a completed focus advances once and never invents unattended sessions',
    () {
      timer.start();
      clock.advance(const Duration(days: 2));
      final session = timer.tick();
      expect(session?.focusSeconds, 1500);
      expect(session?.endedAt, DateTime.utc(2026, 10, 20, 9, 25));
      expect(timer.phase, FocusPhase.shortBreak);
      expect(timer.status, RunStatus.ready);
      expect(timer.completedRounds, 1);
      expect(timer.tick(), isNull);
    },
  );
  test('restore uses a deadline, rather than stale displayed seconds', () {
    timer.start();
    final snapshot = TimerSnapshot.fromJson(timer.snapshot().toJson());
    final nextClock = FakeClock(clock.utcNow.add(const Duration(minutes: 10)));
    final restored = TimerEngine(
      settings: timer.settings,
      clock: nextClock,
      restored: snapshot,
    );
    expect(restored.remainingSeconds, 900);
    nextClock.advance(const Duration(minutes: 16));
    expect(restored.tick()?.id, snapshot.runId);
    expect(restored.phase, FocusPhase.shortBreak);
  });
  test('restore of an overdue focus retains its actual completion day', () {
    timer.start();
    final snapshot = timer.snapshot();
    final recovered = TimerEngine(
      settings: timer.settings,
      clock: FakeClock(DateTime.utc(2026, 10, 23)),
      restored: snapshot,
    );
    expect(recovered.tick()?.endedAt, DateTime.utc(2026, 10, 20, 9, 25));
    expect(recovered.tick(), isNull);
  });
  test('paused snapshot does not consume time while the process is closed', () {
    timer.start();
    clock.advance(const Duration(minutes: 5));
    timer.pause();
    final restored = TimerEngine(
      settings: timer.settings,
      clock: FakeClock(DateTime.utc(2026, 10, 23)),
      restored: timer.snapshot(),
    );
    expect(restored.remainingSeconds, 1200);
    expect(restored.status, RunStatus.paused);
  });
  test('four actual focus completions lead to a long break', () {
    for (var i = 1; i <= 4; i++) {
      timer.start();
      clock.advance(const Duration(minutes: 25));
      expect(timer.tick(), isNotNull);
      expect(
        timer.phase,
        i == 4 ? FocusPhase.longBreak : FocusPhase.shortBreak,
      );
      timer.start();
      clock.advance(Duration(minutes: i == 4 ? 15 : 5));
      timer.tick();
      expect(timer.phase, FocusPhase.focus);
    }
    expect(timer.completedRounds, 0);
  });
  test('skipping and resetting never count a focus session', () {
    timer.start();
    clock.advance(const Duration(minutes: 3));
    timer.reset();
    expect(timer.completedRounds, 0);
    expect(timer.remainingSeconds, 1500);
    timer.start();
    timer.skip();
    expect(timer.completedRounds, 0);
    expect(timer.tick(), isNull);
  });
  test('strict mode locks pause reset skip and phase selection', () {
    timer.updateSettings(const TimerSettings(strictMode: true));
    timer.start();
    clock.advance(const Duration(seconds: 10));
    timer.pause();
    timer.reset();
    timer.skip();
    timer.selectPhase(FocusPhase.longBreak);
    expect(timer.status, RunStatus.running);
    expect(timer.phase, FocusPhase.focus);
    expect(timer.remainingSeconds, 1490);
  });
  test('editing durations does not change a running or paused session', () {
    timer.start();
    timer.updateSettings(const TimerSettings(focusMinutes: 45));
    expect(timer.totalSeconds, 1500);
    timer.pause();
    timer.updateSettings(const TimerSettings(focusMinutes: 50));
    expect(timer.totalSeconds, 1500);
    timer.reset();
    expect(timer.totalSeconds, 3000);
  });
  test(
    'an incomplete saved running timer fails without silently erasing data',
    () {
      expect(
        () => TimerEngine(
          settings: const TimerSettings(),
          restored: const TimerSnapshot(
            phase: FocusPhase.focus,
            status: RunStatus.running,
            totalSeconds: 1500,
            remainingMicros: 1500000000,
            completedRounds: 0,
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
