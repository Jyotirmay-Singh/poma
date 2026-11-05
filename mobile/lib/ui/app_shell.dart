import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import '../application/app_controller.dart';
import '../application/local_repository.dart';
import '../application/desktop_controller.dart';
import 'copy.dart';
import 'focus_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'tasks_screen.dart';
import 'desktop_scope.dart';
import 'calendar_screen.dart';

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
  int _seenDesktopNavigation = 0;
  int _seenNewTask = 0;
  void _goTo(int tab) {
    DesktopScope.maybeOf(context)?.navigate(tab);
    widget.controller.showInsights(tab == 2);
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final desktop = DesktopScope.maybeOf(context);
    if (desktop != null &&
        _seenDesktopNavigation != desktop.navigationRevision) {
      _seenDesktopNavigation = desktop.navigationRevision;
      _tab = desktop.destination;
    }
    if (desktop != null && _seenNewTask != desktop.newTaskRevision) {
      _seenNewTask = desktop.newTaskRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showNewTaskDialog(context, controller);
      });
    }
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
    final page = switch (_tab) {
      0 => FocusScreen(
        controller: controller,
        onTasks: () => _goTo(1),
        announceCompletion: announceCompletion,
      ),
      1 => TasksScreen(controller: controller),
      2 => InsightsScreen(controller: controller),
      4 when desktop != null => CalendarScreen(
        controller: controller,
        desktop: desktop,
        key: const ValueKey('calendar-page'),
      ),
      _ => SettingsScreen(controller: controller),
    };
    if (desktop != null && MediaQuery.sizeOf(context).width >= 700) {
      final extended =
          MediaQuery.sizeOf(context).width >= 1000 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.5;
      return CallbackShortcuts(
        bindings: {
          for (var i = 0; i < 5; i++)
            SingleActivator(
              [
                LogicalKeyboardKey.digit1,
                LogicalKeyboardKey.digit2,
                LogicalKeyboardKey.digit3,
                LogicalKeyboardKey.digit4,
                LogicalKeyboardKey.digit5,
              ][i],
              control: true,
            ): () =>
                _goTo(desktopDestinationOrder[i]),
          const SingleActivator(LogicalKeyboardKey.keyN, control: true):
              desktop.requestNewTask,
        },
        child: Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        extended ? 'Poma' : 'P',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: IntrinsicHeight(
                          child: NavigationRail(
                            extended: extended,
                            minExtendedWidth: 216,
                            selectedIndex: const [0, 1, 4, 2, 3].indexOf(_tab),
                            onDestinationSelected: (i) =>
                                _goTo(const [0, 1, 4, 2, 3][i]),
                            destinations: [
                              for (final entry in [
                                (Icons.timelapse, copy.focus),
                                (Icons.checklist, copy.tasks),
                                (Icons.calendar_month_outlined, 'Calendar'),
                                (Icons.bar_chart, copy.desktopHistory),
                                (Icons.tune, copy.settings),
                              ])
                                NavigationRailDestination(
                                  icon: Tooltip(
                                    message: entry.$2,
                                    child: Icon(entry.$1),
                                  ),
                                  label: Text(entry.$2),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: page),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(bottom: false, child: page),
      bottomNavigationBar: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final labels = [
              copy.focus,
              copy.tasks,
              if (desktop != null) 'Calendar',
              copy.insights,
              copy.settings,
            ];
            final ids = desktop == null
                ? const [0, 1, 2, 3]
                : const [0, 1, 4, 2, 3];
            final icons = [
              Icons.timelapse,
              Icons.checklist,
              if (desktop != null) Icons.calendar_month_outlined,
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
            final columns =
                requiredWidth * labels.length > constraints.maxWidth - 16
                ? 2
                : labels.length;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Wrap(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    SizedBox(
                      width: (constraints.maxWidth - 16) / columns,
                      child: Semantics(
                        selected: _tab == ids[i],
                        child: TextButton(
                          key: Key('destination-${ids[i]}'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 64),
                            foregroundColor: _tab == ids[i]
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                            backgroundColor: _tab == ids[i]
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .10)
                                : null,
                          ),
                          onPressed: () => _goTo(ids[i]),
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
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: EdgeInsets.fromLTRB(
        DesktopScope.maybeOf(context) == null
            ? 24
            : math.max(24, (constraints.maxWidth - 1120) / 2),
        20,
        DesktopScope.maybeOf(context) == null
            ? 24
            : math.max(24, (constraints.maxWidth - 1120) / 2),
        28,
      ),
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
    ),
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
