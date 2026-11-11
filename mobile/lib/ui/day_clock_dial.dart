import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../domain/calendar_data.dart';
import '../domain/day_clock.dart';
import 'design_tokens.dart';

Color clockInk(Color fill) =>
    fill.computeLuminance() > .179 ? Colors.black : Colors.white;

String? calendarEventFill(
  CalendarEvent event,
  CalendarSource? source,
  CalendarEventPalette? palette,
) {
  if (event.colorId != null && event.colorId!.isNotEmpty) {
    return palette?.colors[event.colorId]?.background;
  }
  // Calendar labels are not indices into the global event colour palette.
  if (event.eventLabelId != null && event.eventLabelId!.isNotEmpty) return null;
  return safeCalendarColor(source?.backgroundColor);
}

Color clockColor(String? hex, Color fallback) => hex == null
    ? fallback
    : Color(0xff000000 | int.parse(hex.substring(1), radix: 16));

/// One measured layout for painting and selection, including enlarged numerals.
class DayClockGeometry {
  DayClockGeometry(this.size, this.scaler, {this.labels}) {
    radius = size.shortestSide / 2 - 4;
    final measurements = <Size>[];
    for (var hour = 1; hour <= 12; hour++) {
      final text = TextPainter(
        text: TextSpan(text: labels?[hour - 1] ?? '$hour', style: numeralStyle),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      measurements.add(text.size);
      text.dispose();
    }
    var orbit = radius * .875;
    List<Rect> boxes() => [
      for (var hour = 1; hour <= 12; hour++)
        Rect.fromCenter(
          center: center + direction(dayClockAngle(hour * 60.0)) * orbit,
          width: measurements[hour - 1].width,
          height: measurements[hour - 1].height,
        ),
    ];
    bool fits(Rect box) => [
      box.topLeft,
      box.topRight,
      box.bottomLeft,
      box.bottomRight,
    ].every((p) => (p - center).distance <= radius * .925);
    var measuredBoxes = boxes();
    while (!measuredBoxes.every(fits) && orbit > radius * .45) {
      orbit -= 1;
      measuredBoxes = boxes();
    }
    numeralBoxes = List.unmodifiable(measuredBoxes);
    final nearest = numeralBoxes
        .map((box) {
          final dx = (center.dx - box.center.dx).abs() - box.width / 2;
          final dy = (center.dy - box.center.dy).abs() - box.height / 2;
          return Offset(math.max(0, dx), math.max(0, dy)).distance;
        })
        .reduce(math.min);
    outerRadius = math.min(radius * .80, nearest - 12);
  }
  final Size size;
  final TextScaler scaler;
  final List<String>? labels;
  late final double radius, outerRadius;
  late final List<Rect> numeralBoxes;
  Offset get center => size.center(Offset.zero);
  double get hubRadius => radius * .25;
  double get overflowRadius => outerRadius + 5;
  TextStyle get numeralStyle => PomaType.sectionTitle.copyWith(
    fontSize: (size.width * .06).clamp(20, 40),
  );
  static Offset direction(double angle) =>
      Offset(math.cos(angle), math.sin(angle));
  (double, double) radii(DayClockSector sector) {
    final count = math.min(4, sector.laneCount),
        lane = math.min(3, sector.lane);
    final width = (outerRadius - hubRadius) / count;
    return (hubRadius + lane * width, hubRadius + (lane + 1) * width);
  }
}

double dayClockCaptionHeight(BuildContext context, String time, String label) {
  final scaler = MediaQuery.textScalerOf(context);
  if (scaler.scale(1) < 1.5) return 0;
  final text = TextPainter(
    text: TextSpan(
      text: '$time $label',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    textScaler: scaler,
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  final height = PomaSpace.sm + text.height;
  text.dispose();
  return height;
}

class DayClockDial extends StatelessWidget {
  const DayClockDial({
    required this.projection,
    required this.colors,
    required this.selected,
    required this.onEvent,
    required this.onEmpty,
    required this.centerTime,
    required this.centerLabel,
    this.numeralLabels,
    super.key,
  });
  final DayClockProjection projection;
  final Map<String, Color> colors;
  final String? selected;
  final ValueChanged<CalendarEvent> onEvent;
  final ValueChanged<double> onEmpty;
  final String centerTime, centerLabel;
  final List<String>? numeralLabels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final captionHeight = dayClockCaptionHeight(
        context,
        centerTime,
        centerLabel,
      );
      final size = math.min(
        680.0,
        math.min(
          constraints.maxWidth,
          constraints.hasBoundedHeight
              ? math.max(0.0, constraints.maxHeight - captionHeight)
              : double.infinity,
        ),
      );
      final theme = Theme.of(context), scale = MediaQuery.textScalerOf(context);
      final highContrast = MediaQuery.highContrastOf(context);
      final geometry = DayClockGeometry(
        Size.square(size),
        scale,
        labels: numeralLabels,
      );
      final painter = DayClockPainter(
        projection: projection,
        colors: colors,
        selected: selected,
        scheme: theme.colorScheme,
        dark: theme.brightness == Brightness.dark,
        highContrast: highContrast,
        scaler: scale,
        geometry: geometry,
      );
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label:
                  '${projection.window.half == DayClockHalf.am ? 'AM' : 'PM'} clock, '
                  '${projection.agenda.length} timed events. Select events in the chronological agenda, '
                  'or use Add task to enter a time.',
              value: '$centerTime $centerLabel',
              child: GestureDetector(
                key: const ValueKey('day-clock-dial'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final center = Offset(size / 2, size / 2);
                  final delta = details.localPosition - center;
                  if (delta.distance < geometry.hubRadius ||
                      delta.distance > geometry.overflowRadius + 3) {
                    return;
                  }
                  final minute =
                      ((math.atan2(delta.dy, delta.dx) +
                              math.pi / 2 +
                              2 * math.pi) %
                          (2 * math.pi)) *
                      360 /
                      math.pi;
                  for (final sector in painter.ordered.reversed) {
                    if (sector.lane >= 4 && sector.identity != selected) {
                      continue;
                    }
                    final radii = geometry.radii(sector);
                    if (minute >= sector.startMinute &&
                        minute < sector.endMinute &&
                        delta.distance >= radii.$1 &&
                        delta.distance <= radii.$2) {
                      onEvent(sector.event);
                      return;
                    }
                  }
                  // A visually blank overlap lane is not unscheduled dial space.
                  final occupied = projection.sectors
                      .where(
                        (s) => minute >= s.startMinute && minute < s.endMinute,
                      )
                      .firstOrNull;
                  if (occupied != null) {
                    onEvent(occupied.event);
                    return;
                  }
                  if (projection.window.transitions.any(
                    (s) => !s.repeated && minute >= s.start && minute < s.end,
                  )) {
                    return;
                  }
                  onEmpty((minute / 5).floor() * 5.0);
                },
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: size,
                    child: Stack(
                      children: [
                        RepaintBoundary(
                          key: const ValueKey('day-clock-face'),
                          child: CustomPaint(
                            size: Size.square(size),
                            painter: painter,
                          ),
                        ),
                        RepaintBoundary(
                          key: const ValueKey('day-clock-hand'),
                          child: CustomPaint(
                            size: Size.square(size),
                            painter: DayClockHandPainter(
                              geometry: geometry,
                              angle: projection.handAngle,
                              scheme: theme.colorScheme,
                              highContrast: highContrast,
                              centerTime: centerTime,
                              centerLabel: centerLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (scale.scale(1) >= 1.5) ...[
              const SizedBox(height: PomaSpace.sm),
              Text(
                '$centerTime $centerLabel',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ],
        ),
      );
    },
  );
}

class DayClockPainter extends CustomPainter {
  DayClockPainter({
    required this.projection,
    required this.colors,
    required this.selected,
    required this.scheme,
    required this.dark,
    required this.highContrast,
    required this.scaler,
    required this.geometry,
  });
  final DayClockProjection projection;
  final Map<String, Color> colors;
  final String? selected;
  final ColorScheme scheme;
  final bool dark, highContrast;
  final TextScaler scaler;
  final DayClockGeometry geometry;
  List<DayClockSector> get ordered => [...projection.sectors]
    ..sort((a, b) {
      final first = a.identity == selected, second = b.identity == selected;
      if (first != second) return first ? 1 : -1;
      return a.lane.compareTo(b.lane);
    });
  Path sectorPath(
    Offset center,
    double inner,
    double outer,
    double angle,
    double sweep,
  ) => Path()
    ..moveTo(
      center.dx + inner * math.cos(angle),
      center.dy + inner * math.sin(angle),
    )
    ..lineTo(
      center.dx + outer * math.cos(angle),
      center.dy + outer * math.sin(angle),
    )
    ..arcTo(Rect.fromCircle(center: center, radius: outer), angle, sweep, false)
    ..lineTo(
      center.dx + inner * math.cos(angle + sweep),
      center.dy + inner * math.sin(angle + sweep),
    )
    ..arcTo(
      Rect.fromCircle(center: center, radius: inner),
      angle + sweep,
      -sweep,
      false,
    )
    ..close();

  void paintSectorLabel(
    Canvas canvas,
    Path path,
    DayClockSector sector,
    (double, double) radii,
    Color fill,
    Size size,
  ) {
    final title = sector.event.title.trim();
    if (title.length > 48 ||
        sector.sweep <= .32 ||
        radii.$2 - radii.$1 <= scaler.scale(25)) {
      return;
    }
    final middle = sector.angle + sector.sweep / 2;
    final candidates = [
      title,
      if (title.split(' ').length == 2) title.replaceFirst(' ', '\n'),
    ];
    for (final candidate in candidates) {
      for (final fraction in [.62, .72, .5]) {
        final distance = radii.$1 + (radii.$2 - radii.$1) * fraction;
        final position =
            geometry.center + DayClockGeometry.direction(middle) * distance;
        final text = TextPainter(
          text: TextSpan(
            text: candidate,
            style: PomaType.bodyStrong.copyWith(
              color: clockInk(fill),
              fontSize: (size.width * .032).clamp(14, 22),
            ),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
          textScaler: scaler,
          maxLines: 2,
        )..layout(maxWidth: math.min(radii.$2 - radii.$1, 140));
        final top = position - Offset(text.width / 2, text.height / 2);
        final box = top & text.size;
        final fits =
            !text.didExceedMaxLines &&
            [
              box.topLeft,
              box.topRight,
              box.bottomLeft,
              box.bottomRight,
            ].every(path.contains);
        if (fits) text.paint(canvas, top);
        text.dispose();
        if (fits) return;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide / 2 - 4;
    final face = highContrast
        ? scheme.surface
        : dark
        ? const Color(0xff111c31)
        : const Color(0xffe9edf8);
    canvas.drawCircle(center, radius, Paint()..color = face);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = dark && !highContrast
            ? const Color(0xff58698e)
            : scheme.outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final transition in projection.window.transitions) {
      final path = sectorPath(
        center,
        geometry.hubRadius,
        geometry.outerRadius,
        dayClockAngle(transition.start),
        (transition.end - transition.start) * math.pi / 360,
      );
      canvas.drawPath(
        path,
        Paint()..color = scheme.onSurface.withValues(alpha: .12),
      );
      canvas.save();
      canvas.clipPath(path);
      for (var x = -size.height; x < size.width; x += 10) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x + size.height, size.height),
          Paint()
            ..color = scheme.onSurface.withValues(alpha: .35)
            ..strokeWidth = 1,
        );
      }
      canvas.restore();
    }
    for (final sector in ordered) {
      if (sector.lane >= 4 && sector.identity != selected) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: geometry.overflowRadius),
          sector.angle,
          sector.sweep,
          false,
          Paint()
            ..color = scheme.onSurface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        continue;
      }
      final r = geometry.radii(sector);
      final path = sectorPath(center, r.$1, r.$2, sector.angle, sector.sweep);
      final draft = sector.event.calendarId == 'poma-draft';
      final fill = draft
          ? scheme.primary.withValues(alpha: .12)
          : colors[sector.identity] ?? scheme.outline;
      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(
        path,
        Paint()
          ..color = draft ? scheme.primary : face
          ..style = PaintingStyle.stroke
          ..strokeWidth = draft ? 2.5 : 1.5,
      );
      if (sector.identity == selected) {
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.black
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      } else if (highContrast) {
        canvas.drawPath(
          path,
          Paint()
            ..color = scheme.onSurface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      paintSectorLabel(canvas, path, sector, r, fill, size);
    }
    for (var i = 0; i < 60; i++) {
      final angle = -math.pi / 2 + i * math.pi / 30;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * radius * (i % 5 == 0 ? 0.94 : 0.965),
        center + direction * radius * .985,
        Paint()
          ..color = scheme.onSurface
          ..strokeWidth = i % 5 == 0 ? 2.5 : 1,
      );
    }
    for (var hour = 1; hour <= 12; hour++) {
      final text = TextPainter(
        text: TextSpan(
          text: geometry.labels?[hour - 1] ?? '$hour',
          style: geometry.numeralStyle.copyWith(color: scheme.onSurface),
        ),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, geometry.numeralBoxes[hour - 1].topLeft);
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(DayClockPainter oldDelegate) =>
      projection.window != oldDelegate.projection.window ||
      !_sameSectors(projection.sectors, oldDelegate.projection.sectors) ||
      selected != oldDelegate.selected ||
      !mapEquals(colors, oldDelegate.colors) ||
      scheme != oldDelegate.scheme ||
      dark != oldDelegate.dark ||
      highContrast != oldDelegate.highContrast ||
      scaler != oldDelegate.scaler;
}

bool _sameSectors(List<DayClockSector> a, List<DayClockSector> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((
          a[i].key,
          a[i].event.title,
          a[i].startMinute,
          a[i].endMinute,
          a[i].lane,
          a[i].laneCount,
        ) !=
        (
          b[i].key,
          b[i].event.title,
          b[i].startMinute,
          b[i].endMinute,
          b[i].lane,
          b[i].laneCount,
        )) {
      return false;
    }
  }
  return true;
}

/// Only this transparent overlay changes on an ordinary presentation tick.
class DayClockHandPainter extends CustomPainter {
  DayClockHandPainter({
    required this.geometry,
    required this.angle,
    required this.scheme,
    required this.highContrast,
    required this.centerTime,
    required this.centerLabel,
  });
  final DayClockGeometry geometry;
  final double? angle;
  final ColorScheme scheme;
  final bool highContrast;
  final String centerTime, centerLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = geometry.center,
        radius = geometry.radius,
        scaler = geometry.scaler;
    if (angle case final angle?) {
      final tip =
          center + Offset(math.cos(angle), math.sin(angle)) * radius * .92;
      canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = Colors.black
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        center,
        tip,
        Paint()
          ..color = const Color(0xfff4f7ff)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawCircle(
      center,
      geometry.hubRadius,
      Paint()..color = scheme.surface,
    );
    canvas.drawCircle(
      center,
      geometry.hubRadius,
      Paint()
        ..color = highContrast ? scheme.onSurface : const Color(0xffb9a7ff)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    if (scaler.scale(1) < 1.5) {
      void label(String value, double dy, TextStyle style) {
        final text = TextPainter(
          text: TextSpan(text: value, style: style),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout();
        if (text.width > radius * .46) {
          text.text = TextSpan(
            text: value,
            style: style.copyWith(
              fontSize: style.fontSize! * radius * .46 / text.width,
            ),
          );
          text.layout();
        }
        if (text.width <= radius * .46 + .01) {
          text.paint(
            canvas,
            center + Offset(-text.width / 2, dy - text.height / 2),
          );
        }
        text.dispose();
      }

      label(
        centerTime,
        -radius * .055,
        PomaType.sectionTitle.copyWith(
          fontSize: (size.width * .065).clamp(22, 44),
          color: scheme.onSurface,
        ),
      );
      label(
        centerLabel,
        radius * .10,
        PomaType.secondary.copyWith(
          fontSize: (size.width * .036).clamp(14, 22),
          color: scheme.onSurfaceVariant,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(DayClockHandPainter oldDelegate) =>
      angle != oldDelegate.angle ||
      scheme != oldDelegate.scheme ||
      highContrast != oldDelegate.highContrast ||
      geometry.scaler != oldDelegate.geometry.scaler ||
      centerTime != oldDelegate.centerTime ||
      centerLabel != oldDelegate.centerLabel;
}
