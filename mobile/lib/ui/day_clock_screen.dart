import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../application/calendar_agenda_controller.dart';
import '../application/day_clock_controller.dart';
import '../application/desktop_controller.dart';
import '../domain/calendar_data.dart';
import '../domain/day_clock.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'day_clock_dial.dart';
import 'day_clock_task_form.dart';
import 'design_tokens.dart';

class DayClockScreen extends StatefulWidget {
  const DayClockScreen({required this.app, required this.desktop, super.key});
  final AppController app;
  final DesktopController desktop;
  @override
  State<DayClockScreen> createState() => _DayClockScreenState();
}

class _DayClockScreenState extends State<DayClockScreen> {
  DialogRoute<void>? _form;
  final _detailsKey = GlobalKey();
  final _dialKey = GlobalKey();
  final _addFocus = FocusNode(debugLabel: 'Day Clock Add task');
  final _nowFocus = FocusNode(debugLabel: 'Day Clock Now');
  final _draftFocus = <String, FocusNode>{};
  String? _focusedEvent;
  DayClockController? get clock => widget.desktop.dayClock;
  @override
  void initState() {
    super.initState();
    widget.desktop.addListener(_visibility);
  }

  void _visibility() {
    if (widget.desktop.sessionState != 'unlocked' ||
        widget.desktop.destination != 5) {
      _closeForm();
    }
  }

  void _closeForm() {
    final route = _form;
    _form = null;
    if (route?.isActive == true) route!.navigator?.removeRoute(route);
  }

  Future<void> _add({
    double? minute,
    String? restoreId,
    FocusNode? opener,
  }) async {
    final c = clock;
    if (c == null || !c.unlocked || _form != null) return;
    final origin = opener?.context ?? _dialKey.currentContext;
    final position = origin == null
        ? null
        : Scrollable.maybeOf(origin)?.position;
    if (restoreId == null) {
      c.beginDraft(minute: minute);
    } else {
      c.restoreCreationDraft(restoreId);
    }
    final route = DialogRoute<void>(
      context: context,
      builder: (_) => DayClockTaskForm(clock: c, app: widget.app),
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    );
    _form = route;
    await Navigator.of(context).push(route);
    if (identical(_form, route)) _form = null;
    if (mounted && c.unlocked && widget.desktop.destination == 5) {
      bool visible(FocusNode node) {
        final nodeContext = node.context;
        if (nodeContext == null || !nodeContext.mounted) return false;
        final box = nodeContext.findRenderObject();
        if (!node.canRequestFocus ||
            box is! RenderBox ||
            !box.attached ||
            !box.hasSize) {
          return false;
        }
        final rect = box.localToGlobal(Offset.zero) & box.size;
        final screen = Offset.zero & MediaQuery.sizeOf(context);
        return screen.contains(rect.topLeft) &&
            screen.contains(rect.bottomRight - const Offset(1, 1));
      }

      final target = [?opener, _addFocus, _nowFocus].where(visible).firstOrNull;
      if (target != null) {
        target.requestFocus();
      } else if (position?.hasPixels == true) {
        // Sliver children can have left the tree while the form was open.
        // Rebuild a visible opener before restoring focus, without animation.
        position!.jumpTo(0);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted &&
            c.unlocked &&
            widget.desktop.destination == 5 &&
            _addFocus.context?.mounted == true) {
          _addFocus.requestFocus();
        }
      }
    }
  }

  void _select(CalendarEvent event) {
    clock!.select(event);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _detailsKey.currentContext;
      if (mounted && target != null) {
        unawaited(
          Scrollable.ensureVisible(
            target,
            duration: Duration.zero,
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          ),
        );
      }
    });
  }

  Widget panel(Widget child) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
    child: Padding(padding: const EdgeInsets.all(PomaSpace.md), child: child),
  );

  Widget scheduleStatus() {
    final c = clock!,
        theme = Theme.of(context),
        status = c.agenda.scheduleStatus;
    final healthy =
        c.covered &&
        c.canRead &&
        c.agenda.verified(c.reader.window) &&
        c.reader.paletteFailure == null;
    final actions = [
      TextButton.icon(
        style: TextButton.styleFrom(
          disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: c.reader.connection.mayRead && !c.reader.refreshing
            ? () => c.reader.retry()
            : null,
        icon: const Icon(Icons.refresh),
        label: Text(c.reader.refreshing ? 'Refreshing…' : 'Refresh schedule'),
      ),
      TextButton.icon(
        onPressed: () =>
            widget.desktop.openCalendarSection(CalendarPageSection.settings),
        icon: const Icon(Icons.tune),
        label: Text(
          c.reader.selected.isEmpty ? 'Choose calendars' : 'Calendar settings',
        ),
      ),
    ];
    if (healthy) {
      return Material(
        key: const ValueKey('day-clock-healthy-status'),
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: PomaSpace.md,
            vertical: PomaSpace.xxs,
          ),
          child: Wrap(
            spacing: PomaSpace.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: PomaSpace.xs),
                  Text(status.title, style: theme.textTheme.titleSmall),
                ],
              ),
              ...actions,
            ],
          ),
        ),
      );
    }
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            !c.covered ? 'Not loaded' : status.title,
            style: theme.textTheme.titleSmall,
          ),
          Text(
            !c.covered
                ? 'This date is outside the retained seven-date window. Availability is unknown. Select Now to return.'
                : status.body,
          ),
          Wrap(
            spacing: PomaSpace.xs,
            runSpacing: PomaSpace.xs,
            children: actions,
          ),
          if (c.reader.paletteFailure != null)
            const Text(
              'Google colours could not be refreshed. Retained colours and events are kept.',
            ),
        ],
      ),
    );
  }

  String day(CalendarDate d) =>
      DeviceFormats.date(context, DateTime(d.year, d.month, d.day));
  String sourceStatus(CalendarSource source) {
    final c = clock!, saved = c.reader.snapshots[source.id];
    final text = saved == null
        ? 'no saved schedule'
        : saved.succeededAt.isAfter(c.reader.now)
        ? 'saved timestamp needs verification'
        : 'updated ${c.reader.now.difference(saved.succeededAt).inMinutes} min ago; '
              '${saved.coverage.covers(c.reader.clock.dayWindow(c.date)) ? 'date covered' : 'partial coverage'}';
    return '${c.agenda.sourceLabel(source.id)}: $text'
        '${c.reader.sourceFailures.containsKey(source.id) ? '; refresh needs attention' : ''}';
  }

  Color color(CalendarEvent event) {
    final c = clock!,
        source = c.reader.sources
            .where((s) => s.id == event.calendarId)
            .firstOrNull;
    return clockColor(
      calendarEventFill(event, source, c.reader.palette),
      Theme.of(context).colorScheme.outline,
    );
  }

  Widget summary(
    String label,
    CalendarEvent? event, {
    int additional = 0,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: PomaSpace.xxs),
      Text(
        event?.title ??
            (!clock!.agenda.verified(clock!.reader.window)
                ? 'Availability unknown — schedule is incomplete or unverified'
                : label == 'Now'
                ? 'No timed event now'
                : 'No next event in retained coverage'),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      if (event != null)
        Text(
          '${clock!.agenda.timeLabel(event.startUtc!)} – ${clock!.agenda.timeLabel(event.endUtc!)}',
        ),
      if (event != null && !clock!.agenda.verified(clock!.reader.window))
        const Text('Retained event; schedule is incomplete or unverified.'),
      if (additional > 0)
        Text(
          '$additional other event${additional == 1 ? '' : 's'} at this time',
        ),
    ],
  );
  Widget agenda() {
    final c = clock!, p = c.projection, theme = Theme.of(context);
    final nowNext = CalendarNowNext(
      c.canRead ? c.agenda.events : [],
      c.reader.now,
    );
    Widget row(CalendarEvent event) {
      final selected = calendarEventIdentity(event) == c.selectedIdentity;
      final focused = calendarEventIdentity(event) == _focusedEvent;
      final source = c.reader.sources
          .where((s) => s.id == event.calendarId)
          .firstOrNull;
      final unresolved =
          calendarEventFill(event, source, c.reader.palette) == null &&
          (event.colorId?.isNotEmpty == true ||
              event.eventLabelId?.isNotEmpty == true);
      return Padding(
        padding: const EdgeInsets.only(bottom: PomaSpace.xs),
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
              side: selected || focused
                  ? BorderSide(
                      color: theme.colorScheme.primary,
                      width: focused ? 3 : 2,
                    )
                  : BorderSide.none,
            ),
            child: InkWell(
              key: ValueKey('day-clock-event-${calendarEventIdentity(event)}'),
              borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
              onTap: () => _select(event),
              onFocusChange: (value) => setState(() {
                _focusedEvent = value
                    ? calendarEventIdentity(event)
                    : _focusedEvent == calendarEventIdentity(event)
                    ? null
                    : _focusedEvent;
              }),
              child: Container(
                padding: const EdgeInsets.all(PomaSpace.sm),
                decoration: selected || focused
                    ? null
                    : BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color(event),
                        border: Border.all(color: theme.colorScheme.onSurface),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: PomaSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.title, style: theme.textTheme.titleSmall),
                          Text(
                            event.allDay
                                ? 'All day'
                                : '${c.agenda.timeLabel(event.startUtc!)} – ${c.agenda.timeLabel(event.endUtc!)}',
                          ),
                          Text(
                            c.agenda.sourceLabel(event.calendarId),
                            style: theme.textTheme.bodySmall,
                          ),
                          if (event.status == 'tentative' ||
                              event.selfResponse == 'tentative')
                            const Text('Tentative'),
                          if (event.selfResponse == 'needsAction')
                            const Text('Response needed'),
                          if (unresolved)
                            const Text('Google event colour unavailable'),
                          if (selected) const Text('Selected'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.selectedEvent case final selected?)
            Padding(
              key: _detailsKey,
              padding: const EdgeInsets.only(top: PomaSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(selected.title, style: theme.textTheme.titleLarge),
                  Text(c.agenda.sourceLabel(selected.calendarId)),
                  const SizedBox(height: PomaSpace.xs),
                  if (selected.allDay)
                    Text(
                      'All day: ${day(selected.startDate!)} – ${day(selected.endDate!.plusDays(-1))}',
                    )
                  else ...[
                    Text(
                      'Starts: ${day(CalendarDate(c.localize(selected.startUtc!).year, c.localize(selected.startUtc!).month, c.localize(selected.startUtc!).day))}, '
                      '${c.agenda.timeLabel(selected.startUtc!)} (${dayClockOffset(c.localize(selected.startUtc!).timeZoneOffset.inMinutes)})',
                    ),
                    Text(
                      'Ends: ${day(CalendarDate(c.localize(selected.endUtc!).year, c.localize(selected.endUtc!).month, c.localize(selected.endUtc!).day))}, '
                      '${c.agenda.timeLabel(selected.endUtc!)} (${dayClockOffset(c.localize(selected.endUtc!).timeZoneOffset.inMinutes)})',
                    ),
                  ],
                  if (!c.agenda.verified(c.reader.clock.dayWindow(c.date)))
                    const Text(
                      'Saved or incomplete schedule. This event may have changed.',
                    ),
                  Wrap(
                    spacing: PomaSpace.xs,
                    runSpacing: PomaSpace.xs,
                    children: [
                      if (safeCalendarUrl(selected.eventUrl, meeting: false) !=
                          null)
                        TextButton(
                          onPressed: () => c.agenda.openEvent(
                            selected,
                            kind: 'event',
                            unlocked: c.unlocked,
                          ),
                          child: const Text('Open event'),
                        ),
                      if (safeCalendarUrl(selected.meetingUrl, meeting: true) !=
                          null)
                        TextButton(
                          onPressed: () => c.agenda.openEvent(
                            selected,
                            kind: 'join',
                            unlocked: c.unlocked,
                          ),
                          child: const Text('Join'),
                        ),
                    ],
                  ),
                  if (c.agenda.actionMessage case final message?)
                    Semantics(liveRegion: true, child: Text(message)),
                ],
              ),
            ),
          if (c.selectedEvent != null) const Divider(height: PomaSpace.xl),
          if (c.followingNow) ...[
            summary(
              'Now',
              nowNext.active.firstOrNull,
              additional: nowNext.active.length > 1
                  ? nowNext.active.length - 1
                  : 0,
            ),
            const SizedBox(height: PomaSpace.md),
            summary(
              'Next',
              nowNext.next,
              additional: nowNext.nextCount > 1 ? nowNext.nextCount - 1 : 0,
            ),
            const Divider(height: PomaSpace.xl),
          ],
          if (p.allDay.isNotEmpty) ...[
            Text('All day', style: theme.textTheme.titleLarge),
            const SizedBox(height: PomaSpace.sm),
            for (final e in p.allDay) row(e),
            const SizedBox(height: PomaSpace.md),
          ],
          Semantics(
            header: true,
            child: Text('Agenda', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: PomaSpace.sm),
          if (p.agenda.isEmpty)
            Text(
              !c.covered || !c.canRead
                  ? 'No loaded timed events for this half-day.'
                  : c.agenda.verified(c.reader.clock.dayWindow(c.date))
                  ? 'No timed events in this half-day.'
                  : 'No retained timed events. Availability is unknown.',
            ),
          for (final e in p.agenda) row(e),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = clock;
    if (c == null) {
      return PomaPage(
        controller: widget.app,
        children: const [
          ScreenHeading(title: 'Day Clock'),
          Text('Google Calendar viewing is unavailable in this build.'),
        ],
      );
    }
    return AnimatedBuilder(
      animation: Listenable.merge([c, widget.desktop]),
      builder: (context, _) {
        if (!c.unlocked) {
          return PomaPage(
            controller: widget.app,
            children: const [
              ScreenHeading(title: 'Day Clock'),
              Text('Unlock Windows to view your schedule.'),
            ],
          );
        }
        final p = c.projection;
        final theme = Theme.of(context),
            highContrast = MediaQuery.highContrastOf(context);
        final localNow = c.localize(c.reader.now);
        final overflow = p.sectors
            .where((s) => s.lane >= 4)
            .map((s) => s.identity)
            .toSet()
            .length;
        return PomaPage(
          controller: widget.app,
          maxContentWidth: PomaLayout.workspaceWidth,
          readingSurface: false,
          children: [
            ScreenHeading(
              title: 'Day Clock',
              subtitle: day(c.date),
              action: FilledButton.icon(
                key: const ValueKey('day-clock-add-task'),
                focusNode: _addFocus,
                onPressed: () => _add(opener: _addFocus),
                icon: const Icon(Icons.add),
                label: const Text('Add task'),
              ),
            ),
            scheduleStatus(),
            const SizedBox(height: PomaSpace.md),
            Wrap(
              spacing: PomaSpace.xs,
              runSpacing: PomaSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: 'Previous date',
                  onPressed:
                      c.date.plusDays(-1).compareTo(c.reader.window.first) >= 0
                      ? () => c.browse(c.date.plusDays(-1), c.half)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final first = c.reader.window.first,
                        last = c.reader.window.until.plusDays(-1);
                    final initial = c.date.compareTo(first) < 0
                        ? first
                        : c.date.compareTo(last) > 0
                        ? last
                        : c.date;
                    final chosen = await showDatePicker(
                      context: context,
                      initialDate: DateTime(
                        initial.year,
                        initial.month,
                        initial.day,
                      ),
                      firstDate: DateTime(first.year, first.month, first.day),
                      lastDate: DateTime(last.year, last.month, last.day),
                    );
                    if (chosen != null && mounted) {
                      c.browse(
                        CalendarDate(chosen.year, chosen.month, chosen.day),
                        c.half,
                      );
                    }
                  },
                  child: Text(day(c.date)),
                ),
                IconButton(
                  tooltip: 'Next date',
                  onPressed:
                      c.date.plusDays(1).compareTo(c.reader.window.until) < 0
                      ? () => c.browse(c.date.plusDays(1), c.half)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                ChoiceChip(
                  label: const Text('AM'),
                  tooltip: 'Midnight to noon',
                  selected: c.half == DayClockHalf.am,
                  selectedColor: highContrast
                      ? theme.colorScheme.primary
                      : null,
                  checkmarkColor: highContrast
                      ? theme.colorScheme.onPrimary
                      : null,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: highContrast && c.half == DayClockHalf.am
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  onSelected: (_) => c.browse(c.date, DayClockHalf.am),
                ),
                ChoiceChip(
                  label: const Text('PM'),
                  tooltip: 'Noon to midnight',
                  selected: c.half == DayClockHalf.pm,
                  selectedColor: highContrast
                      ? theme.colorScheme.primary
                      : null,
                  checkmarkColor: highContrast
                      ? theme.colorScheme.onPrimary
                      : null,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: highContrast && c.half == DayClockHalf.pm
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  onSelected: (_) => c.browse(c.date, DayClockHalf.pm),
                ),
                OutlinedButton(
                  key: const ValueKey('day-clock-now'),
                  focusNode: _nowFocus,
                  onPressed: c.now,
                  child: Text(c.followingNow ? 'Following Now' : 'Now'),
                ),
              ],
            ),
            const SizedBox(height: PomaSpace.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final dial = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DayClockDial(
                      key: _dialKey,
                      projection: p,
                      colors: {
                        for (final e in p.agenda)
                          calendarEventIdentity(e): color(e),
                      },
                      selected: c.selectedIdentity,
                      onEvent: _select,
                      onEmpty: (m) => _add(minute: m),
                      centerTime: p.handAngle == null
                          ? (c.half == DayClockHalf.am ? 'AM' : 'PM')
                          : DateFormat('h:mm').format(localNow),
                      centerLabel: p.handAngle == null
                          ? 'Browsing'
                          : (localNow.hour < 12 ? 'AM' : 'PM'),
                    ),
                    const SizedBox(height: PomaSpace.md),
                    panel(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.half == DayClockHalf.am
                                ? 'AM · Midnight to noon'
                                : 'PM · Noon to midnight',
                          ),
                          Text(
                            c.canRead &&
                                    c.covered &&
                                    c.reader.selected.isNotEmpty
                                ? '${p.scheduled.inHours}h ${p.scheduled.inMinutes % 60}m scheduled in retained events'
                                : 'Scheduled total unavailable until the date is loaded.',
                          ),
                          Text(
                            c.agenda.verified(c.reader.clock.dayWindow(c.date))
                                ? 'Gaps are unscheduled time in the loaded calendars.'
                                : 'Availability in gaps is unknown while coverage is incomplete or unverified.',
                          ),
                          if (overflow > 0)
                            Text(
                              '$overflow additional overlap${overflow == 1 ? '' : 's'}. Select any event in the agenda to highlight it.',
                            ),
                          if (c.selectedIdentity != null &&
                              p.sectors.any(
                                (s) =>
                                    s.lane >= 4 &&
                                    s.identity == c.selectedIdentity,
                              ))
                            const Text(
                              'Selected overlap is highlighted in the outer lane.',
                            ),
                          for (final span in p.window.transitions)
                            Text(
                              span.repeated
                                  ? 'Repeated local hour: separate lanes and UTC offsets identify occurrences.'
                                  : 'Skipped local hour: the hatched span has no real times.',
                            ),
                        ],
                      ),
                    ),
                  ],
                );
                if (constraints.maxWidth >= 900 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.5) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: dial),
                      const SizedBox(width: PomaSpace.lg),
                      Expanded(flex: 2, child: agenda()),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    dial,
                    const SizedBox(height: PomaSpace.lg),
                    agenda(),
                  ],
                );
              },
            ),
            const SizedBox(height: PomaSpace.md),
            panel(
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Calendar freshness and coverage'),
                children: [
                  for (final source in c.reader.sources.where(
                    (s) => c.reader.selected.contains(s.id),
                  ))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: PomaSpace.sm),
                        child: Text(sourceStatus(source)),
                      ),
                    ),
                ],
              ),
            ),
            if (c.creation?.journal case final journal?)
              if (journal.drafts.isNotEmpty || journal.operations.isNotEmpty)
                panel(
                  ExpansionTile(
                    title: const Text('Task drafts and saves'),
                    children: [
                      for (final draft
                          in journal.drafts.values.toList().reversed)
                        ListTile(
                          focusNode: _draftFocus.putIfAbsent(
                            draft.id,
                            () => FocusNode(debugLabel: 'Day Clock kept draft'),
                          ),
                          title: Text(
                            draft.title.isEmpty
                                ? 'Untitled draft'
                                : draft.title,
                          ),
                          subtitle: Text(
                            (journal.operations[draft.id] == null
                                    ? null
                                    : c.creation!.describe(
                                        journal.operations[draft.id]!,
                                      )) ??
                                'Draft · Not scheduled',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: c.creationBusy
                              ? null
                              : () => _add(
                                  restoreId: draft.id,
                                  opener: _draftFocus[draft.id],
                                ),
                        ),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _addFocus.dispose();
    _nowFocus.dispose();
    for (final node in _draftFocus.values) {
      node.dispose();
    }
    widget.desktop.removeListener(_visibility);
    final route = _form;
    if (route?.isActive == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route?.isActive == true) route!.navigator?.removeRoute(route);
      });
    }
    super.dispose();
  }
}
