import '../domain/calendar_data.dart';

enum CalendarReadFailureKind {
  cancelled,
  network,
  authorization,
  forbidden,
  throttled,
  response,
  storage,
}

class CalendarReadFailure implements Exception {
  const CalendarReadFailure(this.kind, {this.retryAt});
  final CalendarReadFailureKind kind;
  final DateTime? retryAt;
  @override
  String toString() => 'Calendar read failed (${kind.name}).';
}

abstract interface class CalendarReadProvider {
  Future<List<CalendarSource>> calendars();
  Future<List<CalendarEvent>> events(
    CalendarSource source,
    CalendarWindow window,
  );
  void cancel();
  void dispose();
}

class CalendarCacheLease {
  const CalendarCacheLease(this.revision, this.scope, this.accountKey);
  final int revision, scope;
  final String accountKey;
  Map<String, Object?> toJson() => {
    'revision': revision,
    'scope': scope,
    'accountKey': accountKey,
  };
}

abstract interface class CalendarCacheStore {
  Future<CalendarCacheLease> open(int revision, String accountKey);
  Future<CalendarAccountData?> read(CalendarCacheLease lease);
  Future<void> write(CalendarCacheLease lease, CalendarAccountData data);
  Future<void> invalidate();
}

abstract interface class CalendarClock {
  DateTime nowUtc();
  CalendarWindow window();
  CalendarWindow dayWindow(CalendarDate day);
  DateTime nextMidnightUtc();
}

abstract interface class CalendarScheduledJob {
  void cancel();
}

abstract interface class CalendarScheduler {
  CalendarScheduledJob after(Duration duration, void Function() callback);
}
