import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/focus_audio_ports.dart';
import 'package:poma/domain/focus_sound_preferences.dart';
import 'package:poma/domain/models.dart';
import 'focus_audio_support.dart';
import 'alert_support.dart';

void main() {
  test(
    'mobile audio expiry preserves the independent pending completion alert',
    () async {
      final alerts = FakeAlerts();
      final f = AudioFixture(background: true, alerts: alerts);
      await f.initialize();
      addTearDown(f.close);
      await f.app.setCompletionAlerts(true);
      await f.start();
      await f.app.setForeground(false);
      final request = alerts.pending.values.single;

      f.scheduler.elapse(const Duration(minutes: 26));
      await f.settle();
      expect(f.player.active, isNull);
      // The OS receiver must still be allowed to deliver its registered alert.
      // An audio callback cannot acknowledge/cancel that separate request.
      expect(alerts.pending.values.single.runId, request.runId);
      expect(alerts.pending.values.single.generation, request.generation);

      await f.app.setForeground(true);
      await f.settle();
      expect(f.app.timer.status, RunStatus.ready);
      expect(f.app.sessions, hasLength(1));
      await f.app.reconcile();
      expect(f.app.sessions, hasLength(1));
    },
  );
  test(
    'mobile background keeps continuous audio and disables the UI ticker',
    () async {
      final f = AudioFixture(background: true);
      await f.initialize();
      await f.start();
      final starts = f.player.starts.length;
      await f.app.setForeground(false);
      await f.settle();
      expect(f.player.active, isNotNull);
      expect(f.player.starts.length, starts);
      f.scheduler.elapse(const Duration(minutes: 26));
      await f.settle();
      expect(f.player.active, isNull);
      await f.app.setForeground(true);
      await f.settle();
      expect(f.app.timer.status, RunStatus.ready);
      expect(f.app.sessions, hasLength(1));
      await f.close();
    },
  );
  test(
    'background dismissal restores only the eligible Focus stream',
    () async {
      final f = AudioFixture(background: true);
      await f.initialize();
      await f.start();
      await f.audio.preview(FocusSoundId.waterfall);
      await f.settle();
      await f.app.setForeground(false);
      await f.settle();
      expect(f.audio.state.previewSound, isNull);
      expect(f.player.active?.sound, FocusSoundId.oceanWaves);
      await f.close();
    },
  );
  test(
    'media pause/play affect audio without timer commands or history',
    () async {
      final f = AudioFixture(background: true);
      await f.initialize();
      await f.start();
      final player = f.player as FakeBackgroundAudioPlayback;
      final revision = f.app.timer.revision;
      player.media(FocusAudioMediaAction.pause);
      await f.settle();
      expect(player.active, isNull);
      expect(f.app.timer.revision, revision);
      expect(f.app.timer.status, RunStatus.running);
      player.media(FocusAudioMediaAction.play);
      await f.settle();
      expect(player.active, isNotNull);
      expect(f.app.sessions, isEmpty);
      expect(f.app.timer.revision, revision);
      await f.close();
    },
  );
  test(
    'stale media actions cannot cancel replacement or override mute',
    () async {
      final f = AudioFixture(background: true);
      await f.initialize();
      await f.start();
      final player = f.player as FakeBackgroundAudioPlayback;
      final old = player.generation;
      f.audio.selectSound(FocusSoundId.forestBirds);
      await f.settle();
      player.media(FocusAudioMediaAction.pause, generation: old);
      await f.settle();
      expect(player.active?.sound, FocusSoundId.forestBirds);
      f.audio.setMuted(true);
      await f.settle();
      player.media(FocusAudioMediaAction.play);
      await f.settle();
      expect(player.active, isNull);
      expect(f.audio.preferences.muted, isTrue);
      await f.close();
    },
  );
  test('mobile interruption end stays silent until explicit Play', () async {
    final f = AudioFixture(background: true);
    await f.initialize();
    await f.start();
    final player = f.player as FakeBackgroundAudioPlayback;
    final interrupted = player.generation;
    player.onEvent!(
      FocusAudioPlaybackEvent(FocusAudioEventKind.interrupted, interrupted),
    );
    await f.settle();
    player.onEvent!(
      FocusAudioPlaybackEvent(
        FocusAudioEventKind.interruptionEnded,
        interrupted,
      ),
    );
    await f.settle();
    expect(player.active, isNull);
    player.media(FocusAudioMediaAction.play);
    await f.settle();
    expect(player.active, isNotNull);
    await f.close();
  });
  test(
    'expired and paused timer media Play cannot start another phase',
    () async {
      final f = AudioFixture(background: true);
      await f.initialize();
      await f.start();
      final player = f.player as FakeBackgroundAudioPlayback;
      await f.app.toggleTimer();
      await f.settle();
      player.media(FocusAudioMediaAction.play);
      await f.settle();
      expect(f.app.timer.status, RunStatus.paused);
      expect(player.active, isNull);
      await f.app.toggleTimer();
      await f.settle();
      f.clock.advance(const Duration(minutes: 26));
      player.media(FocusAudioMediaAction.play);
      await f.settle();
      expect(player.active, isNull);
      expect(f.app.timer.status, RunStatus.ready);
      expect(f.app.sessions, hasLength(1));
      await f.close();
    },
  );
  test(
    'ordinary refreshes do not publish native session messages every tick',
    () async {
      final f = AudioFixture(background: true);
      await f.initialize();
      await f.start();
      final player = f.player as FakeBackgroundAudioPlayback;
      final messages = player.sessions.length;
      for (var i = 0; i < 5; i++) {
        f.clock.advance(const Duration(seconds: 1));
        await f.app.refresh();
      }
      expect(player.sessions.length, messages);
      await f.close();
    },
  );
}
