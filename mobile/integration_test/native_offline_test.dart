import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/local_alerts.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/timer_clock.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';

/// Run only on a dedicated test installation. This native foreground smoke
/// test is separate from the required computer-disconnected device procedure.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native focus completion, manual break, and durable reopen',
    (tester) async {
      var repository = SqliteRepository();
      var app = await AppController.create(
        repository,
        clock: NativeTimerClock(),
        alerts: NativeLocalAlerts(),
      );
      addTearDown(() async {
        app.dispose();
        await app.flush();
        await repository.close();
      });
      await app.updateSettings(app.settings.copyWith(focusMinutes: 1));
      // No unattended OS permission prompt: device delivery is tested manually.
      await app.setCompletionAlerts(false);
      await app.loadHistory();
      await app.loadSummaries();
      final initialCount = app.todaySummary?.count;
      await tester.pumpWidget(PomaApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('destination-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a task'));
      await tester.pumpAndSettle();
      final title =
          'Native offline check ${DateTime.now().millisecondsSinceEpoch}';
      await tester.enterText(find.byType(TextFormField), title);
      await tester.tap(find.text('Save task'));
      await tester.pumpAndSettle();
      await app.flush();
      final task = app.tasks.last;
      app.selectTask(task.id);
      await app.flush();
      await tester.tap(find.byKey(const Key('destination-0')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('timer-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timer-toggle')));
      await tester.pumpAndSettle();
      final runId = app.timer.runId;
      for (
        var second = 0;
        second < 70 && app.timer.status == RunStatus.running;
        second++
      ) {
        await tester.pump(const Duration(seconds: 1));
        await app.reconcile();
      }
      await app.loadHistory();
      expect(app.sessions.where((s) => s.id == runId).length, 1);
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.ready);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('timer-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('timer-toggle')));
      await tester.pumpAndSettle();
      expect(app.timer.status, RunStatus.running);
      await app.updateSettings(app.settings.copyWith(appearance: 'dark'));
      await app.loadSummaries();
      if (initialCount != null) {
        expect(app.todaySummary!.count, initialCount + 1);
      }
      await tester.pumpWidget(const SizedBox());
      await app.flush();
      app.dispose();
      await repository.close();
      repository = SqliteRepository();
      app = await AppController.create(
        repository,
        clock: NativeTimerClock(),
        alerts: NativeLocalAlerts(),
      );
      await app.loadHistory();
      expect(app.tasks.any((t) => t.id == task.id && t.title == title), isTrue);
      expect(app.selectedTaskId, task.id);
      expect(app.settings.appearance, 'dark');
      expect(app.sessions.where((s) => s.id == runId).single.taskTitle, title);
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.running);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
