import 'calendar_read_ports.dart';

abstract interface class CalendarReminderStore {
  Future<Map<String, Object?>?> read(CalendarCacheLease lease);
  Future<void> write(CalendarCacheLease lease, Map<String, Object?> document);
}

/// Resident scheduler/presenter only. No event contents cross this port.
abstract interface class CalendarReminderPlatform {
  Future<String> availability();
  Future<void> replace(int generation, Set<String> tokens);
  Future<void> arm(int generation, DateTime? deadline);
  Future<void> show(int generation, String token, DateTime expires);
  Future<List<Map<String, Object?>>> responses();
  Future<void> acknowledge(String token, String action);
}
