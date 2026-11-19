import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/data/local_alerts.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/domain/alert_state.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'package:poma/main.dart';

import 'alert_support.dart';
import 'support.dart';

class WaitingPreview extends FakeAlerts {
  final result = Completer<AlertAvailability>();
  final entered = Completer<void>();
  @override
  Future<AlertAvailability> previewCompletionBell() {
    previews++;
    entered.complete();
    return result.future;
  }
}

class BellPresenter implements CompletionPresenter {
  final requests = <AlertRequest>[];
  @override
  Future<void> presentCompletion(AlertRequest request) async {
    requests.add(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled bell is two-second mono PCM under 200 KB', () async {
    final data = await rootBundle.load(
      'native/resources/raw/completion_bell.wav',
    );
    expect(data.lengthInBytes, lessThan(200000));
    expect(data.getUint16(20, Endian.little), 1);
    expect(data.getUint16(22, Endian.little), 1);
    expect(data.getUint32(24, Endian.little), 44100);
    expect(data.getUint16(34, Endian.little), 16);
    expect(data.getUint32(40, Endian.little), 44100 * 2 * 2);
  });

  test(
    'legacy alert records default to bell on without enabling disabled alerts',
    () {
      final json = const AlertState(enabled: false).toJson()
        ..remove('bellEnabled');
      final legacy = AlertState.fromJson(json);
      expect(legacy.bellEnabled, isTrue);
      expect(legacy.enabled, isFalse);
      expect(
        AlertState.fromJson(
          const AlertState(bellEnabled: false).toJson(),
        ).bellEnabled,
        isFalse,
      );
      expect(
        () => AlertState.fromJson({...json, 'bellEnabled': 'yes'}),
        throwsFormatException,
      );
    },
  );

  for (final phase in FocusPhase.values) {
    test(
      '$phase keeps one existing OS request across natural foreground expiry',
      () async {
        final repository = MemoryRepository(
          SavedState(
            settings: const TimerSettings(
              focusMinutes: 1,
              shortBreakMinutes: 1,
              longBreakMinutes: 1,
            ),
          ),
        );
        final clock = FakeClock()..bootCount = 7;
        final alerts = FakeAlerts();
        final app = await AppController.create(
          repository,
          clock: clock,
          alerts: alerts,
        );
        addTearDown(app.dispose);
        await app.selectPhase(phase);
        await app.toggleTimer();
        final original = repository.state.alerts.current!;
        final legacyRequest = original.toJson()..remove('bellEnabled');
        expect(AlertRequest.fromJson(legacyRequest).bellEnabled, isTrue);
        clock.advance(const Duration(minutes: 1));
        await app.reconcile();
        expect(repository.state.alerts.current, isNull);
        expect(
          repository.state.alerts.pendingCompletion?.runId,
          original.runId,
        );
        expect(alerts.pending.values.single.generation, original.generation);
        expect(
          repository.state.sessions,
          hasLength(phase == FocusPhase.focus ? 1 : 0),
        );
        final serial = repository.state.alerts.serial;
        await app.reconcile(forceAlerts: true);
        expect(repository.state.alerts.serial, serial);
        expect(alerts.pending, hasLength(1));
        await app.setCompletionBell(true);
        expect(alerts.pending, hasLength(1));
        // The completion marker never recreates an already-delivered or missing alarm.
        alerts.pending.clear();
        await app.reconcile(forceAlerts: true);
        expect(alerts.pending, isEmpty);
        expect(app.timer.status, RunStatus.ready);
        expect(app.sessions, hasLength(phase == FocusPhase.focus ? 1 : 0));
      },
    );
  }

  for (final action in [
    TimerAction.pause,
    TimerAction.reset,
    TimerAction.skip,
  ]) {
    test(
      '$action cancels its alarm without preserving a completion bell',
      () async {
        final clock = FakeClock();
        final repository = MemoryRepository();
        final alerts = FakeAlerts();
        final app = await AppController.create(
          repository,
          clock: clock,
          alerts: alerts,
        );
        addTearDown(app.dispose);
        await app.toggleTimer();
        clock.advance(const Duration(minutes: 21));
        await app.handleTimerAction(action, runId: app.timer.runId!);
        expect(repository.state.alerts.pendingCompletion, isNull);
        expect(alerts.pending, isEmpty);
        expect(app.sessions, hasLength(action == TimerAction.skip ? 1 : 0));
      },
    );
  }

  test(
    'bell changes replace generation without changing strict running deadline',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(strictMode: true)),
      );
      final clock = FakeClock()..bootCount = 1;
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(app.dispose);
      await app.toggleTimer();
      final original = repository.state.alerts.current!;
      clock.advance(const Duration(seconds: 70));
      await app.setCompletionBell(false);
      final silent = repository.state.alerts.current!;
      expect(app.completionBellEnabled, isFalse);
      expect(silent.bellEnabled, isFalse);
      expect(silent.generation, greaterThan(original.generation));
      expect(silent.runId, original.runId);
      expect(silent.notificationId, original.notificationId);
      expect(silent.elapsedDeadlineMicros, original.elapsedDeadlineMicros);
      expect(silent.deadlineUtcMicros, original.deadlineUtcMicros);
      expect(app.timer.remainingSeconds, 1430);
      expect(app.timer.controlsLocked, isTrue);
      expect(alerts.permissionRequests, 0);
      final syncs = alerts.syncs;
      await app.refresh();
      await app.refresh();
      expect(alerts.syncs, syncs);
      await app.setCompletionBell(true);
      expect(repository.state.alerts.current!.bellEnabled, isTrue);
      expect(
        repository.state.alerts.current!.elapsedDeadlineMicros,
        original.elapsedDeadlineMicros,
      );
    },
  );

  test(
    'a failed bell-setting write never registers its uncommitted request',
    () async {
      final repository = MemoryRepository();
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        alerts: alerts,
      );
      addTearDown(app.dispose);
      await app.toggleTimer();
      final original = repository.state.alerts.current!;
      repository.failWrites = true;
      await app.setCompletionBell(false);
      expect(repository.state.alerts.bellEnabled, isTrue);
      expect(alerts.pending, isEmpty);
      expect(app.saveError, isNotNull);
      repository.failWrites = false;
      await app.retrySave();
      await app.flush();
      expect(alerts.pending.values.single.bellEnabled, isFalse);
      expect(
        alerts.pending.values.single.elapsedDeadlineMicros,
        original.elapsedDeadlineMicros,
      );
    },
  );

  test(
    'disabling the bell silences a completion held behind a failed save',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final clock = FakeClock();
      final presenter = BellPresenter();
      final app = await AppController.create(
        repository,
        clock: clock,
        alerts: FakeAlerts(),
        completionPresenter: presenter,
      );
      addTearDown(app.dispose);
      await app.toggleTimer();
      repository.failWrites = true;
      clock.advance(const Duration(minutes: 1));
      await app.reconcile();
      expect(presenter.requests, isEmpty);
      await app.setCompletionBell(false);
      repository.failWrites = false;
      await app.retrySave();
      await app.flush();
      expect(presenter.requests.single.bellEnabled, isFalse);
      expect(app.sessions, hasLength(1));
    },
  );

  test(
    'restart keeps the preference but retires a natural completion without replay',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final alerts = FakeAlerts();
      final clock = FakeClock();
      var app = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      await app.setCompletionBell(false);
      await app.toggleTimer();
      clock.advance(const Duration(minutes: 1));
      await app.reconcile();
      expect(repository.state.alerts.pendingCompletion?.bellEnabled, isFalse);
      app.dispose();
      app = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(app.dispose);
      expect(app.completionBellEnabled, isFalse);
      expect(repository.state.alerts.pendingCompletion, isNull);
      expect(alerts.pending, isEmpty);
      expect(app.sessions, hasLength(1));
      await app.deleteAllLocalData();
      expect(app.completionBellEnabled, isTrue);
      expect(repository.state.alerts.pendingCompletion, isNull);
    },
  );

  test(
    'preview is isolated from disabled alerts, bell preference, and timer history',
    () async {
      final repository = MemoryRepository();
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        alerts: alerts,
      );
      addTearDown(app.dispose);
      await app.setCompletionAlerts(false);
      await app.setCompletionBell(false);
      final before = repository.state.alerts.toJson();
      final writes = repository.writes;
      expect(await app.previewCompletionBell(), AlertAvailability.ready);
      expect(alerts.previews, 1);
      expect(alerts.permissionRequests, 0);
      expect(alerts.pending, isEmpty);
      expect(repository.state.alerts.toJson(), before);
      expect(repository.writes, writes);
      expect(app.sessions, isEmpty);
      alerts.mode = AlertAvailability.denied;
      expect(await app.previewCompletionBell(), AlertAvailability.denied);
    },
  );

  test('concurrent preview taps submit only one native request', () async {
    final alerts = WaitingPreview();
    final app = await AppController.create(
      MemoryRepository(),
      clock: FakeClock(),
      alerts: alerts,
    );
    addTearDown(app.dispose);
    final first = app.previewCompletionBell();
    expect(app.bellPreviewPending, isTrue);
    expect(await app.previewCompletionBell(), AlertAvailability.unavailable);
    await alerts.entered.future;
    expect(alerts.previews, 1);
    alerts.result.complete(AlertAvailability.ready);
    expect(await first, AlertAvailability.ready);
    expect(app.bellPreviewPending, isFalse);
  });

  test(
    'native preview bridge returns status without a scheduling payload',
    () async {
      const channel = MethodChannel('poma/test/completion-bell');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return 'denied';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      expect(
        await NativeLocalAlerts(channel: channel).previewCompletionBell(),
        AlertAvailability.denied,
      );
      expect(
        await WindowsLocalAlerts(
          NativeWindowsHost(channel: channel),
        ).previewCompletionBell(),
        AlertAvailability.denied,
      );
      expect(
        calls.map((call) => call.method),
        everyElement('previewCompletionBell'),
      );
      expect(calls.map((call) => call.arguments), everyElement(isNull));
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'bell controls and denied-preview feedback fit at ${scale}x text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final alerts = FakeAlerts()..mode = AlertAvailability.denied;
        final app = await AppController.create(
          MemoryRepository(),
          clock: FakeClock(),
          alerts: alerts,
        );
        addTearDown(app.dispose);
        await tester.pumpWidget(PomaApp(controller: app));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Settings').last);
        await tester.pumpAndSettle();
        final bell = find.byKey(const ValueKey('completion-bell-switch'));
        await tester.scrollUntilVisible(bell, 250);
        await tester.pumpAndSettle();
        await tester.ensureVisible(bell);
        await tester.pumpAndSettle();
        await tester.tap(bell);
        await tester.pumpAndSettle();
        expect(app.completionBellEnabled, isFalse);
        final preview = find.byKey(const ValueKey('preview-completion-bell'));
        await tester.scrollUntilVisible(preview, 150);
        await tester.pumpAndSettle();
        await tester.ensureVisible(preview);
        await tester.pumpAndSettle();
        await tester.tap(preview);
        await tester.pumpAndSettle();
        expect(alerts.previews, 1);
        expect(find.textContaining('Bell preview is blocked'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
