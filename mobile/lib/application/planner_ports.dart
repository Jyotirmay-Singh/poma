import '../domain/calendar_data.dart';
import '../domain/planner.dart';

enum PlannerFailureKind {
  network,
  permission,
  conflict,
  precondition,
  deleted,
  invalid,
  cancelled,
}

class PlannerFailure implements Exception {
  const PlannerFailure(
    this.kind,
    this.message, {
    this.retryAt,
    this.uncertain = false,
  });
  final PlannerFailureKind kind;
  final String message;
  final DateTime? retryAt;
  final bool uncertain;
  @override
  String toString() => 'Planner operation failed (${kind.name}).';
}

class PlannerRemoteEvent {
  PlannerRemoteEvent(this.calendarId, Map<String, dynamic> value)
    : value = Map.unmodifiable(plannerJsonCopy(value));
  final String calendarId;
  final Map<String, dynamic> value;
  String get id => value['id'] as String;
  String get etag => value['etag'] as String? ?? '';
  bool get deleted => value['status'] == 'cancelled';
  Map get privateProperties =>
      (value['extendedProperties'] as Map?)?['private'] as Map? ?? {};
  bool get focusOwned => privateProperties['pomaOwner'] == 'poma.windows';
  bool get editable =>
      !deleted &&
      !focusOwned &&
      value['locked'] != true &&
      (value['eventType'] ?? 'default') == 'default' &&
      ((value['organizer'] as Map?)?['self'] == true ||
          value['guestsCanModify'] == true);
  Map<String, dynamic> get fields => {
    'summary': value['summary'] ?? 'Busy',
    'start': _endpoint(value['start'] as Map),
    'end': _endpoint(value['end'] as Map),
    'colorId': value['colorId'],
    'transparency': value['transparency'] ?? 'opaque',
    'recurrence': value['recurrence'] ?? <String>[],
  };

  static Map<String, dynamic> _endpoint(Map value) => {
    if (value['date'] != null) 'date': value['date'],
    if (value['dateTime'] != null)
      'dateTime': DateTime.parse(
        value['dateTime'] as String,
      ).toUtc().toIso8601String(),
    if (value['timeZone'] != null) 'timeZone': value['timeZone'],
  };

  CalendarEvent? get event {
    if (deleted || (value['recurrence'] as List? ?? []).isNotEmpty) return null;
    final start = value['start'] as Map, end = value['end'] as Map;
    return CalendarEvent.fromJson({
      'id': id,
      'calendarId': calendarId,
      'title': value['summary'] ?? 'Busy',
      'status': value['status'] ?? 'confirmed',
      'selfResponse':
          (value['attendees'] as List? ?? [])
              .whereType<Map>()
              .where((attendee) => attendee['self'] == true)
              .firstOrNull?['responseStatus'] ??
          'unknown',
      'startUtc': start['dateTime'],
      'endUtc': end['dateTime'],
      'startDate': start['date'],
      'endDate': end['date'],
      'startZone': start['timeZone'],
      'endZone': end['timeZone'],
      'recurringEventId': value['recurringEventId'],
      'originalStart':
          (value['originalStartTime'] as Map?)?['dateTime'] ??
          (value['originalStartTime'] as Map?)?['date'],
      'colorId': value['colorId'],
      'eventLabelId': value['eventLabelId'],
      'eventUrl': value['htmlLink'],
      'meetingUrl': value['hangoutLink'],
      'etag': etag,
      'updatedUtc': value['updated'],
      'transparency': value['transparency'] ?? 'opaque',
      'eventType': value['eventType'] ?? 'default',
      'locked': value['locked'] == true,
      'organizerSelf': (value['organizer'] as Map?)?['self'] == true,
      'guestsCanModify': value['guestsCanModify'] == true,
      'hasGuests':
          (value['attendees'] as List? ?? []).isNotEmpty ||
          value['attendeesOmitted'] == true,
      'focusOwned': focusOwned,
    });
  }
}

abstract interface class PlannerEventWriter {
  Future<bool> validateDestination(String accountKey, String calendarId);
  Future<PlannerRemoteEvent?> get(
    String accountKey,
    String calendarId,
    String eventId,
  );
  Future<PlannerRemoteEvent> create(PlannerOperation operation);
  Future<PlannerRemoteEvent> update(
    PlannerOperation operation,
    PlannerRemoteEvent latest,
    Map<String, dynamic> patch,
  );
  Future<void> delete(PlannerOperation operation, PlannerRemoteEvent latest);
  void cancel();
}
