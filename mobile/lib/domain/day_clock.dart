import 'dart:math' as math;

import 'calendar_data.dart';

enum DayClockHalf { am, pm }

double dayClockAngle(double minute) => -math.pi / 2 + minute * math.pi / 360;

/// An offset-constant UTC interval mapped onto the civil clock. A fold can have
/// two slices at the same angle; a skipped hour has no corresponding slice.
class DayClockTimeSlice {
  const DayClockTimeSlice(
    this.startUtc,
    this.endUtc,
    this.startMinute,
    this.endMinute,
    this.offsetMinutes,
  );
  final DateTime startUtc, endUtc;
  final double startMinute, endMinute;
  final int offsetMinutes;
}

class DayClockWallSpan {
  const DayClockWallSpan(this.start, this.end, {this.repeated = false});
  final double start, end;
  final bool repeated;
}

class DayClockWindow {
  const DayClockWindow(
    this.date,
    this.half,
    this.slices,
    this.transitions, {
    this.minutesPerElapsedMinute = 1,
    this.startMinute = 0,
    this.spanMinutes = 720,
  });
  final CalendarDate date;
  final DayClockHalf half;
  final List<DayClockTimeSlice> slices;
  final List<DayClockWallSpan> transitions;
  final double minutesPerElapsedMinute;
  final int startMinute, spanMinutes;

  /// Boundary rules are supplied by the existing device calendar owner. Walking
  /// minute-resolution instants detects real gaps/folds without a fixed-length
  /// local half-day or a second timezone database in production.
  factory DayClockWindow.build({
    required CalendarDate date,
    required DayClockHalf half,
    required CalendarWindow day,
    required DateTime Function(DateTime) localize,
    int? startMinute,
    int spanMinutes = 720,
  }) {
    final begin = startMinute ?? (half == DayClockHalf.am ? 0 : 720);
    final scale = 720 / spanMinutes;
    final slices = <DayClockTimeSlice>[];
    DateTime? first;
    var firstMinute = 0.0, lastMinute = 0.0;
    int? offset;
    void finish(DateTime end) {
      if (first != null) {
        slices.add(
          DayClockTimeSlice(first!, end, firstMinute, lastMinute, offset!),
        );
      }
      first = null;
    }

    var cursor = day.startUtc;
    while (cursor.isBefore(day.endUtc)) {
      final local = localize(cursor);
      final days = DateTime.utc(
        local.year,
        local.month,
        local.day,
      ).difference(DateTime.utc(date.year, date.month, date.day)).inDays;
      final wallMinute =
          days * 1440 +
          local.hour * 60 +
          local.minute +
          local.second / 60 +
          local.millisecond / 60000;
      final included = wallMinute >= begin && wallMinute < begin + spanMinutes;
      final next = cursor.add(const Duration(minutes: 1));
      final until = next.isAfter(day.endUtc) ? day.endUtc : next;
      final currentOffset = local.timeZoneOffset.inMinutes;
      if (!included || (first != null && offset != currentOffset)) {
        finish(cursor);
      }
      if (included) {
        final minute = (wallMinute - begin) * scale;
        if (first == null) {
          first = cursor;
          firstMinute = minute;
          offset = currentOffset;
        }
        lastMinute =
            minute + until.difference(cursor).inMicroseconds / 60000000 * scale;
      }
      cursor = until;
    }
    finish(cursor);
    final points = <double>{
      0,
      720,
      for (final s in slices) ...[s.startMinute, s.endMinute],
    }.toList()..sort();
    final transitions = <DayClockWallSpan>[];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      if (b <= a) continue;
      final count = slices
          .where((s) => s.startMinute < b && s.endMinute > a)
          .length;
      if (count != 1) {
        transitions.add(DayClockWallSpan(a, b, repeated: count > 1));
      }
    }
    return DayClockWindow(
      date,
      half,
      List.unmodifiable(slices),
      List.unmodifiable(transitions),
      minutesPerElapsedMinute: scale,
      startMinute: begin,
      spanMinutes: spanMinutes,
    );
  }

  double? minuteAt(DateTime utc) {
    for (final slice in slices) {
      if (!utc.isBefore(slice.startUtc) && utc.isBefore(slice.endUtc)) {
        return slice.startMinute +
            utc.difference(slice.startUtc).inMicroseconds /
                60000000 *
                minutesPerElapsedMinute;
      }
    }
    return null;
  }
}

class DayClockSector {
  const DayClockSector({
    required this.event,
    required this.key,
    required this.startUtc,
    required this.endUtc,
    required this.startMinute,
    required this.endMinute,
    required this.offsetMinutes,
    this.lane = 0,
    this.laneCount = 1,
  });
  final CalendarEvent event;
  final String key;
  final DateTime startUtc, endUtc;
  final double startMinute, endMinute;
  final int offsetMinutes, lane, laneCount;
  String get identity => calendarEventIdentity(event);
  double get angle => dayClockAngle(startMinute);
  double get sweep => (endMinute - startMinute) * math.pi / 360;
  DayClockSector withLane(int value, int count) => DayClockSector(
    event: event,
    key: key,
    startUtc: startUtc,
    endUtc: endUtc,
    startMinute: startMinute,
    endMinute: endMinute,
    offsetMinutes: offsetMinutes,
    lane: value,
    laneCount: count,
  );
}

class DayClockProjection {
  const DayClockProjection({
    required this.window,
    required this.sectors,
    required this.agenda,
    required this.allDay,
    required this.scheduled,
    required this.handAngle,
  });
  final DayClockWindow window;
  final List<DayClockSector> sectors;
  final List<CalendarEvent> agenda, allDay;
  final Duration scheduled;
  final double? handAngle;
  Map<String, int> get lanes => {for (final s in sectors) s.key: s.lane};

  factory DayClockProjection.project({
    required DayClockWindow window,
    required Iterable<CalendarEvent> events,
    required DateTime nowUtc,
    Map<String, int> previousLanes = const {},
  }) {
    final fragments = <DayClockSector>[];
    final allDay = <String, CalendarEvent>{}, timed = <String, CalendarEvent>{};
    for (final event in events.where((e) => e.eligible)) {
      final identity = calendarEventIdentity(event);
      if (event.allDay) {
        if (event.startDate!.compareTo(window.date) <= 0 &&
            event.endDate!.compareTo(window.date) > 0) {
          allDay[identity] = event;
        }
        continue;
      }
      for (final slice in window.slices) {
        final a = event.startUtc!.isAfter(slice.startUtc)
            ? event.startUtc!
            : slice.startUtc;
        final b = event.endUtc!.isBefore(slice.endUtc)
            ? event.endUtc!
            : slice.endUtc;
        if (!a.isBefore(b)) continue;
        timed[identity] = event;
        fragments.add(
          DayClockSector(
            event: event,
            key: '$identity/${slice.startUtc.toIso8601String()}',
            startUtc: a,
            endUtc: b,
            startMinute:
                slice.startMinute +
                a.difference(slice.startUtc).inMicroseconds /
                    60000000 *
                    window.minutesPerElapsedMinute,
            endMinute:
                slice.startMinute +
                b.difference(slice.startUtc).inMicroseconds /
                    60000000 *
                    window.minutesPerElapsedMinute,
            offsetMinutes: slice.offsetMinutes,
          ),
        );
      }
    }
    fragments.sort((a, b) {
      final n = a.startMinute.compareTo(b.startMinute);
      return n != 0 ? n : a.key.compareTo(b.key);
    });
    final sectors = <DayClockSector>[];
    var index = 0;
    while (index < fragments.length) {
      final group = <DayClockSector>[fragments[index++]];
      var end = group.first.endMinute;
      while (index < fragments.length && fragments[index].startMinute < end) {
        final value = fragments[index++];
        group.add(value);
        end = math.max(end, value.endMinute);
      }
      group.sort((a, b) {
        final oldA = previousLanes.containsKey(a.key),
            oldB = previousLanes.containsKey(b.key);
        if (oldA != oldB) return oldA ? -1 : 1;
        final n = a.startUtc.compareTo(b.startUtc);
        return n != 0 ? n : a.key.compareTo(b.key);
      });
      final assigned = <DayClockSector>[];
      final occupied = <int, List<DayClockSector>>{};
      for (final sector in group) {
        bool free(int lane) =>
            !(occupied[lane] ?? const <DayClockSector>[]).any(
              (s) =>
                  s.startMinute < sector.endMinute &&
                  s.endMinute > sector.startMinute,
            );
        var lane = previousLanes[sector.key] ?? 0;
        if (lane < 0 || lane >= group.length || !free(lane)) {
          lane = 0;
          while (!free(lane)) {
            lane++;
          }
        }
        assigned.add(sector.withLane(lane, 1));
        occupied.putIfAbsent(lane, () => []).add(sector);
      }
      final count = assigned.fold(1, (int n, s) => math.max(n, s.lane + 1));
      sectors.addAll(assigned.map((s) => s.withLane(s.lane, count)));
    }
    final intervals = fragments.toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    DateTime? start, end;
    var total = Duration.zero;
    for (final s in intervals) {
      if (end == null || s.startUtc.isAfter(end)) {
        if (start != null) total += end!.difference(start);
        start = s.startUtc;
        end = s.endUtc;
      } else if (s.endUtc.isAfter(end)) {
        end = s.endUtc;
      }
    }
    if (start != null) total += end!.difference(start);
    final agenda = timed.values.toList()
      ..sort((a, b) {
        final n = a.startUtc!.compareTo(b.startUtc!);
        return n != 0
            ? n
            : calendarEventIdentity(a).compareTo(calendarEventIdentity(b));
      });
    final days = allDay.values.toList()
      ..sort(
        (a, b) => calendarEventIdentity(a).compareTo(calendarEventIdentity(b)),
      );
    final minute = window.minuteAt(nowUtc);
    return DayClockProjection(
      window: window,
      sectors: List.unmodifiable(sectors),
      agenda: List.unmodifiable(agenda),
      allDay: List.unmodifiable(days),
      scheduled: total,
      handAngle: minute == null ? null : dayClockAngle(minute),
    );
  }
}
