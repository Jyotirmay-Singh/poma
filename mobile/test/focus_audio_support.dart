import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/focus_audio_coordinator.dart';
import 'package:poma/application/focus_audio_ports.dart';
import 'package:poma/application/local_reset_participant.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/domain/focus_sound_preferences.dart';
import 'package:poma/domain/models.dart';
import 'support.dart';

class _Job implements FocusAudioCancellation {
  _Job(this.at, this.callback);
  final int at;
  final void Function() callback;
  bool cancelled = false;
  @override
  void cancel() {
    cancelled = true;
  }
}

class FakeAudioScheduler implements FocusAudioScheduler {
  FakeAudioScheduler(this.clock);
  final FakeClock clock;
  final List<_Job> _jobs = [];
  @override
  FocusAudioCancellation after(Duration delay, void Function() callback) {
    final job = _Job(
      clock.elapsed.inMicroseconds + delay.inMicroseconds,
      callback,
    );
    _jobs.add(job);
    return job;
  }

  void elapse(Duration duration) {
    clock.advance(duration);
    final due =
        _jobs
            .where((j) => !j.cancelled && j.at <= clock.elapsed.inMicroseconds)
            .toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    for (final job in due) {
      if (!job.cancelled) {
        job.cancelled = true;
        job.callback();
      }
    }
    _jobs.removeWhere((j) => j.cancelled);
  }
}

class FakePrepared implements PreparedFocusAudio {
  FakePrepared(this.sound);
  final FocusSoundId sound;
  bool released = false;
}

class FakeFocusAudioPlayback implements FocusAudioPlaybackPort {
  @override
  FocusAudioAvailability availability = FocusAudioAvailability.available;
  FakeFocusAudioPlayback(this.scheduler);
  final FakeAudioScheduler scheduler;
  @override
  void Function(FocusAudioPlaybackEvent)? onEvent;
  final List<FakePrepared> prepared = [];
  final List<FocusSoundId> starts = [];
  final List<FocusAudioLease> leases = [];
  final List<Completer<PreparedFocusAudio>> pending = [];
  FakePrepared? active;
  bool holdLoads = false, failLoads = false, closed = false;
  bool expireOnStart = false;
  double gain = 0;
  int generation = 0, revocations = 0;
  FocusAudioCancellation? cap;
  @override
  Future<PreparedFocusAudio> prepare(
    FocusSoundId sound, {
    FocusAudioPreparation? request,
  }) async {
    if (failLoads) throw StateError('Missing asset');
    final resource = FakePrepared(sound);
    prepared.add(resource);
    if (holdLoads) {
      final completer = Completer<PreparedFocusAudio>();
      pending.add(completer);
      return completer.future;
    }
    return resource;
  }

  void completeLoad([int index = 0]) {
    pending[index].complete(prepared[index]);
  }

  @override
  Future<void> start(
    PreparedFocusAudio resource,
    FocusAudioLease lease,
    int generation,
    double volume,
  ) async {
    if (expireOnStart) {
      expireOnStart = false;
      scheduler.clock.advance(
        Duration(
          microseconds:
              lease.deadlineMicros - scheduler.clock.elapsed.inMicroseconds,
        ),
      );
      throw const FocusAudioLeaseExpired();
    }
    if (closed ||
        (resource as FakePrepared).released ||
        active != null ||
        scheduler.clock.elapsed.inMicroseconds >= lease.deadlineMicros) {
      throw StateError('Invalid output');
    }
    active = resource;
    gain = volume;
    this.generation = generation;
    starts.add(resource.sound);
    leases.add(lease);
    cap = scheduler.after(
      Duration(
        microseconds:
            lease.deadlineMicros - scheduler.clock.elapsed.inMicroseconds,
      ),
      () {
        active = null;
        gain = 0;
        onEvent?.call(
          FocusAudioPlaybackEvent(FocusAudioEventKind.expired, generation),
        );
      },
    );
  }

  @override
  void revoke(int generation, {bool fade = false}) {
    this.generation = generation;
    revocations++;
    active = null;
    gain = 0;
    cap?.cancel();
  }

  @override
  void setVolume(double volume) {
    gain = volume;
  }

  @override
  Future<void> release(PreparedFocusAudio source) async {
    if (identical(active, source)) throw StateError('Releasing audible source');
    (source as FakePrepared).released = true;
  }

  @override
  Future<void> close() async {
    closed = true;
    revoke(++generation);
  }
}

class AudioFixture {
  AudioFixture({SavedState? state, this.background = false, this.alerts})
    : repository = MemoryRepository(state);
  final bool background;
  final LocalAlerts? alerts;
  final FakeClock clock = FakeClock();
  final MemoryRepository repository;
  late final FakeAudioScheduler scheduler = FakeAudioScheduler(clock);
  late final FakeFocusAudioPlayback player = background
      ? FakeBackgroundAudioPlayback(scheduler)
      : FakeFocusAudioPlayback(scheduler);
  late final FocusAudioCoordinator audio = FocusAudioCoordinator(
    player,
    scheduler: scheduler,
  );
  late final AppController app;
  Future<void> initialize() async {
    app = await AppController.create(
      repository,
      clock: clock,
      alerts: alerts,
      focusAudio: audio,
      onFocusAudioSession: audio.onSession,
      resetParticipant: CompositeLocalResetParticipant([audio]),
    );
    audio.bind(
      preferences: app.focusSoundPreferences,
      save: app.updateFocusSoundPreferences,
      reconcile: () async {
        await app.reconcile();
      },
    );
  }

  Future<void> settle() async {
    await pumpEventQueue(times: 30);
  }

  Future<void> start([FocusSoundId sound = FocusSoundId.oceanWaves]) async {
    audio.selectSound(sound);
    await settle();
    await app.toggleTimer();
    await settle();
  }

  Future<void> close() async {
    await audio.close();
    app.dispose();
    await app.flush();
  }
}

class FakeBackgroundAudioPlayback extends FakeFocusAudioPlayback
    implements BackgroundFocusAudioPlayback {
  FakeBackgroundAudioPlayback(super.scheduler);
  @override
  void Function(FocusAudioMediaCommand)? onMediaCommand;
  final List<FocusAudioSessionEvent> sessions = [];
  @override
  void sessionChanged(FocusAudioSessionEvent event) => sessions.add(event);
  void media(FocusAudioMediaAction action, {int? generation, String? runId}) {
    final current = sessions.last.snapshot;
    onMediaCommand?.call(
      FocusAudioMediaCommand(
        action,
        generation ?? this.generation,
        runId ?? current.runId,
        current.segment,
      ),
    );
  }
}
