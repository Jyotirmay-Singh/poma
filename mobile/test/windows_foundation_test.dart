import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/local_storage_policy.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/domain/alert_state.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/settings_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'desktop_test.dart' show FakeShell;
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory folder;
  late NativeWindowsHost host;
  late DesktopEnvironment environment;
  final repositories = <SqliteRepository>[];
  const channel = MethodChannel('poma-windows-foundation-test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<SqliteRepository> open() async {
    final repository = await host.repository(environment);
    repositories.add(repository);
    return repository;
  }

  setUp(() {
    folder = Directory.systemTemp.createTempSync('poma-windows-foundation-');
    host = NativeWindowsHost(channel: channel);
    environment = DesktopEnvironment(
      dataDirectory: path.join(folder.path, 'new-profile'),
      version: '1.0.0.2010',
      packaged: false,
    );
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(channel, null);
    for (final repository in repositories) {
      await repository.close();
    }
    repositories.clear();
    await folder.delete(recursive: true);
  });

  test(
    'production Windows factory creates and reopens durable timer data',
    () async {
      final first = await open();
      expect(first.factory, same(databaseFactoryFfi));
      expect(
        first.databasePath,
        path.join(environment.dataDirectory, 'databases', 'poma.db'),
      );
      final clock =
          FakeClock(); // Windows intentionally has no persisted boot ID.
      var app = await AppController.create(first, clock: clock);
      await app.setForeground(false);
      app.addTask('Fictional Windows task');
      await app.flush();
      final task = app.tasks.single;
      app.selectTask(task.id);
      await app.updateSettings(
        const TimerSettings(focusMinutes: 1, appearance: 'dark'),
      );
      await app.toggleTimer();
      final run = app.timer.runId;
      clock.advance(const Duration(seconds: 7, microseconds: 123));
      await app.toggleTimer();
      final paused = app.timer.snapshot().toJson();
      await app.flush();
      app.dispose();
      await first.close();

      final second = await open();
      app = await AppController.create(second, clock: clock);
      await app.setForeground(false);
      expect(app.timer.snapshot().toJson(), paused);
      expect(app.tasks.single.id, task.id);
      expect(app.settings.appearance, 'dark');
      await app.toggleTimer();
      expect(app.timer.runId, run);
      final deadline = app.timer.snapshot().deadline;
      await app.flush();
      app.dispose();
      await second.close();

      clock.advance(const Duration(days: 2));
      final third = await open();
      app = await AppController.create(third, clock: clock);
      addTearDown(app.dispose);
      await app.setForeground(false);
      await app.reconcile();
      await app.loadHistory();
      expect(app.sessions.single.id, run);
      expect(app.sessions.single.endedAt, deadline);
      expect(app.sessions.single.taskTitle, task.title);
      expect(app.sessions.single.focusSeconds, 60);
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.ready);
      await app.reconcile();
      expect((await third.readHistoryPage()).sessions, hasLength(1));
    },
  );

  test(
    'blocked production directory gives a safe retryable storage failure',
    () async {
      await Directory(environment.dataDirectory).create(recursive: true);
      final blocker = File(path.join(environment.dataDirectory, 'databases'));
      await blocker.writeAsString('retain this fictional sentinel');
      await expectLater(open(), throwsA(isA<StorageFailure>()));
      expect(await blocker.readAsString(), 'retain this fictional sentinel');
      await blocker.delete();
      expect((await (await open()).loadInitial()).tasks, isEmpty);
    },
  );

  for (final futureSchema in [false, true]) {
    test(
      'production factory retains ${futureSchema ? 'future schema' : 'corrupt database'}',
      () async {
        final repository = await open();
        final file = File(repository.databasePath!);
        if (futureSchema) {
          final db = await repository.factory.openDatabase(file.path);
          await db.execute('PRAGMA user_version = 999');
          await db.close();
        } else {
          await file.writeAsString('fictional-unreadable-sentinel');
        }
        final before = await file.readAsBytes();
        await expectLater(
          repository.loadInitial(),
          throwsA(isA<StorageFailure>()),
        );
        await repository.close();
        expect(await file.readAsBytes(), orderedEquals(before));
      },
    );
  }

  test(
    'production SQLite FULL rolls back and retries without replacing data',
    () async {
      final repository = await open();
      final initial = await repository.loadInitial();
      // Use the production connection: max_page_count is connection-local.
      final db = await repository.factory.openDatabase(
        repository.databasePath!,
      );
      final pages = (await db.rawQuery(
        'PRAGMA page_count',
      )).single.values.single;
      await db.rawQuery('PRAGMA max_page_count = $pages');
      final commit = LocalCommit(
        id: 'windows-full-retry',
        expectedRevision: initial.revision,
        changes: [
          LocalChange(
            state: SavedState(
              settings: const TimerSettings(appearance: 'dark'),
            ),
            tasks: List.generate(
              500,
              (i) => FocusTask(id: 'fictional-$i', title: 'x' * 160),
            ),
          ),
        ],
      );
      await expectLater(
        repository.commit(commit),
        throwsA(
          isA<StorageFailure>().having(
            (error) => error.kind,
            'kind',
            StorageFailureKind.full,
          ),
        ),
      );
      expect((await repository.loadInitial()).tasks, isEmpty);
      expect((await repository.loadInitial()).revision, initial.revision);
      await db.rawQuery('PRAGMA max_page_count = 1000000');
      expect(await repository.commit(commit), initial.revision + 1);
      expect(await repository.commit(commit), initial.revision + 1);
      await repository.close();
      expect((await (await open()).loadInitial()).tasks, hasLength(500));
    },
  );

  test(
    'Windows storage policy never calls the mobile backup channel',
    () async {
      const storageChannel = MethodChannel('poma-forbidden-mobile-storage');
      messenger.setMockMethodCallHandler(storageChannel, (_) async {
        fail('Windows must not invoke an iOS storage operation');
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(storageChannel, null),
      );
      await LocalStoragePolicy(
        platform: TargetPlatform.windows,
        channel: storageChannel,
      ).prepareDirectory(environment.dataDirectory);
    },
  );

  for (final availability in [
    AlertAvailability.unavailable,
    AlertAvailability.denied,
    AlertAvailability.failed,
  ]) {
    testWidgets('Windows $availability is visible and never blocks a timer', (
      tester,
    ) async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'synchronizeAlerts') return availability.name;
        if (call.method == 'responses') return <Object>[];
        return null;
      });
      final alerts = WindowsLocalAlerts(host);
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
        alerts: alerts,
        completionPresenter: alerts,
      );
      final desktop = DesktopController(app, FakeShell(), environment);
      addTearDown(() {
        desktop.dispose();
        app.dispose();
      });
      await desktop.initialize();
      await app.setCompletionAlerts(true);
      await tester.pumpWidget(PomaApp(controller: app, desktop: desktop));
      desktop.navigate(3);
      await tester.pumpAndSettle();
      final text = switch (availability) {
        AlertAvailability.denied =>
          'Completion alerts are blocked in Windows notification settings. Your timer still works.',
        AlertAvailability.failed =>
          'Completion alert could not be registered. Your timer is kept. Try again.',
        _ => 'Completion alerts are unavailable. Your timer still works.',
      };
      await tester.scrollUntilVisible(
        find.text(text),
        250,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(find.text(text), findsOneWidget);
      await app.toggleTimer();
      expect(app.timer.status, RunStatus.running);
      expect(app.alertAvailability, availability);
      await tester.pumpWidget(const SizedBox());
      desktop.dispose();
      app.dispose();
    });
  }

  test('missing alert capability is explicitly unavailable', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(
      await WindowsLocalAlerts(host).synchronize(const AlertState()),
      AlertAvailability.unavailable,
    );
  });
}
