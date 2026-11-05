import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_read_controller.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/google_calendar_reader.dart';
import 'package:poma/data/windows_calendar_cache.dart';
import 'package:poma/data/windows_calendar_credentials.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/main.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'calendar_connection_test.dart'
    show MemoryCredentials, FakeAuthorization, configured;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

const work = CalendarSource(
  id: 'work/@example',
  name: 'Work',
  accessRole: 'owner',
  timeZone: 'America/New_York',
  backgroundColor: '#112233',
);
const team = CalendarSource(
  id: 'team',
  name: 'Work',
  accessRole: 'reader',
  timeZone: 'Asia/Kolkata',
);
const restricted = CalendarSource(
  id: 'restricted',
  name: 'Availability only',
  accessRole: 'freeBusyReader',
  timeZone: 'UTC',
);

class TestCalendarClock implements CalendarClock {
  TestCalendarClock({DateTime? time, String location = 'UTC'})
    : time = time ?? DateTime.utc(2026, 10, 25, 12),
      location = location == 'UTC' ? tz.UTC : tz.getLocation(location);
  DateTime time;
  tz.Location location;
  @override
  CalendarWindow dayWindow(CalendarDate day) {
    final until = day.plusDays(1);
    return CalendarWindow(
      first: day,
      until: until,
      startUtc: tz.TZDateTime(location, day.year, day.month, day.day).toUtc(),
      endUtc: tz.TZDateTime(
        location,
        until.year,
        until.month,
        until.day,
      ).toUtc(),
    );
  }

  @override
  DateTime nowUtc() => time.toUtc();
  @override
  DateTime nextMidnightUtc() {
    final local = tz.TZDateTime.from(time, location);
    return tz.TZDateTime(
      location,
      local.year,
      local.month,
      local.day + 1,
    ).toUtc();
  }

  @override
  CalendarWindow window() {
    final local = tz.TZDateTime.from(time, location);
    final first = CalendarDate(local.year, local.month, local.day);
    final until = first.plusDays(7);
    return CalendarWindow(
      first: first,
      until: until,
      startUtc: tz.TZDateTime(
        location,
        first.year,
        first.month,
        first.day,
      ).toUtc(),
      endUtc: tz.TZDateTime(
        location,
        until.year,
        until.month,
        until.day,
      ).toUtc(),
    );
  }
}

class ScheduledTestJob implements CalendarScheduledJob {
  ScheduledTestJob(this.at, this.callback);
  final DateTime at;
  final void Function() callback;
  bool cancelled = false;
  @override
  void cancel() {
    cancelled = true;
  }
}

class TestCalendarScheduler implements CalendarScheduler {
  TestCalendarScheduler(this.clock);
  final TestCalendarClock clock;
  final List<ScheduledTestJob> jobs = [];
  @override
  CalendarScheduledJob after(Duration duration, void Function() callback) {
    final job = ScheduledTestJob(
      clock.nowUtc().add(duration.isNegative ? Duration.zero : duration),
      callback,
    );
    jobs.add(job);
    return job;
  }

  Future<void> advance(Duration duration) async {
    final end = clock.nowUtc().add(duration);
    while (true) {
      final due = jobs.where((j) => !j.cancelled && !j.at.isAfter(end)).toList()
        ..sort((a, b) => a.at.compareTo(b.at));
      if (due.isEmpty) break;
      final job = due.first;
      clock.time = job.at;
      job.cancel();
      job.callback();
      await settleCalendar();
    }
    clock.time = end;
    await settleCalendar();
  }
}

Future<void> settleCalendar() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

CalendarEvent event(
  String id,
  CalendarWindow window, {
  String calendar = 'work/@example',
}) => CalendarEvent(
  id: id,
  calendarId: calendar,
  title: 'Synthetic event',
  status: 'confirmed',
  selfResponse: 'accepted',
  startUtc: window.startUtc.add(const Duration(hours: 10)),
  endUtc: window.startUtc.add(const Duration(hours: 11)),
);

class MemoryCalendarCache implements CalendarCacheStore {
  final Map<String, CalendarAccountData> accounts = {};
  int scope = 0, writes = 0;
  String? active;
  int Function() revision = () => 0;
  bool fail = false;
  Completer<void>? nextWrite;
  void check(CalendarCacheLease lease) {
    if (lease.scope != scope ||
        lease.accountKey != active ||
        lease.revision != revision()) {
      throw const CalendarReadFailure(CalendarReadFailureKind.storage);
    }
  }

  @override
  Future<CalendarCacheLease> open(int expected, String accountKey) async {
    if (expected != revision()) {
      throw const CalendarReadFailure(CalendarReadFailureKind.storage);
    }
    active = accountKey;
    return CalendarCacheLease(expected, ++scope, accountKey);
  }

  @override
  Future<CalendarAccountData?> read(CalendarCacheLease lease) async {
    check(lease);
    return accounts[lease.accountKey];
  }

  @override
  Future<void> write(CalendarCacheLease lease, CalendarAccountData data) async {
    final gate = nextWrite;
    nextWrite = null;
    await gate?.future;
    check(lease);
    if (fail) throw const CalendarReadFailure(CalendarReadFailureKind.storage);
    accounts[lease.accountKey] = CalendarAccountData.fromJson(
      jsonDecode(jsonEncode(data.toJson())) as Map,
      lease.accountKey,
    );
    writes++;
  }

  @override
  Future<void> invalidate() async {
    scope++;
    active = null;
  }
}

class FakeCalendarProvider implements CalendarReadProvider {
  List<CalendarSource> catalog = [work, team, restricted];
  final Map<String, List<CalendarEvent>> items = {};
  final Map<String, CalendarReadFailure> errors = {};
  Future<List<CalendarSource>> Function()? onCalendars;
  Future<List<CalendarEvent>> Function(CalendarSource, CalendarWindow)?
  onEvents;
  int lists = 0, cancellations = 0;
  final List<String> requests = [];
  @override
  Future<List<CalendarSource>> calendars() async {
    lists++;
    return onCalendars == null ? catalog : onCalendars!();
  }

  @override
  Future<List<CalendarEvent>> events(
    CalendarSource source,
    CalendarWindow window,
  ) async {
    requests.add(source.id);
    if (errors[source.id] != null) throw errors[source.id]!;
    return onEvents == null
        ? items[source.id] ?? []
        : onEvents!(source, window);
  }

  @override
  void cancel() {
    cancellations++;
  }

  @override
  void dispose() {
    cancel();
  }
}

class CalendarRig {
  CalendarRig(
    this.clock,
    this.scheduler,
    this.credentials,
    this.auth,
    this.connection,
    this.provider,
    this.cache,
    this.reader,
  );
  final TestCalendarClock clock;
  final TestCalendarScheduler scheduler;
  final MemoryCredentials credentials;
  final FakeAuthorization auth;
  final CalendarConnectionController connection;
  final FakeCalendarProvider provider;
  final MemoryCalendarCache cache;
  final CalendarReadController reader;
}

Future<CalendarRig> rig({TestCalendarClock? testClock}) async {
  final clock = testClock ?? TestCalendarClock();
  final scheduler = TestCalendarScheduler(clock);
  final store = MemoryCredentials();
  final auth = FakeAuthorization();
  CalendarAuthorization grant([String account = 'synthetic-primary']) =>
      CalendarAuthorization(
        accountId: account,
        accessToken: 'synthetic-access',
        refreshToken: 'synthetic-refresh',
        scopes: calendarReadScopes,
        expiresAt: clock.nowUtc().add(const Duration(hours: 1)),
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
  final cache = MemoryCalendarCache()..revision = () => store.revision;
  store.onPurge = () {
    cache.accounts.clear();
    cache.scope++;
    cache.active = null;
  };
  final provider = FakeCalendarProvider();
  final reader = CalendarReadController(
    connection: connection,
    provider: provider,
    cache: cache,
    clock: clock,
    scheduler: scheduler,
  )..initialize();
  addTearDown(() {
    reader.dispose();
    connection.dispose();
  });
  await settleCalendar();
  return CalendarRig(
    clock,
    scheduler,
    store,
    auth,
    connection,
    provider,
    cache,
    reader,
  );
}

class TestAccess implements CalendarReadAccess {
  String token = 'old';
  int refreshes = 0, reconnects = 0;
  bool refreshSucceeds = true;
  @override
  Future<T?> withAccess<T>(Future<T> Function(String token) operation) =>
      operation(token);
  @override
  Future<bool> refreshRejectedAccess(String token) async {
    refreshes++;
    this.token = 'new';
    return refreshSucceeds;
  }

  @override
  void requireReconnect() {
    reconnects++;
  }
}

http.Response jsonReply(
  Object value, [
  int status = 200,
  Map<String, String>? headers,
]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json', ...?headers},
);

void main() {
  setUpAll(tz_data.initializeTimeZones);
  test(
    'initial metadata preserves identity and roles without fetching events or adopting provider selection',
    () async {
      final r = await rig();
      expect(r.reader.sources.map((s) => s.id), [
        work.id,
        team.id,
        restricted.id,
      ]);
      expect(r.reader.sources.first.timeZone, work.timeZone);
      expect(r.reader.sources.first.backgroundColor, '#112233');
      expect(r.reader.selected, isEmpty);
      expect(r.provider.requests, isEmpty);
      await r.reader.select({restricted.id});
      expect(r.reader.selected, isEmpty);
      expect(r.provider.requests, isEmpty);
    },
  );
  test(
    'atomic per-source snapshots retain previous success on failure and remove moved/deleted events',
    () async {
      final r = await rig();
      r.provider.items[work.id] = [event('old', r.reader.window)];
      r.provider.items[team.id] = [
        event('team-old', r.reader.window, calendar: team.id),
      ];
      await r.reader.select({work.id, team.id});
      final success = r.reader.snapshots[work.id]!.succeededAt;
      r.clock.time = r.clock.time.add(const Duration(minutes: 6));
      r.provider.errors[work.id] = const CalendarReadFailure(
        CalendarReadFailureKind.network,
      );
      r.provider.items[team.id] = [
        event('team-new', r.reader.window, calendar: team.id),
      ];
      await r.reader.refresh();
      expect(r.reader.snapshots[work.id]!.events.single.id, 'old');
      expect(r.reader.snapshots[work.id]!.succeededAt, success);
      expect(r.reader.snapshots[team.id]!.events.single.id, 'team-new');
      expect(
        r.reader.sourceFailures[work.id]!.kind,
        CalendarReadFailureKind.network,
      );
      r.provider.errors.clear();
      r.provider.items[work.id] = [];
      await r.reader.refresh();
      expect(r.reader.snapshots[work.id]!.events, isEmpty);
      expect(r.reader.sourceFailures, isEmpty);
    },
  );
  test(
    'failed cache commit preserves event data and timestamp, retry commits',
    () async {
      final r = await rig();
      r.provider.items[work.id] = [event('old', r.reader.window)];
      await r.reader.select({work.id});
      final original = r.reader.snapshots[work.id];
      r.cache.fail = true;
      r.provider.items[work.id] = [];
      await r.reader.refresh();
      expect(r.reader.snapshots[work.id], same(original));
      expect(r.reader.failure!.kind, CalendarReadFailureKind.storage);
      r.cache.fail = false;
      await r.reader.retry();
      expect(r.reader.snapshots[work.id]!.events, isEmpty);
    },
  );
  test(
    'deselection invalidates a late page and durably removes that calendar',
    () async {
      final r = await rig();
      await r.reader.select({work.id});
      final late = Completer<List<CalendarEvent>>();
      r.provider.onEvents = (s, w) => late.future;
      final refresh = r.reader.refresh();
      await settleCalendar();
      await r.reader.select({});
      late.complete([event('obsolete', r.reader.window)]);
      await refresh;
      expect(r.reader.events, isEmpty);
      expect(r.reader.snapshots, isEmpty);
      expect(r.cache.accounts.values.single.selected, isEmpty);
    },
  );
  test(
    'native-style lease rejects a delayed write after selection changes',
    () async {
      final r = await rig();
      await r.reader.select({work.id});
      final gate = Completer<void>();
      r.cache.nextWrite = gate;
      final refresh = r.reader.refresh();
      await settleCalendar();
      await r.reader.select({});
      gate.complete();
      await refresh;
      expect(r.cache.accounts.values.single.selected, isEmpty);
      expect(r.reader.snapshots, isEmpty);
    },
  );
  test(
    'same verified account reconnect retains selection, different account starts empty',
    () async {
      final r = await rig();
      await r.reader.select({work.id, team.id});
      final key = r.connection.verifiedAccountKey;
      await r.connection.connect();
      await settleCalendar();
      expect(r.reader.selected, {work.id, team.id});
      expect(r.credentials.purges.last, isFalse);
      r.auth.onAuthorize = () async => CalendarAuthorization(
        accountId: 'another-account',
        accessToken: 'other',
        refreshToken: 'other-refresh',
        scopes: calendarReadScopes,
        expiresAt: r.clock.nowUtc().add(const Duration(hours: 1)),
      );
      await r.connection.connect();
      await settleCalendar();
      expect(r.connection.verifiedAccountKey, isNot(key));
      expect(r.reader.selected, isEmpty);
      expect(r.reader.snapshots, isEmpty);
      expect(r.cache.accounts.containsKey(key), isFalse);
    },
  );
  test(
    'invalid grant retires credentials while stale cache and same-account selection survive restart',
    () async {
      final r = await rig();
      r.provider.items[work.id] = [event('saved', r.reader.window)];
      await r.reader.select({work.id});
      r.connection.requireReconnect();
      await settleCalendar();
      expect(r.credentials.value, isNull);
      expect(r.credentials.retired, isNotNull);
      expect(r.reader.events.single.id, 'saved');
      final requests = r.provider.requests.length;
      await r.scheduler.advance(const Duration(minutes: 5));
      expect(r.provider.requests.length, requests);
      r.reader.dispose();
      r.connection.dispose();
      final restored = CalendarConnectionController(
        configuration: configured,
        authorization: r.auth,
        store: r.credentials,
        now: r.clock.nowUtc,
      );
      await restored.initialize();
      expect(restored.status, CalendarConnectionStatus.reconnectRequired);
      final reader = CalendarReadController(
        connection: restored,
        provider: FakeCalendarProvider(),
        cache: r.cache,
        clock: r.clock,
        scheduler: r.scheduler,
      )..initialize();
      addTearDown(() {
        reader.dispose();
        restored.dispose();
      });
      await settleCalendar();
      expect(reader.selected, {work.id});
      expect(reader.events.single.id, 'saved');
    },
  );
  test(
    'disconnect purges account data and rejects late results; reconnect selects none',
    () async {
      final r = await rig();
      await r.reader.select({work.id});
      final late = Completer<List<CalendarEvent>>();
      r.provider.onEvents = (s, w) => late.future;
      final refresh = r.reader.refresh();
      await settleCalendar();
      await r.connection.disconnect();
      late.complete([event('late', r.reader.window)]);
      await refresh;
      await settleCalendar();
      expect(r.cache.accounts, isEmpty);
      expect(r.reader.accountKey, isNull);
      r.provider.onEvents = null;
      await r.connection.connect();
      await settleCalendar();
      expect(r.reader.selected, isEmpty);
    },
  );
  test(
    'complete catalog loss of access purges snapshots, failed catalog does not',
    () async {
      final r = await rig();
      r.provider.items[work.id] = [event('saved', r.reader.window)];
      await r.reader.select({work.id});
      r.provider.onCalendars = () async =>
          throw const CalendarReadFailure(CalendarReadFailureKind.network);
      await r.reader.refresh();
      expect(r.reader.selected, {work.id});
      r.provider.onCalendars = null;
      r.provider.catalog = [
        CalendarSource(
          id: work.id,
          name: 'Work',
          accessRole: 'freeBusyReader',
          timeZone: work.timeZone,
        ),
      ];
      await r.reader.refresh();
      expect(r.reader.selected, isEmpty);
      expect(r.reader.snapshots, isEmpty);
    },
  );
  test(
    'offline rollover trims expired entries and exposes uncovered tail; device zone changes invalidate work',
    () async {
      final r = await rig();
      r.provider.items[work.id] = [
        event('expired-today', r.reader.window),
        CalendarEvent(
          id: 'future',
          calendarId: work.id,
          title: 'Future',
          status: 'confirmed',
          selfResponse: 'unknown',
          startUtc: r.reader.window.startUtc.add(const Duration(days: 3)),
          endUtc: r.reader.window.startUtc.add(
            const Duration(days: 3, hours: 1),
          ),
        ),
      ];
      await r.reader.select({work.id});
      r.connection.requireReconnect();
      await settleCalendar();
      r.clock.time = r.clock.time.add(const Duration(days: 1));
      await r.reader.lifecycleChanged();
      await settleCalendar();
      expect(r.reader.events.map((e) => e.id), ['future']);
      expect(
        r.reader.snapshots[work.id]!.coverage.covers(r.reader.window),
        isFalse,
      );
      expect(
        r.cache.accounts.values.single.snapshots[work.id]!.events,
        hasLength(1),
      );
      final previous = r.reader.window.key;
      r.clock.location = tz.getLocation('Pacific/Auckland');
      await r.reader.lifecycleChanged();
      expect(r.reader.window.key, isNot(previous));
    },
  );
  test(
    'manual/lifecycle refreshes coalesce and minute presentation performs no IO',
    () async {
      final r = await rig();
      await r.reader.select({work.id});
      final lists = r.provider.lists, writes = r.cache.writes;
      await r.scheduler.advance(const Duration(minutes: 1));
      expect(r.provider.lists, lists);
      expect(r.cache.writes, writes);
      await r.reader.opened();
      expect(r.provider.lists, lists);
      final pending = Completer<List<CalendarSource>>();
      r.provider.onCalendars = () => pending.future;
      final a = r.reader.refresh(), b = r.reader.refresh(manual: true);
      expect(identical(a, b), isTrue);
      pending.complete(r.provider.catalog);
      await Future.wait([a, b]);
      expect(r.provider.lists, lists + 1);
      r.provider.onCalendars = null;
      await r.scheduler.advance(const Duration(minutes: 4));
      expect(r.provider.lists, lists + 2);
    },
  );
  test(
    'DST windows use local dates instead of 168 hours, all-day end is exclusive',
    () {
      final spring = TestCalendarClock(
        time: DateTime.utc(2026, 3, 7, 12),
        location: 'America/New_York',
      ).window();
      final autumn = TestCalendarClock(
        time: DateTime.utc(2026, 10, 31, 12),
        location: 'America/New_York',
      ).window();
      expect(spring.endUtc.difference(spring.startUtc).inHours, 167);
      expect(autumn.endUtc.difference(autumn.startUtc).inHours, 169);
      final ended = CalendarEvent(
        id: 'ended',
        calendarId: work.id,
        title: 'Day',
        status: 'confirmed',
        selfResponse: 'unknown',
        startDate: spring.first.plusDays(-1),
        endDate: spring.first,
      );
      expect(ended.overlaps(spring), isFalse);
      expect(
        CalendarDate.parse('2026-12-31').plusDays(1).toString(),
        '2027-01-01',
      );
      expect(() => CalendarDate.parse('2026-02-30'), throwsFormatException);
    },
  );
  test(
    'fully paginated metadata handles empty continuation pages, hidden calendars and restricted roles',
    () async {
      final clock = TestCalendarClock(), access = TestAccess();
      final requests = <http.Request>[];
      final reader = GoogleCalendarReader(
        access: access,
        clock: clock,
        scheduler: TestCalendarScheduler(clock),
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          if (!request.url.queryParameters.containsKey('pageToken')) {
            return jsonReply({'items': [], 'nextPageToken': 'second'});
          }
          return jsonReply({
            'items': [
              {
                'id': 'real-calendar',
                'summary': 'Original',
                'summaryOverride': 'Mine',
                'accessRole': 'writerWithoutPrivateAccess',
                'timeZone': 'Asia/Kolkata',
                'colorId': '4',
                'backgroundColor': '#abcdef',
                'foregroundColor': '#123456',
                'selected': true,
              },
            ],
          });
        }),
      );
      addTearDown(reader.dispose);
      final result = await reader.calendars();
      expect(requests, hasLength(2));
      expect(requests.first.url.queryParameters['showHidden'], 'true');
      expect(result.single.id, 'real-calendar');
      expect(result.single.name, 'Mine');
      expect(result.single.readable, isTrue);
      expect(result.single.foregroundColor, '#123456');
      expect(
        requests.first.url.queryParameters['fields'],
        isNot(contains('description')),
      );
    },
  );
  test(
    'event pages expand recurrence, preserve original instance identity, include ongoing and date-only events, and omit private extras',
    () async {
      final clock = TestCalendarClock(location: 'Asia/Kolkata');
      final requests = <http.Request>[];
      final reader = GoogleCalendarReader(
        access: TestAccess(),
        clock: clock,
        scheduler: TestCalendarScheduler(clock),
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          if (request.url.queryParameters['pageToken'] == 'next') {
            return jsonReply({
              'items': [
                {
                  'id': 'all-day',
                  'start': {'date': '${clock.window().until.plusDays(-1)}'},
                  'end': {'date': '${clock.window().until}'},
                },
              ],
            });
          }
          return jsonReply({
            'nextPageToken': 'next',
            'items': [
              {
                'id': 'instance',
                'summary': 'Synthetic',
                'recurringEventId': 'series',
                'originalStartTime': {'dateTime': '2026-10-25T09:00:00Z'},
                'start': {
                  'dateTime': '2026-10-24T23:00:00Z',
                  'timeZone': 'UTC',
                },
                'end': {'dateTime': '2026-10-25T13:00:00Z'},
                'attendees': [
                  {
                    'self': true,
                    'responseStatus': 'tentative',
                    'email': 'do-not-retain',
                  },
                ],
                'description': 'never-retain-description',
                'conferenceData': {
                  'entryPoints': [
                    {
                      'entryPointType': 'video',
                      'uri': 'https://meet.google.com/abc-defg-hij',
                    },
                  ],
                },
                'htmlLink':
                    'https://calendar.google.com/calendar/event?eid=synthetic',
              },
              {'id': 'cancelled', 'status': 'cancelled'},
              {
                'id': 'declined',
                'attendees': [
                  {'self': true, 'responseStatus': 'declined'},
                ],
                'start': {'dateTime': '2026-10-25T11:00:00Z'},
                'end': {'dateTime': '2026-10-25T12:00:00Z'},
              },
            ],
          });
        }),
      );
      addTearDown(reader.dispose);
      final result = await reader.events(work, clock.window());
      expect(result, hasLength(2));
      expect(result.first.id, 'instance');
      expect(result.first.recurringEventId, 'series');
      expect(result.first.originalStart, '2026-10-25T09:00:00Z');
      expect(result.first.selfResponse, 'tentative');
      expect(result.first.meetingUrl, startsWith('https://meet.google.com/'));
      expect(result.last.title, 'Busy');
      expect(result.last.allDay, isTrue);
      expect(requests.first.url.pathSegments[3], work.id);
      expect(requests.first.url.queryParameters['singleEvents'], 'true');
      expect(requests.first.url.queryParameters['maxAttendees'], '1');
      expect(requests.first.url.queryParameters, isNot(contains('syncToken')));
      expect(
        DateTime.parse(requests.first.url.queryParameters['timeMax']!),
        DateTime.utc(2026, 11, 1, 4),
      );
      final retained = jsonEncode(result.map((e) => e.toJson()).toList());
      expect(retained, isNot(contains('never-retain-description')));
      expect(retained, isNot(contains('do-not-retain')));
    },
  );
  test(
    'failed later page, repeated token and malformed interval never return a partial snapshot',
    () async {
      for (final mode in ['page-failure', 'repeated', 'malformed']) {
        final clock = TestCalendarClock();
        var calls = 0;
        final reader = GoogleCalendarReader(
          access: TestAccess(),
          clock: clock,
          scheduler: TestCalendarScheduler(clock),
          clientFactory: () => MockClient((request) async {
            calls++;
            if (mode == 'malformed') {
              return jsonReply({
                'items': [
                  {
                    'id': 'broken',
                    'start': {'dateTime': 'missing-offset'},
                    'end': {'date': '2026-10-27'},
                  },
                ],
              });
            }
            if (calls == 1 || mode == 'repeated') {
              return jsonReply({'items': [], 'nextPageToken': 'same'});
            }
            return jsonReply({}, 403);
          }),
        );
        await expectLater(
          reader.events(work, clock.window()),
          throwsA(isA<CalendarReadFailure>()),
        );
        expect(calls, mode == 'malformed' ? 1 : 2);
        reader.dispose();
      }
    },
  );
  test(
    '401 forces one refresh and replay; repeated 401 requires reconnect, permission 403 never retries',
    () async {
      for (final mode in ['recover', 'repeat', 'forbidden']) {
        final clock = TestCalendarClock(), access = TestAccess();
        var calls = 0;
        final reader = GoogleCalendarReader(
          access: access,
          clock: clock,
          scheduler: TestCalendarScheduler(clock),
          clientFactory: () => MockClient((request) async {
            calls++;
            if (mode == 'forbidden') return jsonReply({}, 403);
            if (calls == 1 || mode == 'repeat') return jsonReply({}, 401);
            expect(request.headers['Authorization'], 'Bearer new');
            return jsonReply({'items': []});
          }),
        );
        if (mode == 'recover') {
          expect(await reader.calendars(), isEmpty);
        } else {
          await expectLater(
            reader.calendars(),
            throwsA(isA<CalendarReadFailure>()),
          );
        }
        expect(calls, mode == 'forbidden' ? 1 : 2);
        expect(access.refreshes, mode == 'forbidden' ? 0 : 1);
        expect(access.reconnects, mode == 'repeat' ? 1 : 0);
        reader.dispose();
      }
    },
  );
  test(
    '429 and rate-limit 403 honor Retry-After, bound retries, reject manual hammering',
    () async {
      for (final status in [429, 403]) {
        final clock = TestCalendarClock(), access = TestAccess();
        final scheduler = TestCalendarScheduler(clock);
        var calls = 0;
        final reader = GoogleCalendarReader(
          access: access,
          clock: clock,
          scheduler: scheduler,
          jitter: () => 0,
          clientFactory: () => MockClient((request) async {
            calls++;
            return jsonReply(
              {
                'error': {
                  'errors': [
                    {'reason': 'rateLimitExceeded'},
                  ],
                },
              },
              status,
              {'retry-after': '120'},
            );
          }),
        );
        final response = expectLater(
          reader.calendars(),
          throwsA(
            isA<CalendarReadFailure>().having(
              (e) => e.kind,
              'kind',
              CalendarReadFailureKind.throttled,
            ),
          ),
        );
        await settleCalendar();
        expect(calls, 1);
        await expectLater(
          reader.calendars(),
          throwsA(isA<CalendarReadFailure>()),
        );
        expect(calls, 1);
        await scheduler.advance(const Duration(seconds: 119));
        expect(calls, 1);
        await scheduler.advance(const Duration(seconds: 1));
        expect(calls, 2);
        await scheduler.advance(const Duration(seconds: 120));
        await response;
        expect(calls, 3);
        reader.dispose();
      }
    },
  );
  test(
    'network retry backoff is cancellable and never survives Quit',
    () async {
      final clock = TestCalendarClock();
      final scheduler = TestCalendarScheduler(clock);
      var calls = 0;
      final reader = GoogleCalendarReader(
        access: TestAccess(),
        clock: clock,
        scheduler: scheduler,
        jitter: () => 0,
        clientFactory: () => MockClient((request) async {
          calls++;
          throw const SocketException('synthetic');
        }),
      );
      final pending = expectLater(
        reader.calendars(),
        throwsA(
          isA<CalendarReadFailure>().having(
            (e) => e.kind,
            'kind',
            CalendarReadFailureKind.cancelled,
          ),
        ),
      );
      await settleCalendar();
      expect(calls, 1);
      reader.dispose();
      await pending;
      await scheduler.advance(const Duration(minutes: 10));
      expect(calls, 1);
    },
  );
  test(
    'meeting/event URL validation rejects deceptive hosts, schemes, credentials and remote markup',
    () {
      for (final url in [
        'javascript:alert(1)',
        'file:///test',
        'https://meet.google.com.evil.test/x',
        'https://evilzoom.us/x',
        'https://user@meet.google.com/x',
        'https://zoom.us:444/x',
        'https://meet.google.com/\\evil',
        '<a href="https://meet.google.com/x">',
      ]) {
        expect(safeCalendarUrl(url, meeting: true), isNull);
      }
      expect(
        safeCalendarUrl('https://company.zoom.us/j/123', meeting: true),
        isNotNull,
      );
      expect(
        safeCalendarUrl(
          'https://www.google.com/url?redirect=evil',
          meeting: false,
        ),
        isNull,
      );
    },
  );
  test(
    'account replacement drops an old event response instead of populating the new namespace',
    () async {
      final r = await rig();
      await r.reader.select({work.id});
      final pending = Completer<List<CalendarEvent>>();
      r.provider.onEvents = (_, _) => pending.future;
      final old = r.reader.refresh();
      await settleCalendar();
      r.auth.onAuthorize = () async => CalendarAuthorization(
        accountId: 'other',
        accessToken: 'other',
        refreshToken: 'other',
        scopes: calendarReadScopes,
        expiresAt: r.clock.nowUtc().add(const Duration(hours: 1)),
      );
      await r.connection.connect();
      await settleCalendar();
      pending.complete([event('wrong-account', r.clock.window())]);
      await old;
      expect(r.reader.events, isEmpty);
      expect(r.cache.accounts.values.single.selected, isEmpty);
    },
  );
  test(
    'window change rejects old responses even when events overlap both windows',
    () async {
      final r = await rig();
      await r.reader.select({work.id});
      final pending = Completer<List<CalendarEvent>>();
      final oldWindow = r.reader.window;
      r.provider.onEvents = (_, window) =>
          window.key == oldWindow.key ? pending.future : Future.value([]);
      final old = r.reader.refresh();
      await settleCalendar();
      r.clock.time = r.clock.time.add(const Duration(days: 1));
      await r.reader.lifecycleChanged();
      pending.complete([event('old-window', r.reader.window)]);
      await old;
      expect(r.reader.snapshots[work.id]!.coverage.key, r.reader.window.key);
      expect(r.reader.events, isEmpty);
    },
  );
  test(
    'full reset clears cache and prevents a delayed event from repopulating it',
    () async {
      final r = await rig();
      await r.reader.select({work.id});
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
        resetParticipant: r.connection,
      );
      addTearDown(app.dispose);
      final pending = Completer<List<CalendarEvent>>();
      r.provider.onEvents = (_, _) => pending.future;
      final old = r.reader.refresh();
      await settleCalendar();
      expect(await app.deleteAllLocalData(), isTrue);
      pending.complete([event('pre-reset', r.reader.window)]);
      await old;
      await settleCalendar();
      expect(r.cache.accounts, isEmpty);
      expect(r.reader.selected, isEmpty);
    },
  );
  test(
    'native adapter validates documents, carries leases, and reads legacy and retired credentials',
    () async {
      const channel = MethodChannel('synthetic/calendar-session6');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var scope = 0;
      String? document;
      String? credentialJson;
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map?;
        switch (call.method) {
          case 'calendarCacheBind':
            return ++scope;
          case 'calendarCacheInvalidate':
            scope++;
            return null;
          case 'calendarCacheRead':
            return document;
          case 'calendarCacheWrite':
            if (args!['scope'] != scope) {
              throw PlatformException(
                code: 'obsolete',
                message: 'private path',
              );
            }
            document = args['document'] as String;
            return null;
          case 'calendarCredentialsRead':
            return {'revision': 7, 'credential': credentialJson};
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      const cache = WindowsCalendarCache(channel);
      final key = 'a' * 64;
      final lease = await cache.open(7, key);
      final data = CalendarAccountData(
        accountKey: key,
        sources: [work],
        selected: {work.id},
      );
      await cache.write(lease, data);
      expect((await cache.read(lease))!.selected, {work.id});
      final malformedColor = data.toJson();
      (malformedColor['sources'] as List).first['backgroundColor'] =
          'not-a-color';
      document = jsonEncode(malformedColor);
      final recovered = (await cache.read(lease))!;
      expect(recovered.sources.single.backgroundColor, isNull);
      expect(recovered.selected, {work.id});
      await cache.invalidate();
      await expectLater(
        cache.write(lease, data),
        throwsA(isA<CalendarReadFailure>()),
      );
      document = '{"version":99}';
      await expectLater(
        cache.read(await cache.open(7, key)),
        throwsA(isA<CalendarReadFailure>()),
      );
      final credentials = WindowsCalendarCredentials(channel);
      credentialJson = jsonEncode({
        'version': 1,
        'clientId': configured.clientId,
        'accountId': 'synthetic',
        'refreshToken': 'synthetic-only',
        'scopes': calendarReadScopes.toList(),
      });
      expect((await credentials.read()).credential, isNotNull);
      credentialJson = jsonEncode(
        CalendarAccountIdentity(
          clientId: configured.clientId,
          accountId: 'synthetic',
        ).retiredJson(),
      );
      final retired = await credentials.read();
      expect(retired.credential, isNull);
      expect(retired.identity!.accountId, 'synthetic');
    },
  );
  testWidgets(
    'Settings requires Save selection, labels source access and age, and respects lock redaction',
    (tester) async {
      final r = (await tester.runAsync(rig))!;
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final desktop = DesktopController(
        app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'synthetic',
          version: 'test',
          packaged: false,
          sessionState: 'unlocked',
        ),
        connection: r.connection,
        calendarData: r.reader,
      );
      await desktop.initialize();
      desktop.navigate(4);
      await tester.pumpWidget(PomaApp(controller: app, desktop: desktop));
      await tester.pumpAndSettle();
      final tile = find.byKey(ValueKey('calendar-source-${work.id}'));
      await tester.tap(find.text('Calendar settings'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        tile,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pump();
      expect(r.provider.requests, isEmpty);
      final save = find.byKey(const ValueKey('calendar-save-selection'));
      await tester.scrollUntilVisible(
        save,
        250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(r.reader.selected, {work.id});
      expect(r.provider.requests, [work.id]);
      expect(
        find.textContaining('updated less than a minute ago'),
        findsOneWidget,
      );
      await shell.onEvent!('sessionState', {'state': 'locked'});
      await tester.pumpAndSettle();
      expect(find.text(work.name), findsNothing);
      final settingsScroll = find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first;
      tester.state<ScrollableState>(settingsScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.textContaining('Calendar details are hidden'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      desktop.dispose();
      app.dispose();
    },
  );
}
