import 'package:flutter/services.dart';
import '../application/focus_block_ports.dart';

class WindowsFocusTime implements FocusTimeResolver {
  WindowsFocusTime(this.channel);
  final MethodChannel channel;
  @override
  Future<String> fingerprint() async {
    try {
      return (await channel.invokeMapMethod<String, Object?>(
            'focusTimeZone',
          ))!['fingerprint']
          as String;
    } catch (_) {
      throw const FocusFailure(FocusFailureKind.invalidTime);
    }
  }

  @override
  Future<FocusTimeResolution> resolve(DateTime wallTime) async {
    try {
      final m = (await channel
          .invokeMapMethod<String, Object?>('focusTimeResolve', {
            'year': wallTime.year,
            'month': wallTime.month,
            'day': wallTime.day,
            'hour': wallTime.hour,
            'minute': wallTime.minute,
            'second': wallTime.second,
          }))!;
      return FocusTimeResolution(
        utc: DateTime.fromMicrosecondsSinceEpoch(
          m['utcMicros'] as int,
          isUtc: true,
        ),
        offsetMinutes: m['offsetMinutes'] as int,
        zone: m['zone'] as String,
        fingerprint: m['fingerprint'] as String,
      );
    } catch (_) {
      throw const FocusFailure(FocusFailureKind.invalidTime);
    }
  }
}
