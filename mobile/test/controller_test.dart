import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/domain/models.dart';
import 'support.dart';

void main() {
  test('a control at the deadline cannot act on two phases', () async {
    for (final action in ['toggle', 'skip', 'reset']) {
      final clock = FakeClock();
      final app = await AppController.create(MemoryRepository(), clock: clock);
      app.toggleTimer();
      clock.advance(const Duration(minutes: 25));
      switch (action) {
        case 'toggle':
          app.toggleTimer();
        case 'skip':
          app.skipTimer();
        case 'reset':
          app.resetTimer();
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
      first.toggleTimer();
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
}
