import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/focus_block_controller.dart';
import 'package:poma/application/focus_block_ports.dart';
import 'package:poma/domain/focus_blocks.dart';

final instant = DateTime.utc(2026, 11, 3, 10);
const account =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const block = '12345678-1234-4234-8234-123456789abc';
FocusPayload payload({String title = 'Outline proposal', int minutes = 30}) =>
    FocusPayload(
      title: title,
      start: instant.add(Duration(minutes: minutes)),
      end: instant.add(Duration(minutes: minutes + 25)),
      zone: 'Test zone',
      zoneFingerprint: 'zone-v1',
      startOffsetMinutes: 330,
      endOffsetMinutes: 330,
    );
FocusBlockDraft draft({String id = block, FocusPayload? value}) =>
    FocusBlockDraft(
      id: id,
      payload: value ?? payload(),
      taskId: 'local-only-task',
    );
FocusCalendarBinding binding({
  String id = 'poma-calendar',
  String key = '12345678-1234-4234-8234-111111111111',
}) => FocusCalendarBinding(
  accountKey: account,
  clientId: 'desktop-client',
  id: id,
  calendarKey: key,
  provisioningId: '12345678-1234-4234-8234-222222222222',
  name: 'Poma Focus',
);

class WriteSession extends ChangeNotifier implements FocusWriteSession {
  @override
  String? verifiedAccountKey = account;
  @override
  String focusClientId = 'desktop-client';
  @override
  String? credentialGeneration = 'credential-1';
  @override
  bool focusWriteEnabled = true;
  @override
  bool focusOnline = true;
  @override
  CalendarWriteCapability writeCapability = CalendarWriteCapability.ready;
  void change() {
    notifyListeners();
  }
}

class JournalStore implements FocusBlockOperationStore {
  JournalStore(this.directory);
  final Directory directory;
  int generation = 0, revision = 0;
  bool failSave = false, failAck = false, failBound = false;
  Completer<void>? gate;
  File get file => File('${directory.path}/journal.json');
  @override
  Future<FocusStoredJournal> open(String key) async => FocusStoredJournal(
    FocusStoreLease(key, generation, revision),
    file.existsSync() ? file.readAsStringSync() : null,
    stopped: File('${directory.path}/stopped').existsSync(),
  );
  @override
  Future<FocusStoreLease> save(FocusStoreLease lease, String document) async {
    await gate?.future;
    if (failBound && document.contains('"provisioningState":"bound"') ||
        failSave ||
        lease.generation != generation ||
        lease.revision != revision ||
        failAck && document.contains('"status":"saved"')) {
      throw const FocusFailure(FocusFailureKind.storage);
    }
    final temporary = File('${file.path}.tmp');
    temporary.writeAsStringSync(document, flush: true);
    if (file.existsSync()) file.deleteSync();
    temporary.renameSync(file.path);
    revision++;
    return FocusStoreLease(lease.accountKey, generation, revision);
  }

  @override
  Future<void> stop({bool purge = false}) async {
    generation++;
    File('${directory.path}/stopped').writeAsStringSync('1', flush: true);
    if (purge && file.existsSync()) file.deleteSync();
  }
}

class Times implements FocusTimeResolver {
  String zone = 'zone-v1';
  bool invalid = false;
  @override
  Future<String> fingerprint() async => zone;
  @override
  Future<FocusTimeResolution> resolve(DateTime wall) async {
    if (invalid) throw const FocusFailure(FocusFailureKind.invalidTime);
    return FocusTimeResolution(
      utc: wall.toUtc().subtract(const Duration(minutes: 330)),
      offsetMinutes: 330,
      zone: 'Test zone',
      fingerprint: zone,
    );
  }
}

class GoogleStore implements FocusBlockWriter {
  void Function()? beforeCreate;
  final Map<String, FocusRemoteBlock> events = {};
  final List<FocusCalendarBinding> calendars = [];
  int inserts = 0, patches = 0, deletes = 0, gets = 0, calendarInserts = 0;
  bool lostResponse = false,
      lostCalendar = false,
      denied = false,
      inaccessible = false,
      partialList = false,
      precondition = false;
  Completer<void>? responseGate;
  int serial = 0;
  @override
  Future<List<FocusCalendarBinding>> discover(String key, String client) async {
    if (partialList) throw const FocusFailure(FocusFailureKind.network);
    return [...calendars];
  }

  @override
  Future<FocusCalendarBinding> provision(FocusCalendarBinding intent) async {
    calendarInserts++;
    final result = FocusCalendarBinding(
      accountKey: intent.accountKey,
      clientId: intent.clientId,
      id: 'poma-calendar',
      calendarKey: intent.calendarKey,
      provisioningId: intent.provisioningId,
      name: 'Poma Focus',
    );
    calendars.add(result);
    if (lostCalendar) throw const FocusFailure(FocusFailureKind.network);
    return result;
  }

  @override
  Future<FocusCalendarBinding> validate(FocusCalendarBinding b) async {
    if (denied) throw const FocusFailure(FocusFailureKind.permission);
    if (inaccessible ||
        b.id == 'primary' ||
        b.clientId != 'desktop-client' ||
        b.accountKey != account) {
      throw const FocusFailure(FocusFailureKind.missing);
    }
    return b;
  }

  @override
  Future<FocusRemoteBlock?> get(FocusCalendarBinding b, String id) async {
    gets++;
    await validate(b);
    return events[id];
  }

  FocusRemoteBlock resource(
    FocusCalendarBinding b,
    FocusBlockOperation op, {
    Map<String, dynamic>? prior,
  }) => FocusRemoteBlock({
    ...?prior,
    ...op.payload.fields,
    'id': op.eventId,
    'etag': '"${++serial}"',
    'eventType': 'default',
    'visibility': 'private',
    'reminders': {'useDefault': false, 'overrides': []},
    'extendedProperties': {
      'private': {
        ...?((prior?['extendedProperties'] as Map?)?['private'] as Map?),
        ...op.markers,
        'pomaCalendarKey': b.calendarKey,
      },
    },
  });
  @override
  Future<FocusRemoteBlock> create(
    FocusCalendarBinding b,
    FocusBlockOperation op,
  ) async {
    beforeCreate?.call();
    inserts++;
    await validate(b);
    if (events.containsKey(op.eventId)) {
      throw const FocusFailure(FocusFailureKind.conflict);
    }
    final result = resource(b, op);
    events[op.eventId] = result;
    await responseGate?.future;
    if (lostResponse) throw const FocusFailure(FocusFailureKind.network);
    return result;
  }

  @override
  Future<FocusRemoteBlock> edit(
    FocusCalendarBinding b,
    FocusBlockOperation op,
    FocusRemoteBlock current,
  ) async {
    patches++;
    await validate(b);
    if (precondition || events[op.eventId]?.etag != op.etag) {
      throw const FocusFailure(FocusFailureKind.precondition);
    }
    final result = resource(b, op, prior: current.value);
    events[op.eventId] = result;
    if (lostResponse) throw const FocusFailure(FocusFailureKind.network);
    return result;
  }

  @override
  Future<void> delete(FocusCalendarBinding b, FocusBlockOperation op) async {
    deletes++;
    await validate(b);
    if (precondition || events[op.eventId]?.etag != op.etag) {
      throw const FocusFailure(FocusFailureKind.precondition);
    }
    events.remove(op.eventId);
    if (lostResponse) throw const FocusFailure(FocusFailureKind.network);
  }

  @override
  Future<List<FocusRemoteBlock>> recover(
    FocusCalendarBinding b,
    DateTime start,
    DateTime end,
  ) async {
    await validate(b);
    if (partialList) throw const FocusFailure(FocusFailureKind.network);
    return events.values.toList();
  }

  @override
  void cancel() {}
}

void main() {
  late Directory dir;
  late JournalStore disk;
  late WriteSession session;
  late Times times;
  late GoogleStore google;
  late FocusBlockController c;
  late DateTime now;
  FocusBlockController make() => FocusBlockController(
    session: session,
    store: disk,
    writer: google,
    time: times,
    now: () => now,
  );
  Future<void> ready() async {
    await c.initialize();
    await c.bind(binding());
  }

  Future<void> create() async {
    await c.confirm(await c.preview(draft()));
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('poma-focus-');
    disk = JournalStore(dir);
    session = WriteSession();
    times = Times();
    google = GoogleStore();
    now = instant;
    c = make();
  });
  tearDown(() {
    c.dispose();
    dir.deleteSync(recursive: true);
  });
  test('W10 expired at transmission remains visibly Expired', () async {
    await ready();
    final p = await c.preview(draft());
    google.beforeCreate = () {
      now = instant.add(const Duration(hours: 1));
      throw const FocusFailure(FocusFailureKind.invalidTime);
    };
    await c.confirm(p);
    expect(google.inserts, 0);
    expect(c.journal!.operations[block]!.status, FocusOperationStatus.expired);
  });
  test(
    'W09 acknowledged block later missing cannot become a create retry',
    () async {
      await ready();
      await create();
      google.events.clear();
      await c.reconcile(block);
      expect(c.journal!.operations[block]!.error, 'deleted');
      expect(c.journal!.blocks, isEmpty);
      await expectLater(c.retry(block), throwsA(isA<FocusFailure>()));
      expect(google.inserts, 1);
    },
  );
  test('Google-compatible identity and exact Unicode canonical payload', () {
    expect(focusEventId(block), 'poma12345678123442348234123456789abc');
    expect(payload(title: 'A😀é').hash, payload(title: 'A😀é').hash);
    expect(payload(title: 'é').hash, isNot(payload(title: 'é').hash));
    expect(() => payload(title: '  '), throwsFormatException);
  });
  test(
    'W01 separately confirmed identical payloads are distinct intents',
    () async {
      await ready();
      final a = await c.preview(draft());
      final b = await c.preview(draft(id: focusUuid()));
      await Future.wait([c.confirm(a), c.confirm(b)]);
      expect(google.events.length, 2);
      expect(c.journal!.operations.length, 2);
    },
  );
  test(
    'W05 binding acknowledgement failure recovers without calendar reinsert',
    () async {
      await c.initialize();
      disk.failBound = true;
      await c.createCalendar();
      expect(google.calendarInserts, 1);
      c.dispose();
      disk = JournalStore(dir);
      c = make();
      await c.initialize();
      await c.createCalendar();
      expect(google.calendarInserts, 1);
      expect(c.journal!.binding, isNotNull);
    },
  );
  test(
    'W08 provider precondition rejection preserves remote version',
    () async {
      await ready();
      await create();
      final before = google.events.values.single;
      final p = await c.preview(
        draft(
          id: focusUuid(),
          value: payload(title: 'Local edit'),
        ),
        kind: FocusOperationKind.edit,
        before: before,
      );
      google.precondition = true;
      await c.confirm(p);
      expect(google.patches, 1);
      expect(google.events.values.single.title, before.title);
      expect(
        c.journal!.operations.values.last.status,
        FocusOperationStatus.failed,
      );
    },
  );
  test('W09 minimal tombstone is never resurrected', () async {
    await ready();
    await create();
    google.events[focusEventId(block)] = FocusRemoteBlock({
      'id': focusEventId(block),
      'status': 'cancelled',
    });
    await c.reconcile(block);
    expect(c.journal!.operations[block]!.error, 'deleted');
    expect(google.inserts, 1);
  });
  test('W17 cleanup prunes expired terminal content', () async {
    await ready();
    await create();
    await c.saveDraft(draft(id: focusUuid()));
    now = instant.add(const Duration(days: 32));
    c.dispose();
    c = make();
    await c.initialize();
    expect(c.journal!.drafts, isEmpty);
    expect(c.journal!.operations, isEmpty);
    expect(c.journal!.blocks, isEmpty);
    expect(google.inserts, 1);
  });
  test('W17 oversized journal remains blocked and unchanged', () async {
    final bytes = ' ' * (16 * 1024 * 1024 + 1);
    disk.file.writeAsStringSync(bytes);
    await c.initialize();
    expect(c.journal, isNull);
    expect(disk.file.lengthSync(), bytes.length);
    expect(google.inserts, 0);
  });
  test(
    'W01 repeated confirmation and keyboard callbacks create once',
    () async {
      await ready();
      final p = await c.preview(draft());
      await Future.wait([c.confirm(p), c.confirm(p), c.confirm(p)]);
      expect(google.inserts, 1);
      expect(google.events.length, 1);
      expect(c.journal!.operations.length, 1);
    },
  );
  test('W01 W02 delayed journal writes precede transmission', () async {
    await ready();
    final p = await c.preview(draft());
    disk.gate = Completer();
    final send = c.confirm(p);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(google.inserts, 0);
    disk.gate!.complete();
    await send;
    expect(google.inserts, 1);
  });
  test('W02 failed confirmed-operation save sends nothing', () async {
    await ready();
    final p = await c.preview(draft());
    disk.failSave = true;
    await c.confirm(p);
    expect(google.inserts, 0);
    expect(c.message, isNotNull);
  });
  test(
    'W03 timeout after independent server commit reconciles same ID',
    () async {
      await ready();
      google.lostResponse = true;
      await create();
      expect(google.events.length, 1);
      expect(google.gets, greaterThan(0));
      expect(c.journal!.operations[block]!.status, FocusOperationStatus.saved);
      expect(google.inserts, 1);
    },
  );
  test('W03 W04 acknowledgement failure survives durable reopen', () async {
    await ready();
    disk.failAck = true;
    await create();
    expect(google.events.length, 1);
    c.dispose();
    disk = JournalStore(dir);
    c = make();
    disk.failAck = false;
    await c.initialize();
    expect(google.inserts, 1);
    await c.reconcile(block);
    expect(c.journal!.operations[block]!.status, FocusOperationStatus.saved);
    expect(google.inserts, 1);
  });
  test('W04 persisted sending restarts without mutation', () async {
    await ready();
    final op = FocusBlockOperation(
      id: block,
      blockId: block,
      kind: FocusOperationKind.create,
      payload: payload(),
      confirmedAt: now,
      credentialGeneration: 'credential-1',
      status: FocusOperationStatus.sending,
    );
    final j = c.journal!.copy();
    j.operations[block] = op;
    disk.file.writeAsStringSync(jsonEncode(j.toJson()));
    c.dispose();
    disk = JournalStore(dir);
    c = make();
    await c.initialize();
    expect(google.inserts, 0);
    expect(
      c.journal!.operations[block]!.status,
      isNot(FocusOperationStatus.saved),
    );
  });
  test('W05 lost calendar response only discovers on retry', () async {
    await c.initialize();
    google.lostCalendar = true;
    await c.createCalendar();
    expect(google.calendarInserts, 1);
    await c.createCalendar();
    expect(google.calendarInserts, 1);
    expect(c.journal!.binding, isNotNull);
  });
  test(
    'W05 partial or empty discovery cannot repeat calendar insertion',
    () async {
      await c.initialize();
      google.lostCalendar = true;
      await c.createCalendar();
      google.partialList = true;
      await c.createCalendar();
      expect(google.calendarInserts, 1);
      expect(c.journal!.binding, isNull);
    },
  );
  test('W06 W14 access denial stops writes', () async {
    await ready();
    final p = await c.preview(draft());
    google.denied = true;
    await c.confirm(p);
    expect(google.inserts, 0);
    expect(c.message, isNotNull);
  });
  test('W07 foreign duplicate ID is never overwritten', () async {
    await ready();
    google.events[focusEventId(block)] = FocusRemoteBlock({
      'id': focusEventId(block),
      'summary': 'Foreign',
    });
    await create();
    expect(google.events.values.single.title, 'Foreign');
    expect(
      c.journal!.operations[block]!.status,
      FocusOperationStatus.needsReview,
    );
    expect(google.patches, 0);
    expect(google.events.length, 1);
  });
  test('W08 remote change after preview prevents patch', () async {
    await ready();
    await create();
    final before = google.events.values.single;
    final p = await c.preview(
      draft(
        id: focusUuid(),
        value: payload(title: 'Changed'),
      ),
      kind: FocusOperationKind.edit,
      before: before,
    );
    google.events[before.id] = FocusRemoteBlock({
      ...before.value,
      'etag': '"changed"',
      'summary': 'Remote',
    });
    await c.confirm(p);
    expect(google.patches, 0);
    expect(google.events[before.id]!.title, 'Remote');
  });
  test('W08 edit timeout checks markers rather than repeating patch', () async {
    await ready();
    await create();
    final p = await c.preview(
      draft(
        id: focusUuid(),
        value: payload(title: 'Changed'),
      ),
      kind: FocusOperationKind.edit,
      before: google.events.values.single,
    );
    google.lostResponse = true;
    await c.confirm(p);
    expect(google.patches, 1);
    expect(
      c.journal!.operations.values.last.status,
      FocusOperationStatus.saved,
    );
    expect(google.events.values.single.title, 'Changed');
  });
  test('W09 deletion timeout verifies absence without recreation', () async {
    await ready();
    await create();
    final p = await c.preview(
      draft(id: focusUuid()),
      kind: FocusOperationKind.delete,
      before: google.events.values.single,
    );
    google.lostResponse = true;
    await c.confirm(p);
    expect(google.events, isEmpty);
    expect(google.deletes, 1);
    expect(
      c.journal!.operations.values.last.status,
      FocusOperationStatus.saved,
    );
    expect(google.inserts, 1);
  });
  test('W09 inaccessible calendar is not proof of deletion', () async {
    await ready();
    await create();
    google.inaccessible = true;
    await c.reconcile(block);
    expect(c.journal!.blocks, isNotEmpty);
  });
  test('W10 offline draft and restored connectivity never send', () async {
    await ready();
    session.focusOnline = false;
    session.change();
    await c.saveDraft(draft());
    session.focusOnline = true;
    session.change();
    c.dispose();
    c = make();
    await c.initialize();
    expect(google.inserts, 0);
    expect(c.journal!.drafts.length, 1);
  });
  test('W10 expired preview sends nothing', () async {
    await ready();
    final p = await c.preview(draft());
    now = instant.add(const Duration(hours: 1));
    await c.confirm(p);
    expect(google.inserts, 0);
  });
  test('W11 timezone change invalidates preview', () async {
    await ready();
    final p = await c.preview(draft());
    times.zone = 'zone-v2';
    await c.confirm(p);
    expect(google.inserts, 0);
  });
  test('W15 disconnect during queued save rejects all late work', () async {
    await ready();
    final p = await c.preview(draft());
    disk.gate = Completer();
    final send = c.confirm(p);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final stop = c.stop(purge: true);
    disk.gate!.complete();
    await Future.wait([send, stop]);
    expect(google.inserts, 0);
    expect(c.journal, isNull);
  });
  test(
    'W15 disconnect after server commit preserves remote and rejects acknowledgement',
    () async {
      await ready();
      google.responseGate = Completer();
      final send = c.confirm(await c.preview(draft()));
      while (google.events.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await c.stop(purge: true);
      google.responseGate!.complete();
      await send;
      expect(google.events.length, 1);
      expect(c.journal, isNull);
      expect(disk.file.existsSync(), false);
    },
  );
  test('W15 locked session cannot confirm', () async {
    await ready();
    final p = await c.preview(draft());
    c.unlocked = false;
    await c.confirm(p);
    expect(google.inserts, 0);
  });
  test(
    'W16 recovery requires explicit adoption and rejects guests/copied IDs',
    () async {
      await ready();
      await create();
      final good = google.events.values.single;
      google.events['foreign'] = FocusRemoteBlock({
        ...good.value,
        'id': 'foreign',
      });
      google.events['guests'] = FocusRemoteBlock({
        ...good.value,
        'id': 'guests',
        'attendees': [
          {'email': 'fictional@example.invalid'},
        ],
      });
      final found = await c.recover(
        instant,
        instant.add(const Duration(days: 7)),
      );
      expect(found.length, 1);
      expect(google.inserts, 1);
      await c.adopt(found);
      expect(c.journal!.blocks.length, 1);
    },
  );
  test('W06 confirmed operation pins account and calendar identity', () async {
    await ready();
    await create();
    final op = c.journal!.operations[block]!;
    expect(op.target!.id, binding().id);
    expect(op.target!.accountKey, account);
    await expectLater(
      c.bind(binding(id: 'different-calendar')),
      throwsA(isA<FocusFailure>()),
    );
    expect(google.inserts, 1);
  });
  test(
    'W16 journal omits unrelated Google descriptions and private fields',
    () async {
      await ready();
      await create();
      final old = google.events.values.single;
      final remote = FocusRemoteBlock({
        ...old.value,
        'description': 'never-retain-description',
        'location': 'never-retain-location',
        'creator': {'email': 'never-retain@example.invalid'},
        'extendedProperties': {
          'private': {
            ...old.properties,
            'unrelatedPrivate': 'never-retain-private',
          },
        },
      });
      google.events[old.id] = remote;
      await c.adopt([remote]);
      final stored = disk.file.readAsStringSync();
      expect(stored, isNot(contains('never-retain')));
      expect(
        google.events[old.id]!.value['description'],
        'never-retain-description',
      );
    },
  );
  test('W17 corrupt journal blocks scheduling without recreation', () async {
    disk.file.writeAsStringSync('{corrupt');
    await c.initialize();
    expect(c.journal, isNull);
    expect(c.message, isNotNull);
    expect(google.inserts, 0);
  });
  test(
    'W18 disabled scheduling leaves ordinary application independent',
    () async {
      session.focusWriteEnabled = false;
      session.writeCapability = CalendarWriteCapability.disabled;
      await c.initialize();
      await c.saveDraft(draft());
      expect(google.inserts, 0);
      expect(session.verifiedAccountKey, account);
    },
  );
}
