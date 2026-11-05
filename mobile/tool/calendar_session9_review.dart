// Isolated instrumentation, never imported by production main. Synthetic only.
// The ticker diagnostic is intentionally observed by this explicit review target.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_read_controller.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/calendar_reminder_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/data/calendar_time.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/timer_clock.dart';
import 'package:poma/data/windows_calendar_cache.dart';
import 'package:poma/data/windows_calendar_credentials.dart';
import 'package:poma/data/windows_calendar_reminders.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart' show PomaApp;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Authorization implements GoogleCalendarAuthorization {
  @override
  Future<CalendarAuthorization> authorize(
    GoogleCalendarConfiguration _,
  ) async => CalendarAuthorization(
    accountId: 'session9-fictional',
    accessToken: 'session9-synthetic-access',
    refreshToken: 'session9-synthetic-refresh',
    scopes: calendarReadScopes,
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
  );
  @override
  Future<CalendarAuthorization> refresh(
    GoogleCalendarConfiguration configuration,
    CalendarCredential credential,
  ) => authorize(configuration);
  @override
  Future<bool> revoke(String _) async => false;
  @override
  Future<void> cancelPending() async {}
  @override
  void dispose() {}
}

class _Provider implements CalendarReadProvider {
  int lists = 0, reads = 0, cancellations = 0;
  final origin = DateTime.now().toUtc().add(const Duration(hours: 1));
  @override
  Future<List<CalendarSource>> calendars() async {
    lists++;
    return [
      for (final id in ['fictional-work', 'fictional-personal'])
        CalendarSource(id: id, name: id, accessRole: 'reader', timeZone: 'UTC'),
    ];
  }

  @override
  Future<List<CalendarEvent>> events(
    CalendarSource source,
    CalendarWindow _,
  ) async {
    reads++;
    return [
      for (var i = 0; i < 10; i++)
        CalendarEvent(
          id: 'fictional-$i',
          calendarId: source.id,
          title: 'Fictional review event $i',
          status: 'confirmed',
          selfResponse: 'accepted',
          startUtc: origin.add(Duration(hours: i)),
          endUtc: origin.add(Duration(hours: i, minutes: 30)),
        ),
    ];
  }

  @override
  void cancel() {
    cancellations++;
  }

  @override
  void dispose() => cancel();
}

class _Cache implements CalendarCacheStore {
  _Cache(this.inner);
  final WindowsCalendarCache inner;
  int reads = 0, writes = 0;
  @override
  Future<CalendarCacheLease> open(int revision, String key) =>
      inner.open(revision, key);
  @override
  Future<CalendarAccountData?> read(CalendarCacheLease lease) {
    reads++;
    return inner.read(lease);
  }

  @override
  Future<void> write(CalendarCacheLease lease, CalendarAccountData data) {
    writes++;
    return inner.write(lease, data);
  }

  @override
  Future<void> invalidate() => inner.invalidate();
}

class _Host extends NativeWindowsHost {
  final events = <String>[];
  int publications = 0, formatting = 0;
  @override
  set onEvent(Future<void> Function(String, Map<String, Object?>)? handler) {
    super.onEvent = handler == null
        ? null
        : (name, values) async {
            events.add(name);
            await handler(name, values);
          };
  }

  @override
  Future<void> publish(Map<String, Object?> snapshot) {
    publications++;
    return super.publish(snapshot);
  }

  @override
  Future<Map<String, String>> formatCalendar(
    List<DateTime> times,
    List<CalendarDate> dates,
  ) {
    formatting++;
    return super.formatCalendar(times, dates);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = _Host();
  final metadata = await host.channel.invokeMapMethod<String, Object?>(
    'environment',
  );
  if (metadata?['calendarReview'] != true || metadata?['packaged'] == true) {
    throw StateError('Isolated unpackaged review target required');
  }
  final environment = await host.initialize();
  if (!environment.dataDirectory.endsWith('fictional-review-profile')) {
    throw StateError('Isolated profile required');
  }
  final directory = Directory(environment.dataDirectory);
  final status = File('${directory.path}/session9-phase.json');
  Future<void> record(Map<String, Object?> value) async {
    final pending = File('${status.path}.tmp');
    await pending.writeAsString(jsonEncode(value), flush: true);
    await pending.rename(status.path);
  }

  sqfliteFfiInit();
  final repository = SqliteRepository(
    factory: databaseFactoryFfi,
    databasePath: inMemoryDatabasePath,
  );
  final credentials = WindowsCalendarCredentials(host.channel);
  final connection = CalendarConnectionController(
    configuration: const GoogleCalendarConfiguration(
      clientId: '123456-session9.apps.googleusercontent.com',
    ),
    authorization: _Authorization(),
    store: credentials,
  );
  const clock = DeviceCalendarClock();
  final provider = _Provider();
  final cache = _Cache(WindowsCalendarCache(host.channel));
  final reader = CalendarReadController(
    connection: connection,
    provider: provider,
    cache: cache,
    clock: clock,
    scheduler: const TimerCalendarScheduler(),
  );
  final alerts = WindowsLocalAlerts(host);
  final app = await AppController.create(
    repository,
    clock: NativeTimerClock(),
    alerts: alerts,
    completionPresenter: alerts,
    resetParticipant: connection,
  );
  final desktop = DesktopController(
    app,
    host,
    environment,
    connection: connection,
    calendarData: reader,
    calendarPlatform: host,
  );
  await desktop.initialize();
  final reminderAdapter = WindowsCalendarReminders(host.channel);
  desktop.attachReminders(
    CalendarReminderController(
      reader: reader,
      store: reminderAdapter,
      platform: reminderAdapter,
      openAgenda: desktop.showPopup,
    ),
  );
  runApp(PomaApp(controller: app, desktop: desktop));
  app.addTask('Fictional Session 9 task');
  await app.flush();
  await connection.initialize();
  final observations = <Map<String, Object?>>[];
  Map<String, Object?> counters() => {
    'calendarLists': provider.lists,
    'eventReads': provider.reads,
    'cacheReads': cache.reads,
    'cacheWrites': cache.writes,
    'publications': host.publications,
    'formatting': host.formatting,
    'nativeTimerDeadlines': host.events.where((e) => e == 'deadline').length,
    'nativeCalendarDeadlines': host.events
        .where((e) => e == 'calendarReminderDeadline')
        .length,
    'foregroundTickerActive': app.tickerActive,
    'tasks': app.tasks.length,
    'history': app.sessions.length,
  };
  var phase = 0;
  Future<void> condition(
    String name,
    bool visible, {
    int samples = 3,
    int seconds = 30,
  }) async {
    await host.channel.invokeMethod<void>('reviewVisibility', {
      'visible': visible,
    });
    final initial = counters();
    await record({
      'phase': phase,
      'condition': name,
      'state': 'warming',
      'warmupSeconds': 30,
    });
    await Future<void>.delayed(const Duration(seconds: 30));
    final before = counters();
    await record({
      'phase': phase,
      'condition': name,
      'state': 'sampling',
      'samples': samples,
      'seconds': seconds,
      'before': before,
    });
    final acknowledgement = File(
      '${directory.path}/session9-phase-$phase.done',
    );
    final deadline = DateTime.now().add(
      Duration(seconds: samples * seconds + 120),
    );
    while (!await acknowledgement.exists()) {
      if (DateTime.now().isAfter(deadline)) {
        throw StateError('Resource sampler did not acknowledge');
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    observations.add({
      'phase': phase,
      'condition': name,
      'warmupStart': initial,
      'before': before,
      'after': counters(),
    });
    phase++;
  }

  await condition('disconnected-visible', true);
  await condition('disconnected-hidden', false);
  await connection.connect();
  // Selection is explicit, matching the production reader contract.
  final selectionDeadline = DateTime.now().add(const Duration(seconds: 20));
  while (!reader.canSelect) {
    if (DateTime.now().isAfter(selectionDeadline)) {
      throw StateError('Synthetic reader did not become ready');
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  await reader.select({'fictional-work', 'fictional-personal'});
  await condition('synthetic-visible', true);
  await condition('synthetic-hidden', false);
  await condition('synthetic-hidden-refresh', false, samples: 12);

  // Separate awake hidden-expiry check; excluded from all idle resource samples.
  await app.updateSettings(app.settings.copyWith(focusMinutes: 1));
  await app.toggleTimer();
  final run = app.timer.runId;
  final deadline = app.timer.snapshot().deadline;
  await reminderAdapter.replace(999999, {'a' * 64});
  await reminderAdapter.arm(
    999999,
    DateTime.now().toUtc().add(const Duration(seconds: 2)),
  );
  await record({
    'phase': phase,
    'condition': 'hidden-expiry-probe',
    'state': 'probe',
  });
  await Future<void>.delayed(const Duration(seconds: 70));
  final nativeCompleted =
      app.sessions.length == 1 && app.timer.status == RunStatus.ready;
  await app.reconcile();
  await app.reconcile();
  final result = {
    'scope':
        'isolated synthetic unpackaged runtime; real native clock/cache; memory-only timer database; no network',
    'version': environment.version,
    'packaged': environment.packaged,
    'conditions': observations,
    'finalCounters': counters(),
    'notificationAvailability': await reminderAdapter.availability(),
    'nativeCompletedBeforeReconciliation': nativeCompleted,
    'sameCompletionIdentity': app.sessions.singleOrNull?.id == run,
    'fixedCompletionDeadline': app.sessions.singleOrNull?.endedAt == deadline,
    'successorReady':
        app.timer.phase == FocusPhase.shortBreak &&
        app.timer.status == RunStatus.ready,
    'passed':
        nativeCompleted &&
        app.sessions.length == 1 &&
        app.sessions.single.id == run &&
        app.sessions.single.endedAt == deadline &&
        app.timer.phase == FocusPhase.shortBreak &&
        app.timer.status == RunStatus.ready &&
        !app.tickerActive,
  };
  await connection.disconnect();
  result['calendarFilesAfterDisconnect'] =
      Directory('${directory.path}/calendar').existsSync()
      ? Directory('${directory.path}/calendar')
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path.substring(directory.path.length + 1))
            .toList()
      : <String>[];
  await File('${directory.path}/session9-runtime.json').writeAsString(
    const JsonEncoder.withIndent('  ').convert(result),
    flush: true,
  );
  await desktop.quit();
}
