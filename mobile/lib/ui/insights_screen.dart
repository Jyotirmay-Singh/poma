import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../application/local_repository.dart';
import 'app_shell.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final now = controller.localNow;
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - 6 + i),
    );
    final summaries = controller.summaries;
    final complete = summaries != null && summaries.length == 7;
    final minutes = days.map((day) {
      for (final summary in summaries ?? <DaySummary>[]) {
        if (summary.date.year == day.year &&
            summary.date.month == day.month &&
            summary.date.day == day.day) {
          return summary.focusSeconds ~/ 60;
        }
      }
      return 0;
    }).toList();
    final largest = minutes.fold(1, (max, value) => value > max ? value : max);
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      children: [
        const ScreenHeading(
          title: 'Small sessions add up.',
          subtitle: 'Your focus, one day at a time.',
        ),
        Text(
          complete
              ? '${minutes.reduce((a, b) => a + b)} min'
              : 'Loading focus totals…',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Focused over the last 7 days',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (controller.summaryError != null) ...[
          Text(controller.summaryError!),
          TextButton(
            onPressed: controller.loadSummaries,
            child: const Text('Retry totals'),
          ),
        ],
        if (complete)
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < days.length; i++)
                  Expanded(
                    child: Semantics(
                      label:
                          '${MaterialLocalizations.of(context).formatMediumDate(days[i])}, ${minutes[i]} minutes focused',
                      child: ExcludeSemantics(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '${minutes[i]}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: minutes[i] == 0
                                    ? 3
                                    : 110 * minutes[i] / largest,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: i == 6
                                      ? colors.primary
                                      : colors.primary.withValues(alpha: .25),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(7),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                const [
                                  'M',
                                  'T',
                                  'W',
                                  'T',
                                  'F',
                                  'S',
                                  'S',
                                ][days[i].weekday - 1],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 18),
        Text('Recent sessions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (controller.historyLoading)
          const LinearProgressIndicator(semanticsLabel: 'Loading history'),
        if (controller.historyError != null) ...[
          Text(controller.historyError!),
          TextButton(
            onPressed: controller.retryHistory,
            child: const Text('Retry history'),
          ),
        ],
        if (controller.historyLoaded &&
            controller.sessions.isEmpty &&
            controller.historyError == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Finish your first focus session to see it here.\nSkipped sessions are not counted.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
            ),
          ),
        for (final session in controller.sessions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.check_circle_outline_rounded,
              color: colors.primary,
            ),
            title: Text(session.taskTitle ?? 'Focus session'),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatMediumDate(session.endedAt.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(session.endedAt.toLocal()))}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${session.focusSeconds ~/ 60} min'),
                IconButton(
                  tooltip: 'Delete session',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDeletion(
                          context,
                          title: 'Delete session?',
                          message:
                              'Remove this completed session from history and focus totals?',
                        ) &&
                        context.mounted) {
                      await controller.deleteHistory(id: session.id);
                    }
                  },
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
              child: const Text('Newer'),
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
              child: const Text('Older'),
            ),
            TextButton(
              onPressed: () => controller.loadHistory(),
              child: const Text('Latest'),
            ),
          ],
        ),
        const Text('History stays on this phone until you delete it.'),
        if (controller.deletionError != null) Text(controller.deletionError!),
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ??
    false;
