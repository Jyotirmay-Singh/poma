import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../application/focus_audio_ports.dart';
import '../domain/focus_sound_preferences.dart';

class _MobilePrepared implements PreparedFocusAudio {
  _MobilePrepared(this.id, this.epoch, this.request);
  final int id, epoch;
  final FocusAudioPreparation request;
  bool released = false;
}

/// The native runtime owns the one mobile renderer, its lease, and OS cleanup.
/// No Dart ticker or secondary timer/database owner is involved in expiry.
class MobileFocusAudioPlayback
    implements FocusAudioPlaybackPort, BackgroundFocusAudioPlayback {
  MobileFocusAudioPlayback({MethodChannel? channel, DynamicLibrary? library})
    : _channel = channel ?? const MethodChannel('dev.poma.poma/focus_audio') {
    try {
      final native =
          library ??
          (Platform.isAndroid
              ? DynamicLibrary.open('libpoma_focus_audio.so')
              : DynamicLibrary.process());
      _now = native.lookupFunction<Int64 Function(), int Function()>(
        'pomaMobileNow',
      );
      _epoch = native.lookupFunction<Int64 Function(), int Function()>(
        'pomaMobileEpoch',
      );
      _revoke = native
          .lookupFunction<
            Void Function(Int64, Int64, Int32),
            void Function(int, int, int)
          >('pomaMobileRevoke');
      _volume = native
          .lookupFunction<
            Void Function(Int64, Float),
            void Function(int, double)
          >('pomaMobileVolume');
      _closeNative = native
          .lookupFunction<Void Function(Int64), void Function(int)>(
            'pomaMobileClose',
          );
      _owner = native.lookupFunction<Int64 Function(), int Function()>(
        'pomaMobileOpen',
      )();
      _available = true;
      _channel.setMethodCallHandler(_event);
    } catch (_) {
      _available = false;
    }
  }
  final MethodChannel _channel;
  late final int Function() _now, _epoch;
  late final void Function(int, int, int) _revoke;
  late final void Function(int, double) _volume;
  late final void Function(int) _closeNative;
  int _owner = 0, _generation = 0, _platformEpoch = 0;
  bool _available = false, _closed = false;
  @override
  FocusAudioAvailability get availability => _available && !_closed
      ? FocusAudioAvailability.available
      : FocusAudioAvailability.unavailable;
  @override
  void Function(FocusAudioPlaybackEvent)? onEvent;
  @override
  void Function(FocusAudioMediaCommand)? onMediaCommand;

  Future<void> _event(MethodCall call) async {
    if (_closed || call.arguments is! Map) return;
    final args = Map<String, Object?>.from(call.arguments as Map);
    if (args['owner'] != _owner) return;
    final epoch = args['epoch'], generation = args['generation'];
    if (epoch is! int || generation is! int || epoch < _platformEpoch) return;
    _platformEpoch = epoch;
    if (call.method == 'media') {
      final action = args['action'];
      if (action is! String) return;
      final values = FocusAudioMediaAction.values.where(
        (v) => v.name == action,
      );
      if (values.isEmpty) return;
      onMediaCommand?.call(
        FocusAudioMediaCommand(
          values.first,
          generation,
          args['runId'] as String?,
          args['segment'] as int?,
        ),
      );
    } else if (call.method == 'event') {
      final kind = args['kind'];
      if (kind is int &&
          kind >= 0 &&
          kind < FocusAudioEventKind.values.length) {
        // Interruption end never authorizes automatic playback on mobile.
        onEvent?.call(
          FocusAudioPlaybackEvent(FocusAudioEventKind.values[kind], generation),
        );
      }
    }
  }

  @override
  void sessionChanged(FocusAudioSessionEvent event) {
    if (!_available || _closed) return;
    final snapshot = event.snapshot;
    unawaited(
      _channel
          .invokeMethod<void>('session', {
            'owner': _owner,
            'runId': snapshot.runId,
            'segment': snapshot.segment,
            'deadline': snapshot.elapsedDeadlineMicros,
            'running':
                snapshot.status.name == 'running' &&
                snapshot.phase.name == 'focus' &&
                event.reading != null,
            'restoration': event.restoration,
          })
          .catchError((Object _, StackTrace _) {}),
    );
  }

  @override
  Future<PreparedFocusAudio> prepare(
    FocusSoundId sound, {
    FocusAudioPreparation? request,
  }) async {
    if (!_available ||
        _closed ||
        request == null ||
        sound == FocusSoundId.off ||
        request.generation != _generation) {
      throw StateError('Audio unavailable');
    }
    final epoch = _epoch();
    final startup = math.min(
      _now() + 10000000,
      request.focusDeadlineMicros ?? 0x7fffffffffffffff,
    );
    if (startup <= _now()) throw const FocusAudioLeaseExpired();
    final id = await _channel.invokeMethod<int>('prepare', {
      'owner': _owner,
      'generation': request.generation,
      'epoch': epoch,
      'startupDeadline': startup,
      'sound': sound.index,
      'runId': request.runId,
      'segment': request.segment,
      'intentEpoch': request.intentEpoch,
      'preview': request.preview,
    });
    if (id == null || id <= 0) {
      if (_now() >= startup) throw const FocusAudioLeaseExpired();
      throw StateError('Sound could not be prepared');
    }
    return _MobilePrepared(id, epoch, request);
  }

  @override
  Future<void> start(
    PreparedFocusAudio resource,
    FocusAudioLease lease,
    int generation,
    double volume,
  ) async {
    final source = resource as _MobilePrepared;
    if (_closed ||
        source.released ||
        generation != _generation ||
        source.request.generation != generation ||
        source.request.intentEpoch != lease.intentEpoch ||
        source.request.runId != lease.runId ||
        source.request.segment != lease.segment) {
      return;
    }
    final result = await _channel.invokeMethod<int>('start', {
      'owner': _owner,
      'source': source.id,
      'generation': generation,
      'epoch': source.epoch,
      'deadline': lease.deadlineMicros,
      'volume': volume,
    });
    if (result == -1 || _now() >= lease.deadlineMicros) {
      throw const FocusAudioLeaseExpired();
    }
    if (result != 1) throw StateError('Playback authorization expired');
  }

  @override
  void revoke(int generation, {bool fade = false}) {
    _generation = generation;
    if (_available && !_closed) _revoke(_owner, generation, fade ? 200 : 0);
  }

  @override
  void setVolume(double volume) {
    if (_available && !_closed) _volume(_owner, volume);
  }

  @override
  Future<void> release(PreparedFocusAudio resource) async {
    final source = resource as _MobilePrepared;
    if (source.released) return;
    source.released = true;
    if (_available && !_closed) {
      await _channel.invokeMethod<void>('release', {
        'owner': _owner,
        'source': source.id,
      });
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    if (_available) _closeNative(_owner);
    _closed = true;
    _channel.setMethodCallHandler(null);
    onEvent = null;
    onMediaCommand = null;
  }
}
