import '../domain/alert_state.dart';

enum AlertAvailability { ready, delayed, denied, disabled, unavailable, failed }

class AlertResponse {
  const AlertResponse(this.runId, this.generation, this.action);
  final String runId;
  final int generation;
  final String action;
  String get key => 'action:$runId:$generation:$action';

  bool matches(AlertRequest? request) =>
      request?.runId == runId && request?.generation == generation;
}

/// Implementations must replace by persisted ID and never run a countdown.
abstract interface class LocalAlerts {
  Future<void> initialize({
    required String? databasePath,
    required void Function() onEvent,
  });
  Future<AlertAvailability> synchronize(AlertState state);
  Future<void> requestPermission();
  Future<void> openSettings();
  Future<void> requestExactAccess();
  Future<List<AlertResponse>> responses();
  Future<void> acknowledgeResponse(AlertResponse response);
  Future<void> clearForReset();
  void dispose();
}
