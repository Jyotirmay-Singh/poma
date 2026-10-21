import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import 'app_shell.dart';
import 'copy.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => PomaPage(
    controller: controller,
    children: [
      ScreenHeading(title: context.copy.tasks, subtitle: context.copy.taskHelp),
      FilledButton.icon(
        onPressed: () => _taskDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(context.copy.addTask),
      ),
      const SizedBox(height: 24),
      if (controller.tasks.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                context.copy.emptyTasks,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(context.copy.emptyTasksHelp, textAlign: TextAlign.center),
            ],
          ),
        ),
      if (controller.tasks.isNotEmpty &&
          controller.tasks.every((task) => task.done)) ...[
        Semantics(header: true, child: Text(context.copy.allDone)),
        const SizedBox(height: 8),
        Text(context.copy.allDoneHelp),
      ],
      for (final task in controller.tasks.where((task) => !task.done))
        _taskRow(context, task),
      if (controller.tasks.any((task) => task.done)) ...[
        const SizedBox(height: 24),
        Semantics(
          header: true,
          child: Text(
            context.copy.completed,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 8),
        for (final task in controller.tasks.where((task) => task.done))
          _taskRow(context, task),
      ],
    ],
  );

  Widget _taskRow(BuildContext context, FocusTask task) {
    final selected = task.id == controller.selectedTaskId && !task.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        borderRadius: BorderRadius.circular(14),
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .08)
            : Colors.transparent,
        child: Semantics(
          selected: selected,
          child: ListTile(
            key: ValueKey('task-${task.id}'),
            contentPadding: const EdgeInsets.only(left: 0, right: 0),
            leading: Checkbox(
              value: task.done,
              semanticLabel: task.done
                  ? context.copy.markIncomplete(task.title)
                  : context.copy.markComplete(task.title),
              onChanged: (_) => controller.toggleTask(task.id),
            ),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.done ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: task.done
                ? null
                : Text(
                    selected
                        ? context.copy.selectedTask
                        : context.copy.selectTask,
                  ),
            onTap: task.done ? null : () => controller.selectTask(task.id),
            trailing: PopupMenuButton<String>(
              tooltip: context.copy.taskOptions(task.title),
              onSelected: (action) {
                if (action == 'edit') _taskDialog(context, task: task);
                if (action == 'delete') controller.deleteTask(task.id);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(context.copy.rename)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(context.copy.delete),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _taskDialog(BuildContext context, {FocusTask? task}) async {
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
