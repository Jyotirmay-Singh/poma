import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'poma_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of PomaLocalizations
/// returned by `PomaLocalizations.of(context)`.
///
/// Applications need to include `PomaLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/poma_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: PomaLocalizations.localizationsDelegates,
///   supportedLocales: PomaLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the PomaLocalizations.supportedLocales
/// property.
abstract class PomaLocalizations {
  PomaLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static PomaLocalizations? of(BuildContext context) {
    return Localizations.of<PomaLocalizations>(context, PomaLocalizations);
  }

  static const LocalizationsDelegate<PomaLocalizations> delegate =
      _PomaLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @focus.
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get focus;

  /// No description provided for @timerPhase.
  ///
  /// In en, this message translates to:
  /// **'Timer phase'**
  String get timerPhase;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// No description provided for @insights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insights;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @shortBreak.
  ///
  /// In en, this message translates to:
  /// **'Short break'**
  String get shortBreak;

  /// No description provided for @longBreak.
  ///
  /// In en, this message translates to:
  /// **'Long break'**
  String get longBreak;

  /// No description provided for @startFocus.
  ///
  /// In en, this message translates to:
  /// **'Start focus'**
  String get startFocus;

  /// No description provided for @startShortBreak.
  ///
  /// In en, this message translates to:
  /// **'Start short break'**
  String get startShortBreak;

  /// No description provided for @startLongBreak.
  ///
  /// In en, this message translates to:
  /// **'Start long break'**
  String get startLongBreak;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @resetTimer.
  ///
  /// In en, this message translates to:
  /// **'Reset timer'**
  String get resetTimer;

  /// No description provided for @skipPhase.
  ///
  /// In en, this message translates to:
  /// **'Skip to next phase'**
  String get skipPhase;

  /// No description provided for @focusComplete.
  ///
  /// In en, this message translates to:
  /// **'Focus complete. Start your break when you’re ready.'**
  String get focusComplete;

  /// No description provided for @breakComplete.
  ///
  /// In en, this message translates to:
  /// **'Break complete. Start your focus when you’re ready.'**
  String get breakComplete;

  /// No description provided for @readyHint.
  ///
  /// In en, this message translates to:
  /// **'Each phase starts when you choose.'**
  String get readyHint;

  /// No description provided for @pausedHint.
  ///
  /// In en, this message translates to:
  /// **'Paused. Resume when you’re ready.'**
  String get pausedHint;

  /// No description provided for @runningHint.
  ///
  /// In en, this message translates to:
  /// **'Your timer continues when you leave Poma.'**
  String get runningHint;

  /// No description provided for @strictHint.
  ///
  /// In en, this message translates to:
  /// **'Poma’s timer controls are locked until this phase finishes. Other apps remain available.'**
  String get strictHint;

  /// No description provided for @currentFocus.
  ///
  /// In en, this message translates to:
  /// **'Current focus'**
  String get currentFocus;

  /// No description provided for @nextFocus.
  ///
  /// In en, this message translates to:
  /// **'Next focus'**
  String get nextFocus;

  /// No description provided for @chooseTask.
  ///
  /// In en, this message translates to:
  /// **'Choose a task'**
  String get chooseTask;

  /// No description provided for @noTask.
  ///
  /// In en, this message translates to:
  /// **'No task selected'**
  String get noTask;

  /// No description provided for @unassignedFocus.
  ///
  /// In en, this message translates to:
  /// **'Focus without a task'**
  String get unassignedFocus;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @loadingTotals.
  ///
  /// In en, this message translates to:
  /// **'Loading focus totals…'**
  String get loadingTotals;

  /// No description provided for @retryTotals.
  ///
  /// In en, this message translates to:
  /// **'Retry totals'**
  String get retryTotals;

  /// No description provided for @todayTotals.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No sessions} =1{1 session} other{{count} sessions}} · {minutes} min focused'**
  String todayTotals(int count, int minutes);

  /// No description provided for @roundsComplete.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} focus rounds completed'**
  String roundsComplete(int count, int total);

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute} other{{minutes} minutes}} {seconds, plural, =1{1 second} other{{seconds} seconds}} remaining'**
  String remaining(int minutes, int seconds);

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add a task'**
  String get addTask;

  /// No description provided for @taskHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose a task for your next focus.'**
  String get taskHelp;

  /// No description provided for @emptyTasks.
  ///
  /// In en, this message translates to:
  /// **'What would you like to work on?'**
  String get emptyTasks;

  /// No description provided for @emptyTasksHelp.
  ///
  /// In en, this message translates to:
  /// **'Add one small, achievable task to get started.'**
  String get emptyTasksHelp;

  /// No description provided for @allDone.
  ///
  /// In en, this message translates to:
  /// **'All tasks completed'**
  String get allDone;

  /// No description provided for @allDoneHelp.
  ///
  /// In en, this message translates to:
  /// **'Add another task, or mark a completed task incomplete to use it again.'**
  String get allDoneHelp;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @selectedTask.
  ///
  /// In en, this message translates to:
  /// **'Selected for next focus'**
  String get selectedTask;

  /// No description provided for @selectTask.
  ///
  /// In en, this message translates to:
  /// **'Select for next focus'**
  String get selectTask;

  /// No description provided for @markComplete.
  ///
  /// In en, this message translates to:
  /// **'Mark {title} complete'**
  String markComplete(String title);

  /// No description provided for @markIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Mark {title} incomplete'**
  String markIncomplete(String title);

  /// No description provided for @taskOptions.
  ///
  /// In en, this message translates to:
  /// **'Options for {title}'**
  String taskOptions(String title);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameTask.
  ///
  /// In en, this message translates to:
  /// **'Rename task'**
  String get renameTask;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @saveTask.
  ///
  /// In en, this message translates to:
  /// **'Save task'**
  String get saveTask;

  /// No description provided for @taskName.
  ///
  /// In en, this message translates to:
  /// **'What will you work on?'**
  String get taskName;

  /// No description provided for @enterTask.
  ///
  /// In en, this message translates to:
  /// **'Enter a task name.'**
  String get enterTask;

  /// No description provided for @weekHelp.
  ///
  /// In en, this message translates to:
  /// **'Your completed focus sessions, stored on this phone.'**
  String get weekHelp;

  /// No description provided for @lastSevenDays.
  ///
  /// In en, this message translates to:
  /// **'Focused over the last 7 days'**
  String get lastSevenDays;

  /// No description provided for @dailyTotals.
  ///
  /// In en, this message translates to:
  /// **'Daily focus totals'**
  String get dailyTotals;

  /// No description provided for @focusedMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min focused'**
  String focusedMinutes(int minutes);

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutes(int minutes);

  /// No description provided for @dailySummary.
  ///
  /// In en, this message translates to:
  /// **'{date}: {count, plural, =0{no sessions} =1{1 session} other{{count} sessions}}, {minutes} minutes focused'**
  String dailySummary(String date, int count, int minutes);

  /// No description provided for @recentSessions.
  ///
  /// In en, this message translates to:
  /// **'Recent sessions'**
  String get recentSessions;

  /// No description provided for @loadingHistory.
  ///
  /// In en, this message translates to:
  /// **'Loading history'**
  String get loadingHistory;

  /// No description provided for @retryHistory.
  ///
  /// In en, this message translates to:
  /// **'Retry history'**
  String get retryHistory;

  /// No description provided for @emptyHistory.
  ///
  /// In en, this message translates to:
  /// **'Finish your first focus session to see it here. Skipped sessions are not counted.'**
  String get emptyHistory;

  /// No description provided for @focusSession.
  ///
  /// In en, this message translates to:
  /// **'Focus session'**
  String get focusSession;

  /// No description provided for @sessionDate.
  ///
  /// In en, this message translates to:
  /// **'{date} at {time}'**
  String sessionDate(String date, String time);

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete session'**
  String get deleteSession;

  /// No description provided for @deleteNamedSession.
  ///
  /// In en, this message translates to:
  /// **'Delete {title}, {date}'**
  String deleteNamedSession(String title, String date);

  /// No description provided for @deleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete session?'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionHelp.
  ///
  /// In en, this message translates to:
  /// **'Remove this completed session from history and focus totals?'**
  String get deleteSessionHelp;

  /// No description provided for @newer.
  ///
  /// In en, this message translates to:
  /// **'Newer'**
  String get newer;

  /// No description provided for @older.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get older;

  /// No description provided for @latest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latest;

  /// No description provided for @historyRetention.
  ///
  /// In en, this message translates to:
  /// **'History stays on this phone until you delete it.'**
  String get historyRetention;

  /// No description provided for @settingsHelp.
  ///
  /// In en, this message translates to:
  /// **'Timing, appearance, alerts, and your local data.'**
  String get settingsHelp;

  /// No description provided for @timing.
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get timing;

  /// No description provided for @focusDuration.
  ///
  /// In en, this message translates to:
  /// **'Focus duration'**
  String get focusDuration;

  /// No description provided for @shortDuration.
  ///
  /// In en, this message translates to:
  /// **'Short break duration'**
  String get shortDuration;

  /// No description provided for @longDuration.
  ///
  /// In en, this message translates to:
  /// **'Long break duration'**
  String get longDuration;

  /// No description provided for @cycleRounds.
  ///
  /// In en, this message translates to:
  /// **'Focus rounds before a long break'**
  String get cycleRounds;

  /// No description provided for @durationHelp.
  ///
  /// In en, this message translates to:
  /// **'Duration changes apply immediately to a ready timer. A running or paused phase keeps its original duration.'**
  String get durationHelp;

  /// No description provided for @strictMode.
  ///
  /// In en, this message translates to:
  /// **'Strict mode'**
  String get strictMode;

  /// No description provided for @strictHelp.
  ///
  /// In en, this message translates to:
  /// **'Locks pause, reset, skip, phase changes, and timing settings while a phase runs. It cannot lock your phone or block other apps.'**
  String get strictHelp;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @completionAlerts.
  ///
  /// In en, this message translates to:
  /// **'Completion alerts'**
  String get completionAlerts;

  /// No description provided for @alertHelp.
  ///
  /// In en, this message translates to:
  /// **'One local alert for each phase you start. Your phone controls presentation and sound. The next phase always starts manually.'**
  String get alertHelp;

  /// No description provided for @alertNotAsked.
  ///
  /// In en, this message translates to:
  /// **'Choose whether to allow alerts when you start a timer.'**
  String get alertNotAsked;

  /// No description provided for @alertReady.
  ///
  /// In en, this message translates to:
  /// **'Completion alerts are enabled. Delivery follows your phone’s notification settings.'**
  String get alertReady;

  /// No description provided for @alertDisabled.
  ///
  /// In en, this message translates to:
  /// **'Completion alerts are off in Poma. Your timer still works.'**
  String get alertDisabled;

  /// No description provided for @alertDelayed.
  ///
  /// In en, this message translates to:
  /// **'Alerts may be delayed. Allow precise alerts in Settings.'**
  String get alertDelayed;

  /// No description provided for @alertDenied.
  ///
  /// In en, this message translates to:
  /// **'Completion alerts are off in your phone’s notification settings.'**
  String get alertDenied;

  /// No description provided for @alertFailed.
  ///
  /// In en, this message translates to:
  /// **'Completion alert could not be registered. Your timer is kept. Try again.'**
  String get alertFailed;

  /// No description provided for @alertUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Completion alerts are unavailable. Your timer still works.'**
  String get alertUnavailable;

  /// No description provided for @phoneSettings.
  ///
  /// In en, this message translates to:
  /// **'Phone notification settings'**
  String get phoneSettings;

  /// No description provided for @preciseAlerts.
  ///
  /// In en, this message translates to:
  /// **'Allow precise alerts'**
  String get preciseAlerts;

  /// No description provided for @retryAlerts.
  ///
  /// In en, this message translates to:
  /// **'Retry alerts'**
  String get retryAlerts;

  /// No description provided for @alertPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Know when your time is up'**
  String get alertPromptTitle;

  /// No description provided for @alertPromptHelp.
  ///
  /// In en, this message translates to:
  /// **'Allow completion alerts while your phone is locked or you use another app. Your phone controls sound and delivery.'**
  String get alertPromptHelp;

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @enableAlerts.
  ///
  /// In en, this message translates to:
  /// **'Enable alerts'**
  String get enableAlerts;

  /// No description provided for @localData.
  ///
  /// In en, this message translates to:
  /// **'Local data'**
  String get localData;

  /// No description provided for @privacyHelp.
  ///
  /// In en, this message translates to:
  /// **'Tasks, settings, and history are stored on this phone. Poma requests that they be left out of automatic backups. System backup and phone-transfer behavior can vary, and older backups may retain data. There is no automatic recovery if you uninstall Poma or lose the phone. No account, ads, or tracking.'**
  String get privacyHelp;

  /// No description provided for @deletionHelp.
  ///
  /// In en, this message translates to:
  /// **'History is kept until you delete it. Deleting data cannot be undone.'**
  String get deletionHelp;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear focus history'**
  String get clearHistory;

  /// No description provided for @clearHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear focus history?'**
  String get clearHistoryTitle;

  /// No description provided for @clearHistoryHelp.
  ///
  /// In en, this message translates to:
  /// **'Delete all completed sessions and their totals? Your tasks, settings, and current timer stay.'**
  String get clearHistoryHelp;

  /// No description provided for @historyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Focus history deleted.'**
  String get historyDeleted;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete all local data'**
  String get deleteAll;

  /// No description provided for @deleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete all local data?'**
  String get deleteAllTitle;

  /// No description provided for @deleteAllHelp.
  ///
  /// In en, this message translates to:
  /// **'Stop the current timer, cancel Poma alerts, delete all tasks and history, and restore app defaults? This also stops a strict session.'**
  String get deleteAllHelp;

  /// No description provided for @localDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Local data deleted.'**
  String get localDataDeleted;

  /// No description provided for @cleanupUnfinished.
  ///
  /// In en, this message translates to:
  /// **'Local alert cleanup is unfinished.'**
  String get cleanupUnfinished;

  /// No description provided for @retryDeletion.
  ///
  /// In en, this message translates to:
  /// **'Retry deletion'**
  String get retryDeletion;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About Poma'**
  String get about;

  /// No description provided for @aboutHelp.
  ///
  /// In en, this message translates to:
  /// **'An offline Pomodoro companion for Android and iOS. Inspired by the MIT-licensed Pomatez project.'**
  String get aboutHelp;

  /// No description provided for @attribution.
  ///
  /// In en, this message translates to:
  /// **'Pomatez © 2024 Roldan Montilla Jr.\nSee THIRD_PARTY_NOTICES.md in the source distribution.'**
  String get attribution;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease {label}'**
  String decrease(String label);

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase {label}'**
  String increase(String label);

  /// No description provided for @rounds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 round} other{{count} rounds}}'**
  String rounds(int count);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @finishDeletion.
  ///
  /// In en, this message translates to:
  /// **'Finish deletion'**
  String get finishDeletion;

  /// No description provided for @cleanupNotice.
  ///
  /// In en, this message translates to:
  /// **'Data deletion needs retry before starting another timer.'**
  String get cleanupNotice;

  /// No description provided for @clockError.
  ///
  /// In en, this message translates to:
  /// **'Timer time could not be read. Try again. Your data is kept.'**
  String get clockError;

  /// No description provided for @storageFull.
  ///
  /// In en, this message translates to:
  /// **'Storage is full. Free up space and retry. Unsaved changes may be lost if Poma closes.'**
  String get storageFull;

  /// No description provided for @storageWrite.
  ///
  /// In en, this message translates to:
  /// **'Changes could not be saved. Retry. Unsaved changes may be lost if Poma closes.'**
  String get storageWrite;

  /// No description provided for @storageUnreadable.
  ///
  /// In en, this message translates to:
  /// **'Saved data could not be read. Your existing data is kept. Retry.'**
  String get storageUnreadable;

  /// No description provided for @storageMigration.
  ///
  /// In en, this message translates to:
  /// **'Saved data could not be upgraded. Your existing data is kept. Retry.'**
  String get storageMigration;

  /// No description provided for @storageConflict.
  ///
  /// In en, this message translates to:
  /// **'Saved data changed unexpectedly. Reopen Poma before making more changes.'**
  String get storageConflict;

  /// No description provided for @startupPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Local storage privacy settings could not be applied.'**
  String get startupPrivacy;

  /// No description provided for @startupRead.
  ///
  /// In en, this message translates to:
  /// **'Your saved data could not be opened.'**
  String get startupRead;

  /// No description provided for @tryAgainHelp.
  ///
  /// In en, this message translates to:
  /// **'Try again. Your existing data will be kept.'**
  String get tryAgainHelp;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @opening.
  ///
  /// In en, this message translates to:
  /// **'Opening Poma'**
  String get opening;

  /// No description provided for @totalsReadError.
  ///
  /// In en, this message translates to:
  /// **'Focus totals could not be read. Retry.'**
  String get totalsReadError;

  /// No description provided for @historyReadError.
  ///
  /// In en, this message translates to:
  /// **'History could not be read. Your data is kept. Retry.'**
  String get historyReadError;

  /// No description provided for @deletionSaveError.
  ///
  /// In en, this message translates to:
  /// **'Deletion could not be saved. Data may still be on this phone. Retry saving.'**
  String get deletionSaveError;

  /// No description provided for @deletionCleanupError.
  ///
  /// In en, this message translates to:
  /// **'Data deletion is not complete. Retry to finish saving and clearing local alerts.'**
  String get deletionCleanupError;
}

class _PomaLocalizationsDelegate
    extends LocalizationsDelegate<PomaLocalizations> {
  const _PomaLocalizationsDelegate();

  @override
  Future<PomaLocalizations> load(Locale locale) {
    return SynchronousFuture<PomaLocalizations>(
      lookupPomaLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_PomaLocalizationsDelegate old) => false;
}

PomaLocalizations lookupPomaLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return PomaLocalizationsEn();
  }

  throw FlutterError(
    'PomaLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
