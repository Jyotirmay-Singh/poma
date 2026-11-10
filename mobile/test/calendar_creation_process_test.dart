import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/domain/calendar_event_creation.dart';
import 'calendar_creation_support.dart';
import 'native_probe_support.dart';

void main() {
  for (final stage in ['draft', 'sending', 'serverCommitted', 'acknowledged']) {
    test(
      'real process exit at $stage restores the durable identity without replay',
      () async {
        final temp = Directory.systemTemp.absolute;
        final dir = temp.createTempSync('poma-creation-process-');
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
          ]) {
            final source = File(name);
            if (source.existsSync()) {
              final target = File('${host.path}/$name');
              target.parent.createSync(recursive: true);
              source.copySync(target.path);
            }
          }
          for (final folder in ['assets', 'lib', 'test']) {
            for (final source in Directory(
              folder,
            ).listSync(recursive: true).whereType<File>()) {
              final target = File('${host.path}/${source.path}');
              target.parent.createSync(recursive: true);
              source.copySync(target.path);
            }
          }
          seedProbeNativeCache(host);
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
              '--dart-define=POMA_CREATION_CRASH_STAGE=$stage',
              '--dart-define=POMA_CREATION_CRASH_DIRECTORY=${dir.path}',
              'test/probes/calendar_creation_crash_probe.dart',
            ],
            workingDirectory: host.path,
          ).timeout(const Duration(seconds: 90));
          expect(
            process.exitCode,
            isNot(0),
            reason: '${process.stdout} ${process.stderr}',
          );
          expect(File('${dir.path}/crash-stage').readAsStringSync(), stage);
          final id = File('${dir.path}/draft-id').readAsStringSync();
          final server = CreationGoogle(directory: dir);
          final serverFile = File('${dir.path}/server.json');
          if (serverFile.existsSync()) {
            final data = jsonDecode(serverFile.readAsStringSync()) as Map;
            server.events.addAll(
              data.map(
                (k, v) =>
                    MapEntry(k as String, Map<String, dynamic>.from(v as Map)),
              ),
            );
          }
          final r = await creationRig(
            store: CreationMemory(directory: dir),
            google: server,
          );
          try {
            expect(server.inserts, 0);
            final draft = r.controller.journal!.drafts[id]!;
            if (stage == 'draft') {
              expect(r.controller.journal!.operations, isEmpty);
              expect(server.events, isEmpty);
              expect(draft.title, 'Evening planning');
            } else {
              final op = r.controller.journal!.operations[id]!;
              expect(op.eventId, creationEventId(id));
              await r.controller.check(op);
              expect(server.inserts, 0);
              if (stage == 'sending') {
                expect(server.events, isEmpty);
                expect(
                  r.controller.journal!.operations[id]!.retryAllowed,
                  true,
                );
                await r.controller.submit(draft, op.intent, retry: true);
                expect(server.inserts, 1);
              }
              expect(server.events.length, 1);
              expect(server.events.keys.single, op.eventId);
              expect(
                r.controller.journal!.operations[id]!.state,
                CalendarCreationState.saved,
              );
            }
          } finally {
            r.dispose();
          }
        } finally {
          if (!dir.absolute.path.startsWith(
            '${temp.path}${Platform.pathSeparator}poma-creation-process-',
          )) {
            throw StateError('Unexpected isolated test directory.');
          }
          dir.deleteSync(recursive: true);
        }
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }
}
