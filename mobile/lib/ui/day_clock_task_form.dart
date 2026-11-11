import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/app_controller.dart';
import '../application/day_clock_controller.dart';
import '../domain/calendar_event_creation.dart';
import '../domain/focus_blocks.dart' show CalendarWriteCapability;
import 'day_clock_dial.dart';
import 'design_tokens.dart';

class DayClockTaskForm extends StatefulWidget {
  const DayClockTaskForm({required this.clock, required this.app, super.key});
  final DayClockController clock;
  final AppController app;
  @override
  State<DayClockTaskForm> createState() => _DayClockTaskFormState();
}

class _DayClockTaskFormState extends State<DayClockTaskForm> {
  late final CalendarEventDraft draft;
  late final Map<String, TextEditingController> fields;
  bool _closing = false;
  bool get frozen =>
      widget.clock.operation != null ||
      widget.clock.creationBusy ||
      widget.clock.reader.connection.creationUpgradeActive;
  @override
  void initState() {
    super.initState();
    draft = widget.clock.draft ?? widget.clock.beginDraft();
    fields = {
      for (final entry in {
        'title': draft.title,
        'start-date': draft.startDate,
        'end-date': draft.endDate,
        'start-time': draft.startTime,
        'end-time': draft.endTime,
      }.entries)
        entry.key: TextEditingController(text: entry.value),
    };
  }

  void changed(VoidCallback update) {
    if (frozen) return;
    update();
    widget.clock.touchDraft();
  }

  Widget field(
    String label,
    String key,
    ValueChanged<String> update, {
    String? hint,
    bool autofocus = false,
  }) => TextField(
    key: ValueKey('day-clock-$key'),
    controller: fields[key],
    readOnly: frozen,
    autofocus: autofocus,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: label,
      helperText: hint,
      errorText: key == 'title' ? widget.clock.errors['title'] : null,
      errorMaxLines: 6,
    ),
    onChanged: (value) => changed(() => update(value)),
  );
  Widget endpoint(bool start) {
    final key = start ? 'start' : 'end';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        field(
          start ? 'Start date' : 'End date',
          '$key-date',
          (v) => start ? draft.startDate = v : draft.endDate = v,
          hint: 'YYYY-MM-DD',
        ),
        const SizedBox(height: PomaSpace.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: field(
                start ? 'Start time' : 'End time',
                '$key-time',
                (v) => start ? draft.startTime = v : draft.endTime = v,
                hint: 'h:mm',
              ),
            ),
            const SizedBox(width: PomaSpace.xs),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<bool>(
                style: Theme.of(context).textTheme.bodyMedium,
                key: ValueKey('day-clock-$key-period'),
                initialValue: start ? draft.startPm : draft.endPm,
                decoration: InputDecoration(
                  labelText: start ? 'Start AM/PM' : 'End AM/PM',
                ),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: false, child: Text('AM')),
                  DropdownMenuItem(value: true, child: Text('PM')),
                ],
                onChanged: frozen
                    ? null
                    : (v) {
                        if (v != null) {
                          changed(
                            () => start ? draft.startPm = v : draft.endPm = v,
                          );
                        }
                      },
              ),
            ),
          ],
        ),
        if (widget.clock.errors[key] case final error?)
          Padding(
            padding: const EdgeInsets.only(top: PomaSpace.xs),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget savedDialog(CalendarCreateOperation op) {
    final clock = widget.clock, theme = Theme.of(context), intent = op.intent;
    final source = clock.reader.sources
        .where((s) => s.id == intent.calendarId)
        .firstOrNull;
    final swatch = clock.reader.palette?.colors[intent.colorId];
    String endpoint(DateTime utc, int offset) =>
        '${DateFormat('yyyy-MM-dd, h:mm a').format(utc.add(Duration(minutes: offset)))} '
        '(${dayClockOffset(offset)})';
    final notice = clock
        .savedDisplayMessage(op)
        .replaceFirst(RegExp(r'^Saved(?: to Google Calendar)?\.\s*'), '');
    return AlertDialog(
      key: const ValueKey('day-clock-task-form'),
      insetPadding: const EdgeInsets.all(PomaSpace.md),
      scrollable: true,
      title: Semantics(
        liveRegion: true,
        header: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
            const SizedBox(width: PomaSpace.sm),
            const Expanded(child: Text('Saved to Google Calendar')),
          ],
        ),
      ),
      content: SizedBox(
        key: const ValueKey('day-clock-saved-summary'),
        width: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(intent.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: PomaSpace.md),
            Text('Starts: ${endpoint(intent.startUtc, intent.startOffset)}'),
            const SizedBox(height: PomaSpace.xs),
            Text('Ends: ${endpoint(intent.endUtc, intent.endOffset)}'),
            const SizedBox(height: PomaSpace.xs),
            Text('Timezone: ${intent.zone}'),
            Text(
              'Duration: ${intent.endUtc.difference(intent.startUtc).inMinutes} minutes',
            ),
            const Divider(height: PomaSpace.xl),
            Text(
              'Google account: ${clock.draftAccountLabel ?? 'Original account'}',
            ),
            Text(
              'Destination calendar: ${source?.name ?? intent.calendarId}${source?.primary == true ? ' (primary)' : ''}',
            ),
            const SizedBox(height: PomaSpace.sm),
            Row(
              children: [
                if (swatch != null) ...[
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: clockColor(
                        swatch.background,
                        theme.colorScheme.outline,
                      ),
                      border: Border.all(color: theme.colorScheme.onSurface),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: PomaSpace.xs),
                ],
                Expanded(
                  child: Text(
                    intent.colorId == null
                        ? 'Event colour: Calendar default'
                        : 'Event colour: Google colour ${intent.colorId}',
                  ),
                ),
              ],
            ),
            Text('Show this time as: ${intent.busy ? 'Busy' : 'Free'}'),
            if (notice.isNotEmpty) ...[
              const SizedBox(height: PomaSpace.md),
              Semantics(liveRegion: true, child: Text(notice)),
            ],
            if (clock.validationMessage != null &&
                clock.validationMessage!.contains(
                  'browser could not be opened',
                ))
              Semantics(
                liveRegion: true,
                child: Text(clock.validationMessage!),
              ),
          ],
        ),
      ),
      actions: [
        if (op.event?.eventUrl != null)
          TextButton(
            onPressed: () => clock.openSaved(op),
            child: const Text('Open event in Google Calendar'),
          ),
        TextButton(
          key: const ValueKey('day-clock-saved-show'),
          onPressed: clock.revealing || clock.creationBusy
              ? null
              : () async {
                  final shown = await clock.revealSaved(op);
                  if (!mounted) return;
                  if (shown) {
                    Navigator.pop(context);
                  }
                },
          child: Text(clock.revealing ? 'Showing…' : 'Show on Day Clock'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.clock,
    builder: (context, _) {
      final clock = widget.clock, theme = Theme.of(context);
      final highContrast = MediaQuery.highContrastOf(context);
      if (!clock.unlocked || !identical(clock.draft, draft)) {
        if (!_closing) {
          _closing = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && ModalRoute.of(context)?.isCurrent == true) {
              Navigator.pop(context);
            }
          });
        }
        return const SizedBox.shrink();
      }
      final owned = clock.destinations;
      final target = owned.any((s) => s.id == draft.calendarId)
          ? draft.calendarId
          : null;
      final palette = clock.reader.palette?.colors ?? {};
      final split =
          MediaQuery.sizeOf(context).width >= 900 &&
          MediaQuery.textScalerOf(context).scale(1) < 1.5;
      final task = widget.app.selectedTask;
      final op = clock.operation;
      if (op?.state == CalendarCreationState.saved) return savedDialog(op!);
      final granting = const {
        CalendarWriteCapability.granting,
        CalendarWriteCapability.verifying,
      }.contains(clock.reader.connection.creationCapability);
      return AlertDialog(
        key: const ValueKey('day-clock-task-form'),
        insetPadding: const EdgeInsets.all(PomaSpace.md),
        scrollable: true,
        title: const Text('Add task'),
        content: SizedBox(
          width: 640,
          child: FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  clock.creation == null
                      ? 'Your draft is kept while Poma runs. Google saving will be available in a later update.'
                      : 'Keep draft stores this on your device. Add to Google Calendar schedules it.',
                ),
                const SizedBox(height: PomaSpace.md),
                Text(
                  'Google account: ${clock.draftAccountLabel ?? 'Not connected'}',
                ),
                if (draft.accountKey == null &&
                    clock.reader.connection.verifiedAccountKey != null)
                  TextButton(
                    onPressed: clock.bindUnboundDraft,
                    child: const Text(
                      'Use the connected account for this draft',
                    ),
                  ),
                if (draft.accountKey !=
                    clock.reader.connection.verifiedAccountKey)
                  const Text(
                    'This draft belongs to a different account. Reconnect that account or discard the draft.',
                  ),
                const SizedBox(height: PomaSpace.md),
                field(
                  'Title',
                  'title',
                  (v) => draft.title = v,
                  autofocus: true,
                ),
                if (task != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: frozen
                          ? null
                          : () => changed(() {
                              draft.title = task.title;
                              draft.taskId = task.id;
                              fields['title']!.text = task.title;
                            }),
                      child: const Text('Use selected task title'),
                    ),
                  ),
                const SizedBox(height: PomaSpace.md),
                Text('Time and duration', style: theme.textTheme.titleSmall),
                const SizedBox(height: PomaSpace.sm),
                if (split)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: endpoint(true)),
                      const SizedBox(width: PomaSpace.md),
                      Expanded(child: endpoint(false)),
                    ],
                  )
                else ...[
                  endpoint(true),
                  const SizedBox(height: PomaSpace.md),
                  endpoint(false),
                ],
                const SizedBox(height: PomaSpace.md),
                Text('Timezone: ${clock.timezoneLabel}'),
                const SizedBox(height: PomaSpace.xs),
                Text(
                  clock.review == null
                      ? 'Duration: check the task to calculate elapsed time.'
                      : 'Duration: ${clock.review!.endUtc.difference(clock.review!.startUtc).inMinutes} minutes',
                ),
                if (clock.review case final review?)
                  Text(
                    '${dayClockOffset(review.startOffset)} at start; ${dayClockOffset(review.endOffset)} at end.',
                  ),
                const SizedBox(height: PomaSpace.md),
                const Divider(height: PomaSpace.md),
                const SizedBox(height: PomaSpace.sm),
                if (op != null) ...[
                  const Text('Destination calendar'),
                  Text(
                    owned
                            .where((s) => s.id == draft.calendarId)
                            .firstOrNull
                            ?.name ??
                        draft.calendarId ??
                        'Original calendar unavailable',
                  ),
                ] else
                  DropdownButtonFormField<String>(
                    style: theme.textTheme.bodyMedium,
                    key: ValueKey('day-clock-destination-$target'),
                    initialValue: target,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Destination calendar',
                      errorText: clock.errors['calendar'],
                      errorMaxLines: 6,
                    ),
                    hint: Text(
                      owned.isEmpty
                          ? 'No owned calendars available'
                          : 'Choose an owned calendar',
                    ),
                    items: [
                      for (final s in owned)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            '${s.name}${s.primary ? ' (primary)' : ''}',
                            maxLines: 2,
                          ),
                        ),
                    ],
                    onChanged: owned.isEmpty || frozen
                        ? null
                        : (v) => changed(() => draft.calendarId = v),
                  ),
                const SizedBox(height: PomaSpace.md),
                if (op != null)
                  Row(
                    children: [
                      if (palette[draft.colorId] case final swatch?) ...[
                        Container(
                          width: 20,
                          height: 20,
                          color: clockColor(
                            swatch.background,
                            theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: PomaSpace.xs),
                      ],
                      Flexible(
                        child: Text(
                          draft.colorId == null
                              ? 'Event colour: Calendar default'
                              : 'Event colour: Google colour ${draft.colorId}',
                        ),
                      ),
                    ],
                  )
                else
                  DropdownButtonFormField<String>(
                    style: theme.textTheme.bodyMedium,
                    key: ValueKey('day-clock-colour-${draft.colorId}'),
                    initialValue: draft.colorId ?? '',
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Event colour (optional)',
                      errorText: clock.errors['color'],
                      errorMaxLines: 6,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('Calendar default'),
                      ),
                      if (draft.colorId != null &&
                          !palette.containsKey(draft.colorId))
                        DropdownMenuItem(
                          value: draft.colorId,
                          enabled: false,
                          child: const Text('Unavailable colour'),
                        ),
                      for (final entry in palette.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: clockColor(
                                    entry.value.background,
                                    theme.colorScheme.outline,
                                  ),
                                  border: Border.all(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: PomaSpace.xs),
                              Flexible(
                                child: Text('Google colour ${entry.key}'),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: frozen
                        ? null
                        : (v) =>
                              changed(() => draft.colorId = v == '' ? null : v),
                  ),
                if (palette.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: PomaSpace.xs),
                    child: Text(
                      'Google colour choices will appear when the palette is available.',
                    ),
                  ),
                const SizedBox(height: PomaSpace.md),
                Text('Show this time as', style: theme.textTheme.bodyMedium),
                const SizedBox(height: PomaSpace.xs),
                if (op != null)
                  Text(draft.busy ? 'Busy' : 'Free')
                else
                  Wrap(
                    spacing: PomaSpace.xs,
                    runSpacing: PomaSpace.xs,
                    children: [
                      ChoiceChip(
                        label: const Text('Busy'),
                        selected: draft.busy,
                        selectedColor: highContrast
                            ? theme.colorScheme.primary
                            : null,
                        checkmarkColor: highContrast
                            ? theme.colorScheme.onPrimary
                            : null,
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          color: highContrast && draft.busy
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                        onSelected: frozen
                            ? null
                            : (_) => changed(() => draft.busy = true),
                      ),
                      ChoiceChip(
                        label: const Text('Free'),
                        selected: !draft.busy,
                        selectedColor: highContrast
                            ? theme.colorScheme.primary
                            : null,
                        checkmarkColor: highContrast
                            ? theme.colorScheme.onPrimary
                            : null,
                        labelStyle: theme.textTheme.labelLarge?.copyWith(
                          color: highContrast && !draft.busy
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface,
                        ),
                        onSelected: frozen
                            ? null
                            : (_) => changed(() => draft.busy = false),
                      ),
                    ],
                  ),
                const SizedBox(height: PomaSpace.md),
                Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (clock.validationMessage case final message?)
                        Text(
                          message,
                          style: TextStyle(
                            color:
                                clock.creationState ==
                                    CalendarCreationState.checking
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.error,
                          ),
                        ),
                      Text(clock.overlapMessage),
                    ],
                  ),
                ),
                const SizedBox(height: PomaSpace.sm),
                CheckboxListTile(
                  key: const ValueKey('day-clock-show-after-saving'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Show on Day Clock after saving'),
                  subtitle: const Text(
                    'Include this calendar and open the event’s date and AM/PM half.',
                  ),
                  value: draft.showOnDayClock,
                  onChanged: frozen
                      ? null
                      : (value) =>
                            changed(() => draft.showOnDayClock = value == true),
                ),
                const SizedBox(height: PomaSpace.sm),
                OutlinedButton(
                  onPressed:
                      clock.creationState == CalendarCreationState.validating ||
                          clock.creationBusy ||
                          granting
                      ? null
                      : clock.validateDraft,
                  child: Text(
                    clock.creationState == CalendarCreationState.validating
                        ? 'Checking times…'
                        : 'Check task',
                  ),
                ),
                const SizedBox(height: PomaSpace.md),
                if (clock.creation != null &&
                    !clock.reader.connection.creationEnabled) ...[
                  const Text(
                    'Optional task creation asks Google for event access on calendars you own. Poma creates only the event you review. Viewing and focus scheduling stay separate.',
                  ),
                  TextButton(
                    onPressed:
                        !clock.reader.connection.operationsEnabled ||
                            granting ||
                            clock.creationBusy
                        ? null
                        : clock.enableCreation,
                    child: Text(
                      granting
                          ? 'Waiting for Google consent…'
                          : 'Enable task creation',
                    ),
                  ),
                  if (granting)
                    TextButton(
                      onPressed: clock.reader.connection.cancelCreationConsent,
                      child: const Text('Cancel task creation setup'),
                    ),
                ],
                FilledButton(
                  onPressed:
                      clock.creationConnected &&
                          !clock.creationBusy &&
                          !granting &&
                          clock.review != null &&
                          (op == null || op.retryAllowed)
                      ? clock.submitReviewed
                      : null,
                  style: FilledButton.styleFrom(
                    disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                    disabledBackgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    clock.creationBusy
                        ? 'Checking save…'
                        : op?.retryAllowed == true
                        ? 'Retry Add to Google Calendar'
                        : 'Add to Google Calendar',
                  ),
                ),
                const SizedBox(height: PomaSpace.xs),
                if (clock.creation == null)
                  const Text(
                    'Google saving is unavailable in this build. This remains a draft in Poma.',
                  )
                else if (!clock.creationConnected && !granting)
                  Text(
                    clock.reader.connection.creationMessage ??
                        clock.creation?.message ??
                        'Not scheduled. Enable task creation and connect online to review and save.',
                  ),
                if (op != null) ...[
                  Text(
                    'Save status: ${clock.creationBusy ? 'working' : op.state.name}',
                  ),
                  TextButton(
                    onPressed: clock.creationBusy
                        ? null
                        : () => clock.reconcile(op),
                    child: const Text('Check save outcome'),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (op == null)
            TextButton(
              onPressed: clock.creationBusy || granting
                  ? null
                  : () {
                      clock.discardDraft();
                      Navigator.pop(context);
                    },
              child: const Text('Discard draft'),
            ),
          TextButton(
            onPressed: clock.creationBusy || granting
                ? null
                : () async {
                    if (op != null || await clock.keepDraft()) {
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
            child: Text(op == null ? 'Keep draft' : 'Close'),
          ),
        ],
      );
    },
  );

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }
}
