import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/data/google_calendar_authorization.dart';
import 'package:poma/data/windows_calendar_credentials.dart';
import 'package:poma/main.dart';
import 'package:poma/domain/models.dart';

import 'desktop_test.dart' show FakeShell;
import 'support.dart';

const configured = GoogleCalendarConfiguration(
  clientId: '123456-test.apps.googleusercontent.com',
);
CalendarAuthorization grant({
  String account = 'synthetic-primary',
  String? refresh = 'synthetic-refresh',
  Set<String>? scopes,
}) => CalendarAuthorization(
  accountId: account,
  accessToken: 'synthetic-access',
  refreshToken: refresh,
  scopes: scopes ?? calendarReadScopes,
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
);
CalendarCredential credential({
  String account = 'synthetic-primary',
  String client = '123456-test.apps.googleusercontent.com',
}) => CalendarCredential(
  clientId: client,
  accountId: account,
  refreshToken: 'synthetic-refresh',
  scopes: calendarReadScopes,
);

class MemoryCredentials implements ProtectedCalendarStore {
  CalendarCredential? value;
  CalendarAccountIdentity? retired;
  final List<bool> purges = [];
  void Function()? onPurge;
  int revision = 0, writes = 0, clears = 0;
  bool failRead = false, failWrite = false, failClear = false;
  Completer<void>? writeGate;
  Completer<void>? clearGate;
  @override
  Future<CalendarStoredConnection> read() async {
    if (failRead) throw StateError('synthetic storage failure');
    return CalendarStoredConnection(revision, value, retired: retired);
  }

  @override
  Future<void> write(
    int expected,
    CalendarCredential credential, {
    bool purgeAccountData = false,
  }) async {
    writes++;
    purges.add(purgeAccountData);
    await writeGate?.future;
    if (failWrite || expected != revision) {
      throw StateError('synthetic storage failure');
    }
    value = credential;
    retired = null;
    if (purgeAccountData) onPurge?.call();
  }

  @override
  Future<int> invalidateAndClear() async {
    revision++;
    clears++;
    await clearGate?.future;
    if (failClear) throw StateError('synthetic deletion failure');
    value = null;
    retired = null;
    onPurge?.call();
    return revision;
  }

  @override
  Future<int> retire(int expected, CalendarAccountIdentity identity) async {
    if (failClear || expected != revision) {
      throw StateError('Synthetic retirement failure');
    }
    revision++;
    value = null;
    retired = identity;
    return revision;
  }
}

class FakeAuthorization implements GoogleCalendarAuthorization {
  int authorizations = 0, refreshes = 0, revocations = 0, cancellations = 0;
  Future<CalendarAuthorization> Function()? onAuthorize, onRefresh;
  Future<bool> Function()? onRevoke;
  @override
  Future<CalendarAuthorization> authorize(
    GoogleCalendarConfiguration config,
  ) async {
    authorizations++;
    return onAuthorize == null ? grant() : onAuthorize!();
  }

  @override
  Future<CalendarAuthorization> refresh(
    GoogleCalendarConfiguration config,
    CalendarCredential saved,
  ) async {
    refreshes++;
    return onRefresh == null ? grant(refresh: null) : onRefresh!();
  }

  @override
  Future<bool> revoke(String token) async {
    revocations++;
    return onRevoke == null ? false : onRevoke!();
  }

  @override
  Future<void> cancelPending() async {
    cancellations++;
  }

  @override
  void dispose() {}
}

class CapturingBrowser implements CalendarBrowser {
  final opened = Completer<Uri>();
  bool fail = false;
  @override
  Future<void> openAuthorization(Uri uri) async {
    opened.complete(uri);
    if (fail) throw StateError('synthetic browser failure');
  }
}

class LoopbackHttpOverrides extends HttpOverrides {}

Future<int> callback(
  Uri auth, {
  String? state,
  String? code = 'synthetic-code',
  String? error,
  String path = '/oauth2/callback',
  Map<String, dynamic>? query,
  String method = 'GET',
  String? host,
}) async {
  // Widget binding blocks HTTP globally; only this loopback test client opts out.
  final client = HttpOverrides.runWithHttpOverrides(
    HttpClient.new,
    LoopbackHttpOverrides(),
  );
  try {
    final uri = Uri.parse(auth.queryParameters['redirect_uri']!).replace(
      path: path,
      queryParameters:
          query ??
          {
            'state': state ?? auth.queryParameters['state']!,
            'code': ?code,
            'error': ?error,
          },
    );
    final request = await client.openUrl(method, uri);
    if (host != null) request.headers.set('Host', host);
    final response = await request.close();
    await response.drain<void>();
    return response.statusCode;
  } finally {
    client.close(force: true);
  }
}

Future<void> listenerClosed(Uri auth) async {
  final uri = Uri.parse(auth.queryParameters['redirect_uri']!);
  final socket = await ServerSocket.bind(
    InternetAddress.loopbackIPv4,
    uri.port,
  );
  await socket.close();
}

http.Response tokenResponse({
  Object? scope = 'full',
  String? refresh = 'synthetic-refresh',
  int status = 200,
  Object expires = 3600,
}) => http.Response(
  jsonEncode({
    if (status == 200) ...{
      'access_token': 'synthetic-access',
      'token_type': 'Bearer',
      'expires_in': expires,
      if (scope != null)
        'scope': scope == 'full' ? calendarReadScopes.join(' ') : scope,
      'refresh_token': ?refresh,
    } else
      'error': 'invalid_grant',
  }),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  CalendarConnectionController controller(
    MemoryCredentials store,
    FakeAuthorization auth, {
    GoogleCalendarConfiguration config = configured,
    DateTime Function()? now,
  }) {
    final value = CalendarConnectionController(
      configuration: config,
      authorization: auth,
      store: store,
      now: now,
    );
    addTearDown(value.dispose);
    return value;
  }

  test(
    'configuration validates compile contract without network work',
    () async {
      for (final config in [
        const GoogleCalendarConfiguration(),
        const GoogleCalendarConfiguration(clientId: 'web-client'),
        const GoogleCalendarConfiguration(
          clientId: '123-placeholder.apps.googleusercontent.com',
        ),
        const GoogleCalendarConfiguration(
          clientId: '123-test.apps.googleusercontent.com',
          audience: 'unknown',
        ),
      ]) {
        final auth = FakeAuthorization();
        final store = MemoryCredentials();
        final connection = controller(store, auth, config: config);
        await connection.initialize();
        await connection.connect();
        expect(connection.status, CalendarConnectionStatus.unconfigured);
        expect(auth.authorizations + auth.refreshes, 0);
      }
    },
  );

  test(
    'connect persists only refresh material; restart refresh omits token safely',
    () async {
      final store = MemoryCredentials();
      final auth = FakeAuthorization();
      final first = controller(store, auth);
      await first.initialize();
      await first.connect();
      expect(first.operationsEnabled, isTrue);
      expect(
        jsonEncode(store.value!.toJson()),
        isNot(contains('synthetic-access')),
      );
      final restarted = controller(store, auth);
      await restarted.initialize();
      expect(restarted.operationsEnabled, isTrue);
      expect(auth.refreshes, 1);
      expect(store.value!.refreshToken, 'synthetic-refresh');
    },
  );

  test(
    'concurrent refreshes coalesce and rotate refresh credentials',
    () async {
      final store = MemoryCredentials()..value = credential();
      final pending = Completer<CalendarAuthorization>();
      final auth = FakeAuthorization()..onRefresh = () => pending.future;
      final connection = controller(store, auth);
      final initialized = connection.initialize();
      await Future<void>.delayed(Duration.zero);
      final requests = List.generate(8, (_) => connection.accessToken());
      expect(auth.refreshes, 1);
      pending.complete(grant(refresh: 'synthetic-rotated'));
      await initialized;
      await Future.wait(requests);
      expect(store.value!.refreshToken, 'synthetic-rotated');
      expect(store.writes, 1);
    },
  );

  test(
    'initial network failure does not claim saved credentials exist',
    () async {
      final store = MemoryCredentials();
      final auth = FakeAuthorization()
        ..onAuthorize = () async =>
            throw const CalendarConnectionFailure(CalendarFailureKind.network);
      final connection = controller(store, auth);
      await connection.initialize();
      await connection.connect();
      expect(connection.status, CalendarConnectionStatus.offline);
      expect(connection.operationsEnabled, isFalse);
      expect(store.value, isNull);
      expect(store.writes, 0);
      expect(connection.message, contains('No new connection was saved'));
      expect(connection.message, isNot(contains('retained')));
    },
  );

  test(
    'Calendar API refusals are distinct from offline and never save a grant',
    () async {
      for (final status in [403, 404]) {
        final browser = CapturingBrowser();
        final store = MemoryCredentials();
        final provider = DesktopGoogleAuthorization(
          browser: browser,
          clientFactory: () => MockClient(
            (request) async => request.url.path == '/token'
                ? tokenResponse()
                : http.Response('synthetic-private-provider-body', status),
          ),
        );
        final connection = CalendarConnectionController(
          configuration: configured,
          authorization: provider,
          store: store,
        );
        addTearDown(connection.dispose);
        await connection.initialize();
        final connecting = connection.connect();
        final url = await browser.opened.future;
        expect(await callback(url), 200);
        await connecting;
        expect(connection.status, CalendarConnectionStatus.unavailable);
        expect(connection.message, contains('Calendar API'));
        expect(connection.message, isNot(contains('synthetic-private')));
        expect(connection.operationsEnabled, isFalse);
        expect(store.value, isNull);
        expect(store.writes, 0);
        await listenerClosed(url);
      }
    },
  );

  test(
    'refresh network failure preserves saved credential; invalid_grant stops retries',
    () async {
      final store = MemoryCredentials()..value = credential();
      final auth = FakeAuthorization()
        ..onRefresh = () async =>
            throw const CalendarConnectionFailure(CalendarFailureKind.network);
      final connection = controller(store, auth);
      await connection.initialize();
      expect(connection.status, CalendarConnectionStatus.offline);
      expect(store.value, isNotNull);
      expect(
        connection.message,
        contains('Saved refresh credentials are retained'),
      );
      auth.onRefresh = () async => throw const CalendarConnectionFailure(
        CalendarFailureKind.invalidGrant,
      );
      await connection.accessToken();
      await Future<void>.delayed(Duration.zero);
      expect(connection.status, CalendarConnectionStatus.reconnectRequired);
      expect(store.value, isNull);
      final count = auth.refreshes;
      await connection.accessToken();
      expect(auth.refreshes, count);
    },
  );

  test(
    'partial grant and failed protected write never enable operations',
    () async {
      final auth = FakeAuthorization()
        ..onAuthorize = () async => grant(scopes: {calendarReadScopes.first});
      final store = MemoryCredentials();
      final connection = controller(store, auth);
      await connection.initialize();
      await connection.connect();
      await Future<void>.delayed(Duration.zero);
      expect(connection.status, CalendarConnectionStatus.incompletePermissions);
      expect(connection.operationsEnabled, isFalse);
      expect(store.value, isNull);
      auth.onAuthorize = () async => grant();
      store.failWrite = true;
      await connection.connect();
      expect(connection.status, CalendarConnectionStatus.storageError);
      expect(connection.operationsEnabled, isFalse);
    },
  );

  test(
    'read errors leave disconnect available; deletion errors are retryable',
    () async {
      final store = MemoryCredentials()
        ..failRead = true
        ..failClear = true;
      final connection = controller(store, FakeAuthorization());
      await connection.initialize();
      expect(connection.status, CalendarConnectionStatus.storageError);
      await connection.disconnect();
      expect(connection.cleanupPending, isTrue);
      expect(connection.canConnect, isFalse);
      store.failClear = false;
      await connection.disconnect();
      expect(connection.cleanupPending, isFalse);
      expect(connection.canConnect, isTrue);
    },
  );

  test('incompatible client credentials are purged without refresh', () async {
    final store = MemoryCredentials()
      ..value = credential(client: '999-other.apps.googleusercontent.com');
    final auth = FakeAuthorization();
    final connection = controller(store, auth);
    await connection.initialize();
    expect(store.value, isNull);
    expect(auth.refreshes, 0);
  });

  test('cancel and disconnect reject late authorization responses', () async {
    for (final disconnect in [false, true]) {
      final pending = Completer<CalendarAuthorization>();
      final store = MemoryCredentials();
      final auth = FakeAuthorization()..onAuthorize = () => pending.future;
      final connection = controller(store, auth);
      await connection.initialize();
      final operation = connection.connect();
      if (disconnect) {
        await connection.disconnect();
      } else {
        await connection.cancel();
      }
      pending.complete(grant());
      await operation;
      expect(store.value, isNull);
      expect(connection.operationsEnabled, isFalse);
    }
  });

  test(
    'disconnect during protected write cannot resurrect credential',
    () async {
      final gate = Completer<void>();
      final store = MemoryCredentials()..writeGate = gate;
      final connection = controller(store, FakeAuthorization());
      await connection.initialize();
      final operation = connection.connect();
      await Future<void>.delayed(Duration.zero);
      expect(store.writes, 1);
      await connection.disconnect();
      gate.complete();
      await operation;
      expect(store.value, isNull);
      expect(connection.operationsEnabled, isFalse);
    },
  );

  test(
    'late refresh and authorized response are rejected after disconnect',
    () async {
      final pending = Completer<CalendarAuthorization>();
      final store = MemoryCredentials()..value = credential();
      final auth = FakeAuthorization()..onRefresh = () => pending.future;
      final connection = controller(store, auth);
      final operation = connection.initialize();
      await Future<void>.delayed(Duration.zero);
      await connection.disconnect();
      pending.complete(grant());
      await operation;
      expect(store.value, isNull);
      expect(connection.operationsEnabled, isFalse);
      await connection.connect();
      final response = Completer<String>();
      final request = connection.withAccess((_) => response.future);
      await Future<void>.delayed(Duration.zero);
      await connection.disconnect();
      response.complete('old-account-data');
      expect(await request, isNull);
    },
  );

  test(
    'account replacement cannot inherit another account refresh token',
    () async {
      final store = MemoryCredentials();
      final auth = FakeAuthorization();
      final connection = controller(store, auth);
      await connection.initialize();
      await connection.connect();
      auth.onAuthorize = () async =>
          grant(account: 'different-primary', refresh: null);
      await connection.connect();
      expect(connection.operationsEnabled, isFalse);
      expect(connection.status, CalendarConnectionStatus.reconnectRequired);
    },
  );

  test(
    'disconnect disables immediately and blocks reconnect during revocation',
    () async {
      final revocation = Completer<bool>();
      final auth = FakeAuthorization()..onRevoke = () => revocation.future;
      final connection = controller(MemoryCredentials(), auth);
      await connection.initialize();
      await connection.connect();
      final operation = connection.disconnect();
      expect(connection.operationsEnabled, isFalse);
      expect(connection.canConnect, isFalse);
      await connection.connect();
      expect(auth.authorizations, 1);
      revocation.complete(false);
      await operation;
      expect(connection.message, contains('could not be confirmed'));
      expect(connection.canConnect, isTrue);
    },
  );

  test('reset local cleanup never waits for provider revocation', () async {
    final revocation = Completer<bool>();
    final auth = FakeAuthorization()..onRevoke = () => revocation.future;
    final connection = controller(MemoryCredentials(), auth);
    await connection.initialize();
    await connection.connect();
    connection.invalidateForReset();
    await connection.clearForReset().timeout(const Duration(seconds: 1));
    expect(connection.operationsEnabled, isFalse);
    revocation.complete(true);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'loopback S256, state, redirect identity, exact scopes and cleanup',
    () async {
      final browser = CapturingBrowser();
      int tokenCalls = 0;
      Uri? authUrl;
      final provider = DesktopGoogleAuthorization(
        browser: browser,
        clientFactory: () => MockClient((request) async {
          if (request.url.path == '/token') {
            tokenCalls++;
            final body = Uri.splitQueryString(request.body);
            expect(body['client_id'], configured.clientId);
            expect(
              body['redirect_uri'],
              authUrl!.queryParameters['redirect_uri'],
            );
            expect(
              base64Url
                  .encode(
                    sha256.convert(ascii.encode(body['code_verifier']!)).bytes,
                  )
                  .replaceAll('=', ''),
              authUrl.queryParameters['code_challenge'],
            );
            expect(body, isNot(contains('client_secret')));
            return tokenResponse();
          }
          expect(request.url.queryParameters['fields'], 'id,primary');
          expect(request.headers['authorization'], 'Bearer synthetic-access');
          return http.Response(
            '{"id":"synthetic-primary","primary":true}',
            200,
          );
        }),
      );
      addTearDown(provider.dispose);
      final operation = provider.authorize(configured);
      authUrl = await browser.opened.future;
      expect(authUrl.queryParameters['code_challenge_method'], 'S256');
      expect(
        authUrl.queryParameters['scope']!.split(' ').toSet(),
        calendarReadScopes,
      );
      final redirect = Uri.parse(authUrl.queryParameters['redirect_uri']!);
      expect(redirect.host, '127.0.0.1');
      expect(redirect.port, greaterThan(0));
      for (final query in [
        {'state': 'wrong', 'code': 'synthetic-code'},
        {'code': 'synthetic-code'},
        {
          'state': [authUrl.queryParameters['state']!, 'wrong'],
          'code': 'synthetic-code',
        },
        {
          'state': authUrl.queryParameters['state']!,
          'code': 'synthetic-code',
          'error': 'access_denied',
        },
      ]) {
        expect(await callback(authUrl, query: query), 400);
      }
      expect(await callback(authUrl, path: '/wrong'), 400);
      expect(await callback(authUrl, method: 'POST'), 400);
      expect(await callback(authUrl, host: 'localhost:${redirect.port}'), 400);
      final absolute = await Socket.connect(
        InternetAddress.loopbackIPv4,
        redirect.port,
      );
      final absoluteUri = Uri.http('unexpected.invalid', '/oauth2/callback', {
        'state': authUrl.queryParameters['state']!,
        'code': 'synthetic-code',
      });
      absolute.write(
        'GET $absoluteUri HTTP/1.1\r\nHost: 127.0.0.1:${redirect.port}\r\nConnection: close\r\n\r\n',
      );
      final absoluteResponse = await absolute
          .cast<List<int>>()
          .transform(utf8.decoder)
          .join();
      absolute.destroy();
      expect(absoluteResponse.split('\r\n').first, contains('400'));
      expect(tokenCalls, 0);
      expect(await callback(authUrl), 200);
      expect((await operation).accountId, 'synthetic-primary');
      expect(tokenCalls, 1);
      await listenerClosed(authUrl);
    },
  );

  test(
    'each browser attempt has fresh state and challenge; cancellation closes ports',
    () async {
      final urls = <Uri>[];
      for (var i = 0; i < 2; i++) {
        final browser = CapturingBrowser();
        final provider = DesktopGoogleAuthorization(browser: browser);
        final operation = provider.authorize(configured);
        final expectation = expectLater(
          operation,
          throwsA(isA<CalendarConnectionFailure>()),
        );
        final url = await browser.opened.future;
        urls.add(url);
        await provider.cancelPending();
        await expectation;
        await listenerClosed(url);
        provider.dispose();
      }
      expect(
        urls[0].queryParameters['state'],
        isNot(urls[1].queryParameters['state']),
      );
      expect(
        urls[0].queryParameters['code_challenge'],
        isNot(urls[1].queryParameters['code_challenge']),
      );
    },
  );

  test(
    'denial, browser failure and callback timeout close listeners',
    () async {
      for (final scenario in ['denial', 'browser', 'timeout']) {
        final browser = CapturingBrowser()..fail = scenario == 'browser';
        final provider = DesktopGoogleAuthorization(
          browser: browser,
          callbackTimeout: const Duration(milliseconds: 100),
        );
        final operation = provider.authorize(configured);
        final expectation = expectLater(
          operation,
          throwsA(isA<CalendarConnectionFailure>()),
        );
        final url = await browser.opened.future;
        if (scenario == 'denial') {
          await callback(url, code: null, error: 'access_denied');
        }
        await expectation;
        await listenerClosed(url);
        provider.dispose();
      }
    },
  );

  test(
    'raw partial/missing scopes and malformed token replies fail closed',
    () async {
      for (final response in [
        tokenResponse(scope: null),
        tokenResponse(scope: calendarReadScopes.first),
        tokenResponse(expires: 'invalid'),
        http.Response(
          'synthetic-sensitive-response',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ]) {
        final browser = CapturingBrowser();
        final provider = DesktopGoogleAuthorization(
          browser: browser,
          clientFactory: () => MockClient((_) async => response),
        );
        final operation = provider.authorize(configured);
        final expectation = expectLater(
          operation,
          throwsA(
            isA<CalendarConnectionFailure>().having(
              (e) => e.toString(),
              'safe message',
              isNot(contains('synthetic-sensitive-response')),
            ),
          ),
        );
        final url = await browser.opened.future;
        await callback(url);
        await expectation;
        await listenerClosed(url);
        provider.dispose();
      }
    },
  );

  test(
    'real oauth2 refresh preserves omitted token/scopes and sends public client body',
    () async {
      final provider = DesktopGoogleAuthorization(
        browser: CapturingBrowser(),
        clientFactory: () => MockClient((request) async {
          final body = Uri.splitQueryString(request.body);
          expect(body['client_id'], configured.clientId);
          expect(body['grant_type'], 'refresh_token');
          expect(request.headers.containsKey('authorization'), isFalse);
          return tokenResponse(scope: null, refresh: null);
        }),
      );
      addTearDown(provider.dispose);
      final refreshed = await provider.refresh(configured, credential());
      expect(refreshed.refreshToken, 'synthetic-refresh');
      expect(refreshed.scopes, calendarReadScopes);
    },
  );

  test(
    'real adapter refresh invalid_grant and safe transport errors',
    () async {
      for (final response in [
        tokenResponse(status: 400),
        http.Response('synthetic-sensitive-response', 503),
      ]) {
        final provider = DesktopGoogleAuthorization(
          browser: CapturingBrowser(),
          clientFactory: () => MockClient((_) async => response),
        );
        await expectLater(
          provider.refresh(configured, credential()),
          throwsA(isA<CalendarConnectionFailure>()),
        );
        provider.dispose();
      }
    },
  );

  test(
    'native storage channel errors are sanitized and corrupt records rejected',
    () async {
      const channel = MethodChannel('poma/calendar-synthetic-test');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final store = WindowsCalendarCredentials(channel);
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => throw PlatformException(
          code: 'synthetic',
          message: 'synthetic-sensitive-response',
        ),
      );
      await expectLater(
        store.read(),
        throwsA(isA<CalendarConnectionFailure>()),
      );
      await expectLater(
        store.write(0, credential()),
        throwsA(isA<CalendarConnectionFailure>()),
      );
      await expectLater(
        store.invalidateAndClear(),
        throwsA(isA<CalendarConnectionFailure>()),
      );
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {'revision': 0, 'credential': '{"bad":"synthetic"}'},
      );
      await expectLater(
        store.read(),
        throwsA(isA<CalendarConnectionFailure>()),
      );
    },
  );

  test(
    'same account reconnect retains refresh token; fresh account requires one',
    () async {
      final auth = FakeAuthorization();
      final store = MemoryCredentials();
      final connection = controller(store, auth);
      await connection.initialize();
      await connection.connect();
      auth.onAuthorize = () async => grant(refresh: null);
      await connection.connect();
      expect(connection.operationsEnabled, isTrue);
      expect(store.value!.refreshToken, 'synthetic-refresh');
      await connection.disconnect();
      await connection.connect();
      expect(connection.operationsEnabled, isFalse);
      expect(connection.status, CalendarConnectionStatus.reconnectRequired);
    },
  );

  test(
    'disconnect preserves saved task, completed history and running timer exactly',
    () async {
      final connection = controller(MemoryCredentials(), FakeAuthorization());
      await connection.initialize();
      await connection.connect();
      final clock = FakeClock();
      final repository = MemoryRepository();
      final app = await AppController.create(
        repository,
        clock: clock,
        resetParticipant: connection,
      );
      addTearDown(app.dispose);
      app.addTask('Synthetic local task');
      await app.flush();
      await app.updateSettings(const TimerSettings(focusMinutes: 1));
      await app.toggleTimer();
      clock.advance(const Duration(minutes: 1));
      await app.reconcile();
      expect(repository.state.sessions, hasLength(1));
      await app.toggleTimer();
      final before = repository.state;
      final writes = repository.writes;
      final run = app.timer.snapshot().toJson();
      await connection.disconnect();
      expect(repository.state, same(before));
      expect(repository.writes, writes);
      expect(repository.state.tasks.single.title, 'Synthetic local task');
      expect(repository.state.sessions, hasLength(1));
      expect(app.timer.snapshot().toJson(), run);
    },
  );

  test(
    'full reset retries calendar cleanup through the existing persisted barrier',
    () async {
      final store = MemoryCredentials();
      final connection = controller(store, FakeAuthorization());
      await connection.initialize();
      await connection.connect();
      final repository = MemoryRepository();
      final app = await AppController.create(
        repository,
        clock: FakeClock(),
        resetParticipant: connection,
      );
      addTearDown(app.dispose);
      app.addTask('Synthetic reset task');
      await app.flush();
      store.failClear = true;
      expect(await app.deleteAllLocalData(), isFalse);
      expect(connection.operationsEnabled, isFalse);
      expect(repository.state.cleanupPending, isTrue);
      expect(repository.state.tasks, isEmpty);
      store.failClear = false;
      await app.retrySave();
      expect(store.value, isNull);
      expect(app.cleanupPending, isFalse);
    },
  );

  test(
    'cancel during code exchange or identity lookup drops late provider results',
    () async {
      for (final stage in ['token', 'identity']) {
        final browser = CapturingBrowser();
        final arrived = Completer<void>();
        final pending = Completer<http.Response>();
        final provider = DesktopGoogleAuthorization(
          browser: browser,
          clientFactory: () => MockClient((request) async {
            if ((stage == 'token' && request.url.path == '/token') ||
                (stage == 'identity' &&
                    request.url.path.endsWith('/primary'))) {
              arrived.complete();
              return pending.future;
            }
            return tokenResponse();
          }),
        );
        final operation = provider.authorize(configured);
        final expectation = expectLater(
          operation,
          throwsA(isA<CalendarConnectionFailure>()),
        );
        final url = await browser.opened.future;
        await callback(url);
        await arrived.future;
        await provider.cancelPending();
        pending.complete(
          stage == 'token'
              ? tokenResponse()
              : http.Response('{"id":"late-primary","primary":true}', 200),
        );
        await expectation;
        await listenerClosed(url);
        provider.dispose();
      }
    },
  );

  test(
    'Quit during local disconnect cleanup cannot start a later revocation',
    () async {
      final auth = FakeAuthorization();
      final store = MemoryCredentials();
      final connection = CalendarConnectionController(
        configuration: configured,
        authorization: auth,
        store: store,
      );
      await connection.initialize();
      await connection.connect();
      final gate = Completer<void>();
      store.clearGate = gate;
      final disconnected = connection.disconnect();
      connection.dispose();
      gate.complete();
      await disconnected;
      expect(auth.revocations, 0);
    },
  );

  testWidgets(
    'real settings unconfigured state stays separate from demo; timer survives disconnect',
    (tester) async {
      final repository = MemoryRepository();
      final app = await AppController.create(repository, clock: FakeClock());
      final connection = CalendarConnectionController(
        configuration: const GoogleCalendarConfiguration(),
        authorization: FakeAuthorization(),
        store: MemoryCredentials(),
      );
      final desktop = DesktopController(
        app,
        FakeShell(),
        const DesktopEnvironment(
          dataDirectory: 'synthetic-profile',
          version: 'test',
          packaged: false,
          sessionState: 'unlocked',
        ),
        connection: connection,
      );
      await desktop.initialize();
      desktop.openCalendarSection(CalendarPageSection.settings);
      await tester.pumpWidget(PomaApp(controller: app, desktop: desktop));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('google-calendar-status')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('google-calendar-connect')),
            )
            .onPressed,
        isNull,
      );
      await tester.scrollUntilVisible(
        find.text('Calendar preview'),
        250,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Calendar preview'), findsOneWidget);
      final run = app.timer.runId;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('google-calendar-disconnect')),
        -250,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('google-calendar-disconnect')),
      );
      await tester.pump();
      expect(app.timer.runId, run);
      await tester.pumpWidget(const SizedBox());
      desktop.dispose();
      app.dispose();
    },
  );
}
