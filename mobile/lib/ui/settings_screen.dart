import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/app_controller.dart';
import '../application/desktop_controller.dart';
import '../application/calendar_connection_controller.dart';
import '../application/calendar_read_controller.dart';
import '../application/calendar_read_ports.dart';
import '../domain/calendar_reminders.dart';
import '../application/local_alerts.dart';
import '../release_metadata.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'insights_screen.dart';
import 'legal_screen.dart';
import 'desktop_scope.dart';
import 'design_tokens.dart';
import 'google_account_section.dart';
import 'calendar_settings_heading.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final settings = controller.settings;
    final locked = controller.timer.controlsLocked;
    final desktop = DesktopScope.maybeOf(context);
    final googleConnection = desktop?.connection;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return PomaPage(
      key: ValueKey(
        'settings-calendar-${desktop?.calendarSettingsRevision ?? 0}',
      ),
      controller: controller,
      children: [
        ScreenHeading(title: copy.settings),
        if (desktop?.error != null) Text(desktop!.error!),
        if (desktop != null && googleConnection != null)
          GoogleAccountSection(
            connection: googleConnection,
            unlocked: desktop.sessionState == 'unlocked',
            onManageCalendars: () =>
                desktop.openCalendarSection(CalendarPageSection.settings),
          ),
        _SettingsSection(copy.timing, divided: googleConnection != null),
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
        Text(
          copy.durationHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: PomaSpace.xs),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(copy.strictMode),
          subtitle: Text(
            desktop == null ? copy.strictHelp : copy.windowsStrictHelp,
          ),
          value: settings.strictMode,
          onChanged: locked
              ? null
              : (v) =>
                    controller.updateSettings(settings.copyWith(strictMode: v)),
        ),
        _SettingsSection(copy.appearance),
        Wrap(
          spacing: PomaSpace.xs,
          runSpacing: PomaSpace.xs,
          children: [
            for (final (value, label, icon) in [
              ('system', copy.system, Icons.brightness_auto_outlined),
              ('light', copy.light, Icons.light_mode_outlined),
              ('dark', copy.dark, Icons.dark_mode_outlined),
            ])
              ChoiceChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                showCheckmark: false,
                selected: settings.appearance == value,
                side: BorderSide(
                  color: settings.appearance == value
                      ? colors.primary
                      : colors.outlineVariant,
                ),
                onSelected: (_) => controller.updateSettings(
                  settings.copyWith(appearance: value),
                ),
              ),
          ],
        ),
        _SettingsSection(copy.alerts),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(copy.completionAlerts, style: theme.textTheme.bodyMedium),
          subtitle: Text(
            alertStatus(copy, controller),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          value: controller.alertsEnabled,
          onChanged: controller.alertAvailability == null
              ? null
              : controller.setCompletionAlerts,
        ),
        Wrap(
          spacing: PomaSpace.xs,
          runSpacing: PomaSpace.xxs,
          children: [
            if (controller.needsAlertPermission)
              TextButton(
                onPressed: () => controller.setCompletionAlerts(true),
                child: Text(copy.enableAlerts),
              ),
            if (controller.alertAvailability != null)
              TextButton(
                onPressed: controller.openNotificationSettings,
                child: Text(notificationSettingsLabel(context)),
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
        _SettingsSection(copy.localData),
        Text(
          desktop == null ? copy.privacyHelp : copy.windowsPrivacyHelp,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: PomaSpace.sm),
        Wrap(
          spacing: PomaSpace.xs,
          runSpacing: PomaSpace.xs,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(copy.clearHistory),
              onPressed: () async {
                if (await confirmDeletion(
                      context,
                      title: copy.clearHistoryTitle,
                      message:
                          '${copy.clearHistoryHelp}\n\n${copy.deletionHelp}',
                    ) &&
                    context.mounted) {
                  final success = await controller.deleteHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? copy.historyDeleted
                              : copy.deletionSaveError,
                        ),
                      ),
                    );
                  }
                }
              },
            ),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: colors.error),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(copy.deleteAll),
              onPressed: () async {
                if (await confirmDeletion(
                      context,
                      title: copy.deleteAllTitle,
                      message:
                          '${desktop == null ? copy.deleteAllHelp : copy.windowsDeleteAllHelp}\n\n${copy.deletionHelp}',
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
          ],
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
        const Divider(height: PomaSpace.xl),
        Wrap(
          key: const ValueKey('settings-footer'),
          spacing: PomaSpace.xxs,
          runSpacing: PomaSpace.xxs,
          children: [
            TextButton(
              child: Text(copy.about),
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: 'Poma',
                applicationVersion:
                    desktop?.environment.version ?? '$pomaVersion ($pomaBuild)',
                children: [
                  Text(
                    desktop == null ? copy.aboutHelp : copy.windowsAboutHelp,
                  ),
                  const SizedBox(height: PomaSpace.sm),
                  Text(copy.attribution),
                  const SizedBox(height: PomaSpace.sm),
                  const SelectableText('$pomaOwner\n$pomaSupport'),
                ],
              ),
            ),
            for (final document in {
              'Privacy policy': desktop == null
                  ? 'assets/legal/privacy.txt'
                  : 'assets/legal/privacy-windows.txt',
              'Third-party notices': 'assets/legal/notices.txt',
            }.entries)
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        LegalScreen(title: document.key, asset: document.value),
                  ),
                ),
                child: Text(document.key),
              ),
          ],
        ),
      ],
    );
  }
}

/// Shared calendar controls live on the Windows Calendar page.
class CalendarPreferences extends StatelessWidget {
  const CalendarPreferences({required this.desktop, super.key});
  final DesktopController desktop;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (desktop.connection != null) _GoogleCalendarSettings(desktop: desktop),
      if (desktop.calendarData != null)
        _CalendarSelectionSettings(
          calendar: desktop.calendarData!,
          unlocked: desktop.sessionState == 'unlocked',
        ),
    ],
  );
}

class CalendarNotificationPreferences extends StatelessWidget {
  const CalendarNotificationPreferences({required this.desktop, super.key});
  final DesktopController desktop;
  @override
  Widget build(BuildContext context) {
    final reminders = desktop.reminders;
    if (reminders == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: reminders,
      builder: (context, _) {
        final preferences = reminders.preferences;
        final enabled =
            desktop.sessionState == 'unlocked' &&
            desktop.calendarData?.activeLease != null &&
            desktop.calendarData?.saving != true &&
            !reminders.saving;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CalendarSettingsHeading('Notifications'),
            SwitchListTile(
              key: const ValueKey('calendar-reminder-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Meeting reminders'),
              subtitle: const Text('Notify me while Poma is open.'),
              value: preferences.enabled,
              onChanged: enabled
                  ? (v) => reminders.update(preferences.copyWith(enabled: v))
                  : null,
            ),
            if (preferences.enabled) ...[
              const SizedBox(height: PomaSpace.xs),
              DropdownButtonFormField<int>(
                isExpanded: true,
                style: Theme.of(context).textTheme.bodyMedium,
                initialValue: preferences.leadMinutes,
                key: ValueKey('reminder-lead-${preferences.leadMinutes}'),
                decoration: const InputDecoration(
                  labelText: 'Remind before meeting',
                ),
                items: [
                  for (final minutes in CalendarReminderPreferences.leads)
                    DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes minutes'),
                    ),
                ],
                onChanged: enabled
                    ? (v) {
                        if (v != null) {
                          reminders.update(
                            preferences.copyWith(leadMinutes: v),
                          );
                        }
                      }
                    : null,
              ),
              if (desktop.sessionState == 'unlocked')
                for (final source in desktop.calendarData!.sources.where(
                  (s) => desktop.calendarData!.selected.contains(s.id),
                ))
                  CheckboxListTile(
                    key: ValueKey('calendar-reminder-source-${source.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(source.name),
                    value: preferences.calendars.contains(source.id),
                    onChanged: enabled
                        ? (v) {
                            final ids = {...preferences.calendars};
                            if (v == true) {
                              ids.add(source.id);
                            } else {
                              ids.remove(source.id);
                            }
                            reminders.update(
                              preferences.copyWith(calendars: ids),
                            );
                          }
                        : null,
                  ),
              if (desktop.calendarData?.selected.isEmpty == true)
                const Text('Select a calendar above to receive reminders.'),
              if (const {
                'denied',
                'unavailable',
                'failed',
              }.contains(reminders.availability))
                Text(switch (reminders.availability) {
                  'denied' => 'Windows notifications are blocked.',
                  'unavailable' => 'Install Poma to use meeting reminders.',
                  _ => 'Meeting reminders need attention.',
                }, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (reminders.error != null)
              Text(
                reminders.error!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (preferences.enabled || reminders.error != null)
              Wrap(
                spacing: PomaSpace.xs,
                runSpacing: PomaSpace.xs,
                children: [
                  if (reminders.error != null ||
                      reminders.availability == 'failed')
                    TextButton(
                      onPressed: reminders.retry,
                      child: const Text('Retry reminders'),
                    ),
                  TextButton(
                    onPressed: desktop.controller.openNotificationSettings,
                    child: const Text('Notification settings'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}

class _GoogleCalendarSettings extends StatelessWidget {
  const _GoogleCalendarSettings({required this.desktop});
  final DesktopController desktop;
  @override
  Widget build(BuildContext context) {
    final connection = desktop.connection!;
    final copy = context.copy;
    final status = connection.revoking
        ? copy.googleSigningOut
        : connection.cleanupPending
        ? copy.googleAccountAttention
        : switch (connection.status) {
            CalendarConnectionStatus.unconfigured => copy.googleAccountSetup,
            CalendarConnectionStatus.restoring => copy.googleAccountChecking,
            CalendarConnectionStatus.disconnected =>
              copy.googleAccountSignedOut,
            CalendarConnectionStatus.connecting => copy.googleSigningIn,
            CalendarConnectionStatus.connected => copy.googleAccountConnected,
            CalendarConnectionStatus.offline => copy.googleAccountOffline,
            CalendarConnectionStatus.incompletePermissions =>
              copy.googleAccountPermissions,
            CalendarConnectionStatus.reconnectRequired =>
              copy.googleAccountReconnect,
            CalendarConnectionStatus.storageError ||
            CalendarConnectionStatus.unavailable => copy.googleAccountAttention,
          };
    final identity = Row(
      children: [
        ExcludeSemantics(
          child: Image.asset(
            'assets/branding/google-g.png',
            width: 24,
            height: 24,
          ),
        ),
        const SizedBox(width: PomaSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                connection.verifiedAccountLabel ?? copy.googleAccount,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                status,
                key: const ValueKey('google-calendar-status'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
    final action = TextButton(
      key: const ValueKey('calendar-account-settings'),
      onPressed: () => desktop.navigate(3),
      child: const Text('Account settings'),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, action],
          );
        }
        return Row(
          children: [
            Expanded(child: identity),
            action,
          ],
        );
      },
    );
  }
}

class _CalendarSelectionSettings extends StatefulWidget {
  const _CalendarSelectionSettings({
    required this.calendar,
    required this.unlocked,
  });
  final CalendarReadController calendar;
  final bool unlocked;
  @override
  State<_CalendarSelectionSettings> createState() =>
      _CalendarSelectionSettingsState();
}

class _CalendarSelectionSettingsState
    extends State<_CalendarSelectionSettings> {
  Set<String> _draft = {};
  String? _selection;
  String _message(CalendarReadFailure failure) => switch (failure.kind) {
    CalendarReadFailureKind.cancelled => 'Refresh cancelled.',
    CalendarReadFailureKind.network =>
      'Google could not be reached. Saved data may have changed.',
    CalendarReadFailureKind.authorization =>
      'Review your Google connection in Account settings.',
    CalendarReadFailureKind.forbidden =>
      'This calendar is restricted. Check access, then refresh manually.',
    CalendarReadFailureKind.throttled =>
      'Google requested a pause. Refresh respects the retry delay.',
    CalendarReadFailureKind.response =>
      'Google returned an incomplete or unsupported response. Saved data is kept.',
    CalendarReadFailureKind.storage =>
      'Calendar data could not be saved or read. Repair storage and retry; changes are not confirmed.',
  };

  String _sourceDetails(String id, String accessRole) {
    final calendar = widget.calendar;
    final access = switch (accessRole) {
      'owner' => 'Owner',
      'writer' => 'Shared calendar',
      'reader' => 'Read only',
      _ => 'Availability only',
    };
    if (!calendar.selected.contains(id)) return access;
    final snapshot = calendar.snapshots[id];
    final problem = calendar.sourceFailures[id];
    if (snapshot == null) {
      return '$access · ${problem == null ? 'Waiting for data' : _message(problem)}';
    }
    final difference = calendar.now.difference(snapshot.succeededAt);
    final age = difference.isNegative
        ? 'Update time unavailable'
        : difference.inMinutes == 0
        ? 'Updated just now'
        : 'Updated ${difference.inMinutes} min ago';
    final fresh =
        snapshot.fresh(calendar.now, calendar.window) &&
        calendar.failure == null &&
        problem == null &&
        calendar.connection.mayRead;
    return '$access · ${fresh ? '' : 'Refresh needed · '}$age'
        '${snapshot.coverage.covers(calendar.window) ? '' : '\nSome dates are unavailable.'}'
        '${problem == null ? '' : '\n${_message(problem)}'}';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.calendar,
    builder: (context, _) {
      final calendar = widget.calendar;
      final sorted = calendar.selected.toList()..sort();
      final signature = '${calendar.accountKey}/${sorted.join('\u0000')}';
      if (_selection != signature) {
        _selection = signature;
        _draft = {...calendar.selected};
      }
      if (!widget.unlocked) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: PomaSpace.sm),
          child: Text(
            'Calendar details are hidden while Windows is locked or its lock state is unknown.',
            key: ValueKey('calendar-selection-hidden'),
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CalendarSettingsHeading('Selected calendars'),
          Text(
            'Show in Calendar and Day Clock.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (calendar.loading) const Text('Loading saved calendar selection…'),
          if (calendar.refreshing) const Text('Refreshing calendar data…'),
          if (calendar.failure != null)
            Text(
              _message(calendar.failure!),
              key: const ValueKey('calendar-read-error'),
            ),
          if (calendar.accountKey == null && !calendar.loading)
            const Text('Sign in from Account settings to choose calendars.'),
          if (calendar.accountKey != null && calendar.selected.isEmpty)
            const Text('Choose calendars, then save your selection.'),
          for (final source in calendar.sources) ...[
            CheckboxListTile(
              key: ValueKey('calendar-source-${source.id}'),
              contentPadding: EdgeInsets.zero,
              title: Row(
                children: [
                  if (source.backgroundColor != null) ...[
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(
                          0xff000000 |
                              int.parse(
                                source.backgroundColor!.substring(1),
                                radix: 16,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: PomaSpace.xs),
                  ],
                  Expanded(
                    child: Tooltip(
                      message: source.timeZone.isEmpty
                          ? 'Timezone unavailable'
                          : source.timeZone,
                      child: Text(source.name),
                    ),
                  ),
                ],
              ),
              subtitle: Text(
                _sourceDetails(source.id, source.accessRole),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              value: _draft.contains(source.id),
              onChanged: calendar.canSelect && source.readable
                  ? (value) => setState(() {
                      if (value == true) {
                        _draft.add(source.id);
                      } else {
                        _draft.remove(source.id);
                      }
                    })
                  : null,
            ),
          ],
          if (calendar.accountKey != null)
            Wrap(
              spacing: PomaSpace.xs,
              runSpacing: PomaSpace.xs,
              children: [
                FilledButton(
                  key: const ValueKey('calendar-save-selection'),
                  onPressed: calendar.canSelect
                      ? () => calendar.select({..._draft})
                      : null,
                  child: Text(
                    calendar.saving ? 'Saving selection…' : 'Save selection',
                  ),
                ),
                TextButton(
                  key: const ValueKey('calendar-refresh'),
                  onPressed:
                      calendar.connection.mayRead &&
                          !calendar.loading &&
                          !calendar.saving
                      ? calendar.retry
                      : null,
                  child: const Text('Refresh calendars'),
                ),
              ],
            ),
        ],
      );
    },
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection(this.title, {this.divided = true});
  final String title;
  final bool divided;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (divided) const Divider(height: PomaSpace.xl),
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      const SizedBox(height: PomaSpace.xs),
    ],
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
  Widget build(BuildContext context) {
    final valueText = rounds
        ? context.copy.rounds(value)
        : context.copy.minutes(value);
    final valueStyle = Theme.of(context).textTheme.titleSmall!;
    final metrics = TextPainter(
      text: TextSpan(text: valueText, style: valueStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final valueWidth = metrics.width < 64 ? 64.0 : metrics.width + PomaSpace.xs;
    metrics.dispose();
    final desktop = DesktopScope.maybeOf(context) != null;
    final controlsWidth = desktop ? 220.0 : valueWidth + 96;
    final controls = desktop
        ? _DesktopNumber(
            label: label,
            value: value,
            max: max,
            enabled: enabled,
            rounds: rounds,
            onChanged: onChanged,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: context.copy.decrease(label),
                onPressed: enabled && value > 1
                    ? () => onChanged(value - 1)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              SizedBox(
                width: valueWidth,
                child: Semantics(
                  label: label,
                  value: valueText,
                  child: ExcludeSemantics(
                    child: Text(
                      valueText,
                      textAlign: TextAlign.center,
                      style: valueStyle,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: context.copy.increase(label),
                onPressed: enabled && value < max
                    ? () => onChanged(value + 1)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PomaSpace.xs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline =
              constraints.maxWidth >= controlsWidth + 160 &&
              MediaQuery.textScalerOf(context).scale(1) <= 1.4;
          if (inline) {
            return Row(
              children: [
                Expanded(child: Text(label)),
                const SizedBox(width: PomaSpace.md),
                controls,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(label),
              const SizedBox(height: PomaSpace.xs),
              Align(alignment: Alignment.centerRight, child: controls),
            ],
          );
        },
      ),
    );
  }
}

class _DesktopNumber extends StatefulWidget {
  const _DesktopNumber({
    required this.label,
    required this.value,
    required this.max,
    required this.enabled,
    required this.rounds,
    required this.onChanged,
  });
  final String label;
  final int value, max;
  final bool enabled, rounds;
  final ValueChanged<int> onChanged;
  @override
  State<_DesktopNumber> createState() => _DesktopNumberState();
}

class _DesktopNumberState extends State<_DesktopNumber> {
  late final _text = TextEditingController(text: '${widget.value}');
  final _focus = FocusNode();
  bool _invalid = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(_blur);
  }

  void _blur() {
    if (!_focus.hasFocus) _apply();
  }

  void _apply() {
    final value = int.tryParse(_text.text);
    if (!widget.enabled) return;
    final invalid = value == null || value < 1 || value > widget.max;
    setState(() => _invalid = invalid);
    if (!invalid && value != widget.value) widget.onChanged(value);
  }

  @override
  void didUpdateWidget(covariant _DesktopNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focus.hasFocus || !widget.enabled) {
      _text.text = '${widget.value}';
      _invalid = false;
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Semantics(
      label: widget.label,
      child: TextField(
        key: ValueKey('desktop-number-${widget.label}'),
        controller: _text,
        focusNode: _focus,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.end,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          suffixText: widget.rounds
              ? context.copy.roundsUnit(widget.value)
              : context.copy.minutesUnit,
          errorText: _invalid
              ? context.copy.desktopNumberRange(widget.max)
              : null,
          errorMaxLines: 3,
        ),
        onSubmitted: (_) => _apply(),
      ),
    ),
  );
  @override
  void dispose() {
    _focus.removeListener(_blur);
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }
}
