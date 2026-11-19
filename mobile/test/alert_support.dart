import 'package:poma/application/local_alerts.dart';
import 'package:poma/domain/alert_state.dart';

class FakeAlerts implements LocalAlerts {
  final Map<int, AlertRequest> pending = {};
  final List<AlertResponse> queue = [];
  AlertAvailability mode = AlertAvailability.ready;
  bool failBefore = false;
  bool failAfter = false;
  bool failActionAck = false;
  int permissionRequests = 0;
  int settingsOpens = 0;
  int exactRequests = 0;
  int syncs = 0;
  int previews = 0;
  @override
  Future<AlertAvailability> previewCompletionBell() async {
    previews++;
    return mode;
  }

  void Function()? onEvent;
  @override
  Future<void> initialize({
    required String? databasePath,
    required void Function() onEvent,
  }) async {
    this.onEvent = onEvent;
  }

  @override
  Future<AlertAvailability> synchronize(AlertState state) async {
    syncs++;
    if (failBefore) throw StateError('OS unavailable before update');
    final completed = state.pendingCompletion;
    final retained = completed == null
        ? null
        : pending[completed.notificationId];
    pending.clear();
    if (state.enabled &&
        mode != AlertAvailability.denied &&
        retained?.runId == completed?.runId &&
        retained?.generation == completed?.generation &&
        retained != null) {
      pending[retained.notificationId] = retained;
    }
    if (state.enabled &&
        state.current != null &&
        mode != AlertAvailability.denied) {
      pending[state.current!.notificationId] = state.current!;
    }
    if (failAfter) throw StateError('Process interrupted after OS update');
    return state.enabled ? mode : AlertAvailability.disabled;
  }

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  @override
  Future<void> openSettings() async {
    settingsOpens++;
  }

  @override
  Future<void> requestExactAccess() async {
    exactRequests++;
  }

  @override
  Future<List<AlertResponse>> responses() async => queue.toList();
  @override
  Future<void> acknowledgeResponse(AlertResponse response) async {
    if (failActionAck) throw StateError('Crash after receipt');
    queue.removeWhere((item) => item.key == response.key);
  }

  @override
  Future<void> clearForReset() async {
    if (failBefore) throw StateError('OS unavailable');
    pending.clear();
    queue.clear();
    if (failAfter) throw StateError('Interrupted cleanup');
  }

  @override
  void dispose() {}
}
