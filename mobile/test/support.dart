import 'package:poma/application/local_repository.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/domain/timer_engine.dart';

class FakeClock implements TimerClock {
  FakeClock([DateTime? now]) : utcNow = now ?? DateTime.utc(2026, 10, 20, 9);
  DateTime utcNow;
  Duration elapsed = Duration.zero;
  ClockReading get reading =>
      ClockReading(utcNow: utcNow, elapsed: elapsed, bootCount: bootCount);
  bool failReads = false;
  int? bootCount;
  @override
  Future<ClockReading> sample() async {
    if (failReads) throw const TimerClockException();
    return reading;
  }

  void advance(Duration duration) {
    utcNow = utcNow.add(duration);
    elapsed += duration;
  }
}

class MemoryRepository implements LocalRepository {
  MemoryRepository([SavedState? initial]) : state = initial ?? SavedState();
  SavedState state;
  bool failWrites = false;
  int writes = 0;
  final Set<String> receipts = {};
  bool failReceipts = false;
  @override
  Future<String?> notificationDatabasePath() async => null;
  @override
  Future<bool> recordAlertReceipt(String key) async {
    if (failReceipts) throw StateError('Receipt write failed');
    return receipts.add(key);
  }

  Future<SavedState> load() async => state;
  @override
  Future<SavedState> loadInitial() => load();

  Future<void> save(SavedState next) async {
    writes++;
    if (failWrites) throw StateError('Disk full');
    state = next;
  }

  @override
  Future<int> commit(LocalCommit request) async {
    writes++;
    if (failWrites) throw const StorageFailure(StorageFailureKind.full);
    if (state.lastCommitId == request.id &&
        state.revision == request.expectedRevision + 1) {
      return state.revision;
    }
    if (state.revision != request.expectedRevision) {
      throw const StorageFailure(StorageFailureKind.conflict);
    }
    var tasks = state.tasks.toList();
    var sessions = state.sessions.toList();
    for (final change in request.changes) {
      if (change.reset) tasks.clear();
      if (change.reset || change.clearHistory) sessions.clear();
      if (change.reset) receipts.clear();
      tasks.removeWhere((task) => change.deletedTasks.contains(task.id));
      sessions.removeWhere(
        (session) => change.deletedSessions.contains(session.id),
      );
      for (final task in change.tasks) {
        final index = tasks.indexWhere((old) => old.id == task.id);
        if (index < 0) {
          tasks.add(task);
        } else {
          tasks[index] = task;
        }
      }
      for (final session in change.completions) {
        if (!sessions.any((old) => old.id == session.id)) sessions.add(session);
      }
      state = SavedState(
        settings: change.state.settings,
        timer: change.state.timer,
        selectedTaskId: change.state.selectedTaskId,
        alerts: change.state.alerts,
        cleanupPending: change.state.cleanupPending,
        tasks: tasks,
        sessions: sessions,
        revision: request.expectedRevision + 1,
        lastCommitId: request.id,
      );
    }
    return state.revision;
  }

  @override
  Future<HistoryPage> readHistoryPage({
    HistoryCursor? before,
    HistoryCursor? after,
  }) async {
    final all = state.sessions.toList()
      ..sort((a, b) {
        final time = b.endedAt.compareTo(a.endedAt);
        return time == 0 ? b.id.compareTo(a.id) : time;
      });
    bool older(FocusSession s, HistoryCursor c) =>
        s.endedAt.microsecondsSinceEpoch < c.endedMicros ||
        (s.endedAt.microsecondsSinceEpoch == c.endedMicros &&
            s.id.compareTo(c.id) < 0);
    bool newer(FocusSession s, HistoryCursor c) =>
        s.endedAt.microsecondsSinceEpoch > c.endedMicros ||
        (s.endedAt.microsecondsSinceEpoch == c.endedMicros &&
            s.id.compareTo(c.id) > 0);
    var filtered = all
        .where(
          (s) =>
              (before == null || older(s, before)) &&
              (after == null || newer(s, after)),
        )
        .toList();
    if (after != null) filtered = filtered.reversed.toList();
    var page = filtered.take(50).toList();
    if (after != null) page = page.reversed.toList();
    return HistoryPage(
      page,
      hasOlder:
          page.isNotEmpty &&
          all.any((s) => older(s, HistoryCursor.forSession(page.last))),
      hasNewer:
          page.isNotEmpty &&
          all.any((s) => newer(s, HistoryCursor.forSession(page.first))),
    );
  }

  @override
  Future<List<DaySummary>> readDaySummaries(List<DayRange> days) async =>
      days.map((day) {
        final sessions = state.sessions.where(
          (s) =>
              !s.endedAt.isBefore(day.startUtc) &&
              s.endedAt.isBefore(day.endUtc),
        );
        return DaySummary(
          day.date,
          sessions.length,
          sessions.fold(0, (sum, s) => sum + s.focusSeconds),
        );
      }).toList();

  @override
  Future<void> close() async {}
}

/// Test-only fixture helpers. Production startup never enumerates history.
extension RepositoryFixtures on LocalRepository {
  Future<SavedState> load() async {
    final initial = await loadInitial();
    final sessions = <FocusSession>[];
    HistoryCursor? cursor;
    while (true) {
      final page = await readHistoryPage(before: cursor);
      sessions.addAll(page.sessions);
      if (!page.hasOlder || page.sessions.isEmpty) break;
      cursor = HistoryCursor.forSession(page.sessions.last);
    }
    return SavedState(
      settings: initial.settings,
      timer: initial.timer,
      tasks: initial.tasks,
      sessions: sessions,
      selectedTaskId: initial.selectedTaskId,
      alerts: initial.alerts,
      revision: initial.revision,
      lastCommitId: initial.lastCommitId,
      cleanupPending: initial.cleanupPending,
    );
  }

  Future<void> save(SavedState state) async {
    final old = await loadInitial();
    await commit(
      LocalCommit(
        id: newLocalId(),
        expectedRevision: old.revision,
        changes: [
          LocalChange(
            state: state,
            tasks: state.tasks,
            deletedTasks: old.tasks
                .where((t) => !state.tasks.any((n) => n.id == t.id))
                .map((t) => t.id)
                .toList(),
            completions: state.sessions,
          ),
        ],
      ),
    );
  }
}
