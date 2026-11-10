import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'design_tokens.dart';
import 'day_clock_screen.dart';

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
      5 when desktop != null => DayClockScreen(
        app: controller,
        desktop: desktop,
        key: const ValueKey('day-clock-page'),
      ),
      4 when desktop != null => CalendarScreen(
        controller: controller,
        desktop: desktop,
        key: const ValueKey('calendar-page'),
      ),
      _ => SettingsScreen(controller: controller),
    };
    if (desktop != null &&
        MediaQuery.sizeOf(context).width >= PomaLayout.navigationRail) {
      final extended =
          MediaQuery.sizeOf(context).width >= PomaLayout.extendedRail &&
          MediaQuery.textScalerOf(context).scale(1) < 1.5;
      return CallbackShortcuts(
        bindings: {
          for (var i = 0; i < desktopDestinationOrder.length; i++)
            SingleActivator(
              [
                LogicalKeyboardKey.digit1,
                LogicalKeyboardKey.digit2,
                LogicalKeyboardKey.digit3,
                LogicalKeyboardKey.digit4,
                LogicalKeyboardKey.digit5,
                LogicalKeyboardKey.digit6,
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
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: PomaSpace.lg,
                        ),
                        child: Text(
                          extended ? 'Poma' : 'P',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: IntrinsicHeight(
                            child: NavigationRail(
                              extended: extended,
                              minExtendedWidth: 216,
                              selectedIndex: desktopDestinationOrder.indexOf(
                                _tab,
                              ),
                              onDestinationSelected: (i) =>
                                  _goTo(desktopDestinationOrder[i]),
                              destinations: [
                                for (final entry in [
                                  (Icons.timelapse, copy.focus),
                                  (Icons.checklist, copy.tasks),
                                  (Icons.calendar_month_outlined, 'Calendar'),
                                  (Icons.schedule_outlined, 'Day Clock'),
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
      bottomNavigationBar: Material(
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labels = [
                copy.focus,
                copy.tasks,
                if (desktop != null) 'Calendar',
                if (desktop != null) 'Day Clock',
                copy.insights,
                copy.settings,
              ];
              final ids = desktop == null
                  ? const [0, 1, 2, 3]
                  : desktopDestinationOrder;
              final icons = [
                Icons.timelapse,
                Icons.checklist,
                if (desktop != null) Icons.calendar_month_outlined,
                if (desktop != null) Icons.schedule_outlined,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: PomaSpace.xs,
                  vertical: PomaSpace.xxs,
                ),
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
                              minimumSize: const Size(48, 56),
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
                                const SizedBox(height: PomaSpace.xxs),
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
      ),
    );
  }
}

/// Notices share the page scroll region, keeping controls reachable even when
/// multiple failures are visible with large text.
class PomaPage extends StatelessWidget {
  const PomaPage({
    required this.controller,
    required this.children,
    this.maxContentWidth = PomaLayout.readingWidth,
    this.readingSurface = true,
    super.key,
  });
  final AppController controller;
  final List<Widget> children;
  final double maxContentWidth;
  final bool readingSurface;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      padding: EdgeInsets.fromLTRB(
        PomaLayout.pageInset(constraints.maxWidth, maxWidth: maxContentWidth),
        PomaSpace.lg,
        PomaLayout.pageInset(constraints.maxWidth, maxWidth: maxContentWidth),
        PomaSpace.xl,
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
        for (var i = 0; i < children.length; i++)
          if (!readingSurface || i == 0)
            children[i]
          else
            // Keep individual sliver children and their semantics separate.
            Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.vertical(
                top: i == 1
                    ? const Radius.circular(PomaLayout.panelRadius)
                    : Radius.zero,
                bottom: i == children.length - 1
                    ? const Radius.circular(PomaLayout.panelRadius)
                    : Radius.zero,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  PomaSpace.md,
                  i == 1 ? PomaSpace.md : 0,
                  PomaSpace.md,
                  i == children.length - 1 ? PomaSpace.md : 0,
                ),
                child: children[i],
              ),
            ),
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
      padding: const EdgeInsets.only(bottom: PomaSpace.md),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: theme.textTheme.headlineSmall!.copyWith(
              fontSize:
                  MediaQuery.sizeOf(context).width >= PomaLayout.navigationRail
                  ? 28
                  : 24,
              height:
                  MediaQuery.sizeOf(context).width >= PomaLayout.navigationRail
                  ? 36 / 28
                  : 32 / 24,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: PomaSpace.xs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: PomaSpace.lg),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (action == null) return heading;
          if (constraints.maxWidth < 600 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.4) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                const SizedBox(height: PomaSpace.md),
                action!,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: heading),
              const SizedBox(width: PomaSpace.lg),
              action!,
            ],
          );
        },
      ),
    );
  }
}
