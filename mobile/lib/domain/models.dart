import 'dart:math';
import 'alert_state.dart';

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
    this.bootCount,
    this.elapsedDeadlineMicros,
    this.segment = 0,
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
  final int? bootCount;
  final int? elapsedDeadlineMicros;
  final int segment;

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
    'bootCount': bootCount,
    'elapsedDeadlineMicros': elapsedDeadlineMicros,
    'segment': segment,
  };

  void validate() {
    if (totalSeconds < 1 ||
        totalSeconds > 7200 ||
        remainingMicros < 0 ||
        remainingMicros > totalSeconds * 1000000 ||
        completedRounds < 0 ||
        completedRounds > 8 ||
        segment < 0 ||
        (bootCount != null && bootCount! < 0) ||
        (elapsedDeadlineMicros != null && elapsedDeadlineMicros! < 0) ||
        (status != RunStatus.running &&
            (bootCount != null || elapsedDeadlineMicros != null))) {
      throw const FormatException('Saved timer values are out of range.');
    }
    if ((taskId == null) != (taskTitle == null) ||
        (taskId != null &&
            (taskId!.trim().isEmpty ||
                taskTitle!.trim().isEmpty ||
                taskTitle!.length > 160))) {
      throw const FormatException('The saved task snapshot is incomplete.');
    }
    if (status == RunStatus.ready) {
      if (remainingMicros != totalSeconds * 1000000 ||
          deadline != null ||
          startedAt != null ||
          runId != null ||
          taskId != null) {
        throw const FormatException('The saved ready timer is inconsistent.');
      }
    } else if (startedAt == null ||
        runId == null ||
        runId!.trim().isEmpty ||
        (status == RunStatus.running && deadline == null) ||
        (status == RunStatus.paused &&
            (deadline != null || remainingMicros == 0))) {
      throw const FormatException('The saved active timer is incomplete.');
    }
  }

  factory TimerSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime? timestamp(String key) {
      final value = json[key];
      if (value == null) return null;
      if (value is! String) throw const FormatException('Invalid timestamp.');
      final parts = RegExp(
        r'^([+-]?\d{4,6})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
      ).firstMatch(value);
      if (parts == null) throw const FormatException('Invalid timestamp.');
      final year = int.parse(parts[1]!);
      final month = int.parse(parts[2]!);
      final day = int.parse(parts[3]!);
      final calendar = DateTime.utc(year, month, day);
      final offset = parts[7]!;
      if (calendar.year != year ||
          calendar.month != month ||
          calendar.day != day ||
          int.parse(parts[4]!) > 23 ||
          int.parse(parts[5]!) > 59 ||
          int.parse(parts[6]!) > 59 ||
          (offset != 'Z' &&
              (int.parse(offset.substring(1, 3)) > 23 ||
                  int.parse(offset.substring(4, 6)) > 59))) {
        throw const FormatException('Timestamp components are out of range.');
      }
      final date = DateTime.parse(value);
      if (!date.isUtc) throw const FormatException('UTC offset is required.');
      return date.toUtc();
    }

    try {
      final snapshot = TimerSnapshot(
        phase: FocusPhase.values.byName(json['phase'] as String),
        status: RunStatus.values.byName(json['status'] as String),
        totalSeconds: json['totalSeconds'] as int,
        remainingMicros: json['remainingMicros'] as int,
        completedRounds: json['completedRounds'] as int,
        deadline: timestamp('deadline'),
        startedAt: timestamp('startedAt'),
        runId: json['runId'] as String?,
        taskId: json['taskId'] as String?,
        taskTitle: json['taskTitle'] as String?,
        bootCount: json['bootCount'] as int?,
        elapsedDeadlineMicros: json['elapsedDeadlineMicros'] as int?,
        segment: (json['segment'] ?? 0) as int,
      );
      snapshot.validate();
      return snapshot;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('The saved timer has invalid fields.');
    }
  }
}

class SavedState {
  SavedState({
    this.settings = const TimerSettings(),
    this.timer,
    List<FocusTask> tasks = const [],
    List<FocusSession> sessions = const [],
    this.selectedTaskId,
    this.alerts = const AlertState(),
  }) : tasks = List.unmodifiable(tasks),
       sessions = List.unmodifiable(sessions);

  final TimerSettings settings;
  final TimerSnapshot? timer;
  final List<FocusTask> tasks;
  final List<FocusSession> sessions;
  final String? selectedTaskId;
  final AlertState alerts;
}

String newLocalId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
