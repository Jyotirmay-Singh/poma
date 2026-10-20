import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import 'app_shell.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day - 6 + i),
    );
    final minutes = days
        .map(
          (day) =>
              controller
                  .sessionsOn(day)
                  .fold(0, (sum, session) => sum + session.focusSeconds) ~/
              60,
        )
        .toList();
    final largest = minutes.fold(1, (max, value) => value > max ? value : max);
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      children: [
        const ScreenHeading(
          title: 'Small sessions add up.',
          subtitle: 'Your focus, one day at a time.',
        ),
        Text(
          '${minutes.reduce((a, b) => a + b)} min',
          style: Theme.of(
            context,
          ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Focused over the last 7 days',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 200,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: Semantics(
                    label:
                        '${MaterialLocalizations.of(context).formatMediumDate(days[i])}, ${minutes[i]} minutes focused',
                    child: ExcludeSemantics(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${minutes[i]}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: minutes[i] == 0
                                  ? 3
                                  : 110 * minutes[i] / largest,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: i == 6
                                    ? colors.primary
                                    : colors.primary.withValues(alpha: .25),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              const [
                                'M',
                                'T',
                                'W',
                                'T',
                                'F',
                                'S',
                                'S',
                              ][days[i].weekday - 1],
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 18),
        Text('Recent sessions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (controller.sessions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Finish your first focus session to see it here.\nSkipped sessions are not counted.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.6),
            ),
          ),
        for (final session in controller.sessions.take(20))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.check_circle_outline_rounded,
              color: colors.primary,
            ),
            title: Text(session.taskTitle ?? 'Focus session'),
            subtitle: Text(
              '${MaterialLocalizations.of(context).formatMediumDate(session.endedAt.toLocal())} at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(session.endedAt.toLocal()))}',
            ),
            trailing: Text('${session.focusSeconds ~/ 60} min'),
          ),
        if (controller.sessions.length > 20)
          Text(
            'Showing your latest 20 sessions. All sessions are saved locally.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
      ],
    );
  }
}
