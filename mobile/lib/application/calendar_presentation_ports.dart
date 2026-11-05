import '../domain/calendar_data.dart';

/// Windows owns formatting preferences and browser launching, never schedule state.
abstract interface class CalendarPresentationPlatform {
  Future<Map<String, String>> formatCalendar(
    List<DateTime> instants,
    List<CalendarDate> dates,
  );
  Future<void> openCalendarLink(String url, String kind, int generation);
}
