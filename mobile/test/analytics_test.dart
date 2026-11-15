import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/domain/analytics.dart';
import 'package:poma/domain/models.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'support.dart';

DateTime utcBoundary(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

FocusSession analyticsCompletion(String id, DateTime end) => FocusSession(
  id: id,
  startedAt: end.subtract(const Duration(minutes: 25)),
  endedAt: end,
  focusSeconds: 1500,
);

Future<AppController> createAnalyticsApp(
  MemoryRepository repository,
  FakeClock clock,
) => AppController.create(
  repository,
  clock: clock,
  toLocal: (date) => date,
  dayRange: (date) => DayRange(
    date,
    utcBoundary(date),
    DateTime.utc(date.year, date.month, date.day + 1),
  ),
);

Future<void> drainAnalytics() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'six metrics use calendar completion dates and fixed zero-inclusive windows',
    () async {
      final repository = MemoryRepository(
        SavedState(
          sessions: [
            analyticsCompletion('today', DateTime.utc(2026, 11, 15, 9)),
            analyticsCompletion('monday', DateTime.utc(2026, 11, 9)),
            analyticsCompletion('last-sunday', DateTime.utc(2026, 11, 8)),
            analyticsCompletion('last-month', DateTime.utc(2026, 10, 31)),
            analyticsCompletion(
              'first-average-day',
              DateTime.utc(2026, 10, 16),
            ),
            analyticsCompletion(
              'before-average-day',
              DateTime.utc(2026, 10, 15),
            ),
            analyticsCompletion(
              'first-average-week',
              DateTime.utc(2026, 8, 17),
            ),
            analyticsCompletion(
              'before-average-week',
              DateTime.utc(2026, 8, 16),
            ),
            analyticsCompletion(
              'first-average-month',
              DateTime.utc(2025, 11, 1),
            ),
            analyticsCompletion(
              'before-average-month',
              DateTime.utc(2025, 10, 31),
            ),
          ],
        ),
      );
      final query = AnalyticsQuery.forDate(
        DateTime(2026, 11, 15),
        boundaryUtc: utcBoundary,
      );
      final snapshot = AnalyticsSnapshot(
        query,
        await repository.readSessionTotals(query.ranges),
      );
      expect(snapshot.today.count, 1);
      expect(snapshot.thisWeek.count, 2);
      expect(snapshot.lastMonth.count, 3);
      expect(snapshot.dailyAverage, 4 / 30);
      expect(snapshot.weeklyAverage, 5 / 12);
      expect(snapshot.monthlyAverage, .5);
      expect(snapshot.today.focusSeconds, 1500);
      expect(query.metrics[3].start, DateTime(2026, 10, 16));
      expect(query.metrics[4].start, DateTime(2026, 8, 17));
      expect(query.metrics[5].start, DateTime(2025, 11, 1));
    },
  );

  test(
    'Monday boundaries, leap February and year changes produce bounded buckets',
    () {
      final january = AnalyticsQuery.forDate(
        DateTime(2027, 1, 1),
        boundaryUtc: utcBoundary,
      );
      expect(january.metrics[1].start, DateTime(2026, 12, 28));
      expect(january.metrics[2].start, DateTime(2026, 12, 1));
      expect(january.metrics[5].start, DateTime(2026, 1, 1));
      for (final year in [2024, 2026]) {
        final month = AnalyticsQuery.forDate(
          DateTime(year, 3, 1),
          period: AnalyticsPeriod.month,
          anchor: DateTime(year, 2),
          boundaryUtc: utcBoundary,
        );
        expect(month.buckets.length, year == 2024 ? 29 : 28);
        expect(month.buckets.last.end, DateTime(year, 3));
        expect(month.canGoForward, isTrue);
      }
      final longest = AnalyticsQuery.forDate(
        DateTime(2026, 12, 15),
        period: AnalyticsPeriod.month,
        boundaryUtc: utcBoundary,
      );
      expect(longest.ranges.length, 37);
      expect(longest.isFuture(15), isTrue);
      expect(longest.isCurrent(14), isTrue);
      final future = AnalyticsQuery.forDate(
        DateTime(2026, 12, 15),
        period: AnalyticsPeriod.year,
        anchor: DateTime(2030),
        boundaryUtc: utcBoundary,
      );
      expect(future.anchor, DateTime(2026));
      expect(future.buckets.length, 12);
      expect(future.canGoForward, isFalse);
    },
  );

  test('day windows follow real 23-hour and 25-hour timezone boundaries', () {
    tz_data.initializeTimeZones();
    final zone = tz.getLocation('America/New_York');
    DateTime boundary(DateTime date) =>
        tz.TZDateTime(zone, date.year, date.month, date.day).toUtc();
    for (final entry in {
      DateTime(2026, 3, 8): 23,
      DateTime(2026, 11, 1): 25,
    }.entries) {
      final query = AnalyticsQuery.forDate(entry.key, boundaryUtc: boundary);
      final range = query.metrics.first.range;
      expect(range.endUtc.difference(range.startUtc).inHours, entry.value);
      expect(
        query.ranges.every((range) => range.endUtc.isAfter(range.startUtc)),
        isTrue,
      );
    }
  });

  test(
    'new and empty histories retain full denominators and reject incomplete snapshots',
    () async {
      final query = AnalyticsQuery.forDate(
        DateTime(2026, 11, 15),
        boundaryUtc: utcBoundary,
      );
      final repository = MemoryRepository(
        SavedState(
          sessions: [
            analyticsCompletion('yesterday', DateTime.utc(2026, 11, 14)),
          ],
        ),
      );
      final snapshot = AnalyticsSnapshot(
        query,
        await repository.readSessionTotals(query.ranges),
      );
      expect(snapshot.dailyAverage, 1 / 30);
      expect(snapshot.weeklyAverage, 0);
      expect(snapshot.monthlyAverage, 0);
      final empty = AnalyticsSnapshot(
        query,
        List.filled(query.ranges.length, const SessionTotals(0, 0)),
      );
      expect(empty.hasSessions, isFalse);
      expect(empty.dailyAverage, 0);
      expect(() => AnalyticsSnapshot(query, []), throwsArgumentError);
    },
  );

  test(
    'historical chart sessions suppress the empty state even with zero recent metrics',
    () async {
      final query = AnalyticsQuery.forDate(
        DateTime(2026, 11, 15),
        period: AnalyticsPeriod.year,
        anchor: DateTime(2024),
        boundaryUtc: utcBoundary,
      );
      final repository = MemoryRepository(
        SavedState(
          sessions: [
            analyticsCompletion('older-history', DateTime.utc(2024, 4, 12)),
          ],
        ),
      );
      final snapshot = AnalyticsSnapshot(
        query,
        await repository.readSessionTotals(query.ranges),
      );
      expect(snapshot.today.count, 0);
      expect(snapshot.monthlyAverage, 0);
      expect(snapshot.bucket(3).count, 1);
      expect(snapshot.hasSessions, isTrue);
    },
  );

  test(
    'overview loads aggregates independently of history pagination and unrelated writes',
    () async {
      final repository = AnalyticsRepository(
        SavedState(
          sessions: List.generate(
            55,
            (i) => analyticsCompletion(
              'session-$i',
              DateTime.utc(2026, 11, 15, 0, i),
            ),
          ),
        ),
      );
      final app = await createAnalyticsApp(
        repository,
        FakeClock(DateTime.utc(2026, 11, 15, 12)),
      );
      addTearDown(app.dispose);
      app.showInsights(true, history: false);
      await drainAnalytics();
      expect(app.analytics!.today.count, 55);
      expect(repository.historyReads, 0);
      final reads = repository.analyticsReads;
      app.addTask('Unrelated task');
      await app.flush();
      await drainAnalytics();
      expect(repository.analyticsReads, reads);
      app.showAnalyticsHistory(true);
      await drainAnalytics();
      expect(app.sessions.length, 50);
      expect(app.historyPage!.hasOlder, isTrue);
      app.showAnalyticsHistory(false);
      await drainAnalytics();
      expect(app.analytics!.today.count, 55);
    },
  );

  test('older period responses cannot overwrite a later selection', () async {
    final repository = AnalyticsRepository();
    final app = await createAnalyticsApp(
      repository,
      FakeClock(DateTime.utc(2026, 11, 15, 12)),
    );
    addTearDown(app.dispose);
    final gate = Completer<List<SessionTotals>>();
    repository.gate = gate;
    app.setAnalyticsPeriod(AnalyticsPeriod.month);
    final count = app.analyticsQuery.ranges.length;
    await drainAnalytics();
    repository.gate = null;
    app.setAnalyticsPeriod(AnalyticsPeriod.year);
    await drainAnalytics();
    gate.complete(List.filled(count, const SessionTotals(99, 1500)));
    await drainAnalytics();
    expect(app.analytics!.query.period, AnalyticsPeriod.year);
    expect(app.analytics!.today.count, 0);
    expect(app.analyticsLoading, isFalse);
  });

  test('failed reads retain dated values and retry recovers', () async {
    final repository = AnalyticsRepository(
      SavedState(
        sessions: [analyticsCompletion('one', DateTime.utc(2026, 11, 15))],
      ),
    );
    final app = await createAnalyticsApp(
      repository,
      FakeClock(DateTime.utc(2026, 11, 15, 12)),
    );
    addTearDown(app.dispose);
    await app.loadAnalytics();
    repository.failAnalytics = true;
    await app.loadAnalytics();
    expect(app.analytics!.today.count, 1);
    expect(app.analyticsStale, isTrue);
    expect(app.analyticsError, isNotNull);
    repository.failAnalytics = false;
    await app.loadAnalytics();
    expect(app.analyticsStale, isFalse);
    expect(app.analyticsError, isNull);
  });

  test(
    'completion save failures count after durable retry and eligible Skip counts once',
    () async {
      final repository = AnalyticsRepository();
      final clock = FakeClock(DateTime.utc(2026, 11, 15, 12));
      final app = await createAnalyticsApp(repository, clock);
      addTearDown(app.dispose);
      app.showInsights(true, history: false);
      await drainAnalytics();
      await app.toggleTimer();
      repository.failWrites = true;
      clock.advance(const Duration(minutes: 21));
      final run = app.timer.runId;
      await app.skipTimer(expectedRunId: run);
      await drainAnalytics();
      expect(app.analytics!.today.count, 0);
      expect(app.analyticsStale, isTrue);
      repository.failWrites = false;
      await app.retrySave();
      await drainAnalytics();
      expect(app.analytics!.today.count, 1);
      expect(app.analytics!.today.focusSeconds, 1260);
      expect(app.analyticsStale, isFalse);
      await app.skipTimer(expectedRunId: run);
      await app.reconcile();
      await drainAnalytics();
      expect(app.analytics!.today.count, 1);
    },
  );

  test(
    'deletion and reset invalidate pending reads and refresh all metrics',
    () async {
      final repository = AnalyticsRepository(
        SavedState(
          sessions: [analyticsCompletion('one', DateTime.utc(2026, 11, 15))],
        ),
      );
      final app = await createAnalyticsApp(
        repository,
        FakeClock(DateTime.utc(2026, 11, 15, 12)),
      );
      addTearDown(app.dispose);
      app.showInsights(true, history: false);
      await drainAnalytics();
      final gate = Completer<List<SessionTotals>>();
      repository.gate = gate;
      final old = app.loadAnalytics();
      final size = app.analyticsQuery.ranges.length;
      await drainAnalytics();
      repository.gate = null;
      await app.deleteHistory(id: 'one');
      await drainAnalytics();
      gate.complete(List.filled(size, const SessionTotals(99, 1500)));
      await old;
      expect(app.analytics!.today.count, 0);
      app.moveAnalytics(-1);
      await drainAnalytics();
      expect(await app.deleteAllLocalData(), isTrue);
      await drainAnalytics();
      expect(app.analytics!.today.count, 0);
      expect(app.analyticsQuery.isCurrentPeriod, isTrue);
    },
  );

  test(
    'midnight reconciliation and resume regroup completions for the device timezone',
    () async {
      var offset = 0;
      final repository = AnalyticsRepository(
        SavedState(
          sessions: [
            analyticsCompletion('boundary', DateTime.utc(2026, 11, 16)),
          ],
        ),
      );
      final clock = FakeClock(DateTime.utc(2026, 11, 15, 23, 59));
      final app = await AppController.create(
        repository,
        clock: clock,
        toLocal: (date) => date.add(Duration(hours: offset)),
        dayRange: (date) => DayRange(
          date,
          DateTime.utc(
            date.year,
            date.month,
            date.day,
          ).subtract(Duration(hours: offset)),
          DateTime.utc(
            date.year,
            date.month,
            date.day + 1,
          ).subtract(Duration(hours: offset)),
        ),
      );
      addTearDown(app.dispose);
      app.showInsights(true, history: false);
      await drainAnalytics();
      expect(app.analytics!.today.count, 0);
      clock.advance(const Duration(minutes: 1));
      await app.reconcile();
      await drainAnalytics();
      expect(app.analytics!.today.count, 1);
      expect(app.analytics!.query.today, DateTime(2026, 11, 16));
      offset = -5;
      await app.setForeground(true);
      await drainAnalytics();
      expect(app.analytics!.query.today, DateTime(2026, 11, 15));
      expect(app.analytics!.today.count, 1);
      expect(
        repository.state.sessions.single.endedAt,
        DateTime.utc(2026, 11, 16),
      );
    },
  );

  test('navigation and disposal discard in-flight results', () async {
    final repository = AnalyticsRepository();
    final app = await createAnalyticsApp(repository, FakeClock());
    final gate = Completer<List<SessionTotals>>();
    repository.gate = gate;
    final read = app.loadAnalytics();
    app.showInsights(false);
    app.dispose();
    gate.complete(List.filled(13, const SessionTotals(99, 1500)));
    await read;
    expect(app.analytics, isNull);
  });
}

class AnalyticsRepository extends MemoryRepository {
  AnalyticsRepository([super.initial]);
  int analyticsReads = 0;
  int historyReads = 0;
  bool failAnalytics = false;
  Completer<List<SessionTotals>>? gate;

  @override
  Future<List<SessionTotals>> readSessionTotals(List<SessionRange> ranges) {
    analyticsReads++;
    if (gate != null) return gate!.future;
    if (failAnalytics) {
      return Future.error(const StorageFailure(StorageFailureKind.unreadable));
    }
    return super.readSessionTotals(ranges);
  }

  @override
  Future<HistoryPage> readHistoryPage({
    HistoryCursor? before,
    HistoryCursor? after,
  }) {
    historyReads++;
    return super.readHistoryPage(before: before, after: after);
  }
}
