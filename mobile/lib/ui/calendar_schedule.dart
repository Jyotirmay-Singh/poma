import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart' as k;

import '../application/calendar_agenda_controller.dart';
import '../application/calendar_read_controller.dart';
import '../application/calendar_read_ports.dart';
import '../application/desktop_controller.dart';
import '../domain/calendar_data.dart';
import 'calendar_schedule_adapter.dart';
import 'copy.dart';
import 'design_tokens.dart';

enum ScheduleView { sevenDays, day, agenda }

class CalendarSchedule extends StatefulWidget {
  const CalendarSchedule({required this.desktop, super.key});
  final DesktopController desktop;

  @override
  State<CalendarSchedule> createState() => _CalendarScheduleState();
}

class _CalendarScheduleState extends State<CalendarSchedule> {
  final _events = k.DefaultEventsController();
  k.KalenderController? _calendar;
  ScheduleView? _choice;
  CalendarDate? _selectedDay;
  String? _eventKey, _selectedEvent;
  DialogRoute<void>? _details;
  String? _detailScope, _detailFingerprint;
  CalendarReadController? get reader => widget.desktop.calendarData;
  CalendarAgendaController? get agenda => widget.desktop.agenda;
  bool get _hasSelection =>
      reader != null &&
      reader!.accountKey != null &&
      reader!.accountKey == reader!.connection.verifiedAccountKey &&
      reader!.selected.isNotEmpty;
  List<PomaScheduleEvent> get events =>
      _events.events.cast<PomaScheduleEvent>().toList();
  bool get _visible =>
      widget.desktop.sessionState == 'unlocked' &&
      widget.desktop.calendarSection == CalendarPageSection.schedule;

  @override
  void initState() {
    super.initState();
    widget.desktop.addListener(_changed);
    _sync();
    if (reader != null) {
      _calendar = k.KalenderController(
        viewConfiguration: scheduleViewConfiguration(
          reader!.window,
          sevenDays: false,
          selectedDate: reader!.window.startUtc,
        ),
      );
    }
  }

  String get _scope => jsonEncode([
    reader?.accountKey,
    reader?.connection.verifiedAccountKey,
    reader?.connection.sessionGeneration,
    reader?.scopeGeneration,
    reader?.saving,
    reader?.connection.cleanupPending,
    widget.desktop.sessionState,
  ]);

  void _changed() {
    if (!mounted) return;
    _sync();
    setState(() {});
  }

  void _closeDetails() {
    final route = _details;
    _details = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
    _selectedEvent = null;
    _calendar?.deselectEvent();
    _calendar?.hideDayOverlay();
  }

  void _sync() {
    final data = reader, projection = agenda;
    final permitted =
        widget.desktop.sessionState == 'unlocked' &&
        data != null &&
        projection != null &&
        !data.saving &&
        !data.loading &&
        data.connection.mayRead &&
        !data.connection.cleanupPending &&
        data.accountKey != null &&
        data.accountKey == data.connection.verifiedAccountKey;
    final mapped = <String, PomaScheduleEvent>{};
    if (permitted) {
      for (final event in projection.events) {
        final source = data.sources
            .where((s) => s.id == event.calendarId)
            .firstOrNull;
        final tile = PomaScheduleEvent.fromEvent(
          event,
          clock: data.clock,
          sourceLabel: projection.sourceLabel(event.calendarId),
          sourceColor: source?.backgroundColor,
        );
        mapped[tile.id] = tile;
      }
    }
    final key = jsonEncode([
      _scope,
      widget.desktop.calendarPresentationRevision,
      for (final event in mapped.values)
        [event.fingerprint, event.sourceLabel, event.sourceColor],
    ]);
    if (_eventKey != key) {
      _eventKey = key;
      if (!permitted) Tooltip.dismissAllToolTips();
      _events.replaceEvents(mapped.values.toList());
    }
    if (_details != null &&
        (!_visible ||
            _detailScope != _scope ||
            mapped[_selectedEvent]?.fingerprint != _detailFingerprint)) {
      _closeDetails();
    }
    if (_selectedEvent != null && !mapped.containsKey(_selectedEvent)) {
      _selectedEvent = null;
      _calendar?.deselectEvent();
    }
    if (data != null) {
      final first = data.window.first, last = data.window.until.plusDays(-1);
      final chosen = _selectedDay;
      if (chosen == null ||
          chosen.compareTo(first) < 0 ||
          chosen.compareTo(last) > 0) {
        _selectedDay = first;
      }
    }
  }

  Future<void> _open(PomaScheduleEvent tile) async {
    if (!_visible || !events.any((e) => e == tile) || _details != null) return;
    setState(() => _selectedEvent = tile.id);
    _calendar?.selectEvent(tile);
    _detailScope = _scope;
    _detailFingerprint = tile.fingerprint;
    final route = DialogRoute<void>(
      context: context,
      builder: (context) => _ScheduleDetails(
        tile: tile,
        desktop: widget.desktop,
        agenda: agenda!,
        scopeGeneration: reader!.scopeGeneration,
      ),
    );
    _details = route;
    await Navigator.of(context).push(route);
    if (mounted && identical(_details, route)) {
      setState(() => _details = null);
    }
  }

  String _date(CalendarDate day) =>
      DeviceFormats.date(context, DateTime(day.year, day.month, day.day));

  String _label(PomaScheduleEvent tile) =>
      '${tile.event.title}, ${tile.sourceLabel}, ${agenda!.eventDetails(tile.event)}';

  @override
  Widget build(BuildContext context) {
    final data = reader, projection = agenda;
    if (data == null || projection == null) {
      return const Text(
        'Google Calendar viewing is unavailable in this build.',
      );
    }
    if (!_visible) return const SizedBox.shrink();
    final status = projection.scheduleStatus;
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
        final wide = constraints.maxWidth >= 700 && !largeText;
        final compactView = largeText ? ScheduleView.agenda : ScheduleView.day;
        final view = _choice == ScheduleView.sevenDays && !wide
            ? compactView
            : _choice ?? (wide ? ScheduleView.sevenDays : compactView);
        return FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flex(
                direction: constraints.maxWidth >= 900 && !largeText
                    ? Axis.horizontal
                    : Axis.vertical,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (constraints.maxWidth >= 900 && !largeText)
                    Expanded(child: _statusSummary(status.title, status.body))
                  else
                    _statusSummary(status.title, status.body),
                  const SizedBox(width: PomaSpace.lg, height: PomaSpace.sm),
                  Wrap(
                    spacing: PomaSpace.xs,
                    runSpacing: PomaSpace.xs,
                    children: [
                      TextButton.icon(
                        onPressed: () => widget.desktop.openCalendarSection(
                          CalendarPageSection.settings,
                        ),
                        icon: const Icon(Icons.tune),
                        label: Text(
                          data.selected.isEmpty
                              ? 'Choose calendars'
                              : 'Calendar settings',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            data.connection.mayRead &&
                                !data.loading &&
                                !data.saving &&
                                !data.refreshing
                            ? () async {
                                projection.retryFormatting();
                                await data.retry();
                              }
                            : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh schedule'),
                      ),
                    ],
                  ),
                ],
              ),
              if (projection.formattingUnavailable)
                const Text(
                  'Local time formatting is unavailable. Check Windows regional settings, then refresh.',
                ),
              if (projection.actionMessage != null)
                Text(projection.actionMessage!),
              if (data.failure != null) Text(_problem(data.failure!)),
              if (data.loading || data.refreshing || data.saving)
                const LinearProgressIndicator(
                  semanticsLabel: 'Updating calendar schedule',
                ),
              // Keep the calendar visible before setup; unloaded cells never
              // establish an empty or free schedule.
              const SizedBox(height: PomaSpace.md),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: PomaSpace.xs,
                runSpacing: PomaSpace.xs,
                children: [
                  for (final option in ScheduleView.values)
                    ChoiceChip(
                      label: Text(switch (option) {
                        ScheduleView.sevenDays => 'Next 7 days',
                        ScheduleView.day => 'Day',
                        ScheduleView.agenda => 'Agenda',
                      }),
                      selected: view == option,
                      onSelected: option == ScheduleView.sevenDays && !wide
                          ? null
                          : (_) => setState(() => _choice = option),
                    ),
                  _dateControls(view),
                ],
              ),
              const SizedBox(height: PomaSpace.sm),
              if (view == ScheduleView.sevenDays)
                Text(
                  '${_date(data.window.first)} – ${_date(data.window.until.plusDays(-1))}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              if (!_hasSelection)
                const Text('Calendar not loaded. Your availability is unknown.')
              else if (!projection.verified(data.window) ||
                  data.loading ||
                  data.saving)
                const Text(
                  'Missing or stale calendar data does not mean that time is free.',
                ),
              const SizedBox(height: PomaSpace.sm),
              if (view == ScheduleView.agenda)
                _agendaList()
              else
                _timeline(view),
              const SizedBox(height: PomaSpace.md),
              Text(
                'Device timezone: ${DateTime.now().timeZoneName}. '
                'Supported dates: ${_date(data.window.first)} – ${_date(data.window.until.plusDays(-1))}.',
              ),
              const Text(
                'To create or change a Poma block, use Focus blocks. Starting a timer is always manual.',
              ),
              TextButton(
                onPressed: () => widget.desktop.openCalendarSection(
                  CalendarPageSection.focusBlocks,
                ),
                child: const Text('Manage focus blocks'),
              ),
              if (_hasSelection) _sourceStatus(),
            ],
          ),
        );
      },
    );
  }

  Widget _statusSummary(String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          title,
          key: const ValueKey('schedule-status'),
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ),
      const SizedBox(height: PomaSpace.xxs),
      Text(body, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _dateControls(ScheduleView view) => Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: PomaSpace.xs,
    runSpacing: PomaSpace.xs,
    children: [
      OutlinedButton(
        onPressed: () {
          setState(() => _selectedDay = reader!.window.first);
          _calendar?.jumpToDate(reader!.window.startUtc);
        },
        child: const Text('Today'),
      ),
      if (view == ScheduleView.day) ...[
        IconButton(
          tooltip: 'Previous supported day',
          icon: const Icon(Icons.chevron_left),
          onPressed: _selectedDay!.compareTo(reader!.window.first) > 0
              ? () => _move(-1)
              : null,
        ),
        Text(_date(_selectedDay!)),
        IconButton(
          tooltip: 'Next supported day',
          icon: const Icon(Icons.chevron_right),
          onPressed:
              _selectedDay!.plusDays(1).compareTo(reader!.window.until) < 0
              ? () => _move(1)
              : null,
        ),
      ],
    ],
  );

  void _move(int days) {
    setState(() => _selectedDay = _selectedDay!.plusDays(days));
    _calendar?.jumpToDate(reader!.clock.dayWindow(_selectedDay!).startUtc);
  }

  Widget _timeline(ScheduleView view) {
    final readOnly = k.KalenderInteraction(
      allowEventCreation: false,
      allowRescheduling: false,
      allowResizing: false,
    );
    final tiles = k.TileComponents(
      tileBuilder: (context, event, _) => _tile(event as PomaScheduleEvent),
    );
    // The page owns notices and controls; this bounded viewport alone owns the
    // time-of-day scroll. Never use Expanded inside PomaPage's ListView.
    return _TimelineConfiguration(
      controller: _calendar!,
      configurationKey:
          '${reader!.window.key}/$view/${widget.desktop.calendarPresentationRevision}',
      configuration: scheduleViewConfiguration(
        reader!.window,
        sevenDays: view == ScheduleView.sevenDays,
        selectedDate: reader!.clock.dayWindow(_selectedDay!).startUtc,
      ),
      child: Container(
        key: const ValueKey('schedule-timeline'),
        height: math.max(
          400,
          math.min(640, MediaQuery.sizeOf(context).height * .65),
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: k.KalenderTheme(
          data: k.KalenderThemeData(
            hourLinesStyle: MediaQuery.highContrastOf(context)
                ? k.HourLinesStyle(color: Theme.of(context).colorScheme.outline)
                : null,
            daySeparatorStyle: MediaQuery.highContrastOf(context)
                ? k.DaySeparatorStyle(
                    color: Theme.of(context).colorScheme.outline,
                  )
                : null,
          ),
          child: k.KalenderView(
            eventsController: _events,
            kalenderController: _calendar!,
            locale: WidgetsBinding.instance.platformDispatcher.locale,
            interaction: readOnly,
            callbacks: k.KalenderCallbacks(
              onPageChanged: (range) {
                if (view != ScheduleView.day) return;
                final date = range.start;
                final day = CalendarDate(date.year, date.month, date.day);
                if (day.compareTo(reader!.window.first) < 0 ||
                    day.compareTo(reader!.window.until) >= 0) {
                  return;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedDay!.compareTo(day) != 0) {
                    setState(() => _selectedDay = day);
                  }
                });
              },
            ),
            views: [
              k.MultiDayViewParts(
                header: k.MultiDayHeader(
                  interaction: readOnly,
                  tileComponents: tiles,
                ),
                body: k.MultiDayBody(
                  interaction: readOnly,
                  tileComponents: tiles,
                  configuration: const k.MultiDayBodyConfiguration(
                    eventLayoutStrategy: k.EventLayoutStrategy.sideBySide(),
                    minimumTileHeight: 32,
                    pageScrollPhysics: NeverScrollableScrollPhysics(),
                  ),
                ),
              ),
            ],
            components: k.KalenderComponents(
              multiDayComponents: k.MultiDayComponents(
                headerComponents: k.MultiDayHeaderComponents(
                  weekNumberBuilder: (_, _) => const SizedBox.shrink(),
                  dayHeaderBuilder: (context, date) {
                    final day = CalendarDate(date.year, date.month, date.day);
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: PomaSpace.xs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${DeviceFormats.weekday(context, date)} ${date.day}',
                          ),
                          Text(
                            !_hasSelection || reader!.loading || reader!.saving
                                ? 'Not loaded'
                                : projectionVerified(day)
                                ? 'Verified'
                                : 'Unverified',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                bodyComponents: k.MultiDayBodyComponents(
                  timelineStringBuilder: (_, time) =>
                      agenda!.timelineLabel(time.hour, time.minute),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool projectionVerified(CalendarDate day) =>
      _hasSelection &&
      !reader!.loading &&
      !reader!.saving &&
      !reader!.connection.cleanupPending &&
      agenda!.verified(reader!.clock.dayWindow(day));

  Widget _agendaList() => Column(
    key: const ValueKey('schedule-agenda'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final day in agenda!.days) ...[
        Padding(
          padding: const EdgeInsets.only(
            top: PomaSpace.md,
            bottom: PomaSpace.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              '${_date(day)}${projectionVerified(day) ? '' : ' · Unverified'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        ..._dayEvents(day),
      ],
    ],
  );

  List<Widget> _dayEvents(CalendarDate day) {
    final items =
        events
            .where((e) => e.event.overlaps(reader!.clock.dayWindow(day)))
            .toList()
          ..sort((a, b) {
            if (a.event.allDay != b.event.allDay) {
              return a.event.allDay ? -1 : 1;
            }
            final time = a.start.compareTo(b.start);
            return time != 0 ? time : a.id.compareTo(b.id);
          });
    if (items.isEmpty) {
      return [
        Text(
          projectionVerified(day)
              ? 'No events on this verified day.'
              : 'No saved events for this day. Schedule unavailable or unverified.',
        ),
      ];
    }
    return [
      for (final tile in items)
        Padding(
          padding: const EdgeInsets.only(bottom: PomaSpace.xs),
          child: Semantics(
            label: _label(tile),
            button: true,
            selected: _selectedEvent == tile.id,
            child: ExcludeSemantics(
              child: OutlinedButton(
                key: ValueKey('agenda-${tile.id}-$day'),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(PomaSpace.md),
                ),
                onPressed: () => _open(tile),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tile.event.title),
                    Text(agenda!.eventDetails(tile.event)),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _tile(PomaScheduleEvent tile) {
    final colors = Theme.of(context).colorScheme;
    final background =
        MediaQuery.highContrastOf(context) || tile.sourceColor == null
        ? colors.primary
        : Color(
            0xff000000 | int.parse(tile.sourceColor!.substring(1), radix: 16),
          );
    final foreground = background.computeLuminance() > .179
        ? Colors.black
        : Colors.white;
    final selected = tile.id == _selectedEvent;
    final title = tile.event.selfResponse == 'needsAction'
        ? 'Response needed: ${tile.event.title}'
        : tile.event.status == 'tentative' ||
              tile.event.selfResponse == 'tentative'
        ? 'Tentative: ${tile.event.title}'
        : tile.event.title;
    return Semantics(
      button: true,
      label: _label(tile),
      selected: selected,
      child: ExcludeSemantics(
        child: Tooltip(
          message: _label(tile),
          child: Material(
            color: background,
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('tile-${tile.id}'),
              onTap: () => _open(tile),
              focusColor: foreground.withValues(alpha: .25),
              child: Container(
                decoration: BoxDecoration(
                  border: selected
                      ? Border.all(color: foreground, width: 3)
                      : null,
                ),
                child: LayoutBuilder(
                  builder: (context, box) => Padding(
                    padding: EdgeInsets.all(box.maxHeight < 24 ? 2 : 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.labelLarge?.copyWith(color: foreground),
                          ),
                        ),
                        if (box.maxHeight > 84)
                          Text(
                            tile.sourceLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: foreground),
                          ),
                        if (box.maxHeight > 110 &&
                            (tile.event.status == 'tentative' ||
                                tile.event.selfResponse == 'tentative' ||
                                tile.event.selfResponse == 'needsAction'))
                          Text(
                            tile.event.selfResponse == 'needsAction'
                                ? 'Response needed'
                                : 'Tentative',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: foreground),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sourceStatus() => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: const Text('Calendar freshness and coverage'),
    children: [
      for (final source in reader!.sources.where(
        (s) => reader!.selected.contains(s.id),
      ))
        Padding(
          padding: const EdgeInsets.only(bottom: PomaSpace.sm),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              [
                agenda!.sourceLabel(source.id),
                if (reader!.snapshots[source.id] case final saved?) ...[
                  saved.succeededAt.isAfter(reader!.now)
                      ? 'Saved timestamp needs verification'
                      : 'Updated ${reader!.now.difference(saved.succeededAt).inMinutes} min ago',
                  saved.coverage.covers(reader!.window)
                      ? 'Seven-date coverage'
                      : 'Partial coverage',
                ] else
                  'No saved schedule',
                if (reader!.sourceFailures[source.id] case final failure?)
                  _problem(failure),
              ].join(' · '),
            ),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    widget.desktop.removeListener(_changed);
    // Any event route is also removed when its page goes away.
    final route = _details;
    if (route?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      });
    }
    _calendar?.dispose();
    _events.feedbackWidgetSize.dispose();
    _events.dispose();
    super.dispose();
  }
}

/// Applies view changes before the calendar subtree builds, so timer rebuilds
/// never recreate its controllers or change the selected date and scroll.
class _TimelineConfiguration extends StatefulWidget {
  const _TimelineConfiguration({
    required this.controller,
    required this.configuration,
    required this.configurationKey,
    required this.child,
  });
  final k.KalenderController controller;
  final k.MultiDayViewConfiguration configuration;
  final String configurationKey;
  final Widget child;
  @override
  State<_TimelineConfiguration> createState() => _TimelineConfigurationState();
}

class _TimelineConfigurationState extends State<_TimelineConfiguration> {
  void _apply() {
    widget.controller.viewConfiguration = widget.configuration;
    widget.controller.jumpToDate(widget.configuration.initialDateTime!);
  }

  @override
  void initState() {
    super.initState();
    _apply();
  }

  @override
  void didUpdateWidget(_TimelineConfiguration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.configurationKey != oldWidget.configurationKey) _apply();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

String _problem(CalendarReadFailure failure) => switch (failure.kind) {
  CalendarReadFailureKind.network =>
    'Google could not be reached. Saved data may have changed.',
  CalendarReadFailureKind.authorization =>
    'Reconnect Google in Calendar settings.',
  CalendarReadFailureKind.forbidden =>
    'Calendar access is restricted. Check access, then refresh.',
  CalendarReadFailureKind.throttled =>
    'Google requested a pause. Refresh respects its retry delay.',
  CalendarReadFailureKind.storage =>
    'Calendar storage needs attention. Repair storage and retry.',
  CalendarReadFailureKind.response =>
    'Incomplete response. Previous saved data is retained.',
  CalendarReadFailureKind.cancelled => 'Calendar refresh cancelled.',
};

class _ScheduleDetails extends StatelessWidget {
  const _ScheduleDetails({
    required this.tile,
    required this.desktop,
    required this.agenda,
    required this.scopeGeneration,
  });
  final PomaScheduleEvent tile;
  final DesktopController desktop;
  final CalendarAgendaController agenda;
  final int scopeGeneration;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([agenda, desktop]),
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final e = tile.event;
    if (desktop.sessionState != 'unlocked' ||
        desktop.calendarSection != CalendarPageSection.schedule ||
        agenda.reader.scopeGeneration != scopeGeneration ||
        agenda.reader.saving ||
        agenda.reader.loading ||
        !agenda.events.any(
          (current) => jsonEncode(current.toJson()) == tile.fingerprint,
        )) {
      return const SizedBox.shrink();
    }
    String date(CalendarDate value) => DeviceFormats.date(
      context,
      DateTime(value.year, value.month, value.day),
    );
    String instant(DateTime value) =>
        '${DeviceFormats.date(context, value.toLocal())}, '
        '${agenda.timeLabel(value)} (${value.toLocal().timeZoneName})';
    return AlertDialog(
      scrollable: true,
      title: Text(e.title),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tile.sourceLabel),
          const SizedBox(height: PomaSpace.sm),
          if (e.allDay)
            Text(
              'All day: ${date(e.startDate!)} – ${date(e.endDate!.plusDays(-1))}',
            )
          else ...[
            Text('Starts: ${instant(e.startUtc!)}'),
            Text('Ends: ${instant(e.endUtc!)}'),
          ],
          const SizedBox(height: PomaSpace.sm),
          Text(
            e.status == 'tentative' || e.selfResponse == 'tentative'
                ? 'Tentative'
                : 'Confirmed',
          ),
          if (e.selfResponse == 'needsAction') const Text('Response needed'),
          if (agenda.actionMessage != null)
            Semantics(liveRegion: true, child: Text(agenda.actionMessage!)),
          if (!agenda.verified(agenda.reader.window))
            const Text(
              'Saved or incomplete schedule. This event may have changed.',
            ),
        ],
      ),
      actions: [
        if (safeCalendarUrl(e.eventUrl, meeting: false) != null)
          TextButton(
            onPressed: () => agenda.openEvent(
              e,
              kind: 'event',
              unlocked: desktop.sessionState == 'unlocked',
            ),
            child: const Text('Open event'),
          ),
        if (safeCalendarUrl(e.meetingUrl, meeting: true) != null)
          TextButton(
            onPressed: () => agenda.openEvent(
              e,
              kind: 'join',
              unlocked: desktop.sessionState == 'unlocked',
            ),
            child: const Text('Join'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
