import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_repository.dart';
import 'alert_coordinator.dart';
import 'local_alerts.dart';
import '../domain/alert_state.dart';
import '../domain/models.dart';
import '../domain/timer_engine.dart';

enum PersistenceOutcome { notRequired, saved, failed }

class TimerAlertIntent {
  const TimerAlertIntent({
    required this.runId,
    required this.phase,
    required this.remainingMicros,
    required this.deadlineUtc,
    this.notificationId,
    this.generation,
  });
  final String runId;
  final FocusPhase phase;
  final int remainingMicros;
  final DateTime deadlineUtc;
  final int? notificationId;
  final int? generation;
}

class ReconciliationResult {
  const ReconciliationResult({
    required this.snapshot,
    required this.transition,
    required this.persistence,
    required this.clockSucceeded,
    this.alert,
    this.alertAvailability,
  });
  final TimerSnapshot snapshot;
  final TimerTransition transition;
  final PersistenceOutcome persistence;
  final bool clockSucceeded;
  final TimerAlertIntent? alert;
  final AlertAvailability? alertAvailability;
}

class AppController extends ChangeNotifier {
  AppController._(
    this.repository,
    SavedState state,
    this.clock,
    ClockReading now,
    LocalAlerts? alerts,
    this._toLocal,
    this._dayRange,
  ) : tasks = state.tasks.toList(),
      sessions = state.sessions.toList(),
      _revision = state.revision,
      cleanupPending = state.cleanupPending,
      _calendarUtc = now.utcNow,
      selectedTaskId = state.selectedTaskId,
      timer = TimerEngine(
        settings: state.settings,
        restored: state.timer,
        now: now,
      ),
      _savedAlerts = state.alerts,
      _alerts = alerts == null
          ? null
          : AlertCoordinator(alerts, repository, state.alerts);

  static Future<AppController> create(
    LocalRepository repository, {
    required TimerClock clock,
    LocalAlerts? alerts,
    DateTime Function(DateTime)? toLocal,
    DayRange Function(DateTime)? dayRange,
  }) async {
    final state = await repository.loadInitial();
    state.timer?.validate();
    final controller = AppController._(
      repository,
      state,
      clock,
      await clock.sample(),
      alerts,
      toLocal ?? _systemLocal,
      dayRange ?? DayRange.local,
    );
    final result = await controller.reconcile(forceAlerts: true);
    if (!result.clockSucceeded) {
      controller.dispose();
      throw const TimerClockException();
    }
    unawaited(controller.loadSummaries());
    return controller;
  }

  final LocalRepository repository;
  final TimerEngine timer;
  final TimerClock clock;
  final AlertCoordinator? _alerts;
  AlertState _savedAlerts;
  AlertAvailability? get alertAvailability => _alerts?.availability;
  bool get needsAlertPermission =>
      _alerts != null && !_alerts.state.permissionRequested;
  bool get alertsEnabled => _alerts?.state.enabled ?? false;
  int get alertOpenRevision => _alerts?.openRevision ?? 0;
  String? get alertMessage {
    // Explain an unanswered permission choice at Start, not as a denial.
    if (needsAlertPermission && alertAvailability == AlertAvailability.denied) {
      return null;
    }
    return switch (alertAvailability) {
      AlertAvailability.delayed =>
        'Alerts may be delayed. Allow precise alerts in Settings.',
      AlertAvailability.denied =>
        'Completion alerts are off in your phone’s notification settings.',
      AlertAvailability.failed || AlertAvailability.unavailable =>
        'Completion alert could not be registered. Your timer is kept. Try again.',
      _ => null,
    };
  }

  TimerSettings get settings => timer.settings;
  final List<FocusTask> tasks;
  final List<FocusSession> sessions;
  String? selectedTaskId;
  String? saveError;
  String? clockError;
  Timer? _ticker;
  Future<void> _writes = Future.value();
  Future<void> _commands = Future.value();
  bool _refreshPending = false;
  bool _disposed = false;
  bool _foreground = false;
  int _revision;
  final List<LocalChange> _pending = [];
  LocalCommit? _attempt;
  int _actionEpoch = 0;
  Future<bool>? _resetOperation;
  bool cleanupPending;
  String? deletionError;
  DateTime _calendarUtc;
  final DateTime Function(DateTime) _toLocal;
  final DayRange Function(DateTime) _dayRange;
  DateTime get localNow => _toLocal(_calendarUtc);
  Timer? _midnight;
  int _readEpoch = 0;
  int _summaryEpoch = 0;
  bool _insightsVisible = false;
  bool historyLoading = false;
  bool historyLoaded = false;
  String? historyError;
  HistoryPage? historyPage;
  HistoryCursor? _before;
  HistoryCursor? _after;
  bool summariesLoading = false;
  String? summaryError;
  List<DaySummary>? summaries;
  DaySummary? get todaySummary {
    final today = localNow;
    for (final summary in summaries ?? <DaySummary>[]) {
      if (summary.date.year == today.year &&
          summary.date.month == today.month &&
          summary.date.day == today.day) {
        return summary;
      }
    }
    return null;
  }

  FocusTask? get selectedTask {
    for (final task in tasks) {
      if (task.id == selectedTaskId && !task.done) return task;
    }
    return null;
  }

  List<FocusSession> sessionsOn(
    DateTime date, {
    DateTime Function(DateTime)? toLocal,
  }) => sessions.where((session) {
    final local = (toLocal ?? _systemLocal)(session.endedAt);
    return local.year == date.year &&
        local.month == date.month &&
        local.day == date.day;
  }).toList();
  static DateTime _systemLocal(DateTime value) => value.toLocal();

  Future<ReconciliationResult> setForeground(bool foreground) {
    if (_foreground == foreground) return Future.value(_idleResult());
    _foreground = foreground;
    _scheduleMidnight();
    if (foreground) _refreshReads();
    if (!foreground) _syncTicker();
    return _enqueue(
      TimerAction.reconcile,
      checkpoint: !foreground && timer.status != RunStatus.ready,
      forceAlerts: foreground,
    );
  }

  Future<ReconciliationResult> reconcile({
    String? expectedRunId,
    bool forceAlerts = false,
    bool checkpoint = false,
  }) => _enqueue(
    TimerAction.reconcile,
    expectedRunId: expectedRunId,
    forceAlerts: forceAlerts,
    checkpoint: checkpoint,
  );
  Future<ReconciliationResult> refresh() => reconcile();

  Future<ReconciliationResult> toggleTimer({
    int? expectedRevision,
    RunStatus? displayedStatus,
  }) => _control(switch (displayedStatus ?? timer.status) {
    RunStatus.ready => TimerAction.start,
    RunStatus.paused => TimerAction.resume,
    RunStatus.running => TimerAction.pause,
  }, expectedRevision: expectedRevision);

  Future<ReconciliationResult> resetTimer({int? expectedRevision}) =>
      _control(TimerAction.reset, expectedRevision: expectedRevision);
  Future<ReconciliationResult> skipTimer({int? expectedRevision}) =>
      _control(TimerAction.skip, expectedRevision: expectedRevision);
  Future<ReconciliationResult> selectPhase(
    FocusPhase phase, {
    int? expectedRevision,
  }) => _control(
    TimerAction.selectPhase,
    phase: phase,
    expectedRevision: expectedRevision,
  );

  Future<ReconciliationResult> updateSettings(TimerSettings next) =>
      _enqueue(TimerAction.updateSettings, nextSettings: next);

  Future<ReconciliationResult> setCompletionAlerts(bool enabled) => _enqueue(
    TimerAction.reconcile,
    alertsEnabled: enabled,
    requestPermission: enabled,
    forceAlerts: true,
  );
  Future<void> openNotificationSettings() async => _alerts?.port.openSettings();
  Future<void> requestPreciseAlerts() async {
    await _alerts?.port.requestExactAccess();
    await reconcile(forceAlerts: true);
  }

  Future<ReconciliationResult> _control(
    TimerAction action, {
    FocusPhase? phase,
    int? expectedRevision,
  }) => _enqueue(
    action,
    expectedRevision: expectedRevision ?? timer.revision,
    phase: phase,
    task: selectedTask,
  );

  /// Session-3 integration seam: explicit, session-targeted actions, never toggle.
  Future<ReconciliationResult> handleTimerAction(
    TimerAction action, {
    required String runId,
  }) {
    if (!const [
          TimerAction.pause,
          TimerAction.resume,
          TimerAction.reset,
          TimerAction.skip,
        ].contains(action) ||
        runId.trim().isEmpty) {
      throw ArgumentError(
        'A supported action and nonempty session ID are required.',
      );
    }
    return _enqueue(action, expectedRunId: runId);
  }

  Future<ReconciliationResult> _enqueue(
    TimerAction action, {
    int? expectedRevision,
    String? expectedRunId,
    FocusPhase? phase,
    FocusTask? task,
    TimerSettings? nextSettings,
    bool checkpoint = false,
    bool forceAlerts = false,
    bool? alertsEnabled,
    bool requestPermission = false,
  }) {
    final epoch = _actionEpoch;
    final operation = _commands.then((_) async {
      if (_disposed || epoch != _actionEpoch) return _idleResult();
      if (cleanupPending &&
          (action == TimerAction.start || action == TimerAction.resume)) {
        if (_pending.isEmpty) await _finishResetCleanup();
        if (cleanupPending) return _idleResult();
      }
      late ClockReading now;
      late TimerTransition transition;
      try {
        now = await clock.sample();
        if (_disposed || epoch != _actionEpoch) return _idleResult();
        transition = timer.apply(
          action,
          now,
          expectedRevision: expectedRevision,
          expectedRunId: expectedRunId,
          selectedPhase: phase,
          task: task,
          nextSettings: nextSettings,
        );
      } on TimerClockException {
        clockError =
            'Timer time could not be read. Try again. Your data is kept.';
        _syncTicker();
        _notify();
        return _idleResult(clockSucceeded: false);
      }
      clockError = null;
      final previousDay = localNow;
      _calendarUtc = now.utcNow;
      if (forceAlerts) _refreshReads();
      if (previousDay.day != localNow.day ||
          previousDay.month != localNow.month ||
          previousDay.year != localNow.year) {
        _refreshReads();
        _scheduleMidnight();
      }
      if (alertsEnabled != null) _alerts?.setEnabled(alertsEnabled);
      final completed = transition.completion;
      if (completed != null &&
          (_before == null && _after == null) &&
          !sessions.any((s) => s.id == completed.id)) {
        sessions.insert(0, completed);
        if (sessions.length > 50) sessions.removeLast();
      }
      // Capture state in command order before allowing another user action.
      final snapshot = timer.snapshot();
      final alertChanged = _alerts?.update(snapshot, now) ?? false;
      final save =
          transition.changed ||
              checkpoint ||
              alertChanged ||
              alertsEnabled != null
          ? _persist(completions: completed == null ? const [] : [completed])
          : null;
      final alert = timer.status == RunStatus.running
          ? TimerAlertIntent(
              runId: timer.runId!,
              phase: timer.phase,
              remainingMicros: timer.remainingMicros,
              notificationId: _alerts?.state.current?.notificationId,
              generation: _alerts?.state.current?.generation,
              deadlineUtc: now.utcNow.add(
                Duration(microseconds: timer.remainingMicros),
              ),
            )
          : null;
      _syncTicker();
      if (_foreground || transition.changed) _notify();
      final persistence = save == null
          ? (saveError == null
                ? PersistenceOutcome.notRequired
                : PersistenceOutcome.failed)
          : await save;
      if (_alerts != null &&
          (forceAlerts ||
              transition.changed ||
              alertChanged ||
              alertsEnabled != null)) {
        try {
          await _alerts.initialize(() {
            _refreshReads();
            _scheduleMidnight();
            unawaited(reconcile(forceAlerts: true, checkpoint: true));
          });
          if (cleanupPending && persistence != PersistenceOutcome.failed) {
            await _finishResetCleanup();
          }
          if (requestPermission && persistence != PersistenceOutcome.failed) {
            await _alerts.port.requestPermission();
          }
          await _alerts.synchronize(
            durable:
                persistence != PersistenceOutcome.failed &&
                !cleanupPending &&
                _pending.isEmpty,
          );
        } catch (_) {
          _alerts.availability = AlertAvailability.failed;
        }
        _notify();
      }
      return ReconciliationResult(
        snapshot: snapshot,
        transition: transition,
        persistence: persistence,
        clockSucceeded: true,
        alert: alert,
        alertAvailability: alertAvailability,
      );
    });
    // A failed caller must not poison later commands.
    _commands = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  ReconciliationResult _idleResult({bool? clockSucceeded}) =>
      ReconciliationResult(
        snapshot: timer.snapshot(),
        transition: const TimerTransition(
          changed: false,
          outcome: TimerCommandOutcome.unchanged,
        ),
        persistence: saveError == null
            ? PersistenceOutcome.notRequired
            : PersistenceOutcome.failed,
        clockSucceeded: clockSucceeded ?? clockError == null,
        alertAvailability: alertAvailability,
      );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @visibleForTesting
  bool get tickerActive => _ticker?.isActive ?? false;

  void addTask(String title) {
    if (_deferUntilReset(() => addTask(title))) return;
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 160) return;
    final task = FocusTask(id: newLocalId(), title: clean);
    tasks.add(task);
    selectedTaskId ??= task.id;
    _changed(tasks: [task]);
  }

  void editTask(String id, String title) {
    if (_deferUntilReset(() => editTask(id, title))) return;
    final index = tasks.indexWhere((task) => task.id == id);
    final clean = title.trim();
    if (index < 0 || clean.isEmpty || clean.length > 160) return;
    if (tasks[index].title == clean) return;
    tasks[index] = tasks[index].copyWith(title: clean);
    _changed(tasks: [tasks[index]]);
  }

  void toggleTask(String id) {
    if (_deferUntilReset(() => toggleTask(id))) return;
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    tasks[index] = tasks[index].copyWith(done: !tasks[index].done);
    if (tasks[index].done && selectedTaskId == id) selectedTaskId = null;
    _changed(tasks: [tasks[index]]);
  }

  void selectTask(String? id) {
    if (_deferUntilReset(() => selectTask(id))) return;
    if (id == selectedTaskId ||
        (id != null && !tasks.any((task) => task.id == id && !task.done))) {
      return;
    }
    selectedTaskId = id;
    _changed();
  }

  void deleteTask(String id) {
    if (_deferUntilReset(() => deleteTask(id))) return;
    if (!tasks.any((task) => task.id == id)) return;
    tasks.removeWhere((task) => task.id == id);
    if (selectedTaskId == id) selectedTaskId = null;
    _changed(deletedTasks: [id]);
  }

  Future<void> retrySave() async {
    if (cleanupPending) {
      final operation = _commands.then((_) async {
        if (await _persist() != PersistenceOutcome.failed) {
          await _finishResetCleanup();
        }
        _notify();
      });
      _commands = operation.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) {},
      );
      await operation;
      return;
    }
    await _enqueue(TimerAction.reconcile, checkpoint: true, forceAlerts: true);
  }

  Future<void> flush() async {
    await _commands;
    await _writes;
  }

  void _changed({
    List<FocusTask> tasks = const [],
    List<String> deletedTasks = const [],
  }) {
    _persist(tasks: tasks, deletedTasks: deletedTasks);
    _syncTicker();
    if (!_disposed) notifyListeners();
  }

  void _syncTicker() {
    if (!_foreground ||
        timer.status != RunStatus.running ||
        _disposed ||
        clockError != null) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (_refreshPending) return;
        _refreshPending = true;
        unawaited(
          refresh().whenComplete(() {
            _refreshPending = false;
          }),
        );
      });
    }
  }

  Future<PersistenceOutcome> _persist({
    List<FocusTask> tasks = const [],
    List<String> deletedTasks = const [],
    List<FocusSession> completions = const [],
    List<String> deletedSessions = const [],
    bool clearHistory = false,
    bool reset = false,
  }) {
    final state = SavedState(
      settings: settings,
      timer: timer.snapshot(),
      selectedTaskId: selectedTaskId,
      alerts: _alerts?.state ?? _savedAlerts,
      cleanupPending: cleanupPending,
    );
    _pending.add(
      LocalChange(
        state: state,
        tasks: tasks,
        deletedTasks: deletedTasks,
        completions: completions,
        deletedSessions: deletedSessions,
        clearHistory: clearHistory,
        reset: reset,
      ),
    );
    _readEpoch++;
    _summaryEpoch++;
    final result = _writes
        .then((_) async {
          while (_pending.isNotEmpty) {
            // A confirmed reset supersedes earlier unsaved edits. Resolve an
            // uncertain prior commit by identity, without replaying old data.
            final resetIndex = _pending.lastIndexWhere(
              (change) => change.reset,
            );
            if (resetIndex >= 0 &&
                (_attempt == null ||
                    !_attempt!.changes.any((change) => change.reset))) {
              final supersedes = _attempt?.id;
              _pending.removeRange(0, resetIndex);
              _attempt = LocalCommit(
                id: newLocalId(),
                expectedRevision: _revision,
                changes: List.of(_pending),
                supersedesId: supersedes,
              );
            }
            final attempt = _attempt ??= LocalCommit(
              id: newLocalId(),
              expectedRevision: _revision,
              changes: List.of(_pending),
            );
            _revision = await repository.commit(attempt);
            _pending.removeRange(0, attempt.changes.length);
            _attempt = null;
          }
          saveError = null;
          if (!cleanupPending) deletionError = null;
          _refreshReads();
          _notify();
          return PersistenceOutcome.saved;
        })
        .catchError((Object error, StackTrace stack) {
          saveError = error is StorageFailure
              ? error.message
              : const StorageFailure(StorageFailureKind.write).message;
          if (!_disposed) notifyListeners();
          return PersistenceOutcome.failed;
        });
    _writes = result.then<void>((_) {});
    return result;
  }

  void showInsights(bool visible) {
    _insightsVisible = visible;
    _readEpoch++;
    historyLoading = false;
    if (visible) {
      unawaited(loadHistory());
      unawaited(loadSummaries());
    }
  }

  Future<void> loadHistory({
    HistoryCursor? before,
    HistoryCursor? after,
  }) async {
    _before = before;
    _after = after;
    final epoch = ++_readEpoch;
    historyLoading = true;
    historyError = null;
    _notify();
    try {
      final page = await repository.readHistoryPage(
        before: before,
        after: after,
      );
      if (_disposed || epoch != _readEpoch) return;
      historyPage = page;
      sessions
        ..clear()
        ..addAll(page.sessions);
      historyLoaded = true;
    } catch (_) {
      if (_disposed || epoch != _readEpoch) return;
      historyError = 'History could not be read. Your data is kept. Retry.';
    } finally {
      if (!_disposed && epoch == _readEpoch) {
        historyLoading = false;
        _notify();
      }
    }
  }

  Future<void> retryHistory() => loadHistory(before: _before, after: _after);

  Future<void> loadSummaries() async {
    final epoch = ++_summaryEpoch;
    summariesLoading = true;
    summaryError = null;
    _notify();
    final now = localNow;
    final days = List.generate(
      _insightsVisible ? 7 : 1,
      (i) => _dayRange(
        DateTime(now.year, now.month, now.day - (_insightsVisible ? 6 : 0) + i),
      ),
    );
    try {
      final result = await repository.readDaySummaries(days);
      if (_disposed || epoch != _summaryEpoch) return;
      summaries = result;
    } catch (_) {
      if (_disposed || epoch != _summaryEpoch) return;
      summaryError = 'Focus totals could not be read. Retry.';
    } finally {
      if (!_disposed && epoch == _summaryEpoch) {
        summariesLoading = false;
        _notify();
      }
    }
  }

  void _refreshReads() {
    if (_disposed) return;
    unawaited(loadSummaries());
    if (_insightsVisible) {
      unawaited(loadHistory(before: _before, after: _after));
    }
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    if (!_foreground || _disposed) return;
    final now = DateTime.now();
    _midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        _calendarUtc = DateTime.now().toUtc();
        _refreshReads();
        _scheduleMidnight();
      },
    );
  }

  Future<bool> deleteHistory({String? id}) {
    // Reconcile an overdue active session before deciding what is deleted.
    unawaited(reconcile());
    final operation = _commands.then((_) async {
      if (_disposed) return false;
      sessions.removeWhere((session) => id == null || session.id == id);
      final outcome = await _persist(
        deletedSessions: id == null ? const [] : [id],
        clearHistory: id == null,
      );
      deletionError = outcome == PersistenceOutcome.failed
          ? 'Deletion could not be saved. Data may still be on this phone. Retry saving.'
          : null;
      if (outcome != PersistenceOutcome.failed) await loadHistory();
      _notify();
      return outcome != PersistenceOutcome.failed;
    });
    _commands = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  bool _deferUntilReset(void Function() action) {
    if (_resetOperation == null) return false;
    final operation = _commands.then((_) => action());
    _commands = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return true;
  }

  Future<bool> deleteAllLocalData() {
    if (_resetOperation != null) return _resetOperation!;
    _actionEpoch++;
    final operation = _commands.then((_) async {
      if (_disposed) return false;
      // Deletion does not depend on obtaining a fresh native clock sample.
      timer.deleteLocalData(
        ClockReading(utcNow: _calendarUtc, elapsed: Duration.zero),
      );
      tasks.clear();
      sessions.clear();
      selectedTaskId = null;
      final old = _alerts?.state ?? _savedAlerts;
      _savedAlerts = AlertState(
        serial: old.serial + 1,
        nextNotificationId: old.nextNotificationId,
      );
      if (_alerts != null) _alerts.state = _savedAlerts;
      cleanupPending = true;
      historyPage = null;
      historyLoaded = false;
      summaries = null;
      _before = null;
      _after = null;
      _syncTicker();
      final outcome = await _persist(reset: true);
      if (outcome == PersistenceOutcome.failed && _alerts != null) {
        try {
          await _alerts.synchronize(durable: false);
        } catch (_) {
          /* Retry uses the saved cleanup marker. */
        }
      }
      if (outcome != PersistenceOutcome.failed) await _finishResetCleanup();
      deletionError = outcome == PersistenceOutcome.failed || cleanupPending
          ? 'Data deletion is not complete. Retry to finish saving and clearing local alerts.'
          : null;
      _notify();
      return deletionError == null;
    });
    final completed = operation.whenComplete(() {
      _resetOperation = null;
    });
    _resetOperation = completed;
    _commands = completed.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return completed;
  }

  Future<void> _finishResetCleanup() async {
    try {
      await _alerts?.port.clearForReset();
      cleanupPending = false;
      final result = await _persist();
      if (result == PersistenceOutcome.failed) {
        cleanupPending = true;
      } else {
        deletionError = null;
      }
    } catch (_) {
      cleanupPending = true;
      deletionError =
          'Local alerts could not be cleared. Retry to finish data deletion.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _midnight?.cancel();
    _alerts?.port.dispose();
    super.dispose();
  }
}
