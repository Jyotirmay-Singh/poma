// Isolated developer entry: production widgets and adapter, fictional storage.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = NativeWindowsHost();
  final isolated = await host.channel.invokeMethod<bool>(
    'reviewAudioEnvironment',
  );
  final environment = await host.initialize();
  if (isolated != true ||
      environment.packaged ||
      !environment.dataDirectory.endsWith('fictional-review-profile')) {
    throw StateError('Isolated unpackaged Session 3 review required');
  }
  final repository = await host.repository(environment);
  final audio = FocusAudioCoordinator(SoLoudFocusAudioPlayback());
  final app = await AppController.create(
    repository,
    clock: NativeTimerClock(),
    onFocusAudioSession: audio.onSession,
    focusAudio: audio,
    suspendAudioInBackground: false,
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
  final root = GlobalKey();
  runApp(
    RepaintBoundary(
      key: root,
      child: PomaApp(controller: app, desktop: desktop),
    ),
  );
  final report = <String, Object?>{
    'kind': 'Isolated Windows production UI and real adapter',
    'listening': 'Not performed',
    'physicalAcceptance': 'Pending',
    'checks': <String>[],
    'captures': <String>[],
  };
  final directory = Directory(environment.dataDirectory);
  Future<void> until(bool Function() predicate) async {
    final end = DateTime.now().add(const Duration(seconds: 15));
    while (!predicate()) {
      if (DateTime.now().isAfter(end)) throw StateError('Review timeout');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  void check(String label, bool condition) {
    if (!condition) throw StateError(label);
    (report['checks'] as List<String>).add(label);
  }

  TextButton button(String key) {
    TextButton? found;
    void visit(Element e) {
      final w = e.widget;
      if (w is TextButton && w.key == Key(key)) found = w;
      e.visitChildElements(visit);
    }

    visit(root.currentContext! as Element);
    return found ?? (throw StateError('Missing UI action $key'));
  }

  Future<void> capture(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    (report['captures'] as List<String>).add('$name.png');
    report['captureSize'] = {
      'width': boundary.size.width,
      'height': boundary.size.height,
      'devicePixelRatio': View.of(root.currentContext!).devicePixelRatio,
      'renderScale': 1,
      'fonts': 'Bundled production Sora and Source Sans 3',
    };
  }

  try {
    await app.deleteAllLocalData();
    app.addTask('Read a fictional chapter');
    await app.flush();
    app.selectTask(app.tasks.first.id);
    await app.updateSettings(const TimerSettings(appearance: 'dark'));
    audio.selectSound(FocusSoundId.oceanWaves);
    audio.setVolume(.12, commit: true);
    await app.toggleTimer();
    await until(() => audio.state.transport == FocusAudioTransport.playing);
    await Future<void>.delayed(const Duration(seconds: 4));
    check(
      'real selected sound starts exactly one voice',
      SoLoud.instance.getActiveVoiceCount() == 1,
    );
    await capture('windows-playing');
    button('focus-sounds-open').onPressed!();
    await Future<void>.delayed(const Duration(seconds: 1));
    await capture('windows-chooser');
    button('sound-preview-tibetanBells').onPressed!();
    await until(
      () =>
          audio.state.previewSound == FocusSoundId.tibetanBells &&
          audio.state.transport == FocusAudioTransport.playing,
    );
    check(
      'UI preview retains selected ocean',
      audio.preferences.sound == FocusSoundId.oceanWaves,
    );
    check(
      'UI preview uses one stream',
      SoLoud.instance.getActiveVoiceCount() == 1,
    );
    await capture('windows-preview');
    button('sound-close').onPressed!();
    await until(
      () =>
          audio.state.previewSound == null &&
          audio.state.transport == FocusAudioTransport.playing,
    );
    check(
      'chooser dismissal restores continuous Focus',
      app.timer.status == RunStatus.running,
    );
    button('sound-compact-mute').onPressed!();
    await until(() => audio.state.transport == FocusAudioTransport.stopped);
    check(
      'UI mute immediately revokes output',
      SoLoud.instance.getActiveVoiceCount() == 0,
    );
    await capture('windows-muted');
    report['passed'] = true;
  } catch (error, stack) {
    report['passed'] = false;
    report['error'] = error.toString();
    report['stack'] = stack.toString();
  } finally {
    await File('${directory.path}/session3-runtime.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
      flush: true,
    );
    await desktop.quit();
  }
}
