import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/local_storage_policy.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'backup preparation failure preserves an existing database and retry reopens it',
    () async {
      final dir = Directory.systemTemp.createTempSync('poma-backup-test-');
      final dbPath = '${dir.path}/poma.db';
      final first = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      await first.save(
        SavedState(
          settings: const TimerSettings(focusMinutes: 40),
          tasks: const [FocusTask(id: 'kept', title: 'Keep existing data')],
          selectedTaskId: 'kept',
        ),
      );
      await first.close();
      final original = File(dbPath).readAsBytesSync();
      final policy = ControlledStoragePolicy()..failPreparation = true;
      final reopened = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
        storagePolicy: policy,
      );
      try {
        await expectLater(
          reopened.load(),
          throwsA(isA<LocalStoragePreparationException>()),
        );
        expect(File(dbPath).readAsBytesSync(), orderedEquals(original));
        policy.failPreparation = false;
        final state = await reopened.load();
        expect(state.tasks.single.title, 'Keep existing data');
        expect(state.settings.focusMinutes, 40);
        expect(state.selectedTaskId, 'kept');
        expect(policy.directories, [dir.path, dir.path]);
      } finally {
        await reopened.close();
        dir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'a database is not created until privacy preparation succeeds',
    () async {
      final dir = Directory.systemTemp.createTempSync('poma-new-backup-test-');
      final dbPath = '${dir.path}/poma.db';
      final policy = ControlledStoragePolicy()..failPreparation = true;
      final repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
        storagePolicy: policy,
      );
      try {
        await expectLater(
          repository.load(),
          throwsA(isA<LocalStoragePreparationException>()),
        );
        expect(File(dbPath).existsSync(), isFalse);
        policy.failPreparation = false;
        await repository.save(
          SavedState(
            tasks: const [FocusTask(id: 'new', title: 'New task')],
          ),
        );
        expect((await repository.load()).tasks.single.title, 'New task');
      } finally {
        await repository.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
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

class ControlledStoragePolicy extends LocalStoragePolicy {
  bool failPreparation = false;
  final List<String> directories = [];

  @override
  Future<void> prepareDirectory(String directory) async {
    directories.add(directory);
    if (failPreparation) throw const LocalStoragePreparationException();
  }
}
