import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../application/local_alerts.dart';
import '../domain/models.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'theme.dart';
import 'timer_dial.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({
    required this.controller,
    required this.onTasks,
    this.announceCompletion = false,
    super.key,
  });
  final AppController controller;
  final VoidCallback onTasks;
  final bool announceCompletion;
  @override
  Widget build(BuildContext context) {
    final timer = controller.timer;
    final revision = timer.revision;
    final colors = Theme.of(context).colorScheme;
    final copy = context.copy;
    final accent = timer.phase == FocusPhase.focus
        ? colors.primary
        : (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF81D4CF)
              : pomaTeal);
    final today = controller.todaySummary;
    final activeFocus =
        timer.phase == FocusPhase.focus && timer.status != RunStatus.ready;
    final completion = controller.lastPhaseCompletion;
    return PomaPage(
      controller: controller,
      children: [
        ScreenHeading(title: copy.focus),
        if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
          InputDecorator(
            decoration: InputDecoration(labelText: copy.timerPhase),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<FocusPhase>(
                value: timer.phase,
                isExpanded: true,
                items: [
                  for (final phase in FocusPhase.values)
                    DropdownMenuItem(
                      value: phase,
                      child: Text(phaseName(copy, phase)),
                    ),
                ],
                onChanged: timer.controlsLocked
                    ? null
                    : (phase) {
                        if (phase != null) {
                          controller.selectPhase(
                            phase,
                            expectedRevision: revision,
                          );
                        }
                      },
              ),
            ),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final phase in FocusPhase.values)
                ChoiceChip(
                  label: Text(phaseName(copy, phase)),
                  selected: timer.phase == phase,
                  showCheckmark: false,
                  onSelected: timer.controlsLocked
                      ? null
                      : (_) => controller.selectPhase(
                          phase,
                          expectedRevision: revision,
                        ),
                ),
            ],
          ),
        const SizedBox(height: 18),
        Center(
          child: TimerDial(timer: timer, color: accent),
        ),
        const SizedBox(height: 10),
        Text(
          copy.roundsComplete(
            timer.displayedRounds,
            controller.settings.rounds,
          ),
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (completion != null)
          Semantics(
            key: ValueKey('completion-${completion.runId}'),
            liveRegion: announceCompletion,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                completion.phase == FocusPhase.focus
                    ? copy.focusComplete
                    : copy.breakComplete,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        _TimerControls(controller: controller, accent: accent),
        const SizedBox(height: 12),
        Text(
          timer.controlsLocked
              ? copy.strictHint
              : timer.status == RunStatus.paused
              ? copy.pausedHint
              : timer.status == RunStatus.running
              ? copy.runningHint
              : copy.readyHint,
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        if (activeFocus) ...[
          Text(
            copy.currentFocus,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(controller.activeTaskTitle ?? copy.unassignedFocus),
          const SizedBox(height: 16),
        ],
        Semantics(
          button: true,
          child: Material(
            color: colors.primary.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTasks,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.selectedTask == null
                                ? copy.chooseTask
                                : copy.nextFocus,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(controller.selectedTask?.title ?? copy.noTask),
                        ],
                      ),
                    ),
                    const ExcludeSemantics(child: Icon(Icons.chevron_right)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (controller.alertAvailability != null) ...[
          Text(
            alertStatus(copy, controller),
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          if (!controller.needsAlertPermission &&
              controller.alertAvailability == AlertAvailability.denied)
            TextButton(
              onPressed: controller.openNotificationSettings,
              child: Text(copy.phoneSettings),
            ),
          if (controller.alertAvailability == AlertAvailability.failed ||
              controller.alertAvailability == AlertAvailability.unavailable)
            TextButton(
              onPressed: () => controller.reconcile(forceAlerts: true),
              child: Text(copy.retryAlerts),
            ),
          const SizedBox(height: 12),
        ],
        const Divider(),
        Semantics(
          header: true,
          child: Text(
            copy.today,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          (controller.summaryError != null ? copy.totalsReadError : null) ??
              (today == null
                  ? copy.loadingTotals
                  : copy.todayTotals(today.count, today.focusSeconds ~/ 60)),
        ),
        if (controller.summaryError != null)
          TextButton(
            onPressed: controller.loadSummaries,
            child: Text(copy.retryTotals),
          ),
      ],
    );
  }
}

class _TimerControls extends StatelessWidget {
  const _TimerControls({required this.controller, required this.accent});
  final AppController controller;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final timer = controller.timer;
    final revision = timer.revision;
    final displayedStatus = timer.status;
    final copy = context.copy;
    final primary = FilledButton.icon(
      key: const Key('timer-toggle'),
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      onPressed: timer.controlsLocked
          ? null
          : () async {
              if (displayedStatus == RunStatus.ready &&
                  controller.needsAlertPermission) {
                final enable = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    scrollable: true,
                    title: Text(copy.alertPromptTitle),
                    content: Text(copy.alertPromptHelp),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(copy.notNow),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(copy.enableAlerts),
                      ),
                    ],
                  ),
                );
                if (enable == null) return;
                await controller.setCompletionAlerts(enable);
              }
              await controller.toggleTimer(
                expectedRevision: revision,
                displayedStatus: displayedStatus,
              );
            },
      icon: Icon(
        timer.status == RunStatus.running ? Icons.pause : Icons.play_arrow,
      ),
      label: Text(
        timer.controlsLocked
            ? copy.inProgress
            : switch (timer.status) {
                RunStatus.running => copy.pause,
                RunStatus.paused => copy.resume,
                RunStatus.ready => switch (timer.phase) {
                  FocusPhase.focus => copy.startFocus,
                  FocusPhase.shortBreak => copy.startShortBreak,
                  FocusPhase.longBreak => copy.startLongBreak,
                },
              },
      ),
    );
    final reset = IconButton.filledTonal(
      tooltip: copy.resetTimer,
      onPressed: timer.controlsLocked
          ? null
          : () => controller.resetTimer(expectedRevision: revision),
      icon: const Icon(Icons.replay),
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
    );
    final skip = IconButton.filledTonal(
      tooltip: copy.skipPhase,
      onPressed: timer.controlsLocked
          ? null
          : () => controller.skipTimer(expectedRevision: revision),
      icon: const Icon(Icons.skip_next),
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
    );
    return FocusTraversalGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          primary,
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [reset, const SizedBox(width: 24), skip],
          ),
        ],
      ),
    );
  }
}
