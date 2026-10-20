import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_repository.dart';
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
        now: FakeClock().reading,
      )..apply(TimerAction.start, FakeClock().reading);
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

  test(
    'failed SQLite completion rolls back timer and history; retry survives reopen',
    () async {
      final dir = Directory.systemTemp.createTempSync('poma-transaction-test-');
      final dbPath = '${dir.path}/poma.db';
      final repo = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      final clock = FakeClock();
      final app = await AppController.create(repo, clock: clock);
      try {
        app.addTask('Snapshot title');
        await app.flush();
        final started = await app.toggleTimer();
        final id = started.snapshot.runId;
        final raw = await databaseFactoryFfi.openDatabase(
          dbPath,
          options: OpenDatabaseOptions(singleInstance: false),
        );
        try {
          await raw.execute(
            "CREATE TRIGGER reject_completion BEFORE INSERT ON sessions BEGIN SELECT RAISE(ABORT, 'test failure'); END",
          );
          clock.advance(const Duration(days: 2));
          final result = await app.reconcile();
          expect(result.persistence, PersistenceOutcome.failed);
          expect(app.timer.status, RunStatus.ready);
          final persisted = await repo.load();
          expect(persisted.timer!.runId, id);
          expect(persisted.timer!.status, RunStatus.running);
          expect(persisted.sessions, isEmpty);
          await raw.execute('DROP TRIGGER reject_completion');
        } finally {
          await raw.close();
        }
        app.retrySave();
        await app.flush();
        await repo.close();
        final reopened = SqliteRepository(
          factory: databaseFactoryFfi,
          databasePath: dbPath,
        );
        try {
          final restored = await AppController.create(
            reopened,
            clock: FakeClock(clock.utcNow.add(const Duration(days: 1))),
          );
          await restored.loadHistory();
          expect(restored.sessions, hasLength(1));
          expect(restored.sessions.single.id, id);
          expect(restored.sessions.single.taskTitle, 'Snapshot title');
          expect(restored.sessions.single.endedAt, started.snapshot.deadline);
          expect(restored.timer.phase, FocusPhase.shortBreak);
          expect(restored.timer.status, RunStatus.ready);
          expect(restored.timer.completedRounds, 1);
          await restored.reconcile();
          expect(restored.sessions, hasLength(1));
          restored.dispose();
        } finally {
          await reopened.close();
        }
      } finally {
        app.dispose();
        await repo.close();
        dir.deleteSync(recursive: true);
      }
    },
  );

  test(
    'malformed persisted timer fails startup without rewriting SQLite bytes',
    () async {
      final dir = Directory.systemTemp.createTempSync(
        'poma-invalid-timer-test-',
      );
      final dbPath = '${dir.path}/poma.db';
      final repo = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      final clock = FakeClock();
      final timer = TimerEngine(
        settings: const TimerSettings(),
        now: clock.reading,
      )..apply(TimerAction.start, clock.reading);
      try {
        await repo.save(
          SavedState(
            timer: timer.snapshot(),
            tasks: const [FocusTask(id: 'kept', title: 'Keep data')],
          ),
        );
        await repo.close();
        final raw = await databaseFactoryFfi.openDatabase(dbPath);
        await raw.update(
          'app_state',
          {
            'value': jsonEncode({
              ...timer.snapshot().toJson(),
              'remainingMicros': -1,
            }),
          },
          where: 'key = ?',
          whereArgs: ['timer'],
        );
        await raw.close();
        final bytes = File(dbPath).readAsBytesSync();
        await expectLater(
          AppController.create(repo, clock: clock),
          throwsA(isA<StorageFailure>()),
        );
        await repo.close();
        expect(File(dbPath).readAsBytesSync(), orderedEquals(bytes));
        final inspect = await databaseFactoryFfi.openDatabase(dbPath);
        expect((await inspect.query('tasks')).single['title'], 'Keep data');
        await inspect.close();
      } finally {
        await repo.close();
        dir.deleteSync(recursive: true);
      }
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
