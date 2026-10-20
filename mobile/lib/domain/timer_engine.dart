import 'models.dart';

abstract interface class TimerClock {
  DateTime get utcNow;
  Duration get elapsed;
}

class SystemTimerClock implements TimerClock {
  final Stopwatch _stopwatch = Stopwatch()..start();
  @override
  DateTime get utcNow => DateTime.now().toUtc();
  @override
  Duration get elapsed => _stopwatch.elapsed;
}

/// A countdown anchored to elapsed time, never to the number of UI callbacks.
/// UTC deadlines are used only when restoring a previous process.
class TimerEngine {
  TimerEngine({
    required this.settings,
    TimerClock? clock,
    TimerSnapshot? restored,
  }) : clock = clock ?? SystemTimerClock() {
    if (restored == null) {
      _prepare(FocusPhase.focus);
    } else {
      phase = restored.phase;
      status = restored.status;
      totalSeconds = restored.totalSeconds;
      completedRounds = restored.completedRounds;
      _remaining = Duration(microseconds: restored.remainingMicros);
      _startedAt = restored.startedAt;
      _runId = restored.runId;
      _taskId = restored.taskId;
      _taskTitle = restored.taskTitle;
      if (status == RunStatus.running) {
        if (restored.deadline == null || _startedAt == null || _runId == null) {
          throw const FormatException('The saved running timer is incomplete.');
        }
        _remaining = restored.deadline!.difference(this.clock.utcNow);
        if (_remaining > Duration(seconds: totalSeconds)) {
          _remaining = Duration(seconds: totalSeconds);
        }
        _anchor = this.clock.elapsed;
      }
    }
  }

  final TimerClock clock;
  TimerSettings settings;
  late FocusPhase phase;
  late RunStatus status;
  late int totalSeconds;
  int completedRounds = 0;
  late Duration _remaining;
  Duration _anchor = Duration.zero;
  DateTime? _startedAt;
  String? _runId;
  String? _taskId;
  String? _taskTitle;

  Duration get _rawRemaining => status == RunStatus.running
      ? _remaining - (clock.elapsed - _anchor)
      : _remaining;
  int get remainingSeconds =>
      (_rawRemaining.inMicroseconds / Duration.microsecondsPerSecond)
          .ceil()
          .clamp(0, totalSeconds);
  double get progress => (1 - remainingSeconds / totalSeconds).clamp(0.0, 1.0);
  bool get controlsLocked => settings.strictMode && status == RunStatus.running;

  TimerSnapshot snapshot() => TimerSnapshot(
    phase: phase,
    status: status,
    totalSeconds: totalSeconds,
    remainingMicros: _rawRemaining.inMicroseconds.clamp(0, 7200000000),
    completedRounds: completedRounds,
    deadline: status == RunStatus.running
        ? clock.utcNow.add(_rawRemaining)
        : null,
    startedAt: _startedAt,
    runId: _runId,
    taskId: _taskId,
    taskTitle: _taskTitle,
  );

  void start({FocusTask? task}) {
    if (status == RunStatus.running) return;
    if (status == RunStatus.ready) {
      _startedAt = clock.utcNow;
      _runId = newLocalId();
      _taskId = task?.id;
      _taskTitle = task?.title;
    }
    _anchor = clock.elapsed;
    status = RunStatus.running;
  }

  void pause() {
    if (status != RunStatus.running || controlsLocked) return;
    _remaining = _rawRemaining;
    status = RunStatus.paused;
  }

  void reset() {
    if (!controlsLocked) _prepare(phase);
  }

  void selectPhase(FocusPhase next) {
    if (!controlsLocked) _prepare(next);
  }

  void skip() {
    if (controlsLocked) return;
    _advance();
  }

  void updateSettings(TimerSettings next) {
    settings = next;
    // A running or paused session keeps the duration it started with.
    if (status == RunStatus.ready) _prepare(phase);
  }

  FocusSession? tick() {
    if (status != RunStatus.running || _rawRemaining > Duration.zero) {
      return null;
    }
    final endedAt = clock.utcNow.add(_rawRemaining);
    FocusSession? completed;
    if (phase == FocusPhase.focus) {
      completed = FocusSession(
        id: _runId!,
        startedAt: _startedAt!,
        endedAt: endedAt,
        focusSeconds: totalSeconds,
        taskId: _taskId,
        taskTitle: _taskTitle,
      );
      completedRounds = (completedRounds + 1).clamp(0, settings.rounds);
    }
    _advance();
    return completed;
  }

  void _advance() {
    if (phase == FocusPhase.focus) {
      _prepare(
        completedRounds >= settings.rounds
            ? FocusPhase.longBreak
            : FocusPhase.shortBreak,
      );
    } else {
      if (phase == FocusPhase.longBreak) completedRounds = 0;
      _prepare(FocusPhase.focus);
    }
  }

  void _prepare(FocusPhase next) {
    phase = next;
    status = RunStatus.ready;
    totalSeconds = settings.secondsFor(next);
    _remaining = Duration(seconds: totalSeconds);
    _startedAt = null;
    _runId = null;
    _taskId = null;
    _taskTitle = null;
  }
}
