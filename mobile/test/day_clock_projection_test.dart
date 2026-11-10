import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

CalendarEvent block(
  String id,
  DateTime start,
  DateTime end, {
  String status = 'confirmed',
  String response = 'accepted',
  String? series,
  String? original,
}) => CalendarEvent(
  id: id,
  calendarId: 'fictional',
  title: id,
  status: status,
  selfResponse: response,
  startUtc: start,
  endUtc: end,
  recurringEventId: series,
  originalStart: original,
);

DayClockWindow window(
  CalendarDate date,
  DayClockHalf half, {
  tz.Location? location,
}) {
  final zone = location ?? tz.UTC, until = date.plusDays(1);
  return DayClockWindow.build(
    date: date,
    half: half,
    day: CalendarWindow(
      first: date,
      until: until,
      startUtc: tz.TZDateTime(zone, date.year, date.month, date.day).toUtc(),
      endUtc: tz.TZDateTime(zone, until.year, until.month, until.day).toUtc(),
    ),
    localize: (utc) => tz.TZDateTime.from(utc, zone),
  );
}

void main() {
  setUpAll(tz_data.initializeTimeZones);
  test(
    'PM actual positions, gaps and hand share a conventional clock scale',
    () {
      final p = DayClockProjection.project(
        window: window(CalendarDate(2026, 11, 10), DayClockHalf.pm),
        events: [
          block(
            'late',
            DateTime.utc(2026, 11, 10, 22),
            DateTime.utc(2026, 11, 10, 23),
          ),
          block(
            'lunch',
            DateTime.utc(2026, 11, 10, 12, 30),
            DateTime.utc(2026, 11, 10, 13, 30),
          ),
        ],
        nowUtc: DateTime.utc(2026, 11, 10, 22, 30),
      );
      final late = p.sectors.singleWhere((s) => s.event.id == 'late');
      expect(late.startMinute, 600);
      expect(late.endMinute, 660);
      expect(late.sweep, closeTo(math.pi / 6, 1e-9));
      expect(p.handAngle, closeTo(dayClockAngle(630), 1e-9));
      expect(p.scheduled, const Duration(hours: 2));
      expect(p.agenda.map((e) => e.id), ['lunch', 'late']);
      expect(p.sectors.every((s) => s.laneCount == 1), isTrue);
    },
  );
  test(
    'exclusive noon and midnight clipping retain original endpoints and identity',
    () {
      final noon = block(
        'noon',
        DateTime.utc(2026, 11, 10, 11, 30),
        DateTime.utc(2026, 11, 10, 12, 30),
      );
      final night = block(
        'night',
        DateTime.utc(2026, 11, 10, 23, 30),
        DateTime.utc(2026, 11, 11, 0, 30),
      );
      DayClockProjection project(CalendarDate date, DayClockHalf half) =>
          DayClockProjection.project(
            window: window(date, half),
            events: [noon, night],
            nowUtc: DateTime.utc(2026, 11, 10, 11, 45),
          );
      final am = project(CalendarDate(2026, 11, 10), DayClockHalf.am);
      final pm = project(CalendarDate(2026, 11, 10), DayClockHalf.pm);
      final tomorrow = project(CalendarDate(2026, 11, 11), DayClockHalf.am);
      expect(am.sectors.single.startMinute, 690);
      expect(am.sectors.single.endMinute, 720);
      expect(pm.sectors.firstWhere((s) => s.event.id == 'noon').startMinute, 0);
      expect(pm.sectors.firstWhere((s) => s.event.id == 'noon').endMinute, 30);
      expect(tomorrow.sectors.single.startMinute, 0);
      expect(tomorrow.sectors.single.endMinute, 30);
      expect(identical(tomorrow.sectors.single.event, night), isTrue);
      expect(pm.handAngle, isNull);
      expect(tomorrow.handAngle, isNull);
    },
  );
  test(
    'all-day exclusive dates and cancelled/declined instances stay off the dial',
    () {
      final all = CalendarEvent(
        id: 'all',
        calendarId: 'fictional',
        title: 'All day',
        status: 'confirmed',
        selfResponse: 'accepted',
        startDate: CalendarDate(2026, 11, 9),
        endDate: CalendarDate(2026, 11, 11),
      );
      final events = [
        all,
        block(
          'cancelled',
          DateTime.utc(2026, 11, 10, 13),
          DateTime.utc(2026, 11, 10, 14),
          status: 'cancelled',
        ),
        block(
          'declined',
          DateTime.utc(2026, 11, 10, 13),
          DateTime.utc(2026, 11, 10, 14),
          response: 'declined',
        ),
      ];
      final p = DayClockProjection.project(
        window: window(CalendarDate(2026, 11, 10), DayClockHalf.pm),
        events: events,
        nowUtc: DateTime.utc(2026, 11, 10, 12),
      );
      expect(p.sectors, isEmpty);
      expect(p.allDay, [all]);
      expect(p.scheduled, Duration.zero);
      expect(
        DayClockProjection.project(
          window: window(CalendarDate(2026, 11, 11), DayClockHalf.am),
          events: events,
          nowUtc: DateTime.utc(2026, 11, 11),
        ).allDay,
        isEmpty,
      );
    },
  );
  test(
    'dense lanes are stable on reorder and refresh, while totals merge overlaps',
    () {
      final events = List.generate(
        7,
        (i) => block(
          'event-$i',
          DateTime.utc(2026, 11, 10, 13),
          DateTime.utc(2026, 11, 10, 14 + i % 2),
          series: 'series',
          original: 'instance-$i',
        ),
      );
      final w = window(CalendarDate(2026, 11, 10), DayClockHalf.pm);
      final p = DayClockProjection.project(
        window: w,
        events: events,
        nowUtc: DateTime.utc(2026, 11, 10, 12),
      );
      final reordered = DayClockProjection.project(
        window: w,
        events: events.reversed,
        nowUtc: DateTime.utc(2026, 11, 10, 12),
        previousLanes: p.lanes,
      );
      expect(reordered.lanes, p.lanes);
      expect(p.agenda.length, 7);
      expect(p.sectors.map((s) => s.lane).toSet().length, 7);
      expect(p.sectors.every((s) => s.laneCount == 7), isTrue);
      expect(p.scheduled, const Duration(hours: 2));
      final survivor = p.sectors.firstWhere((s) => s.lane == 6).event;
      final collapsed = DayClockProjection.project(
        window: w,
        events: [survivor],
        nowUtc: DateTime.utc(2026, 11, 10, 12),
        previousLanes: p.lanes,
      );
      expect(collapsed.sectors.single.lane, 0);
      expect(collapsed.sectors.single.laneCount, 1);
      final added = DayClockProjection.project(
        window: w,
        events: [
          ...events,
          block(
            'earlier',
            DateTime.utc(2026, 11, 10, 12, 30),
            DateTime.utc(2026, 11, 10, 13, 30),
          ),
        ],
        nowUtc: DateTime.utc(2026, 11, 10, 12),
        previousLanes: p.lanes,
      );
      for (final entry in p.lanes.entries) {
        expect(added.lanes[entry.key], entry.value);
      }
    },
  );
  test('touching exclusive endpoints reuse a full-depth sector', () {
    final p = DayClockProjection.project(
      window: window(CalendarDate(2026, 11, 10), DayClockHalf.pm),
      events: [
        block(
          'a',
          DateTime.utc(2026, 11, 10, 13),
          DateTime.utc(2026, 11, 10, 14),
        ),
        block(
          'b',
          DateTime.utc(2026, 11, 10, 14),
          DateTime.utc(2026, 11, 10, 15),
        ),
      ],
      nowUtc: DateTime.utc(2026, 11, 10),
    );
    expect(p.sectors.every((s) => s.lane == 0 && s.laneCount == 1), isTrue);
  });
  test('DST spring gap preserves wall positions and exact elapsed totals', () {
    final w = window(
      CalendarDate(2026, 3, 8),
      DayClockHalf.am,
      location: tz.getLocation('America/New_York'),
    );
    expect(
      w.slices.fold(
        Duration.zero,
        (n, s) => n + s.endUtc.difference(s.startUtc),
      ),
      const Duration(hours: 11),
    );
    final gap = w.transitions.single;
    expect(gap.start, 120);
    expect(gap.end, 180);
    expect(gap.repeated, isFalse);
    final p = DayClockProjection.project(
      window: w,
      events: [
        block(
          'spring',
          DateTime.utc(2026, 3, 8, 6, 30),
          DateTime.utc(2026, 3, 8, 7, 30),
        ),
      ],
      nowUtc: DateTime.utc(2026, 3, 8, 7, 15),
    );
    expect(p.sectors.map((s) => (s.startMinute, s.endMinute)), [
      (90.0, 120.0),
      (180.0, 210.0),
    ]);
    expect(p.scheduled, const Duration(hours: 1));
    expect(p.handAngle, dayClockAngle(195));
  });
  test(
    'DST fall occurrences use separate lanes and explicit offset identity',
    () {
      final w = window(
        CalendarDate(2026, 11, 1),
        DayClockHalf.am,
        location: tz.getLocation('America/New_York'),
      );
      expect(
        w.slices.fold(
          Duration.zero,
          (n, s) => n + s.endUtc.difference(s.startUtc),
        ),
        const Duration(hours: 13),
      );
      final fold = w.transitions.single;
      expect(fold.start, 60);
      expect(fold.end, 120);
      expect(fold.repeated, isTrue);
      final p = DayClockProjection.project(
        window: w,
        events: [
          block(
            'first',
            DateTime.utc(2026, 11, 1, 5, 15),
            DateTime.utc(2026, 11, 1, 5, 45),
          ),
          block(
            'second',
            DateTime.utc(2026, 11, 1, 6, 15),
            DateTime.utc(2026, 11, 1, 6, 45),
          ),
        ],
        nowUtc: DateTime.utc(2026, 11, 1, 6, 30),
      );
      expect(p.sectors.map((s) => s.startMinute).toSet(), {75.0});
      expect(p.sectors.map((s) => s.offsetMinutes).toSet(), {-240, -300});
      expect(p.sectors.map((s) => s.lane).toSet(), {0, 1});
      expect(p.scheduled, const Duration(hours: 1));
      expect(p.handAngle, dayClockAngle(90));
    },
  );
}
