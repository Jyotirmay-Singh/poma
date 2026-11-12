import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../application/app_controller.dart';
import '../application/local_alerts.dart';
import '../application/local_repository.dart';
import '../domain/models.dart';
import '../domain/focus_sound_preferences.dart';
import '../application/focus_audio_ports.dart';
import '../l10n/poma_localizations.dart';
import 'desktop_scope.dart';

extension PomaCopy on BuildContext {
  PomaLocalizations get copy => PomaLocalizations.of(this)!;
}

String focusSoundName(PomaLocalizations copy, FocusSoundId sound) =>
    switch (sound) {
      FocusSoundId.off => copy.soundOff,
      FocusSoundId.tibetanBells => copy.soundBells,
      FocusSoundId.waterfall => copy.soundWaterfall,
      FocusSoundId.oceanWaves => copy.soundOcean,
      FocusSoundId.forestBirds => copy.soundBirds,
      FocusSoundId.calmingRain => copy.soundRain,
      FocusSoundId.omChanting => copy.soundOm,
    };

String focusSoundStatus(
  PomaLocalizations copy,
  FocusAudioState state,
  FocusPhase phase,
  RunStatus status,
) {
  final p = state.preferences;
  if (state.availability == FocusAudioAvailability.unavailable) {
    return copy.soundUnavailable;
  }
  if (state.canRetry) return copy.soundFailed;
  if (state.previewSound case final sound?) {
    return state.transport == FocusAudioTransport.loading
        ? copy.soundLoadingPreview
        : copy.soundPreviewing(focusSoundName(copy, sound));
  }
  if (p.volume == 0) return copy.soundZero;
  if (p.muted) return copy.soundMuted;
  if (p.sound == FocusSoundId.off) return copy.soundOff;
  if (phase != FocusPhase.focus) return copy.soundBreak;
  if (state.routeBlocked) return copy.soundRoute;
  if (state.interrupted || state.suspended) return copy.soundInterrupted;
  return switch (state.transport) {
    FocusAudioTransport.loading => copy.soundLoading(
      focusSoundName(copy, p.sound),
    ),
    FocusAudioTransport.playing => copy.soundPlaying,
    _ =>
      status == RunStatus.paused
          ? copy.soundTimerPaused
          : status == RunStatus.ready
          ? copy.soundReady
          : copy.soundPaused,
  };
}

bool focusSoundCanPlay(AppController controller, FocusAudioState state) =>
    controller.clockError == null &&
    state.availability == FocusAudioAvailability.available &&
    controller.timer.phase == FocusPhase.focus &&
    controller.timer.status == RunStatus.running &&
    state.preferences.sound != FocusSoundId.off &&
    !state.preferences.muted &&
    state.preferences.volume > 0;

String phaseName(PomaLocalizations copy, FocusPhase phase) => switch (phase) {
  FocusPhase.focus => copy.focus,
  FocusPhase.shortBreak => copy.shortBreak,
  FocusPhase.longBreak => copy.longBreak,
};

String alertStatus(PomaLocalizations copy, AppController controller) {
  if (controller.needsAlertPermission) return copy.alertNotAsked;
  if (controller.residentNotifications) {
    if (controller.alertAvailability == AlertAvailability.ready) {
      return copy.windowsAlertsReady;
    }
    if (controller.alertAvailability == AlertAvailability.denied) {
      return copy.windowsAlertsDenied;
    }
  }
  return switch (controller.alertAvailability) {
    AlertAvailability.ready => copy.alertReady,
    AlertAvailability.delayed => copy.alertDelayed,
    AlertAvailability.denied => copy.alertDenied,
    AlertAvailability.disabled => copy.alertDisabled,
    AlertAvailability.failed => copy.alertFailed,
    AlertAvailability.unavailable || null => copy.alertUnavailable,
  };
}

String notificationSettingsLabel(BuildContext context) =>
    DesktopScope.maybeOf(context) == null
    ? context.copy.phoneSettings
    : context.copy.windowsNotificationSettings;

/// Product copy remains English; calendar formatting uses the device locale,
/// independently of the application's supported translation locales.
class DeviceFormats {
  static final Future<void> _initialized = initializeDateFormatting();
  static Future<void> initialize() => _initialized;
  static String _locale(BuildContext context) {
    final locale = WidgetsBinding.instance.platformDispatcher.locale.toString();
    return Intl.verifiedLocale(
      locale,
      DateFormat.localeExists,
      onFailure: (_) => 'en',
    )!;
  }

  static String date(BuildContext context, DateTime value) =>
      DateFormat.yMMMd(_locale(context)).format(value);
  static String weekday(BuildContext context, DateTime value) =>
      DateFormat.E(_locale(context)).format(value);
  static String time(BuildContext context, DateTime value) {
    final locale = _locale(context);
    if (MediaQuery.alwaysUse24HourFormatOf(context)) {
      return DateFormat.Hm(locale).format(value);
    }
    // Android reports the user's explicit 12-hour choice even in a locale
    // whose default is 24-hour. Keep regional separators, but honor that
    // choice instead of silently reapplying the locale's default hour cycle.
    final regional = DateFormat.jm(locale).pattern!;
    final twelveHour = regional.replaceAll(RegExp('[Hk]+'), 'h');
    return DateFormat(
      twelveHour == regional ? regional : '$twelveHour a',
      locale,
    ).format(value);
  }
}

String storageMessage(PomaLocalizations copy, StorageFailureKind kind) =>
    switch (kind) {
      StorageFailureKind.full => copy.storageFull,
      StorageFailureKind.write => copy.storageWrite,
      StorageFailureKind.unreadable => copy.storageUnreadable,
      StorageFailureKind.migration => copy.storageMigration,
      StorageFailureKind.conflict => copy.storageConflict,
    };
