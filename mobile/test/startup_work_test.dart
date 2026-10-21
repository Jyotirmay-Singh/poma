import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/domain/alert_state.dart';
import 'package:poma/domain/models.dart';

import 'alert_support.dart';
import 'support.dart';

void main() {
  test(
    'startup and foreground summary reads are counted independently',
    () async {
      final repository = CountingRepository();
      final alerts = FakeAlerts();
      final clock = FakeClock();
      final app = await AppController.create(
        repository,
        clock: clock,
        alerts: alerts,
      );
      addTearDown(app.dispose);
      await drainReads();
      final createReads = repository.summaryReads;
      final createSyncs = alerts.syncs;

      await app.setForeground(true);
      await drainReads();
      final firstForegroundReads = repository.summaryReads - createReads;
      final foregroundSyncs = alerts.syncs - createSyncs;
      final beforeUnchanged = repository.summaryReads;
      await app.setForeground(true);
      await drainReads();
      final unchangedForegroundReads =
          repository.summaryReads - beforeUnchanged;

      await app.setForeground(false);
      await drainReads();
      final beforeResume = repository.summaryReads;
      await app.setForeground(true);
      await drainReads();
      final resumedForegroundReads = repository.summaryReads - beforeResume;

      final beforeDateChange = repository.summaryReads;
      clock.advance(const Duration(days: 1));
      await app.reconcile(forceAlerts: true);
      await drainReads();
      final dateChangeReads = repository.summaryReads - beforeDateChange;

      final measurements = {
        'method': 'Repository call counters; FakeClock and FakeAlerts on host',
        'scope': 'work counts only; no device latency or energy measurement',
        'recorded_at_utc': DateTime.now().toUtc().toIso8601String(),
        'create_summary_reads': createReads,
        'first_foreground_summary_reads': firstForegroundReads,
        'unchanged_foreground_summary_reads': unchangedForegroundReads,
        'resumed_foreground_summary_reads': resumedForegroundReads,
        'forced_date_change_summary_reads': dateChangeReads,
        'history_reads': repository.historyReads,
        'create_native_alert_syncs': createSyncs,
        'first_foreground_native_alert_syncs': foregroundSyncs,
        'state_writes': repository.writes,
      };
      const evidencePath = String.fromEnvironment('POMA_WORK_COUNTS_PATH');
      if (evidencePath.isNotEmpty) {
        final evidence = File(evidencePath);
        await evidence.parent.create(recursive: true);
        await evidence.writeAsString(
          '${const JsonEncoder.withIndent('  ').convert(measurements)}\n',
        );
      }
      expect(createReads, 1);
      expect(firstForegroundReads, 1);
      expect(resumedForegroundReads, 1);
      expect(dateChangeReads, 1);
      expect(unchangedForegroundReads, 0);
      expect(repository.historyReads, 0);
      expect(repository.writes, 0);
      expect(createSyncs, 1);
      expect(foregroundSyncs, 1);
      expect(app.timer.status, RunStatus.ready);
      expect(app.tickerActive, isFalse);
    },
  );

  test(
    'summary reads do not weaken the startup native alert barrier',
    () async {
      final summaryGate = Completer<List<DaySummary>>();
      final alertGate = Completer<void>();
      final repository = CountingRepository()..summaryGate = summaryGate;
      final alerts = GatedAlerts(alertGate);
      var created = false;
      final loading =
          AppController.create(
            repository,
            clock: FakeClock(),
            alerts: alerts,
          ).then((app) {
            created = true;
            return app;
          });

      await drainReads();
      expect(created, isFalse);
      expect(repository.historyReads, 0);
      alertGate.complete();
      final app = await loading;
      addTearDown(app.dispose);
      expect(created, isTrue);
      expect(app.summariesLoading, isTrue);
      expect(app.timer.status, RunStatus.ready);
      expect(app.tickerActive, isFalse);
      summaryGate.complete([DaySummary(DateTime(2026, 10, 20), 3, 4500)]);
      await drainReads();
      expect(app.todaySummary!.count, 3);
      expect(app.summariesLoading, isFalse);
    },
  );

  testWidgets('native-alert countdown ticks do no storage or alert work', (
    tester,
  ) async {
    final repository = CountingRepository();
    final alerts = FakeAlerts();
    final clock = FakeClock();
    final app = await AppController.create(
      repository,
      clock: clock,
      alerts: alerts,
    );
    await app.setForeground(true);
    await app.toggleTimer();
    final runningReads = repository.summaryReads;
    final runningWrites = repository.writes;
    final runningSyncs = alerts.syncs;
    final runningReceipts = repository.receiptCalls;
    for (var second = 0; second < 5; second++) {
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await app.flush();
    }
    expect(app.timer.remainingSeconds, 1495);
    expect(repository.summaryReads, runningReads);
    expect(repository.writes, runningWrites);
    expect(alerts.syncs, runningSyncs);
    expect(repository.receiptCalls, runningReceipts);

    await app.toggleTimer();
    final pausedReads = repository.summaryReads;
    final pausedWrites = repository.writes;
    final pausedSyncs = alerts.syncs;
    final pausedReceipts = repository.receiptCalls;
    clock.advance(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await app.flush();
    expect(app.timer.status, RunStatus.paused);
    expect(app.tickerActive, isFalse);
    expect(repository.summaryReads, pausedReads);
    expect(repository.writes, pausedWrites);
    expect(alerts.syncs, pausedSyncs);
    expect(repository.receiptCalls, pausedReceipts);

    await app.toggleTimer();
    await app.setForeground(false);
    final backgroundReads = repository.summaryReads;
    final backgroundWrites = repository.writes;
    final backgroundSyncs = alerts.syncs;
    final backgroundReceipts = repository.receiptCalls;
    clock.advance(const Duration(hours: 1));
    await tester.pump(const Duration(hours: 1));
    await app.flush();
    expect(app.tickerActive, isFalse);
    expect(repository.summaryReads, backgroundReads);
    expect(repository.writes, backgroundWrites);
    expect(alerts.syncs, backgroundSyncs);
    expect(repository.receiptCalls, backgroundReceipts);

    await app.setForeground(true);
    expect(app.timer.phase, FocusPhase.shortBreak);
    expect(app.timer.status, RunStatus.ready);
    expect(app.sessions, hasLength(1));
    final completedReads = repository.summaryReads;
    final completedWrites = repository.writes;
    final completedSyncs = alerts.syncs;
    final completedReceipts = repository.receiptCalls;
    clock.advance(const Duration(hours: 1));
    await tester.pump(const Duration(hours: 1));
    await app.flush();
    expect(app.tickerActive, isFalse);
    expect(repository.summaryReads, completedReads);
    expect(repository.writes, completedWrites);
    expect(alerts.syncs, completedSyncs);
    expect(repository.receiptCalls, completedReceipts);
    expect(app.sessions, hasLength(1));
    app.dispose();
  });
}

Future<void> drainReads() => Future<void>.delayed(Duration.zero);

class CountingRepository extends MemoryRepository {
  int summaryReads = 0;
  int historyReads = 0;
  int receiptCalls = 0;
  Completer<List<DaySummary>>? summaryGate;

  @override
  Future<List<DaySummary>> readDaySummaries(List<DayRange> days) async {
    summaryReads++;
    if (summaryGate != null) return summaryGate!.future;
    return super.readDaySummaries(days);
  }

  @override
  Future<HistoryPage> readHistoryPage({
    HistoryCursor? before,
    HistoryCursor? after,
  }) {
    historyReads++;
    return super.readHistoryPage(before: before, after: after);
  }

  @override
  Future<bool> recordAlertReceipt(String key) {
    receiptCalls++;
    return super.recordAlertReceipt(key);
  }
}

class GatedAlerts extends FakeAlerts {
  GatedAlerts(this.gate);
  final Completer<void> gate;

  @override
  Future<AlertAvailability> synchronize(AlertState state) async {
    await gate.future;
    return super.synchronize(state);
  }
}
