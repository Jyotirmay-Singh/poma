import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/calendar_data.dart';
import '../domain/calendar_preview.dart';
import 'calendar_connection_controller.dart';
import 'calendar_presentation_ports.dart';
import 'calendar_read_controller.dart';
import 'calendar_read_ports.dart';

int _identity(CalendarEvent a, CalendarEvent b) {
  for (final pair in [
    (a.calendarId, b.calendarId),
    (a.id, b.id),
    (a.recurringEventId ?? '', b.recurringEventId ?? ''),
    (a.originalStart ?? '', b.originalStart ?? ''),
  ]) {
    final order = pair.$1.compareTo(pair.$2);
    if (order != 0) return order;
  }
  return 0;
}

/// Pure selection over retained source identities. Titles never determine identity.
class CalendarNowNext {
  CalendarNowNext(Iterable<CalendarEvent> events, DateTime now) {
    final timed = events.where(
      (e) =>
          e.eligible &&
          !e.allDay &&
          e.startUtc != null &&
          e.endUtc != null &&
          e.endUtc!.isAfter(e.startUtc!),
    );
    active =
        timed
            .where((e) => !e.startUtc!.isAfter(now) && e.endUtc!.isAfter(now))
            .toList()
          ..sort((a, b) {
            final end = a.endUtc!.compareTo(b.endUtc!);
            final start = a.startUtc!.compareTo(b.startUtc!);
            return end != 0
                ? end
                : start != 0
                ? start
                : _identity(a, b);
          });
    upcoming = timed.where((e) => e.startUtc!.isAfter(now)).toList()
      ..sort((a, b) {
        final start = a.startUtc!.compareTo(b.startUtc!);
        final end = a.endUtc!.compareTo(b.endUtc!);
        return start != 0
            ? start
            : end != 0
            ? end
            : _identity(a, b);
      });
  }
  late final List<CalendarEvent> active, upcoming;
  CalendarEvent? get next => upcoming.firstOrNull;
  int get nextCount => next == null
      ? 0
      : upcoming.where((e) => e.startUtc == next!.startUtc).length;
}

class _AgendaAction {
  const _AgendaAction(this.kind, this.scope, {this.event, this.url});
  final String kind, scope;
  final CalendarEvent? event;
  final String? url;
}

/// A disposable projection only: no credentials, repository, HTTP or timer engine.
class CalendarAgendaController extends ChangeNotifier {
  CalendarAgendaController({
    required this.reader,
    required this.platform,
    required this.openSettings,
  }) {
    reader.addListener(_changed);
    reader.connection.addListener(_changed);
    _changed();
  }
  final CalendarReadController reader;
  final CalendarPresentationPlatform platform;
  final void Function() openSettings;
  CalendarConnectionController get connection => reader.connection;
  int generation = 0;
  bool _disposed = false, _unlocked = false, _expanded = false;
  int _formatRevision = 0;
  String? _formatKey, _pendingFormat, _message;
  Map<String, String> _formats = const {};
  bool _formatError = false;
  CalendarScheduledJob? _boundary;
  final Map<String, _AgendaAction> _actions = {};

  String get _scope => jsonEncode([
    reader.accountKey,
    connection.verifiedAccountKey,
    connection.sessionGeneration,
    reader.scopeGeneration,
    reader.saving,
    connection.cleanupPending,
    (reader.selected.toList()..sort()),
  ]);
  bool get _hasAccount =>
      reader.accountKey != null &&
      reader.accountKey == connection.verifiedAccountKey;
  List<CalendarEvent> get events => !_hasAccount
      ? const []
      : reader.events
            .where((e) => reader.selected.contains(e.calendarId))
            .toList();
  List<CalendarDate> get days =>
      List.generate(7, (i) => reader.window.first.plusDays(i));

  // Read-only projections shared with the main window. These never rebuild the
  // native popup's action map or create a second calendar data owner.
  CalendarSection get scheduleStatus => _status(includeActions: false);
  String sourceLabel(String id) => _source(id);
  String timeLabel(DateTime instant) => _time(instant);
  String eventDetails(CalendarEvent event) => _details(event);
  bool verified(CalendarWindow window) => _verified(window);
  String? get actionMessage => _message;
  bool get formattingUnavailable => _formatError;
  void retryFormatting() {
    if (_formatError) preferencesChanged();
  }

  String timelineLabel(int hour, [int minute = 0]) {
    final d = reader.window.first;
    return _time(DateTime(d.year, d.month, d.day, hour % 24, minute).toUtc());
  }

  void _changed() {
    if (_disposed) return;
    ++generation;
    _actions.clear();
    _boundary?.cancel();
    final now = reader.now;
    DateTime? boundary;
    for (final e in events.where((e) => !e.allDay)) {
      for (final time in [e.startUtc, e.endUtc]) {
        if (time != null &&
            time.isAfter(now) &&
            (boundary == null || time.isBefore(boundary))) {
          boundary = time;
        }
      }
    }
    if (boundary != null) {
      _boundary = reader.scheduler.after(boundary.difference(now), _changed);
    }
    _format();
    notifyListeners();
  }

  void preferencesChanged() {
    ++_formatRevision;
    _changed();
  }

  void opened() {
    _expanded = false;
    if (_formatError) ++_formatRevision;
    _changed();
  }

  void _format() {
    final instants = <DateTime>{
      ...events.expand((e) => [e.startUtc, e.endUtc]).whereType<DateTime>(),
      for (var hour = 0; hour < 24; hour++)
        for (var minute = 0; minute < 60; minute += 5)
          DateTime(
            reader.window.first.year,
            reader.window.first.month,
            reader.window.first.day,
            hour,
            minute,
          ).toUtc(),
    }.toList()..sort();
    final dates = days;
    final key = jsonEncode([
      _scope,
      _formatRevision,
      instants.map((e) => e.microsecondsSinceEpoch).toList(),
      dates.map((d) => '$d').toList(),
    ]);
    if (key == _formatKey || key == _pendingFormat) return;
    _pendingFormat = key;
    final scope = _scope;
    unawaited(() async {
      Map<String, String> formatted = const {};
      var failed = false;
      try {
        formatted = await platform.formatCalendar(instants, dates);
      } catch (_) {
        failed = true;
      }
      if (_disposed || _pendingFormat != key || _scope != scope) return;
      _pendingFormat = null;
      _formatKey = key;
      _formats = formatted;
      _formatError = failed;
      ++generation;
      _actions.clear();
      notifyListeners();
    }());
  }

  CalendarWindow _dayWindow(CalendarDate day) {
    return reader.clock.dayWindow(day);
  }

  bool _verified(CalendarWindow window) =>
      _hasAccount &&
      reader.selected.isNotEmpty &&
      connection.status == CalendarConnectionStatus.connected &&
      connection.mayRead &&
      reader.failure == null &&
      reader.selected.every(
        (id) =>
            reader.sourceFailures[id] == null &&
            reader.snapshots[id]?.fresh(reader.now, window) == true,
      );

  String _source(String id) {
    final name =
        reader.sources.where((s) => s.id == id).firstOrNull?.name ??
        'Selected calendar';
    final peers =
        reader.sources
            .where((s) => s.name == name && reader.selected.contains(s.id))
            .map((s) => s.id)
            .toList()
          ..sort();
    return peers.length > 1
        ? '$name (calendar ${peers.indexOf(id) + 1})'
        : name;
  }

  String _rowId(CalendarEvent e) =>
      jsonEncode([e.calendarId, e.id, e.recurringEventId, e.originalStart]);
  String _time(DateTime value) =>
      _formats['${value.microsecondsSinceEpoch}'] ?? 'Local time loading';
  String _details(CalendarEvent e) => [
    e.allDay ? 'All day' : '${_time(e.startUtc!)}–${_time(e.endUtc!)}',
    _source(e.calendarId),
    if (e.status == 'tentative' || e.selfResponse == 'tentative') 'Tentative',
    if (e.selfResponse == 'needsAction') 'Response needed',
  ].join(' · ');

  CalendarDisplayAction _action(
    String kind,
    String label, {
    CalendarEvent? event,
    String? url,
    bool enabled = true,
  }) {
    final id = 'a-$generation-${_actions.length}';
    _actions[id] = _AgendaAction(kind, _scope, event: event, url: url);
    return CalendarDisplayAction(
      id,
      label,
      event == null
          ? label
          : '$label: ${event.title}, ${_source(event.calendarId)}',
      enabled: enabled,
    );
  }

  CalendarSection _event(String prefix, CalendarEvent e, {String day = ''}) {
    final minutes =
        (prefix == 'NOW'
                ? e.endUtc!.difference(reader.now)
                : prefix == 'NEXT'
                ? e.startUtc!.difference(reader.now)
                : Duration.zero)
            .inSeconds;
    final countdown = prefix == 'NOW'
        ? 'Ends in ${(minutes / 60).ceil()} min'
        : prefix == 'NEXT'
        ? 'In ${(minutes / 60).ceil()} min'
        : '';
    final eventUrl = safeCalendarUrl(e.eventUrl, meeting: false);
    final meeting = safeCalendarUrl(e.meetingUrl, meeting: true);
    return CalendarSection(
      id: '$prefix-${_rowId(e)}-$day',
      title: '$prefix · ${e.title}',
      body: [_details(e), if (countdown.isNotEmpty) countdown].join(' · '),
      day: day,
      actions: reader.saving || connection.cleanupPending
          ? const []
          : [
              if (eventUrl != null)
                _action('event', 'Open event', event: e, url: eventUrl),
              if (meeting != null)
                _action('join', 'Join', event: e, url: meeting),
            ],
    );
  }

  CalendarSection _status({bool includeActions = true}) {
    final status = connection.status;
    String title, body, label = 'Calendar settings', kind = 'settings';
    if (status == CalendarConnectionStatus.unconfigured) {
      title = 'Google Calendar is not configured in this build';
      body =
          'A build with Google Desktop client settings is required. Open Calendar settings for setup information. Timers, tasks and history still work offline.';
    } else if (status == CalendarConnectionStatus.connecting) {
      title = 'Connecting Google Calendar';
      body = 'Complete sign-in in your browser, or cancel.';
      label = 'Cancel';
      kind = 'cancel';
    } else if (status == CalendarConnectionStatus.restoring || reader.loading) {
      title = 'Loading calendar';
      body =
          'Restoring saved selection and schedule. This is not an empty agenda.';
    } else if (status == CalendarConnectionStatus.reconnectRequired ||
        status == CalendarConnectionStatus.incompletePermissions) {
      title = 'Reconnect Google Calendar';
      body =
          'Saved data is unverified. Testing access may expire after seven days; revocation or account policy may also require reconnecting.';
      label = 'Reconnect';
    } else if (status == CalendarConnectionStatus.disconnected) {
      title = 'Google Calendar disconnected';
      body =
          'Connect and choose calendars in Settings. Your offline timer remains available.';
      label = 'Connect Google';
    } else if (status == CalendarConnectionStatus.storageError) {
      title = 'Calendar storage needs attention';
      body = 'Open Settings to repair storage or remove saved calendar data.';
    } else if (status == CalendarConnectionStatus.offline) {
      title = 'Google Calendar offline · saved schedule';
      body =
          'Google could not be reached. Saved data is unverified; retry when online.';
    } else if (!_hasAccount) {
      title = 'Calendar unavailable';
      body = 'Open Settings to check the connection and retry.';
    } else if (reader.saving) {
      title = 'Saving calendar selection';
      body = 'Saved content remains visible while the selection is committed.';
    } else if (reader.selected.isEmpty) {
      title = 'No calendars selected';
      body = 'Choose and save calendars before events are loaded.';
      label = 'Choose calendars';
    } else if (reader.refreshing &&
        reader.selected.every((id) => reader.snapshots[id] == null)) {
      title = 'Loading calendar schedule';
      body =
          'Reading selected calendars. No verified schedule is available yet.';
    } else if (reader.refreshing) {
      title = 'Refreshing calendar';
      body =
          'Keeping saved content visible. Individual calendar status appears below.';
    } else if (_verified(reader.window)) {
      title = 'Schedule verified';
      body = 'Selected calendars cover the upcoming seven dates.';
    } else {
      title = reader.sourceFailures.isNotEmpty
          ? 'Some calendars could not be verified'
          : events.isEmpty && reader.snapshots.isEmpty
          ? 'Schedule unavailable'
          : 'Saved schedule · unverified';
      body =
          'Saved events may have changed. Missing coverage does not mean there are no events.';
    }
    return CalendarSection(
      id: 'status',
      title: title,
      body: body,
      actions: !includeActions
          ? const []
          : [
              _action(kind, label),
              if (connection.mayRead && !reader.loading && !reader.saving)
                _action(
                  'refresh',
                  reader.refreshing ? 'Refreshing…' : 'Refresh / Retry',
                  enabled: !reader.refreshing,
                ),
            ],
    );
  }

  String _problem(CalendarReadFailure failure) => switch (failure.kind) {
    CalendarReadFailureKind.network =>
      'Google could not be reached; retry when online.',
    CalendarReadFailureKind.authorization =>
      'Authorization needs attention; reconnect in Settings.',
    CalendarReadFailureKind.forbidden =>
      'Access restricted; check calendar access, then refresh.',
    CalendarReadFailureKind.throttled =>
      'Google requested a pause; retry delay is respected.',
    CalendarReadFailureKind.storage =>
      'Calendar storage failed; repair storage and retry.',
    CalendarReadFailureKind.response =>
      'Incomplete response; previous saved data is kept.',
    CalendarReadFailureKind.cancelled => 'Refresh cancelled.',
  };

  List<CalendarSection> get _sections {
    final status = _status();
    final list = <CalendarSection>[];
    final sourceSections = <CalendarSection>[];
    if (!_hasAccount || reader.selected.isEmpty) {
      list.add(status);
    } else if (!_verified(reader.window)) {
      list.add(
        CalendarSection(
          id: 'schedule-warning',
          title: status.title,
          body:
              'Saved or incomplete schedule. See calendar status below to verify freshness and coverage.',
        ),
      );
    }
    if (_message != null) {
      list.add(CalendarSection(id: 'action-message', title: _message!));
    }
    if (_formatError) {
      list.add(
        const CalendarSection(
          id: 'format-error',
          title: 'Local time formatting unavailable',
          body: 'Check Windows regional settings and reopen the popup.',
        ),
      );
    }
    if (reader.failure != null) {
      list.add(
        CalendarSection(
          id: 'failure',
          title: 'Calendar update needs attention',
          body: _problem(reader.failure!),
        ),
      );
    }
    if (_hasAccount && reader.selected.isNotEmpty) {
      final selected = reader.selected.toList()..sort();
      for (final id in selected) {
        final saved = reader.snapshots[id];
        final problem = reader.sourceFailures[id];
        final age = saved == null
            ? ''
            : saved.succeededAt.isAfter(reader.now)
            ? 'Saved timestamp needs verification'
            : 'Updated ${reader.now.difference(saved.succeededAt).inMinutes} min ago';
        sourceSections.add(
          CalendarSection(
            id: 'source-$id',
            title: _source(id),
            body: [
              saved == null ? 'No saved schedule' : age,
              if (saved != null)
                saved.coverage.covers(reader.window)
                    ? 'Seven-date coverage'
                    : 'Partial coverage; some dates or times unavailable',
              if (saved != null)
                _verifiedSource(id) ? 'Verified' : 'Saved data · unverified',
              if (problem != null) _problem(problem),
            ].join(' · '),
          ),
        );
      }
      final selection = CalendarNowNext(events, reader.now);
      list.add(
        selection.active.isEmpty
            ? const CalendarSection(
                id: 'now',
                title: 'NOW · No current meeting in available data',
              )
            : _event('NOW', selection.active.first),
      );
      if (selection.active.length > 1) {
        list.add(
          CalendarSection(
            id: 'conflicts',
            title: '${selection.active.length} simultaneous meetings',
            actions: [
              _action('overlaps', _expanded ? 'Show less' : 'Show all'),
            ],
          ),
        );
      }
      if (_expanded) {
        list.addAll(selection.active.skip(1).map((e) => _event('ALSO NOW', e)));
      }
      list.add(
        selection.next != null
            ? _event('NEXT', selection.next!)
            : CalendarSection(
                id: 'next',
                title: _verified(reader.window)
                    ? 'NEXT · No upcoming meetings in the cached week'
                    : 'NEXT · No saved upcoming meetings; refresh to verify',
              ),
      );
      if (selection.nextCount > 1) {
        list.add(
          CalendarSection(
            id: 'next-conflict',
            title: '${selection.nextCount} upcoming meetings start together',
            body: 'Each source event remains separate in the agenda.',
          ),
        );
      }
      for (final day in days) {
        final window = _dayWindow(day);
        final items = events.where((e) => e.overlaps(window)).toList()
          ..sort((a, b) {
            if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
            final time = a.allDay
                ? a.startDate!.compareTo(b.startDate!)
                : a.startUtc!.compareTo(b.startUtc!);
            return time != 0 ? time : _identity(a, b);
          });
        list.add(
          CalendarSection(
            id: 'day-$day',
            title: _formats['$day'] ?? '$day',
            day: '$day',
          ),
        );
        list.addAll(
          items.map(
            (e) => _event(e.allDay ? 'ALL DAY' : 'AGENDA', e, day: '$day'),
          ),
        );
        if (items.isEmpty) {
          list.add(
            CalendarSection(
              id: 'empty-$day',
              title: _verified(window)
                  ? 'No events on this verified day'
                  : 'No saved events for this day; schedule is unverified',
              day: '$day',
            ),
          );
        }
      }
      list.add(status);
      list.addAll(sourceSections);
    }
    list.add(
      CalendarSection(
        id: 'google',
        title: 'Google Calendar',
        actions: [
          _action(
            'calendar',
            'Open Google Calendar',
            url: 'https://calendar.google.com/calendar/',
          ),
        ],
      ),
    );
    return list;
  }

  bool _verifiedSource(String id) =>
      connection.status == CalendarConnectionStatus.connected &&
      connection.mayRead &&
      reader.failure == null &&
      reader.sourceFailures[id] == null &&
      reader.snapshots[id]?.fresh(reader.now, reader.window) == true;

  Map<String, Object?> display({
    required bool unlocked,
    required bool tooltipTitles,
  }) {
    if (_unlocked != unlocked) ++generation;
    _unlocked = unlocked;
    _actions.clear();
    final sections = unlocked ? _sections : const <CalendarSection>[];
    final selection = CalendarNowNext(events, reader.now);
    final headline = selection.active.firstOrNull ?? selection.next;
    final verified = _verified(reader.window);
    return {
      'calendarGeneration': generation,
      'calendarLabel': 'Google Calendar',
      'calendarDates': days.map((d) => '$d').toList(),
      'calendarDateLabels': [
        for (var i = 0; i < days.length; i++)
          i == 0
              ? 'Today'
              : i == 1
              ? 'Tomorrow'
              : _formats['${days[i]}'] ?? '${days[i]}',
      ],
      'calendarRefreshAvailable':
          unlocked &&
          connection.mayRead &&
          !reader.loading &&
          !reader.saving &&
          !reader.refreshing,
      'calendarRefreshAction':
          _actions.entries
              .where((e) => e.value.kind == 'refresh')
              .firstOrNull
              ?.key ??
          '',
      'calendarTooltip': !unlocked
          ? ''
          : headline != null && tooltipTitles
          ? '${verified ? '' : 'Saved · '}${headline.title}'
          : reader.selected.isNotEmpty
          ? (verified ? 'Calendar verified' : 'Calendar unverified')
          : 'Calendar needs setup',
      'secondarySections': sections.map((s) => s.toJson()).toList(),
    };
  }

  /// Main-window actions pass through the same current-event, URL and native
  /// generation checks as the compact agenda. Adding an action does not retire
  /// any action already published to the native popup.
  Future<bool> openEvent(
    CalendarEvent event, {
    required String kind,
    required bool unlocked,
  }) async {
    if (_disposed ||
        !unlocked ||
        !_unlocked ||
        !const {'event', 'join'}.contains(kind)) {
      return false;
    }
    final action = _action(
      kind,
      kind == 'join' ? 'Join' : 'Open event',
      event: event,
      url: kind == 'join' ? event.meetingUrl : event.eventUrl,
    );
    return act(action.id, generation);
  }

  Future<bool> act(String id, int expectedGeneration) async {
    final action = _actions[id];
    if (_disposed ||
        !_unlocked ||
        expectedGeneration != generation ||
        action == null ||
        action.scope != _scope) {
      return false;
    }
    _message = null;
    switch (action.kind) {
      case 'settings':
        openSettings();
      case 'cancel':
        unawaited(connection.cancel());
      case 'refresh':
        if (reader.refreshing) return false;
        unawaited(reader.retry());
      case 'overlaps':
        _expanded = !_expanded;
        _changed();
      case 'event':
      case 'join':
      case 'calendar':
        var url = action.url;
        final event = action.event;
        if (event != null) {
          if (!_hasAccount ||
              reader.saving ||
              connection.cleanupPending ||
              !events.any(
                (e) => jsonEncode(e.toJson()) == jsonEncode(event.toJson()),
              )) {
            return false;
          }
          url = safeCalendarUrl(
            action.kind == 'join' ? event.meetingUrl : event.eventUrl,
            meeting: action.kind == 'join',
          );
          if (url == null || url != action.url) return false;
        }
        if (safeCalendarActionUrl(url, action.kind) == null) return false;
        try {
          await platform.openCalendarLink(
            url!,
            action.kind,
            expectedGeneration,
          );
        } catch (_) {
          if (!_disposed &&
              expectedGeneration == generation &&
              action.scope == _scope) {
            _message =
                'The default browser could not be opened. Check Windows default apps and try again.';
            _changed();
          }
          return false;
        }
    }
    return true;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _boundary?.cancel();
    _actions.clear();
    reader.removeListener(_changed);
    connection.removeListener(_changed);
    super.dispose();
  }
}
