import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../application/calendar_agenda_controller.dart';
import '../application/day_clock_controller.dart';
import '../application/desktop_controller.dart';
import '../domain/calendar_data.dart';
import '../domain/calendar_event_creation.dart';
import '../domain/day_clock.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'day_clock_dial.dart';
import 'day_clock_task_form.dart';
import 'design_tokens.dart';
import 'planner_screen.dart';

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
  final _eventKeys = <String, GlobalKey>{};
  final _eventFocus = <String, FocusNode>{};
  final _agendaScroll = ScrollController();
  int _seenReveal = 0;
  final _dialKey = GlobalKey();
  final _addFocus = FocusNode(debugLabel: 'Day Clock Add task');
  final _nowFocus = FocusNode(debugLabel: 'Day Clock Now');
  final _draftFocus = <String, FocusNode>{};
  String? _focusedEvent;
  DayClockController? get clock => widget.desktop.dayClock;
  @override
  void initState() {
    super.initState();
    _seenReveal = clock?.revealRevision ?? 0;
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
    await route.completed;
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
    _queueReveal();
  }

  void _select(CalendarEvent event) {
    clock!.select(event);
    _scrollToSelection();
  }

  void _queueReveal() {
    final c = clock;
    if (c == null || _form != null || c.revealRevision == _seenReveal) return;
    _seenReveal = c.revealRevision;
    _scrollToSelection();
  }

  void _scrollToSelection() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final identity = clock?.selectedIdentity;
      final target = _eventKeys[identity]?.currentContext;
      if (mounted && target != null) {
        await Scrollable.ensureVisible(
          target,
          duration: Duration.zero,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
        // Scroll offsets are painted in the following frame. Check visibility
        // only after that layout, before deciding where keyboard focus belongs.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || identity != clock?.selectedIdentity || _form != null) {
          return;
        }
        final focus = FocusManager.instance.primaryFocus;
        final focusContext = focus?.context;
        final focused = focusContext?.mounted == true
            ? focusContext!.findRenderObject()
            : null;
        final viewport = Offset.zero & MediaQuery.sizeOf(context);
        final visible =
            focus != null &&
            focus is! FocusScopeNode &&
            focused is RenderBox &&
            focused.hasSize &&
            focused.attached &&
            viewport.contains(
              focused.localToGlobal(focused.size.center(Offset.zero)),
            );
        final openerContext = _addFocus.context;
        final opener = openerContext?.mounted == true
            ? openerContext!.findRenderObject()
            : null;
        final openerVisible =
            opener is RenderBox &&
            opener.hasSize &&
            opener.attached &&
            viewport.contains(
              opener.localToGlobal(opener.size.center(Offset.zero)),
            );
        if (!visible || !openerVisible) {
          _eventFocus[identity]?.requestFocus();
        }
      }
    });
  }

  Widget panel(Widget child) => Material(
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.all(PomaSpace.md), child: child),
  );

  Widget scheduleStatus({bool compact = false}) {
    final c = clock!,
        theme = Theme.of(context),
        status = c.agenda.scheduleStatus;
    final healthy =
        c.covered && c.canRead && c.agenda.verified(c.reader.window);
    final title = !c.covered ? 'Not loaded' : status.title;
    final body = !c.covered
        ? 'Outside the retained seven-date window. Select Now to return; availability is unknown.'
        : status.body;
    final actions = <Widget>[
      IconButton(
        tooltip: c.reader.refreshing
            ? 'Refreshing schedule'
            : 'Refresh schedule',
        onPressed: c.reader.connection.mayRead && !c.reader.refreshing
            ? () => c.reader.retry()
            : null,
        icon: const Icon(Icons.refresh, size: 20),
      ),
      TextButton.icon(
        onPressed: () =>
            widget.desktop.openCalendarSection(CalendarPageSection.settings),
        icon: const Icon(Icons.tune, size: 18),
        label: Text(
          c.reader.selected.isEmpty ? 'Choose calendars' : 'Calendar settings',
        ),
      ),
    ];
    final description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        if (!healthy) Text(body, style: theme.textTheme.bodySmall),
        if (c.reader.paletteFailure != null)
          const Text(
            'Google colours could not be refreshed. Retained colours and events are kept.',
          ),
      ],
    );
    return Material(
      key: healthy ? const ValueKey('day-clock-healthy-status') : null,
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: PomaSpace.md,
          vertical: healthy ? 0 : PomaSpace.xs,
        ),
        child: compact
            ? Row(
                children: [
                  if (healthy) ...[
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: PomaSpace.xs),
                  ],
                  Expanded(child: description),
                  const SizedBox(width: PomaSpace.xs),
                  ...actions,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  description,
                  Wrap(spacing: PomaSpace.xs, children: actions),
                ],
              ),
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
    bool spacious = false,
  }) {
    final c = clock!, theme = Theme.of(context);
    final active = label == 'Now' && event != null;
    return Container(
      padding: const EdgeInsets.all(PomaSpace.sm),
      decoration: BoxDecoration(
        color: active ? theme.colorScheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: PomaSpace.sm,
              vertical: PomaSpace.xxs,
            ),
            decoration: BoxDecoration(
              color: active
                  ? color(event)
                  : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: active
                    ? clockInk(color(event))
                    : theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: PomaSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event?.title ??
                      (!c.agenda.verified(c.reader.window)
                          ? 'Availability unknown'
                          : label == 'Now'
                          ? 'No timed event now'
                          : 'No next event in retained coverage'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: spacious ? 20 : 16,
                  ),
                ),
                if (event != null)
                  Text(
                    '${c.agenda.timeLabel(event.startUtc!)} – ${c.agenda.timeLabel(event.endUtc!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: spacious ? 16 : 14,
                    ),
                  ),
                if (additional > 0)
                  Text(
                    '$additional other events at this time',
                    style: theme.textTheme.bodySmall,
                  ),
                if (event != null && !c.agenda.verified(c.reader.window))
                  const Text(
                    'Retained event; schedule is incomplete or unverified.',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget nowNext() {
    final c = clock!;
    final value = CalendarNowNext(
      c.canRead ? c.agenda.events : [],
      c.reader.now,
    );
    return LayoutBuilder(
      builder: (context, bounds) => panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summary(
              'Now',
              value.active.firstOrNull,
              additional: math.max(0, value.active.length - 1),
              spacious: bounds.maxWidth >= 400,
            ),
            const SizedBox(height: PomaSpace.xxs),
            summary(
              'Next',
              value.next,
              additional: math.max(0, value.nextCount - 1),
              spacious: bounds.maxWidth >= 400,
            ),
          ],
        ),
      ),
    );
  }

  Widget savedReceipt(CalendarCreateOperation op) {
    final c = clock!, theme = Theme.of(context);
    final event = c.savedReaderEvent(op);
    final start = c.localize(event?.startUtc ?? op.intent.startUtc);
    final end = c.localize(event?.endUtc ?? op.intent.endUtc);
    final dateFormat = DateFormat('d MMM, h:mm a');
    return Semantics(
      liveRegion: true,
      child: Material(
        key: const ValueKey('day-clock-saved-receipt'),
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
          side: BorderSide(color: theme.colorScheme.primary),
        ),
        child: Padding(
          padding: const EdgeInsets.all(PomaSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: PomaSpace.xs),
                  Expanded(
                    child: Text(
                      event?.title ?? op.intent.title,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  if (safeCalendarUrl(op.event?.eventUrl, meeting: false) !=
                      null)
                    IconButton(
                      tooltip: 'Open in Google Calendar',
                      onPressed: () => c.openSaved(op),
                      icon: const Icon(Icons.open_in_new, size: 18),
                    ),
                ],
              ),
              Text(
                '${dateFormat.format(start)} – ${start.day == end.day && start.month == end.month && start.year == end.year ? DateFormat('h:mm a').format(end) : dateFormat.format(end)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: PomaSpace.xxs),
              Text(c.savedDisplayMessage(op), style: theme.textTheme.bodySmall),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('day-clock-receipt-show'),
                  onPressed: c.revealing || c.creationBusy
                      ? null
                      : () => c.revealSaved(op),
                  icon: const Icon(Icons.schedule, size: 18),
                  label: Text(c.revealing ? 'Showing…' : 'Show on Day Clock'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget eventDetails(CalendarEvent selected) {
    final c = clock!, theme = Theme.of(context);
    return ExpansionTile(
      key: ValueKey('day-clock-details-${calendarEventIdentity(selected)}'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: const Text('Event details'),
      children: [
        Padding(
          key: _detailsKey,
          padding: const EdgeInsets.only(bottom: PomaSpace.sm),
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
      ],
    );
  }

  Widget agenda() {
    final c = clock!, p = c.projection, theme = Theme.of(context);
    Widget row(CalendarEvent event) {
      final identity = calendarEventIdentity(event);
      final selected = identity == c.selectedIdentity,
          focused = identity == _focusedEvent;
      final source = c.reader.sources
          .where((s) => s.id == event.calendarId)
          .firstOrNull;
      final unresolved =
          calendarEventFill(event, source, c.reader.palette) == null &&
          (event.colorId?.isNotEmpty == true ||
              event.eventLabelId?.isNotEmpty == true);
      return Padding(
        key: _eventKeys.putIfAbsent(identity, () => GlobalKey()),
        padding: const EdgeInsets.only(bottom: PomaSpace.xxs),
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
              key: ValueKey('day-clock-event-$identity'),
              focusNode: _eventFocus.putIfAbsent(
                identity,
                () => FocusNode(debugLabel: 'Day Clock agenda event'),
              ),
              borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
              onTap: () => _select(event),
              onFocusChange: (value) => setState(() {
                _focusedEvent = value
                    ? identity
                    : _focusedEvent == identity
                    ? null
                    : _focusedEvent;
              }),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: PomaLayout.controlHeight,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: PomaSpace.sm,
                  vertical: PomaSpace.xs,
                ),
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
                    Tooltip(
                      message: c.agenda.sourceLabel(event.calendarId),
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: PomaSpace.xxs),
                        decoration: BoxDecoration(
                          color: color(event),
                          border: Border.all(
                            color: theme.colorScheme.onSurface,
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: PomaSpace.sm),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final time = event.allDay
                              ? 'All day'
                              : '${c.agenda.timeLabel(event.startUtc!)} – ${c.agenda.timeLabel(event.endUtc!)}';
                          final spacious = constraints.maxWidth >= 320;
                          final titleStyle = theme.textTheme.titleSmall!
                              .copyWith(
                                fontSize: spacious ? 20 : 16,
                                height: 1.4,
                              );
                          final timeStyle = theme.textTheme.bodySmall!.copyWith(
                            fontSize: spacious ? 16 : 14,
                          );
                          double measure(String value, TextStyle style) {
                            final text = TextPainter(
                              text: TextSpan(text: value, style: style),
                              textDirection: Directionality.of(context),
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout();
                            final width = text.width;
                            text.dispose();
                            return width;
                          }

                          final inline =
                              measure(event.title, titleStyle) +
                                  measure(time, timeStyle) +
                                  PomaSpace.sm <=
                              constraints.maxWidth;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (inline)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        event.title,
                                        style: titleStyle,
                                      ),
                                    ),
                                    const SizedBox(width: PomaSpace.sm),
                                    Text(time, style: timeStyle),
                                  ],
                                )
                              else ...[
                                Text(event.title, style: titleStyle),
                                Text(time, style: timeStyle),
                              ],
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
                              if (selected)
                                Text(
                                  'Selected',
                                  style: theme.textTheme.bodySmall,
                                ),
                            ],
                          );
                        },
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

    final fresh =
        c.covered && c.agenda.verified(c.reader.clock.dayWindow(c.date));
    return panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text('Agenda', style: theme.textTheme.titleLarge),
                ),
              ),
              Text(
                fresh ? 'Updated' : 'Unverified',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: PomaSpace.sm),
          if (p.allDay.isNotEmpty) ...[
            Text('All day', style: theme.textTheme.titleSmall),
            for (final e in p.allDay) row(e),
            const SizedBox(height: PomaSpace.sm),
          ],
          if (p.agenda.isEmpty)
            Text(
              !c.covered || !c.canRead
                  ? 'No loaded timed events for this half-day.'
                  : fresh
                  ? 'No timed events in this half-day.'
                  : 'No retained timed events. Availability is unknown.',
            ),
          for (final e in p.agenda) row(e),
          if (c.selectedEvent case final selected?) eventDetails(selected),
        ],
      ),
    );
  }

  Widget diagnostics() {
    final c = clock!, p = c.projection;
    final overflow = p.sectors
        .where((s) => s.lane >= 4)
        .map((s) => s.identity)
        .toSet()
        .length;
    return panel(
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Calendar freshness and coverage'),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                c.half == DayClockHalf.am
                    ? 'AM · Midnight to noon'
                    : 'PM · Noon to midnight',
              ),
              Text(
                c.canRead && c.covered && c.reader.selected.isNotEmpty
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
                  '$overflow additional overlaps. Select any event in the agenda to highlight it.',
                ),
              if (c.selectedIdentity != null &&
                  p.sectors.any(
                    (s) => s.lane >= 4 && s.identity == c.selectedIdentity,
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
              const SizedBox(height: PomaSpace.sm),
              for (final source in c.reader.sources.where(
                (s) => c.reader.selected.contains(s.id),
              ))
                Padding(
                  padding: const EdgeInsets.only(bottom: PomaSpace.sm),
                  child: Text(sourceStatus(source)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget drafts() {
    final c = clock!, journal = c.creation!.journal!;
    return panel(
      ExpansionTile(
        title: const Text('Task drafts and saves'),
        tilePadding: EdgeInsets.zero,
        children: [
          for (final draft in journal.drafts.values.toList().reversed)
            ListTile(
              focusNode: _draftFocus.putIfAbsent(
                draft.id,
                () => FocusNode(debugLabel: 'Day Clock kept draft'),
              ),
              title: Text(draft.title.isEmpty ? 'Untitled draft' : draft.title),
              subtitle: Text(
                journal.operations[draft.id] == null
                    ? 'Draft · Not scheduled'
                    : c.creation!.describe(journal.operations[draft.id]!),
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
    );
  }

  List<Widget> supportingContent({bool includeReceipt = true}) {
    final c = clock!;
    return [
      if (includeReceipt && c.savedReceipt != null) ...[
        savedReceipt(c.savedReceipt!),
        const SizedBox(height: PomaSpace.sm),
      ],
      if (c.followingNow && c.reader.selected.isNotEmpty) ...[
        nowNext(),
        const SizedBox(height: PomaSpace.md),
      ],
      agenda(),
      const SizedBox(height: PomaSpace.md),
      diagnostics(),
      if (c.creation?.journal case final journal?)
        if (journal.drafts.isNotEmpty || journal.operations.isNotEmpty) ...[
          const SizedBox(height: PomaSpace.sm),
          drafts(),
        ],
    ];
  }

  Widget dateControls() {
    final c = clock!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous date',
          onPressed: c.date.plusDays(-1).compareTo(c.reader.window.first) >= 0
              ? () => c.browse(c.date.plusDays(-1), c.half)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(side: BorderSide.none),
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
                initialDate: DateTime(initial.year, initial.month, initial.day),
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
        ),
        IconButton(
          tooltip: 'Next date',
          onPressed: c.date.plusDays(1).compareTo(c.reader.window.until) < 0
              ? () => c.browse(c.date.plusDays(1), c.half)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget primaryControls() {
    final c = clock!,
        theme = Theme.of(context),
        highContrast = MediaQuery.highContrastOf(context);
    return Wrap(
      spacing: PomaSpace.xs,
      runSpacing: PomaSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final half in DayClockHalf.values)
                ChoiceChip(
                  label: Text(half == DayClockHalf.am ? 'AM' : 'PM'),
                  tooltip: half == DayClockHalf.am
                      ? 'Midnight to noon'
                      : 'Noon to midnight',
                  showCheckmark: false,
                  side: BorderSide.none,
                  selected: c.half == half,
                  selectedColor: highContrast
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primaryContainer,
                  labelStyle: theme.textTheme.labelLarge?.copyWith(
                    color: c.half == half
                        ? highContrast
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                  onSelected: (_) => c.browse(c.date, half),
                ),
            ],
          ),
        ),
        OutlinedButton(
          key: const ValueKey('day-clock-now'),
          focusNode: _nowFocus,
          onPressed: c.now,
          child: Text(c.followingNow ? 'Following Now' : 'Now'),
        ),
        FilledButton.icon(
          key: const ValueKey('day-clock-add-task'),
          focusNode: _addFocus,
          onPressed: () => _add(opener: _addFocus),
          icon: const Icon(Icons.add),
          label: const Text('Add task'),
        ),
      ],
    );
  }

  Widget header({required bool wide}) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Day Clock',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: wide ? 32 : 28,
              height: 1.25,
            ),
          ),
        ),
        dateControls(),
      ],
    );
    return wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: PomaSpace.md),
              primaryControls(),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: PomaSpace.xs),
              primaryControls(),
            ],
          );
  }

  Widget dial() {
    final c = clock!, p = c.projection, localNow = c.localize(c.reader.now);
    return DayClockDial(
      key: _dialKey,
      projection: p,
      colors: {for (final e in p.agenda) calendarEventIdentity(e): color(e)},
      selected: c.selectedIdentity,
      onEvent: _select,
      onEmpty: (m) => _add(minute: m),
      centerTime: p.handAngle == null
          ? (c.half == DayClockHalf.am ? 'AM' : 'PM')
          : DateFormat('h:mm').format(localNow),
      centerLabel: p.handAngle == null
          ? 'Browsing'
          : localNow.hour < 12
          ? 'AM'
          : 'PM',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.desktop.planner case final planner?) {
      return PlannerScreen(
        desktop: widget.desktop,
        planner: planner,
        clock: true,
      );
    }
    final c = clock;
    if (c == null || !c.unlocked) {
      return PomaPage(
        controller: widget.app,
        children: [
          const ScreenHeading(title: 'Day Clock'),
          Text(
            c == null
                ? 'Google Calendar viewing is unavailable in this build.'
                : 'Unlock Windows to view your schedule.',
          ),
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
        _queueReveal();
        return LayoutBuilder(
          builder: (context, viewport) {
            final inset = PomaLayout.pageInset(
              viewport.maxWidth,
              maxWidth: PomaLayout.workspaceWidth,
            );
            final width = viewport.maxWidth - inset * 2;
            final appNotice =
                widget.app.clockError != null ||
                widget.app.saveError != null ||
                widget.app.cleanupPending;
            final desktop =
                width >= 744 &&
                viewport.maxHeight >= 620 &&
                MediaQuery.textScalerOf(context).scale(1) < 1.5 &&
                !appNotice;
            if (!desktop) {
              return PomaPage(
                controller: widget.app,
                maxContentWidth: PomaLayout.workspaceWidth,
                readingSurface: false,
                children: [
                  header(wide: false),
                  const SizedBox(height: PomaSpace.sm),
                  scheduleStatus(),
                  const SizedBox(height: PomaSpace.md),
                  if (c.savedReceipt case final op?) ...[
                    savedReceipt(op),
                    const SizedBox(height: PomaSpace.md),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      dial(),
                      const SizedBox(height: PomaSpace.lg),
                      ...supportingContent(includeReceipt: false),
                    ],
                  ),
                ],
              );
            }
            return Padding(
              padding: EdgeInsets.fromLTRB(
                inset,
                PomaSpace.lg,
                inset,
                PomaSpace.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header(wide: true),
                  const SizedBox(height: PomaSpace.xs),
                  scheduleStatus(compact: true),
                  const SizedBox(height: PomaSpace.md),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, space) {
                        final side = ((width - PomaSpace.lg) * .39).clamp(
                          320.0,
                          440.0,
                        );
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width: math.min(
                                    width - side - PomaSpace.lg,
                                    space.maxHeight,
                                  ),
                                  height: math.min(
                                    width - side - PomaSpace.lg,
                                    space.maxHeight,
                                  ),
                                  child: dial(),
                                ),
                              ),
                            ),
                            const SizedBox(width: PomaSpace.lg),
                            SizedBox(
                              width: side,
                              child: Scrollbar(
                                controller: _agendaScroll,
                                thumbVisibility: true,
                                child: SingleChildScrollView(
                                  key: const ValueKey(
                                    'day-clock-agenda-scroll',
                                  ),
                                  controller: _agendaScroll,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: supportingContent(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _agendaScroll.dispose();
    _addFocus.dispose();
    _nowFocus.dispose();
    for (final node in _draftFocus.values) {
      node.dispose();
    }
    for (final node in _eventFocus.values) {
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
