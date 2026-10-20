import 'package:flutter/material.dart';
import '../application/app_controller.dart';
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
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (_seenAlertOpenRevision != controller.alertOpenRevision) {
      _seenAlertOpenRevision = controller.alertOpenRevision;
      _tab = 0;
    }
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (controller.alertMessage != null)
              MaterialBanner(
                content: Text(controller.alertMessage!),
                actions: [
                  TextButton(
                    onPressed: () => controller.reconcile(forceAlerts: true),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: controller.openNotificationSettings,
                    child: const Text('Settings'),
                  ),
                ],
              ),
            if (controller.clockError != null)
              MaterialBanner(
                content: Text(controller.clockError!),
                actions: [
                  TextButton(
                    onPressed: controller.reconcile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            if (controller.saveError != null)
              MaterialBanner(
                content: Text(controller.saveError!),
                actions: [
                  TextButton(
                    onPressed: controller.retrySave,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            Expanded(
              child: switch (_tab) {
                0 => FocusScreen(
                  controller: controller,
                  onTasks: () => setState(() => _tab = 1),
                ),
                1 => TasksScreen(controller: controller),
                2 => InsightsScreen(controller: controller),
                _ => SettingsScreen(controller: controller),
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (tab) => setState(() => _tab = tab),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.timelapse_outlined),
            selectedIcon: Icon(Icons.timelapse),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class ScreenHeading extends StatelessWidget {
  const ScreenHeading({
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });
  final String title;
  final String subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        ?action,
      ],
    ),
  );
}
