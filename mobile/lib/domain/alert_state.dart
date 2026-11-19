import 'models.dart';

/// Durable desired OS state. Contains no task names or other lock-screen data.
class AlertRequest {
  const AlertRequest({
    required this.runId,
    required this.generation,
    required this.notificationId,
    required this.phase,
    required this.segment,
    required this.deadlineUtcMicros,
    required this.elapsedDeadlineMicros,
    required this.maximumRemainingMicros,
    this.bootCount,
    this.bellEnabled = true,
  });

  final String runId;
  final int generation;
  final int notificationId;
  final FocusPhase phase;
  final int segment;
  final int deadlineUtcMicros;
  final int elapsedDeadlineMicros;
  final int maximumRemainingMicros;
  final int? bootCount;
  final bool bellEnabled;

  AlertRequest copyWith({required bool bellEnabled}) =>
      bellEnabled == this.bellEnabled
      ? this
      : AlertRequest(
          runId: runId,
          generation: generation,
          notificationId: notificationId,
          phase: phase,
          segment: segment,
          deadlineUtcMicros: deadlineUtcMicros,
          elapsedDeadlineMicros: elapsedDeadlineMicros,
          maximumRemainingMicros: maximumRemainingMicros,
          bootCount: bootCount,
          bellEnabled: bellEnabled,
        );

  Map<String, Object?> toJson() => {
    'runId': runId,
    'generation': generation,
    'notificationId': notificationId,
    'phase': phase.name,
    'segment': segment,
    'deadlineUtcMicros': deadlineUtcMicros,
    'elapsedDeadlineMicros': elapsedDeadlineMicros,
    'maximumRemainingMicros': maximumRemainingMicros,
    'bootCount': bootCount,
    'bellEnabled': bellEnabled,
  };

  factory AlertRequest.fromJson(Map<String, dynamic> json) {
    try {
      final value = AlertRequest(
        runId: json['runId'] as String,
        generation: json['generation'] as int,
        notificationId: json['notificationId'] as int,
        phase: FocusPhase.values.byName(json['phase'] as String),
        segment: json['segment'] as int,
        deadlineUtcMicros: json['deadlineUtcMicros'] as int,
        elapsedDeadlineMicros: json['elapsedDeadlineMicros'] as int,
        maximumRemainingMicros: json['maximumRemainingMicros'] as int,
        bootCount: json['bootCount'] as int?,
        bellEnabled: json['bellEnabled'] as bool? ?? true,
      );
      if (value.runId.trim().isEmpty ||
          value.generation < 1 ||
          value.notificationId < 1 ||
          value.notificationId > 0x7fffffff ||
          value.segment < 0 ||
          value.elapsedDeadlineMicros < 0 ||
          value.maximumRemainingMicros < 1 ||
          value.maximumRemainingMicros > 7200000000 ||
          (value.bootCount != null && value.bootCount! < 0)) {
        throw const FormatException('Invalid saved alert.');
      }
      return value;
    } catch (_) {
      throw const FormatException('Invalid saved alert.');
    }
  }
}

class AlertState {
  const AlertState({
    this.enabled = true,
    this.bellEnabled = true,
    this.permissionRequested = false,
    this.serial = 0,
    this.nextNotificationId = 1,
    this.current,
    this.previous,
    this.pendingCompletion,
    this.retiredIds = const [],
  });
  final bool enabled;
  final bool bellEnabled;
  final bool permissionRequested;
  final int serial;
  final int nextNotificationId;
  final AlertRequest? current;
  final AlertRequest? previous;

  /// Only retains an already-scheduled request after a live natural expiry.
  /// It is never a source of new alarms or overdue notification replays.
  final AlertRequest? pendingCompletion;
  final List<int> retiredIds;

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'bellEnabled': bellEnabled,
    'permissionRequested': permissionRequested,
    'serial': serial,
    'nextNotificationId': nextNotificationId,
    'current': current?.toJson(),
    'previous': previous?.toJson(),
    'pendingCompletion': pendingCompletion?.toJson(),
    'retiredIds': retiredIds,
  };

  factory AlertState.fromJson(Map<String, dynamic> json) {
    try {
      AlertRequest? request(String key) => json[key] == null
          ? null
          : AlertRequest.fromJson(json[key] as Map<String, dynamic>);
      final state = AlertState(
        enabled: json['enabled'] as bool,
        bellEnabled: json['bellEnabled'] as bool? ?? true,
        permissionRequested: json['permissionRequested'] as bool,
        serial: json['serial'] as int,
        nextNotificationId: json['nextNotificationId'] as int,
        current: request('current'),
        previous: request('previous'),
        pendingCompletion: request('pendingCompletion'),
        retiredIds: List<int>.unmodifiable(
          (json['retiredIds'] as List).cast<int>(),
        ),
      );
      if (state.serial < 0 ||
          state.nextNotificationId < 1 ||
          state.nextNotificationId > 0x7fffffff ||
          state.retiredIds.any((id) => id < 1 || id > 0x7fffffff) ||
          (state.current != null &&
              (!state.enabled || state.current!.generation > state.serial)) ||
          (state.pendingCompletion != null &&
              (!state.enabled ||
                  state.pendingCompletion!.generation > state.serial))) {
        throw const FormatException('Invalid saved alert state.');
      }
      return state;
    } catch (_) {
      throw const FormatException('Invalid saved alert state.');
    }
  }
}
