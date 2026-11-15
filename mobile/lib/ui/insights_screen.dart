import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/analytics.dart';
import 'analytics_chart.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'design_tokens.dart';
import 'session_history.dart';

export 'session_history.dart' show confirmDeletion;

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({required this.controller, this.onFocus, super.key});
  final AppController controller;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final history = controller.analyticsHistoryVisible;
    return PomaPage(
      controller: controller,
      maxContentWidth: PomaLayout.workspaceWidth,
      children: [
        ScreenHeading(
          title: copy.insights,
          subtitle: DeviceFormats.date(context, controller.localNow),
        ),
        Wrap(
          spacing: PomaSpace.xs,
          runSpacing: PomaSpace.xs,
          children: [
            _ViewTab(
              key: const Key('analytics-overview-tab'),
              label: copy.analyticsOverview,
              selected: !history,
              onPressed: () => controller.showAnalyticsHistory(false),
            ),
            _ViewTab(
              key: const Key('analytics-history-tab'),
              label: copy.analyticsHistory,
              selected: history,
              onPressed: () => controller.showAnalyticsHistory(true),
            ),
          ],
        ),
        const SizedBox(height: PomaSpace.lg),
        if (history)
          SessionHistory(controller: controller)
        else
          _Overview(controller: controller, onFocus: onFocus),
      ],
    );
  }
}

class _ViewTab extends StatelessWidget {
  const _ViewTab({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? colors.onPrimaryContainer
              : colors.onSurface,
          backgroundColor: selected ? colors.primaryContainer : colors.surface,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.controller, this.onFocus});
  final AppController controller;
  final VoidCallback? onFocus;

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final snapshot = controller.analytics;
    final query = snapshot?.query ?? controller.analyticsQuery;
    final averages = _Averages(snapshot: snapshot, query: query);
    final chart = AnalyticsActivity(controller: controller);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.analyticsLoading) ...[
          Semantics(
            liveRegion: true,
            label: copy.analyticsLoading,
            child: const ExcludeSemantics(
              child: LinearProgressIndicator(value: 0),
            ),
          ),
          const SizedBox(height: PomaSpace.md),
        ],
        if (controller.analyticsError != null || controller.analyticsStale) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              controller.analyticsError != null
                  ? copy.analyticsReadError
                  : copy.analyticsStale,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: controller.analyticsLoading
                  ? null
                  : controller.loadAnalytics,
              icon: const Icon(Icons.refresh),
              label: Text(
                controller.analyticsError != null
                    ? copy.analyticsRetry
                    : copy.analyticsRefresh,
              ),
            ),
          ),
          const SizedBox(height: PomaSpace.md),
        ],
        _Totals(snapshot: snapshot, query: query),
        const SizedBox(height: PomaSpace.xl),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 960 &&
                MediaQuery.textScalerOf(context).scale(1) <= 1.3) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: chart),
                  const SizedBox(width: PomaSpace.xl),
                  Expanded(child: averages),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                averages,
                const SizedBox(height: PomaSpace.xl),
                chart,
              ],
            );
          },
        ),
        if (snapshot != null &&
            !snapshot.hasSessions &&
            controller.analyticsError == null &&
            !controller.analyticsLoading) ...[
          const SizedBox(height: PomaSpace.lg),
          Text(copy.analyticsEmpty),
          if (onFocus != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onFocus,
                icon: const Icon(Icons.timelapse),
                label: Text(copy.analyticsGoToFocus),
              ),
            ),
        ],
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.snapshot, required this.query});
  final AnalyticsSnapshot? snapshot;
  final AnalyticsQuery query;

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final today = _Total(
      key: const Key('analytics-today'),
      label: copy.today,
      count: snapshot?.today.count,
      date: DeviceFormats.date(context, query.today),
      prominent: true,
    );
    final week = _Total(
      key: const Key('analytics-this-week'),
      label: copy.analyticsThisWeek,
      count: snapshot?.thisWeek.count,
      date: DeviceFormats.dateRange(
        context,
        query.metrics[1].start,
        DateTime(
          query.metrics[1].start.year,
          query.metrics[1].start.month,
          query.metrics[1].start.day + 6,
        ),
      ),
    );
    final month = _Total(
      key: const Key('analytics-last-month'),
      label: copy.analyticsLastMonth,
      count: snapshot?.lastMonth.count,
      date: DeviceFormats.month(context, query.metrics[2].start),
    );
    return Container(
      padding: const EdgeInsets.all(PomaSpace.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final normalText = MediaQuery.textScalerOf(context).scale(1) <= 1.3;
          if (constraints.maxWidth >= 552 && normalText) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: today),
                const SizedBox(width: PomaSpace.lg),
                Expanded(child: week),
                const SizedBox(width: PomaSpace.lg),
                Expanded(child: month),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              today,
              const SizedBox(height: PomaSpace.lg),
              if (constraints.maxWidth >= 272 && normalText)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: week),
                    const SizedBox(width: PomaSpace.md),
                    Expanded(child: month),
                  ],
                )
              else ...[
                week,
                const SizedBox(height: PomaSpace.lg),
                month,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.count,
    required this.date,
    this.prominent = false,
    super.key,
  });
  final String label;
  final int? count;
  final String date;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = count == null ? '—' : DeviceFormats.number(context, count!);
    final units = count == null
        ? context.copy.analyticsUnavailable
        : context.copy.analyticsSessionUnit(count!);
    return Semantics(
      container: true,
      label: '$label, $value $units, $date',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.titleSmall),
            const SizedBox(height: PomaSpace.xs),
            Text(
              value,
              style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: prominent ? 48 : 36,
                height: 1.2,
                color: prominent
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(units, style: theme.textTheme.bodySmall),
            const SizedBox(height: PomaSpace.xs),
            Text(
              date,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Averages extends StatelessWidget {
  const _Averages({required this.snapshot, required this.query});
  final AnalyticsSnapshot? snapshot;
  final AnalyticsQuery query;

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(PomaSpace.md),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              copy.analyticsAverages,
              style: theme.textTheme.titleLarge,
            ),
          ),
          _Average(
            key: const Key('analytics-daily-average'),
            label: copy.analyticsDailyAverage,
            value: snapshot?.dailyAverage,
            units: copy.analyticsPerDay,
            help: copy.analyticsDailyHelp,
            window: query.metrics[3],
          ),
          const Divider(height: PomaSpace.lg),
          _Average(
            key: const Key('analytics-weekly-average'),
            label: copy.analyticsWeeklyAverage,
            value: snapshot?.weeklyAverage,
            units: copy.analyticsPerWeek,
            help: copy.analyticsWeeklyHelp,
            window: query.metrics[4],
          ),
          const Divider(height: PomaSpace.lg),
          _Average(
            key: const Key('analytics-monthly-average'),
            label: copy.analyticsMonthlyAverage,
            value: snapshot?.monthlyAverage,
            units: copy.analyticsPerMonth,
            help: copy.analyticsMonthlyHelp,
            window: query.metrics[5],
          ),
        ],
      ),
    );
  }
}

class _Average extends StatelessWidget {
  const _Average({
    required this.label,
    required this.value,
    required this.units,
    required this.help,
    required this.window,
    super.key,
  });
  final String label, units, help;
  final double? value;
  final AnalyticsWindow window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = DeviceFormats.dateRange(
      context,
      window.start,
      window.lastDate,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: theme.textTheme.titleSmall)),
            IconButton(
              tooltip: label,
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  scrollable: true,
                  title: Text(label),
                  content: Text('$help\n\n$range'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.copy.soundClose),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Wrap(
          spacing: PomaSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              value == null
                  ? '—'
                  : DeviceFormats.number(context, value!, fractionDigits: 1),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 28,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(units, style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: PomaSpace.xxs),
        Text(
          range,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
