import 'models.dart';

class ClockReading {
  ClockReading({
    required DateTime utcNow,
    required this.elapsed,
    this.bootCount,
  }) : utcNow = utcNow.toUtc() {
    if (elapsed.isNegative || (bootCount != null && bootCount! < 0)) {
      throw const TimerClockException();
    }
  }
  final DateTime utcNow;
  final Duration elapsed;
  final int? bootCount;
}

abstract interface class TimerClock {
  Future<ClockReading> sample();
}

class TimerClockException implements Exception {
  const TimerClockException();
}

enum TimerAction {
  reconcile,
  start,
  resume,
  pause,
  reset,
  skip,
  selectPhase,
  updateSettings,
}

enum TimerCommandOutcome {
  unchanged,
  applied,
  blocked,
  stale,
  completionConsumed,
}

class TimerTransition {
  const TimerTransition({
    required this.changed,
    required this.outcome,
    this.completedPhase = false,
    this.completion,
    this.previousRunId,
  });
  final bool changed;
  final bool completedPhase;
  final FocusSession? completion;

  /// Identity to cancel/replace even when a break ends without focus history.
  final String? previousRunId;
  final TimerCommandOutcome outcome;
}

/// Synchronous state machine. Callers sample an injectable clock once per
/// operation. Callback frequency and wall time never drive live elapsed time.
class TimerEngine {
  TimerEngine({
    required TimerSettings settings,
    required ClockReading now,
    TimerSnapshot? restored,
  }) : _settings = TimerSettings.fromJson(settings.toJson()),
       _now = now {
    if (restored == null) {
      _prepare(FocusPhase.focus);
    } else {
      restored.validate();
      _phase = restored.phase;
      _status = restored.status;
      _totalSeconds = restored.totalSeconds;
      _completedRounds = restored.completedRounds;
      _remaining = Duration(microseconds: restored.remainingMicros);
      _startedAt = restored.startedAt;
      _runId = restored.runId;
      _taskId = restored.taskId;
      _taskTitle = restored.taskTitle;
      _deadline = restored.deadline?.toUtc();
      _segment = restored.segment;
      if (_status == RunStatus.running) {
        final sameBoot =
            restored.bootCount != null &&
            restored.bootCount == now.bootCount &&
            restored.elapsedDeadlineMicros != null;
        _remaining = sameBoot
            ? Duration(microseconds: restored.elapsedDeadlineMicros!) -
                  now.elapsed
            : _deadline!.difference(now.utcNow);
        if (_remaining > Duration(seconds: _totalSeconds)) {
          _remaining = Duration(seconds: _totalSeconds);
          _deadline = now.utcNow.add(_remaining);
          _recoveryAdjusted = true;
        }
        _anchor = now.elapsed;
      }
    }
  }

  TimerSettings _settings;
  ClockReading _now;
  late FocusPhase _phase;
  late RunStatus _status;
  late int _totalSeconds;
  int _completedRounds = 0;
  int _revision = 0;
  int _segment = 0;
  bool _recoveryAdjusted = false;
  late Duration _remaining;
  Duration _anchor = Duration.zero;
  DateTime? _deadline;
  DateTime? _startedAt;
  String? _runId;
  String? _taskId;
  String? _taskTitle;

  TimerSettings get settings => _settings;
  FocusPhase get phase => _phase;
  RunStatus get status => _status;
  int get totalSeconds => _totalSeconds;
  int get completedRounds => _completedRounds;
  int get displayedRounds => _completedRounds.clamp(0, _settings.rounds);
  int get revision => _revision;
  String? get runId => _runId;
  Duration get _rawRemaining => _status == RunStatus.running
      ? _remaining - (_now.elapsed - _anchor)
      : _remaining;
  int get remainingMicros =>
      _rawRemaining.inMicroseconds.clamp(0, _totalSeconds * 1000000);
  int get remainingSeconds => (remainingMicros + 999999) ~/ 1000000;
  double get progress => 1 - remainingMicros / (_totalSeconds * 1000000);
  bool get controlsLocked =>
      _settings.strictMode && _status == RunStatus.running;

  TimerSnapshot snapshot() => TimerSnapshot(
    phase: _phase,
    status: _status,
    totalSeconds: _totalSeconds,
    remainingMicros: remainingMicros,
    completedRounds: _completedRounds,
    deadline: _deadline,
    startedAt: _startedAt,
    runId: _runId,
    taskId: _taskId,
    taskTitle: _taskTitle,
    bootCount: _status == RunStatus.running ? _now.bootCount : null,
    elapsedDeadlineMicros: _status == RunStatus.running
        ? (_anchor + _remaining).inMicroseconds
        : null,
    segment: _segment,
  );

  TimerTransition reconcile(ClockReading now) =>
      apply(TimerAction.reconcile, now);

  /// Explicit user data deletion is separate from strict phase controls.
  void deleteLocalData(ClockReading now) {
    _now = now;
    _settings = const TimerSettings();
    _completedRounds = 0;
    _segment = 0;
    _recoveryAdjusted = false;
    _prepare(FocusPhase.focus);
    _revision++;
  }

  TimerTransition apply(
    TimerAction action,
    ClockReading now, {
    int? expectedRevision,
    String? expectedRunId,
    FocusTask? task,
    FocusPhase? selectedPhase,
    TimerSettings? nextSettings,
  }) {
    if (now.elapsed < _now.elapsed) throw const TimerClockException();
    if (action == TimerAction.selectPhase && selectedPhase == null ||
        action == TimerAction.updateSettings && nextSettings == null) {
      throw ArgumentError('This timer command needs its value.');
    }
    final beforeRevision = _revision;
    final beforeRunId = _runId;
    final recovered = _recoveryAdjusted;
    _recoveryAdjusted = false;
    if (recovered) _revision++;
    _now = now;
    final expired =
        _status == RunStatus.running && _rawRemaining <= Duration.zero;
    FocusSession? completion;
    if (expired) {
      if (_phase == FocusPhase.focus) {
        completion = FocusSession(
          id: _runId!,
          startedAt: _startedAt!,
          endedAt: _deadline!,
          focusSeconds: _totalSeconds,
          taskId: _taskId,
          taskTitle: _taskTitle,
        );
        _completedRounds = (_completedRounds + 1).clamp(0, 8);
      }
      _advance();
      _revision++;
    }
    TimerTransition result(
      TimerCommandOutcome outcome, [
      bool changed = false,
    ]) => TimerTransition(
      changed: expired || recovered || changed,
      completedPhase: expired,
      completion: completion,
      previousRunId: beforeRunId,
      outcome: outcome,
    );
    if (expectedRevision != null && expectedRevision != beforeRevision ||
        expectedRunId != null && expectedRunId != beforeRunId) {
      return result(TimerCommandOutcome.stale);
    }
    if (action == TimerAction.reconcile) {
      return result(
        expired || recovered
            ? TimerCommandOutcome.applied
            : TimerCommandOutcome.unchanged,
      );
    }
    if (expired && action != TimerAction.updateSettings) {
      return result(TimerCommandOutcome.completionConsumed);
    }
    if (action == TimerAction.updateSettings) {
      var next = TimerSettings.fromJson(nextSettings!.toJson());
      if (controlsLocked) {
        next = _settings.copyWith(appearance: next.appearance);
      }
      if (_sameSettings(_settings, next)) {
        return result(
          controlsLocked
              ? TimerCommandOutcome.blocked
              : TimerCommandOutcome.unchanged,
        );
      }
      _settings = next;
      if (_status == RunStatus.ready) _prepare(_phase);
    } else {
      if (controlsLocked) return result(TimerCommandOutcome.blocked);
      switch (action) {
        case TimerAction.start:
          if (_status != RunStatus.ready) {
            return result(TimerCommandOutcome.unchanged);
          }
          _startedAt = now.utcNow;
          _runId = newLocalId();
          _taskId = task?.id;
          _taskTitle = task?.title;
          _run(now);
        case TimerAction.resume:
          if (_status != RunStatus.paused) {
            return result(TimerCommandOutcome.unchanged);
          }
          _run(now);
        case TimerAction.pause:
          if (_status != RunStatus.running) {
            return result(TimerCommandOutcome.unchanged);
          }
          _remaining = _rawRemaining;
          _status = RunStatus.paused;
          _deadline = null;
        case TimerAction.reset:
          if (_status == RunStatus.ready &&
              _totalSeconds == _settings.secondsFor(_phase)) {
            return result(TimerCommandOutcome.unchanged);
          }
          _prepare(_phase);
        case TimerAction.skip:
          _advance();
        case TimerAction.selectPhase:
          if (_status == RunStatus.ready &&
              selectedPhase == _phase &&
              _totalSeconds == _settings.secondsFor(_phase)) {
            return result(TimerCommandOutcome.unchanged);
          }
          _prepare(selectedPhase!);
        case TimerAction.reconcile:
        case TimerAction.updateSettings:
          throw StateError('Command already handled.');
      }
    }
    _revision++;
    return result(TimerCommandOutcome.applied, true);
  }

  void _run(ClockReading now) {
    _segment++;
    _anchor = now.elapsed;
    _deadline = now.utcNow.add(_remaining);
    _status = RunStatus.running;
  }

  void _advance() {
    if (_phase == FocusPhase.focus) {
      _prepare(
        _completedRounds >= _settings.rounds
            ? FocusPhase.longBreak
            : FocusPhase.shortBreak,
      );
    } else {
      if (_phase == FocusPhase.longBreak) _completedRounds = 0;
      _prepare(FocusPhase.focus);
    }
  }

  void _prepare(FocusPhase next) {
    _phase = next;
    _status = RunStatus.ready;
    _totalSeconds = _settings.secondsFor(next);
    _remaining = Duration(seconds: _totalSeconds);
    _deadline = null;
    _startedAt = null;
    _runId = null;
    _taskId = null;
    _taskTitle = null;
  }

  static bool _sameSettings(TimerSettings a, TimerSettings b) =>
      a.focusMinutes == b.focusMinutes &&
      a.shortBreakMinutes == b.shortBreakMinutes &&
      a.longBreakMinutes == b.longBreakMinutes &&
      a.rounds == b.rounds &&
      a.strictMode == b.strictMode &&
      a.appearance == b.appearance;
}
