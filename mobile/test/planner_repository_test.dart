import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/schema_migrations.dart';
import 'package:poma/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'native_probe_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  for (final version in [1, 2, 3]) {
    test(
      'v$version to v4 retains existing tasks, selection and history',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'poma-planner-upgrade-',
        );
        final path = '${directory.path}/poma.db';
        final database = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: version,
            onCreate: (db, _) => migrateSchema(db, 0, version),
          ),
        );
        final task = FocusTask(
          id: newLocalId(),
          title: 'Fictional retained task',
          done: true,
        );
        await database.insert('tasks', task.toRow(0));
        await database.insert('app_state', {
          'key': 'selectedTaskId',
          'value': task.id,
        });
        final session = FocusSession(
          id: newLocalId(),
          startedAt: DateTime.utc(2026, 11, 9, 9),
          endedAt: DateTime.utc(2026, 11, 9, 9, 25),
          focusSeconds: 1500,
          taskId: task.id,
          taskTitle: task.title,
        );
        await database.insert('sessions', {
          ...session.toRow(),
          if (version >= 3)
            'ended_at_utc_micros': session.endedAt.microsecondsSinceEpoch,
        });
        await database.close();
        final repository = SqliteRepository(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        try {
          final restored = await repository.loadInitial();
          expect(restored.tasks.single.toRow(0), task.toRow(0));
          expect(restored.selectedTaskId, task.id);
          expect(
            (await repository.readHistoryPage()).sessions.single.toRow(),
            session.toRow(),
          );
          expect(restored.planner.schedules, isEmpty);
          expect(restored.planner.preferences, isEmpty);
        } finally {
          await repository.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  test(
    'failed migration rolls back every v4 table and can be retried',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'poma-planner-migration-',
      );
      final path = '${directory.path}/poma.db';
      final database = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, _) => migrateSchema(db, 0, 3),
        ),
      );
      await database.execute('CREATE TABLE planner_operations (fixture TEXT)');
      await database.close();
      var repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      await expectLater(repository.loadInitial(), throwsA(isA<Object>()));
      await repository.close();
      final inspection = await databaseFactoryFfi.openDatabase(path);
      expect(await inspection.getVersion(), 3);
      expect(
        await inspection.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'planner_schedules'",
        ),
        isEmpty,
      );
      await inspection.execute('DROP TABLE planner_operations');
      await inspection.close();
      repository = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: path,
      );
      await repository.loadInitial();
      await repository.close();
      await directory.delete(recursive: true);
    },
  );

  for (final stage in ['beforeCommit', 'afterCommit']) {
    test(
      'planner owner exit $stage retains all task, link and operation rows together',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'poma-planner-process-',
        );
        final path = '${directory.path}/poma.db';
        final repository = SqliteRepository(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        await repository.loadInitial();
        await repository.close();
        try {
          var sdk = File(Platform.resolvedExecutable).parent;
          while (!File(
            '${sdk.path}/bin/cache/flutter_tools.snapshot',
          ).existsSync()) {
            if (sdk.parent.path == sdk.path) {
              throw StateError('Flutter SDK not found.');
            }
            sdk = sdk.parent;
          }
          final host = Directory('${directory.path}/probe')..createSync();
          for (final name in [
            'pubspec.yaml',
            'pubspec.lock',
            '.dart_tool/package_config.json',
            '.dart_tool/package_graph.json',
            '.flutter-plugins-dependencies',
            'test/probes/planner_crash_probe.dart',
            'test/support.dart',
          ]) {
            final source = File(name);
            if (source.existsSync()) {
              final target = File('${host.path}/$name');
              target.parent.createSync(recursive: true);
              source.copySync(target.path);
            }
          }
          for (final root in ['lib', 'assets']) {
            for (final source in Directory(
              root,
            ).listSync(recursive: true).whereType<File>()) {
              final target = File('${host.path}/${source.path}');
              target.parent.createSync(recursive: true);
              source.copySync(target.path);
            }
          }
          seedProbeNativeCache(host);
          final result = await Process.run(
            '${sdk.path}/bin/cache/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}',
            [
              '${sdk.path}/bin/cache/flutter_tools.snapshot',
              '--suppress-analytics',
              '--no-version-check',
              'test',
              '--no-pub',
              '--reporter',
              'json',
              '--dart-define=POMA_CRASH_PATH=$path',
              '--dart-define=POMA_CRASH_STAGE=$stage',
              'test/probes/planner_crash_probe.dart',
            ],
            workingDirectory: host.path,
          ).timeout(const Duration(seconds: 90));
          expect(result.exitCode, isNot(0));
          expect(
            File('$path.planner-stage').readAsStringSync(),
            stage,
            reason: '${result.stdout} ${result.stderr}',
          );
          final restored = await repository.loadInitial();
          final expected = stage == 'afterCommit' ? 1 : 0;
          expect(restored.tasks, hasLength(expected));
          expect(restored.planner.schedules, hasLength(expected));
          expect(restored.planner.operations, hasLength(expected));
          if (expected == 1) {
            final schedule = restored.planner.schedules.values.single;
            expect(schedule.taskId, restored.tasks.single.id);
            expect(
              restored.planner.operations.values.single.eventId,
              schedule.eventId,
            );
          }
        } finally {
          await repository.close();
          await directory.delete(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
