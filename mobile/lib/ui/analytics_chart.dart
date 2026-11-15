import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/app_controller.dart';
import '../domain/analytics.dart';
import 'copy.dart';
import 'design_tokens.dart';

class AnalyticsActivity extends StatefulWidget {
  const AnalyticsActivity({required this.controller, super.key});
  final AppController controller;

  @override
  State<AnalyticsActivity> createState() => _AnalyticsActivityState();
}

class _AnalyticsActivityState extends State<AnalyticsActivity> {
  bool _showData = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final copy = context.copy;
    final theme = Theme.of(context);
    final query = controller.analyticsQuery;
    final saved = controller.analytics;
    // A response for a different period or timezone keeps its own identity.
    final matches =
        saved != null &&
        saved.query.period == query.period &&
        saved.query.chartWindow.range.startUtc ==
            query.chartWindow.range.startUtc &&
        saved.query.chartWindow.range.endUtc ==
            query.chartWindow.range.endUtc &&
        saved.query.today == query.today;
    final snapshot = matches ? saved : null;
    final labels = [
      copy.analyticsWeek,
      copy.analyticsMonth,
      copy.analyticsYear,
    ];
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            copy.analyticsActivity,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: PomaSpace.sm),
        Wrap(
          spacing: PomaSpace.xs,
          runSpacing: PomaSpace.xs,
          children: [
            for (final period in AnalyticsPeriod.values)
              ChoiceChip(
                key: Key('analytics-period-${period.name}'),
                label: Text(labels[period.index]),
                selected: controller.analyticsPeriod == period,
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surface,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: controller.analyticsPeriod == period
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
                showCheckmark: false,
                onSelected: (_) => controller.setAnalyticsPeriod(period),
              ),
          ],
        ),
        const SizedBox(height: PomaSpace.sm),
        Text(switch (query.period) {
          AnalyticsPeriod.week => DeviceFormats.dateRange(
            context,
            query.chartWindow.start,
            query.chartWindow.lastDate,
          ),
          AnalyticsPeriod.month => DeviceFormats.month(context, query.anchor),
          AnalyticsPeriod.year => DeviceFormats.year(context, query.anchor),
        }, style: theme.textTheme.titleSmall),
        Wrap(
          spacing: PomaSpace.xxs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton(
              key: const Key('analytics-previous'),
              tooltip: copy.analyticsPrevious,
              onPressed: () => controller.moveAnalytics(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              key: const Key('analytics-next'),
              tooltip: copy.analyticsNext,
              onPressed: query.canGoForward
                  ? () => controller.moveAnalytics(1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
            if (query.isCurrentPeriod)
              Text(
                copy.inProgress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              TextButton(
                onPressed: controller.resetAnalyticsPeriod,
                child: Text(copy.analyticsCurrent),
              ),
          ],
        ),
        const SizedBox(height: PomaSpace.md),
        if (snapshot == null)
          Semantics(
            liveRegion: true,
            child: SizedBox(
              height: largeText ? 64 : 264,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  controller.analyticsLoading
                      ? copy.analyticsLoading
                      : copy.analyticsUnavailable,
                ),
              ),
            ),
          )
        else ...[
          if (!largeText)
            _SessionChart(
              key: ValueKey(
                '${query.period.name}-${query.anchor}-${query.today}',
              ),
              snapshot: snapshot,
            ),
          if (!largeText)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('analytics-show-data'),
                onPressed: () => setState(() => _showData = !_showData),
                icon: Icon(
                  _showData ? Icons.expand_less : Icons.table_rows_outlined,
                ),
                label: Text(
                  _showData ? copy.analyticsHideData : copy.analyticsShowData,
                ),
              ),
            ),
          if (_showData || largeText)
            for (var i = 0; i < query.buckets.length; i++)
              _BucketValue(snapshot: snapshot, index: i),
        ],
      ],
    );
  }
}

String _bucketDate(BuildContext context, AnalyticsQuery query, int index) {
  final date = query.buckets[index].start;
  final label = query.period == AnalyticsPeriod.year
      ? DeviceFormats.month(context, date)
      : DeviceFormats.date(context, date);
  if (!query.isCurrent(index)) return label;
  final current = query.period == AnalyticsPeriod.year
      ? context.copy.inProgress
      : context.copy.today;
  return '$label ($current)';
}

String _bucketSummary(
  BuildContext context,
  AnalyticsSnapshot snapshot,
  int index,
) {
  final date = _bucketDate(context, snapshot.query, index);
  if (snapshot.query.isFuture(index)) {
    return '$date, ${context.copy.analyticsUpcoming}';
  }
  final total = snapshot.bucket(index);
  return context.copy.analyticsBucketSummary(
    date,
    total.count,
    total.focusSeconds ~/ 60,
  );
}

class _BucketValue extends StatelessWidget {
  const _BucketValue({required this.snapshot, required this.index});
  final AnalyticsSnapshot snapshot;
  final int index;

  @override
  Widget build(BuildContext context) {
    final future = snapshot.query.isFuture(index);
    final total = snapshot.bucket(index);
    return Semantics(
      container: true,
      label: _bucketSummary(context, snapshot, index),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: PomaSpace.sm),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: PomaSpace.md,
            runSpacing: PomaSpace.xxs,
            children: [
              Text(_bucketDate(context, snapshot.query, index)),
              Text(
                future
                    ? context.copy.analyticsUpcoming
                    : '${DeviceFormats.number(context, total.count)} '
                          '${context.copy.analyticsSessionUnit(total.count)}, '
                          '${context.copy.minutes(total.focusSeconds ~/ 60)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionChart extends StatefulWidget {
  const _SessionChart({required this.snapshot, super.key});
  final AnalyticsSnapshot snapshot;

  @override
  State<_SessionChart> createState() => _SessionChartState();
}

class _SessionChartState extends State<_SessionChart> {
  final _focus = FocusNode();
  late int _selected;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    final query = widget.snapshot.query;
    _selected = query.buckets.indexWhere(
      (bucket) =>
          !bucket.start.isAfter(query.today) && bucket.end.isAfter(query.today),
    );
    if (_selected < 0) _selected = query.buckets.length - 1;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _select(int index) {
    final next = index.clamp(0, widget.snapshot.query.buckets.length - 1);
    if (next != _selected) setState(() => _selected = next);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _select(_selected - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _select(_selected + 1);
    } else if (key == LogicalKeyboardKey.home) {
      _select(0);
    } else if (key == LogicalKeyboardKey.end) {
      _select(widget.snapshot.query.buckets.length - 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final query = snapshot.query;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final counts = List<int?>.generate(
      query.buckets.length,
      (i) => query.isFuture(i) ? null : snapshot.bucket(i).count,
    );
    final maximum = counts.fold(
      0,
      (value, count) => math.max(value, count ?? 0),
    );
    final step = _tickStep(maximum);
    final axisMax = step * 4;
    final summary = _bucketSummary(context, snapshot, _selected);
    final axisText = theme.textTheme.bodySmall!;
    final measurement = TextPainter(
      text: TextSpan(
        text: DeviceFormats.number(context, axisMax),
        style: axisText,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final axisWidth = measurement.width + PomaSpace.sm;
    measurement.dispose();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: const Key('analytics-chart'),
          label: context.copy.analyticsChartHelp,
          value: summary,
          increasedValue: _selected < counts.length - 1
              ? _bucketSummary(context, snapshot, _selected + 1)
              : null,
          decreasedValue: _selected > 0
              ? _bucketSummary(context, snapshot, _selected - 1)
              : null,
          onIncrease: _selected < counts.length - 1
              ? () => _select(_selected + 1)
              : null,
          onDecrease: _selected > 0 ? () => _select(_selected - 1) : null,
          child: Focus(
            focusNode: _focus,
            onKeyEvent: _key,
            onFocusChange: (value) => setState(() => _focused = value),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focused ? colors.primary : colors.surface,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(PomaSpace.xs),
                child: ExcludeSemantics(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: axisWidth,
                        height: 216,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            for (var i = 4; i >= 0; i--)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: PomaSpace.xs,
                                ),
                                child: Text(
                                  DeviceFormats.number(context, i * step),
                                  style: axisText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            void point(double x) => _select(
                              (x / constraints.maxWidth * counts.length)
                                  .floor(),
                            );
                            return MouseRegion(
                              onHover: (event) => point(event.localPosition.dx),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  _focus.requestFocus();
                                  point(details.localPosition.dx);
                                },
                                onHorizontalDragUpdate: (details) =>
                                    point(details.localPosition.dx),
                                child: Tooltip(
                                  message: summary,
                                  excludeFromSemantics: true,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: PomaSpace.xs),
                                      SizedBox(
                                        height: 200,
                                        width: double.infinity,
                                        child: CustomPaint(
                                          painter: _BarsPainter(
                                            counts: counts,
                                            maximum: axisMax,
                                            selected: _selected,
                                            current: query.buckets.indexWhere(
                                              (bucket) =>
                                                  !bucket.start.isAfter(
                                                    query.today,
                                                  ) &&
                                                  bucket.end.isAfter(
                                                    query.today,
                                                  ),
                                            ),
                                            barColor: colors.primary,
                                            gridColor: colors.outlineVariant,
                                            markerColor: colors.onSurface,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: PomaSpace.sm),
                                      SizedBox(
                                        height: 24,
                                        child: _AxisLabels(query: query),
                                      ),
                                    ],
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
              ),
            ),
          ),
        ),
        const SizedBox(height: PomaSpace.sm),
        Semantics(
          liveRegion: _focused,
          child: Text(summary, style: theme.textTheme.bodySmall),
        ),
      ],
    );
  }
}

int _tickStep(int maximum) {
  if (maximum <= 4) return 1;
  final raw = maximum / 4;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
  final normalized = raw / magnitude;
  final nice = [1, 2, 5, 10].firstWhere((value) => value >= normalized);
  return (nice * magnitude).round();
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.query});
  final AnalyticsQuery query;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = query.buckets.length;
      final stride = query.period == AnalyticsPeriod.week
          ? 1
          : (count / 6).ceil();
      return Stack(
        children: [
          for (var i = 0; i < count; i++)
            if ((i % stride == 0 && i <= count - 1 - stride) || i == count - 1)
              Positioned(
                left: ((i + .5) * constraints.maxWidth / count - 22).clamp(
                  0,
                  math.max(0, constraints.maxWidth - 44),
                ),
                width: 44,
                child: Text(
                  switch (query.period) {
                    AnalyticsPeriod.week => DeviceFormats.weekday(
                      context,
                      query.buckets[i].start,
                    ),
                    AnalyticsPeriod.month => DeviceFormats.day(
                      context,
                      query.buckets[i].start,
                    ),
                    AnalyticsPeriod.year => DeviceFormats.shortMonth(
                      context,
                      query.buckets[i].start,
                    ),
                  },
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
        ],
      );
    },
  );
}

class _BarsPainter extends CustomPainter {
  const _BarsPainter({
    required this.counts,
    required this.maximum,
    required this.selected,
    required this.current,
    required this.barColor,
    required this.gridColor,
    required this.markerColor,
  });
  final List<int?> counts;
  final int maximum, selected, current;
  final Color barColor, gridColor, markerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = (size.height - 1) * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final slot = size.width / counts.length;
    final bar = Paint()..color = barColor;
    final marker = Paint()
      ..color = markerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < counts.length; i++) {
      final count = counts[i];
      if (count == null) continue;
      final center = (i + .5) * slot;
      final width = math.min(28.0, slot * .56);
      final height = (size.height - 1) * count / maximum;
      final rect = Rect.fromLTWH(
        center - width / 2,
        size.height - height - 1,
        width,
        height,
      );
      if (count > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          bar,
        );
      }
      if (i == current) {
        final outline = Rect.fromLTRB(
          rect.left - 2,
          math.max(1, rect.top - 3),
          rect.right + 2,
          size.height - 1,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(outline, const Radius.circular(4)),
          marker,
        );
      }
    }
    final cursor = (selected + .5) * slot;
    canvas.drawLine(Offset(cursor, 0), Offset(cursor, size.height), grid);
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      !listEquals(old.counts, counts) ||
      old.maximum != maximum ||
      old.selected != selected ||
      old.current != current ||
      old.barColor != barColor ||
      old.gridColor != gridColor ||
      old.markerColor != markerColor;
}
