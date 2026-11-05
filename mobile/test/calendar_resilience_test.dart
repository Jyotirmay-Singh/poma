import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_agenda_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_read_controller.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/application/calendar_reminder_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/data/google_calendar_reader.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/calendar_reminders.dart';
import 'package:poma/domain/models.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'calendar_agenda_test.dart' as agenda;
import 'calendar_connection_test.dart' as auth;
import 'calendar_read_test.dart' as f;
import 'calendar_reminder_test.dart' as reminders;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

class _HeldCredentials extends auth.MemoryCredentials {
  final restored = Completer<CalendarStoredConnection>();
  @override
  Future<CalendarStoredConnection> read() => restored.future;
}

/// Mirrors the native store's lease check after an asynchronous write boundary.
class _LeasedReminders extends reminders.ReminderAdapter {
  _LeasedReminders(this.cache);
  final f.MemoryCalendarCache cache;
  @override
  Future<void> write(
    CalendarCacheLease lease,
    Map<String, Object?> document,
  ) async {
    await gate?.future;
    cache.check(lease);
    await super.write(lease, document);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz_data.initializeTimeZones);

  test(
    'failed calendar reset cleanup reports remaining local data and retries',
    () async {
      final r = await f.rig();
      await r.reader.select({f.work.id});
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
        resetParticipant: r.connection,
      );
      addTearDown(app.dispose);
      app.addTask('Disposable reset fixture');
      await app.flush();
      r.credentials.failClear = true;
      expect(await app.deleteAllLocalData(), isFalse);
      expect(app.cleanupPending, isTrue);
      expect(r.connection.operationsEnabled, isFalse);
      expect(r.connection.canConnect, isFalse);
      expect(app.deletionError, contains('remaining local data'));
      await app.retrySave();
      expect(app.cleanupPending, isTrue);
      expect(app.deletionError, contains('remaining local data'));
      r.credentials.failClear = false;
      await app.retrySave();
      await f.settleCalendar();
      expect(app.cleanupPending, isFalse);
      expect(app.deletionError, isNull);
      expect(r.credentials.value, isNull);
      expect(r.cache.accounts, isEmpty);
      expect(app.tasks, isEmpty);
    },
  );

  test(
    'pending or failed calendar restore leaves the offline application usable',
    () async {
      final store = _HeldCredentials();
      final connection = CalendarConnectionController(
        configuration: auth.configured,
        authorization: auth.FakeAuthorization(),
        store: store,
      );
      final timerClock = FakeClock();
      final repository = MemoryRepository();
      final app = await AppController.create(repository, clock: timerClock);
      final shell = FakeShell();
      final desktop = DesktopController(
        app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'synthetic',
          version: 'test',
          packaged: false,
          visible: false,
        ),
        connection: connection,
      );
      addTearDown(() {
        desktop.dispose();
        app.dispose();
      });
      await desktop.initialize().timeout(const Duration(seconds: 1));
      expect(connection.status, CalendarConnectionStatus.restoring);
      app.addTask('Offline task');
      await app.updateSettings(app.settings.copyWith(focusMinutes: 1));
      await app.flush();
      await app.toggleTimer();
      final run = app.timer.runId;
      timerClock.advance(const Duration(minutes: 1));
      await shell.send('deadline', {'runId': run});
      await shell.send('deadline', {'runId': run});
      await app.loadHistory();
      expect(app.tasks.single.title, 'Offline task');
      expect(repository.state.sessions.single.id, run);
      expect(app.timer.status, RunStatus.ready);
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.tickerActive, isFalse);
      store.restored.completeError(
        StateError('synthetic-private-storage-detail'),
      );
      await connection.initialize();
      expect(connection.status, CalendarConnectionStatus.storageError);
      expect(connection.message, isNot(contains('synthetic-private')));
      app.addTask('Still available');
      await app.flush();
      expect(repository.state.tasks, hasLength(2));
    },
  );

  for (final boundary in ['disconnect', 'reset', 'replace']) {
    test(
      '$boundary rejects late events, formatting and reminder receipts',
      () async {
        final r = await f.rig();
        final now = r.clock.nowUtc();
        r.provider.items[f.work.id] = [
          agenda.meeting(
            'held-occurrence',
            now.add(const Duration(minutes: 6)),
            now.add(const Duration(minutes: 36)),
            title: 'Synthetic private occurrence',
          ),
        ];
        await r.reader.select({f.work.id});
        final platform = agenda.RecordingCalendarPlatform();
        final presentation = CalendarAgendaController(
          reader: r.reader,
          platform: platform,
          openSettings: () {},
        );
        final adapter = _LeasedReminders(r.cache);
        final purge = r.credentials.onPurge!;
        r.credentials.onPurge = () {
          purge();
          adapter.documents.clear();
        };
        final reminder = CalendarReminderController(
          reader: r.reader,
          store: adapter,
          platform: adapter,
          openAgenda: () async => fail('Obsolete action opened the agenda'),
        )..unlocked = true;
        addTearDown(() {
          presentation.dispose();
          reminder.dispose();
        });
        await reminders.drain(reminder);
        await reminder.update(
          const CalendarReminderPreferences(
            enabled: true,
            calendars: {'work/@example'},
          ),
        );
        await reminders.drain(reminder);
        final oldAccount = r.reader.accountKey;
        final oldGeneration = adapter.generation;
        final oldTokens = Set<String>.of(adapter.tokens);
        r.clock.time = adapter.armed!;
        adapter.gate = Completer<void>();
        final due = reminder.deadline(oldGeneration);
        await f.settleCalendar();
        final events = Completer<List<CalendarEvent>>();
        r.provider.onEvents = (_, _) => events.future;
        final reading = r.reader.refresh();
        await f.settleCalendar();
        platform.delayed = Completer<Map<String, String>>();
        presentation.preferencesChanged();
        await f.settleCalendar();

        final repository = MemoryRepository();
        final app = await AppController.create(
          repository,
          clock: FakeClock(),
          resetParticipant: r.connection,
        );
        addTearDown(app.dispose);
        app.addTask('Preserved unless full reset');
        await app.flush();
        if (boundary == 'reset') {
          expect(await app.deleteAllLocalData(), isTrue);
        } else if (boundary == 'replace') {
          r.auth.onAuthorize = () async => CalendarAuthorization(
            accountId: 'replacement',
            accessToken: 'synthetic-new-access',
            refreshToken: 'synthetic-new-refresh',
            scopes: calendarReadScopes,
            expiresAt: now.add(const Duration(hours: 1)),
          );
          await r.connection.connect();
        } else {
          await r.connection.disconnect();
        }
        await f.settleCalendar();
        events.complete(r.provider.items[f.work.id]!);
        adapter.gate!.complete();
        platform.delayed!.complete({});
        await reading;
        await due;
        await reminders.drain(reminder);
        await f.settleCalendar();
        expect(r.cache.accounts.containsKey(oldAccount), isFalse);
        expect(adapter.documents.containsKey(oldAccount), isFalse);
        expect(r.reader.events, isEmpty);
        expect(adapter.shown, isEmpty);
        expect(adapter.armed, isNull);
        expect(adapter.tokens.intersection(oldTokens), isEmpty);
        expect(platform.opened, isEmpty);
        expect(
          jsonEncode(presentation.display(unlocked: true, tooltipTitles: true)),
          isNot(contains('Synthetic private occurrence')),
        );
        expect(app.tasks.length, boundary == 'reset' ? 0 : 1);
        expect(r.credentials.value == null, boundary != 'replace');
        expect(r.provider.cancellations, greaterThan(0));
      },
    );

    test(
      '$boundary rejects a queued snapshot write after its lease is cleared',
      () async {
        final r = await f.rig();
        await r.reader.select({f.work.id});
        final key = r.reader.accountKey;
        final gate = Completer<void>();
        r.cache.nextWrite = gate;
        final writing = r.reader.refresh();
        await f.settleCalendar();
        if (boundary == 'reset') {
          r.connection.invalidateForReset();
          await r.connection.clearForReset();
        } else if (boundary == 'replace') {
          r.auth.onAuthorize = () async => CalendarAuthorization(
            accountId: 'replacement',
            accessToken: 'synthetic-new-access',
            refreshToken: 'synthetic-new-refresh',
            scopes: calendarReadScopes,
            expiresAt: r.clock.nowUtc().add(const Duration(hours: 1)),
          );
          await r.connection.connect();
        } else {
          await r.connection.disconnect();
        }
        gate.complete();
        await writing;
        await f.settleCalendar();
        expect(r.cache.accounts.containsKey(key), isFalse);
        expect(r.reader.snapshots, isEmpty);
      },
    );
  }

  test(
    'real paginated adapter preserves prior source on partial failure and never writes events',
    () async {
      final clock = f.TestCalendarClock();
      final scheduler = f.TestCalendarScheduler(clock);
      final credentials = auth.MemoryCredentials();
      final connection = CalendarConnectionController(
        configuration: auth.configured,
        authorization: auth.FakeAuthorization(),
        store: credentials,
        now: clock.nowUtc,
      );
      await connection.initialize();
      await connection.connect();
      final cache = f.MemoryCalendarCache()
        ..revision = () => credentials.revision;
      final requests = <http.Request>[];
      var mode = 'initial';
      final provider = GoogleCalendarReader(
        access: connection,
        clock: clock,
        scheduler: scheduler,
        clientFactory: () => MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('calendarList')) {
            return f.jsonReply({
              'items': [
                for (final id in ['work', 'team'])
                  {
                    'id': id,
                    'summary': id,
                    'accessRole': 'reader',
                    'timeZone': 'UTC',
                  },
              ],
            });
          }
          final work = request.url.pathSegments.contains('work');
          if (mode == 'partial' &&
              work &&
              request.url.queryParameters['pageToken'] == 'second') {
            return f.jsonReply({
              'error': {'message': 'synthetic-private-body'},
            }, 403);
          }
          return f.jsonReply({
            if (mode == 'partial' && work) 'nextPageToken': 'second',
            'items': mode == 'deleted'
                ? []
                : [
                    {
                      'id': mode == 'initial' ? 'original' : 'moved-instance',
                      'summary': 'Synthetic',
                      'recurringEventId': 'series',
                      'originalStartTime': {'dateTime': '2026-10-25T13:00:00Z'},
                      'start': {'dateTime': '2026-10-25T14:00:00Z'},
                      'end': {'dateTime': '2026-10-25T15:00:00Z'},
                    },
                  ],
          });
        }),
      );
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
      await f.settleCalendar();
      await reader.select({'work', 'team'});
      final original = reader.snapshots['work']!;
      mode = 'partial';
      await reader.refresh();
      expect(reader.snapshots['work']!.toJson(), original.toJson());
      expect(reader.snapshots['team']!.events.single.id, 'moved-instance');
      expect(
        reader.sourceFailures['work']!.kind,
        CalendarReadFailureKind.forbidden,
      );
      expect(
        '${reader.sourceFailures['work']}',
        isNot(contains('private-body')),
      );
      mode = 'moved';
      await reader.refresh(manual: true);
      expect(reader.snapshots['work']!.events.single.id, 'moved-instance');
      expect(
        reader.snapshots['work']!.events.single.originalStart,
        '2026-10-25T13:00:00Z',
      );
      mode = 'deleted';
      await reader.refresh();
      expect(reader.events, isEmpty);
      expect(requests.every((r) => r.method == 'GET'), isTrue);
      expect(requests.every((r) => r.url.host == 'www.googleapis.com'), isTrue);
    },
  );

  test(
    'HTTP-date Retry-After survives manual retries and cancellation',
    () async {
      final clock = f.TestCalendarClock();
      final scheduler = f.TestCalendarScheduler(clock);
      var requests = 0;
      final reader = GoogleCalendarReader(
        access: f.TestAccess(),
        clock: clock,
        scheduler: scheduler,
        jitter: () => 0,
        clientFactory: () => MockClient((_) async {
          requests++;
          return f.jsonReply({}, 429, {
            'retry-after': HttpDate.format(
              clock.nowUtc().add(const Duration(minutes: 2)),
            ),
          });
        }),
      );
      final pending = expectLater(
        reader.calendars(),
        throwsA(
          isA<CalendarReadFailure>().having(
            (e) => e.kind,
            'cancelled',
            CalendarReadFailureKind.cancelled,
          ),
        ),
      );
      await f.settleCalendar();
      await scheduler.advance(const Duration(seconds: 119));
      expect(requests, 1);
      await expectLater(
        reader.calendars(),
        throwsA(isA<CalendarReadFailure>()),
      );
      expect(requests, 1);
      reader.dispose();
      await pending;
      await scheduler.advance(const Duration(minutes: 5));
      expect(requests, 1);
    },
  );
}
