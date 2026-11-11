import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalender/kalender.dart' as k;
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/planner.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/planner_editor.dart';
import 'package:poma/ui/planner_screen.dart';

import 'calendar_read_test.dart' show settleCalendar;
import 'desktop_test.dart' show FakeShell;
import 'day_clock_support.dart' show FictionalDayClock;
import 'planner_support.dart';

const captures = String.fromEnvironment('POMA_PLANNER_SCREENSHOTS');

Future<void> capture(WidgetTester tester, String name) async {
  if (captures.isEmpty) return;
  await tester.pump();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('planner-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$captures/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> settlePlanner(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
    await tester.runAsync(settleCalendar);
  }
  await tester.pumpAndSettle();
}

Future<(PlannerRig, DesktopController)> mount(
  WidgetTester tester, {
  double width = 1067,
  double height = 724,
  double scale = 1,
  bool dark = true,
  bool contrast = false,
  bool calendar = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        highContrast: contrast,
        disableAnimations: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final r = (await tester.runAsync(
    () => plannerRig(calendarClock: FictionalDayClock()),
  ))!;
  r.creation.day.dispose();
  r.creation.agenda.dispose();
  final desktop = (await tester.runAsync(
    () async => DesktopController(
      r.app,
      FakeShell(),
      const DesktopEnvironment(
        dataDirectory: 'fictional-planner-only',
        version: 'planner-review',
        packaged: false,
        visible: true,
        sessionState: 'unlocked',
      ),
      connection: r.creation.connection,
      calendarData: r.creation.reader,
      calendarPlatform: r.creation.agenda.platform,
    ),
  ))!;
  await tester.runAsync(() async {
    await desktop.initialize();
    desktop.attachPlanner(r.planner);
    await settleCalendar();
    await r.app.updateSettings(
      r.app.settings.copyWith(appearance: dark ? 'dark' : 'light'),
    );
    r.planner.browse(CalendarDate(2026, 11, 10), selectedHalf: 1);
  });
  for (var i = 0; i < 5; i++) {
    final start = DateTime(
      2026,
      11,
      10,
      [12, 13, 15, 16, 21][i],
      [30, 30, 0, 30, 0][i],
    ).toUtc();
    r.google.events['fictional-$i'] = {
      'id': 'fictional-$i',
      'calendarId': 'synthetic-primary',
      'summary': ['Lunch', 'Deep work', 'Travel', 'Meeting', 'Reading'][i],
      'status': 'confirmed',
      'start': {
        'dateTime': start.toIso8601String(),
        'timeZone': 'Asia/Kolkata',
      },
      'end': {
        'dateTime': start.add(const Duration(hours: 1)).toIso8601String(),
        'timeZone': 'Asia/Kolkata',
      },
      'transparency': 'opaque',
      'colorId': i.isEven ? '2' : '5',
      'organizer': {'self': true},
      'eventType': 'default',
      'etag': '"fictional-$i"',
    };
  }
  await tester.runAsync(r.creation.reader.refresh);
  desktop.navigate(calendar ? 4 : 5);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('planner-capture'),
      child: PomaApp(controller: r.app, desktop: desktop),
    ),
  );
  await tester.runAsync(settleCalendar);
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    desktop.dispose();
    r.app.dispose();
  });
  return (r, desktop);
}

void main() {
  testWidgets('scheduled task deletion stops offering Undo at its deadline', (
    tester,
  ) async {
    final (rig, desktop) = await mount(tester);
    await tester.runAsync(() async {
      await rig.planner.saveDraft(await rig.draft(title: 'Fictional deletion'));
    });
    desktop.navigate(1);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          accessibleNavigation: true,
          disableAnimations: true,
        );
    await settlePlanner(tester);
    await tester.tap(find.byTooltip('Options for Fictional deletion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete task and calendar event'));
    await settlePlanner(tester);
    expect(rig.google.deletes, 0);
    expect(find.text('Task and schedule removed'), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).persist, isFalse);
    await tester.pump(const Duration(seconds: 11));
    await tester.runAsync(
      () => rig.creation.scheduler.advance(const Duration(seconds: 11)),
    );
    await settlePlanner(tester);
    expect(rig.google.deletes, 1);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Undo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact Tasks scheduling saves once and reveals the selected planner item',
    (tester) async {
      final (rig, desktop) = await mount(tester, width: 640, height: 724);
      desktop.navigate(1);
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await settlePlanner(tester);
      expect(find.byType(PlannerEditor), findsOneWidget);
      expect(rig.google.inserts, 0);
      await tester.enterText(
        find.byKey(const ValueKey('planner-title')),
        'Fictional scheduled Tasks journey',
      );
      await tester.tap(find.byKey(const ValueKey('planner-scheduled')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('planner-start')),
        '22:00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('planner-end')),
        '23:00',
      );
      await tester.tap(find.byKey(const ValueKey('planner-save')));
      await settlePlanner(tester);
      expect(desktop.destination, 5);
      expect(rig.google.inserts, 1);
      expect(rig.planner.selectedDate.toString(), '2026-11-10');
      expect(rig.planner.selectedIdentity, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await settlePlanner(tester);
      expect(find.byType(PlannerEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-title')))
            .controller!
            .text,
        'Fictional scheduled Tasks journey',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settlePlanner(tester);
      expect(rig.google.patches, 0);
      expect(tester.takeException(), isNull);
    },
  );

  Future<Offset Function(int)> gridTimes(
    WidgetTester tester,
    PlannerRig rig,
  ) async {
    rig.planner.setCalendarView(PlannerCalendarView.day);
    await settlePlanner(tester);
    final calendar = tester.widget<k.KalenderView>(find.byType(k.KalenderView));
    final controller =
        calendar.kalenderController.viewController as k.MultiDayViewController;
    controller.scrollController.jumpTo(
      18 * 60 * controller.heightPerMinute.value - 100,
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(k.MultiDayBody));
    return (minute) => Offset(
      rect.left + 72 + (rect.width - 72) / 2,
      rect.top +
          minute * controller.heightPerMinute.value -
          controller.scrollController.offset +
          .5,
    );
  }

  testWidgets(
    'Calendar range dragging opens a precise draft and Escape cancels a gesture',
    (tester) async {
      final (rig, _) = await mount(tester, calendar: true);
      final point = await gridTimes(tester, rig);
      final gesture = await tester.startGesture(
        point(18 * 60),
        kind: ui.PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump();
      await gesture.moveTo(point(19 * 60 + 30));
      await tester.pump();
      await gesture.moveBy(const Offset(0, .1));
      await tester.pump();
      expect(rig.google.inserts, 0);
      await gesture.up();
      await settlePlanner(tester);
      expect(find.byType(PlannerEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-start')))
            .controller!
            .text,
        '18:00',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-end')))
            .controller!
            .text,
        '19:30',
      );
      await capture(tester, 'calendar-range-draft');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settlePlanner(tester);
      final secondPoint = await gridTimes(tester, rig);
      final cancelled = await tester.startGesture(
        secondPoint(18 * 60),
        kind: ui.PointerDeviceKind.mouse,
      );
      await cancelled.moveBy(const Offset(0, 20));
      await tester.pump();
      await cancelled.moveTo(secondPoint(19 * 60));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await cancelled.up();
      await settlePlanner(tester);
      expect(find.byType(PlannerEditor), findsNothing);
      expect(rig.google.inserts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide editor reserves the full dial and repeated Ctrl N opens one editor',
    (tester) async {
      final (rig, _) = await mount(tester, width: 1536, height: 816);
      await tester.tap(find.byKey(const ValueKey('planner-add-task')));
      await settlePlanner(tester);
      expect(rig.planner.editorPane, isTrue);
      final dial = tester.getRect(
        find.byKey(const ValueKey('planner-clock-dial')),
      );
      final pane = tester.getRect(
        find.byKey(const ValueKey('planner-editor-panel')),
      );
      expect(dial.right, lessThanOrEqualTo(pane.left - 20));
      await tester.enterText(
        find.byKey(const ValueKey('planner-title')),
        'Fictional draft preview',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(PlannerEditor), findsOneWidget);
      await capture(tester, 'wide-editor-draft');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dense Unicode, pending and conflict states remain operable', (
    tester,
  ) async {
    final (rig, _) = await mount(tester, width: 1536, height: 816);
    for (var index = 0; index < 9; index++) {
      rig.google.events['dense-$index'] = {
        'id': 'dense-$index',
        'calendarId': 'synthetic-primary',
        'summary': 'Fictional ${index + 1} · План · योजना · 計画',
        'status': 'confirmed',
        'start': {
          'dateTime': DateTime(2026, 11, 10, 15).toUtc().toIso8601String(),
          'timeZone': 'Asia/Kolkata',
        },
        'end': {
          'dateTime': DateTime(
            2026,
            11,
            10,
            15,
            index == 0 ? 1 : 45,
          ).toUtc().toIso8601String(),
          'timeZone': 'Asia/Kolkata',
        },
        'transparency': 'opaque',
        'organizer': {'self': true},
        'etag': '"dense-$index"',
      };
    }
    await tester.runAsync(rig.creation.reader.refresh);
    await tester.pumpAndSettle();
    await capture(tester, 'clock-dense-unicode');
    rig.google.offline = true;
    await tester.runAsync(() async {
      await rig.planner.saveDraft(await rig.draft());
    });
    await settlePlanner(tester);
    await tester.ensureVisible(find.textContaining('Waiting to sync').last);
    await capture(tester, 'clock-waiting-to-sync');
    rig.google.offline = false;
    final operation = rig.planner.data.operations.values.single;
    await tester.runAsync(() async {
      await rig.planner.retry(operation.id);
    });
    await settlePlanner(tester);
    final schedule = rig.planner.data.schedules.values.single;
    final draft = rig.planner.editSchedule(schedule)
      ..['title'] = 'Fictional local review';
    rig.google.events[schedule.eventId]!.addAll({
      'summary': 'Fictional Google review',
      'etag': '"review"',
    });
    await tester.runAsync(() async {
      await rig.planner.saveDraft(draft);
    });
    await settlePlanner(tester);
    await tester.ensureVisible(find.text('Review my changes'));
    await capture(tester, 'clock-conflict-review');
    expect(find.text('Review my changes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final spec in [(1067.0, 724.0), (1536.0, 816.0)]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('complete planner dial at ${spec.$1}x${spec.$2}, text $scale', (
        tester,
      ) async {
        await mount(tester, width: spec.$1, height: spec.$2, scale: scale);
        expect(find.byType(PlannerScreen), findsOneWidget);
        final dial = tester.getRect(
          find.byKey(const ValueKey('planner-clock-dial')),
        );
        expect(dial.top, greaterThanOrEqualTo(0));
        expect(dial.bottom, lessThanOrEqualTo(spec.$2));
        expect(dial.width, greaterThanOrEqualTo(240));
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'clock-${spec.$1.toInt()}-${spec.$2.toInt()}-${(scale * 100).toInt()}',
        );
      });
    }
  }

  testWidgets(
    'click 10 PM on the clock and Save once through the production editor',
    (tester) async {
      final (r, _) = await mount(tester);
      final rect = tester.getRect(
        find.byKey(const ValueKey('planner-clock-dial')),
      );
      // 10 PM is 300 degrees clockwise from noon. Click inside an empty sector.
      final center = rect.topLeft + Offset(rect.width / 2, rect.width / 2);
      final angle = -math.pi / 2 + 600 * math.pi / 360;
      await tester.tapAt(
        center + Offset(math.cos(angle), math.sin(angle)) * rect.width * .32,
      );
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(find.byType(PlannerEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-start')))
            .controller!
            .text,
        '22:00',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-end')))
            .controller!
            .text,
        '23:00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('planner-title')),
        'Fictional one-action task',
      );
      await tester.tap(find.byKey(const ValueKey('planner-save')));
      await settlePlanner(tester);
      expect(r.google.inserts, 1);
      expect(r.app.tasks.single.title, 'Fictional one-action task');
      expect(find.byType(PlannerEditor), findsNothing);
      expect(r.planner.selectedDate.toString(), '2026-11-10');
      await capture(tester, 'clock-saved-task');
      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await settlePlanner(tester);
      expect(find.byType(PlannerEditor), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settlePlanner(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'click 10 PM in Calendar opens the same editor with precise fields',
    (tester) async {
      final (r, _) = await mount(tester, calendar: true);
      final calendar = tester.widget<k.KalenderView>(
        find.byType(k.KalenderView),
      );
      final controller =
          calendar.kalenderController.viewController
              as k.MultiDayViewController;
      controller.scrollController.jumpTo(
        22 * 60 * controller.heightPerMinute.value - 100,
      );
      await tester.pumpAndSettle();
      final body = tester.getRect(find.byType(k.MultiDayBody));
      final localStart = calendar
          .kalenderController
          .visibleDateTimeRange
          .value
          .start
          .toLocal();
      final index = DateTime(2026, 11, 10)
          .difference(
            DateTime(localStart.year, localStart.month, localStart.day),
          )
          .inDays;
      final columnWidth = (body.width - 72) / 7;
      final y =
          22 * 60 * controller.heightPerMinute.value -
          controller.scrollController.offset;
      await tester.tapAt(
        Offset(body.left + 72 + columnWidth * (index + .5), body.top + y + .5),
      );
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(find.byType(PlannerEditor), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-date')))
            .controller!
            .text,
        '2026-11-10',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-start')))
            .controller!
            .text,
        '22:00',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('planner-end')))
            .controller!
            .text,
        '23:00',
      );
      await tester.enterText(
        find.byKey(const ValueKey('planner-title')),
        'Fictional Calendar task',
      );
      await tester.tap(find.byKey(const ValueKey('planner-save')));
      await settlePlanner(tester);
      expect(r.google.inserts, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('24-hour, zoom, month and day remain usable in high contrast', (
    tester,
  ) async {
    final (r, desktop) = await mount(
      tester,
      width: 1536,
      height: 816,
      contrast: true,
    );
    r.planner.setClockMode(PlannerClockMode.fullDay);
    await tester.pumpAndSettle();
    await capture(tester, 'clock-24-hour-high-contrast');
    r.planner.setClockMode(PlannerClockMode.threeHours);
    await tester.pumpAndSettle();
    await capture(tester, 'clock-three-hour');
    desktop.navigate(4);
    r.planner.calendarView = PlannerCalendarView.month;
    await tester.pumpAndSettle();
    await tester.runAsync(settleCalendar);
    await tester.pumpAndSettle();
    expect(find.byType(k.MonthBody), findsOneWidget);
    await capture(tester, 'calendar-month');
    r.planner.calendarView = PlannerCalendarView.day;
    r.planner.browse(CalendarDate(2026, 11, 10));
    await tester.pumpAndSettle();
    expect(find.byType(k.MultiDayBody), findsOneWidget);
    await capture(tester, 'calendar-day');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unscheduled Tasks use the shared editor and keep calendar requests empty',
    (tester) async {
      final (r, desktop) = await mount(tester);
      desktop.navigate(1);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tasks-add-task')));
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(find.byType(PlannerEditor), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('planner-title')),
        'Fictional checklist',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(r.app.tasks.single.title, 'Fictional checklist');
      expect(r.google.inserts, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('shared editor fits enlarged text $scale in light appearance', (
      tester,
    ) async {
      await mount(tester, scale: scale, dark: false);
      await tester.tap(find.byKey(const ValueKey('planner-add-task')));
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('planner-title')),
        'Fictional planning task with a long readable title',
      );
      final save = tester.getRect(find.byKey(const ValueKey('planner-save')));
      expect(save.bottom, lessThanOrEqualTo(724));
      await capture(tester, 'editor-light-${(scale * 100).toInt()}');
      expect(tester.takeException(), isNull);
    });
  }
}
