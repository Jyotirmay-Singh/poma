import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../application/local_repository.dart';
import 'app_shell.dart';
import 'copy.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final now = controller.localNow;
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - 6 + i),
    );
    final summaries = controller.summaries;
    final complete = summaries != null && summaries.length == 7;
    final daily = days
        .map(
          (day) =>
              summaries
                  ?.where(
                    (s) =>
                        s.date.year == day.year &&
                        s.date.month == day.month &&
                        s.date.day == day.day,
                  )
                  .firstOrNull ??
              DaySummary(day, 0, 0),
        )
        .toList();
    final largest = daily.fold(
      1,
      (max, day) => day.focusSeconds > max ? day.focusSeconds : max,
    );
    final colors = Theme.of(context).colorScheme;
    return PomaPage(
      controller: controller,
      children: [
        ScreenHeading(title: copy.insights, subtitle: copy.weekHelp),
        Text(
          complete
              ? copy.minutes(
                  daily.fold(0, (sum, day) => sum + day.focusSeconds) ~/ 60,
                )
              : copy.loadingTotals,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          copy.lastSevenDays,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        if (controller.summaryError != null) ...[
          Text(copy.totalsReadError),
          TextButton(
            onPressed: controller.loadSummaries,
            child: Text(copy.retryTotals),
          ),
        ],
        if (complete) ...[
          const SizedBox(height: 24),
          // The chart is supplementary. Exact dates, session counts and amounts
          // are always available as text and one semantic node per day below.
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                return const SizedBox.shrink();
              }
              return ExcludeSemantics(
                child: SizedBox(
                  height: 160,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < daily.length; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  height: daily[i].focusSeconds == 0
                                      ? 3
                                      : 110 * daily[i].focusSeconds / largest,
                                  width: double.infinity,
                                  color: colors.primary,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  DeviceFormats.weekday(context, days[i]),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              copy.dailyTotals,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (var i = 0; i < daily.length; i++)
            Semantics(
              label: copy.dailySummary(
                '${DeviceFormats.date(context, days[i])}${i == 6 ? ', ${copy.today}' : ''}',
                daily[i].count,
                daily[i].focusSeconds ~/ 60,
              ),
              child: ExcludeSemantics(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${DeviceFormats.date(context, days[i])}${i == 6 ? ' (${copy.today})' : ''}',
                      ),
                      Text(
                        copy.todayTotals(
                          daily[i].count,
                          daily[i].focusSeconds ~/ 60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        Semantics(
          header: true,
          child: Text(
            copy.recentSessions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        if (controller.historyLoading)
          LinearProgressIndicator(semanticsLabel: copy.loadingHistory),
        if (controller.historyError != null) ...[
          Text(copy.historyReadError),
          TextButton(
            onPressed: controller.retryHistory,
            child: Text(copy.retryHistory),
          ),
        ],
        if (controller.historyLoaded &&
            controller.sessions.isEmpty &&
            controller.historyError == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              copy.emptyHistory,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
            ),
          ),
        for (final session in controller.sessions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.taskTitle ?? copy.focusSession,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  copy.sessionDate(
                    DeviceFormats.date(context, session.endedAt.toLocal()),
                    DeviceFormats.time(context, session.endedAt.toLocal()),
                  ),
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(copy.minutes(session.focusSeconds ~/ 60)),
                    IconButton(
                      key: ValueKey('delete-session-${session.id}'),
                      tooltip: copy.deleteNamedSession(
                        session.taskTitle ?? copy.focusSession,
                        DeviceFormats.date(context, session.endedAt.toLocal()),
                      ),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirmDeletion(
                              context,
                              title: copy.deleteSessionTitle,
                              message: copy.deleteSessionHelp,
                            ) &&
                            context.mounted) {
                          await controller.deleteHistory(id: session.id);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed:
                  !controller.historyLoading &&
                      controller.historyPage?.hasNewer == true &&
                      controller.sessions.isNotEmpty
                  ? () => controller.loadHistory(
                      after: HistoryCursor.forSession(
                        controller.sessions.first,
                      ),
                    )
                  : null,
              child: Text(copy.newer),
            ),
            TextButton(
              onPressed:
                  !controller.historyLoading &&
                      controller.historyPage?.hasOlder == true &&
                      controller.sessions.isNotEmpty
                  ? () => controller.loadHistory(
                      before: HistoryCursor.forSession(
                        controller.sessions.last,
                      ),
                    )
                  : null,
              child: Text(copy.older),
            ),
            TextButton(
              onPressed: controller.historyLoading
                  ? null
                  : () => controller.loadHistory(),
              child: Text(copy.latest),
            ),
          ],
        ),
        Text(copy.historyRetention),
        if (controller.deletionError != null) Text(copy.deletionSaveError),
      ],
    );
  }
}

Future<bool> confirmDeletion(
  BuildContext context, {
  required String title,
  required String message,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.copy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.copy.delete),
          ),
        ],
      ),
    ) ??
    false;
