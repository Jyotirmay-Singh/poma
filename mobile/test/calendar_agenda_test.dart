import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_agenda_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_presentation_ports.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/data/google_calendar_reader.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/calendar_preview.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'calendar_read_test.dart' as fixtures;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

class RecordingCalendarPlatform implements CalendarPresentationPlatform {
  final List<(String, String, int)> opened = [];
  final List<List<String>> dateRequests = [];
  int formats = 0;
  bool failBrowser = false, twelveHour = false;
  Completer<Map<String, String>>? delayed;
  @override
  Future<Map<String, String>> formatCalendar(
    List<DateTime> instants,
    List<CalendarDate> dates,
  ) async {
    formats++;
    dateRequests.add(dates.map((d) => '$d').toList());
    if (delayed != null) return delayed!.future;
    return {
      for (final instant in instants)
        '${instant.microsecondsSinceEpoch}': twelveHour ? '12.00 PM' : '12.00',
      for (final date in dates) '$date': '$date',
    };
  }

  @override
  Future<void> openCalendarLink(String url, String kind, int generation) async {
    if (failBrowser) throw StateError('synthetic browser unavailable');
    opened.add((url, kind, generation));
  }
}

CalendarEvent meeting(
  String id,
  DateTime start,
  DateTime end, {
  String calendar = 'work/@example',
  String title = 'Fictional design — 日本語 🧭 Café',
  String status = 'confirmed',
  String response = 'accepted',
  String? url = 'https://meet.google.com/abc-defg-hij',
}) => CalendarEvent(
  id: id,
  calendarId: calendar,
  title: title,
  status: status,
  selfResponse: response,
  startUtc: start,
  endUtc: end,
  meetingUrl: url,
  recurringEventId: 'series',
  originalStart: start.toIso8601String(),
  eventUrl: 'https://calendar.google.com/calendar/event?eid=$id',
);

List<Map> rows(Map<String, Object?> display) =>
    (display['secondarySections'] as List).cast<Map>();
String text(Map<String, Object?> display) => jsonEncode(display);
Map action(Map<String, Object?> display, String label, {String? prefix}) =>
    rows(display)
        .where(
          (r) => prefix == null || (r['title'] as String).startsWith(prefix),
        )
        .expand((r) => (r['actions'] as List).cast<Map>())
        .firstWhere((a) => a['label'] == label);

void main() {
  test(
    'connection and first-load states offer recovery without claiming empty coverage',
    () async {
      final r = await fixtures.rig();
      var settings = 0;
      final platform = RecordingCalendarPlatform();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {
          settings++;
        },
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      for (final status in [
        CalendarConnectionStatus.unconfigured,
        CalendarConnectionStatus.disconnected,
        CalendarConnectionStatus.connecting,
        CalendarConnectionStatus.storageError,
        CalendarConnectionStatus.offline,
      ]) {
        r.connection.status = status;
        agenda.preferencesChanged();
        final display = agenda.display(unlocked: true, tooltipTitles: true);
        expect(
          text(display),
          isNot(contains('No upcoming meetings in the cached week')),
        );
        expect(rows(display).first['actions'], isNotEmpty);
      }
      r.connection.status = CalendarConnectionStatus.connected;
      final waiting = Completer<List<CalendarEvent>>();
      r.provider.onEvents = (_, _) => waiting.future;
      final selecting = r.reader.select({fixtures.work.id});
      await fixtures.settleCalendar();
      var display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(text(display), contains('Loading calendar schedule'));
      expect(
        text(display),
        isNot(contains('No upcoming meetings in the cached week')),
      );
      waiting.complete([]);
      await selecting;
      display = agenda.display(unlocked: true, tooltipTitles: true);
      await agenda.act(
        action(display, 'Calendar settings')['id'] as String,
        agenda.generation,
      );
      expect(settings, 1);
      expect(platform.opened, isEmpty);
    },
  );

  test(
    'account replacement and privacy transitions invalidate old event actions',
    () async {
      final r = await fixtures.rig();
      final now = r.clock.nowUtc();
      r.provider.items[fixtures.work.id] = [
        meeting('same', now, now.add(const Duration(hours: 1))),
      ];
      await r.reader.select({fixtures.work.id});
      final platform = RecordingCalendarPlatform();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      var display = agenda.display(unlocked: true, tooltipTitles: true);
      final oldId = action(display, 'Join', prefix: 'NOW')['id'] as String;
      final oldGeneration = agenda.generation;
      agenda.display(unlocked: false, tooltipTitles: true);
      display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(await agenda.act(oldId, oldGeneration), isFalse);
      final id = action(display, 'Join', prefix: 'NOW')['id'] as String;
      final generation = agenda.generation;
      r.auth.onAuthorize = () async => CalendarAuthorization(
        accountId: 'replacement',
        accessToken: 'synthetic-other',
        refreshToken: 'synthetic-other',
        scopes: calendarReadScopes,
        expiresAt: now.add(const Duration(hours: 1)),
      );
      await r.connection.connect();
      expect(await agenda.act(id, generation), isFalse);
      await fixtures.settleCalendar();
      expect(r.reader.selected, isEmpty);
      expect(platform.opened, isEmpty);
    },
  );

  test(
    'late formatting after disconnect cannot restore event presentation',
    () async {
      final r = await fixtures.rig();
      final now = r.clock.nowUtc();
      r.provider.items[fixtures.work.id] = [
        meeting('late', now, now.add(const Duration(hours: 1))),
      ];
      await r.reader.select({fixtures.work.id});
      final platform = RecordingCalendarPlatform()
        ..delayed = Completer<Map<String, String>>();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await r.connection.disconnect();
      platform.delayed!.complete({'2026-10-25': 'Fictional date'});
      await fixtures.settleCalendar();
      final display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(text(display), isNot(contains('Fictional design')));
      expect(platform.opened, isEmpty);
    },
  );
  test(
    'Now Next boundaries, full tie order and identical source events remain deterministic',
    () {
      final now = DateTime.utc(2026, 10, 25, 12);
      final start = now.subtract(const Duration(minutes: 10));
      final end = now.add(const Duration(minutes: 10));
      final events = [
        meeting('z', start, end, calendar: 'b'),
        meeting('z', start, end, calendar: 'a'),
        meeting('a', start, end, calendar: 'a'),
        meeting('later-start', now, end),
        meeting('earliest-end', start, now.add(const Duration(minutes: 1))),
        meeting('ended', start, now),
        meeting('declined', start, end, response: 'declined'),
        meeting('cancelled', start, end, status: 'cancelled'),
        meeting('next-long', end, end.add(const Duration(hours: 1))),
        meeting('next-short', end, end.add(const Duration(minutes: 1))),
        CalendarEvent(
          id: 'date-only',
          calendarId: 'a',
          title: 'All day',
          status: 'confirmed',
          selfResponse: 'accepted',
          startDate: CalendarDate(2026, 10, 25),
          endDate: CalendarDate(2026, 10, 27),
        ),
      ];
      final chosen = CalendarNowNext(events.reversed, now);
      expect(chosen.active.map((e) => e.id), [
        'earliest-end',
        'a',
        'z',
        'z',
        'later-start',
      ]);
      expect(chosen.active[2].calendarId, 'a');
      expect(chosen.next!.id, 'next-short');
      expect(chosen.nextCount, 2);
      expect(CalendarNowNext(events, end).active.map((e) => e.id), [
        'next-short',
        'next-long',
      ]);
    },
  );

  test('Dart and native consume the same provider URL safety corpus', () {
    for (final text in [
      'javascript:https://meet.google.com/abc-defg-hij',
      '<a href="javascript:https://meet.google.com/abc-defg-hij">Join</a>',
      'file:///https://meet.google.com/abc-defg-hij',
      'custom://https://meet.google.com/abc-defg-hij',
    ]) {
      expect(calendarMeetingFromText(text), isNull);
    }
    for (final line in File(
      'test/fixtures/calendar_links.tsv',
    ).readAsLinesSync().where((s) => s.isNotEmpty)) {
      final parts = line.split('\t');
      expect(
        safeCalendarActionUrl(parts[2], parts[0]) != null,
        parts[1] == '1',
        reason: line,
      );
    }
    for (final bad in [
      'https://meet.google.com/abc-defg-hij\n',
      'https://meet.google.com/abc-defg-hij\u202e',
      'https://zoom.us/j/123\u0000',
    ]) {
      expect(safeCalendarActionUrl(bad, 'join'), isNull);
    }
  });

  test(
    'conference precedence and literal text fallbacks retain no raw content',
    () async {
      for (var level = 0; level < 4; level++) {
        final clock = fixtures.TestCalendarClock();
        final reader = GoogleCalendarReader(
          access: fixtures.TestAccess(),
          clock: clock,
          scheduler: fixtures.TestCalendarScheduler(clock),
          clientFactory: () => MockClient((request) async {
            expect(
              request.url.queryParameters['fields'],
              contains('description'),
            );
            return fixtures.jsonReply({
              'items': [
                {
                  'id': 'fictional',
                  'summary': 'Fictional',
                  'start': {'dateTime': '2026-10-25T12:00:00Z'},
                  'end': {'dateTime': '2026-10-25T13:00:00Z'},
                  'conferenceData': {
                    'entryPoints': [
                      {
                        'entryPointType': 'video',
                        'uri': level == 0
                            ? 'https://meet.google.com/abc-defg-hij'
                            : 'https://meet.google.com.evil.example/abc-defg-hij',
                      },
                    ],
                  },
                  'hangoutLink': level <= 1
                      ? 'https://meet.google.com/xyz-abcd-efg'
                      : null,
                  'location': level <= 2
                      ? 'PRIVATE LOCATION https://company.zoom.us/j/123'
                      : 'PRIVATE LOCATION',
                  'description':
                      '<a href="https://teams.live.com/meet/123?p=test&amp;x=1">PRIVATE DESCRIPTION</a>',
                },
              ],
            });
          }),
        );
        final events = await reader.events(fixtures.work, clock.window());
        expect(
          events.single.meetingUrl,
          [
            'https://meet.google.com/abc-defg-hij',
            'https://meet.google.com/xyz-abcd-efg',
            'https://company.zoom.us/j/123',
            'https://teams.live.com/meet/123?p=test&x=1',
          ][level],
        );
        expect(jsonEncode(events.single.toJson()), isNot(contains('PRIVATE')));
        reader.dispose();
      }
    },
  );

  test(
    'real agenda preserves sources, invitations, full Unicode and multiple explicit actions',
    () async {
      final r = await fixtures.rig();
      final now = r.clock.nowUtc();
      for (final source in [fixtures.work, fixtures.team]) {
        r.provider.items[source.id] = [
          meeting(
            'same',
            now.subtract(const Duration(minutes: 1)),
            now.add(const Duration(minutes: 8)),
            calendar: source.id,
            response: 'tentative',
          ),
        ];
      }
      await r.reader.select({fixtures.work.id, fixtures.team.id});
      final platform = RecordingCalendarPlatform();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      var display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(text(display), contains('日本語 🧭 Café'));
      expect(text(display), contains('Tentative'));
      expect(text(display), contains('2 simultaneous meetings'));
      expect(
        rows(display).where(
          (e) =>
              e['day'] == '2026-10-25' &&
              (e['title'] as String).startsWith('AGENDA'),
        ),
        hasLength(2),
      );
      final join = action(display, 'Join', prefix: 'NOW');
      expect(join['accessibleName'], contains('日本語 🧭 Café'));
      expect(join['id'], isNot(contains('same')));
      expect(platform.opened, isEmpty);
      expect(await agenda.act(join['id'] as String, agenda.generation), isTrue);
      expect(platform.opened.single.$2, 'join');
      final expand = action(display, 'Show all');
      await agenda.act(expand['id'] as String, agenda.generation);
      display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(text(display), contains('ALSO NOW'));
      expect(platform.opened, hasLength(1));
      expect(
        text(agenda.display(unlocked: false, tooltipTitles: true)),
        isNot(contains('日本語')),
      );
      expect(
        await agenda.act(join['id'] as String, agenda.generation),
        isFalse,
      );
      expect(
        agenda.display(unlocked: true, tooltipTitles: false)['calendarTooltip'],
        isNot(contains('日本語')),
      );
    },
  );

  test(
    'verified empty differs from missing coverage, partial failure, stale and reconnect',
    () async {
      final r = await fixtures.rig();
      final platform = RecordingCalendarPlatform();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        contains('No calendars selected'),
      );
      await r.reader.select({fixtures.work.id, fixtures.team.id});
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        contains('No upcoming meetings in the cached week'),
      );
      r.provider.errors[fixtures.team.id] = const CalendarReadFailure(
        CalendarReadFailureKind.network,
      );
      await r.reader.refresh();
      final partial = text(agenda.display(unlocked: true, tooltipTitles: true));
      expect(partial, contains('Some calendars could not be verified'));
      expect(
        partial,
        contains('No saved upcoming meetings; refresh to verify'),
      );
      expect(partial, contains('Google could not be reached'));
      r.connection.requireReconnect();
      await fixtures.settleCalendar();
      final reconnect = text(
        agenda.display(unlocked: true, tooltipTitles: true),
      );
      expect(reconnect, contains('Reconnect Google Calendar'));
      expect(reconnect, contains('unverified'));
      expect(platform.opened, isEmpty);
    },
  );

  test(
    'event boundaries recompute without network and regional preferences reformat independently',
    () async {
      final r = await fixtures.rig();
      final now = r.clock.nowUtc();
      r.provider.items[fixtures.work.id] = [
        meeting(
          'boundary',
          now.add(const Duration(seconds: 10)),
          now.add(const Duration(seconds: 20)),
          response: 'needsAction',
        ),
      ];
      await r.reader.select({fixtures.work.id});
      final platform = RecordingCalendarPlatform();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        contains('NEXT · Fictional'),
      );
      final requests = r.provider.requests.length;
      final formats = platform.formats;
      await r.scheduler.advance(const Duration(seconds: 10));
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        contains('NOW · Fictional'),
      );
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        contains('Response needed'),
      );
      await r.scheduler.advance(const Duration(seconds: 10));
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        contains('No current meeting'),
      );
      expect(r.provider.requests, hasLength(requests));
      expect(platform.formats, formats);
      platform.twelveHour = true;
      agenda.preferencesChanged();
      await fixtures.settleCalendar();
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        contains('12.00 PM'),
      );
      expect(platform.opened, isEmpty);
    },
  );

  test(
    'all-day exclusive dates, DST midnight and timezone changes regroup without shifting dates',
    () async {
      tz_data.initializeTimeZones();
      final r = await fixtures.rig();
      r.clock.location = tz.getLocation('America/New_York');
      r.clock.time = DateTime.utc(2026, 11, 1, 4);
      await r.reader.lifecycleChanged();
      r.provider.items[fixtures.work.id] = [
        CalendarEvent(
          id: 'all-day',
          calendarId: fixtures.work.id,
          title: 'Fictional planning day',
          status: 'confirmed',
          selfResponse: 'accepted',
          startDate: CalendarDate(2026, 11, 1),
          endDate: CalendarDate(2026, 11, 3),
        ),
      ];
      await r.reader.select({fixtures.work.id});
      final platform = RecordingCalendarPlatform();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      var display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(
        rows(display)
            .where((row) => (row['title'] as String).startsWith('ALL DAY'))
            .map((r) => r['day']),
        ['2026-11-01', '2026-11-02'],
      );
      expect(
        r.clock
            .dayWindow(CalendarDate(2026, 11, 1))
            .endUtc
            .difference(r.clock.dayWindow(CalendarDate(2026, 11, 1)).startUtc)
            .inHours,
        25,
      );
      r.clock.time = DateTime.utc(2026, 11, 2, 5);
      r.connection.requireReconnect();
      await fixtures.settleCalendar();
      await r.reader.lifecycleChanged();
      await fixtures.settleCalendar();
      display = agenda.display(unlocked: true, tooltipTitles: true);
      expect((display['calendarDates'] as List).first, '2026-11-02');
      expect(text(display), contains('Partial coverage'));
      expect(text(display), isNot(contains('2026-11-01')));
      r.clock.location = tz.getLocation('Pacific/Honolulu');
      await r.reader.lifecycleChanged();
      await fixtures.settleCalendar();
      expect(
        (agenda.display(unlocked: true, tooltipTitles: true)['calendarDates']
                as List)
            .first,
        '2026-11-01',
      );
      expect(platform.opened, isEmpty);
    },
  );

  test(
    'obsolete, replaced, deselected and disconnected actions never open a browser',
    () async {
      final r = await fixtures.rig();
      final now = r.clock.nowUtc();
      r.provider.items[fixtures.work.id] = [
        meeting('one', now, now.add(const Duration(hours: 1))),
      ];
      await r.reader.select({fixtures.work.id});
      final platform = RecordingCalendarPlatform();
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      var display = agenda.display(unlocked: true, tooltipTitles: true);
      var id = action(display, 'Join', prefix: 'NOW')['id'] as String;
      var generation = agenda.generation;
      r.provider.items[fixtures.work.id] = [
        meeting(
          'one',
          now,
          now.add(const Duration(hours: 1)),
          url: 'https://zoom.us/j/123',
        ),
      ];
      await r.reader.refresh();
      expect(await agenda.act(id, generation), isFalse);
      display = agenda.display(unlocked: true, tooltipTitles: true);
      id = action(display, 'Join', prefix: 'NOW')['id'] as String;
      generation = agenda.generation;
      await r.reader.select({});
      expect(await agenda.act(id, generation), isFalse);
      await r.reader.select({fixtures.work.id});
      display = agenda.display(unlocked: true, tooltipTitles: true);
      id = action(display, 'Join', prefix: 'NOW')['id'] as String;
      generation = agenda.generation;
      final disconnect = r.connection.disconnect();
      expect(await agenda.act(id, generation), isFalse);
      await disconnect;
      expect(platform.opened, isEmpty);
      expect(
        text(agenda.display(unlocked: true, tooltipTitles: true)),
        isNot(contains('Fictional design')),
      );
    },
  );

  test(
    'stale retained content permits explicit safe action and browser failure is recoverable',
    () async {
      final r = await fixtures.rig();
      final now = r.clock.nowUtc();
      r.provider.items[fixtures.work.id] = [
        meeting('one', now, now.add(const Duration(hours: 1)), url: null),
      ];
      await r.reader.select({fixtures.work.id});
      final platform = RecordingCalendarPlatform()..failBrowser = true;
      final agenda = CalendarAgendaController(
        reader: r.reader,
        platform: platform,
        openSettings: () {},
      );
      addTearDown(agenda.dispose);
      await fixtures.settleCalendar();
      r.provider.errors[fixtures.work.id] = const CalendarReadFailure(
        CalendarReadFailureKind.network,
      );
      await r.scheduler.advance(const Duration(minutes: 6));
      var display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(text(display), contains('unverified'));
      expect(
        rows(display)
            .where((e) => (e['title'] as String).startsWith('NOW'))
            .single['actions'],
        hasLength(1),
      );
      var id = action(display, 'Open event', prefix: 'NOW')['id'] as String;
      expect(await agenda.act(id, agenda.generation), isFalse);
      display = agenda.display(unlocked: true, tooltipTitles: true);
      expect(text(display), contains('default browser could not be opened'));
      platform.failBrowser = false;
      id = action(display, 'Open event', prefix: 'NOW')['id'] as String;
      expect(await agenda.act(id, agenda.generation), isTrue);
      expect(platform.opened.single.$2, 'event');
    },
  );

  test(
    'real desktop snapshots, fixture isolation and timer actions retain the sole owner',
    () async {
      final r = await fixtures.rig();
      final now = r.clock.nowUtc();
      r.provider.items[fixtures.work.id] = [
        meeting('one', now, now.add(const Duration(hours: 1))),
      ];
      await r.reader.select({fixtures.work.id});
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final platform = RecordingCalendarPlatform();
      final desktop = DesktopController(
        app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'synthetic',
          version: 'test',
          packaged: false,
          sessionState: 'unlocked',
        ),
        calendarData: r.reader,
        connection: r.connection,
        calendarPlatform: platform,
      );
      await desktop.initialize();
      addTearDown(desktop.dispose);
      addTearDown(app.dispose);
      await fixtures.settleCalendar();
      expect(text(shell.snapshot), contains('Fictional design'));
      desktop.calendar.select(CalendarFixture.longTitles);
      await fixtures.settleCalendar();
      expect(
        (shell.snapshot['secondarySections'] as List).toString(),
        isNot(contains('Fictional action preview')),
      );
      expect(shell.snapshot['calendarPreview'], isNotNull);
      final previewGeneration = desktop.calendar.generation;
      await shell.send('calendarAction', {
        'preview': true,
        'actionId': 'join:review',
        'generation': previewGeneration,
      });
      expect(platform.opened, isEmpty);
      await shell.send('timer', {
        'action': 'start',
        'runId': app.timer.runId,
        'revision': app.timer.revision,
      });
      expect(platform.opened, isEmpty);
      await shell.send('sessionState', {'state': 'unknown'});
      await fixtures.settleCalendar();
      expect(shell.snapshot['secondarySections'], isEmpty);
      expect(shell.snapshot['calendarTooltip'], '');
    },
  );
}
