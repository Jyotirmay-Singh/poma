import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:poma/domain/planner.dart';
import 'package:poma/data/planner_time.dart';
import 'package:poma/ui/day_clock_dial.dart';
import 'package:poma/ui/planner_dial.dart';
import 'package:timezone/timezone.dart' as tz;

import 'planner_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => PlannerTime().initialize());
  final window = DayClockWindow(
    CalendarDate(2026, 11, 1),
    DayClockHalf.am,
    [
      DayClockTimeSlice(
        DateTime.utc(2026, 11, 1, 5),
        DateTime.utc(2026, 11, 1, 6),
        60,
        120,
        -240,
      ),
      DayClockTimeSlice(
        DateTime.utc(2026, 11, 1, 6),
        DateTime.utc(2026, 11, 1, 7),
        60,
        120,
        -300,
      ),
    ],
    const [DayClockWallSpan(60, 120, repeated: true)],
  );

  Future<DayClockProjection> mount(
    WidgetTester tester, {
    List<CalendarEvent> events = const [],
    DayClockWindow? displayedWindow,
    bool selectEvent = false,
    required ValueChanged<DateTime> onAdd,
    required void Function(CalendarEvent, DateTime?) onEvent,
    void Function(CalendarEvent, DateTime, DateTime)? onMove,
  }) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final rig = (await tester.runAsync(
      () => plannerRig(time: PlannerTime(fixedZone: 'America/New_York')),
    ))!;
    addTearDown(rig.dispose);
    if (selectEvent) rig.planner.select(events.single);
    final projection = DayClockProjection.project(
      window: displayedWindow ?? window,
      events: events,
      nowUtc: DateTime.utc(2026, 11, 2),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 740,
              child: PlannerDial(
                planner: rig.planner,
                projection: projection,
                colors: const {},
                labels: null,
                onAdd: onAdd,
                onEvent: onEvent,
                onContext: (_, _, _) {},
                onMove: (event, start, end) async {
                  onMove?.call(event, start, end);
                  return false;
                },
                onEdit: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    return projection;
  }

  Offset atFold(Rect rect, double radius) =>
      rect.topLeft +
      Offset(rect.width / 2, rect.width / 2) +
      Offset(math.cos(dayClockAngle(90)), math.sin(dayClockAngle(90))) * radius;

  final foldTime = DateFormat.jm().format(DateTime.utc(2026, 11, 1, 1, 30));
  final firstOffset = '$foldTime · UTC-04:00';
  final secondOffset = '$foldTime · UTC-05:00';

  DayClockWindow localWindow(CalendarDate date, {int span = 720}) {
    final zone = tz.getLocation('America/New_York');
    return DayClockWindow.build(
      date: date,
      half: DayClockHalf.am,
      day: CalendarWindow(
        first: date,
        until: date.plusDays(1),
        startUtc: plannerUtcInstant(
          tz.TZDateTime(zone, date.year, date.month, date.day),
        ),
        endUtc: plannerUtcInstant(
          tz.TZDateTime(zone, date.year, date.month, date.day + 1),
        ),
      ),
      localize: (instant) => tz.TZDateTime.from(instant, zone),
      spanMinutes: span,
    );
  }

  CalendarEvent movable(DateTime start, DateTime end) => CalendarEvent(
    id: 'fictional-move',
    calendarId: 'synthetic-primary',
    title: 'Fictional movable event',
    status: 'confirmed',
    selfResponse: 'accepted',
    startUtc: start,
    endUtc: end,
    etag: '"fictional-version"',
    organizerSelf: true,
  );

  Offset position(Rect rect, double minute, double radius) =>
      rect.topLeft +
      Offset(rect.width / 2, rect.width / 2) +
      DayClockGeometry.direction(dayClockAngle(minute)) * radius;

  Future<TestGesture> movePointer(
    WidgetTester tester,
    DayClockProjection projection,
    double from,
    double to,
  ) async {
    final rect = tester.getRect(
      find.byKey(const ValueKey('planner-clock-dial')),
    );
    final geometry = DayClockGeometry(
      Size.square(rect.width),
      TextScaler.noScaling,
    );
    final radii = geometry.radii(projection.sectors.first);
    final radius = (radii.$1 + radii.$2) / 2;
    final gesture = await tester.startGesture(position(rect, from, radius));
    await gesture.moveTo(position(rect, from + 5, radius));
    await tester.pump();
    await gesture.moveTo(position(rect, to, radius));
    await tester.pump();
    return gesture;
  }

  testWidgets('empty fold placement offers both numeric offsets', (
    tester,
  ) async {
    DateTime? added;
    await mount(tester, onAdd: (value) => added = value, onEvent: (_, _) {});
    final rect = tester.getRect(
      find.byKey(const ValueKey('planner-clock-dial')),
    );
    await tester.tapAt(atFold(rect, rect.width * .32));
    await tester.pumpAndSettle();
    expect(added, isNull);
    expect(find.text(firstOffset), findsOneWidget);
    expect(find.text(secondOffset), findsOneWidget);
    await tester.tap(find.text(secondOffset));
    await tester.pumpAndSettle();
    expect(added, DateTime.utc(2026, 11, 1, 6, 30));
  });

  testWidgets(
    'occupied folds retain inspection identity and Add task offset choice',
    (tester) async {
      final event = CalendarEvent(
        id: 'fictional-second-fold',
        calendarId: 'synthetic-primary',
        title: 'Second fold instance',
        status: 'confirmed',
        selfResponse: 'accepted',
        startUtc: DateTime.utc(2026, 11, 1, 6),
        endUtc: DateTime.utc(2026, 11, 1, 7),
      );
      DateTime? added, inspected;
      final projection = await mount(
        tester,
        events: [event],
        onAdd: (value) => added = value,
        onEvent: (_, value) => inspected = value,
      );
      final rect = tester.getRect(
        find.byKey(const ValueKey('planner-clock-dial')),
      );
      final geometry = DayClockGeometry(
        Size.square(rect.width),
        TextScaler.noScaling,
      );
      final radii = geometry.radii(projection.sectors.single);
      await tester.tapAt(atFold(rect, (radii.$1 + radii.$2) / 2));
      await tester.pumpAndSettle();
      expect(inspected, DateTime.utc(2026, 11, 1, 6, 30));
      await tester.tapAt(atFold(rect, geometry.overflowRadius));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Add task here'));
      await tester.pumpAndSettle();
      expect(added, isNull);
      expect(find.text(firstOffset), findsOneWidget);
      expect(find.text(secondOffset), findsOneWidget);
      await tester.tap(find.text(secondOffset));
      await tester.pumpAndSettle();
      expect(added, DateTime.utc(2026, 11, 1, 6, 30));
    },
  );

  testWidgets('clock movement follows spring wall time and rejects a gap', (
    tester,
  ) async {
    final event = movable(
      DateTime.utc(2026, 3, 8, 6),
      DateTime.utc(2026, 3, 8, 6, 30),
    );
    DateTime? movedStart, movedEnd;
    final projection = await mount(
      tester,
      displayedWindow: localWindow(CalendarDate(2026, 3, 8)),
      events: [event],
      selectEvent: true,
      onAdd: (_) {},
      onEvent: (_, _) {},
      onMove: (_, start, end) {
        movedStart = start;
        movedEnd = end;
      },
    );
    var gesture = await movePointer(tester, projection, 75, 135);
    expect(find.textContaining('This time is unavailable'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(movedStart, isNull);
    gesture = await movePointer(tester, projection, 75, 195);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(movedStart, DateTime.utc(2026, 3, 8, 7));
    expect(movedEnd, DateTime.utc(2026, 3, 8, 7, 30));
  });

  testWidgets('moving into a fold asks which offset before saving', (
    tester,
  ) async {
    final event = movable(
      DateTime.utc(2026, 11, 1, 4),
      DateTime.utc(2026, 11, 1, 4, 30),
    );
    DateTime? movedStart;
    final projection = await mount(
      tester,
      displayedWindow: localWindow(CalendarDate(2026, 11, 1)),
      events: [event],
      selectEvent: true,
      onAdd: (_) {},
      onEvent: (_, _) {},
      onMove: (_, start, _) => movedStart = start,
    );
    final gesture = await movePointer(tester, projection, 15, 75);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(movedStart, isNull);
    expect(find.text('This time occurs twice'), findsOneWidget);
    final targetTime = DateFormat.jm().format(DateTime.utc(2026, 11, 1, 1, 15));
    await tester.tap(find.text('$targetTime · UTC-05:00'));
    await tester.pumpAndSettle();
    expect(movedStart, DateTime.utc(2026, 11, 1, 6));
  });

  testWidgets('24-hour movement across midnight advances the date', (
    tester,
  ) async {
    final event = movable(
      DateTime.utc(2026, 11, 12, 4),
      DateTime.utc(2026, 11, 12, 5),
    );
    DateTime? movedStart;
    final projection = await mount(
      tester,
      displayedWindow: localWindow(CalendarDate(2026, 11, 11), span: 1440),
      events: [event],
      selectEvent: true,
      onAdd: (_) {},
      onEvent: (_, _) {},
      onMove: (_, start, _) => movedStart = start,
    );
    final gesture = await movePointer(tester, projection, 705, 15);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(movedStart, DateTime.utc(2026, 11, 12, 5));
  });

  testWidgets(
    'end handle crosses the clock boundary and Escape cancels a drag',
    (tester) async {
      final event = movable(
        DateTime.utc(2026, 11, 11, 16),
        DateTime.utc(2026, 11, 11, 17),
      );
      DateTime? movedStart, movedEnd;
      final projection = await mount(
        tester,
        displayedWindow: localWindow(CalendarDate(2026, 11, 11)),
        events: [event],
        selectEvent: true,
        onAdd: (_) {},
        onEvent: (_, _) {},
        onMove: (_, start, end) {
          movedStart = start;
          movedEnd = end;
        },
      );
      var gesture = await movePointer(tester, projection, 720, 60);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(movedStart, event.startUtc);
      expect(movedEnd, DateTime.utc(2026, 11, 11, 18));
      movedStart = null;
      gesture = await movePointer(tester, projection, 690, 600);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(movedStart, isNull);
    },
  );
}
