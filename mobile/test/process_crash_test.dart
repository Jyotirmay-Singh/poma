import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'support.dart';
import 'alert_support.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  for (final stage in ['beforeCommit', 'afterCommit']) {
    test(
      'owner process exit $stage preserves atomic completion and alert cancellation',
      () async {
        final dir = Directory.systemTemp.createTempSync('poma-crash-');
        final path = '${dir.path}/poma.db';
        final repository = SqliteRepository(
          factory: databaseFactoryFfi,
          databasePath: path,
        );
        try {
          final app = await AppController.create(
            repository,
            clock: FakeClock(),
            alerts: FakeAlerts(),
          );
          app.addTask('Crash snapshot');
          await app.flush();
          final started = await app.toggleTimer();
          final id = started.snapshot.runId;
          final deadline = started.snapshot.deadline;
          app.dispose();
          await repository.close();
          var sdk = File(Platform.resolvedExecutable).parent;
          while (!File(
            '${sdk.path}/bin/cache/flutter_tools.snapshot',
          ).existsSync()) {
            if (sdk.parent.path == sdk.path) {
              throw StateError('Flutter SDK not found for crash probe.');
            }
            sdk = sdk.parent;
          }
          final executable =
              '${sdk.path}/bin/cache/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}';
          // The parent has sqlite3.dll loaded on Windows. Give the child its own
          // Flutter build directory so native-asset preparation cannot delete it.
          final host = Directory('${dir.path}/probe')..createSync();
          for (final name in [
            'pubspec.yaml',
            'pubspec.lock',
            'assets/licenses/pomatez.txt',
            '.dart_tool/package_config.json',
            '.dart_tool/package_graph.json',
            '.flutter-plugins-dependencies',
            'test/support.dart',
            'test/alert_support.dart',
            'test/probes/crash_probe.dart',
          ]) {
            final source = File(name);
            if (source.existsSync()) {
              final target = File('${host.path}/$name');
              target.parent.createSync(recursive: true);
              source.copySync(target.path);
            }
          }
          for (final entity in Directory(
            'lib',
          ).listSync(recursive: true).whereType<File>()) {
            final target = File('${host.path}/${entity.path}');
            target.parent.createSync(recursive: true);
            entity.copySync(target.path);
          }
          final result = await Process.run(executable, [
            '${sdk.path}/bin/cache/flutter_tools.snapshot',
            'test',
            '--no-pub',
            '--reporter',
            'json',
            '--dart-define=POMA_CRASH_PATH=$path',
            '--dart-define=POMA_CRASH_STAGE=$stage',
            'test/probes/crash_probe.dart',
          ], workingDirectory: host.path).timeout(const Duration(seconds: 90));
          expect(
            result.exitCode,
            isNot(0),
            reason: 'Probe must terminate before its test can finish.',
          );
          final marker = File('$path.crash-stage');
          expect(
            marker.existsSync(),
            isTrue,
            reason: 'Probe output: ${result.stdout} ${result.stderr}',
          );
          expect(marker.readAsStringSync(), stage);
          final saved = await repository.loadInitial();
          final history = await repository.readHistoryPage();
          if (stage == 'beforeCommit') {
            expect(saved.timer!.runId, id);
            expect(saved.timer!.status, RunStatus.running);
            expect(history.sessions, isEmpty);
            expect(saved.alerts.current!.runId, id);
          } else {
            expect(saved.timer!.status, RunStatus.ready);
            expect(history.sessions.single.id, id);
            expect(saved.alerts.current, isNull);
          }
          final clock = FakeClock()..advance(const Duration(days: 3));
          final restored = await AppController.create(
            repository,
            clock: clock,
            alerts: FakeAlerts(),
          );
          await restored.loadHistory();
          await restored.reconcile();
          expect(restored.sessions.single.id, id);
          expect(restored.sessions.single.endedAt, deadline);
          expect(restored.sessions.single.taskTitle, 'Crash snapshot');
          expect(restored.timer.phase, FocusPhase.shortBreak);
          expect(restored.timer.status, RunStatus.ready);
          restored.dispose();
          await repository.close();
          expect((await repository.readHistoryPage()).sessions.length, 1);
        } finally {
          await repository.close();
          dir.deleteSync(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
