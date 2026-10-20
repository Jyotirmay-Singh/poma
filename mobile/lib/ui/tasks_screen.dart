import 'package:flutter/material.dart';
import '../application/app_controller.dart';
import '../domain/models.dart';
import 'app_shell.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({required this.controller, super.key});
  final AppController controller;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
    children: [
      const ScreenHeading(
        title: 'Give your time a purpose.',
        subtitle: 'Choose a task. Keep the list simple.',
      ),
      FilledButton.icon(
        onPressed: () => _taskDialog(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add a task'),
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
              const Text(
                'What would you like to work on?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start with one small, achievable task.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      for (final task in controller.tasks.where((task) => !task.done))
        _taskRow(context, task),
      if (controller.tasks.any((task) => task.done)) ...[
        const SizedBox(height: 24),
        const Text('Completed', style: TextStyle(fontWeight: FontWeight.w600)),
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
        child: ListTile(
          contentPadding: const EdgeInsets.only(left: 0, right: 0),
          leading: Checkbox(
            value: task.done,
            semanticLabel: 'Complete ${task.title}',
            onChanged: (_) => controller.toggleTask(task.id),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              decoration: task.done ? TextDecoration.lineThrough : null,
            ),
          ),
          subtitle: selected ? const Text('Selected for focus') : null,
          onTap: task.done ? null : () => controller.selectTask(task.id),
          trailing: PopupMenuButton<String>(
            tooltip: 'Options for ${task.title}',
            onSelected: (action) {
              if (action == 'edit') _taskDialog(context, task: task);
              if (action == 'delete') controller.deleteTask(task.id);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
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
    title: Text(widget.initial == null ? 'Add a task' : 'Rename task'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _input,
        autofocus: true,
        maxLength: 160,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'What will you work on?'),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Enter a task name.' : null,
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Save task')),
    ],
  );
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }
}
