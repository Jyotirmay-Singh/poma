import 'dart:async';

import 'package:flutter/foundation.dart';

import 'local_repository.dart';
import '../domain/models.dart';
import '../domain/timer_engine.dart';

class AppController extends ChangeNotifier {
  AppController._(this.repository, SavedState state, TimerClock? clock)
    : settings = state.settings,
      tasks = state.tasks.toList(),
      sessions = state.sessions.toList(),
      selectedTaskId = state.selectedTaskId,
      timer = TimerEngine(
        settings: state.settings,
        restored: state.timer,
        clock: clock,
      );

  static Future<AppController> create(
    LocalRepository repository, {
    TimerClock? clock,
  }) async {
    final state = await repository.load();
    final controller = AppController._(repository, state, clock);
    controller.refresh();
    await controller.flush();
    return controller;
  }

  final LocalRepository repository;
  final TimerEngine timer;
  TimerSettings settings;
  final List<FocusTask> tasks;
  final List<FocusSession> sessions;
  String? selectedTaskId;
  String? saveError;
  Timer? _ticker;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  bool _foreground = false;

  FocusTask? get selectedTask {
    for (final task in tasks) {
      if (task.id == selectedTaskId && !task.done) return task;
    }
    return null;
  }

  List<FocusSession> sessionsOn(DateTime date) => sessions.where((session) {
    final local = session.endedAt.toLocal();
    return local.year == date.year &&
        local.month == date.month &&
        local.day == date.day;
  }).toList();

  void setForeground(bool foreground) {
    _foreground = foreground;
    refresh();
    _persist();
  }

  bool refresh() {
    final beforePhase = timer.phase;
    final beforeStatus = timer.status;
    final completed = timer.tick();
    if (completed != null && !sessions.any((s) => s.id == completed.id)) {
      sessions.insert(0, completed);
    }
    final transitioned =
        beforePhase != timer.phase || beforeStatus != timer.status;
    if (transitioned) _persist();
    _syncTicker();
    if (!_disposed) notifyListeners();
    return transitioned;
  }

  void toggleTimer() {
    if (refresh()) return;
    if (timer.status == RunStatus.running) {
      timer.pause();
    } else {
      timer.start(task: selectedTask);
    }
    _changed();
  }

  void resetTimer() {
    if (refresh()) return;
    timer.reset();
    _changed();
  }

  void skipTimer() {
    if (refresh()) return;
    timer.skip();
    _changed();
  }

  void selectPhase(FocusPhase phase) {
    refresh();
    timer.selectPhase(phase);
    _changed();
  }

  void updateSettings(TimerSettings next) {
    refresh();
    // Strict mode cannot be switched off in the middle of a strict session.
    if (timer.controlsLocked && !next.strictMode) return;
    settings = TimerSettings.fromJson(next.toJson());
    timer.updateSettings(settings);
    _changed();
  }

  void addTask(String title) {
    final clean = title.trim();
    if (clean.isEmpty || clean.length > 160) return;
    final task = FocusTask(id: newLocalId(), title: clean);
    tasks.add(task);
    selectedTaskId ??= task.id;
    _changed();
  }

  void editTask(String id, String title) {
    final index = tasks.indexWhere((task) => task.id == id);
    final clean = title.trim();
    if (index < 0 || clean.isEmpty || clean.length > 160) return;
    tasks[index] = tasks[index].copyWith(title: clean);
    _changed();
  }

  void toggleTask(String id) {
    final index = tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    tasks[index] = tasks[index].copyWith(done: !tasks[index].done);
    if (tasks[index].done && selectedTaskId == id) selectedTaskId = null;
    _changed();
  }

  void selectTask(String? id) {
    selectedTaskId = id;
    _changed();
  }

  void deleteTask(String id) {
    tasks.removeWhere((task) => task.id == id);
    if (selectedTaskId == id) selectedTaskId = null;
    _changed();
  }

  void retrySave() => _persist();
  Future<void> flush() => _writes;

  void _changed() {
    _persist();
    _syncTicker();
    if (!_disposed) notifyListeners();
  }

  void _syncTicker() {
    if (!_foreground || timer.status != RunStatus.running || _disposed) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    }
  }

  void _persist() {
    final state = SavedState(
      settings: settings,
      timer: timer.snapshot(),
      tasks: tasks,
      sessions: sessions,
      selectedTaskId: selectedTaskId,
    );
    // Serialize writes in the order of user actions; later state cannot be
    // overwritten by an earlier, slower database transaction.
    _writes = _writes
        .then((_) => repository.save(state))
        .then((_) {
          if (saveError != null) {
            saveError = null;
            if (!_disposed) notifyListeners();
          }
        })
        .catchError((Object error, StackTrace stack) {
          saveError =
              'Changes could not be saved. Free up storage and try again.';
          if (!_disposed) notifyListeners();
        });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
