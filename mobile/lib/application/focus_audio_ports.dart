import '../domain/models.dart';
import '../domain/timer_engine.dart';
import '../domain/focus_sound_preferences.dart';

class FocusAudioSessionEvent {
  const FocusAudioSessionEvent({
    required this.snapshot,
    required this.action,
    required this.transition,
    this.reading,
    this.restoration = false,
  });
  final TimerSnapshot snapshot;
  final TimerAction action;
  final TimerTransition transition;
  final ClockReading? reading;
  final bool restoration;
}

class FocusAudioLease {
  const FocusAudioLease({
    required this.deadlineMicros,
    required this.intentEpoch,
    this.runId,
    this.segment,
    this.preview = false,
  });
  final String? runId;
  final int? segment;
  final int deadlineMicros;
  final int intentEpoch;
  final bool preview;
}

class FocusAudioPreparation {
  const FocusAudioPreparation({
    required this.generation,
    required this.intentEpoch,
    required this.preview,
    this.runId,
    this.segment,
    this.focusDeadlineMicros,
  });
  final int generation, intentEpoch;
  final bool preview;
  final String? runId;
  final int? segment, focusDeadlineMicros;
}

enum FocusAudioMediaAction { play, pause, stop }

class FocusAudioMediaCommand {
  const FocusAudioMediaCommand(
    this.action,
    this.generation,
    this.runId,
    this.segment,
  );
  final FocusAudioMediaAction action;
  final int generation;
  final String? runId;
  final int? segment;
}

/// Mobile OS controls attach to the existing application owner, never a timer.
abstract interface class BackgroundFocusAudioPlayback {
  set onMediaCommand(void Function(FocusAudioMediaCommand)? callback);
  void sessionChanged(FocusAudioSessionEvent event);
}

enum FocusAudioTransport { stopped, loading, playing, error }

enum FocusAudioAvailability { available, unavailable }

enum FocusAudioEventKind {
  expired,
  interrupted,
  interruptionEnded,
  routeLost,
  suspended,
  resumed,
  error,
}

class FocusAudioPlaybackEvent {
  const FocusAudioPlaybackEvent(
    this.kind,
    this.generation, {
    this.mayResume = false,
  });
  final FocusAudioEventKind kind;
  final int generation;
  final bool mayResume;
}

abstract interface class PreparedFocusAudio {}

/// Safe cancellation at the native deadline, rather than a playback failure.
class FocusAudioLeaseExpired implements Exception {
  const FocusAudioLeaseExpired();
}

/// revoke must silence immediately, including while prepare/start is pending.
abstract interface class FocusAudioPlaybackPort {
  FocusAudioAvailability get availability;
  set onEvent(void Function(FocusAudioPlaybackEvent)? callback);
  Future<PreparedFocusAudio> prepare(
    FocusSoundId sound, {
    FocusAudioPreparation? request,
  });
  Future<void> start(
    PreparedFocusAudio source,
    FocusAudioLease lease,
    int generation,
    double volume,
  );
  void setVolume(double volume);
  void revoke(int generation, {bool fade = false});
  Future<void> release(PreparedFocusAudio source);
  Future<void> close();
}

abstract interface class FocusAudioCancellation {
  void cancel();
}

abstract interface class FocusAudioScheduler {
  FocusAudioCancellation after(Duration delay, void Function() callback);
}

class FocusAudioState {
  const FocusAudioState({
    required this.preferences,
    required this.transport,
    required this.availability,
    this.previewSound,
    this.interrupted = false,
    this.routeBlocked = false,
    this.suspended = false,
    this.message,
  });
  final FocusSoundPreferences preferences;
  final FocusAudioTransport transport;
  final FocusAudioAvailability availability;
  final FocusSoundId? previewSound;
  final bool interrupted, routeBlocked, suspended;
  final String? message;
  bool get canRetry =>
      availability == FocusAudioAvailability.available &&
      transport == FocusAudioTransport.error;
}
