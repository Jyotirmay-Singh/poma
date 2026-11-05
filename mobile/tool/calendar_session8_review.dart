// Opt-in, isolated Windows runtime check. Never imported by production main.
// No Google adapter, owner database, credentials or calendar events are used.
// This opt-in runtime test reads the test-only ticker diagnostic.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/timer_clock.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/data/windows_calendar_reminders.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart' show PomaApp;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Host extends NativeWindowsHost {
  final events = <String>[];
  @override
  set onEvent(Future<void> Function(String, Map<String, Object?>)? handler) {
    super.onEvent = handler == null
        ? null
        : (name, values) async {
            events.add(name);
            await handler(name, values);
          };
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = _Host();
  final metadata = await host.channel.invokeMapMethod<String, Object?>(
    'environment',
  );
  if (metadata?['calendarReview'] != true) {
    throw StateError('Isolated review target required');
  }
  final environment = await host.initialize();
  if (environment.packaged || environment.visible) {
    throw StateError('Launch isolated review with --startup');
  }
  sqfliteFfiInit();
  final repository = SqliteRepository(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
  final alerts = WindowsLocalAlerts(host);
  final app = await AppController.create(
    repository,
    clock: NativeTimerClock(),
    alerts: alerts,
    completionPresenter: alerts,
  );
  final desktop = DesktopController(app, host, environment);
  await desktop.initialize();
  await app.updateSettings(app.settings.copyWith(focusMinutes: 1));
  await app.setCompletionAlerts(true);
  runApp(PomaApp(controller: app, desktop: desktop));
  await app.toggleTimer();
  final run = app.timer.runId;
  final originalDeadline = app.timer.snapshot().deadline;
  final calendar = WindowsCalendarReminders(host.channel);
  final availability = await calendar.availability();
  await calendar.replace(1, {'a' * 64});
  await calendar.arm(1, DateTime.now().toUtc().add(const Duration(seconds: 2)));
  await Future<void>.delayed(const Duration(seconds: 70));
  final completedByNativeDeadline =
      app.timer.status == RunStatus.ready && app.sessions.length == 1;
  await app.reconcile(forceAlerts: true);
  await app.reconcile(forceAlerts: true);
  await app.flush();
  final record = {
    'scope':
        'isolated unpackaged Windows runtime; awake; memory-only timer database',
    'version': environment.version,
    'packaged': environment.packaged,
    'initiallyVisible': environment.visible,
    'notificationAvailability': availability,
    'nativeDeadlineEvents': host.events.where((e) => e == 'deadline').length,
    'nativeCalendarDeadlineEvents': host.events
        .where((e) => e == 'calendarReminderDeadline')
        .length,
    'completedByNativeDeadline': completedByNativeDeadline,
    'historyCountAfterRepeatedReconciliation': app.sessions.length,
    'sameCompletionIdentity': app.sessions.singleOrNull?.id == run,
    'fixedCompletionDeadline':
        app.sessions.singleOrNull?.endedAt == originalDeadline,
    'successorPhase': app.timer.phase.name,
    'successorStatus': app.timer.status.name,
    'foregroundTickerActive': app.tickerActive,
    'passed':
        completedByNativeDeadline &&
        app.sessions.length == 1 &&
        app.sessions.single.id == run &&
        app.sessions.single.endedAt == originalDeadline &&
        app.timer.phase == FocusPhase.shortBreak &&
        app.timer.status == RunStatus.ready &&
        !app.tickerActive &&
        host.events.contains('calendarReminderDeadline'),
    'unrun': [
      'installed toast presentation and actions',
      'DND/denial',
      'physical lock/unlock',
      'real sleep/hibernate',
      'live Google',
    ],
  };
  await File(
    '${environment.dataDirectory}/session8-runtime.json',
  ).writeAsString(
    const JsonEncoder.withIndent('  ').convert(record),
    flush: true,
  );
  await desktop.quit();
}
