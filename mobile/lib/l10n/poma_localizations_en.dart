// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'poma_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class PomaLocalizationsEn extends PomaLocalizations {
  PomaLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get focusSounds => 'Focus sounds';

  @override
  String get soundOff => 'Off';

  @override
  String get soundBells => 'Tibetan bells';

  @override
  String get soundWaterfall => 'Waterfall';

  @override
  String get soundOcean => 'Ocean waves';

  @override
  String get soundBirds => 'Forest birds';

  @override
  String get soundRain => 'Calming rain';

  @override
  String get soundOm => 'OM chanting';

  @override
  String get soundBellsDetail => 'Bowl tones';

  @override
  String get soundWaterfallDetail => 'Flowing water';

  @override
  String get soundOceanDetail => 'Gentle waves';

  @override
  String get soundBirdsDetail => 'Birdsong';

  @override
  String get soundRainDetail => 'Piano and rainfall';

  @override
  String get soundOnlyFocus => 'Session audio plays during Focus';

  @override
  String get soundSelected => 'Selected';

  @override
  String get soundReady => 'Selected for focus';

  @override
  String get soundPlaying => 'Playing';

  @override
  String get soundPaused => 'Sound paused';

  @override
  String get soundTimerPaused => 'Paused with timer';

  @override
  String get soundMuted => 'Muted';

  @override
  String get soundZero => 'Volume 0%';

  @override
  String get soundBreak => 'Silent during break';

  @override
  String get soundRoute => 'Audio output changed';

  @override
  String get soundInterrupted => 'Sound interrupted';

  @override
  String get soundFailed => 'Sound couldn’t play';

  @override
  String get soundUnavailable => 'Playback unavailable on this device';

  @override
  String soundLoading(String sound) {
    return 'Loading $sound…';
  }

  @override
  String soundPreviewing(String sound) {
    return 'Previewing $sound';
  }

  @override
  String get soundLoadingPreview => 'Loading preview…';

  @override
  String get soundPreview => 'Preview 10 s';

  @override
  String soundPreviewLabel(String sound) {
    return 'Preview $sound for up to 10 seconds';
  }

  @override
  String get soundStopPreview => 'Stop preview';

  @override
  String soundStopPreviewLabel(String sound) {
    return 'Stop preview of $sound';
  }

  @override
  String get soundMute => 'Mute sounds';

  @override
  String get soundUnmute => 'Unmute sounds';

  @override
  String get soundMuteLabel => 'Mute focus sounds';

  @override
  String get soundPlay => 'Play sounds';

  @override
  String get soundPause => 'Pause sounds';

  @override
  String get soundRetry => 'Retry sound';

  @override
  String get soundVolume => 'Volume';

  @override
  String get soundVolumeLabel => 'Focus sounds volume';

  @override
  String soundPercent(int percent) {
    return '$percent%';
  }

  @override
  String soundPercentLabel(int percent) {
    return '$percent percent';
  }

  @override
  String get soundClose => 'Close';

  @override
  String get soundDone => 'Done';

  @override
  String get focus => 'Focus';

  @override
  String get timerPhase => 'Timer phase';

  @override
  String get tasks => 'Tasks';

  @override
  String get insights => 'Analytics';

  @override
  String get analyticsOverview => 'Overview';

  @override
  String get analyticsHistory => 'History';

  @override
  String get analyticsThisWeek => 'This week';

  @override
  String get analyticsLastMonth => 'Last month';

  @override
  String get analyticsAverages => 'Averages';

  @override
  String get analyticsDailyAverage => 'Daily average';

  @override
  String get analyticsWeeklyAverage => 'Weekly average';

  @override
  String get analyticsMonthlyAverage => 'Monthly average';

  @override
  String get analyticsPerDay => 'sessions/day';

  @override
  String get analyticsPerWeek => 'sessions/week';

  @override
  String get analyticsPerMonth => 'sessions/month';

  @override
  String get analyticsDailyHelp =>
      'Total completed sessions over the previous 30 completed days, divided by 30. Zero-session days are included.';

  @override
  String get analyticsWeeklyHelp =>
      'Total completed sessions over the previous 12 completed Monday–Sunday weeks, divided by 12. Zero-session weeks are included.';

  @override
  String get analyticsMonthlyHelp =>
      'Total completed sessions over the previous 12 completed calendar months, divided by 12. Zero-session months are included.';

  @override
  String analyticsSessionUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sessions',
      one: 'session',
    );
    return '$_temp0';
  }

  @override
  String get analyticsActivity => 'Activity';

  @override
  String get analyticsWeek => 'Week';

  @override
  String get analyticsMonth => 'Month';

  @override
  String get analyticsYear => 'Year';

  @override
  String get analyticsPrevious => 'Previous period';

  @override
  String get analyticsNext => 'Next period';

  @override
  String get analyticsCurrent => 'Current period';

  @override
  String get analyticsShowData => 'Show data';

  @override
  String get analyticsHideData => 'Hide data';

  @override
  String get analyticsUpcoming => 'Upcoming';

  @override
  String get analyticsLoading => 'Loading analytics…';

  @override
  String get analyticsReadError =>
      'Analytics couldn’t be loaded. Retry to read your saved sessions.';

  @override
  String get analyticsRetry => 'Retry analytics';

  @override
  String get analyticsStale =>
      'These totals are out of date. Refresh to read the latest saved sessions.';

  @override
  String get analyticsRefresh => 'Refresh analytics';

  @override
  String get analyticsUnavailable => 'Unavailable';

  @override
  String get analyticsEmpty => 'No completed sessions in these periods yet.';

  @override
  String get analyticsGoToFocus => 'Go to Focus';

  @override
  String get analyticsChartHelp =>
      'Session counts over time. Use Left and Right arrow keys to explore, or show the data list.';

  @override
  String analyticsBucketSummary(String date, int count, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sessions',
      one: '1 session',
      zero: '0 sessions',
    );
    return '$date, $_temp0, $minutes min focused';
  }

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
  String get earlyFinishHint => 'Skip now to count this session as complete.';

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
  String get emptyHistory => 'Finish your first focus session to see it here.';

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
  String get googleAccount => 'Google account';

  @override
  String get googleAccountWelcome => 'Connect your Google account';

  @override
  String get googleAccountInvite =>
      'See your schedule in Calendar and Day Clock.';

  @override
  String get googleAccountShared => 'Used by Calendar and Day Clock.';

  @override
  String get googleSignIn => 'Sign in with Google';

  @override
  String get googleManageCalendars => 'Manage calendars';

  @override
  String get googleAccountOptions => 'Google account options';

  @override
  String get googleSwitchAccount => 'Switch account';

  @override
  String get googleSignOut => 'Sign out';

  @override
  String get googleRetrySignOut => 'Retry sign out';

  @override
  String get googleAccountConnected => 'Connected';

  @override
  String get googleAccountSignedOut => 'Signed out';

  @override
  String get googleSigningIn => 'Signing in…';

  @override
  String get googleSigningOut => 'Signing out…';

  @override
  String get googleAccountChecking => 'Checking account…';

  @override
  String get googleAccountOffline => 'Offline';

  @override
  String get googleAccountReconnect => 'Sign-in required';

  @override
  String get googleAccountPermissions => 'Permission needed';

  @override
  String get googleAccountAttention => 'Needs attention';

  @override
  String get googleAccountSetup => 'Setup required';

  @override
  String get googleAccountSetupHelp =>
      'Google sign-in needs setup in this build.';

  @override
  String get googleAccountHidden => 'Account hidden';

  @override
  String get googleAccountUnlock =>
      'Unlock Windows to manage your Google account.';

  @override
  String get timing => 'Timing';

  @override
  String get focusDuration => 'Focus duration';

  @override
  String get shortDuration => 'Short break duration';

  @override
  String get longDuration => 'Long break duration';

  @override
  String get cycleRounds => 'Long break every';

  @override
  String get durationHelp => 'New durations apply when the timer is ready.';

  @override
  String get strictMode => 'Strict mode';

  @override
  String get strictHelp =>
      'Lock timer controls and timing settings while running.';

  @override
  String get appearance => 'Appearance';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get darkBackground => 'Dark background';

  @override
  String get nebulaBackground => 'Nebula';

  @override
  String get classicBackground => 'Classic';

  @override
  String get focusBackgroundHelp => 'Used on Focus in dark mode.';

  @override
  String get desktopBackgroundHelp =>
      'Used on Focus and Day Clock in dark mode.';

  @override
  String get alerts => 'Alerts';

  @override
  String get completionAlerts => 'Completion alerts';

  @override
  String get desktopHistory => 'Analytics';

  @override
  String get windowsWeekHelp =>
      'Your completed focus sessions, stored on this computer.';

  @override
  String get windowsHistoryRetention =>
      'History stays on this computer until you delete it or uninstall Poma.';

  @override
  String get windowsStrictHelp =>
      'Lock timer controls and timing settings while running.';

  @override
  String get windowsDeleteAllHelp =>
      'Stop the current timer, disconnect Google Calendar and clear its local credentials/data, clear Poma alerts, delete all tasks and history, and restore defaults? This also stops a strict session. Google revocation cannot be confirmed while offline.';

  @override
  String get windowsDeletionSaveError =>
      'Deletion could not be saved. Data may still be on this computer. Retry saving.';

  @override
  String desktopNumberRange(int max) {
    return 'Enter a whole number from 1 to $max.';
  }

  @override
  String get historyDuration => 'Focus time';

  @override
  String get windowsAlertsHelp =>
      'Alerts work while Poma is open. Sleep may delay them until resume. Every next phase starts manually.';

  @override
  String get windowsAlertsReady =>
      'Completion alerts are enabled while Poma runs. Windows settings and Do Not Disturb control presentation and sound.';

  @override
  String get windowsAlertsDenied =>
      'Completion alerts are blocked in Windows notification settings. Your timer still works.';

  @override
  String get windowsNotificationSettings => 'Windows notification settings';

  @override
  String get windowsPrivacyHelp =>
      'Tasks and focus history are stored on this PC.';

  @override
  String get windowsAboutHelp =>
      'An offline Pomodoro companion for Windows. Inspired by the MIT-licensed Pomatez project.';

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
      'Tasks and focus history are stored on this device.';

  @override
  String get deletionHelp => 'This cannot be undone.';

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
  String get minutesUnit => 'min';

  @override
  String roundsUnit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'rounds',
      one: 'round',
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
