import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'support.dart';
import 'alert_support.dart';

void main() {
  testWidgets('failed history is an error, retry shows a real empty state', (
    tester,
  ) async {
    final repository = ReadRepository()..failReads = true;
    final app = await AppController.create(repository, clock: FakeClock());
    await tester.pumpWidget(PomaApp(controller: app));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Insights'));
    await tester.pumpAndSettle();
    expect(
      find.text('History could not be read. Your data is kept. Retry.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Finish your first focus session'),
      findsNothing,
    );
    expect(find.text('0 min'), findsNothing);
    repository.failReads = false;
    await tester.tap(find.text('Retry history'));
    await app.loadSummaries();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Finish your first focus session'),
      findsOneWidget,
    );
    expect(app.historyError, isNull);
    await tester.pumpWidget(const SizedBox());
    app.dispose();
  });

  testWidgets(
    'history pages, confirmation cancel, delete and clear history work',
    (tester) async {
      final sessions = List.generate(
        55,
        (i) => FocusSession(
          id: 'id-${i.toString().padLeft(3, '0')}',
          startedAt: DateTime.utc(2026, 10, 20),
          endedAt: DateTime.utc(2026, 10, 20, 0, i),
          focusSeconds: 60,
          taskTitle: 'Task $i',
        ),
      );
      final repository = ReadRepository(SavedState(sessions: sessions));
      final app = await AppController.create(repository, clock: FakeClock());
      await tester.pumpWidget(PomaApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(app.sessions.length, 50);
      expect(app.historyPage!.hasOlder, isTrue);
      await tester.scrollUntilVisible(find.text('Older'), 500, maxScrolls: 30);
      await tester.tap(find.text('Older'));
      await tester.pumpAndSettle();
      expect(app.sessions.length, 5);
      expect(app.historyPage!.hasNewer, isTrue);
      await tester.ensureVisible(find.byTooltip('Delete session').first);
      await tester.tap(find.byTooltip('Delete session').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.state.sessions.length, 55);
      await tester.tap(find.byTooltip('Delete session').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repository.state.sessions.length, 54);
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Clear focus history'), 400);
      await tester.tap(find.text('Clear focus history'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repository.state.sessions, isEmpty);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );

  testWidgets(
    'full reset confirmation and native cleanup failure have retry feedback',
    (tester) async {
      final repository = ReadRepository();
      final alerts = FakeAlerts();
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        alerts: alerts,
      );
      app.addTask('Kept until confirmation');
      await app.flush();
      await tester.pumpWidget(PomaApp(controller: app));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Delete all local data'), 400);
      await tester.tap(find.text('Delete all local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.state.tasks.length, 1);
      alerts.failBefore = true;
      await tester.tap(find.text('Delete all local data'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(app.cleanupPending, isTrue);
      expect(find.text('Retry deletion'), findsOneWidget);
      alerts.failBefore = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Retry deletion'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry deletion'));
      await tester.pumpAndSettle();
      expect(app.cleanupPending, isFalse);
      expect(repository.state.tasks, isEmpty);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    },
  );

  test(
    'stale async pages cannot overwrite newer results or reappear after deletion',
    () async {
      final repository = ReadRepository();
      final app = await AppController.create(repository, clock: FakeClock());
      final gate = Completer<HistoryPage>();
      repository.gate = gate;
      final old = app.loadHistory();
      await Future<void>.delayed(Duration.zero);
      repository.gate = null;
      await app.loadHistory();
      gate.complete(
        HistoryPage([
          FocusSession(
            id: 'stale',
            startedAt: DateTime.utc(2026),
            endedAt: DateTime.utc(2026),
            focusSeconds: 60,
          ),
        ]),
      );
      await old;
      expect(app.sessions, isEmpty);
      expect(app.historyLoading, isFalse);
      repository.failReads = true;
      await app.loadHistory();
      expect(app.historyError, isNotNull);
      expect(app.historyLoaded, isTrue);
      repository.failReads = false;
      await app.retryHistory();
      expect(app.historyError, isNull);
      app.dispose();
    },
  );

  test(
    'foreground date and timezone reconciliation refresh local-day aggregates',
    () async {
      var offset = 0;
      final session = FocusSession(
        id: 'midnight',
        startedAt: DateTime.utc(2026, 10, 20, 23, 30),
        endedAt: DateTime.utc(2026, 10, 21),
        focusSeconds: 1500,
      );
      final repository = ReadRepository(SavedState(sessions: [session]));
      final clock = FakeClock(DateTime.utc(2026, 10, 20, 23, 59));
      final app = await AppController.create(
        repository,
        clock: clock,
        toLocal: (utc) => utc.add(Duration(hours: offset)),
        dayRange: (day) => DayRange(
          day,
          DateTime.utc(
            day.year,
            day.month,
            day.day,
          ).subtract(Duration(hours: offset)),
          DateTime.utc(
            day.year,
            day.month,
            day.day + 1,
          ).subtract(Duration(hours: offset)),
        ),
      );
      await app.loadSummaries();
      expect(app.todaySummary!.count, 0);
      clock.advance(const Duration(minutes: 1));
      await app.refresh();
      await app.loadSummaries();
      expect(app.todaySummary!.date.day, 21);
      expect(app.todaySummary!.count, 1);
      offset = -5;
      await app.reconcile(forceAlerts: true);
      await app.loadSummaries();
      expect(app.todaySummary!.date.day, 20);
      expect(app.todaySummary!.count, 1);
      expect(
        repository.state.sessions.single.endedAt,
        DateTime.utc(2026, 10, 21),
      );
      app.dispose();
    },
  );
}

class ReadRepository extends MemoryRepository {
  ReadRepository([super.initial]);
  bool failReads = false;
  Completer<HistoryPage>? gate;
  @override
  Future<HistoryPage> readHistoryPage({
    HistoryCursor? before,
    HistoryCursor? after,
  }) async {
    if (gate != null) return gate!.future;
    if (failReads) throw const StorageFailure(StorageFailureKind.unreadable);
    return super.readHistoryPage(before: before, after: after);
  }

  @override
  Future<List<DaySummary>> readDaySummaries(List<DayRange> days) async {
    if (failReads) throw const StorageFailure(StorageFailureKind.unreadable);
    return super.readDaySummaries(days);
  }
}
