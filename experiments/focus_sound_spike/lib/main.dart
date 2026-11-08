import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'lease_gate.dart';

final stage = ValueNotifier<String>('Ready — isolated developer experiment');

class WindowsClock {
  final _sample = DynamicLibrary.open('kernelbase.dll')
      .lookupFunction<
        Void Function(Pointer<Uint64>),
        void Function(Pointer<Uint64>)
      >('QueryInterruptTimePrecise');

  int now() {
    final reading = calloc<Uint64>();
    try {
      _sample(reading);
      return reading.value ~/ 10;
    } finally {
      calloc.free(reading);
    }
  }
}

bool hideOwnWindow() {
  final user = DynamicLibrary.open('user32.dll');
  final find = user
      .lookupFunction<
        IntPtr Function(Pointer<Utf16>, Pointer<Utf16>),
        int Function(Pointer<Utf16>, Pointer<Utf16>)
      >('FindWindowW');
  final owner = user
      .lookupFunction<
        Uint32 Function(IntPtr, Pointer<Uint32>),
        int Function(int, Pointer<Uint32>)
      >('GetWindowThreadProcessId');
  final show = user
      .lookupFunction<Int32 Function(IntPtr, Int32), int Function(int, int)>(
        'ShowWindow',
      );
  final visible = user
      .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
        'IsWindowVisible',
      );
  final title = 'focus_sound_spike'.toNativeUtf16();
  final ownerId = calloc<Uint32>();
  try {
    final window = find(nullptr.cast<Utf16>(), title);
    if (window == 0) throw StateError('Spike window not found');
    owner(window, ownerId);
    if (ownerId.value != pid) {
      throw StateError('Refusing to hide another process');
    }
    show(window, 0);
    return visible(window) == 0;
  } finally {
    calloc.free(title);
    calloc.free(ownerId);
  }
}

Future<void> audit(String reportPath) async {
  final engine = SoLoud.instance;
  late final WindowsClock clock;
  late final LeaseGate gate;
  final checks = <Map<String, Object?>>[];
  final report = <String, Object?>{
    'kind':
        'Windows x64 isolated real-backend experiment; not production acceptance',
    'library': 'flutter_soloud 4.1.7',
    'startedUtc': DateTime.now().toUtc().toIso8601String(),
    'clock': 'QueryInterruptTimePrecise (100ns / 10)',
    'profileOpened': false,
    'foregroundCountdown': false,
    'listening': 'Not performed; transport/clock measurements only',
    'checks': checks,
  };
  void check(
    String name,
    bool passed, [
    Map<String, Object?> details = const {},
  ]) {
    checks.add({'name': name, 'passed': passed, ...details});
    if (!passed) throw StateError('Failed: $name');
  }

  try {
    clock = WindowsClock();
    gate = LeaseGate(clock.now);
    stage.value = 'Initializing real audio backend';
    await engine.init(sampleRate: 48000, bufferSize: 512);
    check('native engine initialized', engine.isInitialized, {
      'availableDeviceCount': engine.listPlaybackDevices().length,
    });
    for (final name in [
      'tibetan_bells',
      'waterfall',
      'ocean_waves',
      'forest_birds',
    ]) {
      stage.value = 'Checking bundled $name';
      final source = await engine.loadAsset(
        'assets/$name.ogg',
        mode: LoadMode.disk,
      );
      final length = engine.getLength(source);
      final voice = engine.play(source, looping: true, volume: 0.12);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      check('$name starts', engine.getIsValidVoiceHandle(voice));
      engine.setVolume(voice, 0.06);
      check('$name volume', (engine.getVolume(voice) - 0.06).abs() < 0.001);
      engine.fadeVolume(voice, 0.03, const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      check('$name fade', (engine.getVolume(voice) - 0.03).abs() < 0.001);
      engine.setPause(voice, true);
      final paused = engine.getPosition(voice);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      check(
        '$name pause',
        (engine.getPosition(voice) - paused).inMilliseconds.abs() < 40,
      );
      engine.setPause(voice, false);
      for (var join = 0; join < 5; join++) {
        engine.seek(voice, length - const Duration(milliseconds: 180));
        await Future<void>.delayed(const Duration(milliseconds: 400));
        final position = engine.getPosition(voice);
        check(
          '$name loop wrap ${join + 1}',
          position < const Duration(seconds: 2),
          {'positionMicros': position.inMicroseconds},
        );
      }
      await engine.stop(voice);
      check('$name stop', !engine.getIsValidVoiceHandle(voice));
      await engine.disposeSource(source);
    }
    final source = await engine.loadAsset(
      'assets/waterfall.ogg',
      mode: LoadMode.disk,
    );
    stage.value = 'Hidden-window native deadline test';
    check('own window hidden', hideOwnWindow());
    final deadline = clock.now() + 2000000;
    final ticket = gate.bind('synthetic-focus', 1, deadline);
    final voice = engine.play(source, looping: true, volume: 0.12);
    engine.scheduleStop(voice, Duration(microseconds: deadline - clock.now()));
    while (engine.getIsValidVoiceHandle(voice) &&
        clock.now() < deadline + 1000000) {
      // Observation only. The native scheduler, not this callback, stops audio.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final latency = clock.now() - deadline;
    check(
      'hidden native deadline <=250ms',
      !engine.getIsValidVoiceHandle(voice) &&
          latency <= 250000 &&
          latency >= -50000,
      {'stopObservedOffsetMicros': latency},
    );
    check(
      'expired interruption token rejected',
      !gate.allows(ticket, 'synthetic-focus', 1),
    );

    stage.value = 'Native stop while Dart is deliberately blocked';
    final blockedVoice = engine.play(source, looping: true, volume: 0.12);
    engine.scheduleStop(blockedVoice, const Duration(seconds: 1));
    sleep(const Duration(milliseconds: 1500));
    check(
      'native stop survives blocked Dart isolate',
      !engine.getIsValidVoiceHandle(blockedVoice),
    );

    final interruptedDeadline = clock.now() + 300000;
    final interruptedTicket = gate.bind(
      'synthetic-focus',
      2,
      interruptedDeadline,
    );
    final interruptedVoice = engine.play(source, looping: true, volume: 0.04);
    engine.setPause(interruptedVoice, true);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final resumeAllowed = gate.allows(interruptedTicket, 'synthetic-focus', 2);
    if (!resumeAllowed) await engine.stop(interruptedVoice);
    check(
      'paused native transport cannot resume an expired lease',
      !resumeAllowed && !engine.getIsValidVoiceHandle(interruptedVoice),
    );

    stage.value = 'Switch/stop/dispose repetition';
    for (var cycle = 0; cycle < 20; cycle++) {
      final next = engine.play(source, looping: true, volume: 0.04);
      check('single voice cycle $cycle', engine.getActiveVoiceCount() <= 1);
      await engine.stop(next);
      check('retired voice cycle $cycle', !engine.getIsValidVoiceHandle(next));
    }
    gate.revoke();
    await engine.disposeSource(source);
    check('no active voices after cleanup', engine.getActiveVoiceCount() == 0);
    await engine.deinitAsync();
    check('engine disposed', !engine.isInitialized);
    report['passed'] = true;
  } catch (error, stack) {
    report['passed'] = false;
    report['error'] = error.toString();
    report['stack'] = stack.toString();
    if (engine.isInitialized) await engine.deinitAsync();
  }
  report['finishedUtc'] = DateTime.now().toUtc().toIso8601String();
  final file = File(reportPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  exit(report['passed'] == true ? 0 : 1);
}

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final reportPath = args
      .where((a) => a.startsWith('--report='))
      .map((a) => a.substring(9))
      .firstOrNull;
  runApp(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder<String>(
            valueListenable: stage,
            builder: (context, value, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value),
                const Text(
                  'No Poma data or notifications. Listening acceptance is separate.',
                ),
                if (!args.contains('--self-test'))
                  ElevatedButton(
                    onPressed: reportPath == null
                        ? null
                        : () => unawaited(audit(reportPath)),
                    child: const Text('Run playback qualification'),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (args.contains('--self-test') && reportPath != null) {
    stage.addListener(() {
      File('$reportPath.events.jsonl').writeAsStringSync(
        '${jsonEncode({'stage': stage.value, 'utc': DateTime.now().toUtc().toIso8601String()})}\n',
        mode: FileMode.append,
      );
    });
    unawaited(
      Future<void>.delayed(const Duration(seconds: 5), () => audit(reportPath)),
    );
  }
}
