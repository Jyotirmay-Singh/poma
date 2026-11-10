// Fictional providers and accounts only. This library is never imported by lib/.
import 'package:intl/intl.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_read_controller.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/day_clock_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/focus_block_ports.dart';
import 'package:poma/data/calendar_time.dart';
import 'package:poma/domain/calendar_data.dart';

import 'calendar_agenda_test.dart' show RecordingCalendarPlatform;
import 'calendar_connection_test.dart'
    show MemoryCredentials, FakeAuthorization, configured;
import 'calendar_read_test.dart' as f;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

class FictionalDayClock extends f.TestCalendarClock {
  FictionalDayClock() : super(time: DateTime(2026, 11, 9, 15, 20).toUtc());
  @override
  CalendarWindow dayWindow(CalendarDate date) =>
      const DeviceCalendarClock().dayWindow(date);
  @override
  CalendarWindow window() {
    final now = time.toLocal(),
        first = CalendarDate(now.year, now.month, now.day),
        until = first.plusDays(7);
    return CalendarWindow(
      first: first,
      until: until,
      startUtc: dayWindow(first).startUtc,
      endUtc: dayWindow(until).startUtc,
    );
  }

  @override
  DateTime nextMidnightUtc() => dayWindow(window().first).endUtc;
}

class FictionalCalendarProvider extends f.FakeCalendarProvider
    implements CalendarPaletteProvider {
  FictionalCalendarProvider(this.clock);
  final FictionalDayClock clock;
  int paletteReads = 0;
  bool failPalette = false;
  @override
  Future<CalendarEventPalette> eventPalette() async {
    paletteReads++;
    if (failPalette) {
      throw const CalendarReadFailure(CalendarReadFailureKind.network);
    }
    return CalendarEventPalette(
      {
        '1': const CalendarEventColor('#7986CB', '#000000'),
        '2': const CalendarEventColor('#33B679', '#000000'),
        '3': const CalendarEventColor('#8E24AA', '#FFFFFF'),
        '4': const CalendarEventColor('#E67C73', '#000000'),
        '5': const CalendarEventColor('#F6BF26', '#000000'),
      },
      clock.nowUtc(),
      updated: 'fictional-palette',
    );
  }
}

class FictionalRegionalPlatform extends RecordingCalendarPlatform {
  @override
  Future<Map<String, String>> formatCalendar(
    List<DateTime> instants,
    List<CalendarDate> dates,
  ) async => {
    for (final t in instants)
      '${t.microsecondsSinceEpoch}': DateFormat('h:mm a').format(t.toLocal()),
    for (final date in dates) '$date': '$date',
  };
}

class FictionalTimeResolver implements FocusTimeResolver {
  bool reject = false;
  @override
  Future<String> fingerprint() async => 'fictional-device-zone';
  @override
  Future<FocusTimeResolution> resolve(DateTime wall) async {
    if (reject) throw StateError('fictional DST rejection');
    final local = DateTime(
      wall.year,
      wall.month,
      wall.day,
      wall.hour,
      wall.minute,
    );
    return FocusTimeResolution(
      utc: local.toUtc(),
      offsetMinutes: local.timeZoneOffset.inMinutes,
      zone: local.timeZoneName,
      fingerprint: 'fictional-device-zone',
    );
  }
}

class DayClockRig {
  DayClockRig(
    this.app,
    this.desktop,
    this.clock,
    this.provider,
    this.reader,
    this.cache,
    this.scheduler,
    this.connection,
    this.platform,
    this.resolver,
  );
  final AppController app;
  final DesktopController desktop;
  final FictionalDayClock clock;
  final FictionalCalendarProvider provider;
  final CalendarReadController reader;
  final f.MemoryCalendarCache cache;
  final f.TestCalendarScheduler scheduler;
  final CalendarConnectionController connection;
  final FictionalRegionalPlatform platform;
  final FictionalTimeResolver resolver;
  DayClockController get day => desktop.dayClock!;
  void dispose() {
    desktop.dispose();
    app.dispose();
  }
}

Future<DayClockRig> dayClockRig({bool crowded = false}) async {
  final clock = FictionalDayClock();
  // The scheduler and reader share exactly the same controllable clock.
  final actualScheduler = f.TestCalendarScheduler(clock);
  final store = MemoryCredentials(), auth = FakeAuthorization();
  CalendarAuthorization grant() => CalendarAuthorization(
    accountId: 'fictional.account@example.test',
    accessToken: 'fictional-access',
    refreshToken: 'fictional-refresh',
    scopes: calendarReadScopes,
    expiresAt: clock.nowUtc().add(const Duration(days: 3)),
  );
  auth.onAuthorize = () async => grant();
  auth.onRefresh = () async => grant();
  final connection = CalendarConnectionController(
    configuration: configured,
    authorization: auth,
    store: store,
    now: clock.nowUtc,
  );
  await connection.initialize();
  await connection.connect();
  final cache = f.MemoryCalendarCache()..revision = () => store.revision;
  final provider = FictionalCalendarProvider(clock)
    ..catalog = const [
      CalendarSource(
        id: 'personal',
        name: 'Personal',
        accessRole: 'owner',
        timeZone: 'UTC',
        primary: true,
        backgroundColor: '#64D8CB',
      ),
      CalendarSource(
        id: 'work',
        name: 'Work',
        accessRole: 'owner',
        timeZone: 'UTC',
        backgroundColor: '#B9A7FF',
      ),
      CalendarSource(
        id: 'travel',
        name: 'Travel',
        accessRole: 'reader',
        timeZone: 'UTC',
        backgroundColor: '#6CCBFF',
      ),
      CalendarSource(
        id: 'team',
        name: 'Team',
        accessRole: 'writer',
        timeZone: 'UTC',
        backgroundColor: '#F2C078',
      ),
      CalendarSource(
        id: 'reading',
        name: 'Reading',
        accessRole: 'owner',
        timeZone: 'UTC',
        backgroundColor: '#E89AB5',
      ),
    ];
  CalendarEvent event(
    String id,
    String title,
    String source,
    int hour,
    int minute,
    int duration,
  ) => CalendarEvent(
    id: id,
    calendarId: source,
    title: title,
    status: 'confirmed',
    selfResponse: 'accepted',
    startUtc: DateTime(2026, 11, 9, hour, minute).toUtc(),
    endUtc: DateTime(
      2026,
      11,
      9,
      hour,
      minute,
    ).add(Duration(minutes: duration)).toUtc(),
    eventUrl: 'https://calendar.google.com/calendar/event?eid=$id',
    meetingUrl: 'https://meet.google.com/abc-defg-hij',
  );
  final events = [
    event('lunch', 'Lunch', 'personal', 12, 30, 60),
    event('deep', 'Deep work', 'work', 13, 30, 60),
    event('travel', 'Travel', 'travel', 15, 0, 60),
    event('meeting', 'Meeting', 'team', 16, 30, 60),
    event('reading', 'Reading', 'reading', 21, 0, 60),
    CalendarEvent(
      id: 'all',
      calendarId: 'personal',
      title: 'Fictional workshop',
      status: 'confirmed',
      selfResponse: 'accepted',
      startDate: CalendarDate(2026, 11, 9),
      endDate: CalendarDate(2026, 11, 10),
    ),
    if (crowded) ...[
      for (var i = 0; i < 8; i++)
        event(
          'overlap-$i',
          'Fictional overlap ${i + 1}',
          'work',
          13,
          i * 3,
          100 - i * 3,
        ),
      event('short', 'Three-minute check-in', 'personal', 15, 12, 3),
    ],
  ];
  for (final source in provider.catalog) {
    provider.items[source.id] = events
        .where((e) => e.calendarId == source.id)
        .toList();
  }
  final reader = CalendarReadController(
    connection: connection,
    provider: provider,
    cache: cache,
    clock: clock,
    scheduler: actualScheduler,
  )..initialize();
  await f.settleCalendar();
  await reader.select(provider.catalog.map((s) => s.id).toSet());
  final app = await AppController.create(
    MemoryRepository(),
    clock: FakeClock(),
  );
  final platform = FictionalRegionalPlatform();
  final desktop = DesktopController(
    app,
    FakeShell(),
    const DesktopEnvironment(
      dataDirectory: 'fictional-only',
      version: 'session1-preview',
      packaged: false,
      visible: true,
      sessionState: 'unlocked',
    ),
    connection: connection,
    calendarData: reader,
    calendarPlatform: platform,
  );
  await desktop.initialize();
  final resolver = FictionalTimeResolver();
  desktop.dayClock!.time = resolver;
  desktop.navigate(5);
  await f.settleCalendar();
  return DayClockRig(
    app,
    desktop,
    clock,
    provider,
    reader,
    cache,
    actualScheduler,
    connection,
    platform,
    resolver,
  );
}
