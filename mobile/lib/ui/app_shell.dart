import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/app_controller.dart';
import '../application/local_repository.dart';
import '../application/desktop_controller.dart';
import 'copy.dart';
import 'focus_screen.dart';
import 'insights_screen.dart';
import 'settings_screen.dart';
import 'planner_scope.dart';
import 'planner_screen.dart';
import 'calendar_tasks.dart';
import 'desktop_scope.dart';
import 'calendar_screen.dart';
import 'design_tokens.dart';
import 'day_clock_screen.dart';
import 'planner_editor.dart';
import 'nebula_appearance.dart';

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
  final _hideSidebarFocus = FocusNode(debugLabel: 'Hide sidebar');
  final _showSidebarFocus = FocusNode(debugLabel: 'Show sidebar');
  final _pageFocus = FocusNode(debugLabel: 'Page content');

  @override
  void dispose() {
    _hideSidebarFocus.dispose();
    _showSidebarFocus.dispose();
    _pageFocus.dispose();
    super.dispose();
  }

  void _toggleSidebar() {
    final collapsed = !widget.controller.desktopPreferences.sidebarCollapsed;
    unawaited(
      widget.controller.patchDesktopPreferences(sidebarCollapsed: collapsed),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!widget.controller.desktopPreferences.sidebarCollapsed) {
        _hideSidebarFocus.requestFocus();
        return;
      }
      final button = _showSidebarFocus.context?.findRenderObject();
      if (button is RenderBox && button.attached) {
        final top = button.localToGlobal(Offset.zero).dy;
        final size = MediaQuery.sizeOf(context);
        if (top >= MediaQuery.paddingOf(context).top &&
            top + button.size.height <= size.height) {
          _showSidebarFocus.requestFocus();
          return;
        }
      }
      // Focusing an off-screen heading would scroll away from the user's work.
      _pageFocus.requestFocus();
    });
  }

  void _toggleSidebarFromKeyboard() {
    if (MediaQuery.sizeOf(context).width < PomaLayout.navigationRail ||
        ModalRoute.of(context)?.isCurrent == false ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorStateOfType<EditableTextState>() !=
            null) {
      return;
    }
    _toggleSidebar();
  }

  void _goTo(int tab) {
    if (tab == 1) tab = 4;
    DesktopScope.maybeOf(context)?.navigate(tab);
    widget.controller.showInsights(tab == 2, history: false);
    setState(() => _tab = tab);
  }

  void _requestNewTask() {
    if (ModalRoute.of(context)?.isCurrent == false ||
        FocusManager.instance.primaryFocus?.context
                ?.findAncestorStateOfType<EditableTextState>() !=
            null) {
      return;
    }
    DesktopScope.maybeOf(context)?.requestNewTask();
  }

  Widget _desktopShortcuts(Widget child) => CallbackShortcuts(
    bindings: {
      for (var i = 0; i < desktopDestinationOrder.length; i++)
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
          _requestNewTask,
      const SingleActivator(LogicalKeyboardKey.keyB, control: true):
          _toggleSidebarFromKeyboard,
    },
    child: Focus(autofocus: true, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final desktop = DesktopScope.maybeOf(context);
    if (desktop != null &&
        _seenDesktopNavigation != desktop.navigationRevision) {
      _seenDesktopNavigation = desktop.navigationRevision;
      if (_tab != desktop.destination) {
        _tab = desktop.destination;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.showInsights(_tab == 2, history: false);
        });
      }
    }
    if (desktop != null && _seenNewTask != desktop.newTaskRevision) {
      _seenNewTask = desktop.newTaskRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent != false) {
          final planner = PlannerScope.maybeOf(context) ?? desktop.planner;
          if (planner != null) {
            showPlannerEditor(context, planner, startUtc: planner.inspectedUtc);
          }
        }
      });
    }
    if (_seenAlertOpenRevision != controller.alertOpenRevision) {
      _seenAlertOpenRevision = controller.alertOpenRevision;
      _tab = 0;
      controller.showInsights(false);
    }
    return PomaNebulaScene(
      enabled:
          controller.settings.darkBackground == 'nebula' &&
          (_tab == 0 || (_tab == 5 && desktop != null)),
      child: Builder(builder: _buildShell),
    );
  }

  Widget _buildShell(BuildContext context) {
    final controller = widget.controller;
    final desktop = DesktopScope.maybeOf(context);
    final theme = Theme.of(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final dark = theme.brightness == Brightness.dark;
    final nebula = usesNebulaAppearance(context);
    final navigationBackground = nebula
        ? NebulaColors.canvas
        : highContrast
        ? theme.colorScheme.surface
        : dark
        ? const Color(0xFF1E1F20)
        : const Color(0xFFF8FAFD);
    final navigationAccent = nebula || highContrast
        ? theme.colorScheme.primary
        : dark
        ? const Color(0xFFA8C7FA)
        : const Color(0xFF174EA6);
    final copy = context.copy;
    final planner = PlannerScope.maybeOf(context) ?? desktop?.planner;
    final notice = controller.lastPhaseCompletion;
    final announceCompletion =
        _tab == 0 && notice != null && _announcedRun != notice.runId;
    if (announceCompletion) _announcedRun = notice.runId;
    final page = switch (_tab) {
      0 => FocusScreen(
        controller: controller,
        onTasks: () {
          if (planner != null) {
            showFocusTaskPicker(
              context,
              controller,
              planner,
              onManage: () => _goTo(4),
            );
          }
        },
        announceCompletion: announceCompletion,
      ),
      2 => InsightsScreen(controller: controller, onFocus: () => _goTo(0)),
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
      4 when planner != null => PlannerScreen(planner: planner, clock: false),
      _ => SettingsScreen(controller: controller),
    };
    if (desktop != null &&
        MediaQuery.sizeOf(context).width >= PomaLayout.navigationRail) {
      final extended =
          MediaQuery.sizeOf(context).width >= PomaLayout.extendedRail &&
          MediaQuery.textScalerOf(context).scale(1) < 1.5;
      final collapsed = controller.desktopPreferences.sidebarCollapsed;
      final railWidth = extended ? 216.0 : 80.0;
      final hideButton = _SidebarButton(
        collapsed: false,
        focusNode: _hideSidebarFocus,
        onPressed: _toggleSidebar,
      );
      return _desktopShortcuts(
        _DesktopSidebarScope(
          collapsed: collapsed,
          onToggle: _toggleSidebar,
          showFocus: _showSidebarFocus,
          child: Scaffold(
            body: Row(
              children: [
                ExcludeSemantics(
                  excluding: collapsed,
                  child: ExcludeFocus(
                    excluding: collapsed,
                    child: IgnorePointer(
                      ignoring: collapsed,
                      child: TweenAnimationBuilder<double>(
                        key: const Key('desktop-sidebar-transition'),
                        tween: Tween<double>(
                          begin: collapsed ? 0 : 1,
                          end: collapsed ? 0 : 1,
                        ),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                        builder: (context, value, child) => ClipRect(
                          key: const Key('desktop-sidebar'),
                          child: Align(
                            alignment: Alignment.centerRight,
                            widthFactor: value,
                            child: child,
                          ),
                        ),
                        child: SizedBox(
                          width: railWidth + 1,
                          child: Row(
                            children: [
                              SizedBox(
                                width: railWidth,
                                child: Material(
                                  color: navigationBackground,
                                  child: SafeArea(
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: PomaSpace.lg,
                                          ),
                                          child: extended
                                              ? Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        left: PomaSpace.lg,
                                                        right: PomaSpace.xs,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Poma',
                                                          style: theme
                                                              .textTheme
                                                              .headlineSmall,
                                                        ),
                                                      ),
                                                      hideButton,
                                                    ],
                                                  ),
                                                )
                                              : Column(
                                                  children: [
                                                    Text(
                                                      'P',
                                                      style: theme
                                                          .textTheme
                                                          .headlineSmall,
                                                    ),
                                                    const SizedBox(
                                                      height: PomaSpace.xs,
                                                    ),
                                                    hideButton,
                                                  ],
                                                ),
                                        ),
                                        Expanded(
                                          child: SingleChildScrollView(
                                            child: IntrinsicHeight(
                                              child: NavigationRail(
                                                extended: extended,
                                                minWidth: 80,
                                                minExtendedWidth: 216,
                                                selectedIndex:
                                                    desktopDestinationOrder
                                                        .indexOf(_tab),
                                                onDestinationSelected: (i) =>
                                                    _goTo(
                                                      desktopDestinationOrder[i],
                                                    ),
                                                destinations: [
                                                  for (final entry in [
                                                    (
                                                      Icons.timelapse,
                                                      copy.focus,
                                                    ),
                                                    (
                                                      Icons
                                                          .calendar_month_outlined,
                                                      'Calendar',
                                                    ),
                                                    (
                                                      Icons.schedule_outlined,
                                                      'Day Clock',
                                                    ),
                                                    (
                                                      Icons.bar_chart,
                                                      copy.desktopHistory,
                                                    ),
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
                              ),
                              const VerticalDivider(width: 1),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Focus(
                    focusNode: _pageFocus,
                    skipTraversal: true,
                    child: page,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final compact = Scaffold(
      body: SafeArea(bottom: false, child: page),
      bottomNavigationBar: Material(
        color: navigationBackground,
        child: SafeArea(
          top: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final labels = [
                copy.focus,
                'Calendar',
                if (desktop != null) 'Day Clock',
                copy.insights,
                copy.settings,
              ];
              final ids = desktop == null
                  ? const [0, 4, 2, 3]
                  : desktopDestinationOrder;
              final icons = [
                Icons.timelapse,
                Icons.calendar_month_outlined,
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
                                  ? navigationAccent
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                              backgroundColor: _tab == ids[i]
                                  ? navigationAccent.withValues(alpha: .12)
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
    return desktop == null ? compact : _desktopShortcuts(compact);
  }
}

class _DesktopSidebarScope extends InheritedWidget {
  const _DesktopSidebarScope({
    required this.collapsed,
    required this.onToggle,
    required this.showFocus,
    required super.child,
  });

  final bool collapsed;
  final VoidCallback onToggle;
  final FocusNode showFocus;

  static _DesktopSidebarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_DesktopSidebarScope>();

  @override
  bool updateShouldNotify(_DesktopSidebarScope oldWidget) =>
      collapsed != oldWidget.collapsed ||
      onToggle != oldWidget.onToggle ||
      showFocus != oldWidget.showFocus;
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.collapsed,
    required this.focusNode,
    required this.onPressed,
  });

  final bool collapsed;
  final FocusNode focusNode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: Key(collapsed ? 'show-sidebar' : 'hide-sidebar'),
    focusNode: focusNode,
    tooltip: collapsed ? 'Show sidebar (Ctrl+B)' : 'Hide sidebar (Ctrl+B)',
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    onPressed: onPressed,
    icon: Icon(collapsed ? Icons.chevron_right : Icons.chevron_left),
  );
}

/// Restores the app navigation from screens with their own toolbars.
class DesktopSidebarLeading extends StatelessWidget {
  const DesktopSidebarLeading({super.key});

  @override
  Widget build(BuildContext context) {
    final sidebar = _DesktopSidebarScope.maybeOf(context);
    if (sidebar == null || !sidebar.collapsed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: PomaSpace.xs),
      child: _SidebarButton(
        collapsed: true,
        focusNode: sidebar.showFocus,
        onPressed: sidebar.onToggle,
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
    final sidebar = _DesktopSidebarScope.maybeOf(context);
    Widget heading = Column(
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
    if (sidebar?.collapsed == true) {
      heading = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DesktopSidebarLeading(),
          Expanded(child: heading),
        ],
      );
    }
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
