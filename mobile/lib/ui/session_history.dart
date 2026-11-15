import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../application/local_repository.dart';
import 'copy.dart';
import 'desktop_scope.dart';
import 'design_tokens.dart';

class SessionHistory extends StatelessWidget {
  const SessionHistory({required this.controller, super.key});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final desktop = DesktopScope.maybeOf(context) != null;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            copy.recentSessions,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: PomaSpace.sm),
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
            padding: const EdgeInsets.symmetric(vertical: PomaSpace.lg),
            child: Text(
              copy.emptyHistory,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        if (DesktopScope.maybeOf(context) != null &&
            MediaQuery.sizeOf(context).width >= 1280 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.3)
          DataTable(
            key: const Key('desktop-history-table'),
            columnSpacing: 24,
            horizontalMargin: 8,
            dataRowMaxHeight: double.infinity,
            columns: [
              DataColumn(label: Text(copy.taskName)),
              DataColumn(label: Text(copy.completed)),
              DataColumn(label: Text(copy.historyDuration)),
              DataColumn(label: Text(copy.delete)),
            ],
            rows: [
              for (final session in controller.sessions)
                DataRow(
                  cells: [
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: PomaSpace.sm,
                          ),
                          child: Text(session.taskTitle ?? copy.focusSession),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        copy.sessionDate(
                          DeviceFormats.date(
                            context,
                            session.endedAt.toLocal(),
                          ),
                          DeviceFormats.time(
                            context,
                            session.endedAt.toLocal(),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(copy.minutes(session.focusSeconds ~/ 60))),
                    DataCell(
                      IconButton(
                        tooltip: copy.deleteNamedSession(
                          session.taskTitle ?? copy.focusSession,
                          DeviceFormats.date(
                            context,
                            session.endedAt.toLocal(),
                          ),
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
                    ),
                  ],
                ),
            ],
          )
        else
          for (final session in controller.sessions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PomaSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.taskTitle ?? copy.focusSession,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: PomaSpace.xxs),
                  Text(
                    copy.sessionDate(
                      DeviceFormats.date(context, session.endedAt.toLocal()),
                      DeviceFormats.time(context, session.endedAt.toLocal()),
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: PomaSpace.sm,
                    children: [
                      Text(copy.minutes(session.focusSeconds ~/ 60)),
                      IconButton(
                        key: ValueKey('delete-session-${session.id}'),
                        tooltip: copy.deleteNamedSession(
                          session.taskTitle ?? copy.focusSession,
                          DeviceFormats.date(
                            context,
                            session.endedAt.toLocal(),
                          ),
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
          spacing: PomaSpace.sm,
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
        Text(desktop ? copy.windowsHistoryRetention : copy.historyRetention),
        if (controller.deletionError != null)
          Text(
            desktop ? copy.windowsDeletionSaveError : copy.deletionSaveError,
          ),
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
