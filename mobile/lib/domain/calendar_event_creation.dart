import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'calendar_data.dart';
import 'focus_blocks.dart' show focusUuid, validFocusUuid;

enum CalendarCreationState {
  draft,
  validating,
  ready,
  sending,
  checking,
  saved,
  failed,
}

/// Raw values deliberately survive invalid edits and closing the form.
class CalendarEventDraft {
  CalendarEventDraft({
    required this.accountKey,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    required this.startPm,
    required this.endPm,
    this.title = '',
    this.calendarId,
    this.colorId,
    this.taskId,
    this.busy = true,
    String? id,
  }) : id = id ?? focusUuid();
  final String id;
  DateTime? savedAt;
  String? accountKey;
  String title, startDate, endDate, startTime, endTime;
  bool startPm, endPm, busy;
  String? calendarId, colorId, taskId;
  Map<String, Object?> toJson() => {
    'id': id,
    'savedAt': savedAt?.toIso8601String(),
    'accountKey': accountKey,
    'title': title,
    'startDate': startDate,
    'endDate': endDate,
    'startTime': startTime,
    'endTime': endTime,
    'startPm': startPm,
    'endPm': endPm,
    'busy': busy,
    'calendarId': calendarId,
    'colorId': colorId,
    'taskId': taskId,
  };
  factory CalendarEventDraft.fromJson(Map m) =>
      CalendarEventDraft(
          id: m['id'] as String,
          accountKey: m['accountKey'] as String?,
          title: m['title'] as String,
          startDate: m['startDate'] as String,
          endDate: m['endDate'] as String,
          startTime: m['startTime'] as String,
          endTime: m['endTime'] as String,
          startPm: m['startPm'] as bool,
          endPm: m['endPm'] as bool,
          busy: m['busy'] as bool,
          calendarId: m['calendarId'] as String?,
          colorId: m['colorId'] as String?,
          taskId: m['taskId'] as String?,
        )
        ..savedAt = m['savedAt'] == null
            ? null
            : DateTime.parse(m['savedAt'] as String).toUtc();
}

class CalendarCreateIntent {
  const CalendarCreateIntent({
    required this.accountKey,
    required this.calendarId,
    required this.title,
    required this.startUtc,
    required this.endUtc,
    required this.zone,
    required this.zoneFingerprint,
    required this.startOffset,
    required this.endOffset,
    required this.busy,
    this.colorId,
    this.taskId,
  });
  final String accountKey, calendarId, title, zone, zoneFingerprint;
  final DateTime startUtc, endUtc;
  final int startOffset, endOffset;
  final bool busy;
  final String? colorId, taskId;
  String get hash => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            title,
            startUtc.toUtc().toIso8601String(),
            endUtc.toUtc().toIso8601String(),
            busy,
            colorId,
          ]),
        ),
      )
      .toString();
  Map<String, Object?> get fields => {
    'summary': title,
    'start': {'dateTime': creationEndpoint(startUtc, startOffset)},
    'end': {'dateTime': creationEndpoint(endUtc, endOffset)},
    'transparency': busy ? 'opaque' : 'transparent',
    'eventType': 'default',
    if (colorId != null) 'colorId': colorId,
  };
  Map<String, Object?> toJson() => {
    'accountKey': accountKey,
    'calendarId': calendarId,
    'title': title,
    'startUtc': startUtc.toUtc().toIso8601String(),
    'endUtc': endUtc.toUtc().toIso8601String(),
    'zone': zone,
    'zoneFingerprint': zoneFingerprint,
    'startOffset': startOffset,
    'endOffset': endOffset,
    'busy': busy,
    'colorId': colorId,
    'taskId': taskId,
  };
  factory CalendarCreateIntent.fromJson(Map m) => CalendarCreateIntent(
    accountKey: m['accountKey'] as String,
    calendarId: m['calendarId'] as String,
    title: m['title'] as String,
    startUtc: DateTime.parse(m['startUtc'] as String).toUtc(),
    endUtc: DateTime.parse(m['endUtc'] as String).toUtc(),
    zone: m['zone'] as String,
    zoneFingerprint: m['zoneFingerprint'] as String,
    startOffset: m['startOffset'] as int,
    endOffset: m['endOffset'] as int,
    busy: m['busy'] as bool,
    colorId: m['colorId'] as String?,
    taskId: m['taskId'] as String?,
  );
}

String creationEndpoint(DateTime utc, int offset) =>
    '${utc.toUtc().add(Duration(minutes: offset)).toIso8601String().replaceFirst('Z', '')}'
    '${offset < 0 ? '-' : '+'}${(offset.abs() ~/ 60).toString().padLeft(2, '0')}:'
    '${(offset.abs() % 60).toString().padLeft(2, '0')}';
String creationEventId(String id) =>
    'pomadc${id.replaceAll('-', '').toLowerCase()}';

/// Session 2 must durably store this frozen intent and stable client event ID
/// before invoking create. Generic markers must differ from focus ownership.
class CalendarCreateOperation {
  const CalendarCreateOperation(
    this.operationId,
    this.eventId,
    this.intent, {
    this.clientId = '',
    this.generation = '',
    this.state = CalendarCreationState.checking,
    this.confirmedAt,
    this.transitionAt,
    this.event,
    this.message,
    this.retryAllowed = false,
  });
  final String operationId, eventId;
  final CalendarCreateIntent intent;
  final String clientId, generation;
  final CalendarCreationState state;
  final DateTime? confirmedAt, transitionAt;
  final CalendarEvent? event;
  final String? message;
  final bool retryAllowed;
  Map<String, String> get markers => {
    'pomaDayClockSchema': '1',
    'pomaDayClockOperation': operationId,
    'pomaDayClockPayloadHash': intent.hash,
  };
  CalendarCreateOperation result(CalendarCreateResult r, DateTime now) =>
      CalendarCreateOperation(
        operationId,
        eventId,
        intent,
        clientId: clientId,
        generation: generation,
        state: r.state,
        confirmedAt: confirmedAt,
        transitionAt: now,
        event: r.event ?? event,
        message: r.message,
        retryAllowed: r.retryAllowed,
      );
  Map<String, Object?> toJson() => {
    'operationId': operationId,
    'eventId': eventId,
    'intent': intent.toJson(),
    'clientId': clientId,
    'generation': generation,
    'state': state.name,
    'confirmedAt': confirmedAt?.toIso8601String(),
    'transitionAt': transitionAt?.toIso8601String(),
    'event': event?.toJson(),
    'message': message,
    'retryAllowed': retryAllowed,
    'payloadHash': intent.hash,
  };
  factory CalendarCreateOperation.fromJson(Map m) {
    final op = CalendarCreateOperation(
      m['operationId'] as String,
      m['eventId'] as String,
      CalendarCreateIntent.fromJson(m['intent'] as Map),
      clientId: m['clientId'] as String,
      generation: m['generation'] as String,
      state: CalendarCreationState.values.byName(m['state'] as String),
      confirmedAt: DateTime.parse(m['confirmedAt'] as String).toUtc(),
      transitionAt: DateTime.parse(m['transitionAt'] as String).toUtc(),
      event: m['event'] == null
          ? null
          : CalendarEvent.fromJson(m['event'] as Map),
      message: m['message'] as String?,
      retryAllowed: m['retryAllowed'] == true,
    );
    if (!validFocusUuid(op.operationId) ||
        op.eventId != creationEventId(op.operationId) ||
        op.clientId.isEmpty ||
        !validFocusUuid(op.generation) ||
        op.intent.hash != m['payloadHash'] ||
        op.intent.title.trim().isEmpty ||
        !op.intent.endUtc.isAfter(op.intent.startUtc) ||
        op.event != null &&
            (op.event!.id != op.eventId ||
                op.event!.calendarId != op.intent.calendarId)) {
      throw const FormatException('Invalid creation operation.');
    }
    return op;
  }
}

class CalendarCreateResult {
  const CalendarCreateResult(
    this.state, {
    this.event,
    this.message,
    this.retryAllowed = false,
  });
  final CalendarCreationState state;
  final CalendarEvent? event;
  final String? message;
  final bool retryAllowed;
}

class CalendarCreationJournal {
  CalendarCreationJournal(
    this.accountKey, {
    Map<String, CalendarEventDraft>? drafts,
    Map<String, CalendarCreateOperation>? operations,
    this.destination,
  }) : drafts = drafts ?? {},
       operations = operations ?? {};
  final String accountKey;
  final Map<String, CalendarEventDraft> drafts;
  final Map<String, CalendarCreateOperation> operations;
  String? destination;
  String encode() => jsonEncode({
    'version': 1,
    'accountKey': accountKey,
    'destination': destination,
    'drafts': drafts.map((k, v) => MapEntry(k, v.toJson())),
    'operations': operations.map((k, v) => MapEntry(k, v.toJson())),
  });
  factory CalendarCreationJournal.decode(String value, String key) {
    if (utf8.encode(value).length > 16 * 1024 * 1024) {
      throw const FormatException('Creation journal too large.');
    }
    final m = jsonDecode(value) as Map;
    if (m['version'] != 1 || m['accountKey'] != key) {
      throw const FormatException('Invalid creation journal.');
    }
    final j = CalendarCreationJournal(
      key,
      destination: m['destination'] as String?,
      drafts: (m['drafts'] as Map).map(
        (k, v) => MapEntry(k as String, CalendarEventDraft.fromJson(v as Map)),
      ),
      operations: (m['operations'] as Map).map(
        (k, v) =>
            MapEntry(k as String, CalendarCreateOperation.fromJson(v as Map)),
      ),
    );
    if (j.drafts.entries.any(
          (e) =>
              e.key != e.value.id ||
              !validFocusUuid(e.key) ||
              e.value.accountKey != key,
        ) ||
        j.operations.entries.any(
          (e) =>
              e.key != e.value.operationId || e.value.intent.accountKey != key,
        )) {
      throw const FormatException('Mismatched creation identity.');
    }
    return j;
  }
}

abstract interface class CalendarEventCreationWriter {
  Future<bool> validateDestination(String accountKey, String calendarId);
  Future<CalendarCreateResult> create(CalendarCreateOperation operation);
  Future<CalendarCreateResult> readBack(CalendarCreateOperation operation);
  void cancel();
}
