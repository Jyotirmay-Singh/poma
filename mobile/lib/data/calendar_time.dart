import 'dart:async';
import '../application/calendar_read_ports.dart';
import '../domain/calendar_data.dart';

class DeviceCalendarClock implements CalendarClock {
  const DeviceCalendarClock();
  @override
  CalendarWindow dayWindow(CalendarDate day) {
    final until = day.plusDays(1);
    return CalendarWindow(
      first: day,
      until: until,
      startUtc: DateTime(day.year, day.month, day.day).toUtc(),
      endUtc: DateTime(until.year, until.month, until.day).toUtc(),
    );
  }

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
  @override
  DateTime nextMidnightUtc() {
    final local = DateTime.now();
    return DateTime(local.year, local.month, local.day + 1).toUtc();
  }

  @override
  CalendarWindow window() {
    final local = DateTime.now();
    final first = CalendarDate(local.year, local.month, local.day);
    final until = first.plusDays(7);
    return CalendarWindow(
      first: first,
      until: until,
      startUtc: DateTime(first.year, first.month, first.day).toUtc(),
      endUtc: DateTime(until.year, until.month, until.day).toUtc(),
    );
  }
}

class TimerCalendarScheduler implements CalendarScheduler {
  const TimerCalendarScheduler();
  @override
  CalendarScheduledJob after(Duration duration, void Function() callback) =>
      _Job(Timer(duration.isNegative ? Duration.zero : duration, callback));
}

class _Job implements CalendarScheduledJob {
  _Job(this.timer);
  final Timer timer;
  @override
  void cancel() => timer.cancel();
}
