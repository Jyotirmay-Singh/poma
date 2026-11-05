// Synthetic desktop review entry point. Never imported by lib/main.dart.
// Its CMake target uses a runtime-local fictional profile, memory-only calendar
// adapters, and no browser/network/credential adapter. No owner data is loaded.
import 'package:flutter/material.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_presentation_ports.dart';
import 'package:poma/application/calendar_read_controller.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/data/calendar_time.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/timer_clock.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Credentials implements ProtectedCalendarStore {
  CalendarCredential? saved;
  @override
  Future<CalendarStoredConnection> read() async =>
      CalendarStoredConnection(0, saved);
  @override
  Future<void> write(
    int revision,
    CalendarCredential credential, {
    bool purgeAccountData = false,
  }) async {
    saved = credential;
  }

  @override
  Future<int> invalidateAndClear() async {
    saved = null;
    return 1;
  }

  @override
  Future<int> retire(int revision, CalendarAccountIdentity identity) async {
    saved = null;
    return 1;
  }
}

class _Authorization implements GoogleCalendarAuthorization {
  CalendarAuthorization grant() => CalendarAuthorization(
    accountId: 'fictional-review',
    accessToken: 'synthetic',
    refreshToken: 'synthetic',
    scopes: calendarReadScopes,
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  @override
  Future<CalendarAuthorization> authorize(
    GoogleCalendarConfiguration config,
  ) async => grant();
  @override
  Future<CalendarAuthorization> refresh(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  ) async => grant();
  @override
  Future<bool> revoke(String token) async => true;
  @override
  Future<void> cancelPending() async {}
  @override
  void dispose() {}
}

class _Cache implements CalendarCacheStore {
  CalendarAccountData? data;
  @override
  Future<void> invalidate() async {}
  @override
  Future<CalendarCacheLease> open(int revision, String key) async =>
      CalendarCacheLease(revision, 0, key);
  @override
  Future<CalendarAccountData?> read(CalendarCacheLease lease) async => data;
  @override
  Future<void> write(
    CalendarCacheLease lease,
    CalendarAccountData value,
  ) async {
    data = value;
  }
}

class _Provider implements CalendarReadProvider {
  final DateTime seed = DateTime.now().toUtc();
  bool offline = false;
  static const sources = [
    CalendarSource(
      id: 'fictional-a',
      name: 'Fictional Work',
      accessRole: 'reader',
      timeZone: 'UTC',
    ),
    CalendarSource(
      id: 'fictional-b',
      name: 'Fictional Team',
      accessRole: 'reader',
      timeZone: 'UTC',
    ),
  ];
  @override
  Future<List<CalendarSource>> calendars() async => sources;
  @override
  Future<List<CalendarEvent>> events(
    CalendarSource source,
    CalendarWindow window,
  ) async {
    if (offline && source.id == sources.last.id) {
      throw const CalendarReadFailure(CalendarReadFailureKind.network);
    }
    CalendarEvent timed(
      String id,
      String title,
      DateTime start,
      DateTime end, {
      String response = 'accepted',
    }) => CalendarEvent(
      id: id,
      calendarId: source.id,
      title: title,
      status: 'confirmed',
      selfResponse: response,
      startUtc: start,
      endUtc: end,
      eventUrl: 'https://calendar.google.com/calendar/event?eid=fictional',
      meetingUrl: 'https://meet.google.com/abc-defg-hij',
    );
    final tomorrow = window.first.plusDays(1);
    return [
      timed(
        'shared-looking',
        source.id == sources.first.id
            ? 'Fictional design review — 日本語 🧭 Café: a long title for keyboard and large text review'
            : 'Fictional design review',
        seed.subtract(const Duration(minutes: 10)),
        seed.add(Duration(minutes: source.id == sources.first.id ? 8 : 15)),
        response: 'tentative',
      ),
      if (source.id == sources.first.id) ...[
        timed(
          'next',
          'Fictional project planning',
          seed.add(const Duration(minutes: 30)),
          seed.add(const Duration(hours: 1)),
        ),
        timed(
          'tomorrow',
          'Fictional catch-up',
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10).toUtc(),
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11).toUtc(),
          response: 'needsAction',
        ),
        CalendarEvent(
          id: 'date-only',
          calendarId: source.id,
          title: 'Fictional planning days',
          status: 'confirmed',
          selfResponse: 'accepted',
          startDate: window.first,
          endDate: window.first.plusDays(2),
        ),
      ],
    ];
  }

  @override
  void cancel() {}
  @override
  void dispose() {}
}

class _Platform implements CalendarPresentationPlatform {
  _Platform(this.host);
  final NativeWindowsHost host;
  @override
  Future<Map<String, String>> formatCalendar(
    List<DateTime> instants,
    List<CalendarDate> dates,
  ) => host.formatCalendar(instants, dates);
  @override
  Future<void> openCalendarLink(String url, String kind, int generation) async {
    // Intentionally fail safely: review clicks never open real meeting sites.
    throw StateError('Fictional browser action blocked by the review adapter');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = NativeWindowsHost();
  final metadata = await host.channel.invokeMapMethod<String, Object?>(
    'environment',
  );
  if (metadata?['calendarReview'] != true) {
    throw StateError('Review requires the isolated native review target');
  }
  final environment = await host.initialize();
  sqfliteFfiInit();
  final app = await AppController.create(
    SqliteRepository(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    ),
    clock: NativeTimerClock(),
  );
  const clock = DeviceCalendarClock();
  const scheduler = TimerCalendarScheduler();
  final connection = CalendarConnectionController(
    configuration: const GoogleCalendarConfiguration(
      clientId: '123-fictionalreview.apps.googleusercontent.com',
    ),
    authorization: _Authorization(),
    store: _Credentials(),
  );
  final provider = _Provider();
  final reader = CalendarReadController(
    connection: connection,
    provider: provider,
    cache: _Cache(),
    clock: clock,
    scheduler: scheduler,
  );
  final desktop = DesktopController(
    app,
    host,
    environment,
    connection: connection,
    calendarData: reader,
    calendarPlatform: _Platform(host),
  );
  await desktop.initialize();
  await connection.initialize();
  await connection.connect();
  await reader.retry();
  await reader.refresh();
  await reader.select(_Provider.sources.map((s) => s.id).toSet());
  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Session 7 review · fictional data')),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Real CalendarReadController → agenda → native popup. Memory-only synthetic adapters. Browser actions are blocked. The owner profile is not used.',
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: desktop.showPopup,
                    child: const Text('Open real agenda pipeline'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      provider.offline = true;
                      await reader.refresh();
                      await desktop.showPopup();
                    },
                    child: const Text('Partial calendar failure'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      provider.offline = false;
                      await reader.refresh(manual: true);
                      await desktop.showPopup();
                    },
                    child: const Text('Restore fresh data'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await host.channel.invokeMethod<void>('reviewTextScale', {
                        'percent': 200,
                      });
                      await desktop.showPopup();
                    },
                    child: const Text('Native layout at 200% text'),
                  ),
                  OutlinedButton(
                    onPressed: () async {
                      await host.channel.invokeMethod<void>('reviewTextScale', {
                        'percent': 0,
                      });
                      await desktop.showPopup();
                    },
                    child: const Text('Use Windows text preference'),
                  ),
                  OutlinedButton(
                    onPressed: desktop.quit,
                    child: const Text('Quit review'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
