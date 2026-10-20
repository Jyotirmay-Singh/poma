import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:poma/main.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'support.dart';
import 'alert_support.dart';

void main() {
  for (final enable in [false, true]) {
    testWidgets(
      'first Start explains alerts; choice $enable still starts one phase',
      (tester) async {
        final repository = MemoryRepository();
        final alerts = FakeAlerts()..mode = AlertAvailability.denied;
        final app = await AppController.create(
          repository,
          clock: FakeClock(),
          alerts: alerts,
        );
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(PomaApp(controller: app));
        await tester.pumpAndSettle();
        expect(alerts.permissionRequests, 0);
        await tester.scrollUntilVisible(
          find.byKey(const Key('timer-toggle')),
          150,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const Key('timer-toggle')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('timer-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('Know when your time is up'), findsOneWidget);
        await tester.tap(find.text(enable ? 'Enable alerts' : 'Not now'));
        await tester.pumpAndSettle();
        expect(app.timer.status, RunStatus.running);
        expect(app.needsAlertPermission, isFalse);
        expect(alerts.permissionRequests, enable ? 1 : 0);
        expect(app.sessions, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        app.dispose();
        await app.flush();
      },
    );
  }
  for (final phase in FocusPhase.values) {
    test(
      '$phase schedules only while running and resume replaces its segment',
      () async {
        final repository = MemoryRepository();
        final clock = FakeClock()..bootCount = 4;
        final alerts = FakeAlerts();
        final app = await AppController.create(
          repository,
          clock: clock,
          alerts: alerts,
        );
        addTearDown(app.dispose);
        expect(alerts.pending, isEmpty);
        await app.selectPhase(phase);
        await app.toggleTimer();
        final first = repository.state.alerts.current!;
        expect(alerts.pending.values.single.runId, app.timer.runId);
        expect(first.phase, phase);
        clock.advance(const Duration(seconds: 12, microseconds: 500));
        await app.toggleTimer();
        expect(alerts.pending, isEmpty);
        expect(repository.state.alerts.current, isNull);
        final remaining = app.timer.remainingMicros;
        await app.toggleTimer();
        final resumed = repository.state.alerts.current!;
        expect(resumed.runId, first.runId);
        expect(resumed.notificationId, first.notificationId);
        expect(resumed.generation, greaterThan(first.generation));
        expect(resumed.maximumRemainingMicros, remaining);
        await app.resetTimer();
        expect(alerts.pending, isEmpty);
        expect(app.sessions, isEmpty);
      },
    );
  }

  test(
    'skip and phase selection retire their requests; duration edits preserve active timing',
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
      await app.updateSettings(app.settings.copyWith(focusMinutes: 40));
      expect(repository.state.alerts.current!.generation, original.generation);
      expect(app.timer.totalSeconds, 1500);
      await app.skipTimer();
      expect(alerts.pending, isEmpty);
      expect(app.sessions, isEmpty);
      await app.toggleTimer();
      await app.selectPhase(FocusPhase.focus);
      expect(alerts.pending, isEmpty);
      expect(app.timer.totalSeconds, 2400);
    },
  );

  test(
    'strict mode blocks controls without replacing an active request',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(strictMode: true)),
      );
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        alerts: alerts,
      );
      addTearDown(app.dispose);
      await app.toggleTimer();
      final request = repository.state.alerts.current!;
      await app.handleTimerAction(TimerAction.pause, runId: request.runId);
      await app.resetTimer();
      await app.skipTimer();
      expect(app.timer.status, RunStatus.running);
      expect(repository.state.alerts.current!.generation, request.generation);
    },
  );

  test(
    'denial, revocation and inexact fallback retain the running phase',
    () async {
      final repository = MemoryRepository();
      final alerts = FakeAlerts()..mode = AlertAvailability.denied;
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        alerts: alerts,
      );
      addTearDown(app.dispose);
      expect(alerts.permissionRequests, 0);
      await app.setCompletionAlerts(true);
      await app.toggleTimer();
      final run = app.timer.runId;
      expect(app.timer.status, RunStatus.running);
      expect(alerts.pending, isEmpty);
      expect(app.alertAvailability, AlertAvailability.denied);
      expect(app.needsAlertPermission, isFalse);
      alerts.mode = AlertAvailability.delayed;
      await app.reconcile(forceAlerts: true);
      expect(alerts.pending.length, 1);
      expect(app.alertMessage, contains('may be delayed'));
      alerts.mode = AlertAvailability.denied;
      await app.reconcile(forceAlerts: true);
      expect(alerts.pending, isEmpty);
      expect(app.timer.runId, run);
      expect(alerts.permissionRequests, 1);
    },
  );

  for (final afterOs in [false, true]) {
    test(
      'crash ${afterOs ? 'after' : 'before'} OS update repairs from durable desired state',
      () async {
        final repository = MemoryRepository();
        final clock = FakeClock()..bootCount = 9;
        final alerts = FakeAlerts();
        final first = await AppController.create(
          repository,
          clock: clock,
          alerts: alerts,
        );
        alerts.failBefore = !afterOs;
        alerts.failAfter = afterOs;
        await first.toggleTimer();
        final saved = repository.state.alerts.current!;
        expect(repository.state.timer!.runId, saved.runId);
        expect(first.alertAvailability, AlertAvailability.failed);
        first.dispose();
        alerts.failBefore = false;
        alerts.failAfter = false;
        clock.advance(const Duration(seconds: 30));
        final restored = await AppController.create(
          repository,
          clock: clock,
          alerts: alerts,
        );
        addTearDown(restored.dispose);
        expect(restored.timer.runId, saved.runId);
        expect(alerts.pending.length, 1);
        expect(
          alerts.pending.values.single.notificationId,
          saved.notificationId,
        );
        expect(restored.timer.remainingSeconds, 1470);
        expect(restored.sessions, isEmpty);
      },
    );
  }

  test(
    'failed acknowledgement repairs without dropping timer or multiplying requests',
    () async {
      final repository = MemoryRepository();
      final alerts = FakeAlerts();
      final clock = FakeClock()..bootCount = 1;
      final first = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      repository.failReceipts = true;
      await first.toggleTimer();
      final identity = repository.state.alerts.current!;
      expect(alerts.pending.length, 1);
      expect(first.alertAvailability, AlertAvailability.failed);
      first.dispose();
      repository.failReceipts = false;
      final restored = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(restored.dispose);
      expect(alerts.pending.length, 1);
      expect(alerts.pending.values.single.generation, identity.generation);
    },
  );

  test(
    'crash between cancelled database state and OS cancellation removes stale request',
    () async {
      final repository = MemoryRepository();
      final clock = FakeClock();
      final alerts = FakeAlerts();
      final first = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      await first.toggleTimer();
      alerts.failBefore = true;
      await first.resetTimer();
      expect(repository.state.timer!.status, RunStatus.ready);
      expect(repository.state.alerts.current, isNull);
      expect(alerts.pending.length, 1);
      first.dispose();
      alerts.failBefore = false;
      final restored = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(restored.dispose);
      expect(alerts.pending, isEmpty);
      expect(restored.sessions, isEmpty);
    },
  );

  test(
    'failed timer save never registers an uncommitted session; retry repairs it',
    () async {
      final repository = MemoryRepository();
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        alerts: alerts,
      );
      addTearDown(app.dispose);
      repository.failWrites = true;
      await app.toggleTimer();
      final run = app.timer.runId;
      expect(alerts.pending, isEmpty);
      expect(app.saveError, isNotNull);
      expect(app.timer.status, RunStatus.running);
      repository.failWrites = false;
      await app.retrySave();
      expect(alerts.pending.values.single.runId, run);
      expect(repository.state.timer!.runId, run);
    },
  );

  test(
    'clock failure leaves the last durable scheduled request intact',
    () async {
      final clock = FakeClock();
      final alerts = FakeAlerts();
      final app = await AppController.create(
        MemoryRepository(),
        clock: clock,
        alerts: alerts,
      );
      addTearDown(app.dispose);
      await app.toggleTimer();
      final syncs = alerts.syncs;
      clock.failReads = true;
      final result = await app.reconcile(forceAlerts: true);
      expect(result.clockSucceeded, isFalse);
      expect(alerts.syncs, syncs);
      expect(alerts.pending.length, 1);
    },
  );

  test(
    'long absence completes one focus and never schedules the ready break',
    () async {
      final repository = MemoryRepository();
      final clock = FakeClock()..bootCount = 3;
      final alerts = FakeAlerts();
      final first = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      await first.toggleTimer();
      first.dispose();
      clock.advance(const Duration(days: 3));
      final restored = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(restored.dispose);
      await restored.reconcile(forceAlerts: true);
      await restored.reconcile(forceAlerts: true);
      expect(restored.sessions.length, 1);
      expect(restored.timer.phase, FocusPhase.shortBreak);
      expect(restored.timer.status, RunStatus.ready);
      expect(alerts.pending, isEmpty);
    },
  );

  test(
    'duplicate open/dismiss taps, stale payloads and action-ack crash do not advance phases',
    () async {
      final repository = MemoryRepository();
      final clock = FakeClock()..bootCount = 3;
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(app.dispose);
      await app.toggleTimer();
      final request = repository.state.alerts.current!;
      clock.advance(const Duration(minutes: 25));
      alerts.queue.addAll([
        AlertResponse(request.runId, request.generation, 'open'),
        AlertResponse(request.runId, request.generation, 'open'),
        AlertResponse('obsolete', 1, 'open'),
      ]);
      alerts.failActionAck = true;
      await app.reconcile(forceAlerts: true);
      expect(app.alertOpenRevision, 1);
      alerts.failActionAck = false;
      await app.reconcile(forceAlerts: true);
      expect(app.alertOpenRevision, 1);
      alerts.queue.add(
        AlertResponse(request.runId, request.generation, 'dismiss'),
      );
      await app.reconcile(forceAlerts: true);
      expect(alerts.queue, isEmpty);
      expect(app.sessions.length, 1);
      expect(app.timer.status, RunStatus.ready);
      expect(app.timer.phase, FocusPhase.shortBreak);
    },
  );

  test(
    'Android same-boot restoration ignores a changed wall clock; reboot falls back to UTC',
    () async {
      final clock = FakeClock()..bootCount = 5;
      final repository = MemoryRepository();
      final alerts = FakeAlerts();
      final first = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      await first.toggleTimer();
      first.dispose();
      clock.advance(const Duration(minutes: 5));
      clock.utcNow = clock.utcNow.add(const Duration(days: 2));
      final sameBoot = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      expect(sameBoot.timer.status, RunStatus.running);
      expect(sameBoot.timer.remainingSeconds, 1200);
      sameBoot.dispose();
      clock.bootCount = 6;
      clock.elapsed = Duration.zero;
      final rebooted = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(rebooted.dispose);
      expect(rebooted.timer.status, RunStatus.ready);
      expect(rebooted.sessions.length, 1);
      expect(alerts.pending, isEmpty);
    },
  );
}
