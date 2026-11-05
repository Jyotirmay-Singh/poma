import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/domain/alert_state.dart';
import 'package:poma/domain/desktop_preferences.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'alert_support.dart';
import 'support.dart';

class RecordingPresenter implements CompletionPresenter {
  final List<AlertRequest> requests = [];
  void Function()? beforePresent;
  @override
  Future<void> presentCompletion(AlertRequest request) async {
    beforePresent?.call();
    requests.add(request);
  }
}

class FakeShell implements DesktopShell {
  @override
  Future<void> Function(String, Map<String, Object?>)? onEvent;
  TimerSnapshot? armed;
  Map<String, Object?> snapshot = {};
  int exits = 0, opens = 0;
  int popupOpens = 0;
  int armCalls = 0;
  String startup = 'disabled';
  @override
  Future<void> armDeadline(TimerSnapshot? value) async {
    armCalls++;
    armed = value;
  }

  @override
  Future<void> configure(DesktopPreferences value) async {}
  @override
  Future<void> publish(Map<String, Object?> value) async => snapshot = value;
  @override
  Future<void> exit() async {
    exits++;
  }

  @override
  Future<void> showMain() async {
    opens++;
  }

  @override
  Future<void> showPopup({bool preview = false}) async {
    popupOpens++;
  }

  @override
  Future<String> startupState() async => startup;
  @override
  Future<String> setStartup(bool enabled) async =>
      startup = enabled ? 'enabled' : 'disabled';
  Future<void> send(
    String event, [
    Map<String, Object?> values = const {},
  ]) async {
    await onEvent?.call(event, values);
    await Future<void>.delayed(Duration.zero);
  }
}

const environment = DesktopEnvironment(
  dataDirectory: 'test-only',
  version: '1.0.0.2007',
  packaged: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(sqfliteFfiInit);
  for (final failSave in [false, true]) {
    test(
      'desktop early Skip counts once without a toast, save failure $failSave',
      () async {
        final repository = MemoryRepository();
        final clock = FakeClock();
        final alerts = FakeAlerts();
        final presenter = RecordingPresenter();
        final controller = await AppController.create(
          repository,
          clock: clock,
          alerts: alerts,
          completionPresenter: presenter,
        );
        final shell = FakeShell();
        final desktop = DesktopController(controller, shell, environment);
        addTearDown(() {
          desktop.dispose();
          controller.dispose();
        });
        await desktop.initialize();
        await controller.setForeground(false);
        final id = (await controller.toggleTimer()).snapshot.runId;
        final revision = controller.timer.revision;
        clock.advance(const Duration(minutes: 21));
        repository.failWrites = failSave;
        await desktop.requestTimerAction(
          action: 'skip',
          revision: revision,
          runId: id,
        );
        expect(presenter.requests, isEmpty);
        if (failSave) {
          expect(repository.state.sessions, isEmpty);
          repository.failWrites = false;
          await controller.retrySave();
        }
        await desktop.requestTimerAction(
          action: 'skip',
          revision: revision,
          runId: id,
        );
        clock.advance(const Duration(minutes: 4));
        await shell.send('deadline', {'runId': id});
        await controller.reconcile(forceAlerts: true);
        await controller.flush();
        await Future<void>.delayed(Duration.zero);
        expect(repository.state.sessions.single.id, id);
        expect(repository.state.sessions.single.focusSeconds, 1260);
        expect(controller.timer.completedRounds, 1);
        expect(controller.timer.phase, FocusPhase.shortBreak);
        expect(controller.timer.status, RunStatus.ready);
        expect(controller.lastPhaseCompletion!.runId, id);
        expect(presenter.requests, isEmpty);
        expect(alerts.pending, isEmpty);
        expect(shell.armed, isNull);
      },
    );
  }

  test(
    'opening the compact timer never creates or starts another timer',
    () async {
      final controller = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final desktop = DesktopController(controller, shell, environment);
      addTearDown(() {
        desktop.dispose();
        controller.dispose();
      });
      await desktop.initialize();
      await desktop.showPopup();
      await desktop.showPopup();
      expect(shell.popupOpens, 2);
      expect(controller.timer.runId, isNull);
      expect(controller.timer.status, RunStatus.ready);
      await controller.toggleTimer();
      final run = controller.timer.runId;
      await desktop.showPopup();
      expect(controller.timer.runId, run);
      expect(controller.timer.status, RunStatus.running);
    },
  );

  test(
    'early hidden deadline is rearmed and resume preserves a still-running phase',
    () async {
      final clock = FakeClock();
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 2)),
      );
      final controller = await AppController.create(repository, clock: clock);
      final shell = FakeShell();
      final desktop = DesktopController(controller, shell, environment);
      addTearDown(() {
        desktop.dispose();
        controller.dispose();
      });
      await desktop.initialize();
      await controller.toggleTimer();
      await Future<void>.delayed(Duration.zero);
      final calls = shell.armCalls, run = controller.timer.runId;
      await shell.send('deadline', {'runId': run});
      expect(shell.armCalls, greaterThan(calls));
      expect(shell.armed?.runId, run);
      clock.advance(const Duration(minutes: 1));
      await shell.send('resume');
      expect(controller.timer.status, RunStatus.running);
      expect(controller.timer.remainingSeconds, 60);
      expect(repository.state.sessions, isEmpty);
      clock.advance(const Duration(minutes: 1));
      await shell.send('deadline', {'runId': run});
      expect(repository.state.sessions.single.id, run);
      expect(shell.armed, isNull);
    },
  );

  test(
    'resident hidden expiry still commits with notifications disabled',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final clock = FakeClock();
      final alerts = FakeAlerts();
      final presenter = RecordingPresenter();
      final controller = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
        completionPresenter: presenter,
      );
      final shell = FakeShell();
      final desktop = DesktopController(controller, shell, environment);
      addTearDown(() {
        desktop.dispose();
        controller.dispose();
      });
      await desktop.initialize();
      await controller.setCompletionAlerts(false);
      await controller.toggleTimer();
      await Future<void>.delayed(Duration.zero);
      final run = controller.timer.runId;
      expect(shell.armed?.runId, run);
      clock.advance(const Duration(minutes: 2));
      await shell.send('deadline', {'runId': run});
      await shell.send('resume');
      await shell.send('deadline', {'runId': run});
      expect(repository.state.sessions.single.id, run);
      expect(controller.timer.phase, FocusPhase.shortBreak);
      expect(controller.timer.status, RunStatus.ready);
      expect(shell.armed, isNull);
      expect(presenter.requests, isEmpty);
    },
  );

  test(
    'desktop completion is post-commit and duplicate callbacks present once',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final clock = FakeClock();
      final presenter = RecordingPresenter();
      final controller = await AppController.create(
        repository,
        clock: clock,
        alerts: FakeAlerts(),
        completionPresenter: presenter,
      );
      addTearDown(controller.dispose);
      await controller.setForeground(false);
      await controller.toggleTimer();
      presenter.beforePresent = () {
        expect(repository.state.sessions, hasLength(1));
        expect(repository.state.timer?.status, RunStatus.ready);
      };
      clock.advance(const Duration(minutes: 1));
      await controller.reconcile();
      await controller.reconcile(forceAlerts: true);
      expect(presenter.requests, hasLength(1));
      expect(repository.state.sessions, hasLength(1));
    },
  );

  test(
    'failed completion save is presented only after successful retry',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final clock = FakeClock();
      final presenter = RecordingPresenter();
      final controller = await AppController.create(
        repository,
        clock: clock,
        alerts: FakeAlerts(),
        completionPresenter: presenter,
      );
      addTearDown(controller.dispose);
      await controller.setForeground(false);
      await controller.toggleTimer();
      repository.failWrites = true;
      clock.advance(const Duration(minutes: 1));
      await controller.reconcile();
      expect(presenter.requests, isEmpty);
      expect(repository.state.sessions, isEmpty);
      repository.failWrites = false;
      await controller.retrySave();
      await controller.flush();
      expect(presenter.requests, hasLength(1));
      expect(repository.state.sessions, hasLength(1));
    },
  );

  test(
    'cold overdue recovery counts once without replaying a notification',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final clock = FakeClock();
      final presenter = RecordingPresenter();
      var controller = await AppController.create(
        repository,
        clock: clock,
        alerts: FakeAlerts(),
        completionPresenter: presenter,
      );
      await controller.setForeground(false);
      await controller.toggleTimer();
      final deadline = controller.timer.snapshot().deadline;
      controller.dispose();
      clock.advance(const Duration(hours: 8));
      controller = await AppController.create(
        repository,
        clock: clock,
        alerts: FakeAlerts(),
        completionPresenter: presenter,
      );
      addTearDown(controller.dispose);
      await controller.setForeground(false);
      await controller.reconcile();
      expect(repository.state.sessions.single.endedAt, deadline);
      expect(presenter.requests, isEmpty);
      expect(controller.timer.status, RunStatus.ready);
    },
  );

  test('break completion is presented without adding focus history', () async {
    final repository = MemoryRepository(
      SavedState(settings: const TimerSettings(shortBreakMinutes: 1)),
    );
    final clock = FakeClock();
    final presenter = RecordingPresenter();
    final controller = await AppController.create(
      repository,
      clock: clock,
      alerts: FakeAlerts(),
      completionPresenter: presenter,
    );
    addTearDown(controller.dispose);
    await controller.setForeground(false);
    await controller.selectPhase(FocusPhase.shortBreak);
    await controller.toggleTimer();
    clock.advance(const Duration(minutes: 1));
    await controller.reconcile();
    expect(presenter.requests.single.phase, FocusPhase.shortBreak);
    expect(repository.state.sessions, isEmpty);
    expect(controller.timer.phase, FocusPhase.focus);
  });

  test('native controls reject stale identity and obey strict mode', () async {
    final clock = FakeClock();
    final controller = await AppController.create(
      MemoryRepository(),
      clock: clock,
    );
    final shell = FakeShell();
    final desktop = DesktopController(controller, shell, environment);
    addTearDown(() {
      desktop.dispose();
      controller.dispose();
    });
    await desktop.initialize();
    await controller.toggleTimer();
    final old = {
      'runId': controller.timer.runId,
      'revision': controller.timer.revision,
      'action': 'pause',
    };
    await controller.updateSettings(
      controller.settings.copyWith(strictMode: true),
    );
    await shell.send('timer', {...old, 'revision': controller.timer.revision});
    expect(controller.timer.status, RunStatus.running);
    await shell.send('timer', {...old, 'runId': 'old-run'});
    expect(controller.timer.status, RunStatus.running);
  });

  test(
    'full reset invalidates unsaved notification effects and desktop preferences',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final clock = FakeClock();
      final presenter = RecordingPresenter();
      final controller = await AppController.create(
        repository,
        clock: clock,
        alerts: FakeAlerts(),
        completionPresenter: presenter,
      );
      addTearDown(controller.dispose);
      await controller.setForeground(false);
      await controller.updateDesktopPreferences(
        const DesktopPreferences(closeToTray: false, closeExplained: true),
      );
      await controller.toggleTimer();
      repository.failWrites = true;
      clock.advance(const Duration(minutes: 2));
      await controller.reconcile();
      repository.failWrites = false;
      expect(await controller.deleteAllLocalData(), isTrue);
      await controller.reconcile();
      expect(presenter.requests, isEmpty);
      expect(controller.desktopPreferences.closeToTray, isTrue);
      expect(repository.state.sessions, isEmpty);
    },
  );

  test(
    'quit keeps application alive on save failure unless loss is explicitly confirmed',
    () async {
      final repository = MemoryRepository();
      final controller = await AppController.create(
        repository,
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final desktop = DesktopController(controller, shell, environment);
      addTearDown(() {
        desktop.dispose();
        controller.dispose();
      });
      await desktop.initialize();
      repository.failWrites = true;
      controller.addTask('Unsaved');
      await controller.flush();
      desktop.confirmDiscard = () async => false;
      await desktop.quit();
      expect(shell.exits, 0);
      expect(shell.opens, greaterThan(0));
      desktop.confirmDiscard = () async => true;
      await desktop.quit();
      expect(shell.exits, 1);
    },
  );

  test(
    'real SQLite preserves namespaced desktop preferences without a schema upgrade',
    () async {
      final folder = Directory.systemTemp.createTempSync('poma-desktop-');
      final file = '${folder.path}/poma.db';
      final first = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      var controller = await AppController.create(first, clock: FakeClock());
      await controller.setForeground(false);
      await controller.updateDesktopPreferences(
        const DesktopPreferences(
          closeToTray: false,
          closeExplained: true,
          bounds: DesktopBounds(-1800, 40, 1080, 760),
        ),
      );
      controller.addTask('Local Windows task');
      await controller.flush();
      controller.dispose();
      await first.close();
      final second = SqliteRepository(
        factory: databaseFactoryFfi,
        databasePath: file,
      );
      controller = await AppController.create(second, clock: FakeClock());
      try {
        expect(controller.desktopPreferences.closeToTray, isFalse);
        expect(controller.desktopPreferences.bounds?.x, -1800);
        expect(controller.tasks.single.title, 'Local Windows task');
        await controller.deleteAllLocalData();
        expect(controller.desktopPreferences.bounds, isNull);
      } finally {
        controller.dispose();
        await second.close();
        folder.deleteSync(recursive: true);
      }
    },
  );

  test(
    'Windows alerts use only the Windows channel and opaque notification fields',
    () async {
      const channel = MethodChannel('poma-windows-test');
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'synchronizeAlerts') return 'denied';
        if (call.method == 'responses') return <Object>[];
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final alerts = WindowsLocalAlerts(NativeWindowsHost(channel: channel));
      await alerts.initialize(databasePath: 'unused', onEvent: () {});
      expect(
        await alerts.synchronize(const AlertState()),
        AlertAvailability.denied,
      );
      await alerts.presentCompletion(
        const AlertRequest(
          runId: 'opaque',
          generation: 1,
          notificationId: 1,
          phase: FocusPhase.focus,
          segment: 1,
          deadlineUtcMicros: 1,
          elapsedDeadlineMicros: 1,
          maximumRemainingMicros: 1,
        ),
      );
      final payload = calls.last.arguments as Map;
      expect(payload.keys.toSet(), {
        'runId',
        'generation',
        'notificationId',
        'focus',
      });
      await alerts.requestPermission();
      await alerts.requestExactAccess();
      expect(
        calls.any(
          (c) => c.method.contains('Permission') || c.method.contains('Exact'),
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'desktop number entry validates ranges and preserves a running duration',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final desktop = DesktopController(controller, FakeShell(), environment);
      await desktop.initialize();
      await tester.pumpWidget(
        PomaApp(controller: controller, desktop: desktop),
      );
      desktop.navigate(3);
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('desktop-number-Focus duration'));
      await tester.enterText(field, '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 120.'), findsOneWidget);
      expect(controller.settings.focusMinutes, 25);
      await tester.enterText(field, '1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.settings.focusMinutes, 1);
      await controller.toggleTimer();
      await tester.pumpAndSettle();
      await tester.enterText(field, '2');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.settings.focusMinutes, 2);
      expect(controller.timer.snapshot().totalSeconds, 60);
      await tester.pumpWidget(const SizedBox());
      desktop.dispose();
      controller.dispose();
    },
  );

  testWidgets(
    'desktop shortcuts navigate and create one keyboard-accessible task dialog',
    (tester) async {
      final controller = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final desktop = DesktopController(controller, FakeShell(), environment);
      await desktop.initialize();
      await tester.pumpWidget(
        PomaApp(controller: controller, desktop: desktop),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit5);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(desktop.destination, 3);
      expect(find.text('Settings'), findsWidgets);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'Keyboard task');
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      expect(controller.tasks.single.title, 'Keyboard task');
      await tester.pumpWidget(const SizedBox());
      desktop.dispose();
      controller.dispose();
    },
  );

  testWidgets('wide history table wraps populated long task snapshots', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await AppController.create(
      MemoryRepository(
        SavedState(
          sessions: [
            FocusSession(
              id: 'history-1',
              startedAt: DateTime.utc(2026, 10, 24, 10),
              endedAt: DateTime.utc(2026, 10, 24, 10, 25),
              focusSeconds: 1500,
              taskTitle: 'Long immutable task snapshot '.padRight(160, 'x'),
            ),
          ],
        ),
      ),
      clock: FakeClock(),
    );
    final desktop = DesktopController(controller, FakeShell(), environment);
    await desktop.initialize();
    await tester.pumpWidget(PomaApp(controller: controller, desktop: desktop));
    desktop.navigate(2);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('desktop-history-table')), findsOneWidget);
    expect(tester.widget<DataTable>(find.byType(DataTable)).rows, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    desktop.dispose();
    controller.dispose();
  });

  for (final width in [640.0, 1080.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      for (final appearance in ['light', 'dark']) {
        testWidgets(
          'desktop screens width=$width text=$scale appearance=$appearance',
          (tester) async {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final controller = await AppController.create(
              MemoryRepository(
                SavedState(
                  settings: TimerSettings(appearance: appearance),
                  tasks: [
                    FocusTask(
                      id: 'long',
                      title:
                          'Fictional local task with a long Unicode title — 日本語 '
                              .padRight(155, 'x'),
                    ),
                  ],
                ),
              ),
              clock: FakeClock(),
            );
            final desktop = DesktopController(
              controller,
              FakeShell(),
              environment,
            );
            await desktop.initialize();
            await tester.pumpWidget(
              PomaApp(controller: controller, desktop: desktop),
            );
            await tester.pumpAndSettle();
            for (var i = 0; i < 4; i++) {
              desktop.navigate(i);
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox());
            desktop.dispose();
            controller.dispose();
          },
        );
      }
    }
  }
}
