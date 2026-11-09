import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/focus_sound_preferences.dart';
import '../domain/models.dart';
import '../domain/timer_engine.dart';
import 'focus_audio_ports.dart';
import 'local_reset_participant.dart';

class _TimerCancellation implements FocusAudioCancellation {
  _TimerCancellation(this.timer);
  final Timer timer;
  @override
  void cancel() => timer.cancel();
}

class TimerFocusAudioScheduler implements FocusAudioScheduler {
  const TimerFocusAudioScheduler();
  @override
  FocusAudioCancellation after(Duration delay, void Function() callback) =>
      _TimerCancellation(Timer(delay, callback));
}

/// Application lifetime owner. No audio operation joins the timer command lane.
class FocusAudioCoordinator extends ChangeNotifier
    implements LocalResetParticipant {
  FocusAudioCoordinator(
    this.playback, {
    this.scheduler = const TimerFocusAudioScheduler(),
  }) {
    playback.onEvent = _onPlayback;
    if (playback case BackgroundFocusAudioPlayback background) {
      background.onMediaCommand = _onMediaCommand;
    }
  }
  final FocusAudioPlaybackPort playback;
  final FocusAudioScheduler scheduler;
  FocusSoundPreferences _preferences = const FocusSoundPreferences();
  FocusSoundPreferences get preferences => _preferences;
  Future<void> Function(FocusSoundPreferences)? _save;
  Future<void> Function()? _reconcile;
  FocusAudioSessionEvent? _session;
  String? _key, _armedRun;
  int? _armedSegment;
  int _generation = 0, _intentEpoch = 0, _previewSerial = 0;
  int? _previewToken,
      _restoreEpoch,
      _interruptionEpoch,
      _interruptionGeneration;
  FocusSoundId? _previewSound;
  FocusAudioTransport _transport = FocusAudioTransport.stopped;
  String? _message;
  bool _interrupted = false, _routeBlocked = false, _suspended = false;
  bool _closed = false, _quitting = false, _dirtyVolume = false;
  bool _draining = false, _dirty = false;
  PreparedFocusAudio? _source;
  int? _playingGeneration;
  FocusSoundId? _playingSound;
  Future<void>? _closing;
  Future<void> _lane = Future.value();
  FocusAudioCancellation? _previewExpiry, _saveTimer;

  FocusAudioState get state => FocusAudioState(
    availability: playback.availability,
    preferences: _preferences,
    transport: _transport,
    previewSound: _previewSound,
    interrupted: _interrupted,
    routeBlocked: _routeBlocked,
    suspended: _suspended,
    message: _message,
  );

  void bind({
    required FocusSoundPreferences preferences,
    required Future<void> Function(FocusSoundPreferences) save,
    required Future<void> Function() reconcile,
  }) {
    _preferences = preferences;
    _save = save;
    _reconcile = reconcile;
    _notify();
  }

  void _notify() {
    if (!_closed) notifyListeners();
  }

  bool get _running =>
      _session?.reading != null &&
      _session!.snapshot.phase == FocusPhase.focus &&
      _session!.snapshot.status == RunStatus.running &&
      (_session!.snapshot.elapsedDeadlineMicros ?? 0) >
          _session!.reading!.elapsed.inMicroseconds;
  bool get _armed =>
      _running &&
      _armedRun == _session!.snapshot.runId &&
      _armedSegment == _session!.snapshot.segment;
  bool get _audible =>
      playback.availability == FocusAudioAvailability.available &&
      !_closed &&
      !_quitting &&
      !_suspended &&
      !_interrupted &&
      !_routeBlocked &&
      !_preferences.muted &&
      _preferences.volume > 0 &&
      _message == null;

  void onSession(FocusAudioSessionEvent event) {
    if (_closed) return;
    _session = event;
    final s = event.snapshot;
    final key =
        '${s.runId}/${s.segment}/${s.phase}/${s.status}/${s.elapsedDeadlineMicros}/${event.reading != null}';
    final accepted =
        event.transition.outcome == TimerCommandOutcome.applied &&
        !event.restoration &&
        (event.action == TimerAction.start ||
            event.action == TimerAction.resume);
    if (_key == key && !accepted) return;
    _key = key;
    if (playback case BackgroundFocusAudioPlayback background) {
      background.sessionChanged(event);
    }
    if (event.reading == null) {
      _disarm();
    } else if (accepted && _running) {
      _cancelPreview();
      _interrupted = false;
      _suspended = false;
      _arm();
    } else if (event.transition.completedPhase ||
        !_running ||
        _armedRun != s.runId ||
        _armedSegment != s.segment) {
      // Ready/paused Focus previews survive ordinary unchanged reconciliation.
      if (event.transition.changed ||
          s.phase != FocusPhase.focus ||
          event.restoration) {
        _cancelPreview();
      }
      _armedRun = null;
      _armedSegment = null;
      _intentEpoch++;
    }
    _invalidate();
    _request();
  }

  void _onMediaCommand(FocusAudioMediaCommand command) {
    if (_closed ||
        _quitting ||
        command.generation != _generation ||
        command.runId != _session?.snapshot.runId ||
        command.segment != _session?.snapshot.segment) {
      return;
    }
    switch (command.action) {
      case FocusAudioMediaAction.play:
        // playSounds re-samples the real timer; it never starts or resumes Focus.
        unawaited(playSounds());
      case FocusAudioMediaAction.pause:
      case FocusAudioMediaAction.stop:
        pauseSounds();
    }
  }

  void _arm() {
    _armedRun = _session!.snapshot.runId;
    _armedSegment = _session!.snapshot.segment;
    _intentEpoch++;
    _message = null;
  }

  void _disarm() {
    _armedRun = null;
    _armedSegment = null;
    _intentEpoch++;
    _cancelPreview();
  }

  void _cancelPreview() {
    _previewExpiry?.cancel();
    _previewExpiry = null;
    _previewSound = null;
    _previewToken = null;
    _restoreEpoch = null;
  }

  void _invalidate({bool fade = false}) {
    _generation++;
    playback.revoke(_generation, fade: fade);
    _transport = FocusAudioTransport.stopped;
    _notify();
  }

  Future<void> _fresh() async {
    try {
      await _reconcile?.call();
    } catch (_) {
      _disarm();
      _invalidate();
    }
  }

  void selectSound(FocusSoundId sound) {
    if (_closed || _quitting) return;
    _cancelPreview();
    _message = null;
    _preferences = _preferences.copyWith(sound: sound);
    _intentEpoch++;
    _invalidate(fade: sound != FocusSoundId.off);
    if (sound == FocusSoundId.off) _disarm();
    _commit();
    final generation = _generation;
    unawaited(() async {
      await _fresh();
      if (_closed || generation != _generation) return;
      if (_running && sound != FocusSoundId.off) _arm();
      _request();
    }());
  }

  Future<void> playSounds() async {
    if (_closed || _quitting) return;
    _cancelPreview();
    _message = null;
    _intentEpoch++;
    _invalidate();
    final generation = _generation;
    await _fresh();
    if (_closed || generation != _generation) return;
    if (_running) {
      _routeBlocked = false;
      _interrupted = false;
      _suspended = false;
      _arm();
    }
    _request();
  }

  void pauseSounds() {
    if (_closed) return;
    _disarm();
    _invalidate();
    _request();
  }

  void setMuted(bool muted) {
    if (_closed || _quitting || muted == _preferences.muted) return;
    _preferences = _preferences.copyWith(muted: muted);
    _intentEpoch++;
    _cancelPreview();
    _message = null;
    _invalidate();
    _commit();
    if (!muted) {
      unawaited(_refreshDesired());
    } else {
      _request();
    }
  }

  void setVolume(double volume, {bool commit = false, bool keyboard = false}) {
    if (_closed || _quitting || !volume.isFinite) return;
    final wasZero = _preferences.volume == 0;
    _preferences = _preferences.copyWith(volume: volume.clamp(0, 1));
    _dirtyVolume = true;
    if (_preferences.volume == 0) {
      _intentEpoch++;
      _cancelPreview();
      _invalidate();
      _request();
    } else if (wasZero) {
      unawaited(_refreshDesired());
    } else if (_audible) {
      playback.setVolume(_preferences.volume);
    }
    _saveTimer?.cancel();
    if (commit) {
      _commit();
    } else if (keyboard) {
      _saveTimer = scheduler.after(const Duration(milliseconds: 300), _commit);
    }
    _notify();
  }

  Future<void> _refreshDesired() async {
    final generation = _generation;
    await _fresh();
    if (!_closed && generation == _generation) _request();
  }

  void flushPreferences() {
    if (_dirtyVolume && !_closed) _commit();
  }

  void _commit() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _dirtyVolume = false;
    final save = _save;
    if (save != null) {
      unawaited(
        save(_preferences).catchError((Object _, StackTrace _) {
          // The repository's existing save warning/retry owns durability failures.
        }),
      );
    }
    _notify();
  }

  Future<int?> preview(FocusSoundId sound) async {
    if (_closed || _quitting || sound == FocusSoundId.off || !_audible) {
      return null;
    }
    final restore = _previewSound != null
        ? _restoreEpoch
        : (_armed ? _intentEpoch : null);
    _cancelPreview();
    _invalidate();
    final generation = _generation;
    await _fresh();
    if (_closed ||
        generation != _generation ||
        !_audible ||
        _session?.snapshot.phase != FocusPhase.focus ||
        _session?.reading == null) {
      return null;
    }
    _restoreEpoch = restore;
    _previewSound = sound;
    _previewToken = ++_previewSerial;
    _request();
    return _previewToken;
  }

  Future<void> dismissPreview(int token) async {
    flushPreferences();
    if (_previewToken != token || _closed) return;
    final restore = _restoreEpoch;
    _cancelPreview();
    _invalidate();
    final generation = _generation;
    await _fresh();
    if (_closed || generation != _generation) return;
    if (restore == null || restore != _intentEpoch || !_armed) _disarm();
    flushPreferences();
    _request();
  }

  Future<int?> retry() async {
    if (_message == null || _closed) return null;
    final sound = _previewSound;
    _message = null;
    if (sound != null) {
      return preview(sound);
    } else {
      await playSounds();
    }
    return null;
  }

  void _onPlayback(FocusAudioPlaybackEvent event) {
    if (_closed) return;
    if (event.kind == FocusAudioEventKind.interruptionEnded ||
        event.kind == FocusAudioEventKind.resumed) {
      if (event.generation != _interruptionGeneration ||
          !event.mayResume ||
          _interruptionEpoch != _intentEpoch) {
        return;
      }
      unawaited(() async {
        final epoch = _intentEpoch;
        await _fresh();
        if (_closed ||
            epoch != _intentEpoch ||
            !_armed ||
            event.generation != _interruptionGeneration ||
            _interruptionEpoch != epoch) {
          return;
        }
        _interruptionGeneration = null;
        _interruptionEpoch = null;
        _interrupted = false;
        _suspended = false;
        _invalidate();
        _request();
      }());
      return;
    }
    if (event.generation != _generation) return;
    switch (event.kind) {
      case FocusAudioEventKind.expired:
        final token = _previewToken;
        if (token != null) {
          unawaited(dismissPreview(token));
        } else {
          _disarm();
          _invalidate();
          _request();
          // Mobile completion alerts are already registered with the OS. An
          // audio-only expiry must not reconcile/cancel that outbox request
          // before its receiver can deliver. The ordinary foreground ticker,
          // resume or next timer action still owns timer/history reconciliation.
          // Desktop resident completion presentation needs immediate refresh.
          if (playback is! BackgroundFocusAudioPlayback) {
            unawaited(_fresh());
          }
        }
      case FocusAudioEventKind.routeLost:
        _routeBlocked = true;
        _intentEpoch++;
        _cancelPreview();
        _invalidate();
        _request();
      case FocusAudioEventKind.interrupted:
      case FocusAudioEventKind.suspended:
        _interruptionEpoch = _intentEpoch;
        _interruptionGeneration = event.generation;
        _interrupted = true;
        _suspended = event.kind == FocusAudioEventKind.suspended;
        _cancelPreview();
        _invalidate();
        _request();
      case FocusAudioEventKind.error:
        _fail();
      case FocusAudioEventKind.interruptionEnded:
      case FocusAudioEventKind.resumed:
        break;
    }
  }

  void background({required bool mobile}) {
    flushPreferences();
    if (mobile && playback is! BackgroundFocusAudioPlayback) {
      pauseSounds();
    } else if (_previewToken case final token?) {
      unawaited(dismissPreview(token));
    }
  }

  void beginQuit() {
    flushPreferences();
    _quitting = true;
    pauseSounds();
  }

  void cancelQuit() {
    _quitting = false;
    _notify();
  }

  FocusSoundId? get _desired => !_audible
      ? null
      : _previewSound ??
            (_armed && _preferences.sound != FocusSoundId.off
                ? _preferences.sound
                : null);
  void _request() {
    _dirty = true;
    if (_draining || _closed) return;
    _draining = true;
    _lane = _drain()
        .catchError((Object _, StackTrace _) {
          _fail();
        })
        .whenComplete(() {
          _draining = false;
          if (_dirty && !_closed) _request();
        });
  }

  Future<void> _drain() async {
    while (_dirty && !_closed) {
      _dirty = false;
      if (_source != null &&
          _transport == FocusAudioTransport.playing &&
          _playingGeneration == _generation &&
          _playingSound == _desired) {
        continue;
      }
      final previous = _source;
      _source = null;
      if (previous != null) await playback.release(previous);
      final sound = _desired;
      if (sound == null) continue;
      final generation = _generation;
      _transport = FocusAudioTransport.loading;
      _notify();
      PreparedFocusAudio? prepared;
      try {
        final loading = playback.prepare(
          sound,
          request: FocusAudioPreparation(
            generation: generation,
            intentEpoch: _intentEpoch,
            preview: _previewSound != null,
            runId: _session?.snapshot.runId,
            segment: _session?.snapshot.segment,
            focusDeadlineMicros: _running
                ? _session!.snapshot.elapsedDeadlineMicros
                : null,
          ),
        );
        var timedOut = false;
        try {
          prepared = await loading.timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              timedOut = true;
              unawaited(
                loading
                    .then((lateSource) => playback.release(lateSource))
                    .catchError((Object _, StackTrace _) {}),
              );
              throw TimeoutException('Audio preparation timed out');
            },
          );
        } finally {
          if (timedOut) _generation++;
        }
        if (_closed || generation != _generation || _desired != sound) {
          await playback.release(prepared);
          continue;
        }
        // Refresh after slow IO. Native start performs the final deadline check.
        await _fresh();
        if (_closed ||
            generation != _generation ||
            _desired != sound ||
            _session?.reading == null) {
          await playback.release(prepared);
          continue;
        }
        final now = _session!.reading!.elapsed.inMicroseconds;
        var deadline = _previewSound == null
            ? _session!.snapshot.elapsedDeadlineMicros!
            : now + 10000000;
        if (_running && _session!.snapshot.elapsedDeadlineMicros! < deadline) {
          deadline = _session!.snapshot.elapsedDeadlineMicros!;
        }
        final lease = FocusAudioLease(
          deadlineMicros: deadline,
          intentEpoch: _intentEpoch,
          runId: _session!.snapshot.runId,
          segment: _session!.snapshot.segment,
          preview: _previewSound != null,
        );
        _source = prepared;
        await playback.start(prepared, lease, generation, _preferences.volume);
        if (_closed || generation != _generation || _desired != sound) {
          playback.revoke(_generation);
          continue;
        }
        _transport = FocusAudioTransport.playing;
        _playingGeneration = generation;
        _playingSound = sound;
        if (_previewToken != null) {
          final token = _previewToken!;
          _previewExpiry = scheduler.after(
            Duration(microseconds: deadline - now),
            () => unawaited(dismissPreview(token)),
          );
        }
        _notify();
      } on FocusAudioLeaseExpired {
        if (!_closed && generation == _generation) {
          _disarm();
          _invalidate();
          _dirty = true;
          await _fresh();
        }
      } catch (_) {
        if (prepared != null && !identical(_source, prepared)) {
          try {
            await playback.release(prepared);
          } catch (_) {
            /* surfaced below */
          }
        }
        if (!_closed &&
            (generation == _generation ||
                _transport == FocusAudioTransport.loading)) {
          _fail();
        }
      }
    }
  }

  void _fail() {
    _invalidate();
    _message = 'Sound could not play. Retry.';
    _transport = FocusAudioTransport.error;
    _notify();
    _request();
  }

  @override
  void invalidateForReset() {
    _saveTimer?.cancel();
    _dirtyVolume = false;
    _preferences = const FocusSoundPreferences();
    _message = null;
    _routeBlocked = false;
    _interrupted = false;
    _suspended = false;
    _disarm();
    _invalidate();
    _request();
  }

  @override
  Future<void> clearForReset() async {
    await _lane;
  }

  Future<void> close() => _closing ??= _close();
  Future<void> _close() async {
    flushPreferences();
    _disarm();
    _invalidate();
    _closed = true;
    _saveTimer?.cancel();
    playback.onEvent = null;
    if (playback case BackgroundFocusAudioPlayback background) {
      background.onMediaCommand = null;
    }
    // A late prepare is still observed; the adapter quarantines stale resources.
    await playback.close();
    await _lane;
  }

  @override
  void dispose() {
    unawaited(close().catchError((Object _, StackTrace _) {}));
    super.dispose();
  }
}
