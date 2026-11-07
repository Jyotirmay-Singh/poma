import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../application/app_controller.dart';
import '../application/desktop_controller.dart';
import '../application/focus_block_controller.dart';
import '../application/focus_block_ports.dart';
import '../domain/focus_blocks.dart';
import 'app_shell.dart';
import 'settings_screen.dart';
import 'calendar_schedule.dart';
import 'design_tokens.dart';

String _status(FocusOperationStatus status) => switch (status) {
  FocusOperationStatus.needsReview => 'Needs review',
  FocusOperationStatus.checking => 'Checking outcome',
  FocusOperationStatus.pending => 'Pending',
  FocusOperationStatus.sending => 'Sending',
  FocusOperationStatus.saved => 'Saved',
  FocusOperationStatus.failed => 'Failed',
  FocusOperationStatus.expired => 'Expired',
  FocusOperationStatus.cancelled => 'Not scheduled',
};
String _capability(CalendarWriteCapability? state) => switch (state) {
  CalendarWriteCapability.disabled => 'Disabled',
  CalendarWriteCapability.granting => 'Waiting for consent',
  CalendarWriteCapability.verifying => 'Verifying access',
  CalendarWriteCapability.setupRequired => 'Calendar setup required',
  CalendarWriteCapability.ready => 'Ready',
  CalendarWriteCapability.blocked => 'Needs attention',
  null => 'Unavailable',
};
String _time(DateTime instant) =>
    DateFormat('d MMM yyyy, HH:mm').format(instant.toLocal());
String _offset(int minutes) =>
    'UTC${minutes < 0 ? '-' : '+'}${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';
String _failure(Object error) =>
    error is FocusFailure && error.kind == FocusFailureKind.invalidTime
    ? 'Choose a future, unambiguous date and time in the current device timezone.'
    : 'This action needs a fresh review. Check the calendar connection, access and saved operation status.';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    required this.controller,
    required this.desktop,
    super.key,
  });
  final AppController controller;
  final DesktopController desktop;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String? error;
  bool working = false;
  Future<void> _run(Future<void> Function() action) async {
    if (working) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => error = _failure(e));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<bool> _approve(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;
  Future<void> _calendarRecovery() async {
    final c = widget.desktop.focusBlocks!;
    final choices = await c.discoverCalendars();
    if (!mounted) return;
    if (choices.isEmpty) {
      setState(
        () => error =
            'No verified Poma-created calendar was found. An uncertain setup must be inspected in Google Calendar.',
      );
      return;
    }
    final picked = await showDialog<FocusCalendarBinding>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Recover Poma calendar'),
        children: [
          const Padding(
            padding: EdgeInsets.all(PomaSpace.md),
            child: Text(
              'Choose the verified calendar to use. This does not create or delete a Google calendar.',
            ),
          ),
          for (final b in choices)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, b),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: PomaSpace.sm),
                child: Text('${b.name}\n${b.id}'),
              ),
            ),
        ],
      ),
    );
    if (picked != null &&
        mounted &&
        await _approve(
          'Use this calendar?',
          '${picked.name}\nAccount: ${widget.desktop.connection!.verifiedAccountLabel}\nOnly verified Poma focus blocks will be manageable.',
          'Use calendar',
        )) {
      await c.bind(picked);
    }
  }

  Future<void> _manage(FocusRemoteBlock block, FocusOperationKind kind) async {
    final c = widget.desktop.focusBlocks!;
    final remote = await c.freshBlock(block.id);
    if (!mounted) return;
    if (remote.etag != block.etag ||
        remote.actualHash != block.actualHash ||
        c.journal!.operations.values.any(
          (o) => o.eventId == block.id && o.unresolved,
        )) {
      if (!await _approve(
        'Review current Google block',
        '${remote.title}\n${_time(remote.start)} to ${_time(remote.end)}\n${remote.busy ? 'Busy' : 'Free'}\nUse this current version for the next preview?',
        'Use current version',
      )) {
        return;
      }
      await c.adopt([remote]);
    }
    if (mounted) {
      await showFocusBlockDialog(
        context,
        widget.desktop,
        remote: remote,
        kind: kind,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final desktop = widget.desktop,
        c = desktop.focusBlocks,
        connection = desktop.connection;
    return AnimatedBuilder(
      animation: Listenable.merge([desktop, ?c, ?connection]),
      builder: (context, _) => PomaPage(
        controller: widget.controller,
        maxContentWidth: desktop.calendarSection == CalendarPageSection.schedule
            ? PomaLayout.workspaceWidth
            : PomaLayout.readingWidth,
        children: [
          ScreenHeading(
            title: 'Calendar',
            subtitle:
                'See your schedule, plan focused time and choose your calendars.',
            action: OutlinedButton.icon(
              onPressed: desktop.showPopup,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open calendar agenda'),
            ),
          ),
          if (desktop.sessionState != 'unlocked')
            const Padding(
              padding: EdgeInsets.all(PomaSpace.lg),
              child: Text(
                'Calendar details are hidden while Windows is locked or its lock state is unknown.',
              ),
            )
          else ...[
            if (desktop.calendarSection != CalendarPageSection.schedule)
              Container(
                padding: const EdgeInsets.all(PomaSpace.lg),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection?.verifiedAccountLabel ?? 'Google Calendar',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: PomaSpace.xs),
                    Wrap(
                      spacing: PomaSpace.lg,
                      runSpacing: PomaSpace.xs,
                      children: [
                        Text(
                          'Viewing: ${connection?.operationsEnabled == true
                              ? 'Connected'
                              : connection?.mayRead == true
                              ? 'Saved connection'
                              : 'Not connected'}',
                        ),
                        Text('Focus scheduling: ${_capability(c?.capability)}'),
                        if (c != null && !c.online)
                          const Text('Offline · drafts only'),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: PomaSpace.lg),
            Wrap(
              spacing: PomaSpace.xs,
              runSpacing: PomaSpace.xs,
              children: [
                ChoiceChip(
                  label: const Text('Schedule'),
                  selected:
                      desktop.calendarSection == CalendarPageSection.schedule,
                  onSelected: (_) =>
                      desktop.openCalendarSection(CalendarPageSection.schedule),
                ),
                ChoiceChip(
                  label: const Text('Focus blocks'),
                  selected:
                      desktop.calendarSection ==
                      CalendarPageSection.focusBlocks,
                  onSelected: (_) => desktop.openCalendarSection(
                    CalendarPageSection.focusBlocks,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Calendar settings'),
                  selected:
                      desktop.calendarSection == CalendarPageSection.settings,
                  onSelected: (_) =>
                      desktop.openCalendarSection(CalendarPageSection.settings),
                ),
              ],
            ),
            const SizedBox(height: PomaSpace.lg),
            if (error != null) Text(error!, semanticsLabel: error),
            if (working) const LinearProgressIndicator(),
            if (c?.message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: PomaSpace.sm),
                child: Semantics(liveRegion: true, child: Text(c!.message!)),
              ),
            if (c != null &&
                c.journal == null &&
                connection?.verifiedAccountKey != null)
              TextButton(
                onPressed: working
                    ? null
                    : () => _run(() async {
                        await c.stop();
                        await c.initialize();
                      }),
                child: const Text('Retry scheduling storage'),
              ),
            if (desktop.calendarSection == CalendarPageSection.settings) ...[
              if (c != null && connection != null) ...[
                _Heading('Focus scheduling'),
                const Text(
                  'Optional access to events on calendars this app creates. Poma uses its dedicated calendar and changes only verified focus blocks. Skipping keeps calendar viewing and offline Poma.',
                ),
                if (connection.writeMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: PomaSpace.xs),
                    child: Text(connection.writeMessage!),
                  ),
                Wrap(
                  spacing: PomaSpace.xs,
                  runSpacing: PomaSpace.xs,
                  children: [
                    if (!connection.focusWriteEnabled || c.disabled)
                      FilledButton(
                        onPressed: !working && connection.operationsEnabled
                            ? () => _run(() async {
                                if (await _approve(
                                  'Enable focus scheduling?',
                                  'Google grants access to events on calendars this app creates. Poma will use its dedicated Poma Focus calendar and change only blocks it can verify. You review the title and timing before anything is scheduled.',
                                  'Enable focus scheduling',
                                )) {
                                  if (!connection.focusWriteEnabled) {
                                    await connection.enableFocusScheduling();
                                  }
                                  if (connection.focusWriteEnabled) {
                                    await c.enable();
                                  }
                                }
                              })
                            : null,
                        child: const Text('Enable focus scheduling'),
                      ),
                    if (const {
                      CalendarWriteCapability.granting,
                      CalendarWriteCapability.verifying,
                    }.contains(connection.writeCapability))
                      TextButton(
                        onPressed: connection.cancelFocusConsent,
                        child: const Text('Cancel setup'),
                      ),
                    if (connection.focusWriteEnabled && !c.disabled)
                      TextButton(
                        onPressed: working
                            ? null
                            : () => _run(() async {
                                await c.disable();
                                await connection.disableFocusScheduling();
                              }),
                        child: const Text('Disable focus scheduling'),
                      ),
                  ],
                ),
                if (connection.focusWriteEnabled && !c.disabled) ...[
                  const SizedBox(height: PomaSpace.md),
                  Text(
                    c.journal?.binding?.name ??
                        'Poma Focus calendar not set up',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (c.journal?.binding == null)
                    Wrap(
                      spacing: PomaSpace.xs,
                      runSpacing: PomaSpace.xs,
                      children: [
                        FilledButton(
                          onPressed: working
                              ? null
                              : () => _run(() async {
                                  if (c.journal?.provisioning != null ||
                                      await _approve(
                                        'Create Poma Focus calendar?',
                                        'Create one dedicated secondary calendar in this Google account. This does not schedule a block.',
                                        'Create Poma Focus calendar',
                                      )) {
                                    await c.createCalendar();
                                  }
                                }),
                          child: Text(
                            c.journal?.provisioning == null
                                ? 'Create Poma Focus calendar'
                                : 'Check calendar setup',
                          ),
                        ),
                        TextButton(
                          onPressed: working
                              ? null
                              : () => _run(_calendarRecovery),
                          child: const Text('Recover Poma calendar'),
                        ),
                      ],
                    ),
                  if (c.journal?.binding != null)
                    TextButton(
                      onPressed: working
                          ? null
                          : () => _run(() async {
                              await showDialog<void>(
                                context: context,
                                builder: (_) => _RecoverBlocks(controller: c),
                              );
                            }),
                      child: const Text('Recover Poma blocks'),
                    ),
                ],
                const SizedBox(height: PomaSpace.md),
                const Divider(),
              ],
              CalendarPreferences(desktop: desktop),
            ] else if (desktop.calendarSection ==
                CalendarPageSection.focusBlocks) ...[
              Wrap(
                spacing: PomaSpace.xs,
                runSpacing: PomaSpace.xs,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.add),
                    onPressed: () => widget.controller.selectedTask == null
                        ? desktop.navigate(1)
                        : showFocusBlockDialog(
                            context,
                            desktop,
                            taskTitle: widget.controller.selectedTask!.title,
                            taskId: widget.controller.selectedTask!.id,
                          ),
                    label: Text(
                      widget.controller.selectedTask == null
                          ? 'Choose a task'
                          : 'Schedule focus block',
                    ),
                  ),
                  if (c?.journal?.binding != null)
                    TextButton(
                      onPressed: () => _run(() async {
                        await showDialog<void>(
                          context: context,
                          builder: (_) => _RecoverBlocks(controller: c!),
                        );
                      }),
                      child: const Text('Recover Poma blocks'),
                    ),
                ],
              ),
              if (c == null || c.journal == null || c.journal!.binding == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: PomaSpace.lg),
                  child: Text(
                    c?.journal == null
                        ? 'Connect Google to save account-bound drafts.'
                        : 'Complete focus scheduling in Calendar settings. Drafts remain local until you review and confirm them.',
                  ),
                ),
              if (c?.journal != null) ...[
                if (c!.journal!.drafts.isNotEmpty) ...[
                  _Heading('Drafts'),
                  for (final d in c.journal!.drafts.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.edit_note),
                      title: Text(d.payload.title),
                      subtitle: Text(
                        '${d.payload.start.isAfter(c.now) ? 'Not scheduled' : 'Expired'}\n${_time(d.payload.start)} to ${_time(d.payload.end)}',
                      ),
                      isThreeLine: true,
                      trailing: TextButton(
                        onPressed: () =>
                            showFocusBlockDialog(context, desktop, draft: d),
                        child: const Text('Review'),
                      ),
                    ),
                ],
                _Heading('Focus blocks'),
                if (c.journal!.blocks.isEmpty)
                  const Text(
                    'No focus blocks saved here yet. Scheduling never starts or completes your timer.',
                  ),
                for (final b in c.journal!.blocks.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      b.busy ? Icons.event_busy : Icons.event_available,
                    ),
                    title: Text(b.title),
                    subtitle: Text(
                      '${_time(b.start)} to ${_time(b.end)}\n${b.busy ? 'Busy' : 'Free'}',
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<FocusOperationKind>(
                      tooltip: 'Manage focus block',
                      onSelected: (kind) => _run(() => _manage(b, kind)),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: FocusOperationKind.edit,
                          child: Text('Edit focus block'),
                        ),
                        const PopupMenuItem(
                          value: FocusOperationKind.delete,
                          child: Text('Delete focus block'),
                        ),
                      ],
                    ),
                  ),
                if (c.journal!.operations.isNotEmpty) ...[
                  _Heading('Operation status'),
                  for (final op
                      in c.journal!.operations.values.toList().reversed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: PomaSpace.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            op.payload.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text('${op.kind.name} · ${_status(op.status)}'),
                          if (op.error != null)
                            Text(switch (op.error) {
                              'foreign' =>
                                'The event ID belongs to a different or unsupported block. It will not be overwritten.',
                              'notFound' =>
                                'No event found on the verified calendar. A future retry requires another preview.',
                              'deleted' =>
                                'The Google block was deleted. Poma will not recreate it.',
                              'remoteChanged' =>
                                'The Google block changed. Review its current version before another change.',
                              _ =>
                                'Review the connection and current Google block before another action.',
                            }),
                          if (op.unresolved ||
                              op.status == FocusOperationStatus.failed)
                            Wrap(
                              spacing: PomaSpace.xs,
                              children: [
                                TextButton(
                                  onPressed: working
                                      ? null
                                      : () => _run(() => c.reconcile(op.id)),
                                  child: const Text('Check outcome'),
                                ),
                                if (op.kind == FocusOperationKind.create &&
                                    op.error == 'notFound' &&
                                    op.payload.start.isAfter(c.now))
                                  TextButton(
                                    onPressed: working
                                        ? null
                                        : () => _run(() async {
                                            final preview = await c.retry(
                                              op.id,
                                            );
                                            if (context.mounted) {
                                              await showFocusBlockDialog(
                                                context,
                                                desktop,
                                                preview: preview,
                                              );
                                            }
                                          }),
                                    child: const Text('Review same-ID retry'),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ],
            ],
          ],
          Offstage(
            key: const ValueKey('calendar-schedule-section'),
            offstage:
                desktop.sessionState != 'unlocked' ||
                desktop.calendarSection != CalendarPageSection.schedule,
            child: TickerMode(
              enabled:
                  desktop.sessionState == 'unlocked' &&
                  desktop.calendarSection == CalendarPageSection.schedule,
              child: CalendarSchedule(desktop: desktop),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PomaSpace.lg, bottom: PomaSpace.sm),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleLarge),
    ),
  );
}

Future<void> showFocusBlockDialog(
  BuildContext context,
  DesktopController desktop, {
  String? taskTitle,
  String? taskId,
  FocusBlockDraft? draft,
  FocusRemoteBlock? remote,
  FocusOperationKind kind = FocusOperationKind.create,
  FocusBlockPreview? preview,
}) async {
  final c = desktop.focusBlocks;
  if (c == null) return;
  await showDialog<void>(
    context: context,
    builder: (_) => _FocusDialog(
      desktop: desktop,
      title: taskTitle,
      taskId: taskId,
      draft: draft,
      remote: remote,
      kind: kind,
      preview: preview,
    ),
  );
}

class _FocusDialog extends StatefulWidget {
  const _FocusDialog({
    required this.desktop,
    this.title,
    this.taskId,
    this.draft,
    this.remote,
    this.kind = FocusOperationKind.create,
    this.preview,
  });
  final DesktopController desktop;
  final String? title, taskId;
  final FocusBlockDraft? draft;
  final FocusRemoteBlock? remote;
  final FocusOperationKind kind;
  final FocusBlockPreview? preview;
  @override
  State<_FocusDialog> createState() => _FocusDialogState();
}

class _FocusDialogState extends State<_FocusDialog> {
  late final String id =
      widget.draft?.id ?? widget.preview?.draft.id ?? focusUuid();
  late final title = TextEditingController(
    text:
        widget.draft?.payload.title ??
        widget.remote?.title ??
        widget.preview?.draft.payload.title ??
        widget.title ??
        'Focus block',
  );
  late final TextEditingController start, end;
  bool busy = true, working = false, ack = false;
  FocusBlockPreview? review;
  String? error;
  String availability = 'Availability unknown';
  String availabilitySignature = '';
  FocusBlockController get c => widget.desktop.focusBlocks!;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final rounded = DateTime.fromMillisecondsSinceEpoch(
      (now.millisecondsSinceEpoch ~/ 300000 + 1) * 300000,
    );
    final begins =
        widget.draft?.payload.start ??
        widget.remote?.start ??
        widget.preview?.draft.payload.start ??
        rounded;
    final ends =
        widget.draft?.payload.end ??
        widget.remote?.end ??
        widget.preview?.draft.payload.end ??
        begins.add(
          Duration(minutes: widget.desktop.controller.settings.focusMinutes),
        );
    start = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm').format(begins.toLocal()),
    );
    end = TextEditingController(
      text: DateFormat('yyyy-MM-dd HH:mm').format(ends.toLocal()),
    );
    busy =
        widget.draft?.payload.busy ??
        widget.remote?.busy ??
        widget.preview?.draft.payload.busy ??
        true;
    review = widget.preview;
    if (review != null) _overlaps(review!.draft.payload);
  }

  DateTime _wall(String text) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})$',
    ).firstMatch(text);
    if (match == null) throw const FocusFailure(FocusFailureKind.invalidTime);
    final values = [for (var i = 1; i <= 5; i++) int.parse(match[i]!)];
    final t = DateTime.utc(
      values[0],
      values[1],
      values[2],
      values[3],
      values[4],
    );
    if (t.year != values[0] ||
        t.month != values[1] ||
        t.day != values[2] ||
        t.hour != values[3] ||
        t.minute != values[4]) {
      throw const FocusFailure(FocusFailureKind.invalidTime);
    }
    return t;
  }

  String _snapshot() {
    final reader = widget.desktop.calendarData;
    return '${reader?.scopeGeneration}/${reader?.selected}/${reader?.snapshots.values.map((s) => s.succeededAt).join(',')}';
  }

  void _overlaps(FocusPayload p) {
    final reader = widget.desktop.calendarData;
    final matches =
        reader?.events
            .where(
              (e) =>
                  e.startUtc != null &&
                  e.endUtc != null &&
                  e.startUtc!.isBefore(p.end) &&
                  e.endUtc!.isAfter(p.start),
            )
            .toList() ??
        [];
    final known =
        reader != null &&
        reader.selected.isNotEmpty &&
        reader.selected.every(
          (id) =>
              reader.snapshots[id]?.fresh(c.now, reader.window) == true &&
              reader.sourceFailures[id] == null,
        );
    availability =
        '${matches.isEmpty ? 'No known overlaps' : '${matches.length} known overlap${matches.length == 1 ? '' : 's'}'}${known ? ' in selected calendars' : '. Availability unknown; saved data is incomplete or stale.'}';
    ack = widget.kind == FocusOperationKind.delete || matches.isEmpty;
    availabilitySignature = _snapshot();
  }

  Future<void> _prepare({bool draftOnly = false}) async {
    if (working) return;
    setState(() {
      working = true;
      error = null;
    });
    try {
      final a = await c.time.resolve(_wall(start.text)),
          b = await c.time.resolve(_wall(end.text));
      if (a.fingerprint != b.fingerprint) {
        throw const FocusFailure(FocusFailureKind.invalidTime);
      }
      final p = FocusPayload(
        title: title.text,
        start: a.utc,
        end: b.utc,
        busy: busy,
        zone: a.zone,
        zoneFingerprint: a.fingerprint,
        startOffsetMinutes: a.offsetMinutes,
        endOffsetMinutes: b.offsetMinutes,
      );
      final d = FocusBlockDraft(
        id: id,
        payload: p,
        taskId: widget.draft?.taskId ?? widget.taskId,
      );
      if (draftOnly) {
        await c.saveDraft(d);
        if (mounted && c.journal?.drafts[id]?.payload.hash == p.hash) {
          Navigator.pop(context);
        }
      } else {
        final next = await c.preview(
          d,
          kind: widget.kind,
          before: widget.remote,
        );
        if (mounted) {
          setState(() {
            review = next;
            _overlaps(p);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is FormatException
              ? 'Enter a title and a positive duration. Titles can contain up to 1,024 characters.'
              : _failure(e),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _confirm() async {
    if (working || review == null || !ack) return;
    if (widget.kind != FocusOperationKind.delete &&
        availabilitySignature != _snapshot()) {
      setState(() {
        review = null;
        error = 'Calendar availability changed. Review again.';
      });
      return;
    }
    setState(() => working = true);
    await c.confirm(review!);
    if (mounted) {
      Navigator.pop(context);
      widget.desktop.openCalendarSection(CalendarPageSection.focusBlocks);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.desktop,
    builder: (context, _) {
      final unlocked = widget.desktop.sessionState == 'unlocked';
      if (!unlocked) review = null;
      final p = review?.draft.payload;
      return AlertDialog(
        title: Text(
          widget.kind == FocusOperationKind.delete
              ? 'Delete focus block'
              : review == null
              ? 'Schedule focus block'
              : 'Review focus block',
        ),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!unlocked)
                  const Text(
                    'Calendar details are hidden. Unlock Windows, then review again.',
                  )
                else if (p != null) ...[
                  if (widget.kind != FocusOperationKind.create &&
                      review!.before != null) ...[
                    const Text('Current Google block'),
                    Text(review!.before!.title),
                    Text(
                      '${_time(review!.before!.start)} to ${_time(review!.before!.end)}',
                    ),
                    Text(review!.before!.busy ? 'Busy' : 'Free'),
                    const Divider(),
                  ],
                  Text(p.title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: PomaSpace.md),
                  _Detail(
                    'Account',
                    widget.desktop.connection?.verifiedAccountLabel ??
                        'Verified Google account',
                  ),
                  _Detail('Calendar', review!.binding.name),
                  _Detail(
                    'Starts',
                    '${_time(p.start)} (${_offset(p.startOffsetMinutes)})',
                  ),
                  _Detail(
                    'Ends',
                    '${_time(p.end)} (${_offset(p.endOffsetMinutes)})',
                  ),
                  _Detail('Timezone', p.zone),
                  _Detail(
                    'Duration',
                    '${p.end.difference(p.start).inMinutes} minutes',
                  ),
                  _Detail('Show as', p.busy ? 'Busy' : 'Free'),
                  if (widget.kind != FocusOperationKind.delete) ...[
                    const SizedBox(height: PomaSpace.sm),
                    Text(availability),
                    if (!ack)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: ack,
                        onChanged: (v) => setState(() => ack = v == true),
                        title: const Text('I have reviewed the known overlaps'),
                      ),
                  ],
                  const SizedBox(height: PomaSpace.sm),
                  Text(
                    widget.kind == FocusOperationKind.delete
                        ? 'This explicitly deletes only this verified Poma-owned block.'
                        : 'Only this title, timing and Busy/Free choice are sent. Task notes and focus history remain local.',
                  ),
                ] else if (widget.kind == FocusOperationKind.delete) ...[
                  Text(widget.remote!.title),
                  Text(
                    '${_time(widget.remote!.start)} to ${_time(widget.remote!.end)}',
                  ),
                  Text(widget.remote!.busy ? 'Busy' : 'Free'),
                  const Text(
                    'Review the exact current block before confirming deletion.',
                  ),
                ] else ...[
                  TextField(
                    controller: title,
                    maxLength: 1024,
                    decoration: const InputDecoration(
                      labelText: 'Title sent to Google',
                    ),
                  ),
                  const SizedBox(height: PomaSpace.md),
                  TextField(
                    controller: start,
                    decoration: const InputDecoration(
                      labelText: 'Starts · device time',
                      hintText: 'YYYY-MM-DD HH:mm',
                    ),
                  ),
                  const SizedBox(height: PomaSpace.md),
                  TextField(
                    controller: end,
                    decoration: const InputDecoration(
                      labelText: 'Ends · device time',
                      hintText: 'YYYY-MM-DD HH:mm',
                    ),
                  ),
                  const SizedBox(height: PomaSpace.sm),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show as Busy'),
                    subtitle: const Text('Turn off to show as Free.'),
                    value: busy,
                    onChanged: (v) => setState(() => busy = v),
                  ),
                  if (!c.ready)
                    const Text(
                      'Save a local draft, or finish focus scheduling in Calendar settings before reviewing an online operation.',
                    ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: PomaSpace.sm),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (working) const LinearProgressIndicator(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: working ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          if (unlocked && review != null && widget.preview == null)
            TextButton(
              onPressed: working ? null : () => setState(() => review = null),
              child: const Text('Back'),
            ),
          if (unlocked &&
              review == null &&
              widget.kind == FocusOperationKind.create)
            TextButton(
              onPressed: working ? null : () => _prepare(draftOnly: true),
              child: const Text('Save draft'),
            ),
          if (unlocked)
            FilledButton(
              onPressed: working
                  ? null
                  : review == null
                  ? c.ready
                        ? () => _prepare()
                        : null
                  : ack
                  ? _confirm
                  : null,
              child: Text(
                review == null
                    ? 'Review block'
                    : widget.kind == FocusOperationKind.delete
                    ? 'Delete focus block'
                    : widget.kind == FocusOperationKind.edit
                    ? 'Save focus block'
                    : 'Schedule focus block',
              ),
            ),
        ],
      );
    },
  );
  @override
  void dispose() {
    title.dispose();
    start.dispose();
    end.dispose();
    super.dispose();
  }
}

class _Detail extends StatelessWidget {
  const _Detail(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: PomaSpace.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        Text(value),
      ],
    ),
  );
}

class _RecoverBlocks extends StatefulWidget {
  const _RecoverBlocks({required this.controller});
  final FocusBlockController controller;
  @override
  State<_RecoverBlocks> createState() => _RecoverBlocksState();
}

class _RecoverBlocksState extends State<_RecoverBlocks> {
  int week = 0;
  bool loading = true;
  String? error;
  List<FocusRemoteBlock> blocks = [];
  Set<String> selected = {};
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      blocks = [];
      selected = {};
    });
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day + 7 * week),
          end = DateTime(now.year, now.month, now.day + 7 * (week + 1));
      final result = await widget.controller.recover(
        start.toUtc(),
        end.toUtc(),
      );
      if (mounted) setState(() => blocks = result);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'This range could not be completely verified. Retry before recovering blocks.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => AlertDialog(
      title: const Text('Recover Poma blocks'),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.controller.unlocked)
                const Text('Unlock Windows to review calendar details.')
              else ...[
                const Text(
                  'Review and select current Google blocks to manage here. This saves local records only; it restores no tasks or pending commands.',
                ),
                Wrap(
                  spacing: PomaSpace.xs,
                  children: [
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              week--;
                              unawaited(_load());
                            },
                      child: const Text('Previous 7 dates'),
                    ),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              week++;
                              unawaited(_load());
                            },
                      child: const Text('Next 7 dates'),
                    ),
                  ],
                ),
                if (loading) const LinearProgressIndicator(),
                if (error != null) Text(error!),
                if (!loading && error == null && blocks.isEmpty)
                  const Text('No supported Poma blocks in this range.'),
                for (final b in blocks)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(b.title),
                    subtitle: Text(
                      '${_time(b.start)} to ${_time(b.end)}\n${b.busy ? 'Busy' : 'Free'}${b.properties['pomaPayloadHash'] == b.actualHash ? '' : ' · Changed in Google; adopt current version'}',
                    ),
                    value: selected.contains(b.id),
                    onChanged: loading
                        ? null
                        : (v) => setState(() {
                            if (v == true) {
                              selected.add(b.id);
                            } else {
                              selected.remove(b.id);
                            }
                          }),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: loading || selected.isEmpty || !widget.controller.unlocked
              ? null
              : () async {
                  setState(() => loading = true);
                  try {
                    await widget.controller.adopt(
                      blocks.where((b) => selected.contains(b.id)).toList(),
                    );
                    if (context.mounted) Navigator.pop(context);
                  } catch (_) {
                    if (mounted) {
                      setState(() {
                        loading = false;
                        error =
                            'The Google blocks changed. Reload and review them again.';
                        selected = {};
                      });
                    }
                  }
                },
          child: const Text('Recover selected blocks'),
        ),
      ],
    ),
  );
}
