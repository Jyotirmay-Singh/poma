import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/focus_audio_ports.dart';
import 'package:poma/domain/focus_sound_preferences.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'focus_audio_support.dart';
import 'support.dart';

void main() {
  test('unavailable playback saves choices without preparing audio', () async {
    final f = AudioFixture();
    await f.initialize();
    addTearDown(f.close);
    f.player.availability = FocusAudioAvailability.unavailable;
    await f.start();
    expect(f.audio.state.availability, FocusAudioAvailability.unavailable);
    expect(f.player.prepared, isEmpty);
    expect(await f.audio.preview(FocusSoundId.tibetanBells), isNull);
    await f.app.flush();
    expect(f.repository.state.focusSounds!.sound, FocusSoundId.oceanWaves);
    expect(f.audio.state.canRetry, isFalse);
  });

  test(
    'failed preview retry returns the owned replacement dismissal token',
    () async {
      final f = AudioFixture();
      await f.initialize();
      addTearDown(f.close);
      f.player.failLoads = true;
      final original = await f.audio.preview(FocusSoundId.tibetanBells);
      await f.settle();
      expect(f.audio.state.canRetry, isTrue);
      f.player.failLoads = false;
      final replacement = await f.audio.retry();
      await f.settle();
      expect(replacement, isNotNull);
      expect(replacement, isNot(original));
      await f.audio.dismissPreview(replacement!);
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.audio.state.previewSound, isNull);
      expect(f.app.timer.status, RunStatus.ready);
    },
  );
  test(
    'older resume awaiting reconciliation cannot end a newer interruption',
    () async {
      final f = AudioFixture();
      await f.initialize();
      addTearDown(f.close);
      await f.start();
      final first = f.player.generation;
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(FocusAudioEventKind.interrupted, first),
      );
      await f.settle();
      final hold = Completer<void>();
      f.audio.bind(
        preferences: f.audio.preferences,
        save: f.app.updateFocusSoundPreferences,
        reconcile: () async {
          await hold.future;
          await f.app.reconcile();
        },
      );
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.interruptionEnded,
          first,
          mayResume: true,
        ),
      );
      await f.settle();
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.interrupted,
          f.player.generation,
        ),
      );
      hold.complete();
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.audio.state.interrupted, isTrue);
    },
  );
  testWidgets(
    'timed-out load is bounded and its late resource is released without output',
    (tester) async {
      final f = AudioFixture();
      await f.initialize();
      f.player.holdLoads = true;
      await f.app.toggleTimer();
      f.audio.selectSound(FocusSoundId.waterfall);
      await tester.pump();
      expect(f.player.pending, hasLength(1));
      await tester.pump(const Duration(seconds: 11));
      expect(f.audio.state.canRetry, isTrue);
      expect(f.player.active, isNull);
      f.player.completeLoad();
      await tester.pump();
      expect(f.player.prepared.single.released, isTrue);
      expect(f.player.starts, isEmpty);
      await f.close();
    },
  );
  testWidgets(
    'disposal during loading observes and releases the eventual resource',
    (tester) async {
      final f = AudioFixture();
      await f.initialize();
      f.player.holdLoads = true;
      await f.app.toggleTimer();
      f.audio.selectSound(FocusSoundId.waterfall);
      await tester.pump();
      final closing = f.audio.close();
      expect(f.player.active, isNull);
      f.player.completeLoad();
      await tester.pump();
      await closing;
      expect(f.player.prepared.single.released, isTrue);
      expect(f.player.starts, isEmpty);
      await f.close();
    },
  );
  test(
    'expiry between reconciliation and native activation is cancellation, not Retry',
    () async {
      final f = AudioFixture();
      await f.initialize();
      addTearDown(f.close);
      f.player.expireOnStart = true;
      await f.start();
      expect(f.player.active, isNull);
      expect(f.audio.state.canRetry, isFalse);
      expect(f.app.timer.phase, FocusPhase.shortBreak);
      expect(f.app.sessions, hasLength(1));
    },
  );
  test(
    'reset cancels staged keyboard volume and restores default sound preferences',
    () async {
      final f = AudioFixture();
      await f.initialize();
      addTearDown(f.close);
      await f.start();
      f.audio.setVolume(.72, keyboard: true);
      await f.app.deleteAllLocalData();
      f.scheduler.elapse(const Duration(seconds: 1));
      await f.settle();
      await f.app.flush();
      expect(f.player.active, isNull);
      expect(f.audio.preferences, const FocusSoundPreferences());
      expect(f.repository.state.focusSounds, isNull);
    },
  );
  test(
    'preview cap follows the real session deadline and never restores completed audio',
    () async {
      final f = AudioFixture(
        state: SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      await f.initialize();
      addTearDown(f.close);
      await f.start();
      f.scheduler.elapse(const Duration(seconds: 59));
      await f.app.reconcile();
      await f.audio.preview(FocusSoundId.waterfall);
      await f.settle();
      expect(
        f.player.leases.last.deadlineMicros,
        f.app.timer.snapshot().elapsedDeadlineMicros,
      );
      f.scheduler.elapse(const Duration(seconds: 1));
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.app.sessions, hasLength(1));
      expect(f.app.timer.phase, FocusPhase.shortBreak);
    },
  );
  test('late old load failure cannot fail or stop a newer selection', () async {
    final f = AudioFixture();
    await f.initialize();
    addTearDown(f.close);
    f.player.holdLoads = true;
    await f.app.toggleTimer();
    f.audio.selectSound(FocusSoundId.waterfall);
    await f.settle();
    f.audio.selectSound(FocusSoundId.forestBirds);
    await f.settle();
    f.player.holdLoads = false;
    f.player.pending.single.completeError(StateError('old load failed'));
    await f.settle();
    expect(f.player.active!.sound, FocusSoundId.forestBirds);
    expect(f.audio.state.canRetry, isFalse);
  });
  Future<AudioFixture> fixture({SavedState? state}) async {
    final f = AudioFixture(state: state);
    await f.initialize();
    addTearDown(f.close);
    return f;
  }

  test(
    'ready choice saves without loading; accepted Focus starts and repeated ticks do not restart',
    () async {
      final f = await fixture();
      expect(f.audio.preferences.sound, FocusSoundId.off);
      f.audio.selectSound(FocusSoundId.oceanWaves);
      await f.settle();
      expect(f.player.prepared, isEmpty);
      expect(f.repository.state.focusSounds!.sound, FocusSoundId.oceanWaves);
      await f.app.toggleTimer();
      await f.settle();
      expect(f.player.active!.sound, FocusSoundId.oceanWaves);
      final writes = f.repository.writes;
      for (var i = 0; i < 10; i++) {
        f.clock.advance(const Duration(seconds: 1));
        await f.app.reconcile();
      }
      await f.settle();
      expect(f.player.starts, [FocusSoundId.oceanWaves]);
      expect(f.repository.writes, writes);
    },
  );
  test(
    'pause and selection remain silent; resume uses current choice and new segment',
    () async {
      final f = await fixture();
      await f.start();
      final first = f.player.leases.last;
      await f.app.toggleTimer();
      await f.settle();
      expect(f.player.active, isNull);
      f.audio.selectSound(FocusSoundId.forestBirds);
      await f.settle();
      expect(f.player.active, isNull);
      await f.app.toggleTimer();
      await f.settle();
      expect(f.player.active!.sound, FocusSoundId.forestBirds);
      expect(f.player.leases.last.runId, first.runId);
      expect(f.player.leases.last.segment, greaterThan(first.segment!));
    },
  );
  test(
    'mute preserves exact gain and track changes never override mute or zero',
    () async {
      final f = await fixture();
      await f.start();
      f.audio.setVolume(.17, commit: true);
      f.audio.setMuted(true);
      f.audio.selectSound(FocusSoundId.waterfall);
      await f.settle();
      expect(f.player.active, isNull);
      f.audio.setMuted(false);
      await f.settle();
      expect(f.player.gain, .17);
      f.audio.setVolume(0, commit: true);
      f.audio.setMuted(true);
      f.audio.setMuted(false);
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.audio.preferences.volume, 0);
      f.audio.setVolume(.12, commit: true);
      await f.settle();
      expect(f.player.gain, .12);
    },
  );
  test(
    'strict timer blocks pause/reset while music controls remain independent',
    () async {
      final f = await fixture(
        state: SavedState(settings: const TimerSettings(strictMode: true)),
      );
      await f.start();
      final run = f.app.timer.runId;
      expect(
        (await f.app.resetTimer()).transition.outcome,
        TimerCommandOutcome.blocked,
      );
      expect(
        (await f.app.toggleTimer()).transition.outcome,
        TimerCommandOutcome.blocked,
      );
      f.audio.setMuted(true);
      expect(f.player.active, isNull);
      f.audio.selectSound(FocusSoundId.tibetanBells);
      f.audio.setMuted(false);
      await f.settle();
      expect(f.player.active!.sound, FocusSoundId.tibetanBells);
      expect(f.app.timer.runId, run);
      expect(f.app.sessions, isEmpty);
    },
  );
  test('cold recovered Focus is silent until explicit sound action', () async {
    final clock = FakeClock();
    final timer = TimerEngine(
      settings: const TimerSettings(),
      now: clock.reading,
    )..apply(TimerAction.start, clock.reading);
    final f = await fixture(
      state: SavedState(
        timer: timer.snapshot(),
        focusSounds: const FocusSoundPreferences(sound: FocusSoundId.waterfall),
      ),
    );
    await f.settle();
    expect(f.player.prepared, isEmpty);
    await f.app.reconcile();
    await f.settle();
    expect(f.player.active, isNull);
    await f.audio.playSounds();
    await f.settle();
    expect(f.player.active!.sound, FocusSoundId.waterfall);
  });
  test(
    'cold overdue Focus completes once and never plays its successor',
    () async {
      final clock = FakeClock();
      final timer = TimerEngine(
        settings: const TimerSettings(),
        now: clock.reading,
      )..apply(TimerAction.start, clock.reading);
      final f = AudioFixture(
        state: SavedState(
          timer: timer.snapshot(),
          focusSounds: const FocusSoundPreferences(
            sound: FocusSoundId.waterfall,
          ),
        ),
      );
      f.clock.advance(const Duration(hours: 1));
      await f.initialize();
      addTearDown(f.close);
      expect(f.app.timer.phase, FocusPhase.shortBreak);
      expect(f.app.sessions, hasLength(1));
      await f.audio.playSounds();
      await f.settle();
      expect(f.player.prepared, isEmpty);
    },
  );
  test(
    'preview is temporary, does not select or earn time, and restores same run',
    () async {
      final f = await fixture();
      await f.start();
      await f.audio.preview(FocusSoundId.forestBirds);
      await f.settle();
      expect(f.player.active!.sound, FocusSoundId.forestBirds);
      expect(f.audio.preferences.sound, FocusSoundId.oceanWaves);
      f.scheduler.elapse(const Duration(seconds: 10));
      await f.settle();
      expect(f.player.active!.sound, FocusSoundId.oceanWaves);
      expect(f.app.sessions, isEmpty);
    },
  );
  for (final phase in FocusPhase.values) {
    for (final muted in [false, true]) {
      test(
        'explicit previews audition every sound in ${phase.name}, muted=$muted',
        () async {
          final saved = FocusSoundPreferences(
            sound: FocusSoundId.oceanWaves,
            volume: .21,
            muted: muted,
          );
          final f = await fixture(state: SavedState(focusSounds: saved));
          await f.app.selectPhase(phase);
          await f.settle();
          final revision = f.app.timer.revision;
          for (final sound in FocusSoundId.values.skip(1)) {
            final token = await f.audio.preview(sound);
            await f.settle();
            expect(token, isNotNull);
            expect(f.player.active?.sound, sound);
            expect(f.player.gain, saved.volume);
            expect(f.player.leases.last.preview, isTrue);
            expect(
              f.player.leases.last.deadlineMicros -
                  f.clock.elapsed.inMicroseconds,
              10000000,
            );
            expect(f.audio.preferences, saved);
            expect(f.app.timer.phase, phase);
            expect(f.app.timer.status, RunStatus.ready);
            expect(f.app.timer.revision, revision);
            expect(f.app.sessions, isEmpty);
            await f.audio.dismissPreview(token!);
            await f.settle();
            expect(f.player.active, isNull);
          }
          await f.app.flush();
          expect(f.repository.state.focusSounds, saved);
        },
      );
    }
  }

  test(
    'explicit previews follow volume changes and expire on a muted break',
    () async {
      final f = await fixture(
        state: SavedState(
          focusSounds: const FocusSoundPreferences(
            sound: FocusSoundId.calmingRain,
            muted: true,
          ),
        ),
      );
      await f.app.selectPhase(FocusPhase.shortBreak);
      final token = await f.audio.preview(FocusSoundId.waterfall);
      await f.settle();
      expect(token, isNotNull);
      f.audio.setVolume(.12);
      expect(f.player.gain, .12);
      f.audio.setVolume(0);
      await f.settle();
      expect(f.player.active, isNull);
      expect(await f.audio.preview(FocusSoundId.waterfall), isNull);
      f.audio.setVolume(.2);
      await f.settle();
      expect(f.player.active, isNull);
      final replacement = await f.audio.preview(FocusSoundId.omChanting);
      await f.settle();
      expect(replacement, isNotNull);
      f.scheduler.elapse(const Duration(seconds: 10));
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.audio.state.previewSound, isNull);
      expect(f.audio.preferences.muted, isTrue);
      expect(f.app.timer.phase, FocusPhase.shortBreak);
      expect(f.app.timer.status, RunStatus.ready);
      expect(f.app.sessions, isEmpty);
    },
  );

  test(
    'ready, paused and break previews expire without starting a timer',
    () async {
      final f = await fixture();
      final token = await f.audio.preview(FocusSoundId.waterfall);
      await f.settle();
      expect(token, isNotNull);
      expect(f.player.active, isNotNull);
      f.scheduler.elapse(const Duration(seconds: 10));
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.app.timer.status, RunStatus.ready);
      await f.start();
      await f.app.toggleTimer();
      await f.audio.preview(FocusSoundId.forestBirds);
      await f.settle();
      expect(f.player.active, isNotNull);
      expect(f.app.timer.status, RunStatus.paused);
      await f.app.skipTimer();
      await f.settle();
      expect(await f.audio.preview(FocusSoundId.waterfall), isNotNull);
      await f.settle();
      expect(f.player.active?.sound, FocusSoundId.waterfall);
      f.scheduler.elapse(const Duration(seconds: 10));
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.app.timer.phase, FocusPhase.shortBreak);
      expect(f.app.timer.status, RunStatus.ready);
    },
  );
  test(
    'mute/reset/new session and stale dismissal cannot revive preview restoration',
    () async {
      final f = await fixture();
      await f.start();
      final token = (await f.audio.preview(FocusSoundId.waterfall))!;
      await f.settle();
      f.audio.setMuted(true);
      await f.audio.dismissPreview(token);
      await f.settle();
      expect(f.player.active, isNull);
      f.audio.setMuted(false);
      await f.settle();
      final token2 = (await f.audio.preview(FocusSoundId.forestBirds))!;
      await f.app.resetTimer();
      await f.audio.dismissPreview(token2);
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.app.timer.status, RunStatus.ready);
    },
  );
  test(
    'A to B to Off during load never produces late output and releases stale source',
    () async {
      final f = await fixture();
      f.player.holdLoads = true;
      await f.app.toggleTimer();
      f.audio.selectSound(FocusSoundId.waterfall);
      await f.settle();
      f.audio.selectSound(FocusSoundId.forestBirds);
      f.audio.selectSound(FocusSoundId.off);
      f.player.completeLoad();
      await f.settle();
      expect(f.player.starts, isEmpty);
      expect(f.player.prepared.single.released, isTrue);
    },
  );
  for (final end in ['reset', 'completion', 'full reset']) {
    test('$end during loading cancels playback and previews', () async {
      final f = await fixture();
      f.player.holdLoads = true;
      await f.app.toggleTimer();
      f.audio.selectSound(FocusSoundId.waterfall);
      await f.settle();
      Future<Object?>? resetting;
      if (end == 'reset') {
        await f.app.resetTimer();
      } else if (end == 'completion') {
        f.clock.advance(const Duration(hours: 1));
        await f.app.reconcile();
      } else {
        resetting = f.app.deleteAllLocalData();
      }
      f.player.completeLoad();
      await f.settle();
      await resetting;
      expect(f.player.starts, isEmpty);
      expect(f.player.prepared.single.released, isTrue);
    });
  }
  test(
    'native deadline stops hidden playback before persistence and ignores late callback',
    () async {
      final f = await fixture(
        state: SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      await f.start();
      final generation = f.player.generation;
      f.repository.failWrites = true;
      f.scheduler.elapse(const Duration(minutes: 1));
      expect(f.player.active, isNull);
      await f.settle();
      expect(f.app.timer.phase, FocusPhase.shortBreak);
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.interruptionEnded,
          generation,
          mayResume: true,
        ),
      );
      await f.settle();
      expect(f.player.active, isNull);
    },
  );
  test(
    'temporary interruption may resume same run but mute invalidates its old callback',
    () async {
      final f = await fixture();
      await f.start();
      final generation = f.player.generation;
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(FocusAudioEventKind.interrupted, generation),
      );
      await f.settle();
      expect(f.player.active, isNull);
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.interruptionEnded,
          generation,
          mayResume: true,
        ),
      );
      await f.settle();
      expect(f.player.active, isNotNull);
      final next = f.player.generation;
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(FocusAudioEventKind.interrupted, next),
      );
      f.audio.setMuted(true);
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.interruptionEnded,
          next,
          mayResume: true,
        ),
      );
      await f.settle();
      expect(f.player.active, isNull);
    },
  );
  test(
    'route loss requires explicit Play; media pause and volume do not earn time',
    () async {
      final f = await fixture();
      await f.start();
      f.player.onEvent?.call(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.routeLost,
          f.player.generation,
        ),
      );
      await f.settle();
      f.audio.setVolume(.2);
      await f.settle();
      expect(f.player.active, isNull);
      await f.audio.playSounds();
      await f.settle();
      expect(f.player.active, isNotNull);
      f.audio.pauseSounds();
      f.audio.setVolume(.4);
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.app.timer.status, RunStatus.running);
      expect(f.app.sessions, isEmpty);
    },
  );
  test(
    'failed load exposes retry without affecting timer; clock failure also stops',
    () async {
      final f = await fixture();
      f.player.failLoads = true;
      await f.start();
      expect(f.audio.state.canRetry, isTrue);
      expect(f.app.timer.status, RunStatus.running);
      f.player.failLoads = false;
      await f.audio.retry();
      await f.settle();
      expect(f.player.active, isNotNull);
      f.clock.failReads = true;
      await f.app.reconcile();
      await f.settle();
      expect(f.player.active, isNull);
      f.clock.failReads = false;
      await f.app.reconcile();
      await f.settle();
      expect(f.player.active, isNull);
    },
  );
  test(
    'slider writes only final interaction value and keyboard debounce preserves final value',
    () async {
      final f = await fixture();
      final writes = f.repository.writes;
      for (var i = 0; i < 100; i++) {
        f.audio.setVolume(i / 100);
      }
      await f.settle();
      expect(f.repository.writes, writes);
      f.audio.setVolume(.81, commit: true);
      await f.app.flush();
      expect(f.repository.writes, writes + 1);
      expect(f.repository.state.focusSounds!.volume, .81);
      f.audio.setVolume(.5, keyboard: true);
      f.audio.setVolume(.42, keyboard: true);
      f.scheduler.elapse(const Duration(milliseconds: 300));
      await f.app.flush();
      expect(f.repository.state.focusSounds!.volume, .42);
    },
  );
  test(
    'Quit is immediately silent; cancelling it never resumes; disposal rejects callbacks',
    () async {
      final f = await fixture();
      await f.start();
      final callback = f.player.onEvent!;
      final generation = f.player.generation;
      f.audio.setVolume(.23);
      f.audio.beginQuit();
      expect(f.player.active, isNull);
      f.audio.cancelQuit();
      await f.settle();
      expect(f.player.active, isNull);
      await f.app.flush();
      expect(f.repository.state.focusSounds!.volume, .23);
      await f.audio.close();
      callback(
        FocusAudioPlaybackEvent(
          FocusAudioEventKind.resumed,
          generation,
          mayResume: true,
        ),
      );
      await f.settle();
      expect(f.player.active, isNull);
      expect(f.player.closed, isTrue);
    },
  );
}
