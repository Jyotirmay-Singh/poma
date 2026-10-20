import '../domain/models.dart';

enum StorageFailureKind { full, write, unreadable, migration, conflict }

/// Contains no platform exception, SQL arguments, or user text.
class StorageFailure implements Exception {
  const StorageFailure(this.kind);
  final StorageFailureKind kind;
  String get message => switch (kind) {
    StorageFailureKind.full =>
      'Storage is full. Free up space and retry. Unsaved changes may be lost if Poma closes.',
    StorageFailureKind.write =>
      'Changes could not be saved. Retry. Unsaved changes may be lost if Poma closes.',
    StorageFailureKind.unreadable =>
      'Saved data could not be read. Your existing data is kept. Retry.',
    StorageFailureKind.migration =>
      'Saved data could not be upgraded. Your existing data is kept. Retry.',
    StorageFailureKind.conflict =>
      'Saved data changed unexpectedly. Reopen Poma before making more changes.',
  };
  @override
  String toString() => 'StorageFailure(${kind.name})';
}

/// Only dirty rows and new completions, never the history cache.
class LocalChange {
  LocalChange({
    required this.state,
    List<FocusTask> tasks = const [],
    List<String> deletedTasks = const [],
    List<FocusSession> completions = const [],
    List<String> deletedSessions = const [],
    this.clearHistory = false,
    this.reset = false,
  }) : tasks = List.unmodifiable(tasks),
       deletedTasks = List.unmodifiable(deletedTasks),
       completions = List.unmodifiable(completions),
       deletedSessions = List.unmodifiable(deletedSessions);
  final SavedState state;
  final List<FocusTask> tasks;
  final List<String> deletedTasks;
  final List<FocusSession> completions;
  final List<String> deletedSessions;
  final bool clearHistory;
  final bool reset;
}

class LocalCommit {
  LocalCommit({
    required this.id,
    required this.expectedRevision,
    required List<LocalChange> changes,
    this.supersedesId,
  }) : changes = List.unmodifiable(changes);
  final String id;
  final int expectedRevision;
  final String? supersedesId;
  final List<LocalChange> changes;
}

class HistoryCursor {
  const HistoryCursor(this.endedMicros, this.id);
  factory HistoryCursor.forSession(FocusSession session) =>
      HistoryCursor(session.endedAt.microsecondsSinceEpoch, session.id);
  final int endedMicros;
  final String id;
}

class HistoryPage {
  const HistoryPage(
    this.sessions, {
    this.hasOlder = false,
    this.hasNewer = false,
  });
  final List<FocusSession> sessions;
  final bool hasOlder;
  final bool hasNewer;
}

class DayRange {
  const DayRange(this.date, this.startUtc, this.endUtc);
  factory DayRange.local(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return DayRange(
      start,
      start.toUtc(),
      DateTime(date.year, date.month, date.day + 1).toUtc(),
    );
  }
  final DateTime date;
  final DateTime startUtc;
  final DateTime endUtc;
}

class DaySummary {
  const DaySummary(this.date, this.count, this.focusSeconds);
  final DateTime date;
  final int count;
  final int focusSeconds;
}

abstract interface class LocalRepository {
  Future<SavedState> loadInitial();
  Future<int> commit(LocalCommit commit);
  Future<HistoryPage> readHistoryPage({
    HistoryCursor? before,
    HistoryCursor? after,
  });
  Future<List<DaySummary>> readDaySummaries(List<DayRange> days);
  Future<void> close();
  Future<String?> notificationDatabasePath();
  Future<bool> recordAlertReceipt(String key);
}
