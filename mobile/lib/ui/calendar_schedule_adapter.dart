import 'dart:convert';

import 'package:kalender/kalender.dart' as k;

import '../application/calendar_read_ports.dart';
import '../domain/calendar_data.dart';

String scheduleEventIdentity(CalendarEvent event) =>
    calendarEventIdentity(event);

/// A disposable presentation of a provider event. No scheduling journal entries
/// are added here: only Google's retained snapshots supply confirmed tiles.
class PomaScheduleEvent extends k.KalenderEvent {
  PomaScheduleEvent._({
    required this.event,
    required this.sourceLabel,
    required this.sourceColor,
    required super.start,
    required super.end,
  }) : fingerprint = jsonEncode(event.toJson()),
       super(
         id: scheduleEventIdentity(event),
         isAllDay: event.allDay,
         interaction: k.EventInteraction.allowNone(),
       );

  factory PomaScheduleEvent.fromEvent(
    CalendarEvent event, {
    required CalendarClock clock,
    required String sourceLabel,
    String? sourceColor,
  }) => PomaScheduleEvent._(
    event: event,
    sourceLabel: sourceLabel,
    sourceColor: safeCalendarColor(sourceColor),
    // Date-only values stay in their original model. The renderer alone gets
    // device-midnight instants, including the exclusive end across DST.
    start: event.allDay
        ? clock.dayWindow(event.startDate!).startUtc
        : event.startUtc!,
    end: event.allDay
        ? clock.dayWindow(event.endDate!).startUtc
        : event.endUtc!,
  );

  final CalendarEvent event;
  final String sourceLabel, fingerprint;
  final String? sourceColor;

  @override
  PomaScheduleEvent copyWithData({
    required DateTime start,
    required DateTime end,
  }) => PomaScheduleEvent._(
    event: event,
    sourceLabel: sourceLabel,
    sourceColor: sourceColor,
    start: start,
    end: end,
  );

  @override
  bool layoutEquals(k.KalenderEvent other) =>
      super.layoutEquals(other) &&
      other is PomaScheduleEvent &&
      fingerprint == other.fingerprint &&
      sourceLabel == other.sourceLabel &&
      sourceColor == other.sourceColor;

  @override
  bool operator ==(Object other) =>
      other is PomaScheduleEvent && layoutEquals(other);

  @override
  int get hashCode =>
      Object.hash(super.hashCode, fingerprint, sourceLabel, sourceColor);
}

/// A seven-day page starts at the reader's first date, never at a weekday
/// boundary. A conventional week would expose dates the reader hasn't loaded.
k.MultiDayViewConfiguration scheduleViewConfiguration(
  CalendarWindow window, {
  required bool sevenDays,
  required DateTime selectedDate,
}) {
  final range = k.KalenderDateTimeRange(
    start: window.startUtc,
    end: window.endUtc,
  );
  return sevenDays
      ? k.MultiDayViewConfiguration.custom(
          name: 'Next 7 days',
          numberOfDays: 7,
          displayRange: range,
          initialDateTime: selectedDate,
          initialTimeOfDay: const k.KalenderTime(hour: 8, minute: 0),
        )
      : k.MultiDayViewConfiguration.singleDay(
          name: 'Day',
          displayRange: range,
          initialDateTime: selectedDate,
          initialTimeOfDay: const k.KalenderTime(hour: 8, minute: 0),
        );
}
