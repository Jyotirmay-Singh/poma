import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'alert_support.dart';
import 'support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  late Directory dir;
  late String path;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('poma-alert-db-');
    path = '${dir.path}/poma.db';
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> legacyDatabase({bool corrupt = false}) async {
    final timer = TimerEngine(
      settings: const TimerSettings(),
      now: FakeClock().reading,
    )..apply(TimerAction.start, FakeClock().reading);
    final json = timer.snapshot().toJson()
      ..remove('bootCount')
      ..remove('elapsedDeadlineMicros')
      ..remove('segment');
    if (corrupt) json['runId'] = null;
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE app_state (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE tasks (id TEXT PRIMARY KEY, title TEXT NOT NULL, done INTEGER NOT NULL, position INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE sessions (id TEXT PRIMARY KEY, started_at TEXT NOT NULL, ended_at TEXT NOT NULL, focus_seconds INTEGER NOT NULL, task_id TEXT, task_title TEXT)',
          );
          await db.execute(
            'CREATE INDEX sessions_ended_at ON sessions(ended_at)',
          );
          await db.insert('app_state', {
            'key': 'timer',
            'value': jsonEncode(json),
          });
          await db.insert('tasks', {
            'id': 'kept',
            'title': 'Private task',
            'done': 0,
            'position': 0,
          });
        },
      ),
    );
    await db.close();
  }

  test(
    'v1 migration retains running identity/tasks and durable action receipts survive reopen',
    () async {
      await legacyDatabase();
      final repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final original = await repository.load();
      expect(original.tasks.single.title, 'Private task');
      expect(original.timer!.status, RunStatus.running);
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        alerts: alerts,
      );
      expect(repository.databasePath, path);
      final saved = await repository.load();
      expect(saved.timer!.runId, original.timer!.runId);
      expect(saved.alerts.current!.runId, original.timer!.runId);
      expect(await repository.recordAlertReceipt('action:once:1:open'), isTrue);
      expect(
        await repository.recordAlertReceipt('action:once:1:open'),
        isFalse,
      );
      app.dispose();
      await app.flush();
      await repository.close();
      final reopened = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      expect(await reopened.recordAlertReceipt('action:once:1:open'), isFalse);
      expect(
        (await reopened.load()).alerts.current!.generation,
        saved.alerts.current!.generation,
      );
      await reopened.close();
    },
  );

  test(
    'invalid v1 snapshot rejects migration without rewriting database bytes',
    () async {
      await legacyDatabase(corrupt: true);
      final bytes = File(path).readAsBytesSync();
      final repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      await expectLater(repository.load(), throwsA(isA<StorageFailure>()));
      await repository.close();
      expect(File(path).readAsBytesSync(), orderedEquals(bytes));
      final db = await databaseFactoryFfi.openDatabase(path);
      expect(await db.getVersion(), 1);
      expect(
        await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE name='notification_state'",
        ),
        isEmpty,
      );
      await db.close();
    },
  );

  test(
    'completion, successor and alert cancellation roll back and retry together',
    () async {
      final repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      final clock = FakeClock()..bootCount = 4;
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      await app.toggleTimer();
      final before = await repository.load();
      final db = await databaseFactoryFfi.openDatabase(path);
      await db.execute(
        "CREATE TRIGGER fail_completion BEFORE INSERT ON sessions BEGIN SELECT RAISE(ABORT, 'injected'); END",
      );
      clock.advance(const Duration(minutes: 25));
      await app.reconcile();
      expect(app.saveError, isNotNull);
      final rolledBack = await repository.load();
      expect(rolledBack.timer!.runId, before.timer!.runId);
      expect(
        rolledBack.alerts.current!.generation,
        before.alerts.current!.generation,
      );
      expect(rolledBack.sessions, isEmpty);
      expect(
        alerts.pending,
        isEmpty,
      ); // safety cancellation despite failed save
      await db.execute('DROP TRIGGER fail_completion');
      await app.retrySave();
      final committed = await repository.load();
      expect(committed.sessions.single.id, before.timer!.runId);
      expect(committed.timer!.status, RunStatus.ready);
      expect(committed.alerts.current, isNull);
      await app.reconcile(forceAlerts: true);
      expect((await repository.load()).sessions.length, 1);
      app.dispose();
      await app.flush();
      await repository.close();
    },
  );
}
