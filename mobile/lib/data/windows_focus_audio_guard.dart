import 'dart:ffi';
import '../application/focus_audio_ports.dart';

typedef _Event = Void Function(Int32, Int64, Int64);

/// Private runner ABI; it wraps the exact pinned SoLoud native exports.
class WindowsFocusAudioGuard {
  WindowsFocusAudioGuard(this.onEvent) {
    final library = DynamicLibrary.executable();
    _initialize = library
        .lookupFunction<
          Int32 Function(Pointer<NativeFunction<_Event>>),
          int Function(Pointer<NativeFunction<_Event>>)
        >('pomaAudioInitialize');
    _now = library.lookupFunction<Int64 Function(), int Function()>(
      'pomaAudioNow',
    );
    _epoch = library.lookupFunction<Int64 Function(), int Function()>(
      'pomaAudioEpoch',
    );
    _bind = library
        .lookupFunction<
          Int32 Function(Uint32, Int64, Int64, Int64),
          int Function(int, int, int, int)
        >('pomaAudioBind');
    _revoke = library
        .lookupFunction<Void Function(Int64, Int32), void Function(int, int)>(
          'pomaAudioRevoke',
        );
    _detach = library.lookupFunction<Void Function(), void Function()>(
      'pomaAudioDetach',
    );
    void receive(int kind, int generation, int epoch) {
      if (_closed || epoch < _platformEpoch) return;
      _platformEpoch = epoch;
      onEvent(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.values[kind],
          generation,
          mayResume: kind == FocusAudioEventKind.resumed.index,
        ),
      );
    }

    _listener = NativeCallable<_Event>.listener(receive);
    if (_initialize(_listener.nativeFunction) == 0) {
      _listener.close();
      throw StateError('Audio safety guard unavailable');
    }
    _platformEpoch = _epoch();
  }
  final void Function(FocusAudioPlaybackEvent) onEvent;
  late final int Function(Pointer<NativeFunction<_Event>>) _initialize;
  late final int Function() _now, _epoch;
  late final int Function(int, int, int, int) _bind;
  late final void Function(int, int) _revoke;
  late final void Function() _detach;
  late final NativeCallable<_Event> _listener;
  int _platformEpoch = 0;
  bool _closed = false;
  int now() => _now();
  bool bind(int voice, int generation, int deadline) =>
      !_closed && _bind(voice, generation, _platformEpoch, deadline) == 1;
  void revoke(int generation, {bool fade = false}) {
    if (!_closed) _revoke(generation, fade ? 200 : 0);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _detach();
    _listener.close();
  }
}
