// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'poma_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class PomaLocalizationsEn extends PomaLocalizations {
  PomaLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get focus => 'Focus';

  @override
  String get timerPhase => 'Timer phase';

  @override
  String get tasks => 'Tasks';

  @override
  String get insights => 'Insights';

  @override
  String get settings => 'Settings';

  @override
  String get shortBreak => 'Short break';

  @override
  String get longBreak => 'Long break';

  @override
  String get startFocus => 'Start focus';

  @override
  String get startShortBreak => 'Start short break';

  @override
  String get startLongBreak => 'Start long break';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get inProgress => 'In progress';

  @override
  String get resetTimer => 'Reset timer';

  @override
  String get skipPhase => 'Skip to next phase';

  @override
  String get focusComplete =>
      'Focus complete. Start your break when you’re ready.';

  @override
  String get breakComplete =>
      'Break complete. Start your focus when you’re ready.';

  @override
  String get readyHint => 'Each phase starts when you choose.';

  @override
  String get pausedHint => 'Paused. Resume when you’re ready.';

  @override
  String get runningHint => 'Your timer continues when you leave Poma.';

  @override
  String get strictHint =>
      'Poma’s timer controls are locked until this phase finishes. Other apps remain available.';

  @override
  String get currentFocus => 'Current focus';

  @override
  String get nextFocus => 'Next focus';

  @override
  String get chooseTask => 'Choose a task';

  @override
  String get noTask => 'No task selected';

  @override
  String get unassignedFocus => 'Focus without a task';

  @override
  String get today => 'Today';

  @override
  String get loadingTotals => 'Loading focus totals…';

  @override
  String get retryTotals => 'Retry totals';

  @override
  String todayTotals(int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
      zero: 'No sessions',
    );
    return '$_temp0 · $minutes min focused';
  }

  @override
  String roundsComplete(int count, int total) {
    return '$count of $total focus rounds completed';
  }

  @override
  String remaining(int minutes, int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    String _temp1 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return '$_temp0 $_temp1 remaining';
  }

  @override
  String get ready => 'Ready';

  @override
  String get paused => 'Paused';

  @override
  String get running => 'Running';

  @override
  String get addTask => 'Add a task';

  @override
  String get taskHelp => 'Choose a task for your next focus.';

  @override
  String get emptyTasks => 'What would you like to work on?';

  @override
  String get emptyTasksHelp => 'Add one small, achievable task to get started.';

  @override
  String get allDone => 'All tasks completed';

  @override
  String get allDoneHelp =>
      'Add another task, or mark a completed task incomplete to use it again.';

  @override
  String get completed => 'Completed';

  @override
  String get selectedTask => 'Selected for next focus';

  @override
  String get selectTask => 'Select for next focus';

  @override
  String markComplete(String title) {
    return 'Mark $title complete';
  }

  @override
  String markIncomplete(String title) {
    return 'Mark $title incomplete';
  }

  @override
  String taskOptions(String title) {
    return 'Options for $title';
  }

  @override
  String get rename => 'Rename';

  @override
  String get renameTask => 'Rename task';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveTask => 'Save task';

  @override
  String get taskName => 'What will you work on?';

  @override
  String get enterTask => 'Enter a task name.';

  @override
  String get weekHelp => 'Your completed focus sessions, stored on this phone.';

  @override
  String get lastSevenDays => 'Focused over the last 7 days';

  @override
  String get dailyTotals => 'Daily focus totals';

  @override
  String focusedMinutes(int minutes) {
    return '$minutes min focused';
  }

  @override
  String minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String dailySummary(String date, int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
      zero: 'no sessions',
    );
    return '$date: $_temp0, $minutes minutes focused';
  }

  @override
  String get recentSessions => 'Recent sessions';

  @override
  String get loadingHistory => 'Loading history';

  @override
  String get retryHistory => 'Retry history';

  @override
  String get emptyHistory =>
      'Finish your first focus session to see it here. Skipped sessions are not counted.';

  @override
  String get focusSession => 'Focus session';

  @override
  String sessionDate(String date, String time) {
    return '$date at $time';
  }

  @override
  String get deleteSession => 'Delete session';

  @override
  String deleteNamedSession(String title, String date) {
    return 'Delete $title, $date';
  }

  @override
  String get deleteSessionTitle => 'Delete session?';

  @override
  String get deleteSessionHelp =>
      'Remove this completed session from history and focus totals?';

  @override
  String get newer => 'Newer';

  @override
  String get older => 'Older';

  @override
  String get latest => 'Latest';

  @override
  String get historyRetention =>
      'History stays on this phone until you delete it.';

  @override
  String get settingsHelp => 'Timing, appearance, alerts, and your local data.';

  @override
  String get timing => 'Timing';

  @override
  String get focusDuration => 'Focus duration';

  @override
  String get shortDuration => 'Short break duration';

  @override
  String get longDuration => 'Long break duration';

  @override
  String get cycleRounds => 'Focus rounds before a long break';

  @override
  String get durationHelp =>
      'Duration changes apply immediately to a ready timer. A running or paused phase keeps its original duration.';

  @override
  String get strictMode => 'Strict mode';

  @override
  String get strictHelp =>
      'Locks pause, reset, skip, phase changes, and timing settings while a phase runs. It cannot lock your phone or block other apps.';

  @override
  String get appearance => 'Appearance';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get alerts => 'Alerts';

  @override
  String get completionAlerts => 'Completion alerts';

  @override
  String get alertHelp =>
      'One local alert for each phase you start. Your phone controls presentation and sound. The next phase always starts manually.';

  @override
  String get alertNotAsked =>
      'Choose whether to allow alerts when you start a timer.';

  @override
  String get alertReady =>
      'Completion alerts are enabled. Delivery follows your phone’s notification settings.';

  @override
  String get alertDisabled =>
      'Completion alerts are off in Poma. Your timer still works.';

  @override
  String get alertDelayed =>
      'Alerts may be delayed. Allow precise alerts in Settings.';

  @override
  String get alertDenied =>
      'Completion alerts are off in your phone’s notification settings.';

  @override
  String get alertFailed =>
      'Completion alert could not be registered. Your timer is kept. Try again.';

  @override
  String get alertUnavailable =>
      'Completion alerts are unavailable. Your timer still works.';

  @override
  String get phoneSettings => 'Phone notification settings';

  @override
  String get preciseAlerts => 'Allow precise alerts';

  @override
  String get retryAlerts => 'Retry alerts';

  @override
  String get alertPromptTitle => 'Know when your time is up';

  @override
  String get alertPromptHelp =>
      'Allow completion alerts while your phone is locked or you use another app. Your phone controls sound and delivery.';

  @override
  String get notNow => 'Not now';

  @override
  String get enableAlerts => 'Enable alerts';

  @override
  String get localData => 'Local data';

  @override
  String get privacyHelp =>
      'Tasks, settings, and history are stored on this phone. Poma requests that they be left out of automatic backups. System backup and phone-transfer behavior can vary, and older backups may retain data. There is no automatic recovery if you uninstall Poma or lose the phone. No account, ads, or tracking.';

  @override
  String get deletionHelp =>
      'History is kept until you delete it. Deleting data cannot be undone.';

  @override
  String get clearHistory => 'Clear focus history';

  @override
  String get clearHistoryTitle => 'Clear focus history?';

  @override
  String get clearHistoryHelp =>
      'Delete all completed sessions and their totals? Your tasks, settings, and current timer stay.';

  @override
  String get historyDeleted => 'Focus history deleted.';

  @override
  String get deleteAll => 'Delete all local data';

  @override
  String get deleteAllTitle => 'Delete all local data?';

  @override
  String get deleteAllHelp =>
      'Stop the current timer, cancel Poma alerts, delete all tasks and history, and restore app defaults? This also stops a strict session.';

  @override
  String get localDataDeleted => 'Local data deleted.';

  @override
  String get cleanupUnfinished => 'Local alert cleanup is unfinished.';

  @override
  String get retryDeletion => 'Retry deletion';

  @override
  String get about => 'About Poma';

  @override
  String get aboutHelp =>
      'An offline Pomodoro companion for Android and iOS. Inspired by the MIT-licensed Pomatez project.';

  @override
  String get attribution =>
      'Pomatez © 2024 Roldan Montilla Jr.\nSee THIRD_PARTY_NOTICES.md in the source distribution.';

  @override
  String decrease(String label) {
    return 'Decrease $label';
  }

  @override
  String increase(String label) {
    return 'Increase $label';
  }

  @override
  String rounds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rounds',
      one: '1 round',
    );
    return '$_temp0';
  }

  @override
  String get retry => 'Retry';

  @override
  String get finishDeletion => 'Finish deletion';

  @override
  String get cleanupNotice =>
      'Data deletion needs retry before starting another timer.';

  @override
  String get clockError =>
      'Timer time could not be read. Try again. Your data is kept.';

  @override
  String get storageFull =>
      'Storage is full. Free up space and retry. Unsaved changes may be lost if Poma closes.';

  @override
  String get storageWrite =>
      'Changes could not be saved. Retry. Unsaved changes may be lost if Poma closes.';

  @override
  String get storageUnreadable =>
      'Saved data could not be read. Your existing data is kept. Retry.';

  @override
  String get storageMigration =>
      'Saved data could not be upgraded. Your existing data is kept. Retry.';

  @override
  String get storageConflict =>
      'Saved data changed unexpectedly. Reopen Poma before making more changes.';

  @override
  String get startupPrivacy =>
      'Local storage privacy settings could not be applied.';

  @override
  String get startupRead => 'Your saved data could not be opened.';

  @override
  String get tryAgainHelp => 'Try again. Your existing data will be kept.';

  @override
  String get tryAgain => 'Try again';

  @override
  String get opening => 'Opening Poma';

  @override
  String get totalsReadError => 'Focus totals could not be read. Retry.';

  @override
  String get historyReadError =>
      'History could not be read. Your data is kept. Retry.';

  @override
  String get deletionSaveError =>
      'Deletion could not be saved. Data may still be on this phone. Retry saving.';

  @override
  String get deletionCleanupError =>
      'Data deletion is not complete. Retry to finish saving and clearing local alerts.';
}
