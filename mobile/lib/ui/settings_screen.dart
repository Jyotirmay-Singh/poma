import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import 'app_shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final locked = controller.timer.controlsLocked;
    void update(TimerSettings next) => controller.updateSettings(next);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      children: [
        const ScreenHeading(
          title: 'Find your rhythm.',
          subtitle: 'A little structure. Room to make it yours.',
        ),
        _DurationControl(
          label: 'Focus duration',
          value: settings.focusMinutes,
          max: 120,
          enabled: !locked,
          onChanged: (v) => update(settings.copyWith(focusMinutes: v)),
        ),
        _DurationControl(
          label: 'Short break duration',
          value: settings.shortBreakMinutes,
          max: 60,
          enabled: !locked,
          onChanged: (v) => update(settings.copyWith(shortBreakMinutes: v)),
        ),
        _DurationControl(
          label: 'Long break duration',
          value: settings.longBreakMinutes,
          max: 120,
          enabled: !locked,
          onChanged: (v) => update(settings.copyWith(longBreakMinutes: v)),
        ),
        _DurationControl(
          label: 'Focus rounds before a long break',
          value: settings.rounds,
          max: 8,
          unit: 'rounds',
          enabled: !locked,
          onChanged: (v) => update(settings.copyWith(rounds: v)),
        ),
        const SizedBox(height: 8),
        Text(
          'Duration changes apply to your next session.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        const Divider(),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Strict mode'),
          subtitle: const Text(
            'Lock pause, reset, and skip until the current session finishes.',
          ),
          value: settings.strictMode,
          onChanged: locked
              ? null
              : (v) => update(settings.copyWith(strictMode: v)),
        ),
        const Divider(),
        const SizedBox(height: 18),
        Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in const {
              'system': 'System',
              'light': 'Light',
              'dark': 'Dark',
            }.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: settings.appearance == entry.key,
                onSelected: (_) =>
                    update(settings.copyWith(appearance: entry.key)),
              ),
          ],
        ),
        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 20),
        Text(
          'Your space stays yours.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Tasks, settings, and history stay on this phone. Poma excludes this data from automatic backups. There is no automatic recovery if you uninstall Poma or lose the phone. No account, ads, or tracking.',
          style: TextStyle(height: 1.5),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.notifications_off_outlined, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Background alerts are not available yet. Your elapsed session is recovered when you return.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => showAboutDialog(
            context: context,
            applicationName: 'Poma',
            applicationVersion: '0.1.0',
            children: const [
              Text(
                'An offline Pomodoro companion for Android and iOS. Inspired by the MIT-licensed Pomatez project.',
              ),
              SizedBox(height: 12),
              Text(
                'Pomatez © 2024 Roldan Montilla Jr.\nSee THIRD_PARTY_NOTICES.md in the source distribution.',
              ),
            ],
          ),
          icon: const Icon(Icons.info_outline_rounded),
          label: const Text('About Poma'),
        ),
      ],
    );
  }
}

class _DurationControl extends StatelessWidget {
  const _DurationControl({
    required this.label,
    required this.value,
    required this.max,
    required this.enabled,
    required this.onChanged,
    this.unit = 'min',
  });
  final String label;
  final int value;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;
  final String unit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 4,
      children: [
        SizedBox(
          width: 180,
          child: Text(label, style: const TextStyle(fontSize: 15)),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Decrease $label',
              onPressed: enabled && value > 1
                  ? () => onChanged(value - 1)
                  : null,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text(
              '$value $unit',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            IconButton(
              tooltip: 'Increase $label',
              onPressed: enabled && value < max
                  ? () => onChanged(value + 1)
                  : null,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
          ],
        ),
      ],
    ),
  );
}
