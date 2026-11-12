import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/focus_audio_ports.dart';
import 'package:poma/domain/focus_sound_preferences.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'desktop_test.dart' show FakeShell, environment;
import 'focus_audio_support.dart';
import 'refinement_test.dart' show fullyVisibleText;
import 'contrast_support.dart';

const captureDirectory = String.fromEnvironment('POMA_SOUND_CAPTURES');
final evidence = <Map<String, Object?>>[];
DesktopController? mountedDesktop;

Future<void> frames(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

Future<void> tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await frames(tester);
}

Future<void> capture(
  WidgetTester tester,
  String name,
  Map<String, Object?> metadata,
) async {
  if (captureDirectory.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('sound-capture')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$captureDirectory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  evidence.add({
    'file': '$name.png',
    'backend': 'FakeFocusAudioPlayback through production coordinator',
    'fonts': 'Bundled Sora / Source Sans 3',
    'physicalDevice': false,
    'width': tester.view.physicalSize.width,
    'height': tester.view.physicalSize.height,
    'textScale': tester.platformDispatcher.textScaleFactor,
    'safeInsets': 24,
    'reducedMotion': true,
    ...metadata,
  });
}

void main() {
  tearDownAll(() async {
    if (captureDirectory.isNotEmpty) {
      await File(
        '$captureDirectory/screenshots.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
    }
  });
  Future<AudioFixture> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool desktop = false,
    bool highContrast = false,
    String appearance = 'light',
    FocusSoundPreferences preferences = const FocusSoundPreferences(),
    bool strict = false,
    bool unavailable = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(
          disableAnimations: true,
          highContrast: highContrast,
        );
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final f = AudioFixture(
      state: SavedState(
        settings: TimerSettings(appearance: appearance, strictMode: strict),
        focusSounds: preferences,
        tasks: const [
          FocusTask(
            id: 'fiction',
            title:
                'Read a fictional chapter and make thoughtful notes before reviewing the main ideas with a longer task title.',
          ),
        ],
        selectedTaskId: 'fiction',
      ),
    );
    await f.initialize();
    if (unavailable) f.player.availability = FocusAudioAvailability.unavailable;
    DesktopController? shell;
    if (desktop) {
      shell = DesktopController(f.app, FakeShell(), environment);
      await shell.initialize();
      mountedDesktop = shell;
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      if (identical(mountedDesktop, shell)) {
        shell?.dispose();
        mountedDesktop = null;
      }
      f.audio.selectSound(FocusSoundId.off);
      for (var i = 0; i < f.player.pending.length; i++) {
        if (!f.player.pending[i].isCompleted) f.player.completeLoad(i);
      }
      await frames(tester);
      final closing = f.audio.close();
      await frames(tester);
      await closing;
      f.app.dispose();
      final flushing = f.app.flush();
      await frames(tester);
      await flushing;
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('sound-capture'),
        child: PomaApp(controller: f.app, desktop: shell),
      ),
    );
    await frames(tester);
    return f;
  }

  testWidgets(
    'ready selection saves quietly; preview remains distinct and Escape restores focus',
    (tester) async {
      final f = await mount(tester);
      final revision = f.app.timer.revision;
      await tap(tester, 'focus-sounds-open');
      await tap(tester, 'sound-select-oceanWaves');
      expect(f.audio.preferences.sound, FocusSoundId.oceanWaves);
      expect(f.player.prepared, isEmpty);
      await tap(tester, 'sound-preview-tibetanBells');
      expect(f.audio.state.previewSound, FocusSoundId.tibetanBells);
      expect(f.audio.preferences.sound, FocusSoundId.oceanWaves);
      expect(f.app.timer.revision, revision);
      expect(f.repository.state.sessions, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
      expect(f.audio.state.previewSound, isNull);
      expect(f.player.active, isNull);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('focus-sounds-open')))
            .focusNode!
            .hasFocus,
        isTrue,
      );
    },
  );

  for (final sound in [FocusSoundId.calmingRain, FocusSoundId.omChanting]) {
    testWidgets(
      '${sound.name} can be selected and previewed from the chooser',
      (tester) async {
        final f = await mount(tester);
        final revision = f.app.timer.revision;
        await tap(tester, 'focus-sounds-open');
        await tap(tester, 'sound-select-${sound.name}');
        expect(f.audio.preferences.sound, sound);
        expect(f.player.prepared, isEmpty);
        await f.app.flush();
        expect(f.repository.state.focusSounds!.sound, sound);
        await tap(tester, 'sound-preview-${sound.name}');
        expect(f.audio.state.previewSound, sound);
        expect(f.player.active?.sound, sound);
        expect(f.app.timer.revision, revision);
        expect(f.repository.state.sessions, isEmpty);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await frames(tester);
        expect(f.audio.state.previewSound, isNull);
        expect(f.player.active, isNull);
        expect(f.audio.preferences.sound, sound);
      },
    );
  }

  testWidgets(
    'strict timer stays locked while real sound mute and pause work',
    (tester) async {
      final f = await mount(tester, strict: true);
      f.audio.selectSound(FocusSoundId.oceanWaves);
      await frames(tester);
      await f.app.toggleTimer();
      await frames(tester);
      expect(f.app.timer.controlsLocked, isTrue);
      final revision = f.app.timer.revision;
      await tap(tester, 'sound-compact-mute');
      expect(f.player.active, isNull);
      await tap(tester, 'sound-compact-mute');
      expect(f.player.active, isNotNull);
      await tap(tester, 'focus-sounds-open');
      await tap(tester, 'sound-playback');
      expect(f.player.active, isNull);
      expect(f.app.timer.revision, revision);
      expect(f.app.timer.status, RunStatus.running);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('timer-toggle')))
            .onPressed,
        isNull,
      );
    },
  );
  for (final desktop in [false, true]) {
    testWidgets('explicit previews work on a muted break, desktop=$desktop', (
      tester,
    ) async {
      const saved = FocusSoundPreferences(
        sound: FocusSoundId.calmingRain,
        volume: .23,
        muted: true,
      );
      final f = await mount(tester, desktop: desktop, preferences: saved);
      try {
        await f.app.selectPhase(FocusPhase.shortBreak);
        await frames(tester);
        final revision = f.app.timer.revision;
        await tap(tester, 'focus-sounds-open');
        for (final sound in FocusSoundId.values.skip(1)) {
          final key = 'sound-preview-${sound.name}';
          expect(
            tester.widget<TextButton>(find.byKey(Key(key))).onPressed,
            isNotNull,
          );
          await tap(tester, key);
          expect(f.player.active?.sound, sound);
          expect(f.audio.preferences, saved);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('sound-chooser-status')))
                .data,
            startsWith('Previewing '),
          );
          await tap(tester, key);
          expect(f.player.active, isNull);
        }
        await tap(tester, 'sound-close');
        expect(f.app.timer.phase, FocusPhase.shortBreak);
        expect(f.app.timer.status, RunStatus.ready);
        expect(f.app.timer.revision, revision);
        expect(f.app.sessions, isEmpty);
        expect(f.audio.preferences, saved);
      } finally {
        mountedDesktop?.dispose();
        mountedDesktop = null;
      }
    });
  }

  testWidgets('preview retry replacement and close cancel playback', (
    tester,
  ) async {
    final f = await mount(tester);
    await tap(tester, 'focus-sounds-open');
    f.player.failLoads = true;
    await tap(tester, 'sound-preview-waterfall');
    expect(f.audio.state.canRetry, isTrue);
    f.player.failLoads = false;
    await tap(tester, 'sound-retry');
    expect(f.player.active, isNotNull);
    await tap(tester, 'sound-close');
    expect(f.player.active, isNull);
  });

  testWidgets(
    'closing while preview awaits reconciliation cancels its late token',
    (tester) async {
      final f = await mount(tester);
      final wait = Completer<void>();
      f.audio.bind(
        preferences: f.audio.preferences,
        save: f.app.updateFocusSoundPreferences,
        reconcile: () async {
          await wait.future;
          await f.app.reconcile();
        },
      );
      await tap(tester, 'focus-sounds-open');
      await tap(tester, 'sound-preview-waterfall');
      await tap(tester, 'sound-close');
      wait.complete();
      await frames(tester);
      expect(f.player.active, isNull);
      expect(f.audio.state.previewSound, isNull);
    },
  );

  testWidgets('zero and mute persist; keyboard volume commits on dismissal', (
    tester,
  ) async {
    final f = await mount(
      tester,
      preferences: const FocusSoundPreferences(
        sound: FocusSoundId.oceanWaves,
        volume: 0,
      ),
    );
    await tap(tester, 'sound-compact-mute');
    await tap(tester, 'sound-compact-mute');
    expect(f.audio.preferences.volume, 0);
    await tap(tester, 'focus-sounds-open');
    final slider = find.byKey(const Key('sound-volume'));
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.tap(slider);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await frames(tester);
    expect(f.audio.preferences.volume, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await frames(tester);
    expect(f.audio.preferences.volume, 0);
    final writes = f.repository.writes;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await frames(tester);
    expect(f.audio.preferences.volume, .01);
    expect(
      f.repository.writes,
      writes,
      reason: 'Keyboard volume stays staged until coalesced or dismissed',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await frames(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await frames(tester);
    await f.app.flush();
    expect(f.repository.state.focusSounds!.volume, 0);
    expect(f.repository.state.focusSounds!.muted, isFalse);
  });

  for (final dismissal in ['done', 'back', 'barrier', 'drag']) {
    testWidgets(
      '$dismissal dismissal cancels owned preview without timer changes',
      (tester) async {
        final f = await mount(tester);
        final revision = f.app.timer.revision;
        await tap(tester, 'focus-sounds-open');
        await tap(tester, 'sound-preview-waterfall');
        expect(f.player.active, isNotNull);
        switch (dismissal) {
          case 'done':
            await tap(tester, 'sound-done');
          case 'back':
            await tester.binding.handlePopRoute();
          case 'barrier':
            await tester.tapAt(const Offset(4, 30));
          case 'drag':
            final sheet = tester.getRect(find.byType(BottomSheet));
            await tester.dragFrom(
              Offset(sheet.center.dx, sheet.top + 16),
              const Offset(0, 750),
            );
        }
        await frames(tester);
        expect(find.byKey(const Key('sound-chooser-scroll')), findsNothing);
        expect(f.player.active, isNull);
        expect(f.app.timer.revision, revision);
        expect(f.repository.state.sessions, isEmpty);
      },
    );
  }

  testWidgets(
    'radio arrows save quietly; Tab stays in modal and names previews',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final f = await mount(tester);
        await tap(tester, 'focus-sounds-open');
        expect(
          find.bySemanticsLabel('Preview Tibetan bells for up to 10 seconds'),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await frames(tester);
        expect(f.audio.preferences.sound, FocusSoundId.tibetanBells);
        expect(f.player.prepared, isEmpty);
        for (var i = 0; i < 24; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await frames(tester);
          var inside = false;
          FocusManager.instance.primaryFocus!.context!.visitAncestorElements((
            element,
          ) {
            if (element.widget.key == const Key('sound-chooser-scroll')) {
              inside = true;
            }
            return true;
          });
          expect(
            inside,
            isTrue,
            reason: 'Tab traversal $i must stay inside chooser',
          );
        }
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await frames(tester);
        expect(find.byKey(const Key('timer-toggle')), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await frames(tester);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets(
    'completion with chooser open cancels preview and records one focus',
    (tester) async {
      final f = await mount(
        tester,
        preferences: const FocusSoundPreferences(
          sound: FocusSoundId.oceanWaves,
        ),
      );
      await f.app.toggleTimer();
      await frames(tester);
      await tap(tester, 'focus-sounds-open');
      await tap(tester, 'sound-preview-tibetanBells');
      f.clock.advance(const Duration(minutes: 25));
      await f.app.reconcile();
      await frames(tester);
      expect(f.audio.state.previewSound, isNull);
      expect(f.player.active, isNull);
      expect(f.app.timer.status, RunStatus.ready);
      expect(f.app.timer.phase, FocusPhase.shortBreak);
      expect(f.repository.state.sessions, hasLength(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await frames(tester);
    },
  );

  for (final spec in [
    // Rendered fixtures deliberately exercise the real coordinator through a fake port.
    ('phone-off', const Size(390, 844), 1.0, false, 'light', false, 'off'),
    ('phone-ready', const Size(390, 844), 1.0, false, 'dark', false, 'ready'),
    (
      'phone-playing',
      const Size(390, 844),
      1.0,
      false,
      'dark',
      false,
      'playing',
    ),
    (
      'phone-large-muted',
      const Size(320, 700),
      2.0,
      false,
      'light',
      false,
      'muted',
    ),
    (
      'phone-landscape-error',
      const Size(700, 320),
      2.0,
      false,
      'dark',
      false,
      'error',
    ),
    (
      'desktop-playing',
      const Size(1440, 1000),
      1.0,
      true,
      'light',
      false,
      'playing',
    ),
    (
      'desktop-paused',
      const Size(1080, 800),
      1.5,
      true,
      'dark',
      false,
      'paused',
    ),
    ('desktop-zero', const Size(640, 600), 2.0, true, 'dark', false, 'zero'),
    ('contrast-light', const Size(1024, 768), 1.0, true, 'light', true, 'off'),
    ('contrast-dark', const Size(1024, 768), 2.0, true, 'dark', true, 'muted'),
    (
      'desktop-loading',
      const Size(1440, 1000),
      1.0,
      true,
      'dark',
      false,
      'loading',
    ),
    (
      'desktop-error',
      const Size(1440, 1000),
      1.0,
      true,
      'dark',
      false,
      'error',
    ),
    (
      'phone-unavailable',
      const Size(390, 844),
      1.0,
      false,
      'light',
      false,
      'unavailable',
    ),
  ]) {
    testWidgets('${spec.$1} real state layout and accessible actions', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        final mode = spec.$7;
        final f = await mount(
          tester,
          size: spec.$2,
          scale: spec.$3,
          desktop: spec.$4,
          appearance: spec.$5,
          highContrast: spec.$6,
          unavailable: mode == 'unavailable',
          preferences: FocusSoundPreferences(
            sound: mode == 'off' ? FocusSoundId.off : FocusSoundId.oceanWaves,
            volume: mode == 'zero' ? 0 : .35,
            muted: mode == 'muted',
          ),
        );
        if (mode == 'loading') f.player.holdLoads = true;
        if (mode == 'error') f.player.failLoads = true;
        if (['loading', 'error', 'playing', 'paused'].contains(mode)) {
          await f.app.toggleTimer();
          await frames(tester);
          if (mode == 'paused') {
            await f.app.toggleTimer();
            await frames(tester);
          }
        }
        if (find.byKey(const Key('focus-sounds-open')).evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            find.byKey(const Key('focus-sounds-open')),
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(find.byKey(const Key('focus-sounds-open')));
        await tester.pumpAndSettle();
        final metadata = {
          'theme': spec.$5,
          'highContrast': spec.$6,
          'state': mode,
        };
        await capture(tester, '${spec.$1}-closed', metadata);
        await expectLater(
          tester,
          meetsGuideline(
            RenderedTextContrastGuideline(finder: fullyVisibleText(tester)),
          ),
        );
        await tap(tester, 'focus-sounds-open');
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(
          tester,
          meetsGuideline(
            RenderedTextContrastGuideline(
              finder: find.descendant(
                of: find.byKey(const Key("sound-chooser-scroll")),
                matching: fullyVisibleText(tester),
              ),
            ),
          ),
        );
        await capture(tester, '${spec.$1}-chooser', metadata);
        if (mode == 'playing') {
          await tap(tester, 'sound-preview-tibetanBells');
          expect(f.audio.preferences.sound, FocusSoundId.oceanWaves);
          await capture(tester, '${spec.$1}-preview', {
            ...metadata,
            'preview': 'tibetanBells',
          });
        }
        if (mode == 'unavailable') {
          expect(
            tester
                .widget<TextButton>(
                  find.byKey(const Key('sound-preview-waterfall')),
                )
                .onPressed,
            isNull,
          );
          await tap(tester, 'sound-select-waterfall');
          expect(f.player.prepared, isEmpty);
        }
        await tester.ensureVisible(find.byKey(const Key('sound-done')));
        await tester.pumpAndSettle();
        if (mode == 'error') {
          var retryFocused = false;
          for (var i = 0; i < 24 && !retryFocused; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.tab);
            await frames(tester);
            FocusManager.instance.primaryFocus?.context?.visitAncestorElements((
              element,
            ) {
              if (element.widget.key == const Key('sound-retry')) {
                retryFocused = true;
              }
              return true;
            });
          }
          expect(retryFocused, isTrue);
        }
        await capture(tester, '${spec.$1}-footer', metadata);
        await expectLater(
          tester,
          meetsGuideline(
            RenderedTextContrastGuideline(
              finder: find.descendant(
                of: find.byKey(const Key("sound-chooser-scroll")),
                matching: fullyVisibleText(tester),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await frames(tester);
        if (mode == 'loading') {
          f.audio.selectSound(FocusSoundId.off);
          f.player.completeLoad();
          await frames(tester);
        }
      } finally {
        semantics.dispose();
        mountedDesktop?.dispose();
        mountedDesktop = null;
      }
    });
  }
}
