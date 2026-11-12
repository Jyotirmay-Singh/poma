import 'dart:async';
import 'dart:io';
import 'package:flutter_soloud/flutter_soloud.dart';
import '../application/focus_audio_ports.dart';
import '../domain/focus_sound_preferences.dart';
import 'windows_focus_audio_guard.dart';

class _Prepared implements PreparedFocusAudio {
  _Prepared(this.source);
  final AudioSource source;
  bool released = false;
}

class SoLoudFocusAudioPlayback implements FocusAudioPlaybackPort {
  @override
  FocusAudioAvailability get availability => Platform.isWindows
      ? FocusAudioAvailability.available
      : FocusAudioAvailability.unavailable;
  final _engine = SoLoud.instance;
  WindowsFocusAudioGuard? _guard;
  SoundHandle? _voice;
  Timer? _idle;
  bool _closed = false, _refreshDevice = false;
  int _generation = 0;
  Future<void>? _initializing, _teardown;
  Future<void>? _retiring;
  final Set<_Prepared> _sources = {};
  final Map<SoundHash, int> _references = {};
  bool _preparing = false;
  @override
  void Function(FocusAudioPlaybackEvent)? onEvent;
  static const _assets = {
    FocusSoundId.tibetanBells: 'assets/audio/tibetan_bells.ogg',
    FocusSoundId.waterfall: 'assets/audio/waterfall.ogg',
    FocusSoundId.oceanWaves: 'assets/audio/ocean_waves.ogg',
    FocusSoundId.forestBirds: 'assets/audio/forest_birds.ogg',
    FocusSoundId.calmingRain: 'assets/audio/calming_rain.ogg',
    FocusSoundId.omChanting: 'assets/audio/om_chanting.ogg',
  };
  Future<void> _initialize() async {
    await _teardown;
    if (_closed) throw StateError('Audio closed');
    if (_engine.isInitialized) return;
    if (!Platform.isWindows) {
      throw UnsupportedError('Mobile audio integration pending');
    }
    await _engine.init(sampleRate: 48000, bufferSize: 512);
    if (_closed) {
      await _engine.deinitAsync();
      throw StateError('Audio closed');
    }
    try {
      // Session 4 supplies the mobile focus/service/native deadline guard.
      _guard = WindowsFocusAudioGuard((event) {
        if (event.kind == FocusAudioEventKind.routeLost) _refreshDevice = true;
        onEvent?.call(
          event.generation == 0
              ? FocusAudioPlaybackEvent(
                  event.kind,
                  _generation,
                  mayResume: event.mayResume,
                )
              : event,
        );
      });
      _guard!.revoke(_generation);
      _pinDevice();
    } catch (_) {
      _guard?.close();
      _guard = null;
      await _engine.deinitAsync();
      rethrow;
    }
  }

  void _pinDevice() {
    final devices = _engine.listPlaybackDevices();
    final defaults = devices.where((d) => d.isDefault && d.id >= 0);
    if (defaults.isEmpty) throw StateError('No concrete output device');
    _engine.changeDevice(newDevice: defaults.first);
    _refreshDevice = false;
  }

  @override
  Future<PreparedFocusAudio> prepare(
    FocusSoundId sound, {
    FocusAudioPreparation? request,
  }) async {
    if (_preparing) {
      throw StateError('Previous audio preparation is still finishing');
    }
    _preparing = true;
    try {
      return await _prepare(sound);
    } finally {
      _preparing = false;
    }
  }

  Future<PreparedFocusAudio> _prepare(FocusSoundId sound) async {
    _idle?.cancel();
    if (!_assets.containsKey(sound) || _closed) {
      throw StateError('Invalid audio request');
    }
    final initialization = _initializing ??= _initialize();
    try {
      await initialization;
    } finally {
      if (identical(_initializing, initialization)) _initializing = null;
    }
    if (_closed) throw StateError('Audio closed');
    if (_refreshDevice) _pinDevice();
    final source = _Prepared(
      await _engine.loadAsset(_assets[sound]!, mode: LoadMode.disk),
    );
    if (_closed) {
      if (_engine.isInitialized) await _engine.disposeSource(source.source);
      throw StateError('Audio closed');
    }
    _sources.add(source);
    _references.update(
      source.source.soundHash,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return source;
  }

  @override
  Future<void> start(
    PreparedFocusAudio resource,
    FocusAudioLease lease,
    int generation,
    double volume,
  ) async {
    if (_closed || generation < _generation) return;
    final source = resource as _Prepared;
    if (source.released || _guard == null) {
      throw StateError('Source unavailable');
    }
    _idle?.cancel();
    final remaining = lease.deadlineMicros - _guard!.now();
    if (remaining <= 0) throw const FocusAudioLeaseExpired();
    _generation = generation;
    final voice = _voice = _engine.play(
      source.source,
      paused: true,
      looping: true,
      volume: 0,
    );
    final duration = Duration(microseconds: remaining);
    _engine.scheduleStop(voice, duration);
    final fade = remaining < 200000
        ? duration
        : const Duration(milliseconds: 200);
    _engine.fadeScheduled(
      voice,
      _engine.getEngineTime() + duration - fade,
      0,
      fade,
      thenStop: true,
    );
    if (!_guard!.bind(voice.id, generation, lease.deadlineMicros)) {
      _voice = null;
      if (_guard!.now() >= lease.deadlineMicros) {
        throw const FocusAudioLeaseExpired();
      }
      throw StateError('Audio lease rejected');
    }
    _engine.fadeVolume(voice, volume, const Duration(milliseconds: 600));
  }

  @override
  void setVolume(double volume) {
    final voice = _voice;
    if (voice == null || !_engine.isInitialized) return;
    try {
      _engine.setVolume(voice, volume);
    } catch (_) {
      onEvent?.call(
        FocusAudioPlaybackEvent(FocusAudioEventKind.error, _generation),
      );
    }
  }

  @override
  void revoke(int generation, {bool fade = false}) {
    _generation = generation;
    final voice = _voice;
    _voice = null;
    if (voice != null && _engine.isInitialized) {
      try {
        if (fade && _engine.getIsValidVoiceHandle(voice)) {
          _engine.fadeVolume(voice, 0, const Duration(milliseconds: 200));
          _engine.scheduleStop(voice, const Duration(milliseconds: 200));
          _retiring = Future<void>.delayed(const Duration(milliseconds: 200));
        } else {
          _engine.setVolume(voice, 0);
        }
      } catch (_) {
        /* Native guard still revokes the voice below. */
      }
    }
    _guard?.revoke(generation, fade: fade && voice != null);
  }

  @override
  Future<void> release(PreparedFocusAudio resource) async {
    final source = resource as _Prepared;
    if (source.released) return;
    source.released = true;
    await _retiring;
    _retiring = null;
    final hash = source.source.soundHash;
    final references = _references[hash] ?? 1;
    try {
      if (references <= 1) {
        _references.remove(hash);
        if (_engine.isInitialized) await _engine.disposeSource(source.source);
      } else {
        _references[hash] = references - 1;
      }
    } finally {
      _sources.remove(source);
    }
    if (_sources.isEmpty && !_closed) {
      _idle?.cancel();
      _idle = Timer(const Duration(seconds: 5), () {
        _teardown = _shutdownEngine().catchError((Object _, StackTrace _) {
          onEvent?.call(
            FocusAudioPlaybackEvent(FocusAudioEventKind.error, _generation),
          );
        });
      });
    }
  }

  Future<void> _shutdownEngine() async {
    _guard?.close();
    _guard = null;
    if (_engine.isInitialized) await _engine.deinitAsync();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _idle?.cancel();
    revoke(++_generation);
    await _initializing?.catchError((Object _, StackTrace _) {});
    await _teardown;
    await _shutdownEngine();
    _sources.clear();
    _references.clear();
  }
}
