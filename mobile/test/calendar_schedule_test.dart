import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:kalender/kalender.dart' as k;
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/data/calendar_time.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/calendar_schedule_adapter.dart';
import 'package:poma/ui/copy.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_agenda_test.dart' show RecordingCalendarPlatform, meeting;
import 'calendar_read_test.dart' as fixtures;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

class _LocalClock extends fixtures.TestCalendarClock {
  @override
  CalendarWindow dayWindow(CalendarDate day) =>
      const DeviceCalendarClock().dayWindow(day);
  @override
  CalendarWindow window() {
    final local = time.toLocal();
    final first = CalendarDate(local.year, local.month, local.day);
    final until = first.plusDays(7);
    return CalendarWindow(
      first: first,
      until: until,
      startUtc: dayWindow(first).startUtc,
      endUtc: dayWindow(until).startUtc,
    );
  }

  @override
  DateTime nextMidnightUtc() => dayWindow(window().first).endUtc;
}

class _RegionalPlatform extends RecordingCalendarPlatform {
  @override
  Future<Map<String, String>> formatCalendar(
    List<DateTime> instants,
    List<CalendarDate> dates,
  ) async => {
    for (final instant in instants)
      '${instant.microsecondsSinceEpoch}': DateFormat.Hm(
        'en',
      ).format(instant.toLocal()),
    for (final date in dates) '$date': '$date',
  };
}

Future<
  ({
    AppController app,
    DesktopController desktop,
    FakeShell shell,
    fixtures.CalendarRig rig,
    _RegionalPlatform platform,
  })
>
_desktop(WidgetTester tester, {bool selectCalendars = true}) async {
  final r = (await tester.runAsync(
    () => fixtures.rig(testClock: _LocalClock()),
  ))!;
  final day = r.reader.window.first;
  final start = DateTime(day.year, day.month, day.day, 9, 30).toUtc();
  r.provider.items[fixtures.work.id] = [
    meeting(
      'alpha',
      start,
      start.add(const Duration(hours: 1)),
      title: 'Fictional planning 日本語 🧭 Café',
    ),
    meeting(
      'beta',
      start.add(const Duration(minutes: 15)),
      start.add(const Duration(hours: 2)),
      title: 'Fictional overlap',
      response: 'needsAction',
    ),
    CalendarEvent(
      id: 'date-only',
      calendarId: fixtures.work.id,
      title: 'Fictional all-day workshop',
      status: 'tentative',
      selfResponse: 'tentative',
      startDate: day,
      endDate: day.plusDays(2),
    ),
  ];
  if (selectCalendars) await r.reader.select({fixtures.work.id});
  final app = await AppController.create(
    MemoryRepository(),
    clock: FakeClock(),
  );
  final shell = FakeShell();
  final platform = _RegionalPlatform();
  final desktop = DesktopController(
    app,
    shell,
    const DesktopEnvironment(
      dataDirectory: 'synthetic',
      version: 'test',
      packaged: false,
      visible: true,
      sessionState: 'unlocked',
    ),
    connection: r.connection,
    calendarData: r.reader,
    calendarPlatform: platform,
  );
  await desktop.initialize();
  desktop.navigate(4);
  await tester.runAsync(fixtures.settleCalendar);
  return (app: app, desktop: desktop, shell: shell, rig: r, platform: platform);
}

Future<void> _finish(
  WidgetTester tester,
  DesktopController desktop,
  AppController app,
) async {
  await tester.pumpWidget(const SizedBox());
  desktop.dispose();
  app.dispose();
}

Future<void> _capture(WidgetTester tester, String name) async {
  const folder = String.fromEnvironment('POMA_SCHEDULE_SCREENSHOTS');
  if (folder.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('schedule-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$folder/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _showAgenda(WidgetTester tester) async {
  final choice = find.widgetWithText(ChoiceChip, 'Agenda');
  await tester.ensureVisible(choice);
  await tester.pumpAndSettle();
  await tester.tap(choice);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    tz_data.initializeTimeZones();
    await DeviceFormats.initialize();
  });

  test(
    'equal titles, calendar names and recurring instances keep distinct identities',
    () {
      final clock = fixtures.TestCalendarClock();
      final start = clock.nowUtc();
      final first = meeting('same', start, start.add(const Duration(hours: 1)));
      final otherCalendar = meeting(
        'same',
        start,
        start.add(const Duration(hours: 1)),
        calendar: fixtures.team.id,
      );
      final otherInstance = meeting(
        'same',
        start.add(const Duration(days: 1)),
        start.add(const Duration(days: 1, hours: 1)),
      );
      final tiles = [first, otherCalendar, otherInstance]
          .map(
            (e) => PomaScheduleEvent.fromEvent(
              e,
              clock: clock,
              sourceLabel: 'Work',
            ),
          )
          .toList();
      expect(tiles.map((e) => e.id).toSet(), hasLength(3));
      expect(tiles.first.start, first.startUtc);
      expect(tiles.first.end, first.endUtc);
      expect(tiles.first.interaction.allowStartResize, isFalse);
      expect(tiles.first.interaction.allowEndResize, isFalse);
      expect(tiles.first.interaction.allowRescheduling, isFalse);
    },
  );

  test(
    'all-day dates retain exclusive ends across 23-hour and 25-hour days',
    () {
      for (final date in [
        CalendarDate(2026, 3, 8),
        CalendarDate(2026, 11, 1),
      ]) {
        final clock = fixtures.TestCalendarClock(location: 'America/New_York');
        final event = CalendarEvent(
          id: '$date',
          calendarId: 'work',
          title: 'Date only',
          status: 'confirmed',
          selfResponse: 'accepted',
          startDate: date,
          endDate: date.plusDays(1),
        );
        final tile = PomaScheduleEvent.fromEvent(
          event,
          clock: clock,
          sourceLabel: 'Work',
        );
        expect(tile.isAllDay, isTrue);
        expect(tile.start, clock.dayWindow(date).startUtc);
        expect(tile.end, clock.dayWindow(date).endUtc);
        expect(tile.duration.inHours, date.month == 3 ? 23 : 25);
        expect('${tile.event.endDate}', '${date.plusDays(1)}');
      }
    },
  );

  test(
    'timed DST, overnight and multi-day events preserve exact UTC instants',
    () {
      final clock = fixtures.TestCalendarClock(location: 'America/New_York');
      for (final range in [
        (DateTime.utc(2026, 11, 1, 5, 30), DateTime.utc(2026, 11, 1, 6, 30)),
        (DateTime.utc(2026, 11, 1, 3), DateTime.utc(2026, 11, 1, 8)),
        (DateTime.utc(2026, 11, 1, 3), DateTime.utc(2026, 11, 3, 8)),
      ]) {
        final tile = PomaScheduleEvent.fromEvent(
          meeting('timed', range.$1, range.$2),
          clock: clock,
          sourceLabel: 'Work',
        );
        expect(tile.start, range.$1);
        expect(tile.end, range.$2);
        expect(tile.isAllDay, isFalse);
      }
    },
  );

  test(
    'rolling page covers exactly seven retained dates; Day has seven bounded pages',
    () {
      final clock = fixtures.TestCalendarClock(
        time: DateTime.utc(2026, 11, 5, 12),
      );
      final window = clock.window();
      final week = scheduleViewConfiguration(
        window,
        sevenDays: true,
        selectedDate: clock.nowUtc(),
      );
      final calculator = week.pageIndexCalculator;
      expect(calculator.numberOfPages(tz.UTC), 1);
      final page = calculator.rangeFromIndex(0, tz.UTC);
      expect(page.start.forLocation(location: tz.UTC), window.startUtc);
      expect(page.end.forLocation(location: tz.UTC), window.endUtc);
      expect(week.type, k.MultiDayViewType.custom);
      final day = scheduleViewConfiguration(
        window,
        sevenDays: false,
        selectedDate: clock.nowUtc(),
      );
      expect(day.pageIndexCalculator.numberOfPages(tz.UTC), 7);
      expect(
        day.pageIndexCalculator.indexFromDate(
          window.startUtc.subtract(const Duration(days: 1)),
          tz.UTC,
        ),
        0,
      );
      expect(day.pageIndexCalculator.indexFromDate(window.endUtc, tz.UTC), 6);
    },
  );

  for (final width in [640.0, 1080.0, 1440.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'Schedule fits $width pixels at ${scale * 100}% text',
        (tester) async {
          tester.view.physicalSize = Size(width, 1100);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final r = await _desktop(tester);
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('schedule-capture'),
              child: PomaApp(controller: r.app, desktop: r.desktop),
            ),
          );
          await tester.pumpAndSettle();
          final timeline = scale == 1;
          expect(
            find.byKey(
              ValueKey(timeline ? 'schedule-timeline' : 'schedule-agenda'),
            ),
            findsOneWidget,
          );
          expect(r.desktop.calendarSection, CalendarPageSection.schedule);
          expect(find.text('Schedule verified'), findsOneWidget);
          expect(r.rig.connection.focusWriteEnabled, isFalse);
          if (timeline) {
            final configuration =
                tester
                        .widget<k.KalenderView>(find.byType(k.KalenderView))
                        .kalenderController
                        .viewConfiguration
                    as k.MultiDayViewConfiguration;
            expect(configuration.numberOfDays, width == 640 ? 1 : 7);
          }
          await tester.ensureVisible(
            find.byKey(
              ValueKey(timeline ? 'schedule-timeline' : 'schedule-agenda'),
            ),
          );
          await tester.pumpAndSettle();
          await _capture(
            tester,
            'schedule-${width.toInt()}-${(scale * 100).toInt()}',
          );
          expect(tester.takeException(), isNull);
          await _finish(tester, r.desktop, r.app);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }

  testWidgets(
    'Day controls bound navigation and controllers survive timer and refresh rebuilds',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = await _desktop(tester);
      await tester.pumpWidget(PomaApp(controller: r.app, desktop: r.desktop));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Day'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Day'));
      await tester.pumpAndSettle();
      final calendar = tester.widget<k.KalenderView>(
        find.byType(k.KalenderView),
      );
      final previous = find.widgetWithIcon(IconButton, Icons.chevron_left);
      final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
      expect(tester.widget<IconButton>(previous).onPressed, isNull);
      for (var i = 0; i < 6; i++) {
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(tester.widget<IconButton>(next).onPressed, isNull);
      final before = calendar.kalenderController.visibleDateTimeRange.value;
      r.app.addTask('Fictional timer-independent task');
      await r.rig.reader.refresh(manual: true);
      await tester.pumpAndSettle();
      final rebuilt = tester.widget<k.KalenderView>(
        find.byType(k.KalenderView),
      );
      expect(
        identical(rebuilt.kalenderController, calendar.kalenderController),
        isTrue,
      );
      expect(
        identical(rebuilt.eventsController, calendar.eventsController),
        isTrue,
      );
      expect(rebuilt.kalenderController.visibleDateTimeRange.value, before);
      expect(r.app.timer.status.name, 'ready');
      expect(rebuilt.interaction!.allowEventCreation, isFalse);
      expect(rebuilt.interaction!.allowRescheduling, isFalse);
      expect(rebuilt.interaction!.allowResizing, isFalse);
      final parts = rebuilt.views.single as k.MultiDayViewParts;
      expect(
        (parts.header as k.MultiDayHeader).interaction!.allowEventCreation,
        isFalse,
      );
      expect(
        (parts.body as k.MultiDayBody).interaction!.allowResizing,
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await _finish(tester, r.desktop, r.app);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'event details reuse validated links; lock clears details and accessible titles',
    (tester) async {
      final r = await _desktop(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(PomaApp(controller: r.app, desktop: r.desktop));
      await tester.pumpAndSettle();
      await _showAgenda(tester);
      final event = find.text('Fictional planning 日本語 🧭 Café').first;
      await tester.ensureVisible(event);
      await tester.pumpAndSettle();
      await tester.tap(event);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(r.platform.opened.single.$2, 'join');
      await tester.runAsync(
        () => r.shell.onEvent!('sessionState', {'state': 'locked'}),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Fictional planning'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Fictional planning')), findsNothing);
      await tester.runAsync(
        () => r.shell.onEvent!('sessionState', {'state': 'unlocked'}),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(r.platform.opened, hasLength(1));
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await _finish(tester, r.desktop, r.app);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'refresh replaces tiles; deselection invalidates details before storage commits',
    (tester) async {
      final r = await _desktop(tester);
      await tester.pumpWidget(PomaApp(controller: r.app, desktop: r.desktop));
      await tester.pumpAndSettle();
      r.rig.provider.items[fixtures.work.id]!.removeWhere(
        (e) => e.id == 'beta',
      );
      await r.rig.reader.refresh(manual: true);
      await tester.pumpAndSettle();
      expect(find.text('Fictional overlap'), findsNothing);
      await _showAgenda(tester);
      final event = find.text('Fictional planning 日本語 🧭 Café').first;
      await tester.ensureVisible(event);
      await tester.pumpAndSettle();
      await tester.tap(event);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      final gate = Completer<void>();
      r.rig.cache.nextWrite = gate;
      final selecting = r.rig.reader.select({});
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Fictional planning'), findsNothing);
      gate.complete();
      await selecting;
      await tester.pumpAndSettle();
      expect(find.text('No calendars selected'), findsOneWidget);
      expect(r.platform.opened, isEmpty);
      await _finish(tester, r.desktop, r.app);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'stale, partial and failed calendars never report an empty verified day',
    (tester) async {
      final r = await _desktop(tester);
      r.rig.provider.items[fixtures.work.id] = [];
      await r.rig.reader.refresh(manual: true);
      await tester.pumpWidget(PomaApp(controller: r.app, desktop: r.desktop));
      await tester.pumpAndSettle();
      await _showAgenda(tester);
      expect(find.text('No events on this verified day.'), findsNWidgets(7));
      r.rig.clock.time = r.rig.clock.time.add(const Duration(minutes: 6));
      r.rig.provider.errors[fixtures.work.id] = const CalendarReadFailure(
        CalendarReadFailureKind.network,
      );
      await r.rig.reader.refresh(manual: true);
      await tester.pumpAndSettle();
      expect(find.text('No events on this verified day.'), findsNothing);
      expect(
        find.text(
          'Missing or stale calendar data does not mean that time is free.',
        ),
        findsOneWidget,
      );
      await _finish(tester, r.desktop, r.app);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final highContrast in [false, true]) {
    testWidgets(
      'dark Schedule renders with high contrast $highContrast',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1100);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(highContrast: highContrast);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final r = await _desktop(tester);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('schedule-capture'),
            child: PomaApp(controller: r.app, desktop: r.desktop),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('schedule-timeline')),
        );
        await tester.pumpAndSettle();
        await _capture(
          tester,
          highContrast ? 'schedule-dark-high-contrast' : 'schedule-dark',
        );
        if (highContrast) {
          final context = tester.element(find.byType(k.KalenderView));
          expect(
            k.KalenderTheme.of(context).hourLinesStyle!.color,
            Theme.of(context).colorScheme.outline,
          );
          expect(
            k.KalenderTheme.of(context).daySeparatorStyle!.color,
            Theme.of(context).colorScheme.outline,
          );
        }
        expect(tester.takeException(), isNull);
        await _finish(tester, r.desktop, r.app);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  testWidgets(
    'overlapping tiles are side by side; dragging and empty-space taps cannot write',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = await _desktop(tester);
      await tester.pumpWidget(PomaApp(controller: r.app, desktop: r.desktop));
      await tester.pumpAndSettle();
      final entries = r.rig.reader.events.where((e) => !e.allDay).toList();
      final alpha = find.byKey(
        ValueKey('tile-${scheduleEventIdentity(entries[0])}'),
      );
      final beta = find.byKey(
        ValueKey('tile-${scheduleEventIdentity(entries[1])}'),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('schedule-timeline')),
      );
      await tester.pumpAndSettle();
      final a = tester.getRect(alpha), b = tester.getRect(beta);
      expect(a.right <= b.left + 1 || b.right <= a.left + 1, isTrue);
      final before = entries.map((e) => e.toJson().toString()).toList();
      await tester.drag(alpha, const Offset(100, 70));
      await tester.pumpAndSettle();
      final bounds = tester.getRect(
        find.byKey(const ValueKey('schedule-timeline')),
      );
      await tester.tapAt(bounds.topRight + const Offset(-30, 150));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        r.rig.reader.events
            .where((e) => !e.allDay)
            .map((e) => e.toJson().toString()),
        before,
      );
      expect(r.rig.connection.focusWriteEnabled, isFalse);
      expect(r.app.timer.status.name, 'ready');
      await _finish(tester, r.desktop, r.app);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  testWidgets(
    'retained events remain during refresh; disconnect clears the open event',
    (tester) async {
      final r = await _desktop(tester);
      await tester.pumpWidget(PomaApp(controller: r.app, desktop: r.desktop));
      await tester.pumpAndSettle();
      await _showAgenda(tester);
      final delayed = Completer<List<CalendarEvent>>();
      r.rig.provider.onEvents = (_, _) => delayed.future;
      final refreshing = r.rig.reader.refresh(manual: true);
      await tester.pump();
      expect(find.text('Fictional planning 日本語 🧭 Café'), findsOneWidget);
      expect(find.text('Refreshing calendar'), findsOneWidget);
      delayed.complete(r.rig.provider.items[fixtures.work.id]!);
      await refreshing;
      await tester.pumpAndSettle();
      final entry = find.text('Fictional planning 日本語 🧭 Café');
      await tester.ensureVisible(entry);
      await tester.pumpAndSettle();
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await r.rig.connection.disconnect();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('Fictional planning'), findsNothing);
      expect(r.platform.opened, isEmpty);
      await _finish(tester, r.desktop, r.app);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );

  for (final width in [640.0, 1440.0]) {
    testWidgets(
      'explicit Calendar destinations and visual-order shortcuts at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final r = await _desktop(tester);
        await tester.pumpWidget(PomaApp(controller: r.app, desktop: r.desktop));
        await tester.pumpAndSettle();
        await r.shell.onEvent!('settings', {});
        await tester.pumpAndSettle();
        expect(r.desktop.destination, 4);
        expect(r.desktop.calendarSection, CalendarPageSection.settings);
        r.desktop.openCalendarSection(CalendarPageSection.focusBlocks);
        await tester.pumpAndSettle();
        expect(find.text('Choose a task'), findsOneWidget);
        for (final entry in [
          (LogicalKeyboardKey.digit3, 4),
          (LogicalKeyboardKey.digit4, 2),
          (LogicalKeyboardKey.digit5, 3),
        ]) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(entry.$1);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(r.desktop.destination, entry.$2);
          if (entry.$2 == 4) {
            expect(r.desktop.calendarSection, CalendarPageSection.schedule);
          }
        }
        await _finish(tester, r.desktop, r.app);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }

  for (final width in [640.0, 1080.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'calendar frame stays visible before selection at $width / $scale',
        (tester) async {
          tester.view.physicalSize = Size(width, 755);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final r = await _desktop(tester, selectCalendars: false);
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('schedule-capture'),
              child: PomaApp(controller: r.app, desktop: r.desktop),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.widgetWithText(ChoiceChip, 'Day'), findsOneWidget);
          expect(
            find.widgetWithText(ChoiceChip, 'Next 7 days'),
            findsOneWidget,
          );
          expect(
            find.text('Calendar not loaded. Your availability is unknown.'),
            findsOneWidget,
          );
          expect(find.text('No events on this verified day.'), findsNothing);
          if (scale == 1) {
            expect(
              find.byKey(const ValueKey('schedule-timeline')),
              findsOneWidget,
            );
            expect(find.text('Not loaded'), findsWidgets);
            final configuration =
                tester
                        .widget<k.KalenderView>(find.byType(k.KalenderView))
                        .kalenderController
                        .viewConfiguration
                    as k.MultiDayViewConfiguration;
            expect(configuration.numberOfDays, width == 640 ? 1 : 7);
            if (width == 1080) {
              expect(
                tester
                    .getTopLeft(find.byKey(const ValueKey('schedule-timeline')))
                    .dy,
                lessThan(500),
              );
            }
          } else {
            expect(
              find.byKey(const ValueKey('schedule-agenda')),
              findsOneWidget,
            );
          }
          expect(r.rig.reader.selected, isEmpty);
          expect(r.rig.provider.requests, isEmpty);
          expect(r.rig.connection.focusWriteEnabled, isFalse);
          await _capture(
            tester,
            'before-selection-${width.toInt()}-${(scale * 100).toInt()}',
          );
          expect(tester.takeException(), isNull);
          await _finish(tester, r.desktop, r.app);
        },
        variant: TargetPlatformVariant.only(TargetPlatform.windows),
      );
    }
  }
}
