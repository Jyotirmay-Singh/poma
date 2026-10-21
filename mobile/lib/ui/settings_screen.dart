import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../application/local_alerts.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'insights_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final settings = controller.settings;
    final locked = controller.timer.controlsLocked;
    return PomaPage(
      controller: controller,
      children: [
        ScreenHeading(title: copy.settings, subtitle: copy.settingsHelp),
        _Section(copy.timing),
        _DurationControl(
          label: copy.focusDuration,
          value: settings.focusMinutes,
          max: 120,
          enabled: !locked,
          onChanged: (v) =>
              controller.updateSettings(settings.copyWith(focusMinutes: v)),
        ),
        _DurationControl(
          label: copy.shortDuration,
          value: settings.shortBreakMinutes,
          max: 60,
          enabled: !locked,
          onChanged: (v) => controller.updateSettings(
            settings.copyWith(shortBreakMinutes: v),
          ),
        ),
        _DurationControl(
          label: copy.longDuration,
          value: settings.longBreakMinutes,
          max: 120,
          enabled: !locked,
          onChanged: (v) =>
              controller.updateSettings(settings.copyWith(longBreakMinutes: v)),
        ),
        _DurationControl(
          label: copy.cycleRounds,
          value: settings.rounds,
          max: 8,
          rounds: true,
          enabled: !locked,
          onChanged: (v) =>
              controller.updateSettings(settings.copyWith(rounds: v)),
        ),
        Text(copy.durationHelp),
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(copy.strictMode),
          subtitle: Text(copy.strictHelp),
          value: settings.strictMode,
          onChanged: locked
              ? null
              : (v) =>
                    controller.updateSettings(settings.copyWith(strictMode: v)),
        ),
        _Section(copy.appearance),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in {
              'system': copy.system,
              'light': copy.light,
              'dark': copy.dark,
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: settings.appearance == entry.key,
                onSelected: (_) => controller.updateSettings(
                  settings.copyWith(appearance: entry.key),
                ),
              ),
          ],
        ),
        _Section(copy.alerts),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(copy.completionAlerts),
          subtitle: Text(copy.alertHelp),
          value: controller.alertsEnabled,
          onChanged: controller.alertAvailability == null
              ? null
              : controller.setCompletionAlerts,
        ),
        Text(alertStatus(copy, controller)),
        Wrap(
          spacing: 8,
          children: [
            if (controller.needsAlertPermission)
              TextButton(
                onPressed: () => controller.setCompletionAlerts(true),
                child: Text(copy.enableAlerts),
              ),
            if (controller.alertAvailability != null)
              TextButton(
                onPressed: controller.openNotificationSettings,
                child: Text(copy.phoneSettings),
              ),
            if (controller.alertAvailability == AlertAvailability.delayed)
              TextButton(
                onPressed: controller.requestPreciseAlerts,
                child: Text(copy.preciseAlerts),
              ),
            if (controller.alertAvailability == AlertAvailability.failed ||
                controller.alertAvailability == AlertAvailability.unavailable)
              TextButton(
                onPressed: () => controller.reconcile(forceAlerts: true),
                child: Text(copy.retryAlerts),
              ),
          ],
        ),
        _Section(copy.localData),
        Text(copy.privacyHelp, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 16),
        Text(copy.deletionHelp),
        TextButton.icon(
          icon: const Icon(Icons.delete_outline),
          label: Text(copy.clearHistory),
          onPressed: () async {
            if (await confirmDeletion(
                  context,
                  title: copy.clearHistoryTitle,
                  message: copy.clearHistoryHelp,
                ) &&
                context.mounted) {
              final success = await controller.deleteHistory();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? copy.historyDeleted : copy.deletionSaveError,
                    ),
                  ),
                );
              }
            }
          },
        ),
        TextButton.icon(
          icon: const Icon(Icons.delete_forever_outlined),
          label: Text(copy.deleteAll),
          onPressed: () async {
            if (await confirmDeletion(
                  context,
                  title: copy.deleteAllTitle,
                  message: copy.deleteAllHelp,
                ) &&
                context.mounted) {
              final success = await controller.deleteAllLocalData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? copy.localDataDeleted
                          : copy.deletionCleanupError,
                    ),
                  ),
                );
              }
            }
          },
        ),
        if (controller.deletionError != null || controller.cleanupPending) ...[
          Text(
            controller.cleanupPending
                ? copy.deletionCleanupError
                : copy.deletionSaveError,
          ),
          TextButton(
            onPressed: controller.retrySave,
            child: Text(copy.retryDeletion),
          ),
        ],
        const SizedBox(height: 24),
        TextButton.icon(
          icon: const Icon(Icons.info_outline),
          label: Text(copy.about),
          onPressed: () => showAboutDialog(
            context: context,
            applicationName: 'Poma',
            applicationVersion: '0.1.0',
            children: [
              Text(copy.aboutHelp),
              const SizedBox(height: 12),
              Text(copy.attribution),
            ],
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

class _DurationControl extends StatelessWidget {
  const _DurationControl({
    required this.label,
    required this.value,
    required this.max,
    required this.enabled,
    required this.onChanged,
    this.rounds = false,
  });
  final String label;
  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final bool rounds;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        SizedBox(width: 180, child: Text(label)),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: label,
              value: rounds
                  ? context.copy.rounds(value)
                  : context.copy.minutes(value),
              child: ExcludeSemantics(
                child: Text(
                  rounds
                      ? context.copy.rounds(value)
                      : context.copy.minutes(value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.copy.decrease(label),
                  onPressed: enabled && value > 1
                      ? () => onChanged(value - 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                const SizedBox(width: 16),
                IconButton(
                  tooltip: context.copy.increase(label),
                  onPressed: enabled && value < max
                      ? () => onChanged(value + 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}
