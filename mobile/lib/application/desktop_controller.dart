import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/desktop_preferences.dart';
import '../domain/models.dart';
import 'app_controller.dart';
import 'calendar_controller.dart';
import 'calendar_connection_controller.dart';
import 'calendar_read_controller.dart';
import 'calendar_agenda_controller.dart';
import 'calendar_presentation_ports.dart';
import 'calendar_reminder_controller.dart';
import 'focus_block_controller.dart';
import '../domain/calendar_data.dart';

class FocusCalendarConflict {
  const FocusCalendarConflict(
    this.event,
    this.additional,
    this.stale,
    this.signature,
  );
  final CalendarEvent event;
  final int additional;
  final bool stale;
  final String signature;
}

class DesktopEnvironment {
  const DesktopEnvironment({
    required this.dataDirectory,
    required this.version,
    required this.packaged,
    this.visible = false,
    this.sessionState = 'unknown',
  });
  final String dataDirectory;
  final String version;
  final bool packaged;
  final bool visible;
  final String sessionState;
}

/// The host displays snapshots and requests actions. It owns no timer state.
abstract interface class DesktopShell {
  set onEvent(Future<void> Function(String, Map<String, Object?>)? handler);
  Future<void> configure(DesktopPreferences preferences);
  Future<void> publish(Map<String, Object?> snapshot);
  Future<void> armDeadline(TimerSnapshot? snapshot);
  Future<void> showMain();
  Future<void> showPopup({bool preview = false});
  Future<String> startupState();
  Future<String> setStartup(bool enabled);
  Future<void> exit();
}

enum CalendarPageSection { schedule, focusBlocks, settings }

/// Destination IDs are stable; their visual order differs from their IDs.
const desktopDestinationOrder = [0, 1, 4, 2, 3];

class DesktopController extends ChangeNotifier {
  DesktopController(
    this.controller,
    this.shell,
    this.environment, {
    CalendarController? calendar,
    this.connection,
    this.calendarData,
    this.calendarPlatform,
  }) : calendar = calendar ?? CalendarController() {
    controller.addListener(_queuePublish);
    this.calendar.addListener(_calendarChanged);
    connection?.addListener(_calendarChanged);
    calendarData?.addListener(_calendarChanged);
    sessionState = environment.sessionState;
    shell.onEvent = _event;
  }
  final AppController controller;
  final DesktopShell shell;
  final DesktopEnvironment environment;
  final CalendarController calendar;
  final CalendarConnectionController? connection;
  final CalendarReadController? calendarData;
  final CalendarPresentationPlatform? calendarPlatform;
  CalendarAgendaController? agenda;
  CalendarReminderController? reminders;
  FocusBlockController? focusBlocks;
  void attachFocusBlocks(FocusBlockController value) {
    focusBlocks = value;
    value.unlocked = sessionState == 'unlocked';
    value.addListener(_calendarChanged);
    unawaited(value.initialize());
  }

  Future<bool> Function(FocusCalendarConflict)? confirmFocusConflict;
  bool _starting = false;
  int _startEpoch = 0;
  bool get isQuitting => _quitting;
  String sessionState = 'unknown';
  int calendarSettingsRevision = 0;
  int calendarPresentationRevision = 0;
  CalendarPageSection calendarSection = CalendarPageSection.schedule;

  void _calendarChanged() {
    _queuePublish();
    if (!_disposed) notifyListeners();
  }

  void attachReminders(CalendarReminderController value) {
    reminders = value;
    value.unlocked = sessionState == 'unlocked';
    value.addListener(_calendarChanged);
    _calendarChanged();
  }

  Future<bool> Function()? confirmDiscard;
  Future<bool?> Function()? chooseAlerts;
  String startup = 'unavailable';
  String? error;
  int navigationRevision = 0;
  int destination = 0;
  int newTaskRevision = 0;
  bool _disposed = false;
  bool _publishing = false;
  bool _dirty = false;
  bool _quitting = false;
  bool _calendarDisposed = false;
  void _disposeCalendar() {
    if (_calendarDisposed) return;
    _calendarDisposed = true;
    focusBlocks?.removeListener(_calendarChanged);
    focusBlocks?.dispose();
    reminders?.removeListener(_calendarChanged);
    reminders?.dispose();
    agenda?.removeListener(_calendarChanged);
    agenda?.dispose();
    calendar.removeListener(_calendarChanged);
    calendar.dispose();
    calendarData?.removeListener(_calendarChanged);
    calendarData?.dispose();
    connection?.removeListener(_calendarChanged);
    connection?.dispose();
  }

  int _seenAlertOpen = 0;
  Future<void> _events = Future.value();

  Future<void> initialize() async {
    await controller.setForeground(environment.visible);
    await shell.configure(controller.desktopPreferences);
    await refreshStartup();
    calendarData?.initialize();
    if (calendarData != null && calendarPlatform != null) {
      agenda = CalendarAgendaController(
        reader: calendarData!,
        platform: calendarPlatform!,
        openSettings: () {
          openCalendarSection(CalendarPageSection.settings);
          unawaited(shell.showMain());
        },
      );
      agenda!.addListener(_calendarChanged);
    }
    _queuePublish();
    unawaited(connection?.initialize());
  }

  Future<void> refreshStartup() async {
    try {
      startup = await shell.startupState();
    } catch (_) {
      startup = 'unavailable';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> changeStartup(bool enabled) async {
    try {
      startup = await shell.setStartup(enabled);
      error = null;
    } catch (_) {
      error = 'Startup could not be changed. Check Windows startup settings.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> showPopup({bool preview = false}) {
    unawaited(calendarData?.opened());
    return shell.showPopup(preview: preview);
  }

  void openCalendarSection(CalendarPageSection section) {
    if (section == CalendarPageSection.settings) calendarSettingsRevision++;
    navigate(4, section: section);
  }

  void navigate(
    int index, {
    CalendarPageSection section = CalendarPageSection.schedule,
  }) {
    if (index == 4) {
      calendarSection = section;
      unawaited(calendarData?.opened());
    }
    controller.showInsights(index == 2);
    destination = index;
    navigationRevision++;
    notifyListeners();
  }

  void requestNewTask() {
    navigate(1);
    newTaskRevision++;
    notifyListeners();
  }

  Future<void> _event(String name, Map<String, Object?> values) {
    final operation = _events.then((_) async {
      if (_disposed || _quitting) return;
      switch (name) {
        case 'visibility':
          await controller.setForeground(values['visible'] == true);
          if (values['visible'] == true) unawaited(calendarData?.opened());
        case 'deadline':
          await controller.reconcile(expectedRunId: values['runId'] as String?);
          // Re-arm even if the OS callback was early and no transition notified.
          _queuePublish();
        case 'resume':
        case 'timeChanged':
          calendarPresentationRevision++;
          unawaited(focusBlocks?.stop().then((_) => focusBlocks?.initialize()));
          reminders?.lifecycle();
          agenda?.preferencesChanged();
          unawaited(calendarData?.lifecycleChanged());
          await controller.reconcile(forceAlerts: true);
          await refreshStartup();
        case 'suspend':
          unawaited(focusBlocks?.stop());
          reminders?.lifecycle(suspended: true);
        case 'calendarReminderDeadline':
          if (values['generation'] is int) {
            unawaited(reminders?.deadline(values['generation'] as int));
          }
        case 'calendarReminderAction':
          unawaited(reminders?.handleResponses());
        case 'settings':
          openCalendarSection(CalendarPageSection.settings);
          await shell.showMain();
        case 'open':
          await controller.reconcile(forceAlerts: true);
          navigate(0);
          await shell.showMain();
        case 'sessionState':
          sessionState = values['state'] == 'unlocked'
              ? 'unlocked'
              : values['state'] == 'locked'
              ? 'locked'
              : 'unknown';
          if (sessionState != 'unlocked') ++_startEpoch;
          focusBlocks?.unlocked = sessionState == 'unlocked';
          reminders?.unlocked = sessionState == 'unlocked';
          _queuePublish();
          notifyListeners();
        case 'calendarAction':
          if (sessionState == 'unlocked' &&
              values['generation'] is int &&
              values['actionId'] is String) {
            if (values['preview'] == true || agenda == null) {
              calendar.act(
                values['actionId'] as String,
                values['generation'] as int,
              );
            } else {
              unawaited(
                agenda!.act(
                  values['actionId'] as String,
                  values['generation'] as int,
                ),
              );
            }
          }
        case 'openPopup':
          if (values['preview'] != true) agenda?.opened();
          unawaited(calendarData?.opened());
          await controller.reconcile(forceAlerts: true);
        case 'timer':
          // Dialogs must not hold up resume, lock, Quit or expiry events.
          if (values['action'] == 'start') {
            unawaited(_timerAction(values));
          } else {
            await _timerAction(values);
          }
        case 'bounds':
          try {
            final bounds = DesktopBounds.fromJson(values);
            await controller.updateDesktopPreferences(
              controller.desktopPreferences.copyWith(bounds: bounds),
            );
          } on FormatException {
            // A transient minimized/invalid rectangle is not a saved position.
          }
        case 'closeExplained':
          await controller.updateDesktopPreferences(
            controller.desktopPreferences.copyWith(closeExplained: true),
          );
        case 'startupChanged':
          await refreshStartup();
        case 'quit':
          await quit();
      }
    });
    _events = operation.catchError((Object e, StackTrace s) {
      error = 'A desktop action failed. Your saved data is kept. Try again.';
      if (!_disposed) notifyListeners();
    });
    return _events;
  }

  Future<void> _timerAction(Map<String, Object?> values) async {
    final revision = values['revision'];
    final action = values['action'];
    if (revision is! int || values['runId'] != controller.timer.runId) return;
    if (action is! String) return;
    await requestTimerAction(
      action: action,
      revision: revision,
      runId: values['runId'] as String?,
    );
  }

  FocusCalendarConflict? _conflict() {
    final data = calendarData;
    if (data == null ||
        data.accountKey == null ||
        data.accountKey != data.connection.verifiedAccountKey) {
      return null;
    }
    final now = data.now;
    final end = now.add(Duration(seconds: controller.timer.totalSeconds));
    final events =
        data.events
            .where(
              (e) =>
                  !e.allDay &&
                  e.eligible &&
                  data.selected.contains(e.calendarId) &&
                  e.startUtc!.isBefore(end) &&
                  e.endUtc!.isAfter(now),
            )
            .toList()
          ..sort((a, b) {
            final time = a.startUtc!.compareTo(b.startUtc!);
            return time != 0
                ? time
                : '${a.calendarId}/${a.id}/${a.originalStart}'.compareTo(
                    '${b.calendarId}/${b.id}/${b.originalStart}',
                  );
          });
    if (events.isEmpty) return null;
    final stale =
        !data.connection.mayRead ||
        data.failure != null ||
        events.any(
          (e) =>
              data.sourceFailures[e.calendarId] != null ||
              data.snapshots[e.calendarId]?.fresh(now, data.window) != true,
        );
    final signature =
        '${data.accountKey}/${data.scopeGeneration}/$stale/${events.map((e) => '${e.calendarId}/${e.id}/${e.originalStart}/${e.startUtc}/${e.endUtc}/${e.title}').join('|')}';
    return FocusCalendarConflict(
      events.first,
      events.length - 1,
      stale,
      signature,
    );
  }

  Future<void> requestTimerAction({
    required String action,
    required int revision,
    required String? runId,
  }) async {
    if (_disposed || _quitting) return;
    bool current() =>
        !_disposed &&
        !_quitting &&
        controller.timer.revision == revision &&
        controller.timer.runId == runId;
    if (!current()) return;
    if (action == 'start') {
      if (_starting) return;
      _starting = true;
    }
    final epoch = _startEpoch;
    try {
      await controller.reconcile(expectedRunId: runId);
      if (!current()) return;
      if (action == 'start' && controller.timer.status != RunStatus.ready) {
        return;
      }
      if (action == 'start' && controller.needsAlertPermission) {
        await shell.showMain();
        final choice = chooseAlerts;
        if (choice == null) return;
        final enabled = await choice();
        if (enabled == null || !current() || epoch != _startEpoch) return;
        await controller.setCompletionAlerts(enabled);
      }
      if (action == 'start' && controller.timer.phase == FocusPhase.focus) {
        while (current()) {
          final conflict = _conflict();
          if (conflict == null) break;
          if (sessionState != 'unlocked' || confirmFocusConflict == null) {
            return;
          }
          await shell.showMain();
          if (await confirmFocusConflict!(conflict) != true ||
              !current() ||
              epoch != _startEpoch ||
              sessionState != 'unlocked') {
            return;
          }
          if (_conflict()?.signature == conflict.signature) break;
        }
      }
      if (!current() || (action == 'start' && epoch != _startEpoch)) return;
      switch (action) {
        case 'start':
          await controller.toggleTimer(
            expectedRevision: revision,
            expectedRunId: runId,
            displayedStatus: RunStatus.ready,
          );
        case 'pause':
          await controller.toggleTimer(
            expectedRevision: revision,
            expectedRunId: runId,
            displayedStatus: RunStatus.running,
          );
        case 'resume':
          await controller.toggleTimer(
            expectedRevision: revision,
            expectedRunId: runId,
            displayedStatus: RunStatus.paused,
          );
        case 'reset':
          await controller.resetTimer(
            expectedRevision: revision,
            expectedRunId: runId,
          );
        case 'skip':
          await controller.skipTimer(
            expectedRevision: revision,
            expectedRunId: runId,
          );
      }
      _queuePublish();
    } catch (_) {
      error = 'A timer action could not finish. Open Poma and try again.';
      if (!_disposed) notifyListeners();
    } finally {
      if (action == 'start') _starting = false;
    }
  }

  void _queuePublish() {
    if (_disposed || _quitting) return;
    if (_seenAlertOpen != controller.alertOpenRevision) {
      _seenAlertOpen = controller.alertOpenRevision;
      navigate(0);
      unawaited(shell.showMain());
    }
    _dirty = true;
    if (!_publishing) unawaited(_publish());
  }

  Future<void> _publish() async {
    _publishing = true;
    try {
      while (_dirty && !_disposed && !_quitting) {
        _dirty = false;
        final timer = controller.timer;
        final snapshot = timer.snapshot();
        await shell.publish({
          'phase': timer.phase.name,
          'phaseLabel': timer.phase.label,
          'status': timer.status.name,
          'seconds': timer.remainingSeconds,
          'rounds': timer.displayedRounds,
          'targetRounds': controller.settings.rounds,
          'revision': timer.revision,
          'runId': timer.runId,
          'task':
              controller.activeTaskTitle ??
              controller.selectedTask?.title ??
              '',
          'locked': timer.controlsLocked,
          'appearance': controller.settings.appearance,
          'error': controller.clockError != null
              ? 'Timer time needs attention.'
              : controller.saveError != null
              ? 'Unsaved changes. Open Poma to retry.'
              : controller.cleanupPending
              ? 'Data cleanup needs attention.'
              : '',
          'closeToTray': controller.desktopPreferences.closeToTray,
          'closeExplained': controller.desktopPreferences.closeExplained,
          ...?agenda?.display(
            unlocked: sessionState == 'unlocked',
            tooltipTitles: controller.desktopPreferences.tooltipTitles,
          ),
          if (agenda == null)
            ...calendar.display(
              unlocked: sessionState == 'unlocked',
              tooltipTitles: controller.desktopPreferences.tooltipTitles,
            ),
          'calendarPreview': calendar.display(
            unlocked: sessionState == 'unlocked',
            tooltipTitles: false,
          ),
        });
        await shell.armDeadline(
          controller.clockError == null && snapshot.status == RunStatus.running
              ? snapshot
              : null,
        );
      }
    } catch (_) {
      error = 'Desktop controls could not be updated. Open Poma and try again.';
      if (!_disposed) notifyListeners();
    } finally {
      _publishing = false;
    }
  }

  Future<void> quit() async {
    if (_quitting || _disposed) return;
    controller.focusAudio?.beginQuit();
    _quitting = true;
    await focusBlocks?.stop();
    ++_startEpoch;
    notifyListeners();
    await controller.setForeground(false);
    await controller.flush();
    if (controller.saveError != null) {
      await shell.showMain();
      if (await confirmDiscard?.call() != true) {
        _quitting = false;
        controller.focusAudio?.cancelQuit();
        unawaited(focusBlocks?.initialize());
        await controller.setForeground(true);
        _queuePublish();
        return;
      }
    }
    await shell.armDeadline(null);
    await controller.focusAudio?.close();
    _disposeCalendar();
    controller.removeListener(_queuePublish);
    controller.dispose();
    await controller.repository.close();
    await shell.exit();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    controller.removeListener(_queuePublish);
    _disposeCalendar();
    shell.onEvent = null;
    super.dispose();
  }
}
