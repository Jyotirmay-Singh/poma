import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../domain/calendar_preview.dart';

/// A fixture source only: no repository, HTTP, credentials, links or timer owner.
class CalendarController extends ChangeNotifier {
  CalendarController({DateTime Function()? now, bool scheduleUpdates = true})
    : _now = now ?? DateTime.now {
    _seed = _now();
    if (scheduleUpdates) {
      _updates = Timer.periodic(const Duration(minutes: 1), (_) {
        generation++;
        notifyListeners();
      });
    }
  }
  final DateTime Function() _now;
  Timer? _updates;
  late DateTime _seed;
  CalendarFixture fixture = CalendarFixture.disconnected;
  int generation = 0;
  bool _expanded = false;
  String message = '';
  DateTime get today {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  String dayKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);
  List<DateTime> get days =>
      List.generate(7, (i) => DateTime(today.year, today.month, today.day + i));
  bool get hasAgenda => ![
    CalendarFixture.disconnected,
    CalendarFixture.connecting,
    CalendarFixture.error,
  ].contains(fixture);

  void select(CalendarFixture value) {
    fixture = value;
    _seed = _now();
    _expanded = false;
    message = '';
    generation++;
    notifyListeners();
  }

  List<CalendarPreviewEvent> get events {
    if (!hasAgenda || fixture == CalendarFixture.empty) return const [];
    final day = DateTime(_seed.year, _seed.month, _seed.day);
    if (fixture == CalendarFixture.allDay) {
      return [
        CalendarPreviewEvent(
          'planning',
          'Planning day',
          'Personal',
          day,
          DateTime(day.year, day.month, day.day + 2),
          allDay: true,
        ),
      ];
    }
    final title = fixture == CalendarFixture.longTitles
        ? 'Fictional design review — 日本語 🧭 Café: accessibility, international typography and a very long planning discussion with the imaginary project team'
        : 'Design review';
    return [
      CalendarPreviewEvent(
        'review',
        title,
        'Work',
        _seed.subtract(const Duration(minutes: 10)),
        _seed.add(const Duration(minutes: 8)),
      ),
      if (fixture == CalendarFixture.overlapping)
        CalendarPreviewEvent(
          'overlap',
          'Prototype discussion',
          'Team',
          _seed.subtract(const Duration(minutes: 5)),
          _seed.add(const Duration(minutes: 15)),
        ),
      CalendarPreviewEvent(
        'planning',
        'Project planning',
        'Team',
        _seed.add(const Duration(minutes: 38)),
        _seed.add(const Duration(minutes: 68)),
      ),
      CalendarPreviewEvent(
        'all-day',
        'Planning day',
        'Personal',
        day,
        DateTime(day.year, day.month, day.day + 1),
        allDay: true,
      ),
      for (int i = 1; i < 7; i++)
        CalendarPreviewEvent(
          'day-$i',
          'Fictional catch-up',
          'Work',
          DateTime(day.year, day.month, day.day + i, 10),
          DateTime(day.year, day.month, day.day + i, 10, 30),
        ),
    ];
  }

  List<CalendarPreviewEvent> get active {
    final now = _now();
    final result = events
        .where((e) => !e.allDay && !e.start.isAfter(now) && e.end.isAfter(now))
        .toList();
    result.sort((a, b) {
      final end = a.end.compareTo(b.end);
      return end != 0 ? end : a.id.compareTo(b.id);
    });
    return result;
  }

  CalendarPreviewEvent? get next {
    final result =
        events.where((e) => !e.allDay && e.start.isAfter(_now())).toList()
          ..sort((a, b) {
            final start = a.start.compareTo(b.start);
            return start != 0 ? start : a.id.compareTo(b.id);
          });
    return result.isEmpty ? null : result.first;
  }

  String details(CalendarPreviewEvent e) =>
      '${e.allDay ? 'All day' : '${DateFormat.Hm().format(e.start)}–${DateFormat.Hm().format(e.end)}'} · ${e.calendar}';
  CalendarSection eventSection(
    String prefix,
    CalendarPreviewEvent e, {
    String day = '',
  }) => CalendarSection(
    id: '$prefix-${e.id}-$day',
    title: '$prefix · ${e.title}',
    body: details(e),
    day: day,
    actionId:
        '${prefix == 'NOW' || prefix == 'NEXT' ? 'join' : 'event'}:${e.id}',
    actionLabel: prefix == 'NOW' || prefix == 'NEXT'
        ? 'Join (demo)'
        : 'Open event (demo)',
  );

  List<CalendarSection> get sections {
    if (fixture == CalendarFixture.disconnected) {
      return const [
        CalendarSection(
          id: 'disconnected',
          title: 'Calendar disconnected',
          body:
              'Calendar preview only. Try fictional scenarios in Calendar settings.',
          actionId: 'connect',
          actionLabel: 'Preview connection',
        ),
      ];
    }
    if (fixture == CalendarFixture.connecting) {
      return const [
        CalendarSection(
          id: 'connecting',
          title: 'Connecting · fictional preview',
          body: 'No account is being accessed. Your timer remains available.',
          actionId: 'cancel',
          actionLabel: 'Cancel',
        ),
      ];
    }
    if (fixture == CalendarFixture.error) {
      return const [
        CalendarSection(
          id: 'error',
          title: 'Calendar unavailable · demo',
          body:
              'Fictional connection error. Your timer and saved data are available.',
          actionId: 'retry',
          actionLabel: 'Retry preview',
        ),
      ];
    }
    final current = active;
    final upcoming = next;
    return [
      if (message.isNotEmpty) CalendarSection(id: 'message', title: message),
      if (fixture == CalendarFixture.stale)
        const CalendarSection(
          id: 'stale-warning',
          title: 'Stale calendar preview',
          body:
              'Updated 12 minutes ago. This fictional schedule may have changed.',
        ),
      if (current.isNotEmpty)
        eventSection('NOW', current.first)
      else
        const CalendarSection(id: 'now', title: 'NOW · No current meeting'),
      if (current.length > 1)
        CalendarSection(
          id: 'overlaps',
          title: '${current.length} overlapping meetings',
          actionId: 'overlaps',
          actionLabel: _expanded ? 'Show less' : 'Show all',
        ),
      if (_expanded) ...current.skip(1).map((e) => eventSection('ALSO NOW', e)),
      if (upcoming != null)
        eventSection('NEXT', upcoming)
      else
        const CalendarSection(id: 'next', title: 'NEXT · No upcoming meeting'),
      for (final day in days) ...[
        CalendarSection(
          id: 'day-${dayKey(day)}',
          title: DateFormat('EEE, d MMM').format(day),
          day: dayKey(day),
        ),
        ...events
            .where(
              (e) =>
                  e.start.isBefore(
                    DateTime(day.year, day.month, day.day + 1),
                  ) &&
                  e.end.isAfter(day),
            )
            .map(
              (e) => eventSection(
                e.allDay ? 'ALL DAY' : 'AGENDA',
                e,
                day: dayKey(day),
              ),
            ),
        if (!events.any(
          (e) =>
              e.start.isBefore(DateTime(day.year, day.month, day.day + 1)) &&
              e.end.isAfter(day),
        ))
          CalendarSection(
            id: 'empty-${dayKey(day)}',
            title: 'No events in this fictional agenda.',
            day: dayKey(day),
          ),
      ],
      CalendarSection(
        id: 'freshness',
        title: fixture == CalendarFixture.stale
            ? 'Stale · updated 12 minutes ago'
            : 'Fictional preview · updated ${DateFormat.Hm().format(_seed)}',
        body: fixture == CalendarFixture.stale
            ? 'This schedule is out of date. Refresh the preview to recover.'
            : 'No Google account or real calendar data.',
        actionId: 'refresh',
        actionLabel: 'Refresh preview',
      ),
      const CalendarSection(
        id: 'google',
        title: 'Google Calendar',
        actionId: 'google',
        actionLabel: 'Preview calendar action',
      ),
    ];
  }

  /// Only opaque current-generation fixture actions are accepted.
  bool act(String id, int expectedGeneration) {
    if (expectedGeneration != generation ||
        !sections.any((s) => s.actionId == id)) {
      return false;
    }
    if (id == 'connect') {
      select(CalendarFixture.connecting);
      return true;
    }
    if (id == 'cancel') {
      select(CalendarFixture.disconnected);
      return true;
    }
    if (id == 'retry') {
      select(CalendarFixture.normal);
      return true;
    }
    if (id == 'overlaps') {
      _expanded = !_expanded;
    } else if (id == 'refresh') {
      if (fixture == CalendarFixture.stale) fixture = CalendarFixture.normal;
      _seed = _now();
      message = 'Preview refreshed locally.';
    } else {
      message = 'Fictional action preview · no browser opened.';
    }
    generation++;
    notifyListeners();
    return true;
  }

  Map<String, Object?> display({
    required bool unlocked,
    required bool tooltipTitles,
  }) => {
    'calendarGeneration': generation,
    'calendarDates': days.map(dayKey).toList(),
    'calendarDateLabels': [
      for (var i = 0; i < days.length; i++)
        i == 0
            ? 'Today'
            : i == 1
            ? 'Tomorrow'
            : DateFormat('EEE, d MMM').format(days[i]),
    ],
    'calendarRefreshAvailable': unlocked && hasAgenda,
    'calendarTooltip': unlocked && tooltipTitles
        ? (active.isNotEmpty ? active.first.title : next?.title ?? '')
        : '',
    'secondarySections': unlocked
        ? sections.map((s) => s.toJson()).toList()
        : const <Object>[],
  };

  @override
  void dispose() {
    _updates?.cancel();
    super.dispose();
  }
}
