import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../application/planner_controller.dart';
import '../domain/models.dart';
import 'day_clock_dial.dart';
import 'design_tokens.dart';
import 'planner_editor.dart';

Color taskSwatch(PlannerController planner, FocusTask task) {
  final id =
      planner.taskSchedule(task.id)?.fields['colorId'] as String? ??
      task.colorId ??
      '9';
  return clockColor(
    planner.palette.colors[id]?.background,
    const Color(0xFF3F51B5),
  );
}

Future<void> showFocusTaskPicker(
  BuildContext context,
  AppController app,
  PlannerController planner, {
  required VoidCallback onManage,
}) async {
  final manage = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (context) => AnimatedBuilder(
      animation: planner,
      builder: (context, _) {
        final tasks = app.tasks
            .where((task) => !planner.taskDone(task))
            .toList();
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Text(
                  'Choose a task',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    ListTile(
                      title: const Text('No task'),
                      leading: const Icon(Icons.timelapse_rounded),
                      selected: app.selectedTaskId == null,
                      onTap: () {
                        app.selectTask(null);
                        Navigator.pop(context, false);
                      },
                    ),
                    for (final task in tasks)
                      ListTile(
                        key: ValueKey('focus-pick-${task.id}'),
                        selected: task.id == app.selectedTaskId,
                        leading: Icon(
                          Icons.circle,
                          size: 16,
                          color: taskSwatch(planner, task),
                        ),
                        title: Text(task.title),
                        subtitle:
                            planner.taskSchedule(task.id)?.startUtc == null
                            ? null
                            : Text(
                                DateFormat.MMMd().add_jm().format(
                                  planner
                                      .taskSchedule(task.id)!
                                      .startUtc!
                                      .toLocal(),
                                ),
                              ),
                        trailing: task.id == app.selectedTaskId
                            ? const Icon(Icons.check_rounded)
                            : null,
                        onTap: () {
                          app.selectTask(task.id);
                          Navigator.pop(context, false);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Manage tasks in Calendar'),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (manage == true && context.mounted) onManage();
}

class CalendarTaskTray extends StatelessWidget {
  const CalendarTaskTray({required this.planner, super.key});
  final PlannerController planner;

  Widget _row(BuildContext context, FocusTask task) => ListTile(
    key: ValueKey('calendar-task-${task.id}'),
    contentPadding: EdgeInsets.zero,
    leading: Checkbox(
      value: planner.taskDone(task),
      activeColor: taskSwatch(planner, task),
      checkColor: clockInk(taskSwatch(planner, task)),
      semanticLabel:
          '${planner.taskDone(task) ? 'Mark incomplete' : 'Complete'} ${task.title}',
      onChanged: (_) => planner.app.toggleTask(task.id),
    ),
    title: Text(
      task.title,
      style: TextStyle(
        decoration: planner.taskDone(task) ? TextDecoration.lineThrough : null,
      ),
    ),
    onTap: () =>
        showPlannerEditor(context, planner, task: task, scheduled: false),
    trailing: PopupMenuButton<String>(
      tooltip: 'Task options for ${task.title}',
      onSelected: (action) {
        if (action == 'schedule') {
          showPlannerEditor(context, planner, task: task);
        }
        if (action == 'edit') {
          showPlannerEditor(context, planner, task: task, scheduled: false);
        }
        if (action == 'delete') planner.app.deleteTask(task.id);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'schedule', child: Text('Schedule task')),
        PopupMenuItem(value: 'edit', child: Text('Edit task')),
        PopupMenuItem(value: 'delete', child: Text('Delete task')),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tasks = planner.app.tasks
        .where((task) => planner.taskSchedule(task.id) == null)
        .toList();
    final complete = tasks.where(planner.taskDone).toList();
    return ExpansionTile(
      key: const PageStorageKey('calendar-unscheduled'),
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text('Unscheduled', style: Theme.of(context).textTheme.titleSmall),
      children: [
        for (final task in tasks.where((task) => !planner.taskDone(task)))
          _row(context, task),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: PomaSpace.sm),
            child: Text('Tasks without a time appear here.'),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('calendar-add-unscheduled'),
            onPressed: planner.ready
                ? () => showPlannerEditor(context, planner, scheduled: false)
                : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add task'),
          ),
        ),
        if (complete.isNotEmpty)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text('Completed (${complete.length})'),
            children: [for (final task in complete) _row(context, task)],
          ),
      ],
    );
  }
}
