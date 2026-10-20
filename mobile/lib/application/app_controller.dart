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
  ) : tasks = state.tasks.toList(),
      sessions = state.sessions.toList(),
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
  }) async {
    final state = await repository.load();
    state.timer?.validate();
    final controller = AppController._(
      repository,
      state,
      clock,
      await clock.sample(),
      alerts,
    );
    final result = await controller.reconcile(forceAlerts: true);
    if (!result.clockSucceeded) {
      controller.dispose();
      throw const TimerClockException();
    }
    return controller;
  }

  final LocalRepository repository;
  final TimerEngine timer;
  final TimerClock clock;
  final AlertCoordinator? _alerts;
  final AlertState _savedAlerts;
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
    final operation = _commands.then((_) async {
      if (_disposed) return _idleResult();
      late ClockReading now;
      late TimerTransition transition;
      try {
        now = await clock.sample();
        if (_disposed) return _idleResult();
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
      if (alertsEnabled != null) _alerts?.setEnabled(alertsEnabled);
      final completed = transition.completion;
      if (completed != null && !sessions.any((s) => s.id == completed.id)) {
        sessions.insert(0, completed);
      }
      // Capture state in command order before allowing another user action.
      final snapshot = timer.snapshot();
      final alertChanged = _alerts?.update(snapshot, now) ?? false;
      final save =
          transition.changed ||
              checkpoint ||
              alertChanged ||
              alertsEnabled != null
          ? _persist()
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
            unawaited(reconcile(forceAlerts: true, checkpoint: true));
          });
          if (requestPermission && persistence != PersistenceOutcome.failed) {
            await _alerts.port.requestPermission();
          }
          await _alerts.synchronize(
            durable: persistence != PersistenceOutcome.failed,
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
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 160) return;
    final task = FocusTask(id: newLocalId(), title: clean);
    tasks.add(task);
    selectedTaskId ??= task.id;
    _changed();
  }

  void editTask(String id, String title) {
    final index = tasks.indexWhere((task) => task.id == id);
    final clean = title.trim();
    if (index < 0 || clean.isEmpty || clean.length > 160) return;
    tasks[index] = tasks[index].copyWith(title: clean);
    _changed();
  }

  void toggleTask(String id) {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    tasks[index] = tasks[index].copyWith(done: !tasks[index].done);
    if (tasks[index].done && selectedTaskId == id) selectedTaskId = null;
    _changed();
  }

  void selectTask(String? id) {
    selectedTaskId = id;
    _changed();
  }

  void deleteTask(String id) {
    tasks.removeWhere((task) => task.id == id);
    if (selectedTaskId == id) selectedTaskId = null;
    _changed();
  }

  Future<void> retrySave() async {
    await _enqueue(TimerAction.reconcile, checkpoint: true, forceAlerts: true);
  }

  Future<void> flush() async {
    await _commands;
    await _writes;
  }

  void _changed() {
    _persist();
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

  Future<PersistenceOutcome> _persist() {
    final state = SavedState(
      settings: settings,
      timer: timer.snapshot(),
      tasks: tasks,
      sessions: sessions,
      selectedTaskId: selectedTaskId,
      alerts: _alerts?.state ?? _savedAlerts,
    );
    // Serialize writes in the order of user actions; later state cannot be
    // overwritten by an earlier, slower database transaction.
    final result = _writes
        .then((_) => repository.save(state))
        .then((_) {
          if (saveError != null) {
            saveError = null;
            if (!_disposed) notifyListeners();
          }
          return PersistenceOutcome.saved;
        })
        .catchError((Object error, StackTrace stack) {
          saveError =
              'Changes could not be saved. Free up storage and try again.';
          if (!_disposed) notifyListeners();
          return PersistenceOutcome.failed;
        });
    _writes = result.then<void>((_) {});
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _alerts?.port.dispose();
    super.dispose();
  }
}
