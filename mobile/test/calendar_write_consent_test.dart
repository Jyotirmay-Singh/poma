import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/data/google_calendar_authorization.dart';
import 'calendar_connection_test.dart' as f;

class AtomicMemory extends f.MemoryCredentials
    implements AtomicProtectedCalendarStore {
  int commits = 0;
  bool lostAck = false;
  @override
  Future<CalendarStoredConnection> read() async {
    final saved = await super.read();
    return CalendarStoredConnection(
      saved.revision,
      saved.credential,
      retired: saved.retired,
      commitRevision: commits,
    );
  }

  @override
  Future<int> commit(
    int revision,
    int expected,
    CalendarCredential credential, {
    bool purgeAccountData = false,
  }) async {
    if (expected != commits) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
    await write(revision, credential, purgeAccountData: purgeAccountData);
    commits++;
    if (lostAck) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
    return commits;
  }
}

class Upgrade extends f.FakeAuthorization implements GoogleFocusAuthorization {
  Future<CalendarAuthorization> Function()? candidate, verify;
  @override
  Future<CalendarAuthorization> authorizeFocus(
    GoogleCalendarConfiguration config,
  ) async => candidate == null
      ? f.grant(scopes: calendarFocusScopes, refresh: 'synthetic-write-refresh')
      : candidate!();
  @override
  Future<CalendarAuthorization> refreshFocus(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  ) async => verify == null
      ? f.grant(scopes: calendarFocusScopes, refresh: null)
      : verify!();
}

void main() {
  late AtomicMemory disk;
  late f.FakeAuthorization read;
  late Upgrade write;
  late CalendarConnectionController c;
  setUp(() async {
    disk = AtomicMemory()..value = f.credential();
    read = f.FakeAuthorization();
    write = Upgrade();
    c = CalendarConnectionController(
      configuration: f.configured,
      authorization: read,
      writeAuthorization: write,
      store: disk,
    );
    await c.initialize();
  });
  tearDown(() => c.dispose());
  test('W13 competing old read refresh cannot overwrite upgrade', () async {
    final candidate = Completer<CalendarAuthorization>();
    write.candidate = () => candidate.future;
    final enabling = c.enableFocusScheduling();
    await Future<void>.delayed(Duration.zero);
    final delayed = Completer<CalendarAuthorization>();
    read.onRefresh = () => delayed.future;
    final refreshing = c.refreshRejectedAccess('synthetic-access');
    await Future<void>.delayed(Duration.zero);
    candidate.complete(f.grant(scopes: calendarFocusScopes));
    await enabling;
    delayed.complete(f.grant());
    await refreshing;
    expect(disk.value!.scopes, calendarFocusScopes);
    expect(disk.value!.focusReceipt!.enabled, true);
    expect(c.operationsEnabled, true);
  });
  for (final failure in [
    CalendarFailureKind.denied,
    CalendarFailureKind.cancelled,
    CalendarFailureKind.network,
    CalendarFailureKind.permissions,
  ]) {
    test('W12 $failure preserves canonical reader and never revokes', () async {
      final prior = disk.value;
      write.candidate = () async => throw CalendarConnectionFailure(failure);
      await c.enableFocusScheduling();
      expect(identical(disk.value, prior), true);
      expect(c.operationsEnabled, true);
      expect(c.focusWriteEnabled, false);
      expect(read.revocations + write.revocations, 0);
      expect(c.verifiedAccountKey, prior!.accountKey);
    });
  }
  for (final grant in [
    f.grant(scopes: calendarReadScopes),
    f.grant(
      scopes: {
        ...calendarFocusScopes,
        'https://www.googleapis.com/auth/calendar',
      },
    ),
    f.grant(scopes: calendarFocusScopes, refresh: null),
    f.grant(scopes: calendarFocusScopes, account: 'other'),
  ]) {
    test(
      'W12 incomplete, extra, missing refresh or wrong account cannot promote ${grant.scopes.length}/${grant.accountId}/${grant.refreshToken == null}',
      () async {
        final prior = disk.value;
        write.candidate = () async => grant;
        await c.enableFocusScheduling();
        expect(identical(disk.value, prior), true);
        expect(c.operationsEnabled, true);
        expect(c.focusWriteEnabled, false);
        expect(write.revocations, 0);
      },
    );
  }
  test(
    'W13 candidate refresh failure retains protected read credential',
    () async {
      final prior = disk.value;
      write.verify = () async => throw const CalendarConnectionFailure(
        CalendarFailureKind.invalidGrant,
      );
      await c.enableFocusScheduling();
      expect(identical(disk.value, prior), true);
      expect(c.mayRead, true);
      expect(c.focusWriteEnabled, false);
    },
  );
  test(
    'W13 acknowledged or read-back promotion survives credential reload',
    () async {
      disk.lostAck = true;
      await c.enableFocusScheduling();
      expect(c.focusWriteEnabled, true);
      final encoded = jsonDecode(jsonEncode(disk.value!.toJson()));
      final restored = CalendarCredential.fromJson(encoded);
      expect(restored.focusReceipt!.enabled, true);
      expect(restored.scopes, calendarFocusScopes);
      expect(c.operationsEnabled, true);
    },
  );
  test('W13 failed precommit storage leaves reader available', () async {
    final prior = disk.value;
    disk.failWrite = true;
    await c.enableFocusScheduling();
    expect(identical(disk.value, prior), true);
    expect(c.operationsEnabled, true);
    expect(c.focusWriteEnabled, false);
  });
  test(
    'W13 permission refusal blocks writes without retiring reader',
    () async {
      await c.enableFocusScheduling();
      c.blockFocusWrites();
      expect(c.focusWriteEnabled, false);
      expect(c.mayRead, true);
      expect(disk.retired, isNull);
    },
  );
  test('W15 disable preserves reader and persists local disablement', () async {
    await c.enableFocusScheduling();
    await c.disableFocusScheduling();
    expect(c.operationsEnabled, true);
    expect(c.focusWriteEnabled, false);
    expect(disk.value!.focusReceipt!.enabled, false);
    expect(write.revocations, 0);
  });
  test('W15 cancel while candidate is pending cannot enable later', () async {
    final delayed = Completer<CalendarAuthorization>();
    write.candidate = () => delayed.future;
    final enabling = c.enableFocusScheduling();
    await Future<void>.delayed(Duration.zero);
    await c.cancelFocusConsent();
    delayed.complete(f.grant(scopes: calendarFocusScopes));
    await enabling;
    expect(c.focusWriteEnabled, false);
    expect(c.operationsEnabled, true);
  });
  test(
    'W15 account disconnect before candidate returns prevents promotion',
    () async {
      final delayed = Completer<CalendarAuthorization>();
      write.candidate = () => delayed.future;
      final enabling = c.enableFocusScheduling();
      await Future<void>.delayed(Duration.zero);
      await c.disconnect();
      delayed.complete(f.grant(scopes: calendarFocusScopes));
      await enabling;
      expect(disk.value, isNull);
      expect(c.focusWriteEnabled, false);
    },
  );
  test(
    'W17 old saved record with extra scope has no inferred write capability',
    () {
      final m = f.credential().toJson();
      m['scopes'] = calendarFocusScopes.toList();
      final old = CalendarCredential.fromJson(m);
      expect(old.focusReceipt, isNull);
    },
  );
  for (final body in [
    <String, Object?>{
      'access_token': 'synthetic-access',
      'expires_in': 3600,
      'refresh_token': 'synthetic-refresh',
    },
    {
      'access_token': 'synthetic-access',
      'expires_in': 3600,
      'scope': calendarReadScopes.join(' '),
      'refresh_token': 'synthetic-refresh',
    },
    {
      'access_token': 'synthetic-access',
      'expires_in': 3600,
      'scope': calendarFocusScopes.join(' '),
    },
    {
      'access_token': 'synthetic-access',
      'expires_in': 3600,
      'scope': {...calendarFocusScopes, 'unexpected'}.join(' '),
      'refresh_token': 'synthetic-refresh',
    },
  ]) {
    test(
      'W12 raw desktop token evidence rejects library defaults ${body.keys}/${body['scope']}',
      () async {
        final browser = f.CapturingBrowser();
        final provider = DesktopGoogleAuthorization(
          browser: browser,
          clientFactory: () => MockClient(
            (_) async => http.Response(
              jsonEncode(body),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        );
        final future = provider.authorizeFocus(f.configured);
        final assertion = expectLater(
          future,
          throwsA(isA<CalendarConnectionFailure>()),
        );
        final url = await browser.opened.future;
        expect(
          url.queryParameters['scope']!.split(' ').toSet(),
          calendarFocusScopes,
        );
        expect(
          url.queryParameters.containsKey('include_granted_scopes'),
          false,
        );
        await f.callback(url);
        await assertion;
        provider.dispose();
      },
    );
  }
  test(
    'W13 exact-lineage refresh can omit scopes and token but verifies identity',
    () async {
      final provider = DesktopGoogleAuthorization(
        browser: f.CapturingBrowser(),
        clientFactory: () => MockClient((request) async {
          if (request.url.host == 'oauth2.googleapis.com') {
            return f.tokenResponse(scope: null, refresh: null);
          }
          return http.Response(
            jsonEncode({'id': 'synthetic-primary', 'primary': true}),
            200,
          );
        }),
      );
      final result = await provider.refreshFocus(
        f.configured,
        CalendarCredential(
          clientId: f.configured.clientId,
          accountId: 'synthetic-primary',
          refreshToken: 'synthetic-write-refresh',
          scopes: calendarFocusScopes,
        ),
      );
      expect(result.scopes, calendarFocusScopes);
      expect(result.refreshToken, 'synthetic-write-refresh');
      provider.dispose();
    },
  );
}
