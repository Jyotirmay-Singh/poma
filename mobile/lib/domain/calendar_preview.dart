/// Display-only fictional calendar data. No provider or persistence capability.
enum CalendarFixture {
  disconnected('Disconnected'),
  connecting('Connecting'),
  empty('Empty agenda'),
  normal('Normal agenda'),
  overlapping('Overlapping meetings'),
  longTitles('Long Unicode titles'),
  allDay('All-day events'),
  stale('Stale data'),
  error('Calendar error');

  const CalendarFixture(this.label);
  final String label;
}

class CalendarPreviewEvent {
  const CalendarPreviewEvent(
    this.id,
    this.title,
    this.calendar,
    this.start,
    this.end, {
    this.allDay = false,
  });
  final String id, title, calendar;
  final DateTime start, end;
  final bool allDay;
}

class CalendarSection {
  const CalendarSection({
    required this.id,
    required this.title,
    this.body = '',
    this.day = '',
    this.actionId = '',
    this.actionLabel = '',
    this.actions = const [],
  });
  final String id, title, body, day, actionId, actionLabel;
  final List<CalendarDisplayAction> actions;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'day': day,
    'actionId': actionId,
    'actionLabel': actionLabel,
    'actions': actions.map((a) => a.toJson()).toList(),
  };
}

class CalendarDisplayAction {
  const CalendarDisplayAction(
    this.id,
    this.label,
    this.accessibleName, {
    this.enabled = true,
  });
  final String id, label, accessibleName;
  final bool enabled;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'accessibleName': accessibleName,
    'enabled': enabled,
  };
}
