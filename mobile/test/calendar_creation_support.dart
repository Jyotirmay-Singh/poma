// Fictional Google transport and isolated local files only.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_event_creation_controller.dart';
import 'package:poma/application/calendar_event_creation_ports.dart';
import 'package:poma/application/calendar_read_controller.dart';
import 'package:poma/application/calendar_agenda_controller.dart';
import 'package:poma/application/day_clock_controller.dart';
import 'package:poma/application/focus_block_ports.dart';
import 'package:poma/data/google_calendar_reader.dart';
import 'package:poma/data/google_calendar_event_writer.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/calendar_event_creation.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:poma/domain/focus_blocks.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'calendar_connection_test.dart' as f;
import 'calendar_write_consent_test.dart' show AtomicMemory;
import 'calendar_read_test.dart' as reads;
import 'calendar_agenda_test.dart' show RecordingCalendarPlatform;

const creationGeneration = '12345678-1234-4234-8234-123456789abc';

class CreationRegionalPlatform extends RecordingCalendarPlatform {
  @override
  Future<Map<String, String>> formatCalendar(
    List<DateTime> instants,
    List<CalendarDate> dates,
  ) async => {
    for (final t in instants)
      '${t.microsecondsSinceEpoch}': DateFormat(
        'h:mm a',
      ).format(tz.TZDateTime.from(t, tz.getLocation('Asia/Kolkata'))),
    for (final d in dates) '$d': '$d',
  };
}

class CreationMemory implements CalendarCreationStore {
  CreationMemory({this.directory});
  final Directory? directory;
  String? document;
  bool disabled = false, failSave = false, lostAck = false, failStop = false;
  bool failOpen = false;
  int generation = 0, revision = 0, saves = 0;
  String? account;
  Completer<void>? saveGate;
  void Function(String)? onSaved;
  @override
  Future<StoredCreationJournal> open(String key) async {
    if (failOpen) throw StateError('Synthetic unreadable acknowledgement.');
    account = key;
    generation++;
    revision = 0;
    if (directory != null) {
      final file = File('${directory!.path}/journal.json');
      document = file.existsSync() ? file.readAsStringSync() : null;
      disabled = File('${directory!.path}/disabled').existsSync();
    }
    return StoredCreationJournal(
      CreationStoreLease(key, generation, revision),
      document,
      disabled: disabled,
    );
  }

  @override
  Future<CreationStoreLease> save(
    CreationStoreLease lease,
    String value,
  ) async {
    saves++;
    await saveGate?.future;
    if (failSave ||
        lease.generation != generation ||
        lease.revision != revision ||
        lease.accountKey != account) {
      throw StateError('Synthetic storage failure.');
    }
    if (directory != null) {
      final tmp = File('${directory!.path}/journal.tmp');
      tmp.writeAsStringSync(value, flush: true);
      tmp.renameSync('${directory!.path}/journal.json');
    }
    document = value;
    revision++;
    onSaved?.call(value);
    if (lostAck) throw StateError('Synthetic lost acknowledgement.');
    return CreationStoreLease(account!, generation, revision);
  }

  @override
  Future<void> stop({bool purge = false}) async {
    generation++;
    account = null;
    if (failStop) throw StateError('Synthetic cleanup failure.');
    if (purge) {
      document = null;
      final file = directory == null
          ? null
          : File('${directory!.path}/journal.json');
      if (file?.existsSync() == true) file!.deleteSync();
    }
  }

  @override
  Future<void> setDisabled(bool value) async {
    generation++;
    account = null;
    disabled = value;
    if (directory != null) {
      final file = File('${directory!.path}/disabled');
      if (value) {
        file.writeAsStringSync('disabled', flush: true);
      } else if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }
}

class CreationTimes implements FocusTimeResolver {
  String zoneFingerprint = 'synthetic-IST';
  bool reject = false;
  @override
  Future<String> fingerprint() async => zoneFingerprint;
  @override
  Future<FocusTimeResolution> resolve(DateTime wall) async {
    if (reject) throw StateError('Synthetic invalid local time.');
    return FocusTimeResolution(
      utc: DateTime.utc(
        wall.year,
        wall.month,
        wall.day,
        wall.hour,
        wall.minute,
      ).subtract(const Duration(minutes: 330)),
      offsetMinutes: 330,
      zone: 'India Standard Time',
      fingerprint: zoneFingerprint,
    );
  }
}

class CreationGoogle {
  CreationGoogle({this.directory});
  final Directory? directory;
  final Map<String, Map<String, dynamic>> events = {};
  int inserts = 0, gets = 0, lists = 0;
  bool loseResponse = false, omitCommit = false, failList = false, deny = false;
  bool destinationOwned = true;
  bool destinationMissing = false;
  bool gone = false;
  Completer<void>? postGate, listGate, getGate;
  void Function()? afterCommit;
  void Function()? onValidate;
  final List<http.Request> requests = [];
  http.Client client() => MockClient(send);
  http.Response reply(Object value, [int status = 200]) => http.Response(
    jsonEncode(value),
    status,
    headers: {'content-type': 'application/json'},
  );
  Future<http.Response> send(http.Request request) async {
    requests.add(request);
    final parts = request.url.pathSegments;
    if (request.url.path.endsWith('/colors')) {
      return reply({
        'event': {
          '2': {'background': '#33B679', 'foreground': '#000000'},
          '5': {'background': '#F6BF26', 'foreground': '#000000'},
        },
      });
    }
    if (request.url.path.endsWith('/calendarList')) {
      return reply({
        'items': [
          {
            'id': 'synthetic-primary',
            'summary': 'Personal',
            'primary': true,
            'accessRole': 'owner',
            'timeZone': 'Asia/Kolkata',
            'backgroundColor': '#123456',
          },
          {
            'id': 'owned-secondary',
            'summary': 'Planning',
            'accessRole': 'owner',
            'timeZone': 'Asia/Kolkata',
          },
          {
            'id': 'shared',
            'summary': 'Shared',
            'accessRole': 'writer',
            'timeZone': 'Asia/Kolkata',
          },
        ],
      });
    }
    if (parts.contains('calendarList')) {
      onValidate?.call();
      if (destinationMissing) return reply({}, 404);
      return reply({
        'id': parts.last,
        'primary': parts.last == 'synthetic-primary',
        'accessRole': destinationOwned && parts.last != 'shared'
            ? 'owner'
            : 'writer',
      });
    }
    final calendar = parts[3];
    if (request.method == 'POST') {
      inserts++;
      await postGate?.future;
      if (deny) return reply({}, 403);
      final m = jsonDecode(request.body) as Map<String, dynamic>;
      final id = m['id'] as String;
      if (events.containsKey(id)) return reply({}, 409);
      if (!omitCommit) {
        events[id] = {
          ...m,
          'calendarId': calendar,
          'status': 'confirmed',
          'htmlLink': 'https://calendar.google.com/calendar/event?eid=$id',
        };
        if (directory != null) {
          File(
            '${directory!.path}/server.json',
          ).writeAsStringSync(jsonEncode(events), flush: true);
        }
        afterCommit?.call();
      }
      if (loseResponse || omitCommit) {
        throw TimeoutException('Synthetic response loss.');
      }
      return reply(events[id]!, 201);
    }
    if (parts.last == 'events') {
      lists++;
      final gate = listGate;
      listGate = null;
      final snapshot = events.values
          .where((e) => e['calendarId'] == calendar)
          .toList();
      await gate?.future;
      if (failList) return reply({}, 403);
      return reply({'items': snapshot});
    }
    gets++;
    await getGate?.future;
    if (gone) return reply({}, 410);
    final event = events[parts.last];
    return event == null ? reply({}, 404) : reply(event);
  }
}

class CreationRig {
  CreationRig(
    this.connection,
    this.reader,
    this.controller,
    this.writer,
    this.store,
    this.google,
    this.clock,
    this.scheduler,
    this.times,
    this.disk,
    this.auth,
    this.agenda,
    this.day,
  );
  final CalendarConnectionController connection;
  final CalendarReadController reader;
  final CalendarCreationController controller;
  final GoogleCalendarEventWriter writer;
  final CreationMemory store;
  final CreationGoogle google;
  final reads.TestCalendarClock clock;
  final reads.TestCalendarScheduler scheduler;
  final CreationTimes times;
  final AtomicMemory disk;
  final f.FakeAuthorization auth;
  final CalendarAgendaController agenda;
  final DayClockController day;
  CalendarEventDraft draft({String calendar = 'synthetic-primary'}) =>
      CalendarEventDraft(
        accountKey: connection.verifiedAccountKey,
        title: 'Evening planning',
        startDate: '2026-11-10',
        endDate: '2026-11-10',
        startTime: '10:00',
        endTime: '11:00',
        startPm: true,
        endPm: true,
        calendarId: calendar,
        colorId: '2',
      );
  CalendarCreateIntent intent(CalendarEventDraft d) => CalendarCreateIntent(
    accountKey: d.accountKey!,
    calendarId: d.calendarId!,
    title: d.title,
    startUtc: DateTime.utc(2026, 11, 10, 16, 30),
    endUtc: DateTime.utc(2026, 11, 10, 17, 30),
    zone: 'India Standard Time',
    zoneFingerprint: times.zoneFingerprint,
    startOffset: 330,
    endOffset: 330,
    busy: d.busy,
    colorId: d.colorId,
  );
  void dispose() {
    day.dispose();
    controller.dispose();
    agenda.dispose();
    reader.dispose();
    connection.dispose();
  }
}

Future<CreationRig> creationRig({
  CreationMemory? store,
  CreationGoogle? google,
  bool focus = false,
  bool creation = true,
  GoogleCalendarAuthorization? writeAuthorization,
}) async {
  tz_data.initializeTimeZones();
  final clock = reads.TestCalendarClock(
    time: DateTime.utc(2026, 11, 9, 12),
    location: 'Asia/Kolkata',
  );
  final disk = AtomicMemory()
    ..value = CalendarCredential(
      clientId: f.configured.clientId,
      accountId: 'synthetic-primary',
      refreshToken: 'synthetic-refresh',
      scopes: {
        ...calendarReadScopes,
        if (focus) focusWriteScope,
        if (creation) calendarCreationScope,
      },
      focusReceipt: focus
          ? const CalendarWriteReceipt(
              generation: creationGeneration,
              enabled: true,
            )
          : null,
      creationReceipt: creation
          ? const CalendarWriteReceipt(
              generation: creationGeneration,
              enabled: true,
            )
          : null,
    );
  final auth = f.FakeAuthorization()
    ..onRefresh = () async => CalendarAuthorization(
      accountId: 'synthetic-primary',
      accessToken: 'synthetic-access',
      scopes: disk.value!.scopes,
      expiresAt: clock.time.add(const Duration(days: 2)),
    );
  final connection = CalendarConnectionController(
    configuration: f.configured,
    authorization: auth,
    writeAuthorization: writeAuthorization,
    store: disk,
    now: clock.nowUtc,
  );
  await connection.initialize();
  final server = google ?? CreationGoogle(),
      storage = store ?? CreationMemory();
  final scheduler = reads.TestCalendarScheduler(clock);
  final reader = CalendarReadController(
    connection: connection,
    provider: GoogleCalendarReader(
      access: connection,
      clock: clock,
      scheduler: scheduler,
      clientFactory: server.client,
    ),
    cache: reads.MemoryCalendarCache()..revision = () => disk.revision,
    clock: clock,
    scheduler: scheduler,
  )..initialize();
  await reads.settleCalendar();
  await reader.select({'synthetic-primary'});
  final times = CreationTimes();
  final writer = GoogleCalendarEventWriter(
    connection,
    clientFactory: server.client,
    now: clock.nowUtc,
  );
  final controller = CalendarCreationController(
    connection: connection,
    reader: reader,
    store: storage,
    writer: writer,
    time: times,
  )..setUnlocked(true);
  writer.mutationAllowed = () => controller.ready && controller.busy;
  writer.verifyTime = controller.verifyTime;
  await controller.initialize();
  final agenda = CalendarAgendaController(
    reader: reader,
    platform: CreationRegionalPlatform(),
    openSettings: () {},
  );
  final day = DayClockController(
    reader: reader,
    agenda: agenda,
    time: times,
    unlocked: true,
    localize: (t) => tz.TZDateTime.from(t, clock.location),
  )..attachCreation(controller);
  day.browse(CalendarDate(2026, 11, 10), DayClockHalf.pm);
  return CreationRig(
    connection,
    reader,
    controller,
    writer,
    storage,
    server,
    clock,
    scheduler,
    times,
    disk,
    auth,
    agenda,
    day,
  );
}
