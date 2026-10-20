import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import 'app_shell.dart';
import 'theme.dart';
import 'timer_dial.dart';

class FocusScreen extends StatelessWidget {
  const FocusScreen({
    required this.controller,
    required this.onTasks,
    super.key,
  });
  final AppController controller;
  final VoidCallback onTasks;
  @override
  Widget build(BuildContext context) {
    final timer = controller.timer;
    final timerRevision = timer.revision;
    final colors = Theme.of(context).colorScheme;
    final accent = timer.phase == FocusPhase.focus
        ? colors.primary
        : (Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF81D4CF)
              : pomaTeal);
    final today = controller.todaySummary;
    final minutes = (today?.focusSeconds ?? 0) ~/ 60;
    final task = controller.selectedTask;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const ScreenHeading(
          title: 'One thing at a time.',
          subtitle: 'Make a little room for focus.',
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final phase in FocusPhase.values)
              ChoiceChip(
                label: Text(phase.label),
                selected: timer.phase == phase,
                showCheckmark: false,
                onSelected: timer.controlsLocked
                    ? null
                    : (_) => controller.selectPhase(
                        phase,
                        expectedRevision: timerRevision,
                      ),
                visualDensity: VisualDensity.standard,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Center(
          child: TimerDial(timer: timer, color: accent),
        ),
        const SizedBox(height: 10),
        Semantics(
          label:
              '${timer.displayedRounds} of ${controller.settings.rounds} focus rounds completed',
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < controller.settings.rounds; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < timer.completedRounds
                            ? accent
                            : colors.outlineVariant,
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Text(
                  '${timer.displayedRounds}/${controller.settings.rounds}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 26),
        _TimerControls(controller: controller, accent: accent),
        const SizedBox(height: 12),
        Text(
          timer.controlsLocked
              ? 'Strict mode is on. Stay with this session.'
              : timer.status == RunStatus.paused
              ? 'Take a breath. Continue when you’re ready.'
              : timer.phase == FocusPhase.focus
              ? 'A small start is still a start.'
              : 'Step away. Give your mind a moment.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 28),
        Material(
          color: colors.primary.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTasks,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: accent),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task == null ? 'Choose one thing' : 'Your next focus',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task?.title ??
                              'Add a task to give this time a purpose.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 26),
        const Divider(),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 8,
          spacing: 16,
          children: [
            Text('Today', style: Theme.of(context).textTheme.titleSmall),
            Text(
              controller.summaryError ??
                  (today == null
                      ? 'Loading today’s focus…'
                      : '${today.count} ${today.count == 1 ? 'session' : 'sessions'}     $minutes min focused'),
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            if (controller.summaryError != null)
              TextButton(
                onPressed: controller.loadSummaries,
                child: const Text('Retry totals'),
              ),
          ],
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
    final primary = FilledButton.icon(
      key: const Key('timer-toggle'),
      style: FilledButton.styleFrom(backgroundColor: accent),
      onPressed: timer.controlsLocked
          ? null
          : () async {
              if (displayedStatus == RunStatus.ready &&
                  controller.needsAlertPermission) {
                final enable = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Know when your time is up'),
                    content: const Text(
                      'Allow completion alerts while your phone is locked or you use another app. Your phone controls sound and delivery.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Not now'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Enable alerts'),
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
        timer.status == RunStatus.running
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
      ),
      label: Text(
        timer.controlsLocked
            ? 'In progress'
            : switch (timer.status) {
                RunStatus.running => 'Pause',
                RunStatus.paused => 'Resume',
                _ => 'Start',
              },
      ),
    );
    final reset = IconButton.filledTonal(
      tooltip: 'Reset timer',
      onPressed: timer.controlsLocked
          ? null
          : () => controller.resetTimer(expectedRevision: revision),
      icon: const Icon(Icons.replay_rounded),
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
    );
    final skip = IconButton.filledTonal(
      tooltip: 'Skip to next phase',
      onPressed: timer.controlsLocked
          ? null
          : () => controller.skipTimer(expectedRevision: revision),
      icon: const Icon(Icons.skip_next_rounded),
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
            constraints.maxWidth < 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              primary,
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [reset, const SizedBox(width: 24), skip],
              ),
            ],
          );
        }
        return Row(
          children: [
            reset,
            const SizedBox(width: 12),
            Expanded(child: primary),
            const SizedBox(width: 12),
            skip,
          ],
        );
      },
    );
  }
}
