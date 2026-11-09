// Explicit developer target. Never imported by production main.
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/focus_audio_coordinator.dart';
import 'package:poma/application/focus_audio_ports.dart';
import 'package:poma/application/local_reset_participant.dart';
import 'package:poma/data/soloud_focus_audio_playback.dart';
import 'package:poma/data/timer_clock.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/domain/focus_sound_preferences.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart' show PomaApp;

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = NativeWindowsHost();
  final isolated = await host.channel.invokeMethod<bool>(
    'reviewAudioEnvironment',
  );
  final environment = await host.initialize();
  if (isolated != true ||
      environment.packaged ||
      !environment.dataDirectory.endsWith('fictional-review-profile')) {
    throw StateError('Isolated unpackaged audio review required');
  }
  final repository = await host.repository(environment);
  final clock = NativeTimerClock();
  final audio = FocusAudioCoordinator(SoLoudFocusAudioPlayback());
  final app = await AppController.create(
    repository,
    clock: clock,
    onFocusAudioSession: audio.onSession,
    focusAudio: audio,
    resetParticipant: CompositeLocalResetParticipant([audio]),
  );
  audio.bind(
    preferences: app.focusSoundPreferences,
    save: app.updateFocusSoundPreferences,
    reconcile: () async {
      await app.reconcile();
    },
  );
  final desktop = DesktopController(app, host, environment);
  await desktop.initialize();
  runApp(PomaApp(controller: app, desktop: desktop));
  final directory = Directory(environment.dataDirectory);
  final report = <String, Object?>{
    'kind':
        'Isolated production-core/adapter Windows review; not installed acceptance',
    'listening': 'Not performed',
    'physicalSleepWake': 'Pending',
    'physicalRouteRemoval': 'Pending',
    'checks': <Map<String, Object?>>[],
  };
  final checks = report['checks'] as List<Map<String, Object?>>;
  void check(String name, bool passed) {
    checks.add({'name': name, 'passed': passed});
    if (!passed) throw StateError(name);
  }

  Future<void> until(bool Function() condition) async {
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (!condition()) {
      if (DateTime.now().isAfter(end)) {
        throw StateError('Timed out: ${audio.state.message}');
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }

  Future<void> phase(String name, int seconds) async {
    await File('${directory.path}/session2-phase.json').writeAsString(
      jsonEncode({
        'phase': name,
        'seconds': seconds,
        'utc': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
    await Future<void>.delayed(Duration(seconds: seconds));
  }

  Future<void> run() async {
    final engine = SoLoud.instance;
    try {
      await app.deleteAllLocalData();
      check('fresh Off is lazy and silent', !engine.isInitialized);
      if (arguments.contains('--measure')) await phase('off-idle', 60);
      await app.updateSettings(const TimerSettings(focusMinutes: 5));
      audio.setVolume(.12, commit: true);
      audio.selectSound(FocusSoundId.waterfall);
      await app.flush();
      check('ready choice does not load', !engine.isInitialized);
      await app.toggleTimer();
      for (final sound in FocusSoundId.values.where(
        (s) => s != FocusSoundId.off,
      )) {
        audio.selectSound(sound);
        await until(() => audio.state.transport == FocusAudioTransport.playing);
        check(
          '${sound.name} one native voice',
          engine.getActiveVoiceCount() == 1,
        );
        final source = engine.activeSounds.single;
        final voice = source.handles.single;
        await Future<void>.delayed(const Duration(milliseconds: 650));
        check(
          '${sound.name} exact gain',
          (engine.getVolume(voice) - .12).abs() < .001,
        );
        for (var wrap = 0; wrap < 2; wrap++) {
          engine.seek(
            voice,
            engine.getLength(source) - const Duration(milliseconds: 150),
          );
          await Future<void>.delayed(const Duration(milliseconds: 350));
          check(
            '${sound.name} native wrap $wrap',
            engine.getPosition(voice) < const Duration(seconds: 2),
          );
        }
      }
      audio.setMuted(true);
      check('mute immediately silent', engine.getActiveVoiceCount() == 0);
      audio.setMuted(false);
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      final zeroVoice = engine.activeSounds.single.handles.single;
      audio.setVolume(0, commit: true);
      audio.setMuted(true);
      audio.setMuted(false);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      check(
        'zero stays silent through mute and unmute',
        !engine.getIsValidVoiceHandle(zeroVoice) &&
            audio.preferences.volume == 0,
      );
      audio.setVolume(.12, commit: true);
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      await host.channel.invokeMethod<void>('reviewAudioTimer', {
        'action': 'pause',
      });
      await until(() => app.timer.status == RunStatus.paused);
      check('native tray pause stops audio', engine.getActiveVoiceCount() == 0);
      await host.channel.invokeMethod<void>('reviewAudioTimer', {
        'action': 'resume',
      });
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      final voices = engine.getActiveVoiceCount();
      desktop.navigate(1);
      desktop.navigate(0);
      await host.channel.invokeMethod<void>('reviewAudioVisibility', {
        'visible': false,
      });
      await Future<void>.delayed(const Duration(milliseconds: 200));
      check(
        'navigation and hidden window keep one voice',
        engine.getActiveVoiceCount() == voices && voices == 1,
      );
      final library = DynamicLibrary.executable();
      final power = library
          .lookupFunction<Void Function(Uint32), void Function(int)>(
            'pomaAudioTestPower',
          );
      final route = library.lookupFunction<Void Function(), void Function()>(
        'pomaAudioTestRoute',
      );
      final suspendedVoice = engine.activeSounds.single.handles.single;
      power(4);
      check(
        'native suspend gate silent before Dart callback',
        engine.getPause(suspendedVoice) &&
            engine.getVolume(suspendedVoice) == 0,
      );
      await until(() => audio.state.suspended);
      power(18);
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      check(
        'synthetic wake revalidates same Focus',
        engine.getActiveVoiceCount() == 1,
      );
      route();
      await until(() => audio.state.routeBlocked);
      check(
        'native route invalidation silent',
        engine.getActiveVoiceCount() == 0,
      );
      await audio.playSounds();
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      final preview = await audio.preview(FocusSoundId.waterfall);
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      check('preview token present', preview != null);
      await Future<void>.delayed(const Duration(milliseconds: 10300));
      await until(
        () =>
            audio.state.previewSound == null &&
            audio.state.transport == FocusAudioTransport.playing,
      );
      check(
        'preview expiry restores one continuous voice',
        engine.getActiveVoiceCount() == 1,
      );
      if (arguments.contains('--measure')) await phase('playing', 120);
      audio.pauseSounds();
      await until(() => !engine.isInitialized);
      if (arguments.contains('--measure')) await phase('post-stop-idle', 60);
      check('idle engine and sources released', !engine.isInitialized);
      await app.resetTimer();
      await app.updateSettings(const TimerSettings(focusMinutes: 1));
      await app.toggleTimer();
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      final deadline = app.timer.snapshot().elapsedDeadlineMicros!;
      final reading = await clock.sample();
      final untilBlock = deadline - reading.elapsed.inMicroseconds - 700000;
      if (untilBlock > 0) {
        await Future<void>.delayed(Duration(microseconds: untilBlock));
      }
      sleep(const Duration(milliseconds: 1500));
      final stopOffset = library
          .lookupFunction<Int64 Function(), int Function()>(
            'pomaAudioTestStopOffset',
          )();
      report['nativeGuardRetirementAttemptOffsetMicros'] = stopOffset;
      check(
        'native deadline retirement within 250 ms',
        stopOffset >= 0 && stopOffset <= 250000,
      );
      check(
        'real renderer silent across deadline while Dart blocked',
        engine.getActiveVoiceCount() == 0,
      );
      await app.reconcile();
      check(
        'real timer advances once to ready break',
        app.timer.phase == FocusPhase.shortBreak &&
            app.timer.status == RunStatus.ready &&
            app.sessions.length == 1,
      );
      // Normal Quit retains a running timer, but a cold process must not autoplay.
      await app.selectPhase(FocusPhase.focus);
      await app.toggleTimer();
      await until(() => audio.state.transport == FocusAudioTransport.playing);
      audio.beginQuit();
      await app.flush();
      await audio.close();
      check('Quit cleanup releases renderer', !engine.isInitialized);
      report['passed'] = true;
      await File('${directory.path}/session2-runtime.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        flush: true,
      );
      await desktop.quit();
    } catch (error) {
      report['passed'] = false;
      report['failure'] = error.toString();
      await audio.close();
      await File('${directory.path}/session2-runtime.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(report),
        flush: true,
      );
      await host.exit();
    }
  }

  if (arguments.contains('--verify-cold')) {
    try {
      check(
        'cold persisted enabled selection',
        app.focusSoundPreferences.sound != FocusSoundId.off,
      );
      check(
        'cold recovered running Focus',
        app.timer.phase == FocusPhase.focus &&
            app.timer.status == RunStatus.running,
      );
      check('cold launch has no audio engine', !SoLoud.instance.isInitialized);
      await app.deleteAllLocalData();
      check(
        'real reset clears saved selection',
        app.focusSoundPreferences.sound == FocusSoundId.off,
      );
      report['passed'] = true;
    } catch (error) {
      report['passed'] = false;
      report['failure'] = error.toString();
    }
    await File('${directory.path}/session2-cold.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    await desktop.quit();
    return;
  }

  if (arguments.contains('--self-test')) {
    desktop.confirmDiscard = () async => false;
    unawaited(run());
  } else {
    runApp(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Session 2 developer audio review')),
          body: AnimatedBuilder(
            animation: audio,
            builder: (context, _) => ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  '${audio.preferences.sound.name}: ${audio.state.transport.name} ${audio.state.message ?? ''}',
                ),
                for (final sound in FocusSoundId.values)
                  ListTile(
                    title: Text(sound.name),
                    onTap: () => audio.selectSound(sound),
                    trailing: sound == FocusSoundId.off
                        ? null
                        : TextButton(
                            onPressed: () => audio.preview(sound),
                            child: const Text('Preview 10 seconds'),
                          ),
                  ),
                Slider(
                  value: audio.preferences.volume,
                  onChanged: audio.setVolume,
                  onChangeEnd: (v) => audio.setVolume(v, commit: true),
                ),
                SwitchListTile(
                  title: const Text('Mute'),
                  value: audio.preferences.muted,
                  onChanged: audio.setMuted,
                ),
                FilledButton(
                  onPressed: () => app.toggleTimer(),
                  child: const Text('Timer start / pause / resume'),
                ),
                TextButton(
                  onPressed: audio.playSounds,
                  child: const Text('Play sounds'),
                ),
                TextButton(
                  onPressed: audio.pauseSounds,
                  child: const Text('Stop sounds'),
                ),
                TextButton(
                  onPressed: audio.retry,
                  child: const Text('Retry sound'),
                ),
                TextButton(
                  onPressed: run,
                  child: const Text(
                    'Run isolated qualification (exits when finished)',
                  ),
                ),
                TextButton(onPressed: desktop.quit, child: const Text('Quit')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
