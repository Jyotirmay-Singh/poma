/// Provider dates are calendar values, never local/UTC instants.
class CalendarDate implements Comparable<CalendarDate> {
  CalendarDate(this.year, this.month, this.day) {
    final value = DateTime.utc(year, month, day);
    if (value.year != year || value.month != month || value.day != day) {
      throw const FormatException('Invalid calendar date.');
    }
  }
  factory CalendarDate.parse(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Invalid calendar date.');
    }
    return CalendarDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }
  final int year, month, day;
  CalendarDate plusDays(int count) {
    final value = DateTime.utc(year, month, day + count);
    return CalendarDate(value.year, value.month, value.day);
  }

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  @override
  int compareTo(CalendarDate other) => toString().compareTo(other.toString());
}

class CalendarWindow {
  const CalendarWindow({
    required this.first,
    required this.until,
    required this.startUtc,
    required this.endUtc,
  });
  final CalendarDate first, until;
  final DateTime startUtc, endUtc;
  String get key =>
      '$first/$until/${startUtc.toIso8601String()}/${endUtc.toIso8601String()}';
  bool covers(CalendarWindow other) =>
      !startUtc.isAfter(other.startUtc) &&
      !endUtc.isBefore(other.endUtc) &&
      first.compareTo(other.first) <= 0 &&
      until.compareTo(other.until) >= 0;
  CalendarWindow intersect(CalendarWindow other) {
    final start = startUtc.isAfter(other.startUtc) ? startUtc : other.startUtc;
    final end = endUtc.isBefore(other.endUtc) ? endUtc : other.endUtc;
    final date = first.compareTo(other.first) > 0 ? first : other.first;
    final last = until.compareTo(other.until) < 0 ? until : other.until;
    return CalendarWindow(
      first: date,
      until: last.compareTo(date) < 0 ? date : last,
      startUtc: start,
      endUtc: end.isBefore(start) ? start : end,
    );
  }

  Map<String, Object?> toJson() => {
    'first': '$first',
    'until': '$until',
    'start': startUtc.toIso8601String(),
    'end': endUtc.toIso8601String(),
  };
  factory CalendarWindow.fromJson(Map map) => CalendarWindow(
    first: CalendarDate.parse(map['first'] as String),
    until: CalendarDate.parse(map['until'] as String),
    startUtc: DateTime.parse(map['start'] as String).toUtc(),
    endUtc: DateTime.parse(map['end'] as String).toUtc(),
  );
}

String? safeCalendarColor(Object? value) =>
    value is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)
    ? value
    : null;

class CalendarSource {
  const CalendarSource({
    required this.id,
    required this.name,
    required this.accessRole,
    required this.timeZone,
    this.colorId,
    this.backgroundColor,
    this.foregroundColor,
    this.primary = false,
  });
  final String id, name, accessRole, timeZone;
  final String? colorId, backgroundColor, foregroundColor;
  final bool primary;
  bool get readable => const {
    'reader',
    'writerWithoutPrivateAccess',
    'writer',
    'owner',
  }.contains(accessRole);
  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'accessRole': accessRole,
    'timeZone': timeZone,
    'colorId': colorId,
    'backgroundColor': backgroundColor,
    'foregroundColor': foregroundColor,
    'primary': primary,
  };
  factory CalendarSource.fromJson(Map map) => CalendarSource(
    id: map['id'] as String,
    name: map['name'] as String,
    accessRole: map['accessRole'] as String,
    timeZone: map['timeZone'] as String,
    colorId: map['colorId'] as String?,
    backgroundColor: safeCalendarColor(map['backgroundColor']),
    foregroundColor: safeCalendarColor(map['foregroundColor']),
    primary: map['primary'] == true,
  );
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.status,
    required this.selfResponse,
    this.startUtc,
    this.endUtc,
    this.startDate,
    this.endDate,
    this.startZone,
    this.endZone,
    this.recurringEventId,
    this.originalStart,
    this.meetingUrl,
    this.eventUrl,
  });
  final String id, calendarId, title, status, selfResponse;
  final DateTime? startUtc, endUtc;
  final CalendarDate? startDate, endDate;
  final String? startZone,
      endZone,
      recurringEventId,
      originalStart,
      meetingUrl,
      eventUrl;
  bool get allDay => startDate != null;
  bool get eligible => status != 'cancelled' && selfResponse != 'declined';
  bool overlaps(CalendarWindow window) => allDay
      ? startDate!.compareTo(window.until) < 0 &&
            endDate!.compareTo(window.first) > 0
      : startUtc!.isBefore(window.endUtc) && endUtc!.isAfter(window.startUtc);
  Map<String, Object?> toJson() => {
    'id': id,
    'calendarId': calendarId,
    'title': title,
    'status': status,
    'selfResponse': selfResponse,
    'startUtc': startUtc?.toIso8601String(),
    'endUtc': endUtc?.toIso8601String(),
    'startDate': startDate?.toString(),
    'endDate': endDate?.toString(),
    'startZone': startZone,
    'endZone': endZone,
    'recurringEventId': recurringEventId,
    'originalStart': originalStart,
    'meetingUrl': meetingUrl,
    'eventUrl': eventUrl,
  };
  factory CalendarEvent.fromJson(Map map) {
    final result = CalendarEvent(
      id: map['id'] as String,
      calendarId: map['calendarId'] as String,
      title: map['title'] as String,
      status: map['status'] as String,
      selfResponse: map['selfResponse'] as String,
      startUtc: map['startUtc'] == null
          ? null
          : DateTime.parse(map['startUtc'] as String).toUtc(),
      endUtc: map['endUtc'] == null
          ? null
          : DateTime.parse(map['endUtc'] as String).toUtc(),
      startDate: map['startDate'] == null
          ? null
          : CalendarDate.parse(map['startDate'] as String),
      endDate: map['endDate'] == null
          ? null
          : CalendarDate.parse(map['endDate'] as String),
      startZone: map['startZone'] as String?,
      endZone: map['endZone'] as String?,
      recurringEventId: map['recurringEventId'] as String?,
      originalStart: map['originalStart'] as String?,
      meetingUrl: safeCalendarUrl(map['meetingUrl'] as String?, meeting: true),
      eventUrl: safeCalendarUrl(map['eventUrl'] as String?, meeting: false),
    );
    if (result.id.isEmpty ||
        (result.allDay
            ? result.endDate == null ||
                  result.startUtc != null ||
                  result.endUtc != null ||
                  result.endDate!.compareTo(result.startDate!) <= 0
            : result.startUtc == null ||
                  result.endUtc == null ||
                  result.endDate != null ||
                  !result.endUtc!.isAfter(result.startUtc!))) {
      throw const FormatException('Invalid cached event.');
    }
    return result;
  }
}

/// Data validation only. No caller here launches a browser or parses remote HTML.
String? safeCalendarUrl(String? value, {required bool meeting}) {
  if (value == null ||
      value.length > 4096 ||
      RegExp(
        r'[\s\x00-\x1f\x7f\\<>"\u202a-\u202e\u2066-\u2069]',
      ).hasMatch(value) ||
      value.contains("'") ||
      RegExp(r'%(?![0-9a-fA-F]{2})').hasMatch(value) ||
      RegExp(
        r'%(?:0[0-9a-f]|1[0-9a-f]|7f|5c)',
        caseSensitive: false,
      ).hasMatch(value)) {
    return null;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      !uri.hasAuthority ||
      (uri.hasPort && uri.port != 443)) {
    return null;
  }
  final host = uri.host.toLowerCase();
  // Validate the raw authority too: parsers must not turn encoded hostnames into
  // trusted hosts, or disagree with Windows about user info / empty DNS labels.
  final authority = RegExp(
    r'^https://([^/\?#]+)',
    caseSensitive: false,
  ).firstMatch(value)?.group(1);
  if (authority == null ||
      !RegExp(r'^[A-Za-z0-9.-]+(?::443)?$').hasMatch(authority) ||
      !host
          .split('.')
          .every(
            (label) =>
                RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label),
          )) {
    return null;
  }
  final path = uri.path;
  final accepted = meeting
      ? (host == 'meet.google.com' &&
                RegExp(
                  r'^/(?:[a-z]{3}-[a-z]{4}-[a-z]{3}|lookup/[A-Za-z0-9_-]+)/*$',
                ).hasMatch(path)) ||
            (const {
                  'teams.microsoft.com',
                  'teams.live.com',
                  'teams.cloud.microsoft',
                }.contains(host) &&
                RegExp(
                  r'^/(?:l/meetup-join/[^/]+/\d+|meet/[A-Za-z0-9_-]+)/*$',
                ).hasMatch(path)) ||
            ((host == 'zoom.us' || host.endsWith('.zoom.us')) &&
                RegExp(
                  r'^/(?:j/\d+|s/\d+|wc/join/\d+|my/[A-Za-z0-9._-]+)/*$',
                ).hasMatch(path))
      : const {'calendar.google.com', 'www.google.com'}.contains(host) &&
            RegExp(r'^/calendar/(?:u/\d+/)?event(?:/[^/]+)?/*$').hasMatch(path);
  return accepted ? uri.toString() : null;
}

/// Conservative literal extraction only. No remote HTML is rendered or stored.
String? calendarMeetingFromText(String? text) {
  if (text == null) return null;
  for (final match in RegExp(
    r'''(?:^|[\s<>"'(=])(https://[^\s<>"']+)''',
    caseSensitive: false,
  ).allMatches(text)) {
    final candidate = match
        .group(1)!
        .replaceAll('&amp;', '&')
        .replaceFirst(RegExp(r'[),.;]+$'), '');
    final safe = safeCalendarUrl(candidate, meeting: true);
    if (safe != null) return safe;
  }
  return null;
}

String? safeCalendarActionUrl(String? value, String kind) => switch (kind) {
  'calendar' => value == 'https://calendar.google.com/calendar/' ? value : null,
  'event' => safeCalendarUrl(value, meeting: false),
  'join' => safeCalendarUrl(value, meeting: true),
  _ => null,
};

class CalendarSnapshot {
  const CalendarSnapshot({
    required this.coverage,
    required this.succeededAt,
    required this.events,
  });
  final CalendarWindow coverage;
  final DateTime succeededAt;
  final List<CalendarEvent> events;
  CalendarSnapshot trim(CalendarWindow window) => CalendarSnapshot(
    coverage: coverage.intersect(window),
    succeededAt: succeededAt,
    events: List.unmodifiable(events.where((e) => e.overlaps(window))),
  );
  bool fresh(DateTime now, CalendarWindow window) =>
      coverage.covers(window) &&
      !succeededAt.isAfter(now) &&
      now.difference(succeededAt) <= const Duration(minutes: 5);
  Map<String, Object?> toJson() => {
    'coverage': coverage.toJson(),
    'succeededAt': succeededAt.toIso8601String(),
    'events': events.map((e) => e.toJson()).toList(),
  };
  factory CalendarSnapshot.fromJson(Map map, String calendarId) {
    final events = (map['events'] as List)
        .map((e) => CalendarEvent.fromJson(e as Map))
        .toList();
    if (events.any((e) => e.calendarId != calendarId)) {
      throw const FormatException('Cache source mismatch.');
    }
    return CalendarSnapshot(
      coverage: CalendarWindow.fromJson(map['coverage'] as Map),
      succeededAt: DateTime.parse(map['succeededAt'] as String).toUtc(),
      events: List.unmodifiable(events),
    );
  }
}

class CalendarAccountData {
  CalendarAccountData({
    required this.accountKey,
    List<CalendarSource> sources = const [],
    Set<String> selected = const {},
    Map<String, CalendarSnapshot> snapshots = const {},
  }) : sources = List.unmodifiable(sources),
       selected = Set.unmodifiable(selected),
       snapshots = Map.unmodifiable(snapshots);
  final String accountKey;
  final List<CalendarSource> sources;
  final Set<String> selected;
  final Map<String, CalendarSnapshot> snapshots;
  CalendarAccountData copyWith({
    List<CalendarSource>? sources,
    Set<String>? selected,
    Map<String, CalendarSnapshot>? snapshots,
  }) => CalendarAccountData(
    accountKey: accountKey,
    sources: sources ?? this.sources,
    selected: selected ?? this.selected,
    snapshots: snapshots ?? this.snapshots,
  );
  CalendarAccountData trim(CalendarWindow window) => copyWith(
    snapshots: {
      for (final entry in snapshots.entries)
        if (selected.contains(entry.key)) entry.key: entry.value.trim(window),
    },
  );
  Map<String, Object?> toJson() => {
    'version': 1,
    'accountKey': accountKey,
    'sources': sources.map((s) => s.toJson()).toList(),
    'selected': selected.toList(),
    'snapshots': snapshots.map((k, v) => MapEntry(k, v.toJson())),
  };
  factory CalendarAccountData.fromJson(Map map, String key) {
    if (map['version'] != 1 || map['accountKey'] != key) {
      throw const FormatException('Invalid calendar cache.');
    }
    final selected = Set<String>.from(map['selected'] as List);
    final result = CalendarAccountData(
      accountKey: key,
      sources: (map['sources'] as List)
          .map((s) => CalendarSource.fromJson(s as Map))
          .toList(),
      selected: selected,
      snapshots: {
        for (final entry in (map['snapshots'] as Map).entries)
          if (selected.contains(entry.key))
            entry.key as String: CalendarSnapshot.fromJson(
              entry.value as Map,
              entry.key as String,
            ),
      },
    );
    if (result.sources.map((s) => s.id).toSet().length !=
            result.sources.length ||
        selected.any(
          (id) => !result.sources.any((s) => s.id == id && s.readable),
        )) {
      throw const FormatException('Invalid calendar selection.');
    }
    return result;
  }
}
