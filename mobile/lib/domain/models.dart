import 'dart:math';

enum FocusPhase {
  focus('Focus'),
  shortBreak('Short break'),
  longBreak('Long break');

  const FocusPhase(this.label);
  final String label;
}

enum RunStatus { ready, running, paused }

class TimerSettings {
  const TimerSettings({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.rounds = 4,
    this.strictMode = false,
    this.appearance = 'system',
  });

  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int rounds;
  final bool strictMode;
  final String appearance;

  int secondsFor(FocusPhase phase) =>
      60 *
      switch (phase) {
        FocusPhase.focus => focusMinutes,
        FocusPhase.shortBreak => shortBreakMinutes,
        FocusPhase.longBreak => longBreakMinutes,
      };

  TimerSettings copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? rounds,
    bool? strictMode,
    String? appearance,
  }) => TimerSettings(
    focusMinutes: focusMinutes ?? this.focusMinutes,
    shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
    longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
    rounds: rounds ?? this.rounds,
    strictMode: strictMode ?? this.strictMode,
    appearance: appearance ?? this.appearance,
  );

  Map<String, Object?> toJson() => {
    'focusMinutes': focusMinutes,
    'shortBreakMinutes': shortBreakMinutes,
    'longBreakMinutes': longBreakMinutes,
    'rounds': rounds,
    'strictMode': strictMode,
    'appearance': appearance,
  };

  factory TimerSettings.fromJson(Map<String, dynamic> json) {
    int bounded(String key, int fallback, int max) =>
        (json[key] as int? ?? fallback).clamp(1, max);
    return TimerSettings(
      focusMinutes: bounded('focusMinutes', 25, 120),
      shortBreakMinutes: bounded('shortBreakMinutes', 5, 60),
      longBreakMinutes: bounded('longBreakMinutes', 15, 120),
      rounds: bounded('rounds', 4, 8),
      strictMode: json['strictMode'] as bool? ?? false,
      appearance: ['system', 'light', 'dark'].contains(json['appearance'])
          ? json['appearance'] as String
          : 'system',
    );
  }
}

class FocusTask {
  const FocusTask({required this.id, required this.title, this.done = false});
  final String id;
  final String title;
  final bool done;

  FocusTask copyWith({String? title, bool? done}) =>
      FocusTask(id: id, title: title ?? this.title, done: done ?? this.done);

  Map<String, Object?> toRow(int position) => {
    'id': id,
    'title': title,
    'done': done ? 1 : 0,
    'position': position,
  };

  factory FocusTask.fromRow(Map<String, Object?> row) => FocusTask(
    id: row['id'] as String,
    title: row['title'] as String,
    done: row['done'] == 1,
  );
}

class FocusSession {
  const FocusSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.focusSeconds,
    this.taskId,
    this.taskTitle,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int focusSeconds;
  final String? taskId;
  final String? taskTitle;

  Map<String, Object?> toRow() => {
    'id': id,
    'started_at': startedAt.toUtc().toIso8601String(),
    'ended_at': endedAt.toUtc().toIso8601String(),
    'focus_seconds': focusSeconds,
    'task_id': taskId,
    'task_title': taskTitle,
  };

  factory FocusSession.fromRow(Map<String, Object?> row) => FocusSession(
    id: row['id'] as String,
    startedAt: DateTime.parse(row['started_at'] as String),
    endedAt: DateTime.parse(row['ended_at'] as String),
    focusSeconds: row['focus_seconds'] as int,
    taskId: row['task_id'] as String?,
    taskTitle: row['task_title'] as String?,
  );
}

class TimerSnapshot {
  const TimerSnapshot({
    required this.phase,
    required this.status,
    required this.totalSeconds,
    required this.remainingMicros,
    required this.completedRounds,
    this.deadline,
    this.startedAt,
    this.runId,
    this.taskId,
    this.taskTitle,
  });

  final FocusPhase phase;
  final RunStatus status;
  final int totalSeconds;
  final int remainingMicros;
  final int completedRounds;
  final DateTime? deadline;
  final DateTime? startedAt;
  final String? runId;
  final String? taskId;
  final String? taskTitle;

  Map<String, Object?> toJson() => {
    'phase': phase.name,
    'status': status.name,
    'totalSeconds': totalSeconds,
    'remainingMicros': remainingMicros,
    'completedRounds': completedRounds,
    'deadline': deadline?.toUtc().toIso8601String(),
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'runId': runId,
    'taskId': taskId,
    'taskTitle': taskTitle,
  };

  factory TimerSnapshot.fromJson(Map<String, dynamic> json) => TimerSnapshot(
    phase: FocusPhase.values.byName(json['phase'] as String),
    status: RunStatus.values.byName(json['status'] as String),
    totalSeconds: (json['totalSeconds'] as int).clamp(1, 7200),
    remainingMicros: (json['remainingMicros'] as int).clamp(0, 7200000000),
    completedRounds: (json['completedRounds'] as int).clamp(0, 8),
    deadline: DateTime.tryParse(json['deadline'] as String? ?? ''),
    startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
    runId: json['runId'] as String?,
    taskId: json['taskId'] as String?,
    taskTitle: json['taskTitle'] as String?,
  );
}

class SavedState {
  SavedState({
    this.settings = const TimerSettings(),
    this.timer,
    List<FocusTask> tasks = const [],
    List<FocusSession> sessions = const [],
    this.selectedTaskId,
  }) : tasks = List.unmodifiable(tasks),
       sessions = List.unmodifiable(sessions);

  final TimerSettings settings;
  final TimerSnapshot? timer;
  final List<FocusTask> tasks;
  final List<FocusSession> sessions;
  final String? selectedTaskId;
}

String newLocalId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
