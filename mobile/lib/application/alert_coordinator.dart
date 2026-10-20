import '../domain/alert_state.dart';
import '../domain/models.dart';
import '../domain/timer_engine.dart';
import 'local_alerts.dart';
import 'local_repository.dart';

/// Called only inside the controller's command queue. SQLite is the outbox;
/// successful OS calls are acknowledged separately and are safe to repeat.
class AlertCoordinator {
  AlertCoordinator(this.port, this.repository, this.state);
  final LocalAlerts port;
  final LocalRepository repository;
  AlertState state;
  AlertAvailability availability = AlertAvailability.unavailable;
  bool initialized = false;
  int openRevision = 0;

  Future<void> initialize(void Function() onEvent) async {
    if (initialized) return;
    await port.initialize(
      databasePath: await repository.notificationDatabasePath(),
      onEvent: onEvent,
    );
    initialized = true;
  }

  bool update(TimerSnapshot snapshot, ClockReading now) {
    final old = state.current;
    final running = snapshot.status == RunStatus.running && state.enabled;
    final elapsedDeadline = snapshot.elapsedDeadlineMicros;
    if (running &&
        old?.runId == snapshot.runId &&
        old?.segment == snapshot.segment &&
        old?.bootCount == now.bootCount &&
        old?.elapsedDeadlineMicros == elapsedDeadline) {
      return false;
    }
    if (!running && old == null) return false;
    final last = old ?? state.previous;
    final reuse = last?.runId == snapshot.runId;
    final id = reuse ? last!.notificationId : state.nextNotificationId;
    final serial = state.serial + 1;
    state = AlertState(
      enabled: state.enabled,
      permissionRequested: state.permissionRequested,
      serial: serial,
      nextNotificationId: running && !reuse
          ? (id == 0x7fffffff ? 1 : id + 1)
          : state.nextNotificationId,
      current: running
          ? AlertRequest(
              runId: snapshot.runId!,
              generation: serial,
              notificationId: id,
              phase: snapshot.phase,
              segment: snapshot.segment,
              deadlineUtcMicros:
                  now.utcNow.microsecondsSinceEpoch + snapshot.remainingMicros,
              elapsedDeadlineMicros: elapsedDeadline!,
              maximumRemainingMicros: snapshot.remainingMicros,
              bootCount: now.bootCount,
            )
          : null,
      previous: last,
      retiredIds: List.unmodifiable({
        ...state.retiredIds,
        if (old != null) old.notificationId,
      }),
    );
    return true;
  }

  void setEnabled(bool enabled) {
    state = AlertState(
      enabled: enabled,
      permissionRequested: true,
      serial: state.serial,
      nextNotificationId: state.nextNotificationId,
      current: state.current,
      previous: state.previous,
      retiredIds: state.retiredIds,
    );
  }

  Future<void> synchronize({required bool durable}) async {
    if (!durable) {
      // Cancellation is still useful when an in-memory pause/reset could not
      // save. Never register a newly started, uncommitted phase.
      await port.synchronize(
        AlertState(
          retiredIds: [
            ...state.retiredIds,
            if (state.current != null) state.current!.notificationId,
          ],
        ),
      );
      availability = AlertAvailability.failed;
      return;
    }
    availability = await port.synchronize(state);
    if (availability == AlertAvailability.failed ||
        availability == AlertAvailability.unavailable) {
      return;
    }
    await repository.recordAlertReceipt('sync:${state.serial}');
    for (final response in await port.responses()) {
      final valid =
          const ['open', 'dismiss'].contains(response.action) &&
          (response.matches(state.current) || response.matches(state.previous));
      if (valid && await repository.recordAlertReceipt(response.key)) {
        if (response.action == 'open') openRevision++;
      }
      // A crash before this acknowledgement repeats the receipt insertion,
      // whose unique key prevents a second navigation/action.
      await port.acknowledgeResponse(response);
    }
    state = AlertState(
      enabled: state.enabled,
      permissionRequested: state.permissionRequested,
      serial: state.serial,
      nextNotificationId: state.nextNotificationId,
      current: state.current,
      previous: state.previous,
    );
  }
}
