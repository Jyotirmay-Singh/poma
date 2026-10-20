import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'SQLite survives close and reopen with tasks, preferences and a running timer',
    () async {
      final dir = Directory.systemTemp.createTempSync('poma-test-');
      final dbPath = '${dir.path}/poma.db';
      final repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      final timer = TimerEngine(
        settings: const TimerSettings(focusMinutes: 30),
        clock: FakeClock(),
      )..start();
      await repository.save(
        SavedState(
          settings: timer.settings,
          timer: timer.snapshot(),
          tasks: const [
            FocusTask(id: 't1', title: 'Read'),
            FocusTask(id: 't2', title: 'Write', done: true),
          ],
          selectedTaskId: 't1',
        ),
      );
      await repository.close();
      final reopened = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      final restored = await reopened.load();
      expect(restored.settings.focusMinutes, 30);
      expect(restored.tasks.map((task) => task.title), ['Read', 'Write']);
      expect(restored.tasks.last.done, isTrue);
      expect(restored.selectedTaskId, 't1');
      expect(restored.timer?.status, RunStatus.running);
      await reopened.close();
      dir.deleteSync(recursive: true);
    },
  );
  test(
    'completion identity prevents duplicate history and clearing a selection persists',
    () async {
      final repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final session = FocusSession(
        id: 'same-id',
        startedAt: DateTime.utc(2026, 10, 20),
        endedAt: DateTime.utc(2026, 10, 20, 0, 25),
        focusSeconds: 1500,
        taskTitle: 'Original task',
      );
      final state = SavedState(sessions: [session, session]);
      await repository.save(state);
      await repository.save(state);
      expect((await repository.load()).sessions, hasLength(1));
      expect(
        (await repository.load()).sessions.single.taskTitle,
        'Original task',
      );
      await repository.save(SavedState(selectedTaskId: 't1'));
      await repository.save(SavedState());
      expect((await repository.load()).selectedTaskId, isNull);
      await repository.close();
    },
  );
}
