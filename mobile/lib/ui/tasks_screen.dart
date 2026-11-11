import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import 'app_shell.dart';
import 'copy.dart';
import 'desktop_scope.dart';
import 'calendar_screen.dart';
import 'design_tokens.dart';
import 'planner_editor.dart';
import 'planner_screen.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => PomaPage(
    controller: controller,
    children: [
      ScreenHeading(
        title: context.copy.tasks,
        subtitle: context.copy.taskHelp,
        action: FilledButton.icon(
          key: const ValueKey('tasks-add-task'),
          onPressed: () => _taskDialog(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(context.copy.addTask),
        ),
      ),
      if (DesktopScope.maybeOf(context)?.planner case final planner?)
        PlannerOperations(planner: planner),
      if (controller.tasks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: PomaSpace.xxl),
          child: Column(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: PomaSpace.md),
              Text(
                context.copy.emptyTasks,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PomaSpace.xs),
              Text(context.copy.emptyTasksHelp, textAlign: TextAlign.center),
            ],
          ),
        ),
      if (controller.tasks.isNotEmpty &&
          controller.tasks.every((task) => _done(context, task))) ...[
        Semantics(header: true, child: Text(context.copy.allDone)),
        const SizedBox(height: PomaSpace.xs),
        Text(context.copy.allDoneHelp),
      ],
      for (final task in controller.tasks.where(
        (task) => !_done(context, task),
      ))
        _taskRow(context, task),
      if (controller.tasks.any((task) => _done(context, task))) ...[
        const SizedBox(height: PomaSpace.lg),
        Semantics(
          header: true,
          child: Text(
            context.copy.completed,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: PomaSpace.xs),
        for (final task in controller.tasks.where(
          (task) => _done(context, task),
        ))
          _taskRow(context, task),
      ],
    ],
  );

  bool _done(BuildContext context, FocusTask task) =>
      DesktopScope.maybeOf(context)?.planner?.taskDone(task) ?? task.done;

  Widget _taskRow(BuildContext context, FocusTask task) {
    final planner = DesktopScope.maybeOf(context)?.planner;
    final done = _done(context, task);
    final occurrence = planner?.taskOccurrence(task.id);
    final schedule = planner?.taskSchedule(task.id);
    final recurring = schedule?.recurring == true;
    final scheduledTime = occurrence?.startUtc ?? schedule?.startUtc;
    final selected = task.id == controller.selectedTaskId && !done;
    return Padding(
      padding: const EdgeInsets.only(bottom: PomaSpace.xs),
      child: Material(
        borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
            : Colors.transparent,
        child: Semantics(
          selected: selected,
          child: ListTile(
            key: ValueKey('task-${task.id}'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: PomaSpace.xs,
            ),
            titleAlignment: ListTileTitleAlignment.top,
            leading: Checkbox(
              value: done,
              semanticLabel: done
                  ? context.copy.markIncomplete(task.title)
                  : context.copy.markComplete(task.title),
              onChanged: recurring && occurrence == null
                  ? null
                  : (_) => controller.toggleTask(task.id),
            ),
            title: Text(
              task.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: scheduledTime != null
                ? Text(
                    '${DateFormat.yMMMd().add_jm().format(scheduledTime.toLocal())} · ${planner!.status(schedule!)}${done ? ' · Completed' : ''}',
                  )
                : recurring
                ? const Text('No upcoming occurrence')
                : done
                ? null
                : Text(
                    selected
                        ? context.copy.selectedTask
                        : context.copy.selectTask,
                  ),
            onTap: done ? null : () => controller.selectTask(task.id),
            trailing: PopupMenuButton<String>(
              tooltip: context.copy.taskOptions(task.title),
              onSelected: (action) {
                if (action == 'schedule') {
                  final desktop = DesktopScope.maybeOf(context);
                  if (desktop != null) {
                    showFocusBlockDialog(
                      context,
                      desktop,
                      taskTitle: task.title,
                      taskId: task.id,
                    );
                  }
                }
                if (action == 'plan') {
                  _taskDialog(context, task: task, scheduled: true);
                }
                if (action == 'edit') _taskDialog(context, task: task);
                if (action == 'delete') _deleteTask(context, task);
              },
              itemBuilder: (_) => [
                if (DesktopScope.maybeOf(context) != null && !task.done)
                  const PopupMenuItem(
                    value: 'schedule',
                    child: Text('Schedule focus block'),
                  ),
                if (DesktopScope.maybeOf(context)?.planner != null)
                  const PopupMenuItem(
                    value: 'plan',
                    child: Text('Schedule task'),
                  ),
                PopupMenuItem(value: 'edit', child: Text(context.copy.rename)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    DesktopScope.maybeOf(
                              context,
                            )?.planner?.taskSchedule(task.id) !=
                            null
                        ? 'Delete task and calendar event'
                        : context.copy.delete,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTask(BuildContext context, FocusTask task) async {
    final planner = DesktopScope.maybeOf(context)?.planner;
    final schedule = planner?.taskSchedule(task.id);
    if (planner == null || schedule == null) {
      controller.deleteTask(task.id);
      return;
    }
    await planner.deleteTask(task.id);
    if (!context.mounted ||
        controller.tasks.any((item) => item.id == task.id)) {
      return;
    }
    showPlannerDeletionUndo(
      context,
      planner,
      schedule.id,
      'Task and schedule removed',
    );
  }

  Future<void> _taskDialog(
    BuildContext context, {
    FocusTask? task,
    bool scheduled = false,
  }) async {
    final planner = DesktopScope.maybeOf(context)?.planner;
    if (planner != null) {
      await showPlannerEditor(
        context,
        planner,
        task: task,
        scheduled: scheduled,
      );
      return;
    }
    final title = await showDialog<String>(
      context: context,
      builder: (_) => _TaskDialog(initial: task?.title),
    );
    if (title == null) return;
    if (task == null) {
      controller.addTask(title);
    } else {
      controller.editTask(task.id, title);
    }
  }
}

Future<void> showNewTaskDialog(
  BuildContext context,
  AppController controller,
) => TasksScreen(controller: controller)._taskDialog(context);

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.initial});
  final String? initial;
  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initial ?? '',
  );
  final _formKey = GlobalKey<FormState>();
  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.pop(context, _input.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.initial == null ? context.copy.addTask : context.copy.renameTask,
    ),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _input,
        key: const Key('task-name'),
        autofocus: true,
        maxLength: 160,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: context.copy.taskName),
        validator: (value) => value == null || value.trim().isEmpty
            ? context.copy.enterTask
            : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.copy.cancel),
      ),
      FilledButton(onPressed: _submit, child: Text(context.copy.saveTask)),
    ],
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}
