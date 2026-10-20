import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/data/timer_clock.dart';
import 'package:poma/domain/timer_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.poma.poma/timer_clock');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'native sleep-inclusive samples, not Dart execution, drive elapsed time',
    () async {
      var elapsed = 1000000;
      final utc = DateTime.utc(2026, 10, 20).microsecondsSinceEpoch;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'sample');
        return {'utcMicros': utc, 'elapsedMicros': elapsed};
      });
      final clock = NativeTimerClock();
      final first = await clock.sample();
      elapsed += 3600000000;
      final next = await clock.sample();
      expect(next.elapsed - first.elapsed, const Duration(hours: 1));
      expect(next.utcNow, first.utcNow); // Wall time is not an elapsed source.
    },
  );

  test(
    'missing bridge and native failures never fall back to wall time',
    () async {
      await expectLater(
        NativeTimerClock().sample(),
        throwsA(isA<TimerClockException>()),
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(code: 'clock_unavailable'),
      );
      await expectLater(
        NativeTimerClock().sample(),
        throwsA(isA<TimerClockException>()),
      );
    },
  );

  test('malformed and regressing native readings are rejected', () async {
    Object? value;
    messenger.setMockMethodCallHandler(channel, (_) async => value);
    final clock = NativeTimerClock();
    for (final malformed in [
      null,
      {},
      {'utcMicros': 'bad', 'elapsedMicros': 1},
      {'utcMicros': 0, 'elapsedMicros': -1},
      {'utcMicros': 0, 'elapsedMicros': 1.5},
      {'utcMicros': 9223372036854775807, 'elapsedMicros': 1},
    ]) {
      value = malformed;
      await expectLater(clock.sample(), throwsA(isA<TimerClockException>()));
    }
    value = {'utcMicros': 0, 'elapsedMicros': 10};
    await clock.sample();
    value = {'utcMicros': 0, 'elapsedMicros': 9};
    await expectLater(clock.sample(), throwsA(isA<TimerClockException>()));
  });
}
