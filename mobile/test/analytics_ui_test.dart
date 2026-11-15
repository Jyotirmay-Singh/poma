import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/calendar_controller.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/copy.dart';

import 'analytics_test.dart'
    show AnalyticsRepository, createAnalyticsApp, analyticsCompletion;
import 'contrast_support.dart';
import 'desktop_test.dart' show FakeShell, environment;
import 'refinement_test.dart' show fullyVisibleText;
import 'support.dart';

SavedState analyticsFixture(String appearance) {
  final sessions = <FocusSession>[];
  final last = DateTime.utc(2026, 11, 15);
  for (
    var date = DateTime.utc(2025, 11);
    !date.isAfter(last);
    date = DateTime.utc(date.year, date.month, date.day + 1)
  ) {
    final count = [5, 7, 4, 6, 8, 2, 3][date.weekday - 1];
    for (var index = 0; index < count; index++) {
      final end = DateTime.utc(date.year, date.month, date.day, 8 + index, 25);
      sessions.add(
        analyticsCompletion('${date.toIso8601String()}-$index', end),
      );
    }
  }
  return SavedState(
    settings: TimerSettings(appearance: appearance),
    sessions: sessions,
  );
}

Future<void> revealAnalyticsControl(WidgetTester tester, Finder finder) async {
  final scrollable = find
      .descendant(
        of: find.byType(ListView).first,
        matching: find.byType(Scrollable),
      )
      .first;
  if (finder.evaluate().isEmpty) {
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      finder,
      160,
      scrollable: scrollable,
      maxScrolls: 100,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> tapAnalyticsControl(WidgetTester tester, Finder finder) async {
  await revealAnalyticsControl(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> captureAnalytics(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('POMA_SCREENSHOTS')) return;
  const directory = String.fromEnvironment(
    'POMA_SCREENSHOT_DIR',
    defaultValue: '../artifacts/analytics',
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('analytics-preview')),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$directory/analytics-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(() async {
    await DeviceFormats.initialize();
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  Future<AppController> mount(
    WidgetTester tester, {
    Size size = const Size(1440, 1000),
    double scale = 1,
    String appearance = 'light',
    bool highContrast = false,
    AnalyticsRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.localeTestValue = const Locale('en', 'US');
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(
          disableAnimations: true,
          highContrast: highContrast,
        );
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final app = await createAnalyticsApp(
      repository ?? AnalyticsRepository(analyticsFixture(appearance)),
      FakeClock(DateTime.utc(2026, 11, 15, 18)),
    );
    final desktop = size.width >= 800
        ? DesktopController(
            app,
            FakeShell(),
            environment,
            calendar: CalendarController(scheduleUpdates: false),
          )
        : null;
    await desktop?.initialize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      desktop?.dispose();
      app.dispose();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('analytics-preview'),
        child: PomaApp(controller: app, desktop: desktop),
      ),
    );
    await tester.pumpAndSettle();
    await tapAnalyticsControl(
      tester,
      desktop == null
          ? find.byKey(const Key('destination-2'))
          : find.byTooltip('Analytics'),
    );
    return app;
  }

  testWidgets(
    'normal navigation exposes all six saved-session metrics and average definitions',
    (tester) async {
      final app = await mount(tester);
      expect(find.byKey(const Key('analytics-overview-tab')), findsOneWidget);
      expect(app.analyticsHistoryVisible, isFalse);
      for (final metric in [
        'today',
        'this-week',
        'last-month',
        'daily-average',
        'weekly-average',
        'monthly-average',
      ]) {
        expect(find.byKey(Key('analytics-$metric')), findsOneWidget);
      }
      expect(
        find.descendant(
          of: find.byKey(const Key('analytics-today')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('analytics-this-week')),
          matching: find.text('35'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('analytics-last-month')),
          matching: find.text('156'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('analytics-daily-average')),
          matching: find.text('5.0'),
        ),
        findsOneWidget,
      );
      await tapAnalyticsControl(tester, find.byTooltip('Daily average'));
      expect(
        find.textContaining('Zero-session days are included.'),
        findsOneWidget,
      );
      expect(find.textContaining('Oct 16, 2026'), findsWidgets);
      await tester.tap(find.widgetWithText(TextButton, 'Close'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'period controls, current reset, touch, keyboard and exact data work',
    (tester) async {
      final app = await mount(tester);
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('analytics-next')))
            .onPressed,
        isNull,
      );
      await tapAnalyticsControl(
        tester,
        find.byKey(const Key('analytics-period-month')),
      );
      expect(app.analytics!.query.buckets.length, 30);
      await tapAnalyticsControl(
        tester,
        find.byKey(const Key('analytics-previous')),
      );
      expect(app.analytics!.query.anchor, DateTime(2026, 10));
      expect(app.analytics!.today.count, 3);
      await tapAnalyticsControl(tester, find.text('Current period'));
      expect(app.analytics!.query.anchor, DateTime(2026, 11));
      await tapAnalyticsControl(
        tester,
        find.byKey(const Key('analytics-period-year')),
      );
      expect(app.analytics!.query.buckets.length, 12);
      await tester.ensureVisible(find.byKey(const Key('analytics-chart')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('analytics-chart')));
      await tester.pumpAndSettle();
      final before = tester
          .getSemantics(find.byKey(const Key('analytics-chart')))
          .value;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const Key('analytics-chart'))).value,
        isNot(before),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(const Key('analytics-chart'))).value,
        contains('January 2026'),
      );
      await tapAnalyticsControl(
        tester,
        find.byKey(const Key('analytics-show-data')),
      );
      expect(find.text('December 2026'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('History retains pagination and deletion refreshes Overview', (
    tester,
  ) async {
    final app = await mount(tester);
    await tapAnalyticsControl(
      tester,
      find.byKey(const Key('analytics-history-tab')),
    );
    expect(app.sessions.length, 50);
    expect(app.historyPage!.hasOlder, isTrue);
    expect(find.byKey(const Key('desktop-history-table')), findsOneWidget);
    final delete = find.byIcon(Icons.delete_outline).first;
    await tapAnalyticsControl(tester, delete);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    await tapAnalyticsControl(
      tester,
      find.byKey(const Key('analytics-overview-tab')),
    );
    expect(app.analytics!.today.count, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unavailable metrics have retry feedback and real empty values appear after recovery',
    (tester) async {
      final repository = AnalyticsRepository()..failAnalytics = true;
      final app = await mount(tester, repository: repository);
      expect(
        find.textContaining('Analytics couldn’t be loaded.'),
        findsOneWidget,
      );
      expect(app.analytics, isNull);
      expect(find.text('0'), findsNothing);
      repository.failAnalytics = false;
      await tapAnalyticsControl(tester, find.text('Retry analytics'));
      expect(app.analytics!.today.count, 0);
      await tapAnalyticsControl(tester, find.text('Go to Focus'));
      expect(find.byKey(const Key('analytics-overview-tab')), findsNothing);
    },
  );

  for (final viewport in {
    'compact': const Size(320, 700),
    'phone': const Size(390, 844),
    'landscape': const Size(700, 360),
    'tablet': const Size(800, 1024),
    'desktop': const Size(1440, 1000),
  }.entries) {
    for (final appearance in ['light', 'dark']) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          'analytics ${viewport.key} $appearance ${scale}x fits and remains accessible',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              await mount(
                tester,
                size: viewport.value,
                appearance: appearance,
                scale: scale,
              );
              await captureAnalytics(
                tester,
                '${viewport.key}-$appearance-${scale}x-overview',
              );
              for (final target in [
                find.byKey(const Key('analytics-today')),
                find.byKey(const Key('analytics-monthly-average')),
                find.byKey(const Key('analytics-period-month')),
              ]) {
                await revealAnalyticsControl(tester, target);
                expect(tester.takeException(), isNull);
                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(
                    RenderedTextContrastGuideline(
                      finder: fullyVisibleText(tester),
                    ),
                  ),
                );
              }
              await tapAnalyticsControl(
                tester,
                find.byKey(const Key('analytics-period-month')),
              );
              if (scale > 1.3) {
                expect(find.byKey(const Key('analytics-chart')), findsNothing);
                expect(find.text('Upcoming'), findsWidgets);
              } else {
                await tester.ensureVisible(
                  find.byKey(const Key('analytics-chart')),
                );
                await tester.pumpAndSettle();
              }
              await captureAnalytics(
                tester,
                '${viewport.key}-$appearance-${scale}x-activity',
              );
              await tapAnalyticsControl(
                tester,
                find.byKey(const Key('analytics-history-tab')),
              );
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }

  for (final appearance in ['light', 'dark']) {
    testWidgets(
      'analytics high contrast $appearance uses readable controls and totals',
      (tester) async {
        await mount(tester, appearance: appearance, highContrast: true);
        await expectLater(
          tester,
          meetsGuideline(
            RenderedTextContrastGuideline(finder: fullyVisibleText(tester)),
          ),
        );
        await captureAnalytics(tester, 'high-contrast-$appearance');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
