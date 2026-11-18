import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/day_clock_dial.dart';
import 'package:poma/ui/nebula_appearance.dart';
import 'package:poma/ui/timer_dial.dart';

import 'contrast_support.dart';
import 'planner_ui_test.dart' as planner_ui show mount, settlePlanner;
import 'support.dart';

const _captures = String.fromEnvironment('POMA_NEBULA_SCREENSHOTS');

Future<void> _settleArtwork(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final finder = find.descendant(
    of: find.byKey(const ValueKey('poma-nebula')),
    matching: find.byType(Image),
  );
  if (finder.evaluate().isEmpty) return;
  final image = tester.widget<Image>(finder);
  await tester.runAsync(
    () => precacheImage(
      image.image,
      tester.element(finder),
      onError: (error, stack) => fail('Nebula asset failed to load: $error'),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  String name, {
  Key boundaryKey = const ValueKey('nebula-capture'),
}) async {
  if (_captures.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundaryKey),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_captures/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _expectBackdropContrast(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('poma-nebula')),
  );
  final brightest = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final pixels = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      var result = 0.0;
      for (var i = 0; i < pixels.length; i += 4) {
        result = math.max(
          result,
          Color.fromARGB(
            255,
            pixels[i],
            pixels[i + 1],
            pixels[i + 2],
          ).computeLuminance(),
        );
      }
      return result;
    } finally {
      image.dispose();
    }
  });
  for (final color in [NebulaColors.text, NebulaColors.secondaryText]) {
    expect(
      (color.computeLuminance() + .05) / (brightest! + .05),
      greaterThanOrEqualTo(4.5),
      reason:
          'Text remains readable over the brightest composited nebula pixel',
    );
  }
}

Future<AppController> _mountFocus(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  TimerSettings settings = const TimerSettings(appearance: 'dark'),
  MemoryRepository? repository,
  FakeClock? clock,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final app = await AppController.create(
    repository ?? MemoryRepository(SavedState(settings: settings)),
    clock: clock ?? FakeClock(),
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('nebula-capture'),
      child: PomaApp(controller: app),
    ),
  );
  await _settleArtwork(tester);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
  });
  return app;
}

void main() {
  test(
    'saved background values round-trip and older settings select Nebula',
    () {
      expect(TimerSettings.fromJson({}).darkBackground, 'nebula');
      for (final value in ['nebula', 'classic']) {
        final settings = const TimerSettings().copyWith(darkBackground: value);
        expect(TimerSettings.fromJson(settings.toJson()).darkBackground, value);
      }
      for (final invalid in ['unknown', null, 7]) {
        expect(
          () => TimerSettings.fromJson({'darkBackground': invalid}),
          throwsFormatException,
        );
      }
    },
  );

  for (final status in RunStatus.values) {
    test('background updates persist during $status and strict sessions', () {
      final clock = FakeClock();
      final timer = TimerEngine(
        settings: TimerSettings(strictMode: status == RunStatus.running),
        now: clock.reading,
      );
      if (status != RunStatus.ready) {
        timer.apply(TimerAction.start, clock.reading);
      }
      if (status == RunStatus.paused) {
        timer.apply(TimerAction.pause, clock.reading);
      }
      final original = timer.snapshot().toJson();
      final transition = timer.apply(
        TimerAction.updateSettings,
        clock.reading,
        nextSettings: timer.settings.copyWith(darkBackground: 'classic'),
      );
      expect(transition.changed, isTrue);
      expect(timer.settings.darkBackground, 'classic');
      expect(timer.snapshot().toJson(), original);
    });
  }

  testWidgets(
    'background choice saves through Settings and restores on reopen',
    (tester) async {
      final repo = MemoryRepository(
        SavedState(settings: const TimerSettings(appearance: 'dark')),
      );
      final app = await _mountFocus(tester, repository: repo);
      expect(find.byKey(const ValueKey('poma-nebula')), findsOneWidget);
      await tester.tap(find.byKey(const Key('destination-3')));
      await tester.pumpAndSettle();
      final classic = find.byKey(const ValueKey('dark-background-classic'));
      await tester.ensureVisible(classic);
      await tester.tap(classic);
      await tester.pumpAndSettle();
      expect(app.settings.darkBackground, 'classic');
      expect(repo.state.settings.darkBackground, 'classic');
      await tester.tap(find.byKey(const Key('destination-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('poma-nebula')), findsNothing);
      final reopened = await AppController.create(repo, clock: FakeClock());
      expect(reopened.settings.darkBackground, 'classic');
      reopened.dispose();
    },
  );

  testWidgets('System appearance and high contrast resolve the target scene', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await _mountFocus(tester, settings: const TimerSettings());
    expect(find.byKey(const ValueKey('poma-nebula')), findsNothing);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await _settleArtwork(tester);
    expect(find.byKey(const ValueKey('poma-nebula')), findsOneWidget);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(highContrast: true, disableAnimations: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('poma-nebula')), findsNothing);
    final colors = Theme.of(tester.element(find.byType(TimerDial))).colorScheme;
    expect(colors.surface, Colors.black);
    expect(colors.onSurface, Colors.white);
  });

  testWidgets('countdown ticks retain the cached nebula painting', (
    tester,
  ) async {
    final clock = FakeClock();
    final app = await _mountFocus(tester, clock: clock);
    await tester.tap(find.byKey(const Key('timer-toggle')));
    await tester.pumpAndSettle();
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('poma-nebula')),
    );
    final picture = boundary.debugLayer!.firstChild;
    expect(picture, isNotNull);
    clock.advance(const Duration(seconds: 1));
    await app.reconcile();
    await tester.pump();
    expect(boundary.debugLayer!.firstChild, same(picture));
    expect(app.timer.remainingSeconds, 1499);
  });

  for (final spec in [
    (const Size(390, 844), 1.0),
    (const Size(390, 844), 1.5),
    (const Size(320, 640), 2.0),
    (const Size(844, 390), 1.0),
    (const Size(844, 390), 2.0),
  ]) {
    testWidgets('mobile nebula fits ${spec.$1}, text ${spec.$2}', (
      tester,
    ) async {
      await _mountFocus(tester, size: spec.$1, scale: spec.$2);
      expect(find.byKey(const ValueKey('poma-nebula')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        tester,
        meetsGuideline(
          RenderedTextContrastGuideline(
            finder: find.byType(Text).hitTestable(),
          ),
        ),
      );
      if (spec.$2 == 1) await _expectBackdropContrast(tester);
      await _capture(
        tester,
        'focus-mobile-${spec.$1.width.toInt()}-${spec.$1.height.toInt()}-${(spec.$2 * 100).toInt()}',
      );
    });
  }

  for (final spec in [
    (1440.0, 1000.0, 1.0),
    (1067.0, 724.0, 1.0),
    (640.0, 900.0, 1.5),
    (640.0, 900.0, 2.0),
  ]) {
    testWidgets('desktop nebula fits ${spec.$1}, text ${spec.$3}', (
      tester,
    ) async {
      final (_, desktop) = await planner_ui.mount(
        tester,
        width: spec.$1,
        height: spec.$2,
        scale: spec.$3,
      );
      await _settleArtwork(tester);
      expect(find.byKey(const ValueKey('poma-nebula')), findsOneWidget);
      final face = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byKey(const ValueKey('day-clock-face')),
          matching: find.byType(CustomPaint),
        ),
      );
      expect((face.painter! as DayClockPainter).nebula, isTrue);
      await _capture(
        tester,
        'day-clock-${spec.$1.toInt()}-${(spec.$3 * 100).toInt()}',
        boundaryKey: const ValueKey('planner-capture'),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        tester,
        meetsGuideline(
          RenderedTextContrastGuideline(
            finder: find.byType(Text).hitTestable(),
          ),
        ),
      );
      desktop.navigate(0);
      await planner_ui.settlePlanner(tester);
      await _settleArtwork(tester);
      expect(find.byType(TimerDial), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        'focus-desktop-${spec.$1.toInt()}-${(spec.$3 * 100).toInt()}',
        boundaryKey: const ValueKey('planner-capture'),
      );
    });
  }
}
