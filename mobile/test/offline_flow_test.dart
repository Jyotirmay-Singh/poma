import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'alert_support.dart';
import 'support.dart';
import 'calendar_ui_support.dart';

/// Host integration: real SQLite + real app widgets, injected elapsed clock
/// and OS alerts. This does not establish airplane-mode delivery on a phone.
void main() {
  setUpAll(sqfliteFfiInit);
  testWidgets(
    'UI focus, manual break, history and settings survive SQLite reopen',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final directory = await tester.runAsync(
        () => Directory.systemTemp.createTemp('poma-ui-flow-'),
      );
      final path = '${directory!.path}/poma.db';
      final clock = FakeClock();
      final alerts = FakeAlerts();
      var repository = SqliteRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: path,
      );
      var app = (await tester.runAsync(
        () => AppController.create(repository, clock: clock, alerts: alerts),
      ))!;
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(finder);
          await Future<void>.delayed(Duration.zero);
          await app.flush();
        });
        await tester.pumpAndSettle();
      }

      addTearDown(() async {
        app.dispose();
        await app.flush();
        await repository.close();
        await directory.delete(recursive: true);
      });
      await tester.pumpWidget(PomaApp(controller: app));
      await tester.pumpAndSettle();
      await openCalendarTasks(tester);
      await enterCalendarTask(tester, 'Read offline');
      await tap(find.byKey(const ValueKey('planner-save')));
      await closeCalendarDrawer(tester);
      final taskId = app.tasks.single.id;
      expect(app.selectedTaskId, taskId);
      await tap(find.byKey(const Key('destination-3')));
      await tester.runAsync(
        () => app.updateSettings(app.settings.copyWith(focusMinutes: 1)),
      );
      await tester.pumpAndSettle();
      await tap(find.byKey(const Key('destination-0')));
      await tap(find.byKey(const Key('timer-toggle')));
      await tap(find.text('Not now'));
      expect(app.timer.status, RunStatus.running);
      final runId = app.timer.runId;
      clock.advance(const Duration(minutes: 1));
      await tester.runAsync(app.reconcile);
      await tester.pumpAndSettle();
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.ready);
      expect(app.sessions.single.id, runId);
      await tap(find.byKey(const Key('timer-toggle')));
      expect(app.timer.status, RunStatus.running);
      await tap(find.byKey(const Key('destination-2')));
      await tester.runAsync(app.loadAnalytics);
      await tester.pumpAndSettle();
      expect(app.analytics!.today.count, 1);
      expect(app.analytics!.thisWeek.count, 1);
      await tap(find.byKey(const Key('analytics-history-tab')));
      await tester.runAsync(() => app.loadHistory());
      await tester.runAsync(app.loadSummaries);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Read offline'), 300);
      await tester.pumpAndSettle();
      expect(find.text('Read offline'), findsOneWidget);
      expect(app.todaySummary!.count, 1);
      await tap(find.byKey(const Key('destination-3')));
      await tap(find.byTooltip('Increase Focus duration'));
      await tester.scrollUntilVisible(find.text('Dark'), 300);
      await tester.pumpAndSettle();
      await tap(find.text('Dark'));
      expect(app.settings.focusMinutes, 2);
      expect(app.timer.totalSeconds, 300);
      final breakId = app.timer.runId;
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await app.flush();
        app.dispose();
        await repository.close();
        repository = SqliteRepository(
          factory: databaseFactoryFfiNoIsolate,
          databasePath: path,
        );
        app = await AppController.create(
          repository,
          clock: clock,
          alerts: FakeAlerts(),
        );
        await app.loadHistory();
        await app.loadSummaries();
      });
      await tester.pumpWidget(PomaApp(controller: app));
      await tester.pumpAndSettle();
      expect(app.settings.focusMinutes, 2);
      expect(app.settings.appearance, 'dark');
      expect(app.tasks.single.title, 'Read offline');
      expect(app.selectedTaskId, taskId);
      expect(app.sessions.single.id, runId);
      expect(app.sessions.single.taskTitle, 'Read offline');
      expect(app.timer.runId, breakId);
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.running);
      expect(app.lastPhaseCompletion, isNull);
      expect(alerts.permissionRequests, 0);
      await tap(find.byKey(const Key('destination-2')));
      await tester.runAsync(app.loadAnalytics);
      await tester.pumpAndSettle();
      expect(app.analytics!.today.count, 1);
      await tap(find.byKey(const Key('analytics-history-tab')));
      await tester.runAsync(app.loadHistory);
      await tester.pumpAndSettle();
      await tap(find.byKey(ValueKey('delete-session-$runId')));
      await tap(find.widgetWithText(FilledButton, 'Delete'));
      await tap(find.byKey(const Key('analytics-overview-tab')));
      await tester.runAsync(app.loadAnalytics);
      await tester.pumpAndSettle();
      expect(app.analytics!.today.count, 0);
      expect(app.analytics!.thisWeek.count, 0);
      expect(app.timer.runId, breakId);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );
}
