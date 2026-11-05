import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/focus_block_controller.dart';
import 'package:poma/domain/focus_blocks.dart';
import 'focus_blocks_test.dart' as f;

void main() {
  for (final stage in [
    'pending',
    'sending',
    'serverCommitted',
    'acknowledged',
  ]) {
    test(
      'W04 real process exit at $stage never replays a mutation',
      () async {
        final dir = Directory.systemTemp.createTempSync('poma-focus-process-');
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
          final host = Directory('${dir.path}/probe')..createSync();
          for (final name in [
            'pubspec.yaml',
            'pubspec.lock',
            '.dart_tool/package_config.json',
            '.dart_tool/package_graph.json',
            '.flutter-plugins-dependencies',
            'test/focus_blocks_test.dart',
            'test/probes/focus_write_crash_probe.dart',
          ]) {
            final source = File(name);
            if (source.existsSync()) {
              final target = File('${host.path}/$name');
              target.parent.createSync(recursive: true);
              source.copySync(target.path);
            }
          }
          for (final folder in ['assets', 'lib']) {
            for (final source in Directory(
              folder,
            ).listSync(recursive: true).whereType<File>()) {
              final target = File('${host.path}/${source.path}');
              target.parent.createSync(recursive: true);
              source.copySync(target.path);
            }
          }
          final process = await Process.run(
            '${sdk.path}/bin/cache/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}',
            [
              '${sdk.path}/bin/cache/flutter_tools.snapshot',
              '--suppress-analytics',
              '--no-version-check',
              'test',
              '--no-pub',
              '--reporter',
              'json',
              '--dart-define=POMA_FOCUS_CRASH_STAGE=$stage',
              '--dart-define=POMA_FOCUS_CRASH_DIRECTORY=${dir.path}',
              'test/probes/focus_write_crash_probe.dart',
            ],
            workingDirectory: host.path,
          ).timeout(const Duration(seconds: 90));
          expect(process.exitCode, isNot(0));
          expect(
            File('${dir.path}/crash-stage').readAsStringSync(),
            stage,
            reason: '${process.stdout} ${process.stderr}',
          );
          final server = f.GoogleStore();
          final savedServer = File('${dir.path}/server.json');
          if (savedServer.existsSync()) {
            for (final raw
                in jsonDecode(savedServer.readAsStringSync()) as List) {
              final event = FocusRemoteBlock(raw as Map<String, dynamic>);
              server.events[event.id] = event;
            }
          }
          final reopened = FocusBlockController(
            session: f.WriteSession(),
            store: f.JournalStore(dir),
            writer: server,
            time: f.Times(),
            now: () => f.instant,
          );
          await reopened.initialize();
          expect(server.inserts, 0);
          final operation = reopened.journal!.operations[f.block]!;
          expect(operation.eventId, focusEventId(f.block));
          await reopened.reconcile(f.block);
          expect(server.inserts, 0);
          if (stage == 'serverCommitted' || stage == 'acknowledged') {
            expect(server.events.length, 1);
            expect(
              reopened.journal!.operations[f.block]!.status,
              FocusOperationStatus.saved,
            );
          } else {
            expect(server.events, isEmpty);
            final preview = await reopened.retry(f.block);
            expect(server.inserts, 0);
            await reopened.confirm(preview);
            expect(server.events.length, 1);
            expect(server.events.keys.single, operation.eventId);
          }
          reopened.dispose();
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
