import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/day_clock_controller.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:poma/domain/calendar_event_creation.dart';
import 'package:poma/main.dart';
import 'calendar_creation_support.dart';
import 'calendar_creation_consent_test.dart' show CapabilityAuth;
import 'calendar_read_test.dart' show settleCalendar;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

const captures = String.fromEnvironment(
  'POMA_DAY_CLOCK_SESSION3_SCREENSHOTS',
  defaultValue: String.fromEnvironment('POMA_DAY_CLOCK_SESSION2_SCREENSHOTS'),
);
Future<void> capture(WidgetTester tester, String name) async {
  if (captures.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('creation-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$captures/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<(CreationRig, DesktopController)> mount(
  WidgetTester tester, {
  double width = 1440,
  double height = 1100,
  double pixelRatio = 1,
  double scale = 1,
  bool dark = true,
  bool highContrast = false,
  bool reducedMotion = false,
  bool creation = true,
  CapabilityAuth? authorization,
}) async {
  tester.view.physicalSize = Size(width, height) * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        highContrast: highContrast,
        disableAnimations: reducedMotion,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final r = (await tester.runAsync(
    () => creationRig(creation: creation, writeAuthorization: authorization),
  ))!;
  r.day.dispose();
  r.agenda.dispose();
  final app = (await tester.runAsync(
    () => AppController.create(MemoryRepository(), clock: FakeClock()),
  ))!;
  if (dark) {
    await tester.runAsync(
      () => app.updateSettings(app.settings.copyWith(appearance: 'dark')),
    );
  }
  final desktop = (await tester.runAsync(
    () async => DesktopController(
      app,
      FakeShell(),
      const DesktopEnvironment(
        dataDirectory: 'fictional-only',
        version: 'day-clock-session2-test',
        packaged: false,
        visible: true,
        sessionState: 'unlocked',
      ),
      connection: r.connection,
      calendarData: r.reader,
      calendarPlatform: r.agenda.platform,
    ),
  ))!;
  await tester.runAsync(desktop.initialize);
  desktop.dayClock!.dispose();
  desktop.dayClock = DayClockController(
    reader: r.reader,
    agenda: desktop.agenda!,
    time: r.times,
    unlocked: true,
    localize: (v) => tz.TZDateTime.from(v, r.clock.location),
  );
  await tester.runAsync(() async {
    desktop.attachCreation(r.controller);
    await r.controller.initialize();
  });
  desktop.dayClock!.browse(CalendarDate(2026, 11, 10), DayClockHalf.pm);
  desktop.navigate(5);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('creation-capture'),
      child: PomaApp(controller: app, desktop: desktop),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    desktop.dispose();
    app.dispose();
  });
  return (r, desktop);
}

Future<void> open(
  WidgetTester tester,
  DesktopController desktop,
  CreationRig r,
) async {
  final d = desktop.dayClock!.beginDraft();
  final source = r.draft();
  d.title = source.title;
  d.startDate = source.startDate;
  d.endDate = source.endDate;
  d.startTime = source.startTime;
  d.endTime = source.endTime;
  d.startPm = true;
  d.endPm = true;
  d.colorId = '2';
  desktop.dayClock!.touchDraft();
  await tester.tap(find.byKey(const ValueKey('day-clock-add-task')));
  await tester.pumpAndSettle();
}

void main() {
  for (final spec in [
    for (final width in [640.0, 1440.0])
      for (final scale in [1.0, 1.5, 2.0])
        for (final dark in [false, true])
          for (final contrast in [false, true]) (width, scale, dark, contrast),
  ]) {
    testWidgets('production creation form and Saved result $spec', (
      tester,
    ) async {
      final (r, desktop) = await mount(
        tester,
        width: spec.$1,
        scale: spec.$2,
        dark: spec.$3,
        highContrast: spec.$4,
      );
      await open(tester, desktop, r);
      final suffix =
          '${spec.$1.toInt()}-${(spec.$2 * 100).toInt()}-${spec.$3 ? 'dark' : 'light'}${spec.$4 ? '-contrast' : ''}';
      await capture(tester, 'form-$suffix-top');
      final check = find.widgetWithText(OutlinedButton, 'Check task');
      await tester.ensureVisible(check);
      await tester.tap(check);
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(r.google.inserts, 0);
      final save = find.widgetWithText(FilledButton, 'Add to Google Calendar');
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await capture(tester, 'review-$suffix-bottom');
      final callback = tester.widget<FilledButton>(save).onPressed!;
      await tester.runAsync(() async {
        await (callback as dynamic)();
      });
      await tester.pumpAndSettle();
      expect(
        r.google.events.length,
        1,
        reason:
            '${desktop.dayClock!.validationMessage}; ${r.controller.message}',
      );
      expect(r.google.inserts, 1);
      expect(desktop.dayClock!.operation!.state, CalendarCreationState.saved);
      final saved = find.text('Saved to Google Calendar');
      await tester.ensureVisible(saved);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(
        find.byKey(const ValueKey('day-clock-saved-summary')),
        findsOneWidget,
      );
      expect(find.text('Duration: 60 minutes'), findsOneWidget);
      await capture(tester, 'saved-$suffix-top');
      await tester.ensureVisible(find.text('Show this time as: Busy'));
      await tester.pumpAndSettle();
      await capture(tester, 'saved-$suffix-bottom');
      final close = find.widgetWithText(TextButton, 'Close');
      await tester.ensureVisible(close);
      await tester.tap(close);
      await tester.pumpAndSettle();
      expect(desktop.dayClock!.projection.agenda.length, 1);
      expect(desktop.dayClock!.projection.sectors.single.startMinute, 600);
      await capture(tester, 'clock-$suffix');
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'declining creation preserves every form field and the durable draft',
    (tester) async {
      final auth = CapabilityAuth()
        ..candidate = (_) async =>
            throw const CalendarConnectionFailure(CalendarFailureKind.denied);
      final (r, desktop) = await mount(
        tester,
        creation: false,
        authorization: auth,
      );
      await open(tester, desktop, r);
      final before = desktop.dayClock!.draft!.toJson();
      final enable = find.widgetWithText(TextButton, 'Enable task creation');
      await tester.ensureVisible(enable);
      await tester.tap(enable);
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(desktop.dayClock!.draft!.toJson(), before);
      expect(
        r.controller.journal!.drafts.values.single.title,
        'Evening planning',
      );
      expect(r.connection.operationsEnabled, true);
      expect(r.google.inserts, 0);
      expect(
        find.textContaining('Task creation was not enabled.'),
        findsWidgets,
      );
      await capture(tester, 'consent-declined-fields-retained');
    },
  );
  testWidgets(
    'stale Now summaries never assert an empty or available schedule',
    (tester) async {
      final (r, desktop) = await mount(tester);
      r.google.failList = true;
      await tester.runAsync(r.reader.refresh);
      desktop.dayClock!.now();
      await tester.pumpAndSettle();
      expect(find.text('No timed event now'), findsNothing);
      expect(find.text('Availability unknown'), findsNWidgets(2));
      await capture(tester, 'stale-now-unknown');
    },
  );
}
