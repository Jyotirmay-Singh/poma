/// Calendar policy is deliberately independent of timer notification state.
class CalendarReminderPreferences {
  const CalendarReminderPreferences({
    this.enabled = false,
    this.leadMinutes = 5,
    this.calendars = const {},
  });
  static const leads = [1, 5, 10, 15, 30];
  final bool enabled;
  final int leadMinutes;
  final Set<String> calendars;
  CalendarReminderPreferences copyWith({
    bool? enabled,
    int? leadMinutes,
    Set<String>? calendars,
  }) => CalendarReminderPreferences(
    enabled: enabled ?? this.enabled,
    leadMinutes: leadMinutes ?? this.leadMinutes,
    calendars: Set.unmodifiable(calendars ?? this.calendars),
  );
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'leadMinutes': leadMinutes,
    'calendars': calendars.toList()..sort(),
  };
  factory CalendarReminderPreferences.fromJson(Map map) {
    if (map['enabled'] is! bool ||
        !leads.contains(map['leadMinutes']) ||
        map['calendars'] is! List ||
        (map['calendars'] as List).any((e) => e is! String)) {
      throw const FormatException('Invalid reminder preferences.');
    }
    return CalendarReminderPreferences(
      enabled: map['enabled'] as bool,
      leadMinutes: map['leadMinutes'] as int,
      calendars: Set.unmodifiable(Set<String>.from(map['calendars'] as List)),
    );
  }
}
