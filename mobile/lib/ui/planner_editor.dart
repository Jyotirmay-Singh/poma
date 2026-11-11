import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../application/planner_controller.dart';
import '../domain/calendar_data.dart';
import '../domain/models.dart';
import '../domain/planner.dart';
import 'design_tokens.dart';
import 'desktop_scope.dart';

bool _usesPlannerPane(BuildContext context, {required bool allowed}) {
  final size = MediaQuery.sizeOf(context);
  if (!allowed ||
      MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
      size.height < 620) {
    return false;
  }
  final rail = size.width >= PomaLayout.extendedRail ? 216.0 : 80.0;
  final inset = PomaLayout.pageInset(
    size.width - rail,
    maxWidth: PomaLayout.workspaceWidth,
  );
  return size.width - rail - inset * 2 - 24 - 424 >= 360;
}

Future<void> showPlannerEditor(
  BuildContext context,
  PlannerController planner, {
  DateTime? startUtc,
  DateTime? endUtc,
  FocusTask? task,
  bool scheduled = true,
  CalendarEvent? event,
  String? restoreId,
  bool series = false,
  Map<String, dynamic>? initialDraft,
  bool rememberDuration = true,
}) async {
  if (!planner.unlocked ||
      !planner.ready ||
      planner.saving ||
      planner.editorOpening) {
    return;
  }
  planner.editorOpening = true;
  final desktop = DesktopScope.maybeOf(context);
  final originDestination = desktop?.destination;
  FocusNode? opener;
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  bool? savedSchedule;
  try {
    final value =
        initialDraft ??
        (event == null
            ? await planner.beginDraft(
                startUtc: startUtc,
                endUtc: endUtc,
                task: task,
                scheduled: scheduled,
                restoreId: restoreId,
              )
            : await planner.editEvent(event, series: series));
    if (!context.mounted || value == null || !planner.unlocked) return;
    opener = FocusManager.instance.primaryFocus;
    value.putIfAbsent('rememberDuration', () => rememberDuration);
    final allowPane = const [
      4,
      5,
    ].contains(DesktopScope.maybeOf(context)?.destination);
    final pane = _usesPlannerPane(context, allowed: allowPane);
    planner.setEditorPresentation(open: true, pane: pane);
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: pane
          ? Colors.transparent
          : DialogTheme.of(context).barrierColor ??
                Theme.of(context).dialogTheme.barrierColor ??
                Colors.black54,
      themes: themes,
      traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (context) =>
          PlannerEditor(planner: planner, initial: value, allowPane: allowPane),
    );
    savedSchedule = await navigator.push(route);
    await route.completed;
  } finally {
    planner.editorOpening = false;
    planner.setEditorPresentation(open: false, pane: false);
  }
  if (savedSchedule == true &&
      originDestination == 1 &&
      desktop?.destination == 1) {
    desktop!.navigate(5);
    return;
  }
  if (context.mounted &&
      opener?.context?.mounted == true &&
      opener!.canRequestFocus) {
    opener.requestFocus();
  }
}

class PlannerEditor extends StatefulWidget {
  const PlannerEditor({
    required this.planner,
    required this.initial,
    this.allowPane = false,
    super.key,
  });
  final PlannerController planner;
  final Map<String, dynamic> initial;
  final bool allowPane;
  @override
  State<PlannerEditor> createState() => _PlannerEditorState();
}

class _PlannerEditorState extends State<PlannerEditor> {
  late final Map<String, dynamic> value = plannerJsonCopy(widget.initial);
  late final Map<String, TextEditingController> fields = {
    for (final key in [
      'title',
      'date',
      'endDate',
      'start',
      'end',
      'count',
      'until',
    ])
      key: TextEditingController(text: value[key] as String? ?? ''),
  };
  PlannerController get planner => widget.planner;
  Timer? _draftTimer;
  bool _working = false, _saved = false, _discard = false;
  String? _storageMessage;
  bool get editing => value['scheduleId'] != null;
  bool get scheduled => value['scheduled'] == true;

  @override
  void initState() {
    super.initState();
    planner.addListener(_securityChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) planner.updatePreview(value);
    });
  }

  void _securityChanged() {
    if (mounted && !planner.unlocked) {
      _draftTimer?.cancel();
      unawaited(planner.keepDraft(value));
      Navigator.of(context).pop();
    }
  }

  void changed(String key, Object? next) {
    if (_working) return;
    setState(() {
      if (key == 'date' && value['endDate'] == value['date']) {
        value['endDate'] = next;
        fields['endDate']!.text = next as String;
      }
      value[key] = next;
      if (key == 'start' || key == 'date' || key == 'zone') {
        value.remove('startChoice');
      }
      if (key == 'end' || key == 'endDate' || key == 'zone') {
        value.remove('endChoice');
      }
    });
    _draftTimer?.cancel();
    planner.updatePreview(value);
    _draftTimer = Timer(const Duration(milliseconds: 600), () async {
      final saved = await planner.keepDraft(value);
      if (mounted && !saved) {
        setState(
          () => _storageMessage =
              'Draft could not be saved on this device. Your fields are still here.',
        );
      }
    });
  }

  Future<void> _save() async {
    if (_working) return;
    _draftTimer?.cancel();
    setState(() => _working = true);
    final saved = await planner.saveDraft(value);
    if (!mounted) return;
    if (saved) {
      _saved = true;
      Navigator.of(context).pop(scheduled);
    } else {
      setState(() => _working = false);
    }
  }

  Future<void> _keep() async {
    _draftTimer?.cancel();
    if (await planner.keepDraft(value) && mounted) {
      _saved = true;
      Navigator.of(context).pop();
    }
  }

  void _cancel() {
    if (_working) return;
    _discard = true;
    Navigator.of(context).pop();
  }

  Future<void> pickDate(String key) async {
    final initial =
        DateTime.tryParse(value[key] as String? ?? '') ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1602),
      lastDate: DateTime(9998, 12, 31),
    );
    if (selected == null || !mounted) return;
    if (key == 'date' && value['endDate'] == value['date']) {
      value['endDate'] = plannerDate(selected);
      fields['endDate']!.text = value['endDate'] as String;
    }
    fields[key]!.text = plannerDate(selected);
    changed(key, plannerDate(selected));
  }

  Widget field(
    String key,
    String label, {
    bool date = false,
    bool autofocus = false,
    String? help,
  }) => TextField(
    key: ValueKey('planner-$key'),
    controller: fields[key],
    autofocus: autofocus,
    readOnly: _working,
    maxLength: key == 'title' && value['standalone'] != true ? 160 : null,
    minLines: key == 'title' ? 1 : null,
    maxLines: key == 'title' ? 3 : 1,
    textInputAction: key == 'title' && !scheduled
        ? TextInputAction.done
        : TextInputAction.next,
    onSubmitted: (_) {
      if (key == 'title' && !scheduled) _save();
    },
    decoration: InputDecoration(
      labelText: label,
      helperText: help,
      errorText: planner.errors[key],
      errorMaxLines: 4,
      suffixIcon: date
          ? IconButton(
              tooltip: 'Choose $label',
              onPressed: _working ? null : () => pickDate(key),
              icon: const Icon(Icons.calendar_today_outlined),
            )
          : null,
    ),
    onChanged: (next) => changed(key, next),
  );

  Widget _timeFields(bool largeText) {
    final children = [
      Expanded(child: field('start', 'Start time', help: '22:00 or 10:00 PM')),
      const SizedBox(width: PomaSpace.sm, height: PomaSpace.sm),
      Expanded(child: field('end', 'End time', help: '23:00 or 11:00 PM')),
    ];
    return largeText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field('start', 'Start time', help: '22:00 or 10:00 PM'),
              const SizedBox(height: PomaSpace.md),
              field('end', 'End time', help: '23:00 or 11:00 PM'),
            ],
          )
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  List<Widget> _ambiguity() => [
    for (final entry in planner.ambiguousTimes.entries) ...[
      const SizedBox(height: PomaSpace.xs),
      Text('${entry.key == 'start' ? 'Start' : 'End'} occurs twice'),
      Wrap(
        spacing: PomaSpace.xs,
        runSpacing: PomaSpace.xs,
        children: [
          for (final instant in entry.value)
            Builder(
              builder: (context) {
                final local = tz.TZDateTime.from(
                  instant,
                  tz.getLocation(value['zone'] as String),
                );
                final offset = local.timeZoneOffset.inMinutes;
                final label =
                    '${DateFormat.jm().format(local)} · UTC${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:${(offset.abs() % 60).toString().padLeft(2, '0')}';
                return ChoiceChip(
                  label: Text(label),
                  selected:
                      value['${entry.key}Choice'] == instant.toIso8601String(),
                  onSelected: _working
                      ? null
                      : (_) => changed(
                          '${entry.key}Choice',
                          instant.toIso8601String(),
                        ),
                );
              },
            ),
        ],
      ),
    ],
  ];

  Widget _destination() {
    final sources = planner.reader.sources
        .where((s) => s.accessRole == 'owner')
        .toList();
    final local = value['localOnly'] == true;
    final target = local ? 'poma-local' : value['calendarId'] as String?;
    final exists = sources.any((s) => s.id == target);
    if (editing && !local) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Destination', style: Theme.of(context).textTheme.labelLarge),
          Text(
            sources.where((s) => s.id == target).firstOrNull?.name ??
                'Original calendar unavailable',
          ),
          if (planner.errors['calendarId'] case final error?)
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!planner.preferences.syncEnabled && value['standalone'] != true)
            const Text(
              'Sync is paused. Changes will wait until scheduled-task syncing is enabled.',
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('planner-destination-$target'),
          initialValue: target == 'poma-local' || exists ? target : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Destination',
            errorText: planner.errors['calendarId'],
            errorMaxLines: 4,
          ),
          items: [
            const DropdownMenuItem(
              value: 'poma-local',
              child: Text('On this device'),
            ),
            for (final source in sources)
              DropdownMenuItem(
                value: source.id,
                enabled: planner.preferences.syncEnabled,
                child: Text(
                  source.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: _working
              ? null
              : (next) {
                  changed('localOnly', next == 'poma-local');
                  if (next != 'poma-local') {
                    changed('calendarId', next);
                    changed('accountKey', planner.accountKey);
                  }
                },
        ),
        if (!local && planner.connection.verifiedAccountLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: PomaSpace.xs),
            child: Text(
              planner.connection.verifiedAccountLabel!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (!planner.preferences.syncEnabled)
          TextButton.icon(
            onPressed: _working
                ? null
                : () async {
                    setState(() => _working = true);
                    await planner.enableSync();
                    if (!mounted) return;
                    setState(() {
                      _working = false;
                      if (planner.preferences.syncEnabled) {
                        value['localOnly'] = false;
                        value['accountKey'] = planner.accountKey;
                        value['calendarId'] ??=
                            planner.preferences.calendarId ??
                            sources.where((s) => s.primary).firstOrNull?.id;
                      }
                    });
                  },
            icon: const Icon(Icons.sync),
            label: const Text('Enable scheduled-task syncing'),
          ),
        if (!local && !editing)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Make this my default calendar'),
            value: value['makeDefault'] == true,
            onChanged: _working
                ? null
                : (next) => changed('makeDefault', next == true),
          ),
      ],
    );
  }

  Widget _recurrence() {
    if (value['recurringScope'] == 'occurrence') {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: PomaSpace.sm),
        child: Text('Changes apply to this occurrence.'),
      );
    }
    final selected = value['repeat'] as String? ?? 'none';
    final repeating = selected != 'none';
    return ExpansionTile(
      key: ValueKey('planner-repeat-${value['id']}'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: repeating,
      title: const Text('Repeat'),
      subtitle: Text(switch (selected) {
        'daily' => 'Daily',
        'weekdays' => 'Weekdays',
        'weekly' => 'Weekly',
        'monthly' => 'Monthly',
        'unsupported' => 'Existing Google recurrence',
        _ => 'Does not repeat',
      }),
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('planner-repeat-$selected'),
          initialValue: selected,
          decoration: InputDecoration(
            labelText: 'Repeat',
            errorText: planner.errors['repeat'],
            errorMaxLines: 4,
          ),
          isExpanded: true,
          items: [
            for (final entry in {
              'none': 'Does not repeat',
              'daily': 'Daily',
              'weekdays': 'Weekdays',
              'weekly': 'Weekly on selected days',
              'monthly': 'Monthly',
              if (selected == 'unsupported')
                'unsupported': 'Keep existing Google recurrence',
            }.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: _working || selected == 'unsupported'
              ? null
              : (next) => changed('repeat', next),
        ),
        if (selected == 'unsupported')
          const Padding(
            padding: EdgeInsets.only(top: PomaSpace.sm),
            child: Text(
              'Poma will preserve this recurrence. Open Google Calendar to change its repeat pattern.',
            ),
          ),
        if (repeating && selected != 'unsupported') ...[
          const SizedBox(height: PomaSpace.md),
          TextFormField(
            key: const ValueKey('planner-interval'),
            initialValue: '${value['interval'] ?? 1}',
            keyboardType: TextInputType.number,
            readOnly: _working,
            decoration: InputDecoration(
              labelText: 'Every',
              suffixText: selected == 'monthly'
                  ? 'months'
                  : selected == 'weekly'
                  ? 'weeks'
                  : 'days',
            ),
            onChanged: (next) => changed('interval', int.tryParse(next) ?? 0),
          ),
          if (selected == 'weekly')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: PomaSpace.sm),
              child: Wrap(
                spacing: PomaSpace.xs,
                runSpacing: PomaSpace.xs,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(
                        DateFormat.E().format(DateTime(2026, 11, 9 + day - 1)),
                      ),
                      selected: (value['weekdays'] as List? ?? []).contains(
                        day,
                      ),
                      onSelected: _working
                          ? null
                          : (chosen) {
                              final days = List<int>.from(
                                value['weekdays'] as List? ?? [],
                              );
                              if (chosen) {
                                days.add(day);
                              } else {
                                days.remove(day);
                              }
                              changed('weekdays', days);
                            },
                    ),
                ],
              ),
            ),
          if (selected == 'monthly')
            const Padding(
              padding: EdgeInsets.only(top: PomaSpace.xs),
              child: Text(
                'Repeats on this day of the month. Shorter months skip dates they do not contain.',
              ),
            ),
          const SizedBox(height: PomaSpace.md),
          DropdownButtonFormField<String>(
            key: ValueKey('planner-ending-${value['ending']}'),
            initialValue: value['ending'] as String? ?? 'never',
            decoration: const InputDecoration(labelText: 'Ends'),
            items: const [
              DropdownMenuItem(value: 'never', child: Text('Never')),
              DropdownMenuItem(value: 'date', child: Text('On a date')),
              DropdownMenuItem(
                value: 'count',
                child: Text('After a number of occurrences'),
              ),
            ],
            isExpanded: true,
            onChanged: _working ? null : (next) => changed('ending', next),
          ),
          if (value['ending'] == 'date')
            Padding(
              padding: const EdgeInsets.only(top: PomaSpace.md),
              child: field('until', 'Last occurrence date', date: true),
            ),
          if (value['ending'] == 'count')
            Padding(
              padding: const EdgeInsets.only(top: PomaSpace.md),
              child: field('count', 'Occurrence count'),
            ),
          if (value['recurringScope'] == 'series')
            const Padding(
              padding: EdgeInsets.only(top: PomaSpace.sm),
              child: Text('Changes apply to the entire series.'),
            ),
          _repeatPreview(),
        ],
      ],
    );
  }

  Widget _repeatPreview() {
    try {
      final event = planner.preview(value);
      if (event == null) return const SizedBox.shrink();
      final zone = tz.getLocation(value['zone'] as String);
      final recurrence = PlannerRecurrence(
        repeat: PlannerRepeat.values.byName(value['repeat'] as String),
        interval: value['interval'] as int? ?? 1,
        weekdays: List<int>.from(value['weekdays'] as List? ?? []),
        count: value['ending'] == 'count'
            ? int.parse(value['count'] as String)
            : null,
        until: value['ending'] == 'date'
            ? CalendarDate.parse(value['until'] as String)
            : null,
      );
      final start = event.startUtc!, end = start.add(const Duration(days: 370));
      final window = CalendarWindow(
        first: CalendarDate(start.year, start.month, start.day),
        until: CalendarDate(end.year, end.month, end.day),
        startUtc: start,
        endUtc: end,
      );
      final schedule = PlannerSchedule(
        id: 'repeat-preview',
        fields: {
          'summary': 'Preview',
          'start': {'dateTime': start.toIso8601String(), 'timeZone': zone.name},
          'end': {
            'dateTime': event.endUtc!.toIso8601String(),
            'timeZone': zone.name,
          },
          'recurrence': recurrence.rule(zone),
        },
      );
      final dates = plannerOccurrences(schedule, window)
          .take(4)
          .map(
            (event) => DateFormat.MMMd().add_jm().format(
              tz.TZDateTime.from(event.startUtc!, zone),
            ),
          )
          .join(', ');
      return Padding(
        padding: const EdgeInsets.only(top: PomaSpace.sm),
        child: Text(
          'Next occurrences · $dates',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _options() => ExpansionTile(
    key: ValueKey('planner-options-${planner.errors.containsKey('zone')}'),
    initiallyExpanded: planner.errors.containsKey('zone'),
    tilePadding: EdgeInsets.zero,
    title: const Text('More options'),
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show as busy'),
        value: value['busy'] != false,
        onChanged: _working ? null : (next) => changed('busy', next),
      ),
      const SizedBox(height: PomaSpace.sm),
      DropdownButtonFormField<String>(
        key: ValueKey('planner-color-${value['colorId']}'),
        initialValue: value['colorId'] as String? ?? '',
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Event color',
          errorText: planner.errors['colorId'],
        ),
        items: [
          const DropdownMenuItem(value: '', child: Text('Calendar default')),
          if (value['colorId'] != null &&
              planner.reader.palette?.colors.containsKey(value['colorId']) !=
                  true)
            DropdownMenuItem(
              value: value['colorId'] as String,
              child: const Text('Existing event color'),
            ),
          for (final e
              in planner.reader.palette?.colors.entries ??
                  const <MapEntry<String, CalendarEventColor>>[])
            DropdownMenuItem(
              value: e.key,
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color(
                        0xff000000 |
                            int.parse(
                              e.value.background.substring(1),
                              radix: 16,
                            ),
                      ),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: PomaSpace.sm),
                  Text('Google color ${e.key}'),
                ],
              ),
            ),
        ],
        onChanged: _working
            ? null
            : (next) => changed('colorId', next == '' ? null : next),
      ),
      const SizedBox(height: PomaSpace.md),
      DropdownButtonFormField<String>(
        key: ValueKey('planner-zone-${value['zone']}'),
        initialValue: value['zone'] as String?,
        decoration: InputDecoration(
          labelText: 'Timezone',
          errorText: planner.errors['zone'],
          errorMaxLines: 4,
        ),
        isExpanded: true,
        items: [
          for (final zone in planner.time.zones)
            DropdownMenuItem(
              value: zone,
              child: Text(zone, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: _working ? null : (next) => changed('zone', next),
      ),
      const SizedBox(height: PomaSpace.md),
    ],
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: planner,
    builder: (context, _) {
      final size = MediaQuery.sizeOf(context),
          scale = MediaQuery.textScalerOf(context).scale(1);
      final sidePane = _usesPlannerPane(context, allowed: widget.allowPane);
      if (planner.editorPane != sidePane) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            planner.setEditorPresentation(open: true, pane: sidePane);
          }
        });
      }
      return PopScope(
        canPop: !_working,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop && !_saved) {
            _draftTimer?.cancel();
            if (_discard) {
              unawaited(planner.discardDraft(value['id'] as String));
            } else {
              unawaited(planner.keepDraft(value));
            }
          }
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                _save,
            const SingleActivator(LogicalKeyboardKey.escape): _cancel,
            const SingleActivator(LogicalKeyboardKey.keyN, control: true):
                () {},
          },
          child: Align(
            alignment: sidePane ? Alignment.centerRight : Alignment.center,
            child: Dialog(
              alignment: sidePane ? Alignment.centerRight : Alignment.center,
              insetPadding: EdgeInsets.symmetric(
                horizontal: sidePane
                    ? math.max(24, (size.width - 216 - 1120) / 2)
                    : 16,
                vertical: 16,
              ),
              child: SizedBox(
                key: const ValueKey('planner-editor-panel'),
                width: sidePane ? 424 : 560,
                height: math.min(size.height * .9, scheduled ? 760 : 340),
                child: Padding(
                  padding: const EdgeInsets.all(PomaSpace.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              editing
                                  ? value['standalone'] == true
                                        ? 'Edit event'
                                        : 'Edit task'
                                  : 'Add task',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Cancel',
                            onPressed: _working ? null : _cancel,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: PomaSpace.sm),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: PomaSpace.sm),
                              field(
                                'title',
                                value['standalone'] == true
                                    ? 'Event title'
                                    : 'Task title',
                                autofocus: true,
                              ),
                              if (value['standalone'] != true)
                                SwitchListTile(
                                  key: const ValueKey('planner-scheduled'),
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Schedule'),
                                  value: scheduled,
                                  onChanged: _working
                                      ? null
                                      : (next) => changed('scheduled', next),
                                ),
                              if (scheduled) ...[
                                const SizedBox(height: PomaSpace.md),
                                field(
                                  'date',
                                  value['allDay'] == true
                                      ? 'Start date'
                                      : 'Date',
                                  date: true,
                                ),
                                if (value['allDay'] != true) ...[
                                  const SizedBox(height: PomaSpace.md),
                                  _timeFields(scale >= 1.5),
                                  ..._ambiguity(),
                                ],
                                if (value['allDay'] == true ||
                                    value['endDate'] != value['date'] ||
                                    planner.errors['end'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: PomaSpace.md,
                                    ),
                                    child: field(
                                      'endDate',
                                      value['allDay'] == true
                                          ? 'End date (exclusive)'
                                          : 'End date',
                                      date: true,
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: _working
                                        ? null
                                        : () => pickDate('endDate'),
                                    child: const Text('Change end date'),
                                  ),
                                if (value['zone'] != null)
                                  Text(
                                    'Timezone · ${value['zone']}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                if (planner.preview(value) case final preview?)
                                  Text(
                                    'Duration · ${preview.endUtc!.difference(preview.startUtc!).inMinutes} minutes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                if (planner.errors['zone'] != null)
                                  Text(
                                    planner.errors['zone']!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                const SizedBox(height: PomaSpace.md),
                                _destination(),
                                const SizedBox(height: PomaSpace.sm),
                                _recurrence(),
                                _options(),
                                if (value['hasGuests'] == true)
                                  const Text(
                                    'Changes to the meeting title or time can notify its guests.',
                                  ),
                              ],
                              if (_storageMessage != null)
                                Text(_storageMessage!),
                              if (planner.message != null &&
                                  planner.errors.isEmpty)
                                Semantics(
                                  liveRegion: true,
                                  child: Text(planner.message!),
                                ),
                              const SizedBox(height: PomaSpace.md),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: PomaSpace.xs,
                        runSpacing: PomaSpace.xs,
                        children: [
                          TextButton(
                            onPressed: _working ? null : _keep,
                            child: const Text('Keep draft'),
                          ),
                          TextButton(
                            onPressed: _working ? null : _cancel,
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            key: const ValueKey('planner-save'),
                            onPressed: _working ? null : _save,
                            child: Text(_working ? 'Saving…' : 'Save'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  @override
  void dispose() {
    _draftTimer?.cancel();
    planner.removeListener(_securityChanged);
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }
}
