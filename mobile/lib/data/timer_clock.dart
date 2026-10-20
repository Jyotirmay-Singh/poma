import 'package:flutter/services.dart';
import '../domain/timer_engine.dart';

/// Boot-relative clocks include deep sleep. This installs no polling or service.
class NativeTimerClock implements TimerClock {
  NativeTimerClock({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('dev.poma.poma/timer_clock');
  final MethodChannel _channel;
  Duration? _lastElapsed;

  @override
  Future<ClockReading> sample() async {
    try {
      final value = await _channel.invokeMapMethod<String, Object?>('sample');
      final utc = value?['utcMicros'];
      final elapsed = value?['elapsedMicros'];
      if (utc is! int || elapsed is! int || elapsed < 0) {
        throw const TimerClockException();
      }
      final duration = Duration(microseconds: elapsed);
      if (_lastElapsed != null && duration < _lastElapsed!) {
        throw const TimerClockException();
      }
      final reading = ClockReading(
        utcNow: DateTime.fromMicrosecondsSinceEpoch(utc, isUtc: true),
        elapsed: duration,
      );
      _lastElapsed = duration;
      return reading;
    } catch (_) {
      throw const TimerClockException();
    }
  }
}
