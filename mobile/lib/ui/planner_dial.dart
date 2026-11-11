import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../application/day_clock_controller.dart' show dayClockOffset;
import '../application/planner_controller.dart';
import '../domain/calendar_data.dart';
import '../domain/day_clock.dart';
import '../domain/planner.dart';
import 'day_clock_dial.dart';

class PlannerDial extends StatefulWidget {
  const PlannerDial({
    required this.planner,
    required this.projection,
    required this.colors,
    required this.labels,
    required this.onAdd,
    required this.onEvent,
    required this.onContext,
    required this.onMove,
    required this.onEdit,
    super.key,
  });
  final PlannerController planner;
  final DayClockProjection projection;
  final Map<String, Color> colors;
  final List<String>? labels;
  final ValueChanged<DateTime> onAdd;
  final void Function(CalendarEvent, DateTime?) onEvent;
  final ValueChanged<CalendarEvent> onEdit;
  final void Function(CalendarEvent?, DateTime, Offset) onContext;
  final Future<bool> Function(CalendarEvent, DateTime, DateTime) onMove;
  @override
  State<PlannerDial> createState() => _PlannerDialState();
}

class _PlannerDialState extends State<PlannerDial> {
  final _focus = FocusNode(debugLabel: 'Day Clock time cursor');
  double? _hoverMinute;
  double _keyboardMinute = 0;
  double? _dragOrigin;
  DateTime? _dragAnchor;
  CalendarEvent? _dragEvent;
  String _dragKind = 'move';
  DateTime? _proposedStart, _proposedEnd;
  bool _cancelled = false;
  bool _keyboardMoved = false;
  tz.Location? _deviceZone;
  List<DateTime> _dragChoices = [];
  String? _dragError;
  DayClockProjection get projection => widget.projection;
  PlannerController get planner => widget.planner;

  @override
  void initState() {
    super.initState();
    _loadDeviceZone();
  }

  Future<void> _loadDeviceZone() async {
    final name = await planner.time.deviceZone();
    if (mounted && name != null) {
      setState(() => _deviceZone = tz.getLocation(name));
    }
  }

  double? _minute(Offset point, Size size) {
    final geometry = DayClockGeometry(
      size,
      MediaQuery.textScalerOf(context),
      labels: widget.labels,
    );
    final delta = point - geometry.center;
    if (delta.distance < geometry.hubRadius ||
        delta.distance > geometry.overflowRadius + 8) {
      return null;
    }
    final minute =
        ((math.atan2(delta.dy, delta.dx) + math.pi / 2 + math.pi * 2) %
            (math.pi * 2)) *
        360 /
        math.pi;
    return (minute * 100000000).round() / 100000000;
  }

  double _snapped(double normalized) {
    final wall = normalized / projection.window.minutesPerElapsedMinute;
    return plannerSnapMinute(wall, maximum: projection.window.spanMinutes - 5) *
        projection.window.minutesPerElapsedMinute;
  }

  List<DateTime> _instants(double minute) => [
    for (final slice in projection.window.slices)
      if (minute >= slice.startMinute && minute < slice.endMinute)
        slice.startUtc.add(
          Duration(
            microseconds:
                ((minute - slice.startMinute) /
                        projection.window.minutesPerElapsedMinute *
                        60000000)
                    .round(),
          ),
        ),
  ];

  DateTime _instantFor(CalendarEvent event, List<DateTime> instants) =>
      instants
          .where(
            (instant) =>
                !instant.isBefore(event.startUtc!) &&
                instant.isBefore(event.endUtc!),
          )
          .firstOrNull ??
      instants.first;

  String _offsetTime(DateTime instant) {
    final slice = projection.window.slices
        .where(
          (slice) =>
              !instant.isBefore(slice.startUtc) &&
              !instant.isAfter(slice.endUtc),
        )
        .firstOrNull;
    final offset = _deviceZone == null
        ? slice!.offsetMinutes
        : tz.TZDateTime.from(instant, _deviceZone!).timeZoneOffset.inMinutes;
    final wall = plannerUtcInstant(instant).add(Duration(minutes: offset));
    return '${DateFormat.jm().format(wall)} · ${dayClockOffset(offset)}';
  }

  Future<DateTime?> _chooseInstant(List<DateTime> instants) =>
      showDialog<DateTime>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('This time occurs twice'),
          children: [
            for (final instant in instants)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, instant),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_offsetTime(instant)),
                ),
              ),
          ],
        ),
      );

  List<CalendarEvent> _events(double minute) {
    final all = <String, CalendarEvent>{};
    for (final sector in projection.sectors) {
      if (minute >= sector.startMinute && minute < sector.endMinute) {
        all[sector.identity] = sector.event;
      }
    }
    return all.values.toList();
  }

  CalendarEvent? _hit(Offset position, Size size, double minute) {
    final geometry = DayClockGeometry(
      size,
      MediaQuery.textScalerOf(context),
      labels: widget.labels,
    );
    final radius = (position - geometry.center).distance;
    final sectors = projection.sectors.toList()
      ..sort((a, b) => a.lane.compareTo(b.lane));
    for (final sector in sectors.reversed) {
      final radii = geometry.radii(sector);
      if (minute >= sector.startMinute &&
          minute < sector.endMinute &&
          radius >= radii.$1 &&
          radius <= radii.$2) {
        return sector.event;
      }
    }
    return null;
  }

  Future<void> _activate(double minute, {CalendarEvent? hit}) async {
    final instants = _instants(_snapped(minute));
    if (instants.isEmpty) return;
    if (hit != null) {
      widget.onEvent(
        hit,
        plannerSnapInstant(_instantFor(hit, _instants(minute))),
      );
      return;
    }
    final events = _events(minute);
    if (events.isNotEmpty) {
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
                  for (final event in events)
                    ListTile(
                      title: Text(event.title),
                      subtitle: Text(
                        '${DateFormat.jm().format(event.startUtc!.toLocal())} – ${DateFormat.jm().format(event.endUtc!.toLocal())}',
                      ),
                      onTap: () => Navigator.pop(context, event),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(
                      'Add task here · ${DateFormat.jm().format(instants.first.toLocal())}',
                    ),
                    onTap: () => Navigator.pop(context, true),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (chosen is CalendarEvent) {
        widget.onEvent(
          chosen,
          plannerSnapInstant(_instantFor(chosen, _instants(minute))),
        );
        return;
      }
      if (chosen != true) return;
    }
    if (instants.length == 1) {
      widget.onAdd(instants.first);
      return;
    }
    final choice = await _chooseInstant(instants);
    if (choice != null && mounted) widget.onAdd(choice);
  }

  Future<void> _contextAt(
    double minute,
    Offset position, {
    CalendarEvent? hit,
  }) async {
    final instants = _instants(_snapped(minute));
    if (instants.isEmpty) return;
    final instant = hit != null
        ? plannerSnapInstant(_instantFor(hit, _instants(minute)))
        : instants.length == 1
        ? instants.first
        : await _chooseInstant(instants);
    if (!mounted || instant == null) return;
    widget.onContext(hit ?? _events(minute).firstOrNull, instant, position);
  }

  void _startDrag(DragStartDetails details, Size size) {
    final minute = _minute(details.localPosition, size);
    if (minute == null) return;
    var event = _hit(details.localPosition, size, minute);
    var kind = 'move';
    final geometry = DayClockGeometry(
      size,
      MediaQuery.textScalerOf(context),
      labels: widget.labels,
    );
    for (final sector in projection.sectors.where(
      (s) => s.identity == planner.selectedIdentity,
    )) {
      final radii = geometry.radii(sector);
      final radius = (radii.$1 + radii.$2) / 2;
      final start =
          geometry.center + DayClockGeometry.direction(sector.angle) * radius;
      final end =
          geometry.center +
          DayClockGeometry.direction(sector.angle + sector.sweep) * radius;
      if (sector.startUtc == sector.event.startUtc &&
          (details.localPosition - start).distance <= 12) {
        event = sector.event;
        kind = 'start';
      } else if (sector.endUtc == sector.event.endUtc &&
          (details.localPosition - end).distance <= 12) {
        event = sector.event;
        kind = 'end';
      }
    }
    if (event == null ||
        calendarEventIdentity(event) != planner.selectedIdentity ||
        planner.readOnlyReason(event) != null) {
      return;
    }
    _dragOrigin = minute;
    final origins = _instants(minute);
    if (origins.isEmpty && kind == 'move') return;
    _dragAnchor = kind == 'move'
        ? _instantFor(event, origins)
        : kind == 'start'
        ? event.startUtc
        : event.endUtc;
    if (kind != 'move') {
      final boundary = kind == 'start' ? event.startUtc! : event.endUtc!;
      final sector = projection.sectors.firstWhere(
        (sector) =>
            sector.event == event &&
            (kind == 'start'
                ? sector.startUtc == boundary
                : sector.endUtc == boundary),
      );
      _dragOrigin = kind == 'start' ? sector.startMinute : sector.endMinute;
    }
    _dragEvent = event;
    _focus.requestFocus();
    _cancelled = false;
    _dragKind = kind;
    _dragChoices = [];
    _dragError = null;
  }

  (DateTime, DateTime) _dragTimes(CalendarEvent event, DateTime target) {
    final start = _dragKind == 'end'
        ? event.startUtc!
        : _dragKind == 'start'
        ? target
        : plannerSnapInstant(
            event.startUtc!.add(target.difference(_dragAnchor!)),
          );
    final end = _dragKind == 'start'
        ? event.endUtc!
        : _dragKind == 'end'
        ? target
        : start.add(event.endUtc!.difference(event.startUtc!));
    return (start, end);
  }

  void _updateDrag(DragUpdateDetails details, Size size) {
    final event = _dragEvent,
        origin = _dragOrigin,
        minute = _minute(details.localPosition, size);
    if (event == null || origin == null || minute == null || _cancelled) return;
    var delta = minute - origin;
    if (delta > 360) delta -= 720;
    if (delta < -360) delta += 720;
    final normalized = origin + delta;
    final wallMinutes =
        (normalized / projection.window.minutesPerElapsedMinute / 5).round() *
        5;
    final zone = _deviceZone;
    final choices = zone == null
        ? _instants(wallMinutes * projection.window.minutesPerElapsedMinute)
        : plannerResolveWall(
            zone,
            DateTime.utc(
              projection.window.date.year,
              projection.window.date.month,
              projection.window.date.day,
            ).add(
              Duration(minutes: projection.window.startMinute + wallMinutes),
            ),
          ).map(plannerUtcInstant).toList();
    final times = choices.isEmpty ? null : _dragTimes(event, choices.first);
    final valid = times != null && times.$2.isAfter(times.$1);
    setState(() {
      _dragChoices = valid ? choices : [];
      _proposedStart = valid ? times.$1 : null;
      _proposedEnd = valid ? times.$2 : null;
      _dragError = choices.isEmpty
          ? 'This time is unavailable in the device timezone.'
          : valid
          ? null
          : 'End must be after Start.';
    });
  }

  Future<void> _endDrag() async {
    final event = _dragEvent;
    var start = _proposedStart, end = _proposedEnd;
    final cancelled = _cancelled;
    if (!cancelled && event != null && _dragChoices.length > 1) {
      final choice = await _chooseInstant(_dragChoices);
      if (!mounted) return;
      if (choice == null) {
        _cancelDrag();
        return;
      }
      (start, end) = _dragTimes(event, choice);
    }
    setState(() {
      _dragEvent = null;
      _dragOrigin = null;
      _dragAnchor = null;
      _proposedStart = null;
      _proposedEnd = null;
      _dragChoices = [];
      _dragError = null;
    });
    if (event == null || start == null || end == null || cancelled) return;
    if (await widget.onMove(event, start, end) && mounted) {
      final schedule = planner.scheduleForEvent(event);
      if (schedule != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Time updated'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => planner.undoChange(schedule.id),
            ),
          ),
        );
      }
    }
  }

  void _cancelDrag() {
    setState(() {
      _cancelled = true;
      _dragEvent = null;
      _dragOrigin = null;
      _dragAnchor = null;
      _proposedStart = null;
      _proposedEnd = null;
      _dragChoices = [];
      _dragError = null;
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final selected = projection.agenda
        .where(
          (event) => calendarEventIdentity(event) == planner.selectedIdentity,
        )
        .firstOrNull;
    if (event.logicalKey == LogicalKeyboardKey.f2 && selected != null) {
      widget.onEdit(selected);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && _dragEvent != null) {
      _cancelDrag();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final delta =
          event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.arrowDown
          ? -5
          : 5;
      setState(() {
        _keyboardMoved = true;
        _keyboardMinute =
            (_keyboardMinute +
                    delta * projection.window.minutesPerElapsedMinute)
                .clamp(0, 720 - 5 * projection.window.minutesPerElapsedMinute);
        _hoverMinute = _keyboardMinute;
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (selected != null && !_keyboardMoved) {
        widget.onEvent(selected, planner.inspectedUtc);
      } else {
        _activate(_keyboardMinute);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.f10 &&
        HardwareKeyboard.instance.isShiftPressed) {
      _contextAt(
        _keyboardMinute,
        const Offset(300, 250),
        hit: _keyboardMoved ? null : selected,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final localNow = planner.reader.now.toLocal();
      final centerTime = projection.handAngle == null
          ? (projection.window.spanMinutes == 1440 ? '24h' : 'Day')
          : DateFormat('h:mm').format(localNow);
      final centerLabel = projection.handAngle == null
          ? 'Browsing'
          : DateFormat('a').format(localNow);
      final caption = dayClockCaptionHeight(context, centerTime, centerLabel);
      final diameter = math.min(
        680.0,
        math.min(
          constraints.maxWidth,
          math.max(180.0, constraints.maxHeight - caption - 32),
        ),
      );
      final size = Size.square(diameter);
      final instants = _hoverMinute == null
          ? <DateTime>[]
          : _instants(_hoverMinute!);
      final inspected = instants.firstOrNull;
      final preview =
          _dragError ??
          (_proposedStart == null
              ? inspected == null
                    ? null
                    : instants.length > 1
                    ? instants.map(_offsetTime).join(' / ')
                    : DateFormat.jm().format(inspected.toLocal())
              : _dragChoices.length > 1
              ? _dragChoices.map(_offsetTime).join(' / ')
              : '${DateFormat.jm().format(_proposedStart!.toLocal())} – ${DateFormat.jm().format(_proposedEnd!.toLocal())} · ${_proposedEnd!.difference(_proposedStart!).inMinutes} min');
      return Focus(
        focusNode: _focus,
        onKeyEvent: _key,
        onFocusChange: (_) => setState(() {}),
        child: Semantics(
          label:
              'Day Clock time cursor. Use arrow keys to inspect five-minute steps and Enter to add a task. Events are also in the agenda.',
          value: preview,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: diameter,
                height: diameter + caption,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (event) {
                    final minute = _minute(event.localPosition, size);
                    setState(
                      () => _hoverMinute = minute == null
                          ? null
                          : _snapped(minute),
                    );
                  },
                  onExit: (_) => setState(
                    () =>
                        _hoverMinute = _focus.hasFocus ? _keyboardMinute : null,
                  ),
                  child: GestureDetector(
                    key: const ValueKey('planner-clock-dial'),
                    behavior: HitTestBehavior.opaque,
                    dragStartBehavior: DragStartBehavior.down,
                    onTapUp: (details) {
                      _focus.requestFocus();
                      final minute = _minute(details.localPosition, size);
                      if (minute != null) {
                        _keyboardMoved = false;
                        _keyboardMinute = _snapped(minute);
                        _activate(
                          minute,
                          hit: _hit(details.localPosition, size, minute),
                        );
                      }
                    },
                    onSecondaryTapUp: (details) {
                      final minute = _minute(details.localPosition, size);
                      if (minute == null) return;
                      _contextAt(
                        minute,
                        details.globalPosition,
                        hit: _hit(details.localPosition, size, minute),
                      );
                    },
                    onPanStart: (details) => _startDrag(details, size),
                    onPanUpdate: (details) => _updateDrag(details, size),
                    onPanEnd: (_) => _endDrag(),
                    onPanCancel: _cancelDrag,
                    child: Stack(
                      children: [
                        IgnorePointer(
                          child: DayClockDial(
                            projection: projection,
                            colors: widget.colors,
                            selected: planner.selectedIdentity,
                            onEvent: (_) {},
                            onEmpty: (_) {},
                            numeralLabels: widget.labels,
                            centerTime: centerTime,
                            centerLabel: centerLabel,
                          ),
                        ),
                        Positioned(
                          top: 0,
                          left: 0,
                          width: diameter,
                          height: diameter,
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _InspectionPainter(
                                geometry: DayClockGeometry(
                                  size,
                                  MediaQuery.textScalerOf(context),
                                  labels: widget.labels,
                                ),
                                minute: _hoverMinute,
                                scheme: Theme.of(context).colorScheme,
                                selected: projection.sectors
                                    .where(
                                      (s) =>
                                          s.identity ==
                                          planner.selectedIdentity,
                                    )
                                    .toList(),
                                pending: projection.sectors.where((s) {
                                  final schedule = planner.scheduleForEvent(
                                    s.event,
                                  );
                                  return schedule != null &&
                                      planner.pendingFor(schedule.id) != null;
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 32,
                child: Text(
                  preview == null
                      ? ' '
                      : '$preview${_dragEvent == null ? ' · 5-minute snap' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }
}

class _InspectionPainter extends CustomPainter {
  _InspectionPainter({
    required this.geometry,
    required this.minute,
    required this.scheme,
    required this.selected,
    required this.pending,
  });
  final DayClockGeometry geometry;
  final double? minute;
  final ColorScheme scheme;
  final List<DayClockSector> selected, pending;
  @override
  void paint(Canvas canvas, Size size) {
    if (minute != null) {
      final direction = DayClockGeometry.direction(dayClockAngle(minute!));
      for (
        var distance = geometry.hubRadius;
        distance < geometry.radius * .84;
        distance += 12
      ) {
        canvas.drawLine(
          geometry.center + direction * distance,
          geometry.center +
              direction * math.min(distance + 6, geometry.radius * .84),
          Paint()
            ..color = scheme.primary
            ..strokeWidth = 2,
        );
      }
    }
    for (final sector in selected) {
      final radii = geometry.radii(sector);
      final midpoint = (radii.$1 + radii.$2) / 2;
      if (sector.startUtc == sector.event.startUtc) {
        _handle(canvas, sector.angle, midpoint);
      }
      if (sector.endUtc == sector.event.endUtc) {
        _handle(canvas, sector.angle + sector.sweep, midpoint);
      }
    }
    for (final sector in pending) {
      final radii = geometry.radii(sector);
      final angleStep = math.max(.02, 5 / radii.$2);
      for (
        var angle = sector.angle;
        angle < sector.angle + sector.sweep;
        angle += angleStep * 2
      ) {
        canvas.drawArc(
          Rect.fromCircle(center: geometry.center, radius: radii.$2),
          angle,
          math.min(angleStep, sector.angle + sector.sweep - angle),
          false,
          Paint()
            ..color = scheme.onSurface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _handle(Canvas canvas, double angle, double radius) {
    final at = geometry.center + DayClockGeometry.direction(angle) * radius;
    canvas.drawCircle(at, 6, Paint()..color = scheme.surface);
    canvas.drawCircle(
      at,
      6,
      Paint()
        ..color = scheme.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_InspectionPainter oldDelegate) =>
      oldDelegate.minute != minute ||
      oldDelegate.geometry.size != geometry.size ||
      oldDelegate.scheme != scheme ||
      oldDelegate.selected != selected ||
      oldDelegate.pending != pending;
}
