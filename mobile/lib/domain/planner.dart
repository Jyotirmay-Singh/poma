import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

import 'calendar_data.dart';
import 'focus_blocks.dart' show focusUuid;

enum PlannerSyncPolicy { local, google }

enum PlannerOperationKind { create, update, delete }

enum PlannerOperationState {
  queued,
  sending,
  checking,
  saved,
  failed,
  conflict,
  cancelled,
}

enum PlannerCalendarView { day, week, month, agenda }

enum PlannerClockMode { twelveHours, fullDay, threeHours, sixHours }

enum PlannerRepeat { none, daily, weekdays, weekly, monthly }

Map<String, dynamic> plannerJsonCopy(Map value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, dynamic> _frozenPlannerFields(Map value) => Map.unmodifiable({
  for (final entry in value.entries)
    entry.key as String: _freezePlannerValue(entry.value),
});

Object? _freezePlannerValue(Object? value) {
  if (value is Map) return _frozenPlannerFields(value);
  if (value is List) return List.unmodifiable(value.map(_freezePlannerValue));
  return value;
}

String plannerEventId(String scheduleId) =>
    'pomadc${scheduleId.replaceAll('-', '')}';

int plannerSnapMinute(double minute, {int maximum = 1435}) =>
    ((minute / 5).round() * 5).clamp(0, maximum);

// Keep exact instants as core DateTime values. TZDateTime.toLocal follows
// timezone.local, which can differ from the Windows device timezone.
DateTime plannerUtcInstant(DateTime value) =>
    DateTime.fromMicrosecondsSinceEpoch(
      value.microsecondsSinceEpoch,
      isUtc: true,
    );

DateTime plannerSnapInstant(DateTime instant) {
  final utc = plannerUtcInstant(instant);
  final local = utc.toLocal();
  final minute =
      local.hour * 60 +
      local.minute +
      local.second / 60 +
      local.millisecond / 60000;
  final snapped = plannerSnapMinute(minute);
  return utc.add(
    Duration(microseconds: ((snapped - minute) * 60000000).round()),
  );
}

String plannerDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String plannerTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

class PlannerPreferences {
  const PlannerPreferences({
    this.syncEnabled = false,
    this.calendarId,
    this.durationMinutes = 60,
    this.clockMode = PlannerClockMode.twelveHours,
    this.calendarView = PlannerCalendarView.week,
  });
  final bool syncEnabled;
  final String? calendarId;
  final int durationMinutes;
  final PlannerClockMode clockMode;
  final PlannerCalendarView calendarView;

  PlannerPreferences copyWith({
    bool? syncEnabled,
    String? calendarId,
    int? durationMinutes,
    PlannerClockMode? clockMode,
    PlannerCalendarView? calendarView,
  }) => PlannerPreferences(
    syncEnabled: syncEnabled ?? this.syncEnabled,
    calendarId: calendarId ?? this.calendarId,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    clockMode: clockMode ?? this.clockMode,
    calendarView: calendarView ?? this.calendarView,
  );

  Map<String, Object?> toJson() => {
    'syncEnabled': syncEnabled,
    'calendarId': calendarId,
    'durationMinutes': durationMinutes,
    'clockMode': clockMode.name,
    'calendarView': calendarView.name,
  };
  factory PlannerPreferences.fromJson(Map value) {
    final duration = value['durationMinutes'] as int? ?? 60;
    if (duration < 1 || duration > 527040) {
      throw const FormatException('Invalid planner duration.');
    }
    return PlannerPreferences(
      syncEnabled: value['syncEnabled'] == true,
      calendarId: value['calendarId'] as String?,
      durationMinutes: duration,
      clockMode: PlannerClockMode.values.byName(
        value['clockMode'] as String? ?? 'twelveHours',
      ),
      calendarView: PlannerCalendarView.values.byName(
        value['calendarView'] as String? ?? 'week',
      ),
    );
  }
}

/// A task schedule or an explicitly managed standalone event. The Google identity
/// remains here after operation receipts are compacted and after a local deletion.
class PlannerSchedule {
  PlannerSchedule({
    required this.id,
    required Map<String, dynamic> fields,
    this.taskId,
    this.accountKey,
    this.calendarId,
    this.eventId,
    this.etag,
    this.policy = PlannerSyncPolicy.local,
    this.removed = false,
    this.originalStart,
    this.masterId,
    this.undoUntil,
    this.deletedTask,
    Map<String, dynamic> baseline = const {},
  }) : fields = _frozenPlannerFields(fields),
       baseline = _frozenPlannerFields(baseline);

  final String id;
  final String? taskId,
      accountKey,
      calendarId,
      eventId,
      etag,
      originalStart,
      masterId;
  final PlannerSyncPolicy policy;
  final bool removed;
  final DateTime? undoUntil;
  final Map<String, dynamic>? deletedTask;
  final Map<String, dynamic> fields, baseline;

  String get title => fields['summary'] as String? ?? '';
  bool get recurring => (fields['recurrence'] as List? ?? const []).isNotEmpty;
  String get zone =>
      (fields['start'] as Map?)?['timeZone'] as String? ?? 'Etc/UTC';
  DateTime? get startUtc => DateTime.tryParse(
    (fields['start'] as Map?)?['dateTime'] as String? ?? '',
  )?.toUtc();
  DateTime? get endUtc => DateTime.tryParse(
    (fields['end'] as Map?)?['dateTime'] as String? ?? '',
  )?.toUtc();

  PlannerSchedule copyWith({
    Map<String, dynamic>? fields,
    Map<String, dynamic>? baseline,
    String? accountKey,
    String? calendarId,
    String? eventId,
    String? etag,
    PlannerSyncPolicy? policy,
    bool? removed,
    DateTime? undoUntil,
    Map<String, dynamic>? deletedTask,
    bool clearUndo = false,
  }) => PlannerSchedule(
    id: id,
    taskId: taskId,
    accountKey: accountKey ?? this.accountKey,
    calendarId: calendarId ?? this.calendarId,
    eventId: eventId ?? this.eventId,
    etag: etag ?? this.etag,
    originalStart: originalStart,
    masterId: masterId,
    policy: policy ?? this.policy,
    removed: removed ?? this.removed,
    undoUntil: clearUndo ? null : undoUntil ?? this.undoUntil,
    deletedTask: clearUndo ? null : deletedTask ?? this.deletedTask,
    fields: fields ?? this.fields,
    baseline: baseline ?? this.baseline,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'taskId': taskId,
    'accountKey': accountKey,
    'calendarId': calendarId,
    'eventId': eventId,
    'etag': etag,
    'policy': policy.name,
    'removed': removed,
    'originalStart': originalStart,
    'masterId': masterId,
    'undoUntil': undoUntil?.toIso8601String(),
    'deletedTask': deletedTask,
    'fields': fields,
    'baseline': baseline,
  };
  factory PlannerSchedule.fromJson(Map value) {
    final result = PlannerSchedule(
      id: value['id'] as String,
      taskId: value['taskId'] as String?,
      accountKey: value['accountKey'] as String?,
      calendarId: value['calendarId'] as String?,
      eventId: value['eventId'] as String?,
      etag: value['etag'] as String?,
      policy: PlannerSyncPolicy.values.byName(value['policy'] as String),
      removed: value['removed'] == true,
      originalStart: value['originalStart'] as String?,
      masterId: value['masterId'] as String?,
      undoUntil: value['undoUntil'] == null
          ? null
          : DateTime.parse(value['undoUntil'] as String).toUtc(),
      deletedTask: value['deletedTask'] == null
          ? null
          : plannerJsonCopy(value['deletedTask'] as Map),
      fields: plannerJsonCopy(value['fields'] as Map),
      baseline: plannerJsonCopy(value['baseline'] as Map? ?? {}),
    );
    if (result.id.isEmpty ||
        result.title.trim().isEmpty ||
        result.policy == PlannerSyncPolicy.google &&
            (result.accountKey == null ||
                result.calendarId == null ||
                result.eventId == null)) {
      throw const FormatException('Invalid planner schedule.');
    }
    return result;
  }
}

class PlannerOperation {
  PlannerOperation({
    required this.id,
    required this.scheduleId,
    required this.accountKey,
    required this.calendarId,
    required this.eventId,
    required this.kind,
    required Map<String, dynamic> fields,
    Map<String, dynamic> baseFields = const {},
    this.baseEtag,
    this.state = PlannerOperationState.queued,
    this.attempts = 0,
    this.attempted = false,
    this.automatic = true,
    this.notBefore,
    this.retryAt,
    this.completedAt,
    this.message,
    this.dependsOn,
    this.legacy = false,
    Map<String, dynamic>? legacyReceipt,
  }) : fields = _frozenPlannerFields(fields),
       baseFields = _frozenPlannerFields(baseFields),
       legacyReceipt = legacyReceipt == null
           ? null
           : Map.unmodifiable(plannerJsonCopy(legacyReceipt));

  final String id, scheduleId, accountKey, calendarId, eventId;
  final PlannerOperationKind kind;
  final PlannerOperationState state;
  final Map<String, dynamic> fields, baseFields;
  final String? baseEtag, message, dependsOn;
  final DateTime? notBefore, retryAt, completedAt;
  final int attempts;
  final bool attempted, automatic, legacy;
  final Map<String, dynamic>? legacyReceipt;
  bool get terminal => const {
    PlannerOperationState.saved,
    PlannerOperationState.cancelled,
  }.contains(state);
  bool get pending => !terminal;

  PlannerOperation copyWith({
    PlannerOperationState? state,
    int? attempts,
    bool? attempted,
    bool? automatic,
    DateTime? retryAt,
    DateTime? completedAt,
    String? message,
    String? baseEtag,
    Map<String, dynamic>? fields,
    Map<String, dynamic>? baseFields,
    bool clearRetry = false,
    bool clearMessage = false,
  }) => PlannerOperation(
    id: id,
    scheduleId: scheduleId,
    accountKey: accountKey,
    calendarId: calendarId,
    eventId: eventId,
    kind: kind,
    fields: fields ?? this.fields,
    baseFields: baseFields ?? this.baseFields,
    baseEtag: baseEtag ?? this.baseEtag,
    state: state ?? this.state,
    attempts: attempts ?? this.attempts,
    attempted: attempted ?? this.attempted,
    automatic: automatic ?? this.automatic,
    notBefore: notBefore,
    retryAt: clearRetry ? null : retryAt ?? this.retryAt,
    completedAt: completedAt ?? this.completedAt,
    message: clearMessage ? null : message ?? this.message,
    dependsOn: dependsOn,
    legacy: legacy,
    legacyReceipt: legacyReceipt,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'scheduleId': scheduleId,
    'accountKey': accountKey,
    'calendarId': calendarId,
    'eventId': eventId,
    'kind': kind.name,
    'state': state.name,
    'fields': fields,
    'baseFields': baseFields,
    'baseEtag': baseEtag,
    'attempts': attempts,
    'attempted': attempted,
    'automatic': automatic,
    'notBefore': notBefore?.toIso8601String(),
    'retryAt': retryAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'message': message,
    'dependsOn': dependsOn,
    'legacy': legacy,
    'legacyReceipt': legacyReceipt,
  };

  factory PlannerOperation.fromJson(Map value) {
    final result = PlannerOperation(
      id: value['id'] as String,
      scheduleId: value['scheduleId'] as String,
      accountKey: value['accountKey'] as String,
      calendarId: value['calendarId'] as String,
      eventId: value['eventId'] as String,
      kind: PlannerOperationKind.values.byName(value['kind'] as String),
      state: PlannerOperationState.values.byName(value['state'] as String),
      fields: plannerJsonCopy(value['fields'] as Map),
      baseFields: plannerJsonCopy(value['baseFields'] as Map? ?? {}),
      baseEtag: value['baseEtag'] as String?,
      attempts: value['attempts'] as int? ?? 0,
      attempted: value['attempted'] == true,
      automatic: value['automatic'] != false,
      notBefore: value['notBefore'] == null
          ? null
          : DateTime.parse(value['notBefore'] as String).toUtc(),
      retryAt: value['retryAt'] == null
          ? null
          : DateTime.parse(value['retryAt'] as String).toUtc(),
      completedAt: value['completedAt'] == null
          ? null
          : DateTime.parse(value['completedAt'] as String).toUtc(),
      message: value['message'] as String?,
      dependsOn: value['dependsOn'] as String?,
      legacy: value['legacy'] == true,
      legacyReceipt: value['legacyReceipt'] == null
          ? null
          : plannerJsonCopy(value['legacyReceipt'] as Map),
    );
    if ([
          result.id,
          result.scheduleId,
          result.accountKey,
          result.calendarId,
          result.eventId,
        ].any((s) => s.isEmpty) ||
        result.attempts < 0) {
      throw const FormatException('Invalid planner operation.');
    }
    return result;
  }
}

class PlannerData {
  PlannerData({
    Map<String, PlannerSchedule> schedules = const {},
    Map<String, PlannerOperation> operations = const {},
    Map<String, PlannerPreferences> preferences = const {},
    Map<String, Map<String, dynamic>> drafts = const {},
    Set<String> completed = const {},
    Set<String> legacyImports = const {},
  }) : schedules = Map.unmodifiable(schedules),
       operations = Map.unmodifiable(operations),
       preferences = Map.unmodifiable(preferences),
       drafts = Map.unmodifiable(
         drafts.map(
           (k, v) => MapEntry(
             k,
             Map<String, dynamic>.unmodifiable(plannerJsonCopy(v)),
           ),
         ),
       ),
       completed = Set.unmodifiable(completed),
       legacyImports = Set.unmodifiable(legacyImports);
  final Map<String, PlannerSchedule> schedules;
  final Map<String, PlannerOperation> operations;
  final Map<String, PlannerPreferences> preferences;
  final Map<String, Map<String, dynamic>> drafts;
  final Set<String> completed, legacyImports;

  PlannerData copyWith({
    Map<String, PlannerSchedule>? schedules,
    Map<String, PlannerOperation>? operations,
    Map<String, PlannerPreferences>? preferences,
    Map<String, Map<String, dynamic>>? drafts,
    Set<String>? completed,
    Set<String>? legacyImports,
  }) => PlannerData(
    schedules: schedules ?? this.schedules,
    operations: operations ?? this.operations,
    preferences: preferences ?? this.preferences,
    drafts: drafts ?? this.drafts,
    completed: completed ?? this.completed,
    legacyImports: legacyImports ?? this.legacyImports,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'schedules': schedules.map((k, v) => MapEntry(k, v.toJson())),
    'operations': operations.map((k, v) => MapEntry(k, v.toJson())),
    'preferences': preferences.map((k, v) => MapEntry(k, v.toJson())),
    'drafts': drafts,
    'completed': completed.toList(),
    'legacyImports': legacyImports.toList(),
  };

  factory PlannerData.fromJson(Map value) {
    if (value['version'] != 1) {
      throw const FormatException('Unknown planner data.');
    }
    final result = PlannerData(
      schedules: (value['schedules'] as Map).map(
        (k, v) => MapEntry(k as String, PlannerSchedule.fromJson(v as Map)),
      ),
      operations: (value['operations'] as Map).map(
        (k, v) => MapEntry(k as String, PlannerOperation.fromJson(v as Map)),
      ),
      preferences: (value['preferences'] as Map).map(
        (k, v) => MapEntry(k as String, PlannerPreferences.fromJson(v as Map)),
      ),
      drafts: (value['drafts'] as Map).map(
        (k, v) => MapEntry(k as String, plannerJsonCopy(v as Map)),
      ),
      completed: Set<String>.from(value['completed'] as List),
      legacyImports: Set<String>.from(value['legacyImports'] as List? ?? []),
    );
    final activeTasks = result.schedules.values
        .where((schedule) => !schedule.removed && schedule.taskId != null)
        .map((schedule) => schedule.taskId)
        .toList();
    final remoteLinks = result.schedules.values
        .where((schedule) => schedule.policy == PlannerSyncPolicy.google)
        .map(
          (schedule) => jsonEncode([
            schedule.accountKey,
            schedule.calendarId,
            schedule.eventId,
          ]),
        )
        .toList();
    if (activeTasks.toSet().length != activeTasks.length ||
        remoteLinks.toSet().length != remoteLinks.length) {
      throw const FormatException('Duplicate planner relationship.');
    }
    if (result.schedules.entries.any((e) => e.key != e.value.id) ||
        result.operations.entries.any(
          (e) =>
              e.key != e.value.id ||
              !result.schedules.containsKey(e.value.scheduleId),
        )) {
      throw const FormatException('Mismatched planner identity.');
    }
    return result;
  }
}

abstract interface class PlannerTaskActions {
  bool handlesTask(String id);
  Future<void> renameTask(String id, String title);
  Future<void> deleteTask(String id);
  Future<void> completeTask(String id);
  void stopForReset();
}

const plannerEditableFields = {
  'summary',
  'start',
  'end',
  'colorId',
  'transparency',
  'recurrence',
};

Map<String, dynamic> plannerEditable(Map value) => {
  for (final key in plannerEditableFields)
    if (value.containsKey(key)) key: value[key],
};

bool plannerValueEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    return a.length == b.length &&
        a.keys.every((k) => b.containsKey(k) && plannerValueEquals(a[k], b[k]));
  }
  if (a is List && b is List) {
    return a.length == b.length &&
        List.generate(
          a.length,
          (i) => i,
        ).every((i) => plannerValueEquals(a[i], b[i]));
  }
  return a == b;
}

/// Timing endpoints form one edit unit, so an external end change cannot be
/// combined with an old local start and accidentally shorten an appointment.
Map<String, dynamic>? plannerMergePatch(Map base, Map desired, Map latest) {
  final changed = plannerEditableFields
      .where((k) => !plannerValueEquals(base[k], desired[k]))
      .toSet();
  if (changed.contains('start') || changed.contains('end')) {
    changed.addAll({'start', 'end'});
  }
  for (final key in changed) {
    if (!plannerValueEquals(base[key], latest[key]) &&
        !plannerValueEquals(desired[key], latest[key])) {
      return null;
    }
  }
  return {for (final key in changed) key: desired[key]};
}

class PlannerRecurrence {
  const PlannerRecurrence({
    this.repeat = PlannerRepeat.none,
    this.interval = 1,
    this.weekdays = const [],
    this.until,
    this.count,
  });
  final PlannerRepeat repeat;
  final int interval;
  final List<int> weekdays;
  final CalendarDate? until;
  final int? count;
  bool get enabled => repeat != PlannerRepeat.none;

  List<String> rule(tz.Location zone, {bool allDay = false}) {
    if (!enabled) return const [];
    if (interval < 1 ||
        count != null && count! < 1 ||
        until != null && count != null ||
        weekdays.any((d) => d < 1 || d > 7) ||
        repeat == PlannerRepeat.weekly && weekdays.isEmpty) {
      throw const FormatException('Choose a valid repeat interval and ending.');
    }
    final parts = <String>[
      'FREQ=${switch (repeat) {
        PlannerRepeat.daily || PlannerRepeat.weekdays => 'DAILY',
        PlannerRepeat.weekly => 'WEEKLY',
        PlannerRepeat.monthly => 'MONTHLY',
        PlannerRepeat.none => throw StateError('Not repeating'),
      }}',
    ];
    if (interval != 1) parts.add('INTERVAL=$interval');
    const names = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
    if (repeat == PlannerRepeat.weekdays) parts.add('BYDAY=MO,TU,WE,TH,FR');
    if (repeat == PlannerRepeat.weekly) {
      parts.add(
        'BYDAY=${(weekdays.toSet().toList()..sort()).map((d) => names[d - 1]).join(',')}',
      );
    }
    if (count != null) parts.add('COUNT=$count');
    if (until case final date?) {
      if (allDay) {
        parts.add('UNTIL=${date.toString().replaceAll('-', '')}');
        return ['RRULE:${parts.join(';')}'];
      }
      final end = tz.TZDateTime(
        zone,
        date.year,
        date.month,
        date.day,
        23,
        59,
        59,
      ).toUtc();
      parts.add(
        'UNTIL=${end.toIso8601String().replaceAll(RegExp('[-:]'), '').split('.').first}Z',
      );
    }
    return ['RRULE:${parts.join(';')}'];
  }

  static PlannerRecurrence? parse(List<dynamic> rules, tz.Location zone) {
    if (rules.isEmpty) return const PlannerRecurrence();
    if (rules.length != 1 ||
        rules.first is! String ||
        !(rules.first as String).startsWith('RRULE:')) {
      return null;
    }
    try {
      final values = <String, String>{};
      for (final p in (rules.first as String).substring(6).split(';')) {
        final pair = p.split('=');
        if (pair.length != 2 || values.containsKey(pair.first)) return null;
        values[pair.first] = pair.last;
      }
      if (values.keys.any(
        (k) =>
            !const {'FREQ', 'INTERVAL', 'BYDAY', 'COUNT', 'UNTIL'}.contains(k),
      )) {
        return null;
      }
      var repeat = switch (values['FREQ']) {
        'DAILY' => PlannerRepeat.daily,
        'WEEKLY' => PlannerRepeat.weekly,
        'MONTHLY' => PlannerRepeat.monthly,
        _ => null,
      };
      if (repeat == null) return null;
      const names = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
      final days =
          values['BYDAY']
              ?.split(',')
              .map((s) => names.indexOf(s) + 1)
              .toList() ??
          <int>[];
      if (days.contains(0)) return null;
      if (repeat == PlannerRepeat.daily &&
          days.toSet().containsAll([1, 2, 3, 4, 5]) &&
          days.length == 5) {
        repeat = PlannerRepeat.weekdays;
      } else if (repeat != PlannerRepeat.weekly && days.isNotEmpty) {
        return null;
      }
      final untilText = values['UNTIL'];
      CalendarDate? until;
      if (untilText != null) {
        if (RegExp(r'^\d{8}$').hasMatch(untilText)) {
          until = CalendarDate.parse(
            '${untilText.substring(0, 4)}-${untilText.substring(4, 6)}-${untilText.substring(6, 8)}',
          );
        } else {
          final local = tz.TZDateTime.from(DateTime.parse(untilText), zone);
          until = CalendarDate(local.year, local.month, local.day);
        }
      }
      return PlannerRecurrence(
        repeat: repeat,
        interval: int.parse(values['INTERVAL'] ?? '1'),
        weekdays: days,
        count: values['COUNT'] == null ? null : int.parse(values['COUNT']!),
        until: until,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Strict wall-clock resolution: TZDateTime's normalizing constructor alone
/// would silently move a nonexistent spring time or choose one side of a fold.
List<tz.TZDateTime> plannerResolveWall(tz.Location zone, DateTime wall) {
  final utcWall = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  );
  final offsets = <int>{
    for (final delta in [-370, -2, 0, 2, 370])
      tz.TZDateTime.from(
        utcWall.add(Duration(days: delta)),
        zone,
      ).timeZoneOffset.inMilliseconds,
  };
  final result = <tz.TZDateTime>[];
  for (final offset in offsets) {
    final candidate = tz.TZDateTime.from(
      utcWall.subtract(Duration(milliseconds: offset)),
      zone,
    );
    if (candidate.year == wall.year &&
        candidate.month == wall.month &&
        candidate.day == wall.day &&
        candidate.hour == wall.hour &&
        candidate.minute == wall.minute) {
      result.add(candidate);
    }
  }
  result.sort((a, b) => a.compareTo(b));
  return result;
}

Iterable<CalendarEvent> plannerOccurrences(
  PlannerSchedule schedule,
  CalendarWindow range,
) sync* {
  if (schedule.removed ||
      schedule.startUtc == null ||
      schedule.endUtc == null) {
    return;
  }
  final zone = tz.getLocation(schedule.zone);
  final start = tz.TZDateTime.from(schedule.startUtc!, zone);
  final end = tz.TZDateTime.from(schedule.endUtc!, zone);
  final recurrence = PlannerRecurrence.parse(
    schedule.fields['recurrence'] as List? ?? [],
    zone,
  );
  if (recurrence == null) return;
  final origin = DateTime.utc(start.year, start.month, start.day);
  final wallDuration =
      DateTime.utc(
        end.year,
        end.month,
        end.day,
        end.hour,
        end.minute,
      ).difference(
        DateTime.utc(
          start.year,
          start.month,
          start.day,
          start.hour,
          start.minute,
        ),
      );
  final finish = tz.TZDateTime.from(range.endUtc, zone);
  var day = origin;
  var ordinal = 0;
  // With no COUNT, skip historical dates instead of expanding an unbounded past.
  if (recurrence.count == null && recurrence.enabled) {
    final near = tz.TZDateTime.from(
      range.startUtc.subtract(wallDuration).subtract(const Duration(days: 2)),
      zone,
    );
    final candidate = DateTime.utc(near.year, near.month, near.day);
    if (candidate.isAfter(day)) day = candidate;
  }
  while (!day.isAfter(DateTime.utc(finish.year, finish.month, finish.day))) {
    final days = day.difference(origin).inDays;
    final months = (day.year - origin.year) * 12 + day.month - origin.month;
    final week = (days + origin.weekday - 1) ~/ 7;
    final matches = switch (recurrence.repeat) {
      PlannerRepeat.none => days == 0,
      PlannerRepeat.daily => days % recurrence.interval == 0,
      PlannerRepeat.weekdays =>
        days % recurrence.interval == 0 && day.weekday <= 5,
      PlannerRepeat.weekly =>
        week % recurrence.interval == 0 &&
            recurrence.weekdays.contains(day.weekday),
      PlannerRepeat.monthly =>
        months % recurrence.interval == 0 && day.day == origin.day,
    };
    if (recurrence.until != null &&
        CalendarDate(
              day.year,
              day.month,
              day.day,
            ).compareTo(recurrence.until!) >
            0) {
      return;
    }
    if (matches) {
      final walls = plannerResolveWall(
        zone,
        DateTime.utc(day.year, day.month, day.day, start.hour, start.minute),
      );
      if (walls.isNotEmpty) {
        ordinal++;
        if (recurrence.count != null && ordinal > recurrence.count!) return;
        final a = plannerUtcInstant(walls.first);
        final endWall = DateTime.utc(
          day.year,
          day.month,
          day.day,
          start.hour,
          start.minute,
        ).add(wallDuration);
        final ends = plannerResolveWall(zone, endWall);
        if (ends.isNotEmpty) {
          final b = plannerUtcInstant(ends.first);
          if (a.isBefore(range.endUtc) &&
              b.isAfter(range.startUtc) &&
              b.isAfter(a)) {
            final original = a.toIso8601String();
            yield CalendarEvent(
              id: recurrence.enabled
                  ? '${schedule.eventId ?? schedule.id}/$original'
                  : schedule.eventId ?? schedule.id,
              calendarId: schedule.calendarId ?? 'poma-local',
              title: schedule.title,
              status: 'confirmed',
              selfResponse: 'accepted',
              startUtc: a,
              endUtc: b,
              startZone: schedule.zone,
              endZone: schedule.zone,
              recurringEventId: recurrence.enabled
                  ? schedule.eventId ?? schedule.id
                  : schedule.masterId,
              originalStart:
                  schedule.originalStart ??
                  (recurrence.enabled ? original : null),
              colorId: schedule.fields['colorId'] as String?,
              transparency:
                  schedule.fields['transparency'] as String? ?? 'opaque',
            );
          }
        }
      }
    }
    if (!recurrence.enabled) return;
    day = day.add(const Duration(days: 1));
  }
}

String plannerOccurrenceKey(String scheduleId, DateTime original) =>
    '$scheduleId/${original.toUtc().toIso8601String()}';

class PlannerGap {
  PlannerGap(DateTime startUtc, DateTime endUtc)
    : startUtc = plannerUtcInstant(startUtc),
      endUtc = plannerUtcInstant(endUtc);
  final DateTime startUtc, endUtc;
  Duration get duration => endUtc.difference(startUtc);
}

List<PlannerGap> plannerGaps(
  Iterable<CalendarEvent> events,
  CalendarWindow range, {
  required bool verified,
  Duration minimum = const Duration(minutes: 15),
  DateTime? after,
  DateTime Function(CalendarDate)? midnight,
}) {
  if (!verified) return const [];
  final intervals = <PlannerGap>[];
  for (final event in events.where(
    (e) => e.eligible && e.transparency != 'transparent',
  )) {
    if (event.transparency == null) return const [];
    final a = event.allDay ? midnight?.call(event.startDate!) : event.startUtc;
    final b = event.allDay ? midnight?.call(event.endDate!) : event.endUtc;
    if (a == null || b == null) return const [];
    if (a.isBefore(range.endUtc) && b.isAfter(range.startUtc)) {
      intervals.add(PlannerGap(a, b));
    }
  }
  intervals.sort((a, b) => a.startUtc.compareTo(b.startUtc));
  var cursor = after != null && after.isAfter(range.startUtc)
      ? after
      : range.startUtc;
  final result = <PlannerGap>[];
  for (final interval in intervals) {
    if (interval.startUtc.difference(cursor) >= minimum) {
      result.add(PlannerGap(cursor, interval.startUtc));
    }
    if (interval.endUtc.isAfter(cursor)) cursor = interval.endUtc;
    if (!cursor.isBefore(range.endUtc)) return result;
  }
  if (range.endUtc.difference(cursor) >= minimum) {
    result.add(PlannerGap(cursor, range.endUtc));
  }
  return result;
}

String newPlannerId() => focusUuid();
