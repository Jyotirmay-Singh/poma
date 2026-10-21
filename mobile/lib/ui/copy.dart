import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import '../application/app_controller.dart';
import '../application/local_alerts.dart';
import '../application/local_repository.dart';
import '../domain/models.dart';
import '../l10n/poma_localizations.dart';

extension PomaCopy on BuildContext {
  PomaLocalizations get copy => PomaLocalizations.of(this)!;
}

String phaseName(PomaLocalizations copy, FocusPhase phase) => switch (phase) {
  FocusPhase.focus => copy.focus,
  FocusPhase.shortBreak => copy.shortBreak,
  FocusPhase.longBreak => copy.longBreak,
};

String alertStatus(PomaLocalizations copy, AppController controller) {
  if (controller.needsAlertPermission) return copy.alertNotAsked;
  return switch (controller.alertAvailability) {
    AlertAvailability.ready => copy.alertReady,
    AlertAvailability.delayed => copy.alertDelayed,
    AlertAvailability.denied => copy.alertDenied,
    AlertAvailability.disabled => copy.alertDisabled,
    AlertAvailability.failed => copy.alertFailed,
    AlertAvailability.unavailable || null => copy.alertUnavailable,
  };
}

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
