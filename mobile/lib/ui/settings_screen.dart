import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/app_controller.dart';
import '../application/desktop_controller.dart';
import '../application/calendar_connection_controller.dart';
import '../application/calendar_read_controller.dart';
import '../application/calendar_read_ports.dart';
import '../domain/calendar_reminders.dart';
import '../domain/calendar_preview.dart';
import '../application/local_alerts.dart';
import '../release_metadata.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'insights_screen.dart';
import 'legal_screen.dart';
import 'desktop_scope.dart';
import 'design_tokens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final copy = context.copy;
    final settings = controller.settings;
    final locked = controller.timer.controlsLocked;
    final desktop = DesktopScope.maybeOf(context);
    return PomaPage(
      key: ValueKey(
        'settings-calendar-${desktop?.calendarSettingsRevision ?? 0}',
      ),
      controller: controller,
      children: [
        ScreenHeading(title: copy.settings, subtitle: copy.settingsHelp),
        if (desktop != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Calendar'),
            subtitle: const Text(
              'Google connection, calendars, focus blocks and reminders',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () =>
                desktop.openCalendarSection(CalendarPageSection.settings),
          ),
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
        const SizedBox(height: PomaSpace.md),
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
        _Section(copy.appearance),
        Wrap(
          spacing: PomaSpace.xs,
          runSpacing: PomaSpace.xs,
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
        if (desktop != null) ...[
          _Section(copy.desktopBehavior),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(copy.closeToTray),
            subtitle: Text(copy.closeToTrayHelp),
            value: controller.desktopPreferences.closeToTray,
            onChanged: (value) => controller.updateDesktopPreferences(
              controller.desktopPreferences.copyWith(closeToTray: value),
            ),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(copy.startWithWindows),
            subtitle: Text(
              desktop.startup == 'disabledByUser' ||
                      desktop.startup == 'disabledByPolicy'
                  ? copy.startupBlocked
                  : desktop.startup == 'unavailable'
                  ? copy.startupUnavailable
                  : copy.startupHelp,
            ),
            value:
                desktop.startup == 'enabled' ||
                desktop.startup == 'enabledByPolicy',
            onChanged:
                const [
                  'unavailable',
                  'disabledByUser',
                  'disabledByPolicy',
                  'enabledByPolicy',
                ].contains(desktop.startup)
                ? null
                : desktop.changeStartup,
          ),
          if (desktop.error != null) Text(desktop.error!),
          Text(copy.quitHelp),
          TextButton(
            onPressed: desktop.showPopup,
            child: Text(copy.showCompactTimer),
          ),
          TextButton(onPressed: desktop.quit, child: Text(copy.quitPoma)),
        ],
        _Section(copy.alerts),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(copy.completionAlerts),
          subtitle: Text(
            desktop == null ? copy.alertHelp : copy.windowsAlertsHelp,
          ),
          value: controller.alertsEnabled,
          onChanged: controller.alertAvailability == null
              ? null
              : controller.setCompletionAlerts,
        ),
        Text(alertStatus(copy, controller)),
        Wrap(
          spacing: PomaSpace.xs,
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
        _Section(copy.localData),
        Text(
          desktop == null ? copy.privacyHelp : copy.windowsPrivacyHelp,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: PomaSpace.md),
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
                  message: desktop == null
                      ? copy.deleteAllHelp
                      : copy.windowsDeleteAllHelp,
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
        const SizedBox(height: PomaSpace.lg),
        TextButton.icon(
          icon: const Icon(Icons.info_outline),
          label: Text(copy.about),
          onPressed: () => showAboutDialog(
            context: context,
            applicationName: 'Poma',
            applicationVersion:
                desktop?.environment.version ?? '$pomaVersion ($pomaBuild)',
            children: [
              Text(desktop == null ? copy.aboutHelp : copy.windowsAboutHelp),
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
      if (desktop.connection != null)
        _GoogleCalendarSettings(connection: desktop.connection!),
      if (desktop.calendarData != null)
        _CalendarSelectionSettings(
          calendar: desktop.calendarData!,
          unlocked: desktop.sessionState == 'unlocked',
        ),
      if (desktop.reminders != null)
        _CalendarReminderSettings(desktop: desktop),
      const _Section('Tray privacy'),
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Event titles in tray tooltip'),
        subtitle: const Text(
          'Calendar details stay hidden while Windows is locked or its lock state is unknown.',
        ),
        value: desktop.controller.desktopPreferences.tooltipTitles,
        onChanged: (value) => desktop.controller.updateDesktopPreferences(
          desktop.controller.desktopPreferences.copyWith(tooltipTitles: value),
        ),
      ),
      _CalendarPreviewSettings(desktop: desktop),
    ],
  );
}

class _CalendarReminderSettings extends StatelessWidget {
  const _CalendarReminderSettings({required this.desktop});
  final DesktopController desktop;
  @override
  Widget build(BuildContext context) {
    final reminders = desktop.reminders!;
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
            const _Section('Meeting reminders'),
            const Text(
              'Optional, generic Windows notifications while Poma is running. Missed reminders are skipped after sleep or restart. Windows notification settings and Do Not Disturb apply.',
            ),
            SwitchListTile(
              key: const ValueKey('calendar-reminder-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable meeting reminders'),
              value: preferences.enabled,
              onChanged: enabled
                  ? (v) => reminders.update(preferences.copyWith(enabled: v))
                  : null,
            ),
            DropdownButtonFormField<int>(
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
                        reminders.update(preferences.copyWith(leadMinutes: v));
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
                  subtitle: const Text('Include in meeting reminders'),
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
            Text(switch (reminders.availability) {
              'ready' =>
                'Windows allows notification submission; delivery is not guaranteed.',
              'denied' =>
                'Windows notifications are blocked. Check Windows notification settings.',
              'unavailable' =>
                'Notifications require an installed Poma MSIX package.',
              'failed' => 'Calendar reminders need attention.',
              _ => 'Meeting reminders are off.',
            }),
            if (reminders.error != null) Text(reminders.error!),
            Wrap(
              spacing: PomaSpace.xs,
              children: [
                TextButton(
                  onPressed: reminders.retry,
                  child: const Text('Retry reminders'),
                ),
                TextButton(
                  onPressed: desktop.controller.openNotificationSettings,
                  child: const Text('Windows notification settings'),
                ),
              ],
            ),
            const Text(
              'Quit stops reminders. Poma does not wake Windows or guarantee exact delivery while asleep. Saved calendar data must be fresh; Google reminders may also notify you.',
            ),
          ],
        );
      },
    );
  }
}

class _GoogleCalendarSettings extends StatelessWidget {
  const _GoogleCalendarSettings({required this.connection});
  final CalendarConnectionController connection;
  @override
  Widget build(BuildContext context) {
    final status = switch (connection.status) {
      CalendarConnectionStatus.unconfigured =>
        'Google Calendar is not configured in this build. Timers, tasks and history still work offline.',
      CalendarConnectionStatus.restoring => 'Checking saved Google connection…',
      CalendarConnectionStatus.disconnected => 'Disconnected',
      CalendarConnectionStatus.connecting =>
        'Connecting in your default browser…',
      CalendarConnectionStatus.connected => 'Connected to Google Calendar',
      CalendarConnectionStatus.offline => 'Google connection offline',
      CalendarConnectionStatus.incompletePermissions =>
        'Read permissions incomplete',
      CalendarConnectionStatus.reconnectRequired => 'Reconnect required',
      CalendarConnectionStatus.storageError =>
        'Protected storage needs attention',
      CalendarConnectionStatus.unavailable => 'Google connection unavailable',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section('Google Calendar'),
        Text(status, key: const ValueKey('google-calendar-status')),
        if (connection.status == CalendarConnectionStatus.unconfigured)
          const Text(
            'Setup requires a Google Cloud project with Calendar API enabled, the two read permissions, a Desktop OAuth client and your tester account. Use the Windows Calendar setup guide to prepare a configured private build; connecting Google in another app does not configure Poma.',
          ),
        if (connection.message != null) Text(connection.message!),
        const SizedBox(height: PomaSpace.xs),
        const Text(
          'Calendar viewing uses read access. Choose and save calendars before event contents are loaded. Focus scheduling requires separate optional setup. Refresh credentials are protected for this Windows user; saved calendar data is unencrypted. Disconnect preserves tasks, focus history and existing Google events.',
        ),
        if (connection.configuration.audience == 'external_testing')
          const Text(
            'Private Testing: Google Calendar authorization may expire seven days after consent. Reconnect is explicit; Poma will not repeatedly open your browser.',
          ),
        Wrap(
          spacing: PomaSpace.xs,
          children: [
            FilledButton(
              key: const ValueKey('google-calendar-connect'),
              onPressed: connection.canConnect ? connection.connect : null,
              child: Text(
                connection.status == CalendarConnectionStatus.disconnected ||
                        connection.status ==
                            CalendarConnectionStatus.unconfigured
                    ? 'Connect Google'
                    : 'Reconnect',
              ),
            ),
            if (connection.status == CalendarConnectionStatus.connecting)
              TextButton(
                onPressed: connection.cancel,
                child: const Text('Cancel connection'),
              ),
            TextButton(
              key: const ValueKey('google-calendar-disconnect'),
              onPressed: connection.revoking ? null : connection.disconnect,
              child: Text(
                connection.cleanupPending && !connection.revoking
                    ? 'Retry disconnect cleanup'
                    : 'Disconnect',
              ),
            ),
          ],
        ),
        if (connection.revoking)
          const Text(
            'Disconnected locally. Finishing cleanup and a bounded Google revocation attempt…',
          ),
      ],
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
      'Calendar authorization needs attention. Use Reconnect above.',
    CalendarReadFailureKind.forbidden =>
      'This calendar is restricted. Check access, then refresh manually.',
    CalendarReadFailureKind.throttled =>
      'Google requested a pause. Refresh respects the retry delay.',
    CalendarReadFailureKind.response =>
      'Google returned an incomplete or unsupported response. Saved data is kept.',
    CalendarReadFailureKind.storage =>
      'Calendar data could not be saved or read. Repair storage and retry; changes are not confirmed.',
  };
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
          const SizedBox(height: PomaSpace.md),
          const _Section('Selected calendars'),
          if (calendar.loading) const Text('Loading saved calendar selection…'),
          if (calendar.refreshing) const Text('Refreshing calendar data…'),
          if (calendar.failure != null)
            Text(
              _message(calendar.failure!),
              key: const ValueKey('calendar-read-error'),
            ),
          if (calendar.accountKey == null && !calendar.loading)
            const Text(
              'Connect Google to choose calendars. No calendars are selected by default.',
            ),
          if (calendar.accountKey != null && calendar.selected.isEmpty)
            const Text(
              'No calendars selected. Choose calendars and save to load event contents.',
            ),
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
                  Expanded(child: Text(source.name)),
                ],
              ),
              subtitle: Text(
                '${source.accessRole} access · ${source.timeZone.isEmpty ? 'Timezone unavailable' : source.timeZone}',
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
            if (calendar.selected.contains(source.id))
              Padding(
                padding: const EdgeInsets.only(bottom: PomaSpace.xs),
                child: Builder(
                  builder: (_) {
                    final snapshot = calendar.snapshots[source.id];
                    final problem = calendar.sourceFailures[source.id];
                    if (snapshot == null) {
                      return Text(
                        problem == null
                            ? 'No verified event snapshot yet.'
                            : 'No verified event snapshot. ${_message(problem)}',
                      );
                    }
                    final difference = calendar.now.difference(
                      snapshot.succeededAt,
                    );
                    final age = difference.isNegative
                        ? 'age unavailable after a clock change'
                        : difference.inMinutes == 0
                        ? 'updated less than a minute ago'
                        : 'updated ${difference.inMinutes} min ago';
                    final fresh =
                        snapshot.fresh(calendar.now, calendar.window) &&
                        calendar.failure == null &&
                        problem == null &&
                        calendar.connection.mayRead;
                    return Text(
                      '${fresh ? 'Saved snapshot' : 'Stale saved data'} · $age\n'
                      '${snapshot.coverage.covers(calendar.window) ? 'Covers the upcoming seven dates' : 'Partial coverage; some dates or times are unavailable'}'
                      '${problem == null ? '' : '\n${_message(problem)}'}',
                    );
                  },
                ),
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
          const SizedBox(height: PomaSpace.md),
        ],
      );
    },
  );
}

class _CalendarPreviewSettings extends StatelessWidget {
  const _CalendarPreviewSettings({required this.desktop});
  final DesktopController desktop;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Section('Calendar preview'),
        const Text(
          'Fictional demo data only. This separate preview never uses your Google connection or opens a browser. It resets to disconnected after Quit.',
        ),
        const SizedBox(height: PomaSpace.sm),
        InputDecorator(
          decoration: const InputDecoration(labelText: 'Fictional scenario'),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<CalendarFixture>(
              key: const ValueKey('calendar-fixture'),
              isExpanded: true,
              value: desktop.calendar.fixture,
              items: [
                for (final fixture in CalendarFixture.values)
                  DropdownMenuItem(value: fixture, child: Text(fixture.label)),
              ],
              onChanged: (value) {
                if (value != null) desktop.calendar.select(value);
              },
            ),
          ),
        ),
        TextButton(
          onPressed: () => desktop.showPopup(preview: true),
          child: const Text('Open calendar preview'),
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
    padding: const EdgeInsets.only(top: PomaSpace.lg, bottom: PomaSpace.sm),
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
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        decoration: InputDecoration(
          helperText: widget.rounds
              ? context.copy.rounds(widget.value)
              : context.copy.minutes(widget.value),
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
