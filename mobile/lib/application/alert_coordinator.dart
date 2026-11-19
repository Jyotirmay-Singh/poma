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

  bool update(
    TimerSnapshot snapshot,
    ClockReading now, {
    TimerTransition? transition,
    TimerAction? action,
    bool restoration = false,
  }) {
    final old = state.current;
    final naturalCompletion =
        !restoration &&
        transition?.completedPhase == true &&
        transition?.completedEarly == false &&
        old?.runId == transition?.previousRunId;
    // An accepted Reset on an already-ready successor can still cancel a
    // completed OS request, even when it does not change the timer snapshot.
    final cancellation =
        const [
          TimerAction.pause,
          TimerAction.reset,
          TimerAction.skip,
          TimerAction.selectPhase,
        ].contains(action) &&
        transition?.outcome != TimerCommandOutcome.blocked &&
        transition?.outcome != TimerCommandOutcome.stale;
    final pendingCompletion = !state.enabled || restoration
        ? null
        : naturalCompletion
        ? old
        : transition?.dayReset == true || cancellation
        ? null
        : state.pendingCompletion;
    final running = snapshot.status == RunStatus.running && state.enabled;
    final elapsedDeadline = snapshot.elapsedDeadlineMicros;
    if (running &&
        old?.runId == snapshot.runId &&
        old?.segment == snapshot.segment &&
        old?.bellEnabled == state.bellEnabled &&
        old?.bootCount == now.bootCount &&
        old?.elapsedDeadlineMicros == elapsedDeadline &&
        pendingCompletion == state.pendingCompletion) {
      return false;
    }
    if (!running &&
        old == null &&
        pendingCompletion == state.pendingCompletion) {
      return false;
    }
    final last = old ?? state.previous;
    final reuse = last?.runId == snapshot.runId;
    final id = reuse ? last!.notificationId : state.nextNotificationId;
    final serial = state.serial + 1;
    state = AlertState(
      enabled: state.enabled,
      bellEnabled: state.bellEnabled,
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
              bellEnabled: state.bellEnabled,
            )
          : null,
      previous: last,
      pendingCompletion: pendingCompletion,
      retiredIds: List.unmodifiable({
        ...state.retiredIds,
        if (old != null) old.notificationId,
        if (state.pendingCompletion != null &&
            state.pendingCompletion != pendingCompletion)
          state.pendingCompletion!.notificationId,
      }),
    );
    return true;
  }

  void setEnabled(bool enabled) {
    state = AlertState(
      enabled: enabled,
      bellEnabled: state.bellEnabled,
      permissionRequested: true,
      serial: state.serial,
      nextNotificationId: state.nextNotificationId,
      current: state.current,
      previous: state.previous,
      pendingCompletion: state.pendingCompletion,
      retiredIds: state.retiredIds,
    );
  }

  void setBellEnabled(bool enabled) {
    if (enabled == state.bellEnabled) {
      return;
    }
    state = AlertState(
      enabled: state.enabled,
      bellEnabled: enabled,
      permissionRequested: state.permissionRequested,
      serial: state.serial,
      nextNotificationId: state.nextNotificationId,
      current: state.current,
      previous: state.previous,
      retiredIds: [
        ...state.retiredIds,
        if (state.pendingCompletion != null)
          state.pendingCompletion!.notificationId,
      ],
    );
  }

  Future<void> synchronize({required bool durable}) async {
    if (!durable) {
      // Cancellation is still useful when an in-memory pause/reset could not
      // save. Never register a newly started, uncommitted phase.
      await port.synchronize(
        AlertState(
          enabled: false,
          retiredIds: [
            ...state.retiredIds,
            if (state.current != null) state.current!.notificationId,
            if (state.pendingCompletion != null)
              state.pendingCompletion!.notificationId,
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
          (response.matches(state.current) ||
              response.matches(state.previous) ||
              response.matches(state.pendingCompletion));
      if (valid && await repository.recordAlertReceipt(response.key)) {
        if (response.action == 'open') openRevision++;
      }
      // A crash before this acknowledgement repeats the receipt insertion,
      // whose unique key prevents a second navigation/action.
      await port.acknowledgeResponse(response);
    }
    state = AlertState(
      enabled: state.enabled,
      bellEnabled: state.bellEnabled,
      permissionRequested: state.permissionRequested,
      serial: state.serial,
      nextNotificationId: state.nextNotificationId,
      current: state.current,
      previous: state.previous,
      pendingCompletion: state.pendingCompletion,
    );
  }
}
