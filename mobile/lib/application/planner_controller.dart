import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;

import '../data/planner_time.dart';
import '../domain/calendar_data.dart';
import '../domain/calendar_event_creation.dart';
import '../domain/models.dart';
import '../domain/planner.dart';
import 'app_controller.dart';
import 'calendar_connection_controller.dart';
import 'calendar_read_controller.dart';
import 'calendar_read_ports.dart';
import 'planner_ports.dart';

const _repeatFields = [
  'repeat',
  'interval',
  'weekdays',
  'ending',
  'count',
  'until',
  'zone',
  'allDay',
];

class PlannerController extends ChangeNotifier implements PlannerTaskActions {
  PlannerController({
    required this.app,
    required this.reader,
    required this.writer,
    required this.time,
    bool unlocked = true,
  }) : _unlocked = unlocked && !app.cleanupPending {
    final local = reader.now.toLocal();
    selectedDate = CalendarDate(local.year, local.month, local.day);
    clockTick = ValueNotifier(reader.now);
    app.plannerActions = this;
    app.addListener(_appChanged);
    reader.addListener(_readerChanged);
    connection.addListener(_connectionChanged);
    _authority = _session;
  }

  final AppController app;
  final CalendarReadController reader;
  final PlannerEventWriter writer;
  final PlannerTime time;
  late final ValueNotifier<DateTime> clockTick;
  CalendarConnectionController get connection => reader.connection;
  PlannerData get data => app.planner;
  PlannerPreferences get preferences =>
      data.preferences[accountKey ?? 'device'] ?? const PlannerPreferences();
  String? get accountKey => connection.verifiedAccountKey;
  bool get unlocked => _unlocked && !_disposed;
  bool _unlocked, _disposed = false, _resetting = false;
  int _epoch = 0, _viewRevision = 0;
  String _authority = '';
  String get _session =>
      '${connection.verifiedAccountKey}/${connection.sessionGeneration}/${connection.creationGeneration}/'
      '${connection.creationEnabled}/${connection.creationUpgradeActive}/${connection.operationsEnabled}';
  Future<void> _changes = Future.value();
  Future<void>? _draining;
  CalendarScheduledJob? _wake;
  String? message;
  Map<String, String> errors = {};
  Map<String, List<DateTime>> ambiguousTimes = {};
  Map<String, dynamic>? draft;
  bool ready = false, saving = false;
  bool editorOpen = false, editorPane = false, editorOpening = false;
  void setEditorPresentation({required bool open, required bool pane}) {
    if (editorOpen == open && editorPane == pane) return;
    editorOpen = open;
    editorPane = pane;
    _notify();
  }

  late CalendarDate selectedDate;
  bool followingNow = true;
  PlannerCalendarView calendarView = PlannerCalendarView.week;
  PlannerClockMode clockMode = PlannerClockMode.twelveHours;
  int half = 0;
  DateTime? inspectedUtc;
  String? selectedIdentity;
  final Map<String, int> _saveViews = {};
  final Map<String, int> _saveSelections = {};
  final Set<String> _legacyRetries = {};
  Future<void>? _initializing;
  bool _initialized = false, _reconciling = false;
  int _seenReaderRevision = -1;
  String? _readerSignature;
  final Map<String, (Map<String, dynamic>, Map<String, dynamic>)> _localUndo =
      {};

  Future<void> initialize() {
    if (_initialized) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    await time.initialize();
    clockMode = preferences.clockMode;
    calendarView = preferences.calendarView;
    final local = reader.now.toLocal();
    half = local.hour < 12 ? 0 : 1;
    await _change(
      (current) => current.copyWith(
        operations: {
          for (final e in current.operations.entries)
            e.key: e.value.state == PlannerOperationState.sending
                ? e.value.copyWith(
                    state: PlannerOperationState.checking,
                    message: 'Checking the original save after restart.',
                  )
                : e.value,
        },
      ),
    );
    _initialized = true;
    ready = true;
    _notify();
    unawaited(sync());
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _appChanged() {
    if (_resetting &&
        !app.cleanupPending &&
        data.schedules.isEmpty &&
        data.operations.isEmpty) {
      _resetting = false;
    }
    _notify();
  }

  void _readerChanged() {
    clockTick.value = reader.now;
    if (followingNow) {
      final local = reader.now.toLocal();
      selectedDate = CalendarDate(local.year, local.month, local.day);
      half = local.hour < 12 ? 0 : 1;
    }
    if (!_reconciling &&
        reader.dataRevision != _seenReaderRevision &&
        !reader.refreshing &&
        !reader.rangeLoading &&
        !reader.loading) {
      _seenReaderRevision = reader.dataRevision;
      unawaited(_reconcileLinks());
    }
    final signature = [
      reader.dataRevision,
      reader.scopeGeneration,
      reader.selectionRevision,
      reader.loading,
      reader.rangeLoading,
      reader.refreshing,
      reader.failure?.kind,
      reader.sourceFailures.keys.join(','),
      reader.rangeFailures.keys.join(','),
      reader.rangeVerified(dayRange, availability: true),
      selectedDate,
      half,
    ].join('/');
    if (_readerSignature != signature) {
      _readerSignature = signature;
      _notify();
    }
  }

  Future<void> _reconcileLinks() async {
    if (!ready || !unlocked || accountKey == null) return;
    _reconciling = true;
    final epoch = _epoch, account = accountKey;
    try {
      final candidates = data.schedules.values
          .where(
            (schedule) =>
                !schedule.removed &&
                schedule.taskId != null &&
                schedule.policy == PlannerSyncPolicy.google &&
                schedule.accountKey == account &&
                pendingFor(schedule.id) == null,
          )
          .toList();
      for (final schedule in candidates) {
        if (!unlocked || epoch != _epoch) return;
        final observed =
            [
                  for (final range in reader.activeRanges)
                    ...reader.eventsFor(range),
                ]
                .where(
                  (event) =>
                      event.calendarId == schedule.calendarId &&
                      (event.id == schedule.eventId ||
                          event.recurringEventId == schedule.eventId),
                )
                .toList();
        final start = schedule.startUtc?.toLocal();
        final coverage = start == null
            ? null
            : reader.clock.dayWindow(
                CalendarDate(start.year, start.month, start.day),
              );
        final visible = observed.any((event) {
          final local = event.startUtc?.toLocal();
          return local != null &&
              reader.sourceRangeVerified(
                schedule.calendarId!,
                reader.clock.dayWindow(
                  CalendarDate(local.year, local.month, local.day),
                ),
              );
        });
        if (!visible &&
            (coverage == null ||
                !reader.sourceRangeVerified(schedule.calendarId!, coverage))) {
          continue;
        }
        try {
          if (!await writer.validateDestination(
            account!,
            schedule.calendarId!,
          )) {
            continue;
          }
          final remote = await writer.get(
            account,
            schedule.calendarId!,
            schedule.eventId!,
          );
          if (!unlocked || epoch != _epoch) return;
          bool unchanged(PlannerData current) =>
              pendingFor(schedule.id) == null &&
              plannerValueEquals(
                current.schedules[schedule.id]?.toJson(),
                schedule.toJson(),
              );
          await _change(
            (current) {
              if (!unchanged(current)) return current;
              return current.copyWith(
                schedules: {
                  ...current.schedules,
                  schedule.id: remote == null || remote.deleted
                      ? schedule.copyWith(removed: true, clearUndo: true)
                      : schedule.copyWith(
                          fields: remote.fields,
                          baseline: remote.fields,
                          etag: remote.etag,
                        ),
                },
              );
            },
            deriveTasks: (current) {
              final title = remote?.deleted == false
                  ? remote!.fields['summary'] as String?
                  : null;
              final task = app.tasks
                  .where((task) => task.id == schedule.taskId)
                  .firstOrNull;
              return unchanged(current) &&
                      task != null &&
                      title != null &&
                      title.isNotEmpty &&
                      title.length <= 160 &&
                      title != task.title
                  ? [task.copyWith(title: title)]
                  : [];
            },
          );
        } on PlannerFailure {
          // A read/access failure does not establish external deletion.
        }
      }
    } finally {
      _reconciling = false;
    }
  }

  void _connectionChanged() {
    if (_authority != _session) {
      _authority = _session;
      _epoch++;
      writer.cancel();
      selectedIdentity = null;
      _saveViews.clear();
      clockMode = preferences.clockMode;
      calendarView = preferences.calendarView;
    }
    _notify();
    if (unlocked && connection.operationsEnabled) unawaited(sync());
  }

  void setUnlocked(bool value) {
    if (_unlocked == value) return;
    _unlocked = value;
    _epoch++;
    writer.cancel();
    if (value) unawaited(sync());
    _notify();
  }

  Future<bool> _change(
    PlannerData Function(PlannerData current) change, {
    List<FocusTask> tasks = const [],
    List<String> deletedTasks = const [],
    List<FocusTask> Function(PlannerData current)? deriveTasks,
    String? clearSelectedTask,
  }) {
    final completion = Completer<bool>();
    _changes = _changes.catchError((Object _) {}).then((_) async {
      if (_disposed || _resetting) {
        completion.complete(false);
        return;
      }
      try {
        final before = data;
        final changedTasks = deriveTasks?.call(before) ?? tasks;
        final next = change(before);
        final dependencies = next.operations.values
            .where((operation) => operation.pending)
            .map((operation) => operation.dependsOn)
            .toSet();
        final cutoff = reader.now.subtract(const Duration(days: 30));
        final retained = next.copyWith(
          operations: {
            for (final operation in next.operations.values)
              if (!operation.terminal ||
                  operation.completedAt == null ||
                  !operation.completedAt!.isBefore(cutoff) ||
                  dependencies.contains(operation.id))
                operation.id:
                    operation.terminal && operation.completedAt == null
                    ? operation.copyWith(completedAt: reader.now)
                    : operation,
          },
        );
        final saved = await app.commitPlanner(
          retained,
          changedTasks: changedTasks,
          deletedTasks: deletedTasks,
          clearSelectedTask: clearSelectedTask,
        );
        if (!saved) {
          message =
              app.saveError ?? 'Couldn’t save. Your fields are kept. Retry.';
        }
        completion.complete(saved);
      } catch (_) {
        message = 'Couldn’t save. Your fields are kept. Retry.';
        completion.complete(false);
      }
      _notify();
    });
    return completion.future;
  }

  CalendarWindow range(CalendarDate first, CalendarDate until) =>
      CalendarWindow(
        first: first,
        until: until,
        startUtc: reader.clock.dayWindow(first).startUtc,
        endUtc: reader.clock.dayWindow(until).startUtc,
      );
  CalendarWindow get dayRange => range(selectedDate, selectedDate.plusDays(1));
  CalendarWindow weekRange({int firstWeekday = 1}) {
    final weekday = DateTime.utc(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    ).weekday;
    final first = selectedDate.plusDays(-((weekday - firstWeekday + 7) % 7));
    return range(first, first.plusDays(7));
  }

  CalendarWindow monthRange({int firstWeekday = 1}) {
    final first = CalendarDate(selectedDate.year, selectedDate.month, 1);
    final weekday = DateTime.utc(first.year, first.month, 1).weekday;
    final begin = first.plusDays(-((weekday - firstWeekday + 7) % 7));
    return range(begin, begin.plusDays(42));
  }

  void browse(CalendarDate date, {int? selectedHalf, String? identity}) {
    _viewRevision++;
    followingNow = false;
    selectedDate = date;
    if (selectedHalf != null) half = selectedHalf;
    selectedIdentity = identity;
    _notify();
  }

  void now() {
    _viewRevision++;
    followingNow = true;
    inspectedUtc = reader.now;
    _readerChanged();
  }

  void select(CalendarEvent event, {DateTime? at}) {
    _viewRevision++;
    selectedIdentity = calendarEventIdentity(event);
    inspectedUtc = at ?? event.startUtc;
    _notify();
  }

  void inspect(DateTime value) {
    inspectedUtc = value;
    _notify();
  }

  void setClockMode(PlannerClockMode value) {
    clockMode = value;
    final key = accountKey ?? 'device';
    unawaited(
      _change(
        (current) => current.copyWith(
          preferences: {
            ...current.preferences,
            key: (current.preferences[key] ?? const PlannerPreferences())
                .copyWith(clockMode: value),
          },
        ),
      ),
    );
    _notify();
  }

  void setCalendarView(PlannerCalendarView value) {
    calendarView = value;
    final key = accountKey ?? 'device';
    unawaited(
      _change(
        (current) => current.copyWith(
          preferences: {
            ...current.preferences,
            key: (current.preferences[key] ?? const PlannerPreferences())
                .copyWith(calendarView: value),
          },
        ),
      ),
    );
    _notify();
  }

  PlannerSchedule? taskSchedule(String id) => data.schedules.values
      .where((s) => s.taskId == id && !s.removed)
      .firstOrNull;
  PlannerSchedule? scheduleForEvent(CalendarEvent event) {
    final all = data.schedules.values.where(
      (s) =>
          !s.removed &&
          (s.policy == PlannerSyncPolicy.local || s.accountKey == accountKey),
    );
    return all
            .where(
              (s) =>
                  s.calendarId == event.calendarId && s.eventId == event.id ||
                  s.policy == PlannerSyncPolicy.local &&
                      (s.eventId ?? s.id) == event.id,
            )
            .firstOrNull ??
        all.where((s) => s.eventId == event.recurringEventId).firstOrNull;
  }

  List<PlannerOperation> operationsFor(String id) =>
      data.operations.values.where((op) => op.scheduleId == id).toList();
  PlannerOperation? pendingFor(String id) =>
      operationsFor(id).where((op) => op.pending).lastOrNull;

  String status(PlannerSchedule schedule) {
    if (schedule.policy == PlannerSyncPolicy.local) return 'On this device';
    final operation = pendingFor(schedule.id);
    if (operation == null) return 'Saved';
    if (operation.state == PlannerOperationState.conflict) {
      return 'Changed in Google Calendar';
    }
    if (operation.state == PlannerOperationState.failed) {
      return 'Couldn’t save — Retry';
    }
    if (operation.kind == PlannerOperationKind.delete &&
        operation.notBefore?.isAfter(reader.now) == true) {
      return 'Deleting — Undo';
    }
    if (operation.state == PlannerOperationState.sending) return 'Saving';
    if (operation.state == PlannerOperationState.checking &&
        connection.operationsEnabled) {
      return 'Checking save…';
    }
    return 'Waiting to sync';
  }

  String? readOnlyReason(CalendarEvent event) {
    if (event.focusOwned) return 'Manage this focus block in Focus blocks.';
    if (scheduleForEvent(event)?.policy == PlannerSyncPolicy.local) return null;
    if (!reader.sources.any(
      (s) => s.id == event.calendarId && s.accessRole == 'owner',
    )) {
      return 'This calendar is view-only in Poma. Editing is available on calendars you own.';
    }
    if (!event.editable) {
      return 'This event is read-only. Open it in Google Calendar for available actions.';
    }
    if (!connection.creationEnabled) {
      return 'Enable calendar editing in Calendar settings.';
    }
    return null;
  }

  List<CalendarEvent> eventsFor(CalendarWindow window) {
    if (!unlocked) return const [];
    final events = <String, CalendarEvent>{};
    if (reader.accountKey == accountKey && accountKey != null) {
      for (final event in reader.eventsFor(window)) {
        events[calendarEventIdentity(event)] = event;
      }
    }
    for (final schedule in data.schedules.values) {
      if (schedule.policy == PlannerSyncPolicy.google &&
          schedule.accountKey != accountKey) {
        continue;
      }
      if (schedule.masterId != null &&
          data.schedules.values.any(
            (parent) => parent.eventId == schedule.masterId && parent.removed,
          )) {
        continue;
      }
      final operation = pendingFor(schedule.id);
      if (schedule.removed) {
        events.removeWhere(
          (_, event) =>
              event.calendarId == schedule.calendarId &&
              (event.id == schedule.eventId ||
                  event.recurringEventId == schedule.eventId),
        );
        continue;
      }
      if (schedule.policy != PlannerSyncPolicy.local && operation == null) {
        continue;
      }
      final exceptions = data.schedules.values
          .where(
            (other) =>
                other.masterId == schedule.eventId &&
                other.originalStart != null,
          )
          .toList();
      final provisional = plannerOccurrences(schedule, window).where(
        (event) => !exceptions.any(
          (other) =>
              DateTime.tryParse(other.originalStart!)?.toUtc() ==
              event.startUtc,
        ),
      );
      if (schedule.recurring &&
          schedule.policy == PlannerSyncPolicy.google &&
          operation?.kind != PlannerOperationKind.create) {
        continue;
      }
      for (final event in provisional) {
        events.removeWhere(
          (_, old) => old.calendarId == event.calendarId && old.id == event.id,
        );
        events[calendarEventIdentity(event)] = event;
      }
    }
    return events.values.toList()..sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      return a.allDay
          ? a.title.compareTo(b.title)
          : a.startUtc!.compareTo(b.startUtc!);
    });
  }

  List<PlannerGap> gaps(CalendarWindow window, {DateTime? after}) {
    final intervals = [...reader.eventsFor(window), ...eventsFor(window)];
    // Keep both sides of an unconfirmed move and the old interval of a deletion.
    for (final schedule in data.schedules.values.where(
      (s) => pendingFor(s.id) != null,
    )) {
      if (schedule.accountKey == accountKey ||
          schedule.policy == PlannerSyncPolicy.local) {
        intervals.addAll(plannerOccurrences(schedule, window));
      }
      if (schedule.baseline.isNotEmpty && schedule.accountKey == accountKey) {
        intervals.addAll(
          plannerOccurrences(
            schedule.copyWith(fields: schedule.baseline, removed: false),
            window,
          ),
        );
      }
    }
    return plannerGaps(
      intervals,
      window,
      verified: reader.rangeVerified(window, availability: true),
      after: after,
      midnight: (day) => reader.clock.dayWindow(day).startUtc,
    );
  }

  Future<void> enableSync() async {
    if (!unlocked) return;
    if (!connection.creationEnabled) await connection.enableCreation();
    if (!connection.creationEnabled || !unlocked || accountKey == null) return;
    await setPreferences(preferences.copyWith(syncEnabled: true));
  }

  Future<void> setPreferences(PlannerPreferences value) async {
    final key = accountKey ?? 'device';
    await _change(
      (current) =>
          current.copyWith(preferences: {...current.preferences, key: value}),
    );
    if (value.syncEnabled) unawaited(sync());
  }

  Future<Map<String, dynamic>> beginDraft({
    DateTime? startUtc,
    DateTime? endUtc,
    FocusTask? task,
    bool scheduled = true,
    String? restoreId,
  }) async {
    await time.initialize();
    if (restoreId != null && data.drafts[restoreId] != null) {
      draft = plannerJsonCopy(data.drafts[restoreId]!);
      errors = {};
      ambiguousTimes = {};
      _notify();
      return draft!;
    }
    final existing = task == null ? null : taskSchedule(task.id);
    if (existing != null) return editSchedule(existing);
    final zoneName = await time.deviceZone();
    final zone = zoneName == null ? null : tz.getLocation(zoneName);
    final current = reader.now.toLocal();
    final first =
        startUtc ??
        (selectedDate.toString() == plannerDate(current)
            ? DateTime(
                current.year,
                current.month,
                current.day,
                current.hour,
                ((current.minute ~/ 5) + 1) * 5,
              ).toUtc()
            : DateTime(
                selectedDate.year,
                selectedDate.month,
                selectedDate.day,
                half == 1 ? 13 : 9,
              ).toUtc());
    final last =
        endUtc ?? first.add(Duration(minutes: preferences.durationMinutes));
    final start = zone == null
        ? first.toLocal()
        : tz.TZDateTime.from(first, zone);
    final end = zone == null ? last.toLocal() : tz.TZDateTime.from(last, zone);
    draft = {
      'id': newPlannerId(),
      'title': task?.title ?? '',
      'taskId': task?.id,
      'scheduled': scheduled,
      'date': plannerDate(start),
      'endDate': plannerDate(end),
      'start': plannerTime(start),
      'end': plannerTime(end),
      'startChoice': start.toUtc().toIso8601String(),
      'endChoice': end.toUtc().toIso8601String(),
      'zone': zoneName,
      'accountKey': accountKey,
      'calendarId':
          preferences.calendarId ??
          reader.sources
              .where((s) => s.accessRole == 'owner' && s.primary)
              .firstOrNull
              ?.id,
      'localOnly': !preferences.syncEnabled,
      'makeDefault': false,
      'busy': true,
      'repeat': PlannerRepeat.none.name,
      'interval': 1,
      'weekdays': [start.weekday],
      'ending': 'never',
    };
    errors = {};
    ambiguousTimes = {};
    message = null;
    _notify();
    return draft!;
  }

  Map<String, dynamic> editSchedule(PlannerSchedule schedule) {
    final zone = tz.getLocation(schedule.zone);
    final start = schedule.startUtc == null
        ? null
        : tz.TZDateTime.from(schedule.startUtc!, zone);
    final end = schedule.endUtc == null
        ? null
        : tz.TZDateTime.from(schedule.endUtc!, zone);
    final repeat = PlannerRecurrence.parse(
      schedule.fields['recurrence'] as List? ?? [],
      zone,
    );
    draft = {
      'id': newPlannerId(),
      'scheduleId': schedule.id,
      'taskId': schedule.taskId,
      'standalone': schedule.taskId == null,
      'title': schedule.title,
      'scheduled': true,
      'date': start == null
          ? (schedule.fields['start'] as Map)['date']
          : plannerDate(start),
      'endDate': end == null
          ? (schedule.fields['end'] as Map)['date']
          : plannerDate(end),
      'allDay': start == null,
      'start': start == null ? '09:00' : plannerTime(start),
      'end': end == null ? '10:00' : plannerTime(end),
      'zone': schedule.zone,
      'accountKey': schedule.accountKey,
      'calendarId': schedule.calendarId,
      'localOnly': schedule.policy == PlannerSyncPolicy.local,
      'busy': schedule.fields['transparency'] != 'transparent',
      'colorId': schedule.fields['colorId'],
      'baseFields': schedule.baseline,
      'baseEtag': schedule.etag,
      'eventId': schedule.eventId,
      'repeat': repeat?.repeat.name ?? 'unsupported',
      'interval': repeat?.interval ?? 1,
      'weekdays': repeat?.weekdays ?? [],
      'ending': repeat?.count != null
          ? 'count'
          : repeat?.until != null
          ? 'date'
          : 'never',
      'count': repeat?.count?.toString() ?? '',
      'until': repeat?.until?.toString() ?? '',
      'rawRecurrence': schedule.fields['recurrence'] ?? <String>[],
      'originalDate': start == null
          ? (schedule.fields['start'] as Map)['date']
          : plannerDate(start),
      'originalEndDate': end == null
          ? (schedule.fields['end'] as Map)['date']
          : plannerDate(end),
      'originalStartText': start == null ? '09:00' : plannerTime(start),
      'originalEndText': end == null ? '10:00' : plannerTime(end),
      'originalZone': schedule.zone,
      'startChoice': schedule.startUtc?.toIso8601String(),
      'endChoice': schedule.endUtc?.toIso8601String(),
    };
    draft!['repeatBaseline'] = {
      for (final key in _repeatFields) key: draft![key],
    };
    errors = {};
    ambiguousTimes = {};
    message = null;
    _notify();
    return draft!;
  }

  Map<String, dynamic> _eventFields(CalendarEvent event) => {
    'summary': event.title,
    'colorId': event.colorId,
    'transparency': event.transparency ?? 'opaque',
    'recurrence': <String>[],
    'start': event.allDay
        ? {'date': event.startDate.toString()}
        : {
            'dateTime': event.startUtc!.toIso8601String(),
            'timeZone': event.startZone ?? 'Etc/UTC',
          },
    'end': event.allDay
        ? {'date': event.endDate.toString()}
        : {
            'dateTime': event.endUtc!.toIso8601String(),
            'timeZone': event.endZone ?? event.startZone ?? 'Etc/UTC',
          },
  };

  Future<Map<String, dynamic>?> editEvent(
    CalendarEvent event, {
    bool series = false,
  }) async {
    if (readOnlyReason(event) != null) {
      message = readOnlyReason(event);
      _notify();
      return null;
    }
    final epoch = _epoch, account = accountKey;
    final existing = scheduleForEvent(event);
    if (existing?.policy == PlannerSyncPolicy.local) {
      if (event.recurringEventId == null ||
          series ||
          existing!.masterId != null) {
        return editSchedule(existing!);
      }
      final exception = PlannerSchedule(
        id: newPlannerId(),
        calendarId: event.calendarId,
        eventId: event.id,
        masterId: event.recurringEventId,
        originalStart: event.originalStart,
        fields: _eventFields(event),
      );
      final value = editSchedule(exception);
      value['managedSchedule'] = exception.toJson();
      value['recurringScope'] = 'occurrence';
      return value;
    }
    final target = series ? event.recurringEventId ?? event.id : event.id;
    PlannerRemoteEvent? remote;
    try {
      remote = await writer.get(accountKey!, event.calendarId, target);
    } on PlannerFailure catch (e) {
      if (series) {
        message = e.message;
        _notify();
        return null;
      }
    }
    if (!unlocked ||
        accountKey == null ||
        accountKey != account ||
        _epoch != epoch) {
      return null;
    }
    if (remote != null && !remote.editable) {
      message = 'This event is read-only.';
      _notify();
      return null;
    }
    final match = data.schedules.values
        .where(
          (s) =>
              s.accountKey == accountKey &&
              s.calendarId == event.calendarId &&
              s.eventId == target,
        )
        .firstOrNull;
    final schedule =
        match ??
        PlannerSchedule(
          id: newPlannerId(),
          accountKey: accountKey,
          calendarId: event.calendarId,
          eventId: target,
          originalStart: series ? null : event.originalStart,
          masterId: event.recurringEventId,
          policy: PlannerSyncPolicy.google,
          fields: remote?.fields ?? _eventFields(event),
          baseline: remote?.fields ?? _eventFields(event),
          etag: remote?.etag ?? event.etag,
        );
    final reviewed = schedule.copyWith(
      fields: remote?.fields,
      baseline: remote?.fields,
      etag: remote?.etag,
    );
    final result = editSchedule(reviewed);
    result['scheduleId'] = schedule.id;
    result['standalone'] = schedule.taskId == null;
    result['managedSchedule'] = reviewed.toJson();
    result['recurringScope'] = series
        ? 'series'
        : event.recurringEventId == null
        ? null
        : 'occurrence';
    result['hasGuests'] = remote == null
        ? event.hasGuests
        : (remote.value['attendees'] as List? ?? []).isNotEmpty ||
              remote.value['attendeesOmitted'] == true;
    return result;
  }

  Future<bool> keepDraft(Map<String, dynamic> value) => _change(
    (current) => current.copyWith(
      drafts: {
        ...current.drafts,
        value['id'] as String: plannerJsonCopy(value),
      },
    ),
  );
  Future<void> discardDraft(String id) async {
    await _change(
      (current) => current.copyWith(drafts: {...current.drafts}..remove(id)),
    );
    if (draft?['id'] == id) draft = null;
    _notify();
  }

  void updatePreview(Map<String, dynamic> value) {
    draft = plannerJsonCopy(value);
    _notify();
  }

  CalendarEvent? preview(Map<String, dynamic> value) {
    if (value['scheduled'] != true || value['allDay'] == true) return null;
    try {
      final zone = tz.getLocation(value['zone'] as String);
      final starts = plannerResolveWall(
        zone,
        _wall(value['date'] as String, value['start'] as String),
      );
      final ends = plannerResolveWall(
        zone,
        _wall(value['endDate'] as String, value['end'] as String),
      );
      if (starts.isEmpty || ends.isEmpty) return null;
      final start =
          starts
              .where((t) => t.toUtc().toIso8601String() == value['startChoice'])
              .firstOrNull ??
          (starts.length == 1 ? starts.first : null);
      final end =
          ends
              .where((t) => t.toUtc().toIso8601String() == value['endChoice'])
              .firstOrNull ??
          (ends.length == 1 ? ends.first : null);
      if (start == null || end == null || !end.isAfter(start)) return null;
      return CalendarEvent(
        id: 'draft/${value['id']}',
        calendarId: 'poma-draft',
        title: 'Draft · ${value['title'] ?? ''}',
        status: 'tentative',
        selfResponse: 'accepted',
        startUtc: plannerUtcInstant(start),
        endUtc: plannerUtcInstant(end),
        transparency: 'transparent',
      );
    } catch (_) {
      return null;
    }
  }

  DateTime _wall(String date, String text) {
    final day = CalendarDate.parse(date);
    final match = RegExp(
      r'^\s*(\d{1,2}):(\d{2})\s*([AaPp][Mm])?\s*$',
    ).firstMatch(text);
    if (match == null) {
      throw const FormatException('Use a time such as 22:00 or 10:00 PM.');
    }
    var hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    final period = match[3]?.toUpperCase();
    if (minute > 59 ||
        period == null && hour > 23 ||
        period != null && (hour < 1 || hour > 12)) {
      throw const FormatException('Enter a valid hour and minute.');
    }
    if (period != null) hour = hour % 12 + (period == 'PM' ? 12 : 0);
    return DateTime.utc(day.year, day.month, day.day, hour, minute);
  }

  Map<String, dynamic>? validate(Map<String, dynamic> value) {
    errors = {};
    ambiguousTimes = {};
    final title = (value['title'] as String? ?? '').trim();
    final standalone = value['standalone'] == true;
    if (title.isEmpty || !standalone && title.length > 160) {
      errors['title'] = standalone
          ? 'Enter an event title.'
          : 'Enter a task title of 1–160 characters.';
    }
    if (value['scheduled'] != true) {
      return errors.isEmpty ? {'summary': title} : null;
    }
    tz.Location? zone;
    try {
      zone = tz.getLocation(value['zone'] as String);
    } catch (_) {
      errors['zone'] = 'Choose the timezone for this task.';
    }
    Map<String, dynamic>? endpoint(String key, String date) {
      try {
        final originalDate = key == 'start'
            ? value['originalDate']
            : value['originalEndDate'];
        final originalTime = key == 'start'
            ? value['originalStartText']
            : value['originalEndText'];
        final baseline = (value['baseFields'] as Map?)?[key] as Map?;
        if (baseline != null &&
            date == originalDate &&
            value[key] == originalTime &&
            value['zone'] == value['originalZone']) {
          return plannerJsonCopy(baseline);
        }
        if (value['allDay'] == true) {
          return {'date': CalendarDate.parse(date).toString()};
        }
        if (zone == null) return null;
        final wall = _wall(date, value[key] as String);
        final choices = plannerResolveWall(zone, wall);
        if (choices.isEmpty) {
          errors[key] =
              'This time is skipped by daylight saving. Choose a valid time.';
          return null;
        }
        final selected = choices
            .where((t) => t.toUtc().toIso8601String() == value['${key}Choice'])
            .firstOrNull;
        if (choices.length > 1 && selected == null) {
          ambiguousTimes[key] = choices.map((t) => t.toUtc()).toList();
          errors[key] = 'This time occurs twice. Choose the intended offset.';
          return null;
        }
        return {
          'dateTime': (selected ?? choices.first).toUtc().toIso8601String(),
          'timeZone': zone.name,
        };
      } catch (_) {
        errors[key] = 'Enter a real date and time, such as 22:00 or 10:00 PM.';
        return null;
      }
    }

    final start = endpoint('start', value['date'] as String? ?? '');
    final end = endpoint('end', value['endDate'] as String? ?? '');
    if (start != null && end != null) {
      final a = DateTime.parse((start['dateTime'] ?? start['date']) as String);
      final b = DateTime.parse((end['dateTime'] ?? end['date']) as String);
      if (!b.isAfter(a)) {
        errors['end'] =
            'End must be after start. Choose the next end date for an overnight task.';
      }
    }
    final local = value['localOnly'] == true;
    if (!local) {
      final linked = data.schedules[value['scheduleId']];
      final quarantined =
          linked?.policy == PlannerSyncPolicy.google &&
          linked!.accountKey != accountKey &&
          value['accountKey'] == linked.accountKey &&
          value['calendarId'] == linked.calendarId &&
          value['eventId'] == linked.eventId;
      if (!quarantined &&
          (accountKey == null || value['accountKey'] != accountKey)) {
        errors['calendarId'] =
            'Use the original connected account for this task.';
      }
      if (!quarantined &&
          !reader.sources.any(
            (s) => s.id == value['calendarId'] && s.accessRole == 'owner',
          )) {
        errors['calendarId'] = 'Choose an owned Google calendar.';
      }
    }
    if (value['colorId'] != null &&
        reader.palette?.colors.containsKey(value['colorId']) != true &&
        value['colorId'] != (value['baseFields'] as Map?)?['colorId']) {
      errors['colorId'] = 'Choose an available Google color.';
    }
    List<String> recurrence = [];
    try {
      if (value['repeat'] == 'unsupported' ||
          value['repeatBaseline'] != null &&
              plannerValueEquals(value['repeatBaseline'], {
                for (final key in _repeatFields) key: value[key],
              })) {
        recurrence = List<String>.from(value['rawRecurrence'] as List? ?? []);
      } else if (zone != null) {
        final repeat = PlannerRepeat.values.byName(
          value['repeat'] as String? ?? 'none',
        );
        final until = value['ending'] == 'date'
            ? CalendarDate.parse(value['until'] as String? ?? '')
            : null;
        if (until != null &&
            until.compareTo(CalendarDate.parse(value['date'] as String)) < 0) {
          throw const FormatException('End date precedes start.');
        }
        recurrence = PlannerRecurrence(
          repeat: repeat,
          interval: value['interval'] as int? ?? 1,
          weekdays: List<int>.from(value['weekdays'] as List? ?? []),
          until: until,
          count: value['ending'] == 'count'
              ? int.parse(value['count'] as String? ?? '')
              : null,
        ).rule(zone, allDay: value['allDay'] == true);
      }
    } catch (_) {
      errors['repeat'] =
          'Choose repeat days, a positive interval, and a valid ending.';
    }
    if (errors.isNotEmpty || start == null || end == null) {
      _notify();
      return null;
    }
    return {
      'summary': title,
      'start': start,
      'end': end,
      'colorId': value['colorId'],
      'transparency': value['busy'] == false ? 'transparent' : 'opaque',
      'recurrence': recurrence,
    };
  }

  Future<bool> saveDraft(Map<String, dynamic> value) async {
    if (saving) return false;
    saving = true;
    _notify();
    try {
      return await _saveDraft(value);
    } finally {
      saving = false;
      _notify();
    }
  }

  Future<bool> _saveDraft(Map<String, dynamic> value) async {
    if (!unlocked) return false;
    final fields = validate(value);
    if (fields == null) return false;
    final scheduled = value['scheduled'] == true;
    final standalone = value['standalone'] == true;
    final taskId = standalone
        ? null
        : (value['taskId'] ??= newLocalId()) as String;
    final task = taskId == null
        ? null
        : FocusTask(
            id: taskId,
            title: fields['summary'] as String,
            done:
                app.tasks.where((t) => t.id == taskId).firstOrNull?.done ??
                false,
          );
    if (!scheduled) {
      final previous = taskId == null ? null : taskSchedule(taskId);
      if (previous != null) return removeSchedule(previous, title: task?.title);
      final saved = await _change(
        (current) =>
            current.copyWith(drafts: {...current.drafts}..remove(value['id'])),
        tasks: task == null ? [] : [task],
      );
      if (saved) draft = null;
      return saved;
    }
    final existing =
        data.schedules[value['scheduleId'] ?? value['newScheduleId']] ??
        (value['managedSchedule'] == null
            ? null
            : PlannerSchedule.fromJson(value['managedSchedule'] as Map));
    final id =
        existing?.id ?? (value['newScheduleId'] ??= newPlannerId()) as String;
    final policy = value['localOnly'] == true
        ? PlannerSyncPolicy.local
        : PlannerSyncPolicy.google;
    final schedule = PlannerSchedule(
      id: id,
      taskId: taskId,
      accountKey: policy == PlannerSyncPolicy.google
          ? value['accountKey'] as String?
          : existing?.accountKey,
      calendarId: value['calendarId'] as String? ?? existing?.calendarId,
      eventId: existing?.eventId ?? plannerEventId(id),
      etag: value['baseEtag'] as String? ?? existing?.etag,
      originalStart: existing?.originalStart,
      masterId: existing?.masterId,
      policy: policy,
      fields: fields,
      baseline: plannerJsonCopy(
        value['baseFields'] as Map? ?? existing?.baseline ?? {},
      ),
    );
    final saved = await _change((current) {
      var next = current.copyWith(
        schedules: {...current.schedules, id: schedule},
        drafts: {...current.drafts}..remove(value['id']),
      );
      if (policy == PlannerSyncPolicy.google) {
        next = _queue(
          next,
          schedule,
          schedule.baseline.isEmpty
              ? PlannerOperationKind.create
              : PlannerOperationKind.update,
          automatic: !standalone,
        );
      }
      final prefKey = accountKey ?? 'device';
      final duration = schedule.endUtc
          ?.difference(schedule.startUtc!)
          .inMinutes;
      final pref = next.preferences[prefKey] ?? const PlannerPreferences();
      next = next.copyWith(
        preferences: {
          ...next.preferences,
          prefKey: pref.copyWith(
            calendarId: value['makeDefault'] == true
                ? schedule.calendarId
                : null,
            durationMinutes:
                existing == null &&
                    duration != null &&
                    duration > 0 &&
                    value['rememberDuration'] != false
                ? duration
                : null,
          ),
        },
      );
      return next;
    }, tasks: task == null ? [] : [task]);
    if (!saved) return false;
    if (existing != null &&
        policy == PlannerSyncPolicy.local &&
        existing.policy == PlannerSyncPolicy.local) {
      _localUndo[id] = (existing.fields, schedule.fields);
    }
    draft = null;
    final instant = schedule.startUtc?.toLocal();
    if (instant != null) {
      browse(
        CalendarDate(instant.year, instant.month, instant.day),
        selectedHalf: instant.hour < 12 ? 0 : 1,
        identity: calendarEventIdentity(
          CalendarEvent(
            id: schedule.eventId!,
            calendarId: schedule.calendarId ?? 'poma-local',
            title: schedule.title,
            status: 'confirmed',
            selfResponse: 'accepted',
            startUtc: schedule.startUtc,
            endUtc: schedule.endUtc,
          ),
        ),
      );
      _saveViews[id] = _viewRevision;
      _saveSelections[id] = reader.selectionRevision;
    }
    message = policy == PlannerSyncPolicy.local
        ? 'Saved on this device.'
        : 'Task saved. Waiting to sync.';
    _notify();
    unawaited(sync());
    return true;
  }

  PlannerData _queue(
    PlannerData current,
    PlannerSchedule schedule,
    PlannerOperationKind kind, {
    bool automatic = true,
    DateTime? notBefore,
  }) {
    final operations = {...current.operations};
    final pending = operations.values
        .where((op) => op.scheduleId == schedule.id && op.pending)
        .toList();
    final deleting = kind == PlannerOperationKind.delete;
    final replace = deleting
        ? null
        : pending
              .where(
                (op) => !op.attempted && op.kind != PlannerOperationKind.delete,
              )
              .lastOrNull;
    final predecessor = deleting
        ? pending.lastOrNull
        : pending.where((op) => op.attempted).lastOrNull;
    if (replace != null) operations.remove(replace.id);
    // Once a create has been attempted, subsequent edits must wait for its
    // acknowledgement and then update that identity with the new fields.
    final effectiveKind =
        kind == PlannerOperationKind.create &&
            predecessor?.kind == PlannerOperationKind.create
        ? PlannerOperationKind.update
        : replace?.kind == PlannerOperationKind.create
        ? PlannerOperationKind.create
        : kind;
    final operation = PlannerOperation(
      id: replace?.id ?? newPlannerId(),
      scheduleId: schedule.id,
      accountKey: schedule.accountKey!,
      calendarId: schedule.calendarId!,
      eventId: schedule.eventId!,
      kind: effectiveKind,
      fields: schedule.fields,
      baseFields: schedule.baseline,
      baseEtag: schedule.etag,
      automatic: automatic,
      notBefore: notBefore,
      dependsOn: predecessor?.id,
    );
    operations[operation.id] = operation;
    return current.copyWith(operations: operations);
  }

  bool _eligible(PlannerOperation op) =>
      op.pending &&
      !const {
        PlannerOperationState.failed,
        PlannerOperationState.conflict,
      }.contains(op.state) &&
      op.accountKey == accountKey &&
      (!op.automatic || data.preferences[op.accountKey]?.syncEnabled == true) &&
      (!op.legacy || _legacyRetries.contains(op.id)) &&
      (op.dependsOn == null ||
          data.operations[op.dependsOn]?.state == PlannerOperationState.saved);

  Future<void> sync() {
    if (_draining != null) return _draining!;
    final epoch = _epoch;
    final result = _drain();
    _draining = result;
    return result.whenComplete(() {
      if (identical(_draining, result)) _draining = null;
      if (!_disposed && unlocked && epoch != _epoch) {
        scheduleMicrotask(() => unawaited(sync()));
      }
    });
  }

  Future<void> _drain() async {
    _wake?.cancel();
    _wake = null;
    await _changes;
    if (!unlocked ||
        _resetting ||
        app.saveError != null ||
        !connection.operationsEnabled ||
        !connection.creationEnabled) {
      return;
    }
    final epoch = _epoch;
    while (unlocked &&
        epoch == _epoch &&
        !app.cleanupPending &&
        app.saveError == null) {
      final pending = data.operations.values.where(_eligible).toList();
      final now = reader.now;
      final operation = pending
          .where(
            (op) =>
                (op.notBefore == null || !op.notBefore!.isAfter(now)) &&
                (op.retryAt == null || !op.retryAt!.isAfter(now)),
          )
          .firstOrNull;
      if (operation == null) {
        final times =
            pending
                .expand((op) => [op.notBefore, op.retryAt])
                .whereType<DateTime>()
                .where((t) => t.isAfter(now))
                .toList()
              ..sort();
        if (times.isNotEmpty) {
          _wake = reader.scheduler.after(
            times.first.difference(now),
            () => unawaited(sync()),
          );
        }
        return;
      }
      await _send(operation, epoch);
    }
  }

  Future<void> _record(PlannerOperation operation) async {
    await _change(
      (current) => current.copyWith(
        operations: {...current.operations, operation.id: operation},
      ),
    );
  }

  Future<void> _send(PlannerOperation operation, int epoch) async {
    bool current() =>
        !_disposed &&
        unlocked &&
        epoch == _epoch &&
        accountKey == operation.accountKey &&
        !app.cleanupPending;
    try {
      if (!await writer.validateDestination(
        operation.accountKey,
        operation.calendarId,
      )) {
        throw const PlannerFailure(
          PlannerFailureKind.permission,
          'The original owned calendar is unavailable. Choose a calendar after resolving this save.',
        );
      }
      if (!current() ||
          !_eligible(data.operations[operation.id] ?? operation)) {
        return;
      }
      final latest = await writer.get(
        operation.accountKey,
        operation.calendarId,
        operation.eventId,
      );
      if (!current()) return;
      if (operation.kind == PlannerOperationKind.create) {
        if (latest != null) {
          final marker =
              latest.privateProperties[operation.legacy
                  ? 'pomaDayClockOperation'
                  : 'pomaPlannerSchedule'];
          if (latest.deleted ||
              latest.focusOwned ||
              operation.legacy &&
                  latest.privateProperties['pomaDayClockPayloadHash'] !=
                      operation.legacyReceipt?['payloadHash'] ||
              marker !=
                  (operation.legacy ? operation.id : operation.scheduleId)) {
            throw const PlannerFailure(
              PlannerFailureKind.conflict,
              'The original event was changed or removed. Review it before continuing.',
            );
          }
          await _acknowledge(operation, latest, current);
          return;
        }
      } else {
        if (latest == null || latest.deleted) {
          if (operation.kind == PlannerOperationKind.delete) {
            await _acknowledge(operation, null, current);
            return;
          }
          throw const PlannerFailure(
            PlannerFailureKind.deleted,
            'Removed in Google Calendar. Your task is kept without recreating the event.',
          );
        }
        if (latest.privateProperties['pomaPlannerOperation'] == operation.id) {
          await _acknowledge(operation, latest, current);
          return;
        }
        if (!latest.editable) {
          throw const PlannerFailure(
            PlannerFailureKind.permission,
            'This event is read-only. Manage focus blocks in Focus blocks.',
          );
        }
      }
      Map<String, dynamic>? patch;
      if (operation.kind == PlannerOperationKind.update) {
        patch = plannerMergePatch(
          operation.baseFields,
          operation.fields,
          latest!.fields,
        );
        if (patch == null) {
          throw const PlannerFailure(
            PlannerFailureKind.conflict,
            'Changed in Google Calendar. Review your changes.',
          );
        }
        if (patch.isEmpty) {
          await _acknowledge(operation, latest, current);
          return;
        }
      }
      if (operation.kind == PlannerOperationKind.delete &&
          operation.baseEtag != null &&
          latest!.etag != operation.baseEtag) {
        throw const PlannerFailure(
          PlannerFailureKind.conflict,
          'Changed in Google Calendar. Review before deleting.',
        );
      }
      final sending = operation.copyWith(
        state: PlannerOperationState.sending,
        attempted: true,
        attempts: operation.attempts + 1,
        clearRetry: true,
        clearMessage: true,
      );
      await _record(sending);
      if (!current() ||
          app.saveError != null ||
          !_eligible(data.operations[operation.id] ?? sending)) {
        return;
      }
      PlannerRemoteEvent? result;
      switch (operation.kind) {
        case PlannerOperationKind.create:
          result = await writer.create(sending);
        case PlannerOperationKind.update:
          result = await writer.update(sending, latest!, patch!);
        case PlannerOperationKind.delete:
          await writer.delete(sending, latest!);
      }
      if (!current()) return;
      await _acknowledge(sending, result, current);
    } on PlannerFailure catch (failure) {
      if (!current()) return;
      if (data.operations[operation.id]?.terminal == true) return;
      if (failure.kind == PlannerFailureKind.precondition &&
          (data.operations[operation.id]?.attempts ?? 0) < 3) {
        await _record(
          (data.operations[operation.id] ?? operation).copyWith(
            state: PlannerOperationState.checking,
            clearRetry: true,
            message: 'Checking changes in Google Calendar…',
          ),
        );
        return;
      }
      if (failure.kind == PlannerFailureKind.deleted &&
          operation.kind != PlannerOperationKind.delete) {
        await _change(
          (value) => value.copyWith(
            schedules: {
              ...value.schedules,
              operation.scheduleId: value.schedules[operation.scheduleId]!
                  .copyWith(removed: true),
            },
          ),
        );
      }
      final actual = data.operations[operation.id] ?? operation;
      final transient =
          failure.kind == PlannerFailureKind.network ||
          failure.kind == PlannerFailureKind.cancelled;
      final attempts = actual.attempts + (actual.attempted ? 0 : 1);
      final delay = Duration(
        seconds:
            math.min(300, 2 << math.min(attempts, 7)) +
            math.Random().nextInt(3),
      );
      await _record(
        actual.copyWith(
          state:
              failure.kind == PlannerFailureKind.conflict ||
                  failure.kind == PlannerFailureKind.precondition
              ? PlannerOperationState.conflict
              : transient
              ? (actual.attempted || failure.uncertain
                    ? PlannerOperationState.checking
                    : PlannerOperationState.queued)
              : PlannerOperationState.failed,
          attempts: attempts,
          retryAt: transient ? failure.retryAt ?? reader.now.add(delay) : null,
          message: failure.message,
        ),
      );
      message = failure.message;
    } catch (_) {
      if (data.operations[operation.id]?.terminal == true) return;
      if (current()) {
        await _record(
          (data.operations[operation.id] ?? operation).copyWith(
            state: PlannerOperationState.checking,
            retryAt: reader.now.add(const Duration(seconds: 30)),
            message:
                'Waiting to sync. The original event will be checked before retrying.',
          ),
        );
      }
    }
  }

  Future<void> _acknowledge(
    PlannerOperation operation,
    PlannerRemoteEvent? remote,
    bool Function() current,
  ) async {
    if (!current()) return;
    final saved = await _change(
      (value) {
        final schedule = value.schedules[operation.scheduleId]!;
        final successors = value.operations.values.where(
          (op) => op.dependsOn == operation.id && op.pending,
        );
        final operations = {
          ...value.operations,
          operation.id: operation.copyWith(
            state: PlannerOperationState.saved,
            clearRetry: true,
            clearMessage: true,
          ),
        };
        for (final next in successors) {
          operations[next.id] = next.copyWith(
            baseEtag: remote?.etag,
            baseFields: remote?.fields,
          );
        }
        return value.copyWith(
          operations: operations,
          schedules: {
            ...value.schedules,
            schedule.id: schedule.copyWith(
              baseline: remote?.fields ?? schedule.baseline,
              etag: remote?.etag,
              fields: successors.isEmpty && !schedule.removed && remote != null
                  ? remote.fields
                  : schedule.fields,
            ),
          },
        );
      },
      deriveTasks: (value) {
        final schedule = value.schedules[operation.scheduleId];
        final hasSuccessor = value.operations.values.any(
          (next) => next.dependsOn == operation.id && next.pending,
        );
        final task = app.tasks
            .where((task) => task.id == schedule?.taskId)
            .firstOrNull;
        final title = remote?.deleted == false
            ? remote!.fields['summary'] as String?
            : null;
        return schedule?.removed == false &&
                !hasSuccessor &&
                task != null &&
                title != null &&
                title.isNotEmpty &&
                title.length <= 160 &&
                task.title != title
            ? [task.copyWith(title: title)]
            : [];
      },
    );
    if (!saved || !current()) return;
    final series =
        (operation.fields['recurrence'] as List? ?? []).isNotEmpty ||
        (operation.baseFields['recurrence'] as List? ?? []).isNotEmpty;
    try {
      await reader.acceptMutation(
        operation.calendarId,
        operation.eventId,
        event: remote?.event,
        series: series,
      );
      if (!current()) return;
      final reveal =
          _saveViews[operation.scheduleId] == _viewRevision &&
          _saveSelections[operation.scheduleId] == reader.selectionRevision &&
          pendingFor(operation.scheduleId) == null &&
          operation.kind != PlannerOperationKind.delete;
      if (reveal && !reader.selected.contains(operation.calendarId)) {
        await reader.includeForReveal(
          operation.accountKey,
          operation.calendarId,
          current: () =>
              current() && _saveViews[operation.scheduleId] == _viewRevision,
        );
      }
      if (!current()) return;
      final stamp = (remote?.fields ?? operation.fields)['start'] as Map?;
      final local = DateTime.tryParse(
        stamp?['dateTime'] as String? ?? '',
      )?.toLocal();
      final date = local == null
          ? CalendarDate.parse(
              stamp?['date'] as String? ?? selectedDate.toString(),
            )
          : CalendarDate(local.year, local.month, local.day);
      final affected = range(date, date.plusDays(1));
      await reader.ensureRange(affected, force: true);
      if (!current()) return;
      if (reveal && _saveViews[operation.scheduleId] == _viewRevision) {
        final event = eventsFor(affected)
            .where(
              (event) =>
                  event.calendarId == operation.calendarId &&
                  (event.id == operation.eventId ||
                      series && event.recurringEventId == operation.eventId),
            )
            .firstOrNull;
        browse(
          date,
          selectedHalf: local == null || local.hour < 12 ? 0 : 1,
          identity: event == null
              ? selectedIdentity
              : calendarEventIdentity(event),
        );
      }
    } catch (_) {
      // The durable acknowledgement remains Saved when presentation refresh fails.
    }
    message = operation.kind == PlannerOperationKind.delete
        ? 'Deleted.'
        : 'Saved to Google Calendar.';
    _notify();
  }

  Future<void> retry(String id) async {
    final op = data.operations[id];
    if (op == null || op.terminal) return;
    if (op.legacy) _legacyRetries.add(id);
    await _record(
      op.copyWith(state: PlannerOperationState.checking, clearRetry: true),
    );
    unawaited(sync());
  }

  Future<void> resolveConflict(String id, {required bool useGoogle}) async {
    if (!useGoogle) {
      await reviewConflict(id);
      return;
    }
    final op = data.operations[id];
    if (op == null || op.accountKey != accountKey || !unlocked) return;
    final epoch = _epoch;
    try {
      final remote = await writer.get(op.accountKey, op.calendarId, op.eventId);
      if (!unlocked || _epoch != epoch || op.accountKey != accountKey) return;
      if (remote == null || remote.deleted) {
        message = 'This event was removed in Google Calendar.';
        _notify();
        return;
      }
      final schedule = data.schedules[op.scheduleId]!;
      final task = app.tasks
          .where((task) => task.id == schedule.taskId)
          .firstOrNull;
      final title = remote.fields['summary'] as String;
      await _change(
        (current) => current.copyWith(
          operations: {
            for (final entry in current.operations.entries)
              entry.key:
                  entry.value.scheduleId == op.scheduleId && entry.value.pending
                  ? entry.value.copyWith(state: PlannerOperationState.cancelled)
                  : entry.value,
            id: op.copyWith(
              state: PlannerOperationState.cancelled,
              baseEtag: remote.etag,
              baseFields: remote.fields,
              clearRetry: true,
              clearMessage: true,
            ),
          },
          schedules: {
            ...current.schedules,
            op.scheduleId: current.schedules[op.scheduleId]!.copyWith(
              fields: remote.fields,
              baseline: remote.fields,
              etag: remote.etag,
              removed: false,
              clearUndo: true,
            ),
          },
        ),
        tasks:
            schedule.taskId != null && title.isNotEmpty && title.length <= 160
            ? [
                task?.copyWith(title: title) ??
                    FocusTask(
                      id: schedule.taskId!,
                      title: title,
                      done: schedule.deletedTask?['done'] == true,
                    ),
              ]
            : [],
      );
      await reader.acceptMutation(
        op.calendarId,
        op.eventId,
        event: remote.event,
        series: schedule.recurring,
      );
    } on PlannerFailure catch (e) {
      message = e.message;
      _notify();
    }
  }

  Future<bool> moveEvent(
    CalendarEvent event,
    DateTime start,
    DateTime end, {
    bool series = false,
  }) async {
    if (readOnlyReason(event) != null || !end.isAfter(start)) return false;
    final value = await editEvent(event, series: series);
    if (value == null) return false;
    if (series && event.recurringEventId != null) {
      final managed = value['managedSchedule'] == null
          ? data.schedules[value['scheduleId']]
          : PlannerSchedule.fromJson(value['managedSchedule'] as Map);
      if (managed?.startUtc != null && managed?.endUtc != null) {
        start = managed!.startUtc!.add(start.difference(event.startUtc!));
        end = managed.endUtc!.add(end.difference(event.endUtc!));
      }
    }
    final zone = tz.getLocation(value['zone'] as String);
    final a = tz.TZDateTime.from(start, zone),
        b = tz.TZDateTime.from(end, zone);
    value.addAll({
      'date': plannerDate(a),
      'endDate': plannerDate(b),
      'start': plannerTime(a),
      'end': plannerTime(b),
      'startChoice': start.toUtc().toIso8601String(),
      'endChoice': end.toUtc().toIso8601String(),
    });
    return saveDraft(value);
  }

  Future<void> undoChange(String scheduleId) async {
    final schedule = data.schedules[scheduleId];
    final local = _localUndo.remove(scheduleId);
    if (schedule?.policy == PlannerSyncPolicy.local && local != null) {
      await _change((current) {
        final latest = current.schedules[scheduleId];
        if (latest == null || !plannerValueEquals(latest.fields, local.$2)) {
          return current;
        }
        return current.copyWith(
          schedules: {
            ...current.schedules,
            scheduleId: latest.copyWith(fields: local.$1),
          },
        );
      });
      return;
    }
    final previous = operationsFor(scheduleId)
        .where(
          (op) =>
              op.kind == PlannerOperationKind.update &&
              op.state != PlannerOperationState.cancelled,
        )
        .lastOrNull;
    if (schedule == null || previous == null || previous.baseFields.isEmpty) {
      return;
    }
    final title = previous.baseFields['summary'] as String?;
    final task = app.tasks.where((t) => t.id == schedule.taskId).firstOrNull;
    await _change(
      (current) {
        var restored = schedule.copyWith(fields: previous.baseFields);
        var next = current.copyWith(
          schedules: {...current.schedules, scheduleId: restored},
        );
        if (!previous.attempted) {
          next = next.copyWith(
            operations: {
              ...next.operations,
              previous.id: previous.copyWith(
                state: PlannerOperationState.cancelled,
              ),
            },
          );
        } else {
          restored = restored.copyWith(baseline: previous.fields);
          next = next.copyWith(
            schedules: {...next.schedules, scheduleId: restored},
          );
          next = _queue(
            next,
            restored,
            PlannerOperationKind.update,
            automatic: task != null,
          );
        }
        return next;
      },
      tasks: task != null && title != null && title.length <= 160
          ? [task.copyWith(title: title)]
          : [],
    );
    unawaited(sync());
  }

  Future<Map<String, dynamic>?> reviewConflict(String id) async {
    final operation = data.operations[id];
    if (operation == null || operation.accountKey != accountKey || !unlocked) {
      return null;
    }
    final epoch = _epoch;
    try {
      final remote = await writer.get(
        operation.accountKey,
        operation.calendarId,
        operation.eventId,
      );
      if (!unlocked || _epoch != epoch || operation.accountKey != accountKey) {
        return null;
      }
      if (remote == null || remote.deleted) {
        message = 'Removed in Google Calendar. Your task and draft are kept.';
        _notify();
        return null;
      }
      final fields = {...remote.fields};
      final desired =
          pendingFor(operation.scheduleId)?.fields ?? operation.fields;
      for (final key in plannerEditableFields) {
        if (!plannerValueEquals(desired[key], operation.baseFields[key])) {
          fields[key] = desired[key];
        }
      }
      final schedule = data.schedules[operation.scheduleId]!;
      final result = editSchedule(
        schedule.copyWith(
          fields: fields,
          baseline: remote.fields,
          etag: remote.etag,
        ),
      );
      result['managedSchedule'] = schedule
          .copyWith(
            fields: remote.fields,
            baseline: remote.fields,
            etag: remote.etag,
          )
          .toJson();
      final saved = await _change(
        (current) => current.copyWith(
          operations: {
            for (final entry in current.operations.entries)
              entry.key:
                  entry.value.scheduleId == operation.scheduleId &&
                      entry.value.pending
                  ? entry.value.copyWith(state: PlannerOperationState.cancelled)
                  : entry.value,
            id: operation.copyWith(state: PlannerOperationState.cancelled),
          },
          schedules: {
            ...current.schedules,
            schedule.id: schedule.copyWith(
              fields: remote.fields,
              baseline: remote.fields,
              etag: remote.etag,
            ),
          },
          drafts: {...current.drafts, result['id'] as String: result},
        ),
        deriveTasks: (_) {
          final task = app.tasks
              .where((task) => task.id == schedule.taskId)
              .firstOrNull;
          final title = remote.fields['summary'] as String;
          return task != null && title.isNotEmpty && title.length <= 160
              ? [task.copyWith(title: title)]
              : [];
        },
      );
      return saved ? result : null;
    } on PlannerFailure catch (error) {
      message = error.message;
      _notify();
      return null;
    }
  }

  Future<bool> removeSchedule(
    PlannerSchedule schedule, {
    String? title,
    bool deleteTask = false,
  }) async {
    final saved = await _change(
      (current) {
        if (current.schedules[schedule.id]?.removed == true) return current;
        final task = app.tasks
            .where((task) => task.id == schedule.taskId)
            .firstOrNull;
        final removed = schedule.copyWith(
          removed: true,
          undoUntil: reader.now.add(const Duration(seconds: 10)),
          deletedTask: deleteTask && task != null
              ? {'id': task.id, 'title': task.title, 'done': task.done}
              : null,
        );
        var next = current.copyWith(
          schedules: {...current.schedules, schedule.id: removed},
        );
        final pending = current.operations.values
            .where((op) => op.scheduleId == schedule.id && op.pending)
            .toList();
        final unsentCreate = pending.any(
          (op) => op.kind == PlannerOperationKind.create && !op.attempted,
        );
        if (schedule.policy == PlannerSyncPolicy.google && !unsentCreate) {
          next = _queue(
            next,
            removed,
            PlannerOperationKind.delete,
            automatic: schedule.taskId != null,
            notBefore: reader.now.add(const Duration(seconds: 10)),
          );
        } else {
          next = next.copyWith(
            operations: {
              for (final e in next.operations.entries)
                e.key: e.value.scheduleId == schedule.id && e.value.pending
                    ? e.value.copyWith(state: PlannerOperationState.cancelled)
                    : e.value,
            },
          );
        }
        return next;
      },
      deletedTasks: deleteTask && schedule.taskId != null
          ? [schedule.taskId!]
          : [],
      tasks: !deleteTask && title != null && schedule.taskId != null
          ? [
              app.tasks
                  .firstWhere((t) => t.id == schedule.taskId)
                  .copyWith(title: title),
            ]
          : [],
    );
    if (saved) {
      message = 'Schedule removed. Undo is available before deletion is sent.';
      _notify();
      unawaited(sync());
    }
    return saved;
  }

  Future<bool> deleteEvent(CalendarEvent event, {bool series = false}) async {
    final value = await editEvent(event, series: series);
    if (value == null) return false;
    final schedule = value['managedSchedule'] == null
        ? data.schedules[value['scheduleId']]!
        : PlannerSchedule.fromJson(value['managedSchedule'] as Map);
    return removeSchedule(schedule);
  }

  Future<void> undoDelete(String scheduleId) async {
    final op = operationsFor(scheduleId)
        .where(
          (op) =>
              op.kind == PlannerOperationKind.delete &&
              op.pending &&
              !op.attempted,
        )
        .lastOrNull;
    final schedule = data.schedules[scheduleId];
    if (schedule == null ||
        !schedule.removed ||
        schedule.undoUntil?.isAfter(reader.now) != true ||
        operationsFor(scheduleId).any(
          (operation) =>
              operation.kind == PlannerOperationKind.delete &&
              operation.attempted,
        )) {
      return;
    }
    if (schedule.taskId != null && taskSchedule(schedule.taskId!) != null) {
      return;
    }
    if (op != null && op.notBefore?.isAfter(reader.now) != true) return;
    final task =
        schedule.taskId == null || app.tasks.any((t) => t.id == schedule.taskId)
        ? null
        : FocusTask(
            id: schedule.taskId!,
            title: schedule.deletedTask?['title'] as String? ?? schedule.title,
            done: schedule.deletedTask?['done'] == true,
          );
    await _change(
      (current) => current.copyWith(
        schedules: {
          ...current.schedules,
          scheduleId: schedule.copyWith(removed: false, clearUndo: true),
        },
        operations: {
          ...current.operations,
          if (op != null)
            op.id: op.copyWith(state: PlannerOperationState.cancelled),
          for (final operation in current.operations.values.where(
            (operation) =>
                operation.scheduleId == scheduleId &&
                operation.kind == PlannerOperationKind.create &&
                !operation.attempted &&
                operation.state == PlannerOperationState.cancelled &&
                schedule.baseline.isEmpty,
          ))
            operation.id: operation.copyWith(
              state: PlannerOperationState.queued,
              clearRetry: true,
            ),
        },
      ),
      tasks: task == null ? [] : [task],
    );
    message = 'Deletion undone.';
    _notify();
    unawaited(sync());
  }

  @override
  bool handlesTask(String id) => taskSchedule(id) != null;
  @override
  Future<void> renameTask(String id, String title) async {
    final schedule = taskSchedule(id);
    if (schedule == null || title.trim().isEmpty || title.trim().length > 160) {
      return;
    }
    final value = editSchedule(schedule)..['title'] = title.trim();
    await saveDraft(value);
  }

  @override
  Future<void> deleteTask(String id) async {
    final schedule = taskSchedule(id);
    if (schedule != null) await removeSchedule(schedule, deleteTask: true);
  }

  CalendarEvent? taskOccurrence(String id) {
    final schedule = taskSchedule(id);
    if (schedule == null || !schedule.recurring) return null;
    final first = CalendarDate(
      reader.now.toLocal().year,
      reader.now.toLocal().month,
      reader.now.toLocal().day,
    );
    final window = range(first, first.plusDays(42));
    if (schedule.policy == PlannerSyncPolicy.local) {
      final occurrences =
          eventsFor(window)
              .where(
                (event) =>
                    event.recurringEventId == schedule.eventId &&
                    event.endUtc!.isAfter(reader.now),
              )
              .toList()
            ..sort((a, b) => a.startUtc!.compareTo(b.startUtc!));
      return occurrences.firstOrNull;
    }
    final remote = reader
        .eventsFor(window)
        .where(
          (event) =>
              event.calendarId == schedule.calendarId &&
              event.recurringEventId == schedule.eventId,
        )
        .toList();
    final byOriginal = {for (final event in remote) event.originalStart: event};
    final candidates = <CalendarEvent>[...remote];
    for (final event in plannerOccurrences(schedule, window)) {
      if (byOriginal.keys.any(
        (original) =>
            original != null &&
            DateTime.tryParse(original)?.toUtc() == event.startUtc,
      )) {
        continue;
      }
      final local = event.startUtc!.toLocal();
      if (schedule.policy == PlannerSyncPolicy.google &&
          reader.sourceRangeVerified(
            schedule.calendarId!,
            reader.clock.dayWindow(
              CalendarDate(local.year, local.month, local.day),
            ),
          )) {
        continue;
      }
      candidates.add(event);
    }
    candidates.sort((a, b) => a.startUtc!.compareTo(b.startUtc!));
    return candidates
        .where((event) => event.endUtc!.isAfter(reader.now))
        .firstOrNull;
  }

  bool taskDone(FocusTask task) {
    final occurrence = taskOccurrence(task.id);
    return occurrence == null
        ? task.done
        : data.completed.contains(
            plannerOccurrenceKey(
              taskSchedule(task.id)!.id,
              DateTime.tryParse(occurrence.originalStart ?? '') ??
                  occurrence.startUtc!,
            ),
          );
  }

  @override
  Future<void> completeTask(String id) async {
    final task = app.tasks.where((t) => t.id == id).firstOrNull;
    if (task == null) return;
    final occurrence = taskOccurrence(id);
    if (taskSchedule(id)?.recurring == true && occurrence == null) {
      message = 'There is no current or upcoming occurrence to complete.';
      _notify();
      return;
    }
    if (occurrence == null) {
      await _change(
        (current) => current,
        tasks: [task.copyWith(done: !task.done)],
        clearSelectedTask: !task.done ? id : null,
      );
    } else {
      final key = plannerOccurrenceKey(
        taskSchedule(id)!.id,
        DateTime.tryParse(occurrence.originalStart ?? '') ??
            occurrence.startUtc!,
      );
      final completing = !data.completed.contains(key);
      await _change((current) {
        final completed = {...current.completed};
        if (!completed.add(key)) completed.remove(key);
        return current.copyWith(completed: completed);
      }, clearSelectedTask: completing ? id : null);
    }
  }

  Future<void> importLegacy(CalendarCreationJournal journal) async {
    if (journal.accountKey != accountKey ||
        data.legacyImports.contains(journal.accountKey)) {
      return;
    }
    await _change((current) {
      final schedules = {...current.schedules},
          operations = {...current.operations},
          drafts = {...current.drafts};
      for (final d in journal.drafts.values) {
        if (journal.operations.containsKey(d.id)) continue;
        drafts.putIfAbsent(
          d.id,
          () => {
            'id': d.id,
            'title': d.title,
            'scheduled': true,
            'date': d.startDate,
            'endDate': d.endDate,
            'start': '${d.startTime} ${d.startPm ? 'PM' : 'AM'}',
            'end': '${d.endTime} ${d.endPm ? 'PM' : 'AM'}',
            'accountKey': d.accountKey,
            'calendarId': d.calendarId,
            'localOnly': true,
            'busy': d.busy,
            'colorId': d.colorId,
            'repeat': 'none',
            'interval': 1,
            'weekdays': <int>[],
            'ending': 'never',
            'legacy': true,
          },
        );
      }
      for (final old in journal.operations.values) {
        final fields = plannerJsonCopy(old.intent.fields);
        final saved = old.state == CalendarCreationState.saved;
        schedules.putIfAbsent(
          old.operationId,
          () => PlannerSchedule(
            id: old.operationId,
            accountKey: journal.accountKey,
            calendarId: old.intent.calendarId,
            eventId: old.eventId,
            policy: PlannerSyncPolicy.google,
            fields: fields,
            baseline: saved ? fields : {},
          ),
        );
        operations.putIfAbsent(
          old.operationId,
          () => PlannerOperation(
            id: old.operationId,
            scheduleId: old.operationId,
            accountKey: journal.accountKey,
            calendarId: old.intent.calendarId,
            eventId: old.eventId,
            kind: PlannerOperationKind.create,
            fields: fields,
            attempted: true,
            automatic: false,
            legacy: true,
            legacyReceipt: plannerJsonCopy(old.toJson()),
            state: saved
                ? PlannerOperationState.saved
                : PlannerOperationState.failed,
            message: saved
                ? null
                : 'An earlier save needs checking. Retry uses its original event identity.',
          ),
        );
      }
      final prefs = {...current.preferences};
      prefs.putIfAbsent(
        journal.accountKey,
        () => PlannerPreferences(calendarId: journal.destination),
      );
      return current.copyWith(
        schedules: schedules,
        operations: operations,
        drafts: drafts,
        preferences: prefs,
        legacyImports: {...current.legacyImports, journal.accountKey},
      );
    });
  }

  @override
  void stopForReset() {
    _epoch++;
    _resetting = true;
    writer.cancel();
    _wake?.cancel();
    draft = null;
    selectedIdentity = null;
    _saveViews.clear();
    _localUndo.clear();
    _saveSelections.clear();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    writer.cancel();
    _wake?.cancel();
    if (identical(app.plannerActions, this)) app.plannerActions = null;
    app.removeListener(_appChanged);
    reader.removeListener(_readerChanged);
    connection.removeListener(_connectionChanged);
    clockTick.dispose();
    super.dispose();
  }
}
