import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../application/local_repository.dart';
import 'copy.dart';
import 'focus_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({required this.controller, super.key});
  final AppController controller;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _seenAlertOpenRevision = 0;
  int _tab = 0;
  String? _announcedRun;
  void _goTo(int tab) {
    widget.controller.showInsights(tab == 2);
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (_seenAlertOpenRevision != controller.alertOpenRevision) {
      _seenAlertOpenRevision = controller.alertOpenRevision;
      _tab = 0;
      controller.showInsights(false);
    }
    final copy = context.copy;
    final notice = controller.lastPhaseCompletion;
    final announceCompletion =
        _tab == 0 && notice != null && _announcedRun != notice.runId;
    if (announceCompletion) _announcedRun = notice.runId;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: switch (_tab) {
          0 => FocusScreen(
            controller: controller,
            onTasks: () => _goTo(1),
            announceCompletion: announceCompletion,
          ),
          1 => TasksScreen(controller: controller),
          2 => InsightsScreen(controller: controller),
          _ => SettingsScreen(controller: controller),
        },
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labels = [
              copy.focus,
              copy.tasks,
              copy.insights,
              copy.settings,
            ];
            const icons = [
              Icons.timelapse,
              Icons.checklist,
              Icons.bar_chart,
              Icons.tune,
            ];
            final style = Theme.of(context).textTheme.labelLarge!;
            var requiredWidth = 0.0;
            for (final label in labels) {
              final text = TextPainter(
                text: TextSpan(text: label, style: style),
                textScaler: MediaQuery.textScalerOf(context),
                textDirection: Directionality.of(context),
              )..layout();
              if (text.width + 32 > requiredWidth) {
                requiredWidth = text.width + 32;
              }
              text.dispose();
            }
            final columns = requiredWidth * 4 > constraints.maxWidth - 16
                ? 2
                : 4;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Wrap(
                children: [
                  for (var i = 0; i < 4; i++)
                    SizedBox(
                      width: (constraints.maxWidth - 16) / columns,
                      child: Semantics(
                        selected: _tab == i,
                        child: TextButton(
                          key: Key('destination-$i'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 64),
                            foregroundColor: _tab == i
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            backgroundColor: _tab == i
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .10)
                                : null,
                          ),
                          onPressed: () => _goTo(i),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(child: Icon(icons[i])),
                              const SizedBox(height: 4),
                              Text(labels[i], textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Notices share the page scroll region, keeping controls reachable even when
/// multiple failures are visible with large text.
class PomaPage extends StatelessWidget {
  const PomaPage({required this.controller, required this.children, super.key});
  final AppController controller;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    children: [
      if (controller.clockError != null)
        _Notice(
          message: context.copy.clockError,
          action: context.copy.retry,
          onPressed: controller.reconcile,
        ),
      if (controller.saveError != null)
        _Notice(
          message: storageMessage(
            context.copy,
            controller.saveFailureKind ?? StorageFailureKind.write,
          ),
          action: context.copy.retry,
          onPressed: controller.retrySave,
        ),
      if (controller.cleanupPending && controller.saveError == null)
        _Notice(
          message: context.copy.cleanupNotice,
          action: context.copy.finishDeletion,
          onPressed: controller.retrySave,
        ),
      ...children,
    ],
  );
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.message,
    required this.action,
    required this.onPressed,
  });
  final String message;
  final String action;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          TextButton(onPressed: onPressed, child: Text(action)),
          const Divider(),
        ],
      ),
    ),
  );
}

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}
