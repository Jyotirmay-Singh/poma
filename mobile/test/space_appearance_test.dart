import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/design_tokens.dart';
import 'package:poma/ui/space_backdrop.dart';
import 'package:poma/ui/theme.dart';
import 'package:poma/ui/tasks_screen.dart';
import 'support.dart';

void main() {
  test(
    'theme keeps both bundled families and stable Sora countdown digits',
    () {
      final text = pomaTheme(Brightness.dark).textTheme;
      expect(text.headlineSmall!.fontFamily, PomaType.displayFamily);
      expect(text.titleLarge!.fontFamily, PomaType.displayFamily);
      expect(text.displaySmall!.fontFamily, PomaType.displayFamily);
      expect(text.bodyMedium!.fontFamily, PomaType.family);
      expect(text.labelLarge!.fontFamily, PomaType.family);
      double width(String value) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: text.displaySmall),
          textDirection: TextDirection.ltr,
        )..layout();
        final result = painter.width;
        painter.dispose();
        return result;
      }

      expect(width('11:11'), closeTo(width('88:88'), .01));
    },
  );

  for (final brightness in Brightness.values) {
    for (final highContrast in [false, true]) {
      testWidgets(
        'composed $brightness sky remains readable, high contrast $highContrast',
        (tester) async {
          final theme = pomaTheme(brightness, highContrast: highContrast);
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => PomaBackdrop(child: child!),
              home: const Scaffold(body: SizedBox.shrink()),
            ),
          );
          await tester.pumpAndSettle();
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('poma-sky')),
          );
          final bytes = await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            image.dispose();
            return data!;
          });
          final pixels = bytes!.buffer.asUint8List(
            bytes.offsetInBytes,
            bytes.lengthInBytes,
          );
          var darkest = 1.0;
          var brightest = 0.0;
          for (var i = 0; i < pixels.length; i += 4) {
            final luminance = Color.fromARGB(
              255,
              pixels[i],
              pixels[i + 1],
              pixels[i + 2],
            ).computeLuminance();
            darkest = math.min(darkest, luminance);
            brightest = math.max(brightest, luminance);
          }
          if (highContrast) {
            expect(
              darkest,
              brightest,
              reason: 'High contrast has a plain solid sky',
            );
          } else {
            expect(
              brightest,
              greaterThan(darkest),
              reason: 'The background includes the celestial treatment',
            );
          }
          for (final foreground in [
            theme.colorScheme.onSurface,
            theme.colorScheme.onSurfaceVariant,
          ]) {
            final value = foreground.computeLuminance();
            for (final background in [darkest, brightest]) {
              final ratio =
                  (math.max(value, background) + .05) /
                  (math.min(value, background) + .05);
              expect(ratio, greaterThanOrEqualTo(4.5));
            }
          }
        },
      );
    }
  }

  testWidgets('timer and navigation work over a sky retained across updates', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final clock = FakeClock();
    final app = await AppController.create(
      MemoryRepository(
        SavedState(settings: const TimerSettings(appearance: 'dark')),
      ),
      clock: clock,
    );
    addTearDown(app.dispose);
    await tester.pumpWidget(PomaApp(controller: app));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timer-toggle')));
    await tester.pumpAndSettle();
    expect(app.timer.status, RunStatus.running);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('poma-sky')),
    );
    final picture = boundary.debugLayer!.firstChild;
    expect(picture, isNotNull);
    clock.advance(const Duration(seconds: 1));
    await app.reconcile();
    await tester.pump();
    expect(
      boundary.debugLayer!.firstChild,
      same(picture),
      reason: 'Countdown updates retain the painted sky',
    );
    await tester.tap(find.byKey(const Key('destination-1')));
    await tester.pumpAndSettle();
    expect(find.byType(TasksScreen), findsOneWidget);
    expect(
      boundary.debugLayer!.firstChild,
      same(picture),
      reason: 'Navigation does not repaint the sky',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
