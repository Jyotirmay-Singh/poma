/// A half-open interval of completion timestamps.
class SessionRange {
  const SessionRange(this.startUtc, this.endUtc);
  final DateTime startUtc;
  final DateTime endUtc;
}

class SessionTotals {
  const SessionTotals(this.count, this.focusSeconds);
  final int count;
  final int focusSeconds;
}

enum AnalyticsPeriod {
  week,
  month,
  year;

  DateTime start(DateTime date) => switch (this) {
    week => DateTime(date.year, date.month, date.day - date.weekday + 1),
    month => DateTime(date.year, date.month),
    year => DateTime(date.year),
  };

  DateTime move(DateTime date, int steps) => switch (this) {
    week => DateTime(date.year, date.month, date.day + steps * 7),
    month => DateTime(date.year, date.month + steps),
    year => DateTime(date.year + steps),
  };
}

class AnalyticsWindow {
  const AnalyticsWindow(this.start, this.end, this.range);
  final DateTime start;
  final DateTime end;
  final SessionRange range;

  DateTime get lastDate => DateTime(end.year, end.month, end.day - 1);
}

/// Calendar arithmetic stays separate from elapsed-time arithmetic. The boundary
/// converter shares the application's injectable local-day timezone policy.
class AnalyticsQuery {
  AnalyticsQuery._({
    required this.today,
    required this.period,
    required this.anchor,
    required this.metrics,
    required this.buckets,
    required this.chartWindow,
  });

  factory AnalyticsQuery.forDate(
    DateTime now, {
    AnalyticsPeriod period = AnalyticsPeriod.week,
    DateTime? anchor,
    DateTime Function(DateTime)? boundaryUtc,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final monday = AnalyticsPeriod.week.start(today);
    final month = AnalyticsPeriod.month.start(today);
    final convert = boundaryUtc ?? (date) => date.toUtc();
    AnalyticsWindow window(DateTime start, DateTime end) =>
        AnalyticsWindow(start, end, SessionRange(convert(start), convert(end)));

    final current = period.start(today);
    final requested = period.start(anchor ?? today);
    final selected = requested.isAfter(current) ? current : requested;
    final chartEnd = period.move(selected, 1);
    final length = switch (period) {
      AnalyticsPeriod.week => 7,
      AnalyticsPeriod.month => DateTime(
        selected.year,
        selected.month + 1,
        0,
      ).day,
      AnalyticsPeriod.year => 12,
    };
    final buckets = List.generate(length, (i) {
      final start = period == AnalyticsPeriod.year
          ? DateTime(selected.year, i + 1)
          : DateTime(selected.year, selected.month, selected.day + i);
      final end = period == AnalyticsPeriod.year
          ? DateTime(selected.year, i + 2)
          : DateTime(start.year, start.month, start.day + 1);
      return window(start, end);
    });
    return AnalyticsQuery._(
      today: today,
      period: period,
      anchor: selected,
      metrics: List.unmodifiable([
        window(today, tomorrow),
        window(monday, tomorrow),
        window(DateTime(month.year, month.month - 1), month),
        window(DateTime(today.year, today.month, today.day - 30), today),
        window(DateTime(monday.year, monday.month, monday.day - 84), monday),
        window(DateTime(month.year, month.month - 12), month),
      ]),
      buckets: List.unmodifiable(buckets),
      chartWindow: window(selected, chartEnd),
    );
  }

  final DateTime today;
  final AnalyticsPeriod period;
  final DateTime anchor;
  final List<AnalyticsWindow> metrics;
  final List<AnalyticsWindow> buckets;
  final AnalyticsWindow chartWindow;
  List<SessionRange> get ranges => List.unmodifiable([
    ...metrics.map((window) => window.range),
    ...buckets.map((window) => window.range),
  ]);
  bool get canGoForward => anchor.isBefore(period.start(today));
  bool get isCurrentPeriod => anchor == period.start(today);
  bool isFuture(int index) => buckets[index].start.isAfter(today);
  bool isCurrent(int index) =>
      !buckets[index].start.isAfter(today) && buckets[index].end.isAfter(today);
}

class AnalyticsSnapshot {
  AnalyticsSnapshot(this.query, List<SessionTotals> totals)
    : totals = List.unmodifiable(totals) {
    if (totals.length != query.metrics.length + query.buckets.length) {
      throw ArgumentError('Analytics totals must match the requested ranges.');
    }
  }

  final AnalyticsQuery query;
  final List<SessionTotals> totals;
  SessionTotals get today => totals[0];
  SessionTotals get thisWeek => totals[1];
  SessionTotals get lastMonth => totals[2];
  double get dailyAverage => totals[3].count / 30;
  double get weeklyAverage => totals[4].count / 12;
  double get monthlyAverage => totals[5].count / 12;
  SessionTotals bucket(int index) => totals[query.metrics.length + index];
  bool get hasSessions => totals.any((total) => total.count > 0);
}
