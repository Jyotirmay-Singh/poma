import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support.dart';
import 'alert_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory directory;
  late String path;
  late SqliteRepository repository;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('poma-durable-');
    path = '${directory.path}/poma.db';
    repository = SqliteRepository(
      factory: databaseFactoryFfi,
      databasePath: path,
    );
  });
  tearDown(() async {
    await repository.close();
    directory.deleteSync(recursive: true);
  });

  Future<Database> raw() => databaseFactoryFfi.openDatabase(path);
  Future<void> fixture(int version) async {
    final db = await raw();
    for (var v = 1; v <= version; v++) {
      for (final sql in (await File(
        'test/fixtures/v$v.sql',
      ).readAsString()).split(';')) {
        if (sql.trim().isNotEmpty) await db.execute(sql);
      }
    }
    await db.close();
  }

  FocusSession session(String id, [DateTime? end]) => FocusSession(
    id: id,
    startedAt: DateTime.utc(2026, 10, 20),
    endedAt: end ?? DateTime.utc(2026, 10, 20, 0, 25),
    focusSeconds: 1500,
    taskId: 'task',
    taskTitle: 'Original title',
  );
  Future<LocalCommit> request(List<LocalChange> changes) async => LocalCommit(
    id: newLocalId(),
    expectedRevision: (await repository.loadInitial()).revision,
    changes: changes,
  );

  for (final version in [1, 2]) {
    test(
      'fixed v$version fixture migrates, preserves identities/order/snapshots and reopens',
      () async {
        await fixture(version);
        final state = await repository.loadInitial();
        expect(state.tasks.map((t) => t.id), ['task-b', 'task-a']);
        expect(state.settings.appearance, 'dark');
        expect(state.timer!.runId, 'legacy-run');
        expect(state.timer!.remainingMicros, 123456789);
        expect(state.timer!.taskTitle, 'Original title');
        expect(state.sessions, isEmpty);
        final page = await repository.readHistoryPage();
        expect(page.sessions.map((s) => s.id), ['legacy-b', 'legacy-a']);
        expect(page.sessions.last.taskTitle, 'Historic title');
        final db = await raw();
        expect(await db.getVersion(), 3);
        expect(
          (await db.query(
            'tasks',
            orderBy: 'position',
          )).map((t) => t['position']),
          [0, 7],
        );
        if (version == 2) {
          expect(state.alerts.previous!.generation, 7);
          expect(
            await repository.recordAlertReceipt('action:old-alert:7:open'),
            isFalse,
          );
        }
        await repository.close();
        expect((await repository.loadInitial()).timer!.runId, 'legacy-run');
        expect((await repository.readHistoryPage()).sessions.length, 2);
      },
    );
  }

  test('fresh schema is identical to v1 migration', () async {
    await repository.loadInitial();
    final db = await raw();
    final fresh = await db.rawQuery(
      "SELECT name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    await repository.close();
    final otherPath = '${directory.path}/legacy.db';
    final other = await databaseFactoryFfi.openDatabase(otherPath);
    for (final sql in (await File(
      'test/fixtures/v1.sql',
    ).readAsString()).split(';')) {
      if (sql.trim().isNotEmpty) await other.execute(sql);
    }
    await other.close();
    final migrated = SqliteRepository(
      factory: databaseFactoryFfi,
      databasePath: otherPath,
    );
    await migrated.loadInitial();
    final inspect = await databaseFactoryFfi.openDatabase(otherPath);
    expect(
      await inspect.rawQuery(
        "SELECT name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name",
      ),
      fresh,
    );
    await migrated.close();
  });

  test(
    'migration fails after partial backfill and rolls back schema/data/version',
    () async {
      await fixture(1);
      final db = await raw();
      final batch = db.batch();
      for (var i = 0; i < 260; i++) {
        batch.insert(
          'sessions',
          session('m${i.toString().padLeft(4, '0')}').toRow(),
        );
      }
      batch.insert('sessions', {
        ...session('zz-bad').toRow(),
        'ended_at': 'not-a-date-private-sentinel',
      });
      await batch.commit(noResult: true);
      await db.close();
      final bytes = File(path).readAsBytesSync();
      await expectLater(
        repository.loadInitial(),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.migration,
          ),
        ),
      );
      await repository.close();
      expect(File(path).readAsBytesSync(), bytes);
      final inspect = await raw();
      expect(await inspect.getVersion(), 1);
      expect(
        await inspect.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='storage_meta'",
        ),
        isEmpty,
      );
      await inspect.delete('sessions', where: 'id = ?', whereArgs: ['zz-bad']);
      await inspect.close();
      expect((await repository.readHistoryPage()).sessions.length, 50);
    },
  );

  test(
    'future version and unreadable database are retained without reset',
    () async {
      await repository.loadInitial();
      final db = await raw();
      await db.setVersion(99);
      await repository.close();
      final bytes = File(path).readAsBytesSync();
      await expectLater(
        repository.loadInitial(),
        throwsA(isA<StorageFailure>()),
      );
      await repository.close();
      expect(File(path).readAsBytesSync(), bytes);
      final corruptPath = '${directory.path}/corrupt.db';
      File(
        corruptPath,
      ).writeAsStringSync('private-unreadable-database-sentinel');
      final corrupt = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: corruptPath,
      );
      await expectLater(corrupt.loadInitial(), throwsA(isA<StorageFailure>()));
      await corrupt.close();
      expect(
        File(corruptPath).readAsStringSync(),
        'private-unreadable-database-sentinel',
      );
    },
  );

  test(
    'malformed settings/task/history produce safe errors and preserve data',
    () async {
      await repository.loadInitial();
      final db = await raw();
      await db.insert('app_state', {
        'key': 'settings',
        'value': jsonEncode({
          'focusMinutes': 0,
          'appearance': 'private-sentinel',
        }),
      });
      await expectLater(
        repository.loadInitial(),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.toString(),
            'safe error',
            isNot(contains('private-sentinel')),
          ),
        ),
      );
      await db.delete('app_state');
      await db.insert('tasks', {
        'id': 'bad',
        'title': 'private-sentinel',
        'done': 2,
        'position': 0,
      });
      await expectLater(
        repository.loadInitial(),
        throwsA(isA<StorageFailure>()),
      );
      await db.delete('tasks');
      await db.insert('sessions', {
        ...session('bad').toRow(),
        'ended_at_utc_micros': 0,
      });
      expect((await repository.loadInitial()).sessions, isEmpty);
      await expectLater(
        repository.readHistoryPage(),
        throwsA(isA<StorageFailure>()),
      );
      expect((await db.query('sessions')).single['id'], 'bad');
    },
  );

  test(
    'ordinary edits touch only dirty task rows and never reinsert known history',
    () async {
      await repository.save(
        SavedState(
          tasks: const [
            FocusTask(id: 'untouched', title: 'Keep'),
            FocusTask(id: 'edited', title: 'Edit'),
          ],
          sessions: [session('historic')],
        ),
      );
      final db = await raw();
      await db.execute(
        "CREATE TRIGGER protect_delete BEFORE DELETE ON tasks WHEN OLD.id='untouched' BEGIN SELECT RAISE(ABORT,'unexpected rewrite'); END",
      );
      await db.execute(
        "CREATE TRIGGER protect_update BEFORE UPDATE ON tasks WHEN OLD.id='untouched' BEGIN SELECT RAISE(ABORT,'unexpected update'); END",
      );
      await db.execute(
        "CREATE TRIGGER protect_history BEFORE INSERT ON sessions WHEN NEW.id='historic' BEGIN SELECT RAISE(ABORT,'unexpected history attempt'); END",
      );
      final app = await AppController.create(repository, clock: FakeClock());
      app.editTask('edited', 'Renamed');
      app.toggleTask('edited');
      app.addTask('Append');
      await app.flush();
      expect(app.saveError, isNull);
      expect((await repository.loadInitial()).tasks.map((t) => t.title), [
        'Keep',
        'Renamed',
        'Append',
      ]);
      app.deleteTask('edited');
      await app.flush();
      expect(
        (await db.query(
          'tasks',
          orderBy: 'position',
        )).map((t) => t['position']),
        [0, 2],
      );
      app.dispose();
    },
  );

  test(
    '100000-row history has indexed bounded pages, ties and reversible cursors',
    () async {
      await repository.loadInitial();
      final db = await raw();
      final start = DateTime.utc(2026, 1, 1).microsecondsSinceEpoch;
      await db.transaction((txn) async {
        await txn.rawInsert(
          "WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<100000) INSERT INTO sessions(id,started_at,ended_at,focus_seconds,ended_at_utc_micros) SELECT printf('%06d',x),'2026-01-01T00:00:00.000Z','2026-01-01T00:00:00.000Z',1500,? FROM n",
          [start],
        );
      });
      final initial = await repository.loadInitial();
      expect(initial.sessions, isEmpty);
      final first = await repository.readHistoryPage();
      expect(first.sessions.length, 50);
      expect(first.hasNewer, isFalse);
      expect(first.hasOlder, isTrue);
      final second = await repository.readHistoryPage(
        before: HistoryCursor.forSession(first.sessions.last),
      );
      expect(second.sessions.length, 50);
      expect(
        second.sessions
            .map((s) => s.id)
            .toSet()
            .intersection(first.sessions.map((s) => s.id).toSet()),
        isEmpty,
      );
      final back = await repository.readHistoryPage(
        after: HistoryCursor.forSession(second.sessions.first),
      );
      expect(back.sessions.map((s) => s.id), first.sessions.map((s) => s.id));
      final plan = await db.rawQuery(
        'EXPLAIN QUERY PLAN SELECT id FROM sessions WHERE ended_at_utc_micros <= ? AND (ended_at_utc_micros < ? OR id < ?) ORDER BY ended_at_utc_micros DESC,id DESC LIMIT 51',
        [start, start, '099000'],
      );
      expect(plan.toString(), contains('SEARCH'));
      expect(plan.toString(), contains('sessions_end_id'));
      final app = await AppController.create(repository, clock: FakeClock());
      expect(app.sessions, isEmpty); // No startup history fetch.
      await app.loadHistory();
      expect(app.sessions.length, 50);
      app.dispose();
    },
  );

  test(
    'SQLite FULL rolls back all rows and same commit retries after space is available',
    () async {
      await repository.loadInitial();
      final db = await raw();
      final pages =
          (await db.rawQuery('PRAGMA page_count')).single.values.single as int;
      await db.rawQuery('PRAGMA max_page_count = $pages');
      final change = LocalChange(
        state: SavedState(settings: const TimerSettings(appearance: 'dark')),
        tasks: List.generate(
          500,
          (i) => FocusTask(id: 'task-$i', title: 'x' * 160),
        ),
      );
      final commit = await request([change]);
      await expectLater(
        repository.commit(commit),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.full,
          ),
        ),
      );
      expect((await repository.loadInitial()).tasks, isEmpty);
      expect((await repository.loadInitial()).revision, 0);
      await db.rawQuery('PRAGMA max_page_count = 1000000');
      expect(await repository.commit(commit), 1);
      expect(await repository.commit(commit), 1);
      await repository.close();
      final reopened = await repository.loadInitial();
      expect(reopened.tasks.length, 500);
      expect(reopened.settings.appearance, 'dark');
    },
  );

  test(
    'rollback, duplicate completion identity and conflicting content never advance partially',
    () async {
      final commit = await request([
        LocalChange(state: SavedState(), completions: [session('once')]),
      ]);
      expect(await repository.commit(commit), 1);
      expect(await repository.commit(commit), 1);
      await repository.commit(
        await request([
          LocalChange(state: SavedState(), completions: [session('once')]),
        ]),
      );
      final conflict = await request([
        LocalChange(
          state: SavedState(settings: const TimerSettings(appearance: 'dark')),
          completions: [session('once', DateTime.utc(2026, 10, 21))],
        ),
      ]);
      await expectLater(
        repository.commit(conflict),
        throwsA(
          isA<StorageFailure>().having(
            (e) => e.kind,
            'kind',
            StorageFailureKind.conflict,
          ),
        ),
      );
      expect((await repository.loadInitial()).settings.appearance, 'system');
      expect((await repository.readHistoryPage()).sessions.length, 1);
      await expectLater(
        repository.commit(commit),
        throwsA(isA<StorageFailure>()),
      );
    },
  );

  test(
    'UTC range summaries honor midnight, timezone regrouping and 23/25 hour days',
    () async {
      await repository.save(
        SavedState(
          sessions: [
            session('before', DateTime.utc(2026, 10, 20, 23, 59, 59, 999, 999)),
            session('midnight', DateTime.utc(2026, 10, 21)),
            session('after', DateTime.utc(2026, 10, 21, 0, 0, 0, 0, 1)),
          ],
        ),
      );
      final utc = await repository.readDaySummaries([
        DayRange(
          DateTime(2026, 10, 20),
          DateTime.utc(2026, 10, 20),
          DateTime.utc(2026, 10, 21),
        ),
      ]);
      expect(utc.single.count, 1);
      final west = await repository.readDaySummaries([
        DayRange(
          DateTime(2026, 10, 20),
          DateTime.utc(2026, 10, 20, 5),
          DateTime.utc(2026, 10, 21, 5),
        ),
      ]);
      expect(west.single.count, 3);
      for (final hours in [23, 25]) {
        final end = DateTime.utc(2026, 10, 21);
        final result = await repository.readDaySummaries([
          DayRange(
            DateTime(2026, 10, 20),
            end.subtract(Duration(hours: hours)),
            end,
          ),
        ]);
        expect(result.single.count, 1);
      }
    },
  );

  test(
    'failed completion followed by task edits retries every delta, then deletion cannot resurrect it',
    () async {
      final memory = MemoryRepository();
      final clock = FakeClock();
      final app = await AppController.create(memory, clock: clock);
      final run = (await app.toggleTimer()).snapshot.runId;
      memory.failWrites = true;
      clock.advance(const Duration(days: 3));
      await app.reconcile();
      app.addTask('Later edit');
      await app.flush();
      expect(app.saveError, contains('Unsaved'));
      await app.deleteHistory();
      memory.failWrites = false;
      await app.retrySave();
      await app.flush();
      expect(memory.state.tasks.single.title, 'Later edit');
      expect(memory.state.sessions, isEmpty);
      expect(memory.state.timer!.status, RunStatus.ready);
      await app.handleTimerAction(TimerAction.pause, runId: run!);
      expect(memory.state.sessions, isEmpty);
      app.dispose();
    },
  );

  test('delayed save cannot overtake a later task edit or reset', () async {
    final memory = GatedRepository();
    final app = await AppController.create(memory, clock: FakeClock());
    memory.gate = Completer<void>();
    app.addTask('First');
    await Future<void>.delayed(Duration.zero);
    final id = app.tasks.single.id;
    app.editTask(id, 'Newest');
    expect(memory.calls, 1);
    memory.gate!.complete();
    await app.flush();
    expect(memory.state.tasks.single.title, 'Newest');
    expect(await app.deleteAllLocalData(), isTrue);
    expect(memory.state.tasks, isEmpty);
    app.dispose();
  });

  test(
    'commit succeeded but acknowledgement failed retries the exact identity once',
    () async {
      final memory = GatedRepository()..loseAcknowledgement = true;
      final app = await AppController.create(memory, clock: FakeClock());
      app.addTask('Kept');
      await app.flush();
      expect(app.saveError, isNotNull);
      await app.retrySave();
      expect(memory.state.tasks.length, 1);
      expect(memory.ids.take(2).toSet().length, 1);
      expect(app.saveError, isNull);
      app.dispose();
    },
  );

  test(
    'full reset abandons strict timer and unfinished native cleanup resumes on reopen',
    () async {
      final alerts = FakeAlerts();
      final clock = FakeClock();
      final app = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      app.addTask('Private');
      await app.updateSettings(
        const TimerSettings(strictMode: true, appearance: 'dark'),
      );
      final run = (await app.toggleTimer()).snapshot.runId;
      alerts.failBefore = true;
      expect(await app.deleteAllLocalData(), isFalse);
      expect((await repository.loadInitial()).cleanupPending, isTrue);
      expect((await repository.loadInitial()).tasks, isEmpty);
      expect(app.timer.status, RunStatus.ready);
      app.dispose();
      await repository.close();
      final repaired = FakeAlerts();
      final restored = await AppController.create(
        repository,
        clock: clock,
        alerts: repaired,
      );
      expect(restored.cleanupPending, isFalse);
      expect((await repository.loadInitial()).cleanupPending, isFalse);
      await restored.handleTimerAction(TimerAction.resume, runId: run!);
      expect(restored.timer.status, RunStatus.ready);
      expect((await repository.readHistoryPage()).sessions, isEmpty);
      expect(restored.settings.appearance, 'system');
      restored.dispose();
    },
  );

  test(
    'close/reopen retains settings, task order and history without any remote service',
    () async {
      final clock = FakeClock();
      final app = await AppController.create(repository, clock: clock);
      app.addTask('First');
      app.addTask('Second');
      await app.flush();
      final id = app.tasks.first.id;
      await app.updateSettings(
        const TimerSettings(focusMinutes: 1, appearance: 'dark'),
      );
      await app.toggleTimer();
      app.editTask(id, 'Renamed');
      app.deleteTask(id);
      clock.advance(const Duration(minutes: 1));
      await app.reconcile();
      app.dispose();
      await repository.close();
      final restored = await AppController.create(repository, clock: clock);
      expect(restored.settings.appearance, 'dark');
      expect(restored.tasks.single.title, 'Second');
      expect(restored.sessions, isEmpty);
      await restored.loadHistory();
      expect(restored.sessions.single.taskTitle, 'First');
      expect(restored.sessions.single.taskId, id);
      expect(restored.timer.phase, FocusPhase.shortBreak);
      expect(restored.timer.status, RunStatus.ready);
      restored.dispose();
    },
  );

  test('confirmed reset supersedes an earlier failed task insert', () async {
    await repository.loadInitial();
    final db = await raw();
    await db.execute(
      "CREATE TRIGGER reject_old_task BEFORE INSERT ON tasks BEGIN SELECT RAISE(ABORT,'injected failure'); END",
    );
    final app = await AppController.create(repository, clock: FakeClock());
    app.addTask('Unsaved');
    await app.flush();
    expect(app.saveError, isNotNull);
    expect(await app.deleteAllLocalData(), isTrue);
    expect((await repository.loadInitial()).tasks, isEmpty);
    expect(app.saveError, isNull);
    app.dispose();
  });

  test(
    'reset resolves uncertain commit without resurrecting old task contents',
    () async {
      var fail = true;
      final uncertain = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
        commitObserver: (stage) async {
          if (stage == 'afterCommit' && fail) {
            fail = false;
            throw const StorageFailure(StorageFailureKind.write);
          }
        },
      );
      final app = await AppController.create(uncertain, clock: FakeClock());
      app.addTask('Committed but unacknowledged');
      await app.flush();
      expect(app.saveError, isNotNull);
      expect(await app.deleteAllLocalData(), isTrue);
      expect((await uncertain.loadInitial()).tasks, isEmpty);
      expect(app.saveError, isNull);
      app.dispose();
      await uncertain.close();
    },
  );

  test('malformed migration JSON never reaches diagnostic logs', () async {
    await fixture(1);
    final db = await raw();
    await db.update(
      'app_state',
      {'value': 'private-log-sentinel{malformed'},
      where: 'key = ?',
      whereArgs: ['timer'],
    );
    await db.close();
    final logs = <String>[];
    await runZoned(
      () async {
        await expectLater(
          repository.loadInitial(),
          throwsA(isA<StorageFailure>()),
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, message) {
          logs.add(message);
        },
      ),
    );
    expect(logs.join(), isNot(contains('private-log-sentinel')));
  });

  test(
    'task edits dispatched after a reset survive the reset boundary',
    () async {
      final memory = GatedRepository();
      final app = await AppController.create(memory, clock: FakeClock());
      app.addTask('Before reset');
      await app.flush();
      memory.gate = Completer<void>();
      final reset = app.deleteAllLocalData();
      app.addTask('After reset');
      await Future<void>.delayed(Duration.zero);
      memory.gate!.complete();
      expect(await reset, isTrue);
      await app.flush();
      expect(memory.state.tasks.single.title, 'After reset');
      app.dispose();
    },
  );
}

class GatedRepository extends MemoryRepository {
  Completer<void>? gate;
  bool loseAcknowledgement = false;
  int calls = 0;
  final ids = <String>[];
  @override
  Future<int> commit(LocalCommit commit) async {
    calls++;
    ids.add(commit.id);
    final wait = gate;
    if (wait != null) await wait.future;
    final result = await super.commit(commit);
    if (loseAcknowledgement) {
      loseAcknowledgement = false;
      throw const StorageFailure(StorageFailureKind.write);
    }
    return result;
  }
}
