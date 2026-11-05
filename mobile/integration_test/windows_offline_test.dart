import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/timer_clock.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart' as poma;
import 'package:poma/ui/settings_screen.dart';

/// Run only after backing up the closed development profile and creating its
/// .session2-test-profile marker. Uses the real loader, channels and SQLite DLL.
/// This is a live-engine test, not evidence of a disconnected/installed launch.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows production startup, pause/reopen and unique completion',
    (tester) async {
      debugPrint('Windows smoke: requesting native environment');
      final environment = await const MethodChannel(
        'dev.poma.poma/windows_desktop',
      ).invokeMapMethod<String, Object?>('environment');
      expect(environment?['packaged'], isFalse);
      final directory = environment!['dataDirectory'] as String;
      if (!File(path.join(directory, '.session2-test-profile')).existsSync()) {
        throw StateError(
          'Back up and isolate the development profile before this test.',
        );
      }
      // A live test controls the first Flutter frame. Make the test window
      // visible before waiting for frame delivery; normal entry uses FirstFrame.
      await const MethodChannel(
        'dev.poma.poma/windows_desktop',
      ).invokeMethod<void>('showMain');
      debugPrint('Windows smoke: isolated native window shown');
      final evidence = <String, Object?>{
        'startedUtc': DateTime.now().toUtc().toIso8601String(),
        'kind': 'Windows live integration; network connectivity not altered',
        'environment': environment,
      };

      Future<poma.PomaApp> load() async {
        debugPrint('Windows smoke: loading production services');
        poma.main(); // No injected repository, clock, alerts, or desktop services.
        for (var attempt = 0; attempt < 100; attempt++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (find.byType(poma.PomaApp).evaluate().isNotEmpty) {
            await tester.pumpAndSettle();
            debugPrint('Windows smoke: production app rendered');
            return tester.widget<poma.PomaApp>(find.byType(poma.PomaApp));
          }
        }
        throw StateError('Production Windows startup did not reach the app.');
      }

      Future<void> unload(AppController controller) async {
        await tester.pumpWidget(const SizedBox());
        await controller.flush();
        await controller.repository.close();
      }

      var widget = await load();
      var controller = widget.controller;
      final desktop = widget.desktop!;
      expect(controller.repository, isA<SqliteRepository>());
      expect(controller.clock, isA<NativeTimerClock>());
      expect(controller.residentNotifications, isTrue);
      expect((await controller.clock.sample()).bootCount, isNull);
      expect(controller.tasks, isEmpty);
      await controller.loadHistory();
      expect(controller.sessions, isEmpty);
      desktop.requestNewTask();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Fictional Session 2 task',
      );
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      await controller.flush();
      final task = controller.tasks.single;
      debugPrint('Windows smoke: task persisted');
      controller.selectTask(task.id);
      desktop.navigate(3);
      await tester.pumpAndSettle();
      final duration = find.byKey(
        const ValueKey('desktop-number-Focus duration'),
      );
      await tester.enterText(duration, '1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(controller.settings.focusMinutes, 1);
      debugPrint('Windows smoke: Settings persisted');
      await controller.updateSettings(
        controller.settings.copyWith(appearance: 'dark'),
      );
      await controller.setCompletionAlerts(true);
      expect(controller.alertAvailability, AlertAvailability.unavailable);
      await tester.scrollUntilVisible(
        find.text('Completion alerts'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Completion alerts are unavailable. Your timer still works.'),
        findsOneWidget,
      );
      await controller.setCompletionAlerts(false);
      desktop.navigate(0);
      await tester.pumpAndSettle();
      final toggle = find.byKey(const Key('timer-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      final run = controller.timer.runId;
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.timer.status, RunStatus.paused);
      final paused = controller.timer.snapshot().toJson();
      evidence['pausedBeforeReopen'] = paused;
      debugPrint('Windows smoke: exact pause persisted');
      await unload(controller);

      widget = await load();
      controller = widget.controller;
      expect(controller.timer.snapshot().toJson(), paused);
      expect(controller.tasks.single.id, task.id);
      expect(controller.settings.appearance, 'dark');
      evidence['pausedAfterReopen'] = controller.timer.snapshot().toJson();
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(controller.timer.status, RunStatus.running);
      expect(controller.timer.runId, run);
      debugPrint('Windows smoke: resumed; waiting for one completion');
      final deadline = controller.timer.snapshot().deadline;
      evidence['resumed'] = controller.timer.snapshot().toJson();
      final limit = DateTime.now().add(const Duration(seconds: 80));
      while (controller.timer.status == RunStatus.running &&
          DateTime.now().isBefore(limit)) {
        await tester.pump(const Duration(seconds: 1));
        await controller.reconcile();
      }
      await controller.loadHistory();
      expect(controller.sessions.single.id, run);
      expect(controller.sessions.single.endedAt, deadline);
      expect(controller.sessions.single.taskTitle, task.title);
      expect(controller.timer.phase, FocusPhase.shortBreak);
      expect(controller.timer.status, RunStatus.ready);
      await controller.reconcile();
      evidence['completed'] = controller.sessions.single.toRow();
      debugPrint('Windows smoke: one completion verified');
      evidence['successor'] = controller.timer.snapshot().toJson();
      await unload(controller);

      widget = await load();
      controller = widget.controller;
      await controller.loadHistory();
      expect(controller.sessions.single.id, run);
      expect(controller.timer.status, RunStatus.ready);
      expect(controller.timer.phase, FocusPhase.shortBreak);
      await controller.updateSettings(
        controller.settings.copyWith(strictMode: true),
      );
      await controller
          .toggleTimer(); // Successor starts only by explicit action.
      await controller.toggleTimer(); // Strict mode rejects pause.
      expect(controller.timer.status, RunStatus.running);
      expect(controller.timer.controlsLocked, isTrue);
      evidence['strictManualSuccessor'] = controller.timer.snapshot().toJson();
      evidence['completedUtc'] = DateTime.now().toUtc().toIso8601String();
      await unload(controller);
      await File(
        path.join(directory, 'session2-smoke.json'),
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
    },
    skip:
        !Platform.isWindows ||
        !const bool.fromEnvironment('POMA_WINDOWS_SMOKE'),
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
