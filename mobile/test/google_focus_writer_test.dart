import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/focus_block_ports.dart';
import 'package:poma/data/google_focus_writer.dart';
import 'package:poma/domain/focus_blocks.dart';
import 'calendar_connection_test.dart' as auth;
import 'calendar_write_consent_test.dart' show AtomicMemory;
import 'focus_blocks_test.dart' as f;

void main() {
  late CalendarConnectionController connection;
  late GoogleFocusWriter writer;
  late FocusCalendarBinding binding;
  late List<http.Request> requests;
  late Map<String, FocusRemoteBlock> events;
  bool primary = false,
      owner = true,
      marker = true,
      allowed = true,
      missingCalendar = false;
  Map<String, dynamic> metadata() => {
    'id': binding.id,
    'summary': 'Renamed Poma',
    'description': marker ? 'Created by Poma.\n${binding.marker}' : 'Unmarked',
  };
  FocusBlockOperation op({
    FocusOperationKind kind = FocusOperationKind.create,
    FocusRemoteBlock? before,
  }) => FocusBlockOperation(
    id: kind == FocusOperationKind.create ? f.block : focusUuid(),
    blockId: f.block,
    kind: kind,
    payload: f.payload(),
    confirmedAt: f.instant,
    credentialGeneration: 'test',
    etag: before?.etag,
    before: before,
    target: binding,
  );
  http.Response json(Object? body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
  Future<http.Response> route(http.Request r) async {
    requests.add(r);
    final parts = r.url.pathSegments;
    if (parts.contains('calendarList')) {
      if (parts.last == 'calendarList') {
        return json({
          'items': [
            metadata()..addAll({
              'primary': primary,
              'accessRole': owner ? 'owner' : 'writer',
            }),
          ],
        });
      }
      return json({
        'id': binding.id,
        'primary': primary,
        'accessRole': owner ? 'owner' : 'writer',
      });
    }
    if (parts.last == binding.id) {
      if (missingCalendar) return json({}, 404);
      if (!allowed) return json({}, 403);
      return json(metadata());
    }
    if (r.method == 'GET' && parts.last == 'events') {
      return json({'items': events.values.map((e) => e.value).toList()});
    }
    if (r.method == 'GET') {
      final event = events[parts.last];
      return event == null ? json({}, 404) : json(event.value);
    }
    if (r.method == 'POST' && parts.last == 'events') {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(r.url.queryParameters['sendUpdates'], 'none');
      if (events.containsKey(body['id'])) return json({}, 409);
      final remote = FocusRemoteBlock({...body, 'etag': '"one"'});
      events[remote.id] = remote;
      return json(remote.value);
    }
    if (r.method == 'PATCH') {
      final old = events[parts.last]!;
      if (old.etag != r.headers['If-Match']) return json({}, 412);
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final updated = FocusRemoteBlock({
        ...old.value,
        ...body,
        'etag': '"two"',
      });
      events[old.id] = updated;
      return json(updated.value);
    }
    if (r.method == 'DELETE') {
      if (events[parts.last]?.etag != r.headers['If-Match']) {
        return json({}, 412);
      }
      events.remove(parts.last);
      return http.Response('', 204);
    }
    return json({}, 400);
  }

  setUp(() async {
    requests = [];
    events = {};
    primary = false;
    owner = true;
    marker = true;
    allowed = true;
    missingCalendar = false;
    final credential = CalendarCredential(
      clientId: auth.configured.clientId,
      accountId: 'synthetic-primary',
      refreshToken: 'synthetic-write-refresh',
      scopes: calendarFocusScopes,
      focusReceipt: CalendarWriteReceipt(
        generation: focusUuid(),
        enabled: true,
      ),
    );
    final disk = AtomicMemory()..value = credential;
    final provider = auth.FakeAuthorization()
      ..onRefresh = () async =>
          auth.grant(scopes: calendarFocusScopes, refresh: null);
    connection = CalendarConnectionController(
      configuration: auth.configured,
      authorization: provider,
      store: disk,
    );
    await connection.initialize();
    binding = FocusCalendarBinding(
      accountKey: credential.accountKey,
      clientId: credential.clientId,
      id: 'focus@group.calendar.google.com',
      calendarKey: f.binding().calendarKey,
      provisioningId: f.binding().provisioningId,
      name: 'Poma Focus',
    );
    writer = GoogleFocusWriter(
      connection,
      clientFactory: () => MockClient(route),
      now: () => f.instant,
    );
  });
  tearDown(() {
    writer.cancel();
    connection.dispose();
  });
  test(
    'W15 cancellation during final preflight cannot start a new HTTP mutation',
    () async {
      writer = GoogleFocusWriter(
        connection,
        now: () => f.instant,
        verifyTime: (_) async {
          writer.cancel();
        },
        clientFactory: () => MockClient(route),
      );
      await expectLater(
        writer.create(binding, op()),
        throwsA(
          isA<FocusFailure>().having(
            (e) => e.kind,
            'kind',
            FocusFailureKind.cancelled,
          ),
        ),
      );
      expect(events, isEmpty);
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
    },
  );
  test('W10 expiration during preflight prevents transmission', () async {
    var now = f.instant;
    var mutations = 0;
    writer = GoogleFocusWriter(
      connection,
      now: () => now,
      clientFactory: () => MockClient((r) async {
        if (r.method != 'GET') mutations++;
        final result = await route(r);
        if (!r.url.pathSegments.contains('calendarList')) {
          now = f.instant.add(const Duration(hours: 1));
        }
        return result;
      }),
    );
    await expectLater(
      writer.create(binding, op()),
      throwsA(
        isA<FocusFailure>().having(
          (e) => e.kind,
          'kind',
          FocusFailureKind.invalidTime,
        ),
      ),
    );
    expect(mutations, 0);
    expect(events, isEmpty);
  });
  test(
    'W09 HTTP Gone remains a tombstone rather than an absent create',
    () async {
      writer = GoogleFocusWriter(
        connection,
        clientFactory: () => MockClient((r) async {
          if (r.url.pathSegments.contains('events')) return json({}, 410);
          return route(r);
        }),
      );
      final deleted = await writer.get(binding, focusEventId(f.block));
      expect(deleted, isNotNull);
      expect(deleted!.deleted, true);
    },
  );
  test(
    'W06 exact ID metadata and app-created eligibility checked before POST',
    () async {
      final result = await writer.create(binding, op());
      expect(result.owned(binding), true);
      expect(requests.map((r) => r.method), ['GET', 'GET', 'POST']);
      expect(requests[1].url.pathSegments, [
        'calendar',
        'v3',
        'calendars',
        binding.id,
      ]);
      final sent = jsonDecode(requests.last.body) as Map;
      expect(sent['eventType'], 'default');
      expect(sent['visibility'], 'private');
      expect(sent['reminders'], {'useDefault': false, 'overrides': []});
      for (final excluded in [
        'attendees',
        'recurrence',
        'conferenceData',
        'attachments',
        'taskId',
        'description',
      ]) {
        expect(sent.containsKey(excluded), false);
      }
    },
  );
  test('W06 renamed calendar displays current verified name', () async {
    expect((await writer.validate(binding)).name, 'Renamed Poma');
  });
  for (final fault in [
    'primary',
    'owner',
    'marker',
    'eligibility',
    'deleted',
  ]) {
    test('W06 $fault prevents event mutation', () async {
      primary = fault == 'primary';
      owner = fault != 'owner';
      marker = fault != 'marker';
      allowed = fault != 'eligibility';
      missingCalendar = fault == 'deleted';
      await expectLater(
        writer.create(binding, op()),
        throwsA(isA<FocusFailure>()),
      );
      expect(requests.where((r) => r.method != 'GET'), isEmpty);
    });
  }
  test(
    'W07 duplicate event ID never causes alternate ID or overwrite',
    () async {
      final operation = op();
      await writer.create(binding, operation);
      await expectLater(
        writer.create(binding, operation),
        throwsA(
          isA<FocusFailure>().having(
            (e) => e.kind,
            'kind',
            FocusFailureKind.conflict,
          ),
        ),
      );
      expect(events.length, 1);
      expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
    },
  );
  test(
    'W08 patch uses If-Match and preserves other private properties',
    () async {
      final remote = await writer.create(binding, op());
      final withExtra = FocusRemoteBlock({
        ...remote.value,
        'extendedProperties': {
          'private': {...remote.properties, 'unrelated': 'keep'},
        },
        'location': 'keep location',
      });
      events[remote.id] = withExtra;
      await writer.edit(
        binding,
        op(kind: FocusOperationKind.edit, before: withExtra),
        withExtra,
      );
      final patch = requests.last;
      expect(patch.method, 'PATCH');
      expect(patch.headers['If-Match'], '"one"');
      expect(
        (jsonDecode(patch.body)['extendedProperties']['private']
            as Map)['unrelated'],
        'keep',
      );
      expect(events.values.single.value['location'], 'keep location');
    },
  );
  test('W08 changed ETag prevents PATCH before transmission', () async {
    final before = await writer.create(binding, op());
    events[before.id] = FocusRemoteBlock({...before.value, 'etag': '"remote"'});
    await expectLater(
      writer.edit(
        binding,
        op(kind: FocusOperationKind.edit, before: before),
        before,
      ),
      throwsA(isA<FocusFailure>()),
    );
    expect(requests.where((r) => r.method == 'PATCH'), isEmpty);
  });
  for (final change in [
    {
      'attendees': [
        {'email': 'fictional@example.invalid'},
      ],
    },
    {
      'recurrence': ['RRULE:FREQ=DAILY'],
    },
    {'eventType': 'focusTime'},
    {
      'extendedProperties': {'private': {}},
    },
  ]) {
    test(
      'W16 unsupported remote shape blocks deletion ${change.keys}',
      () async {
        final before = await writer.create(binding, op());
        events[before.id] = FocusRemoteBlock({...before.value, ...change});
        await expectLater(
          writer.delete(
            binding,
            op(kind: FocusOperationKind.delete, before: before),
          ),
          throwsA(isA<FocusFailure>()),
        );
        expect(requests.where((r) => r.method == 'DELETE'), isEmpty);
      },
    );
  }
  test(
    'W09 event absence requires independently accessible calendar',
    () async {
      missingCalendar = true;
      await expectLater(
        writer.get(binding, focusEventId(f.block)),
        throwsA(isA<FocusFailure>()),
      );
    },
  );
  test('W14 write-only forbidden does not retire read credential', () async {
    allowed = false;
    await expectLater(
      writer.create(binding, op()),
      throwsA(isA<FocusFailure>()),
    );
    expect(connection.mayRead, true);
    expect(connection.focusWriteEnabled, false);
  });
  test('W05 discovery follows hidden calendars and all pages', () async {
    writer = GoogleFocusWriter(
      connection,
      clientFactory: () => MockClient((r) async {
        if (r.url.pathSegments.last == 'calendarList') {
          expect(r.url.queryParameters['showHidden'], 'true');
          if (r.url.queryParameters['pageToken'] == null) {
            return json({'items': [], 'nextPageToken': 'later'});
          }
          return json({
            'items': [
              metadata()..addAll({'accessRole': 'owner', 'primary': false}),
            ],
          });
        }
        return route(r);
      }),
    );
    final found = await writer.discover(binding.accountKey, binding.clientId);
    expect(found.single.id, binding.id);
  });
}
