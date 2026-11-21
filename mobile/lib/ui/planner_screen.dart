import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kalender/kalender.dart' as k;

import '../application/calendar_agenda_controller.dart';
import '../application/desktop_controller.dart';
import '../application/planner_controller.dart';
import '../domain/calendar_data.dart';
import '../domain/day_clock.dart';
import '../domain/planner.dart';
import '../domain/models.dart';
import 'calendar_schedule_adapter.dart';
import 'day_clock_dial.dart';
import 'nebula_appearance.dart';
import 'design_tokens.dart';
import 'planner_dial.dart';
import 'planner_editor.dart';
import 'calendar_sidebar.dart';
import 'app_shell.dart';
import 'calendar_theme.dart';
import 'calendar_settings_heading.dart';

void showPlannerDeletionUndo(
  BuildContext context,
  PlannerController planner,
  String scheduleId,
  String message,
) {
  final deadline = planner.data.schedules[scheduleId]?.undoUntil;
  if (deadline == null || !deadline.isAfter(planner.currentTime)) return;
  final remaining = deadline.difference(planner.currentTime);
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.removeCurrentSnackBar();
  final notice = messenger.showSnackBar(
    SnackBar(
      persist: false,
      duration: remaining,
      content: Text(message),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => planner.undoDelete(scheduleId),
      ),
    ),
  );
  // Expire at the durable deadline even if another route pauses the snackbar.
  final expiry = Timer(remaining, () {
    if (messenger.mounted) notice.close();
  });
  unawaited(notice.closed.then((_) => expiry.cancel()));
}

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({
    this.desktop,
    this.onOpenSettings,
    this.onOpenFocusBlocks,
    this.onOpenEvent,
    required this.planner,
    required this.clock,
    super.key,
  });
  final DesktopController? desktop;
  final VoidCallback? onOpenSettings, onOpenFocusBlocks;
  final Future<void> Function(CalendarEvent event, String kind)? onOpenEvent;
  final PlannerController planner;
  final bool clock;

  @override
  Widget build(BuildContext context) {
    final workspace = _PlannerWorkspace(
      desktop: desktop,
      planner: planner,
      clock: clock,
      onOpenSettings: onOpenSettings,
      onOpenFocusBlocks: onOpenFocusBlocks,
      onOpenEvent: onOpenEvent,
    );
    return clock
        ? workspace
        : Theme(data: calendarWorkspaceTheme(context), child: workspace);
  }
}

class _PlannerWorkspace extends StatefulWidget {
  const _PlannerWorkspace({
    required this.planner,
    required this.clock,
    this.desktop,
    this.onOpenSettings,
    this.onOpenFocusBlocks,
    this.onOpenEvent,
  });
  final PlannerController planner;
  final bool clock;
  final DesktopController? desktop;
  final VoidCallback? onOpenSettings, onOpenFocusBlocks;
  final Future<void> Function(CalendarEvent event, String kind)? onOpenEvent;
  @override
  State<_PlannerWorkspace> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<_PlannerWorkspace> {
  PlannerController get planner => widget.planner;
  final _agendaScroll = ScrollController();
  final _eventKeys = <String, GlobalKey>{};
  final _eventFocus = <String, FocusNode>{};
  final _gridKey = GlobalKey(), _gridHeaderKey = GlobalKey();
  final _timeCursor = FocusNode(debugLabel: 'Calendar time cursor');
  final _events = k.DefaultEventsController();
  k.KalenderController? _calendar;
  String? _configuration, _eventsFingerprint, _clockFingerprint, _seenSelection;
  DayClockProjection? _cachedClock;
  DateTime? _gridHover, _keyboardTime;
  bool _editorOpening = false;
  bool _showDeviceTasks = true;
  final _workspace = GlobalKey<ScaffoldState>();

  List<CalendarEvent> _visibleEvents(CalendarWindow range) => planner
      .eventsFor(range)
      .where(
        (event) =>
            _showDeviceTasks ||
            planner.scheduleForEvent(event)?.policy != PlannerSyncPolicy.local,
      )
      .toList();

  VoidCallback? get _openSettings =>
      widget.onOpenSettings ??
      (widget.desktop == null
          ? null
          : () => widget.desktop!.openCalendarSection(
              CalendarPageSection.settings,
            ));
  VoidCallback? get _openFocusBlocks =>
      widget.onOpenFocusBlocks ??
      (widget.desktop == null
          ? null
          : () => widget.desktop!.openCalendarSection(
              CalendarPageSection.focusBlocks,
            ));

  Future<void> _openEvent(CalendarEvent event, String kind) async {
    if (widget.onOpenEvent != null) {
      await widget.onOpenEvent!(event, kind);
    } else {
      await widget.desktop?.agenda?.openEvent(
        event,
        kind: kind,
        unlocked: planner.unlocked,
      );
    }
  }

  bool _gridGestureCancelled = false, _gridGestureActive = false;
  final _gridHoverTime = ValueNotifier<DateTime?>(null);
  final _gridDragText = ValueNotifier<String?>(null);
  int get firstWeekday {
    final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    return index == 0 ? 7 : index;
  }

  bool _wasEditorOpen = false;

  @override
  void initState() {
    super.initState();
    planner.addListener(_changed);
    _wasEditorOpen = planner.editorOpen;
    _revealSelection(focus: true);
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    final closedEditor = _wasEditorOpen && !planner.editorOpen;
    _wasEditorOpen = planner.editorOpen;
    final identity = planner.selectedIdentity;
    if (_seenSelection != identity || closedEditor) {
      _seenSelection = identity;
      _revealSelection(focus: closedEditor);
    }
  }

  void _revealSelection({bool focus = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || planner.editorOpen) return;
      final target = _eventKeys[planner.selectedIdentity]?.currentContext;
      if (target == null) {
        if (focus && !widget.clock) _timeCursor.requestFocus();
        return;
      }
      Scrollable.ensureVisible(target, duration: Duration.zero);
      if (focus) _eventFocus[planner.selectedIdentity]?.requestFocus();
    });
  }

  Future<void> _add({
    DateTime? start,
    DateTime? end,
    String? restoreId,
    bool rememberDuration = true,
  }) async {
    if (_editorOpening || !planner.unlocked || !planner.ready) return;
    _editorOpening = true;
    try {
      await showPlannerEditor(
        context,
        planner,
        startUtc: start,
        endUtc: end,
        restoreId: restoreId,
        rememberDuration: rememberDuration,
      );
    } finally {
      _editorOpening = false;
    }
  }

  Future<bool?> _scope(CalendarEvent event, String action) async {
    if (event.recurringEventId == null) return false;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('$action recurring event'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'occurrence'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: PomaSpace.sm),
              child: Text('This occurrence'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'series'),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: PomaSpace.sm),
              child: Text('Entire series'),
            ),
          ),
        ],
      ),
    );
    return result == null ? null : result == 'series';
  }

  Future<void> _edit(CalendarEvent event) async {
    final series = await _scope(event, 'Edit');
    if (series == null || !mounted) return;
    await showPlannerEditor(context, planner, event: event, series: series);
  }

  Future<bool> _move(CalendarEvent event, DateTime start, DateTime end) async {
    final series = await _scope(event, 'Change');
    if (series == null || !mounted) return false;
    return planner.moveEvent(event, start, end, series: series);
  }

  Future<void> _delete(CalendarEvent event) async {
    final series = await _scope(event, 'Delete');
    if (series == null || !mounted) return;
    final success = await planner.deleteEvent(event, series: series);
    if (!success || !mounted) return;
    final target = series ? event.recurringEventId ?? event.id : event.id;
    final schedule = planner.data.schedules.values
        .where((s) => s.calendarId == event.calendarId && s.eventId == target)
        .firstOrNull;
    if (schedule != null) {
      showPlannerDeletionUndo(
        context,
        planner,
        schedule.id,
        'Event will be deleted',
      );
    }
  }

  Future<void> _deleteTask(FocusTask task) async {
    final schedule = planner.taskSchedule(task.id);
    if (schedule == null) return;
    await planner.deleteTask(task.id);
    if (mounted && !planner.app.tasks.any((item) => item.id == task.id)) {
      showPlannerDeletionUndo(
        context,
        planner,
        schedule.id,
        'Task and schedule removed',
      );
    }
  }

  Future<void> _context(
    CalendarEvent? event,
    DateTime at,
    Offset position,
  ) async {
    final readOnly = event == null ? null : planner.readOnlyReason(event);
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        if (event != null)
          PopupMenuItem(
            value: 'edit',
            enabled: readOnly == null,
            child: const Text('Edit'),
          ),
        if (event != null)
          PopupMenuItem(
            value: 'delete',
            enabled: readOnly == null,
            child: const Text('Delete'),
          ),
        const PopupMenuItem(value: 'add', child: Text('Add task here')),
        if (event?.eventUrl != null)
          const PopupMenuItem(
            value: 'open',
            child: Text('Open in Google Calendar'),
          ),
      ],
    );
    if (!mounted) return;
    switch (selected) {
      case 'edit':
        await _edit(event!);
      case 'delete':
        await _delete(event!);
      case 'add':
        await _add(start: at);
      case 'open':
        await _openEvent(event!, 'event');
    }
  }

  Future<void> _select(CalendarEvent event, {DateTime? at}) async {
    _keyboardTime = null;
    planner.select(event, at: at);
    final content = AnimatedBuilder(
      animation: planner,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, color: color(event), size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _details(event),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  if (planner.readOnlyReason(event) == null)
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _edit(event);
                      },
                      child: const Text('Edit'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (MediaQuery.sizeOf(context).width >= 1000 &&
        MediaQuery.textScalerOf(context).scale(1) < 1.5) {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        transitionDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        pageBuilder: (context, _, _) => SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Material(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 424,
                height: double.infinity,
                child: content,
              ),
            ),
          ),
        ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: content,
        ),
      );
    }
  }

  Future<void> _atTime(DateTime at) async {
    final local = at.toLocal();
    final day = CalendarDate(local.year, local.month, local.day);
    final overlapping = planner
        .eventsFor(planner.range(day, day.plusDays(1)))
        .where(
          (event) =>
              !event.allDay &&
              !at.isBefore(event.startUtc!) &&
              at.isBefore(event.endUtc!),
        )
        .toList();
    if (overlapping.isEmpty) {
      await _add(start: at);
      return;
    }
    final chosen = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final event in overlapping)
                  ListTile(
                    title: Text(event.title),
                    subtitle: Text(eventTime(event)),
                    onTap: () => Navigator.pop(context, event),
                  ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('Add task here · ${timeLabel(at)}'),
                  onTap: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (chosen is CalendarEvent) await _select(chosen, at: at);
    if (chosen == true) await _add(start: at);
  }

  Color color(CalendarEvent event) {
    final source = planner.sources
        .where((s) => s.id == event.calendarId)
        .firstOrNull;
    return clockColor(
      calendarEventFill(event, source, planner.palette),
      const Color(0xFF3F51B5),
    );
  }

  String timeLabel(DateTime value) => DateFormat.jm().format(value.toLocal());
  String dateLabel(CalendarDate value) =>
      DateFormat.yMMMEd().format(DateTime(value.year, value.month, value.day));
  String eventTime(CalendarEvent event) => event.allDay
      ? 'All day'
      : '${timeLabel(event.startUtc!)} – ${timeLabel(event.endUtc!)}';
  String sourceLabel(CalendarEvent event) =>
      event.calendarId == 'poma-local' ||
          planner.scheduleForEvent(event)?.policy == PlannerSyncPolicy.local
      ? 'On this device'
      : planner.sources
                .where((s) => s.id == event.calendarId)
                .firstOrNull
                ?.name ??
            'Calendar unavailable';

  Widget _details(CalendarEvent event) {
    final schedule = planner.scheduleForEvent(event),
        reason = planner.readOnlyReason(event);
    final task = planner.app.tasks
        .where((task) => task.id == schedule?.taskId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(sourceLabel(event)),
        const SizedBox(height: PomaSpace.sm),
        Text(
          event.allDay
              ? '${event.startDate} – ${event.endDate}'
              : '${DateFormat.yMMMEd().add_jm().format(event.startUtc!.toLocal())}\n${DateFormat.yMMMEd().add_jm().format(event.endUtc!.toLocal())}',
        ),
        if (!event.allDay)
          Text(
            '${event.endUtc!.difference(event.startUtc!).inMinutes} minutes',
          ),
        Text(event.transparency == 'transparent' ? 'Free' : 'Busy'),
        if (event.hasGuests)
          const Text('Meeting changes can notify its guests.'),
        if (schedule != null)
          Padding(
            padding: const EdgeInsets.only(top: PomaSpace.sm),
            child: Text(planner.status(schedule)),
          ),
        if (task != null)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Completed'),
            value: planner.taskDone(task),
            onChanged: (_) => planner.app.toggleTask(task.id),
          ),
        if (reason != null)
          Padding(
            padding: const EdgeInsets.only(top: PomaSpace.sm),
            child: Text(reason),
          ),
        const SizedBox(height: PomaSpace.md),
        Wrap(
          spacing: PomaSpace.xs,
          runSpacing: PomaSpace.xs,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _add(start: planner.inspectedUtc ?? event.startUtc);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add task here'),
            ),
            if (reason == null)
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (task != null) {
                    _deleteTask(task);
                  } else {
                    _delete(event);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  task == null ? 'Delete' : 'Delete task and calendar event',
                ),
              ),
            if (event.focusOwned && _openFocusBlocks != null)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openFocusBlocks!();
                },
                child: const Text('Manage focus block'),
              ),
            if (event.eventUrl != null)
              TextButton(
                onPressed: () => _openEvent(event, 'event'),
                child: const Text('Open in Google Calendar'),
              ),
            if (event.meetingUrl != null)
              TextButton(
                onPressed: () => _openEvent(event, 'join'),
                child: const Text('Join'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final day = planner.selectedDate;
    final chosen = await showDatePicker(
      context: context,
      initialDate: DateTime(day.year, day.month, day.day),
      firstDate: DateTime(1602),
      lastDate: DateTime(9998, 12, 31),
    );
    if (chosen != null) {
      planner.browse(CalendarDate(chosen.year, chosen.month, chosen.day));
    }
  }

  void _step(int direction) {
    if (!widget.clock && planner.calendarView == PlannerCalendarView.month) {
      final day = planner.selectedDate;
      final first = DateTime.utc(day.year, day.month + direction, 1);
      planner.browse(CalendarDate(first.year, first.month, 1));
    } else {
      planner.browse(
        planner.selectedDate.plusDays(
          direction *
              (!widget.clock && planner.calendarView == PlannerCalendarView.week
                  ? 7
                  : 1),
        ),
      );
    }
  }

  Widget _toolbar(double width) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final compact = width < 1020 || scale >= 1.5;
    final add = FilledButton.icon(
      key: const ValueKey('planner-add-task'),
      onPressed: planner.ready ? () => _add(start: planner.inspectedUtc) : null,
      icon: const Icon(Icons.add),
      label: const Text('Add task'),
    );
    final unit =
        !widget.clock && planner.calendarView == PlannerCalendarView.month
        ? 'month'
        : !widget.clock && planner.calendarView == PlannerCalendarView.week
        ? 'week'
        : 'day';
    final controls = Wrap(
      spacing: PomaSpace.xs,
      runSpacing: PomaSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous $unit',
              onPressed: () => _step(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            OutlinedButton(
              key: const ValueKey('planner-selected-date'),
              onPressed: _pickDate,
              child: Text(
                DateFormat.yMMMd().format(
                  DateTime(
                    planner.selectedDate.year,
                    planner.selectedDate.month,
                    planner.selectedDate.day,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next $unit',
              onPressed: () => _step(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        TextButton(
          onPressed: planner.now,
          child: Text(widget.clock ? 'Now' : 'Today'),
        ),
        PopupMenuButton<String>(
          tooltip: 'View',
          onSelected: (value) {
            if (value == 'am' || value == 'pm') {
              planner.setClockMode(PlannerClockMode.twelveHours);
              planner.browse(
                planner.selectedDate,
                selectedHalf: value == 'am' ? 0 : 1,
              );
            } else if (widget.clock) {
              planner.setClockMode(PlannerClockMode.values.byName(value));
            } else {
              planner.setCalendarView(PlannerCalendarView.values.byName(value));
            }
          },
          itemBuilder: (_) => [
            if (widget.clock) ...[
              for (final mode in PlannerClockMode.values)
                CheckedPopupMenuItem(
                  value: mode.name,
                  checked: planner.clockMode == mode,
                  child: Text(_modeName(mode)),
                ),
              if (compact) ...[
                const PopupMenuDivider(),
                CheckedPopupMenuItem(
                  value: 'am',
                  checked: planner.half == 0,
                  child: const Text('12-hour AM'),
                ),
                CheckedPopupMenuItem(
                  value: 'pm',
                  checked: planner.half == 1,
                  child: const Text('12-hour PM'),
                ),
              ],
            ] else
              for (final view in PlannerCalendarView.values)
                CheckedPopupMenuItem(
                  value: view.name,
                  checked: planner.calendarView == view,
                  child: Text(_viewName(view)),
                ),
          ],
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 72),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('View'), Icon(Icons.arrow_drop_down)],
              ),
            ),
          ),
        ),
        if (widget.clock &&
            !compact &&
            planner.clockMode == PlannerClockMode.twelveHours)
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 0, label: Text('AM')),
              ButtonSegment(value: 1, label: Text('PM')),
            ],
            selected: {planner.half},
            onSelectionChanged: (value) =>
                planner.browse(planner.selectedDate, selectedHalf: value.first),
          ),
        if (!compact) add,
      ],
    );
    final title = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const DesktopSidebarLeading(),
        Flexible(
          child: Text(
            widget.clock ? 'Day Clock' : 'Calendar',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ],
    );
    if (!compact) {
      return Row(
        children: [
          title,
          const SizedBox(width: PomaSpace.lg),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: controls),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: PomaSpace.sm,
          runSpacing: PomaSpace.xs,
          children: [title, add],
        ),
        const SizedBox(height: PomaSpace.xs),
        controls,
      ],
    );
  }

  String _modeName(PlannerClockMode mode) => switch (mode) {
    PlannerClockMode.twelveHours => '12-hour',
    PlannerClockMode.fullDay => '24-hour',
    PlannerClockMode.threeHours => '3 hours',
    PlannerClockMode.sixHours => '6 hours',
  };
  String _viewName(PlannerCalendarView view) => switch (view) {
    PlannerCalendarView.day => 'Day',
    PlannerCalendarView.week => 'Week',
    PlannerCalendarView.month => 'Month',
    PlannerCalendarView.agenda => 'Agenda',
  };

  Widget _calendarToolbar(double width, bool sidebar) {
    final view = planner.calendarView;
    final unit = view == PlannerCalendarView.month
        ? 'month'
        : view == PlannerCalendarView.week
        ? 'week'
        : 'day';
    final date = DateTime(
      planner.selectedDate.year,
      planner.selectedDate.month,
      planner.selectedDate.day,
    );
    final title = TextButton(
      key: const ValueKey('planner-selected-date'),
      onPressed: _pickDate,
      child: Text(
        view == PlannerCalendarView.day || view == PlannerCalendarView.agenda
            ? DateFormat.yMMMMd().format(date)
            : DateFormat.yMMMM().format(date),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
    final browse = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Previous $unit',
          onPressed: () => _step(-1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Next $unit',
          onPressed: () => _step(1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
    final views = PopupMenuButton<PlannerCalendarView>(
      tooltip: 'View',
      onSelected: planner.setCalendarView,
      itemBuilder: (_) => [
        for (final option in PlannerCalendarView.values)
          CheckedPopupMenuItem(
            value: option,
            checked: option == view,
            child: Text(_viewName(option)),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_viewName(view)),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
    final today = OutlinedButton(
      onPressed: planner.now,
      child: const Text('Today'),
    );
    final menu = IconButton(
      key: const ValueKey('calendar-drawer'),
      tooltip: 'Calendars and unscheduled tasks',
      onPressed: () => _workspace.currentState?.openDrawer(),
      icon: const Icon(Icons.menu_rounded),
    );
    final create = FilledButton(
      key: const ValueKey('planner-add-task'),
      onPressed: () => _add(),
      child: const Icon(Icons.add_rounded, semanticLabel: 'Create task'),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: width >= 900 && MediaQuery.textScalerOf(context).scale(1) < 1.5
          ? Row(
              children: [
                const DesktopSidebarLeading(),
                if (!sidebar) menu,
                today,
                const SizedBox(width: 8),
                browse,
                const SizedBox(width: 12),
                Expanded(
                  child: Align(alignment: Alignment.centerLeft, child: title),
                ),
                views,
                if (!sidebar) create,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const DesktopSidebarLeading(),
                    menu,
                    Expanded(child: title),
                    create,
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [today, browse, views],
                ),
              ],
            ),
    );
  }

  Widget _calendarWorkspace(BoxConstraints viewport) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final sidebar =
        viewport.maxWidth >= 1100 && scale < 1.5 && viewport.maxHeight >= 400;
    final range = _visibleRange(viewport.maxWidth);
    planner.remoteReader?.watchRange('planner-calendar', range);
    Widget sideContent() => CalendarSidebar(
      planner: planner,
      showDeviceTasks: _showDeviceTasks,
      onDeviceTasksChanged: (value) => setState(() => _showDeviceTasks = value),
      onCreate: () {
        _workspace.currentState?.closeDrawer();
        _add();
      },
    );
    final agenda =
        planner.calendarView == PlannerCalendarView.agenda ||
        scale >= 1.5 ||
        viewport.maxHeight < 460;
    return Scaffold(
      key: _workspace,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      drawer: sidebar
          ? null
          : Drawer(
              width: math.min(360, viewport.maxWidth * .92),
              child: SafeArea(child: sideContent()),
            ),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, body) {
            if (body.maxHeight < 400) {
              return PomaPage(
                controller: planner.app,
                readingSurface: false,
                maxContentWidth: PomaLayout.workspaceWidth,
                children: [
                  _calendarToolbar(viewport.maxWidth, false),
                  _status(range),
                  _agenda(range),
                  if (planner.message case final message?) Text(message),
                  if (planner.data.drafts.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          _add(restoreId: planner.data.drafts.keys.last),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Continue saved draft'),
                    ),
                  _recovery(),
                ],
              );
            }
            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _calendarToolbar(viewport.maxWidth, sidebar),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sidebar) SizedBox(width: 240, child: sideContent()),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            sidebar ? 0 : 12,
                            0,
                            12,
                            12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _status(range),
                              if (planner.app.saveError case final error?)
                                MaterialBanner(
                                  content: Text(error),
                                  actions: [
                                    TextButton(
                                      onPressed: () async {
                                        await planner.app.retrySave();
                                        await planner.sync();
                                      },
                                      child: const Text('Retry'),
                                    ),
                                  ],
                                ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Material(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surface,
                                    child: agenda
                                        ? SingleChildScrollView(
                                            child: _agenda(range),
                                          )
                                        : LayoutBuilder(
                                            builder: (context, body) {
                                              if (planner.calendarView ==
                                                      PlannerCalendarView
                                                          .week &&
                                                  body.maxWidth < 720) {
                                                return SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  child: SizedBox(
                                                    width: 840,
                                                    height: body.maxHeight,
                                                    child: _grid(range),
                                                  ),
                                                );
                                              }
                                              return _grid(range);
                                            },
                                          ),
                                  ),
                                ),
                              ),
                              if (planner.message != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    planner.message!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                              if (planner.data.drafts.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _add(
                                      restoreId: planner.data.drafts.keys.last,
                                    ),
                                    icon: const Icon(Icons.edit_note_rounded),
                                    label: const Text('Continue saved draft'),
                                  ),
                                ),
                              if (planner.data.operations.values.any(
                                (operation) => operation.pending,
                              ))
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: viewport.maxHeight * .25,
                                  ),
                                  child: SingleChildScrollView(
                                    child: _recovery(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            return content;
          },
        ),
      ),
    );
  }

  Widget _status(CalendarWindow window) {
    if (!planner.supportsGoogle) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              'On this device',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    }
    final read = planner.reader;
    final verified = read.rangeVerified(window);
    final pending = planner.data.operations.values
        .where((op) => op.pending && op.accountKey == planner.accountKey)
        .length;
    final label = read.selected.isEmpty
        ? 'Choose calendars to load your schedule'
        : read.rangeLoading
        ? 'Loading schedule'
        : verified
        ? pending == 0
              ? 'Schedule updated'
              : '$pending waiting to sync'
        : 'Saved schedule · availability unknown';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          verified ? Icons.check_circle_outline : Icons.info_outline,
          size: 18,
        ),
        const SizedBox(width: PomaSpace.xs),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        IconButton(
          tooltip: 'Refresh schedule',
          onPressed: read.rangeLoading
              ? null
              : () async {
                  await read.retry();
                  await read.ensureRange(window, force: true);
                  await planner.sync();
                },
          icon: const Icon(Icons.refresh, size: 20),
        ),
        if (_openSettings != null)
          PopupMenuButton<String>(
            tooltip: 'Calendar settings',
            onSelected: (value) => value == 'focus'
                ? _openFocusBlocks?.call()
                : _openSettings?.call(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'settings',
                child: Text('Calendar settings'),
              ),
              PopupMenuItem(value: 'focus', child: Text('Focus blocks')),
            ],
            icon: const Icon(Icons.tune, size: 20),
          ),
      ],
    );
  }

  Widget _panel(Widget child) => Material(
    color: usesNebulaAppearance(context)
        ? NebulaColors.panel
        : Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: Padding(padding: const EdgeInsets.all(PomaSpace.md), child: child),
  );

  Widget _agenda(CalendarWindow window) {
    final events = _visibleEvents(window);
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Agenda', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: PomaSpace.sm),
          if (events.isEmpty) ...[
            Text(
              planner.rangeVerified(window)
                  ? 'No events for this date.'
                  : 'No loaded events for this date.',
            ),
            TextButton.icon(
              onPressed: () => _add(),
              icon: const Icon(Icons.add),
              label: const Text('Add a task'),
            ),
          ],
          for (final event in events) _agendaRow(event),
        ],
      ),
    );
  }

  Widget _agendaRow(CalendarEvent event) {
    final identity = calendarEventIdentity(event),
        schedule = planner.scheduleForEvent(event);
    final selected = identity == planner.selectedIdentity;
    return FocusableActionDetector(
      key: ValueKey(identity),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f2): _EditPlannerEventIntent(),
        SingleActivator(LogicalKeyboardKey.f10, shift: true):
            _ContextPlannerEventIntent(),
      },
      actions: {
        _EditPlannerEventIntent: CallbackAction<_EditPlannerEventIntent>(
          onInvoke: (_) {
            _edit(event);
            return null;
          },
        ),
        _ContextPlannerEventIntent: CallbackAction<_ContextPlannerEventIntent>(
          onInvoke: (_) {
            _context(
              event,
              event.startUtc ?? planner.currentTime,
              const Offset(500, 300),
            );
            return null;
          },
        ),
      },
      child: Semantics(
        selected: selected,
        child: InkWell(
          key: _eventKeys.putIfAbsent(identity, () => GlobalKey()),
          focusNode: _eventFocus.putIfAbsent(
            identity,
            () => FocusNode(debugLabel: 'Planner agenda ${event.id}'),
          ),
          onTap: () => _select(event),
          onSecondaryTapUp: (details) => _context(
            event,
            event.startUtc ?? planner.currentTime,
            details.globalPosition,
          ),
          borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
          child: Container(
            decoration: selected
                ? BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(
                      PomaLayout.controlRadius,
                    ),
                  )
                : null,
            padding: const EdgeInsets.symmetric(
              vertical: PomaSpace.sm,
              horizontal: PomaSpace.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: color(event),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: PomaSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(eventTime(event)),
                      Text(
                        sourceLabel(event),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (schedule != null)
                        Text(
                          planner.status(schedule),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Event actions',
                  onSelected: (action) {
                    if (action == 'edit') _edit(event);
                    if (action == 'delete') _delete(event);
                    if (action == 'add') _add(start: event.startUtc);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      enabled: planner.readOnlyReason(event) == null,
                      child: const Text('Edit'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      enabled: planner.readOnlyReason(event) == null,
                      child: const Text('Delete'),
                    ),
                    const PopupMenuItem(
                      value: 'add',
                      child: Text('Add task here'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _duration(Duration duration) => duration.inHours > 0
      ? '${duration.inHours}h ${duration.inMinutes % 60}m'
      : '${math.max(1, duration.inMinutes)} min';

  Widget _nowNext(CalendarWindow window) => ValueListenableBuilder<DateTime>(
    valueListenable: planner.clockTick,
    builder: (context, _, _) => _nowNextContent(window),
  );

  Widget _nowNextContent(CalendarWindow window) {
    final now = planner.currentTime;
    final nowNext = CalendarNowNext(planner.eventsFor(window), now);
    final active = nowNext.active.firstOrNull, next = nowNext.next;
    final gaps = planner.gaps(window, after: now);
    final free = gaps.where((g) => !g.startUtc.isAfter(now)).firstOrNull;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (active != null) ...[
            Text(
              'Now · ${active.title}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text('${_duration(active.endUtc!.difference(now))} remaining'),
            if (nowNext.active.length > 1)
              Text('${nowNext.active.length - 1} other ongoing events'),
          ] else if (free != null)
            Text(
              'Free for ${_duration(free.duration)}',
              style: Theme.of(context).textTheme.titleSmall,
            )
          else
            Text(
              planner.rangeVerified(window, availability: true)
                  ? 'No current timed event'
                  : 'Availability unknown',
            ),
          if (next != null) ...[
            const SizedBox(height: PomaSpace.xs),
            Text('Next · ${next.title} at ${timeLabel(next.startUtc!)}'),
            Text(
              'Starts in ${_duration(next.startUtc!.difference(now))}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _gaps(CalendarWindow window) {
    final isToday =
        planner.selectedDate.toString() ==
        plannerDate(planner.currentTime.toLocal());
    final gaps = planner.gaps(
      window,
      after: isToday ? planner.currentTime : null,
    );
    if (gaps.isEmpty) return const SizedBox.shrink();
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Available time',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            'In selected calendars and your local plan',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final gap in gaps.take(3))
            TextButton(
              onPressed: () => _add(
                rememberDuration: false,
                start: gap.startUtc,
                end: gap.startUtc.add(
                  Duration(
                    minutes: math.min(
                      gap.duration.inMinutes,
                      planner.preferences.durationMinutes,
                    ),
                  ),
                ),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${timeLabel(gap.startUtc)} – ${timeLabel(gap.endUtc)} · ${_duration(gap.duration)}',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _recovery() => PlannerOperations(planner: planner);

  Widget _support(CalendarWindow window) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _nowNext(window),
      const SizedBox(height: PomaSpace.md),
      _agenda(window),
      const SizedBox(height: PomaSpace.md),
      _gaps(window),
      _recovery(),
      if (planner.data.drafts.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: PomaSpace.sm),
          child: TextButton.icon(
            onPressed: () => _add(restoreId: planner.data.drafts.keys.last),
            icon: const Icon(Icons.edit_note),
            label: const Text('Continue saved draft'),
          ),
        ),
    ],
  );

  DayClockProjection _projection() {
    final date = planner.selectedDate;
    final span = switch (planner.clockMode) {
      PlannerClockMode.fullDay => 1440,
      PlannerClockMode.threeHours => 180,
      PlannerClockMode.sixHours => 360,
      _ => 720,
    };
    final anchor = (planner.inspectedUtc ?? planner.currentTime).toLocal();
    final start = planner.clockMode == PlannerClockMode.twelveHours
        ? planner.half * 720
        : planner.clockMode == PlannerClockMode.fullDay
        ? 0
        : anchor.hour * 60;
    final range = planner.range(
      date,
      date.plusDays(start + span > 1440 ? 2 : 1),
    );
    final preview = !planner.editorOpen || planner.draft == null
        ? null
        : planner.preview(planner.draft!);
    final events = [..._visibleEvents(range), ?preview];
    final key = jsonEncode([
      range.key,
      start,
      span,
      for (final e in events) e.toJson(),
    ]);
    if (_clockFingerprint != key) {
      final window = DayClockWindow.build(
        date: date,
        half: planner.half == 0 ? DayClockHalf.am : DayClockHalf.pm,
        day: range,
        localize: (value) => value.toLocal(),
        startMinute: start,
        spanMinutes: span,
      );
      _cachedClock = DayClockProjection.project(
        window: window,
        events: events,
        nowUtc: planner.currentTime,
        previousLanes: _cachedClock?.lanes ?? {},
      );
      _clockFingerprint = key;
    }
    final value = _cachedClock!;
    final minute = value.window.minuteAt(planner.currentTime);
    return DayClockProjection(
      window: value.window,
      sectors: value.sectors,
      agenda: value.agenda,
      allDay: value.allDay,
      scheduled: value.scheduled,
      handAngle: minute == null ? null : dayClockAngle(minute),
    );
  }

  Widget _clock() {
    final projection = _projection();
    final window = projection.window;
    final large = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final labels = planner.clockMode == PlannerClockMode.twelveHours
        ? null
        : [
            for (var i = 1; i <= 12; i++)
              if (large && i.isOdd)
                ''
              else
                _dialLabel(
                  window.startMinute +
                      (i == 12 ? 0 : i * window.spanMinutes ~/ 12),
                  window.spanMinutes,
                ),
          ];
    return Column(
      children: [
        Text(
          '${DateFormat.MMMd().format(DateTime(window.date.year, window.date.month, window.date.day))} · ${_windowLabel(window)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: PomaSpace.xs),
        Expanded(
          child: ValueListenableBuilder<DateTime>(
            valueListenable: planner.clockTick,
            builder: (context, _, _) => PlannerDial(
              planner: planner,
              projection: _projection(),
              colors: {
                for (final e in projection.agenda)
                  calendarEventIdentity(e): color(e),
              },
              labels: labels,
              onAdd: (at) => _add(start: at),
              onEvent: (event, at) => _select(event, at: at),
              onEdit: _edit,
              onContext: _context,
              onMove: _move,
            ),
          ),
        ),
      ],
    );
  }

  String _dialLabel(int minute, int span) => span == 1440
      ? '${(minute ~/ 60) % 24}'.padLeft(2, '0')
      : '${(minute ~/ 60) % 24}:${(minute % 60).toString().padLeft(2, '0')}';
  String _windowLabel(DayClockWindow window) {
    if (window.spanMinutes == 720) {
      return planner.half == 0 ? 'Midnight – noon' : 'Noon – midnight';
    }
    final first = DateTime.utc(
      window.date.year,
      window.date.month,
      window.date.day,
      0,
      window.startMinute,
    );
    final until = first.add(Duration(minutes: window.spanMinutes));
    return '${DateFormat.MMMd().add_Hm().format(first)} – ${DateFormat.MMMd().add_Hm().format(until)}';
  }

  CalendarWindow _visibleRange(double width) {
    if (widget.clock || planner.calendarView == PlannerCalendarView.day) {
      return planner.dayRange;
    }
    if (planner.calendarView == PlannerCalendarView.month) {
      return planner.monthRange(firstWeekday: firstWeekday);
    }
    return planner.weekRange(firstWeekday: firstWeekday);
  }

  void _configureGrid(CalendarWindow range, PlannerCalendarView view) {
    final key = '${range.key}/${view.name}';
    if (_configuration == key) return;
    final display = k.KalenderDateTimeRange(
      start: range.startUtc,
      end: range.endUtc,
    );
    final configuration = view == PlannerCalendarView.month
        ? k.MonthViewConfiguration.singleMonth(
            initialDateTime: planner.clock
                .dayWindow(planner.selectedDate)
                .startUtc,
            displayRange: display,
            firstDayOfWeek: firstWeekday,
          )
        : k.MultiDayViewConfiguration.custom(
            name: _viewName(view),
            numberOfDays: view == PlannerCalendarView.week ? 7 : 1,
            displayRange: display,
            initialDateTime: range.startUtc,
            initialTimeOfDay: const k.KalenderTime(hour: 7, minute: 45),
            initialHeightPerMinute: widget.clock ? .7 : 1.0,
          );
    if (_calendar == null) {
      _calendar = k.KalenderController(viewConfiguration: configuration);
      _calendar!.selectedEvent.addListener(_gridSelectionChanged);
    } else {
      _calendar!.viewConfiguration = configuration;
    }
    _configuration = key;
  }

  void _gridSelectionChanged() {
    if (!_gridGestureActive) return;
    final event = _calendar?.selectedEvent.value;
    if (event != null) {
      _gridDragText.value =
          '${timeLabel(event.start)} – ${timeLabel(event.end)} · ${event.duration.inMinutes} min';
    }
  }

  void _gridEvents(CalendarWindow range) {
    final preview = !planner.editorOpen || planner.draft == null
        ? null
        : planner.preview(planner.draft!);
    final events = [
      ..._visibleEvents(range),
      if (preview != null && preview.overlaps(range)) preview,
    ];
    final key = jsonEncode([
      for (final event in events)
        [
          event.toJson(),
          planner.readOnlyReason(event),
          color(event).toARGB32(),
        ],
    ]);
    if (_eventsFingerprint == key) return;
    _eventsFingerprint = key;
    _events.replaceEvents([
      for (final event in events)
        PomaScheduleEvent.fromEvent(
          event,
          clock: planner.clock,
          sourceLabel: sourceLabel(event),
          sourceColor:
              '#${color(event).toARGB32().toRadixString(16).substring(2)}',
          writable:
              event.calendarId != 'poma-draft' &&
              planner.readOnlyReason(event) == null &&
              !event.allDay,
        ),
    ]);
  }

  DateTime _snapInstant(DateTime value) => plannerSnapInstant(value);

  void _hoverGrid(
    PointerHoverEvent event,
    CalendarWindow range,
    double width,
    double gutter,
  ) {
    final view = _calendar?.viewController;
    final header =
        _gridHeaderKey.currentContext?.findRenderObject() as RenderBox?;
    if (view is! k.MultiDayViewController ||
        !view.scrollController.hasClients ||
        header == null ||
        !header.hasSize) {
      return;
    }
    final headerHeight = header.size.height;
    if (event.localPosition.dy < headerHeight ||
        event.localPosition.dx < gutter) {
      _gridHoverTime.value = null;
      return;
    }
    final count = planner.calendarView == PlannerCalendarView.week ? 7 : 1;
    final column =
        ((event.localPosition.dx - gutter) / ((width - gutter) / count))
            .floor()
            .clamp(0, count - 1);
    final date = range.first.plusDays(column);
    final minute = plannerSnapMinute(
      (event.localPosition.dy - headerHeight + view.scrollController.offset) /
          view.heightPerMinute.value,
    );
    _gridHover = DateTime(date.year, date.month, date.day, 0, minute).toUtc();
    _gridHoverTime.value = _gridHover;
  }

  KeyEventResult _gridKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final selected = planner
        .eventsFor(_visibleRange(0))
        .where(
          (candidate) =>
              calendarEventIdentity(candidate) == planner.selectedIdentity,
        )
        .firstOrNull;
    if (event.logicalKey == LogicalKeyboardKey.f2 && selected != null) {
      _edit(selected);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f10 &&
        HardwareKeyboard.instance.isShiftPressed) {
      _context(
        selected,
        planner.inspectedUtc ?? selected?.startUtc ?? planner.currentTime,
        const Offset(300, 250),
      );
      return KeyEventResult.handled;
    }
    final initial =
        _keyboardTime ??
        DateTime(
          planner.selectedDate.year,
          planner.selectedDate.month,
          planner.selectedDate.day,
          9,
        ).toUtc();
    if (const [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ].contains(event.logicalKey)) {
      final delta =
          event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowLeft
          ? -5
          : 5;
      _keyboardTime = initial.add(Duration(minutes: delta));
      _gridHoverTime.value = _keyboardTime;
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (selected != null && _keyboardTime == null) {
        _select(selected, at: planner.inspectedUtc);
      } else {
        _atTime(initial);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _gridGestureCancelled = true;
      _gridGestureActive = false;
      _calendar?.clearNewEvent();
      _calendar?.deselectEvent();
      _gridDragText.value = null;
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _tile(k.KalenderEvent value) {
    final tile = value is PomaScheduleEvent ? value : null;
    final event = tile?.event;
    final draft = event == null || event.calendarId == 'poma-draft';
    final fill = event == null
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : color(event);
    return Semantics(
      button: true,
      selected:
          event != null &&
          calendarEventIdentity(event) == planner.selectedIdentity,
      label: event == null
          ? 'Draft time range'
          : '${event.title}, ${eventTime(event)}, ${sourceLabel(event)}',
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: draft
              ? Theme.of(context).colorScheme.primary.withValues(alpha: .12)
              : fill,
          border: Border.all(
            color:
                draft ||
                    calendarEventIdentity(event) == planner.selectedIdentity
                ? Theme.of(context).colorScheme.onSurface
                : fill,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        clipBehavior: Clip.hardEdge,
        child: LayoutBuilder(
          builder: (context, box) {
            final ink = draft
                ? Theme.of(context).colorScheme.onSurface
                : clockInk(fill);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    event?.title ?? 'Draft',
                    maxLines: box.maxHeight >= 64 ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: ink),
                  ),
                ),
                if (event != null && !event.allDay && box.maxHeight >= 44)
                  Text(
                    eventTime(event),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: ink),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dayHeader(DateTime date) {
    final colors = Theme.of(context).colorScheme;
    final today = DateUtils.isSameDay(date, planner.currentTime.toLocal());
    return Semantics(
      label: DateFormat.yMMMMEEEEd().format(date),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.E().format(date),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: today ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: today ? colors.primary : null,
                ),
                child: Text(
                  '${date.day}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: today ? colors.onPrimary : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grid(CalendarWindow range) {
    final view = planner.calendarView;
    _configureGrid(range, view);
    _gridEvents(range);
    final writable = k.KalenderInteraction(
      allowEventCreation: true,
      allowRescheduling: true,
      allowResizing: true,
      inputMode: k.InputMode.auto,
      createEventGesture: widget.desktop == null
          ? null
          : k.EventInteractionGesture.tap,
      modifyEventGesture: widget.desktop == null
          ? null
          : k.EventInteractionGesture.tap,
    );
    final readOnly = k.KalenderInteraction(
      allowEventCreation: false,
      allowRescheduling: false,
      allowResizing: false,
    );
    final tiles = k.TileComponents(
      tileBuilder: (context, event, _) => _tile(event),
    );
    return Semantics(
      key: const ValueKey('calendar-accessible-agenda'),
      button: true,
      label: 'Calendar schedule',
      hint: 'Open Agenda to read events and manage tasks.',
      onTap: () => planner.setCalendarView(PlannerCalendarView.agenda),
      excludeSemantics: true,
      child: Focus(
        focusNode: _timeCursor,
        onKeyEvent: _gridKeyEvent,
        child: Column(
          children: [
            SizedBox(
              height: 28,
              child: ValueListenableBuilder<String?>(
                valueListenable: _gridDragText,
                builder: (context, drag, _) => ValueListenableBuilder<DateTime?>(
                  valueListenable: _gridHoverTime,
                  builder: (context, at, _) => Text(
                    drag ??
                        (at == null
                            ? ' '
                            : '${DateFormat.MMMd().add_jm().format(at.toLocal())} · 5-minute snap'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final gutter =
                      72.0 *
                      MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.7);
                  return MouseRegion(
                    onHover: view == PlannerCalendarView.month
                        ? null
                        : (event) =>
                              _hoverGrid(event, range, box.maxWidth, gutter),
                    onExit: (_) => _gridHoverTime.value = null,
                    child: ClipRRect(
                      key: _gridKey,
                      borderRadius: BorderRadius.circular(
                        PomaLayout.panelRadius,
                      ),
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        child: k.KalenderView(
                          eventsController: _events,
                          kalenderController: _calendar!,
                          locale:
                              WidgetsBinding.instance.platformDispatcher.locale,
                          interaction: view == PlannerCalendarView.month
                              ? readOnly
                              : writable,
                          callbacks: k.KalenderCallbacks(
                            onPageChanged: (page) {
                              if (view != PlannerCalendarView.month) return;
                              final middle = page.start
                                  .add(page.duration ~/ 2)
                                  .toLocal();
                              if (middle.year == planner.selectedDate.year &&
                                  middle.month == planner.selectedDate.month) {
                                return;
                              }
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  planner.browse(
                                    CalendarDate(middle.year, middle.month, 1),
                                  );
                                }
                              });
                            },
                            onTapped: (at) {
                              if (view == PlannerCalendarView.month) {
                                final local = at.toLocal();
                                planner.browse(
                                  CalendarDate(
                                    local.year,
                                    local.month,
                                    local.day,
                                  ),
                                );
                                planner.setCalendarView(
                                  PlannerCalendarView.day,
                                );
                              } else {
                                _timeCursor.requestFocus();
                                _atTime(_snapInstant(at));
                              }
                            },
                            onSecondaryTappedWithDetail: (detail) {
                              if (detail is k.DayDetail) {
                                _context(
                                  null,
                                  _snapInstant(detail.date),
                                  detail.renderBox.localToGlobal(
                                    detail.localOffset,
                                  ),
                                );
                              }
                            },
                            onEventTappedWithDetail: (event, detail) {
                              if (event is PomaScheduleEvent) {
                                _timeCursor.requestFocus();
                                _select(
                                  event.event,
                                  at: detail is k.DayDetail
                                      ? _snapInstant(detail.date)
                                      : event.start,
                                );
                              }
                            },
                            onEventSecondaryTappedWithDetail: (event, detail) {
                              if (event is PomaScheduleEvent) {
                                _context(
                                  event.event,
                                  _gridHover ?? event.start,
                                  detail.renderBox.localToGlobal(
                                    detail.localOffset,
                                  ),
                                );
                              }
                            },
                            onEventCreate: (event) {
                              _gridGestureCancelled = false;
                              _gridGestureActive = true;
                              _timeCursor.requestFocus();
                              _gridDragText.value =
                                  'Choose the end of the task';
                              return event;
                            },
                            onEventCreated: (event) {
                              _gridGestureActive = false;
                              _gridDragText.value = null;
                              _calendar?.clearNewEvent();
                              if (_gridGestureCancelled) return;
                              _add(
                                start: event.start.toUtc(),
                                end: event.end.toUtc(),
                              );
                            },
                            onEventChange: (event) {
                              _gridGestureCancelled = false;
                              _gridGestureActive = true;
                              _timeCursor.requestFocus();
                              _gridDragText.value =
                                  '${timeLabel(event.start)} – ${timeLabel(event.end)} · ${event.duration.inMinutes} min';
                            },
                            onEventChanged: (before, after) async {
                              _gridGestureActive = false;
                              _gridDragText.value = null;
                              if (_gridGestureCancelled) {
                                _eventsFingerprint = null;
                                setState(() {});
                                return;
                              }
                              if (before is! PomaScheduleEvent) return;
                              final success = await _move(
                                before.event,
                                after.start.toUtc(),
                                after.end.toUtc(),
                              );
                              _eventsFingerprint = null;
                              if (mounted && context.mounted) {
                                setState(() {});
                                if (success) {
                                  final schedule = planner.scheduleForEvent(
                                    before.event,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Time updated'),
                                      action: schedule == null
                                          ? null
                                          : SnackBarAction(
                                              label: 'Undo',
                                              onPressed: () => planner
                                                  .undoChange(schedule.id),
                                            ),
                                    ),
                                  );
                                }
                              }
                            },
                            dateLabel: k.GestureCallbacks<k.DayDetail>(
                              onTap: (detail) {
                                final date = detail.date.toLocal();
                                planner.browse(
                                  CalendarDate(date.year, date.month, date.day),
                                );
                                planner.setCalendarView(
                                  PlannerCalendarView.day,
                                );
                              },
                            ),
                          ),
                          views: [
                            k.MonthViewParts(
                              body: k.MonthBody(
                                interaction: readOnly,
                                tileComponents: tiles,
                              ),
                            ),
                            k.MultiDayViewParts(
                              header: Container(
                                key: _gridHeaderKey,
                                child: k.MultiDayHeader(
                                  configuration: k.MultiDayHeaderConfiguration(
                                    tileHeight: 48,
                                    showTiles: _visibleEvents(
                                      range,
                                    ).any((event) => event.allDay),
                                  ),
                                  interaction: readOnly,
                                  tileComponents: tiles,
                                  callbacks: k.KalenderCallbacks(
                                    onEventTappedWithDetail: (event, detail) {
                                      if (event is PomaScheduleEvent) {
                                        _select(event.event);
                                      }
                                    },
                                    dateLabel: k.GestureCallbacks<k.DayDetail>(
                                      onTap: (detail) {
                                        final date = detail.date.toLocal();
                                        planner.browse(
                                          CalendarDate(
                                            date.year,
                                            date.month,
                                            date.day,
                                          ),
                                        );
                                        planner.setCalendarView(
                                          PlannerCalendarView.day,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              body: Semantics(
                                label:
                                    'Calendar time grid. Select a time to add a task.',
                                child: k.MultiDayBody(
                                  interaction: writable,
                                  tileComponents: tiles,
                                  snapping: const k.KalenderSnapping(
                                    snapIntervalMinutes: 5,
                                    snapToTimeIndicator: false,
                                    snapToOtherEvents: false,
                                  ),
                                  configuration: k.MultiDayBodyConfiguration(
                                    eventLayoutStrategy:
                                        k.EventLayoutStrategy.sideBySide(),
                                    minimumTileHeight: widget.desktop == null
                                        ? 48
                                        : 32,
                                    pageScrollPhysics:
                                        const NeverScrollableScrollPhysics(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                          components: k.KalenderComponents(
                            multiDayComponents: k.MultiDayComponents(
                              headerComponents: k.MultiDayHeaderComponents(
                                dayHeaderBuilder: (_, date) => _dayHeader(date),
                                weekNumberBuilder: (_, _) =>
                                    const SizedBox.shrink(),
                              ),
                              bodyComponents: k.MultiDayBodyComponents(
                                timelineWidth: (_, _) => gutter,
                                timeIndicator:
                                    (context, times, height, location) =>
                                        k.TimeIndicator(
                                          timeOfDayRange: times,
                                          heightPerMinute: height,
                                          location: location,
                                          nowCallback: () =>
                                              planner.currentTime.toLocal(),
                                        ),
                                timelineStringBuilder: (_, time) =>
                                    DateFormat.jm().format(
                                      DateTime(
                                        2026,
                                        1,
                                        1,
                                        time.hour,
                                        time.minute,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!planner.unlocked) {
      return const Center(child: Text('Unlock Windows to view your schedule.'));
    }
    if (!planner.ready) return const Center(child: CircularProgressIndicator());
    if (!widget.clock) {
      return LayoutBuilder(
        builder: (context, viewport) => _calendarWorkspace(viewport),
      );
    }
    return LayoutBuilder(
      builder: (context, viewport) {
        final inset = PomaLayout.pageInset(
          viewport.maxWidth,
          maxWidth: PomaLayout.workspaceWidth,
        );
        final width = viewport.maxWidth - inset * 2;
        final range = _visibleRange(width);
        final requested =
            widget.clock &&
                (planner.clockMode == PlannerClockMode.threeHours ||
                    planner.clockMode == PlannerClockMode.sixHours)
            ? planner.range(
                planner.selectedDate,
                planner.selectedDate.plusDays(2),
              )
            : range;
        planner.remoteReader?.watchRange(
          widget.clock ? 'planner-clock' : 'planner-calendar',
          requested,
        );
        final wide =
            width >= 744 &&
            viewport.maxHeight >= 620 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.5;
        final content = widget.clock
            ? _clock()
            : planner.calendarView == PlannerCalendarView.agenda
            ? SingleChildScrollView(child: _agenda(range))
            : _grid(range);
        return Padding(
          padding: EdgeInsets.fromLTRB(inset, 16, inset, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _toolbar(width),
              _status(range),
              if (planner.app.saveError != null)
                MaterialBanner(
                  content: Text(planner.app.saveError!),
                  actions: [
                    TextButton(
                      onPressed: () async {
                        await planner.app.retrySave();
                        await planner.sync();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              const SizedBox(height: PomaSpace.xs),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: content),
                          const SizedBox(width: PomaSpace.lg),
                          SizedBox(
                            width: planner.editorPane
                                ? 424
                                : (width * .38).clamp(320, 440),
                            child: Scrollbar(
                              controller: _agendaScroll,
                              child: SingleChildScrollView(
                                controller: _agendaScroll,
                                child: _support(planner.dayRange),
                              ),
                            ),
                          ),
                        ],
                      )
                    : widget.clock
                    ? LayoutBuilder(
                        builder: (context, body) => SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: math.max(
                                  280,
                                  math.min(body.maxHeight, width + 96),
                                ),
                                child: content,
                              ),
                              const SizedBox(height: PomaSpace.md),
                              _support(planner.dayRange),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(child: content),
                          if (planner.message != null)
                            Text(
                              planner.message!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    planner.removeListener(_changed);
    planner.remoteReader?.releaseRange(
      widget.clock ? 'planner-clock' : 'planner-calendar',
    );
    _calendar?.dispose();
    _events.dispose();
    _agendaScroll.dispose();
    for (final node in _eventFocus.values) {
      node.dispose();
    }
    _timeCursor.dispose();
    _gridHoverTime.dispose();
    _gridDragText.dispose();
    super.dispose();
  }
}

class _EditPlannerEventIntent extends Intent {
  const _EditPlannerEventIntent();
}

class _ContextPlannerEventIntent extends Intent {
  const _ContextPlannerEventIntent();
}

class PlannerOperations extends StatelessWidget {
  const PlannerOperations({required this.planner, super.key});
  final PlannerController planner;
  @override
  Widget build(BuildContext context) {
    final operations = planner.data.operations.values
        .where((op) => op.pending)
        .toList();
    if (operations.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final operation in operations)
          Padding(
            padding: const EdgeInsets.only(top: PomaSpace.sm),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
              child: Padding(
                padding: const EdgeInsets.all(PomaSpace.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      planner.data.schedules[operation.scheduleId]?.title ??
                          'Scheduled task',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      operation.accountKey != planner.accountKey
                          ? 'Waiting for the original Google account. This save keeps its original calendar.'
                          : operation.message ??
                                planner.status(
                                  planner.data.schedules[operation.scheduleId]!,
                                ),
                    ),
                    Wrap(
                      spacing: PomaSpace.xs,
                      runSpacing: PomaSpace.xs,
                      children: [
                        if (operation.accountKey != planner.accountKey)
                          const SizedBox.shrink()
                        else if (operation.kind ==
                                PlannerOperationKind.delete &&
                            !operation.attempted &&
                            operation.notBefore?.isAfter(planner.currentTime) ==
                                true)
                          TextButton(
                            onPressed: () =>
                                planner.undoDelete(operation.scheduleId),
                            child: const Text('Undo'),
                          )
                        else if (operation.state ==
                            PlannerOperationState.conflict) ...[
                          TextButton(
                            onPressed: () => planner.resolveConflict(
                              operation.id,
                              useGoogle: true,
                            ),
                            child: const Text('Use Google'),
                          ),
                          TextButton(
                            onPressed: () async {
                              final schedule =
                                  planner.data.schedules[operation.scheduleId];
                              if (schedule == null) return;
                              final value = await planner.reviewConflict(
                                operation.id,
                              );
                              if (context.mounted && value != null) {
                                await showPlannerEditor(
                                  context,
                                  planner,
                                  initialDraft: value,
                                );
                              }
                            },
                            child: const Text('Review my changes'),
                          ),
                        ] else
                          TextButton(
                            onPressed:
                                operation.state == PlannerOperationState.sending
                                ? null
                                : () => planner.retry(operation.id),
                            child: const Text('Retry'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PlannerPreferencesPanel extends StatelessWidget {
  const PlannerPreferencesPanel({required this.planner, super.key});
  final PlannerController planner;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: planner,
    builder: (context, _) {
      final preferences = planner.preferences;
      final sources = planner.sources
          .where((s) => s.accessRole == 'owner')
          .toList();
      final calendar = DropdownButtonFormField<String>(
        key: ValueKey('planner-default-${preferences.calendarId}'),
        initialValue: sources.any((s) => s.id == preferences.calendarId)
            ? preferences.calendarId
            : null,
        isExpanded: true,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: const InputDecoration(labelText: 'Default calendar'),
        items: [
          for (final source in sources)
            DropdownMenuItem(
              value: source.id,
              child: Text(source.name, maxLines: 2),
            ),
        ],
        onChanged: sources.isEmpty || !planner.unlocked
            ? null
            : (value) => planner.setPreferences(
                preferences.copyWith(calendarId: value),
              ),
      );
      final duration = TextFormField(
        key: ValueKey('planner-duration-${preferences.durationMinutes}'),
        initialValue: '${preferences.durationMinutes}',
        enabled: planner.unlocked,
        style: Theme.of(context).textTheme.bodyMedium,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Default duration',
          suffixText: 'min',
        ),
        onFieldSubmitted: (value) {
          final minutes = int.tryParse(value);
          if (minutes != null && minutes > 0 && minutes <= 527040) {
            planner.setPreferences(
              preferences.copyWith(durationMinutes: minutes),
            );
          }
        },
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CalendarSettingsHeading('Scheduled tasks'),
          SwitchListTile(
            key: const ValueKey('planner-sync-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Sync to Google Calendar'),
            subtitle: const Text('Sync scheduled tasks and queued changes.'),
            value: preferences.syncEnabled,
            onChanged: !planner.unlocked
                ? null
                : (enabled) async {
                    if (enabled) {
                      await planner.enableSync();
                    } else {
                      await planner.setPreferences(
                        preferences.copyWith(syncEnabled: false),
                      );
                    }
                  },
          ),
          const SizedBox(height: PomaSpace.xs),
          LayoutBuilder(
            builder: (context, constraints) {
              if (preferences.syncEnabled &&
                  constraints.maxWidth >= 600 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.4) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: calendar),
                    const SizedBox(width: PomaSpace.md),
                    SizedBox(width: 200, child: duration),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (preferences.syncEnabled) ...[
                    calendar,
                    const SizedBox(height: PomaSpace.md),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(width: 240, child: duration),
                  ),
                ],
              );
            },
          ),
          PlannerOperations(planner: planner),
        ],
      );
    },
  );
}
