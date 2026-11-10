import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:oauth2/oauth2.dart' as oauth2;

import '../application/calendar_connection_controller.dart';

abstract interface class CalendarBrowser {
  Future<void> openAuthorization(Uri uri);
}

const _authorizationEndpoint = 'https://accounts.google.com/o/oauth2/v2/auth';
final _tokenEndpoint = Uri.https('oauth2.googleapis.com', '/token');
final _identityEndpoint = Uri.https(
  'www.googleapis.com',
  '/calendar/v3/users/me/calendarList/primary',
  {'fields': 'id,primary'},
);

/// Only production Google endpoints are compiled in. Tests inject transport,
/// browser and durations, never alternate endpoints into a distributed build.
class DesktopGoogleAuthorization
    implements
        GoogleCalendarAuthorization,
        GoogleFocusAuthorization,
        GoogleCapabilityAuthorization {
  DesktopGoogleAuthorization({
    required this.browser,
    http.Client Function()? clientFactory,
    this.callbackTimeout = const Duration(minutes: 5),
    this.requestTimeout = const Duration(seconds: 30),
  }) : _clientFactory = clientFactory ?? http.Client.new;
  final CalendarBrowser browser;
  final http.Client Function() _clientFactory;
  final Duration callbackTimeout, requestTimeout;
  final Set<http.Client> _clients = {};
  _LoopbackAttempt? _attempt;
  int _epoch = 0;
  bool _disposed = false;

  String _random(int bytes) {
    final random = Random.secure();
    return base64Url
        .encode(List.generate(bytes, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  void _check(int epoch) {
    if (_disposed || epoch != _epoch) {
      throw const CalendarConnectionFailure(CalendarFailureKind.cancelled);
    }
  }

  @override
  Future<CalendarAuthorization> authorize(GoogleCalendarConfiguration config) =>
      _authorize(config, focus: false);

  @override
  Future<CalendarAuthorization> authorizeFocus(
    GoogleCalendarConfiguration config,
  ) => _authorize(config, focus: true);
  @override
  Future<CalendarAuthorization> authorizeScopes(
    GoogleCalendarConfiguration config,
    Set<String> scopes,
  ) {
    if (!approvedCalendarScopes(scopes)) {
      throw const CalendarConnectionFailure(CalendarFailureKind.permissions);
    }
    return _authorize(config, focus: true, requestedScopes: scopes);
  }

  Future<CalendarAuthorization> _authorize(
    GoogleCalendarConfiguration config, {
    required bool focus,
    Set<String>? requestedScopes,
  }) async {
    final scopes =
        requestedScopes ?? (focus ? calendarFocusScopes : calendarReadScopes);
    if (!config.configured || _disposed || _attempt != null) {
      throw const CalendarConnectionFailure(CalendarFailureKind.response);
    }
    final epoch = ++_epoch;
    _LoopbackAttempt? attempt;
    _GoogleTokenClient? transport;
    oauth2.AuthorizationCodeGrant? grant;
    try {
      attempt = await _LoopbackAttempt.bind(_random(32));
      _check(epoch);
      _attempt = attempt;
      transport = _GoogleTokenClient(
        _clientFactory(),
        requestTimeout,
        requiredScopes: scopes,
        exact: focus,
        requireRefresh: focus,
      );
      _clients.add(transport);
      grant = oauth2.AuthorizationCodeGrant(
        config.clientId,
        Uri.parse(_authorizationEndpoint),
        _tokenEndpoint,
        secret: config.desktopSecret.isEmpty ? null : config.desktopSecret,
        basicAuth: false,
        httpClient: transport,
        codeVerifier: _random(64),
      );
      final url = grant.getAuthorizationUrl(
        attempt.redirect,
        scopes: scopes,
        state: attempt.state,
      );
      final browserUrl = url.replace(
        queryParameters: {
          ...url.queryParameters,
          'access_type': 'offline',
          'prompt': 'consent select_account',
        },
      );
      try {
        await browser.openAuthorization(browserUrl).timeout(requestTimeout);
      } catch (_) {
        throw const CalendarConnectionFailure(CalendarFailureKind.browser);
      }
      _check(epoch);
      final parameters = await attempt.result.timeout(callbackTimeout);
      _check(epoch);
      // Close even before exchange: no authorization listener remains resident.
      await attempt.close();
      final client = await grant.handleAuthorizationResponse(parameters);
      _check(epoch);
      final account = await _identify(client);
      _check(epoch);
      return _result(client.credentials, account);
    } catch (error) {
      throw _safe(error);
    } finally {
      await attempt?.close();
      if (identical(_attempt, attempt)) _attempt = null;
      grant?.close();
      transport?.close();
      _clients.remove(transport);
    }
  }

  @override
  Future<CalendarAuthorization> refresh(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  ) => _refreshCredential(config, credential, focus: false);
  @override
  Future<CalendarAuthorization> refreshFocus(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  ) => _refreshCredential(config, credential, focus: true);
  @override
  Future<CalendarAuthorization> refreshVerified(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  ) => _refreshCredential(
    config,
    credential,
    focus: true,
    requestedScopes: credential.scopes,
  );
  Future<CalendarAuthorization> _refreshCredential(
    GoogleCalendarConfiguration config,
    CalendarCredential credential, {
    required bool focus,
    Set<String>? requestedScopes,
  }) async {
    final epoch = _epoch;
    final transport = _GoogleTokenClient(
      _clientFactory(),
      requestTimeout,
      verifiedScopes: credential.scopes,
      requiredScopes:
          requestedScopes ?? (focus ? calendarFocusScopes : calendarReadScopes),
      exact: focus,
    );
    _clients.add(transport);
    try {
      _check(epoch);
      if (!config.configured || credential.clientId != config.clientId) {
        throw const CalendarConnectionFailure(CalendarFailureKind.invalidGrant);
      }
      final credentials =
          await oauth2.Credentials(
            '',
            refreshToken: credential.refreshToken,
            tokenEndpoint: _tokenEndpoint,
            scopes: credential.scopes,
          ).refresh(
            identifier: config.clientId,
            secret: config.desktopSecret.isEmpty ? null : config.desktopSecret,
            basicAuth: false,
            httpClient: transport,
          );
      _check(epoch);
      String account = credential.accountId;
      if (focus) {
        final client = oauth2.Client(
          credentials,
          identifier: config.clientId,
          httpClient: transport,
        );
        account = await _identify(client);
        _check(epoch);
      }
      return _result(credentials, account);
    } catch (error) {
      throw _safe(error);
    } finally {
      transport.close();
      _clients.remove(transport);
    }
  }

  CalendarAuthorization _result(
    oauth2.Credentials credentials,
    String account,
  ) {
    final scopes = credentials.scopes?.toSet() ?? {};
    if (!scopes.containsAll(calendarReadScopes) ||
        credentials.expiration == null) {
      throw const CalendarConnectionFailure(CalendarFailureKind.permissions);
    }
    return CalendarAuthorization(
      accountId: account,
      accessToken: credentials.accessToken,
      refreshToken: credentials.refreshToken,
      scopes: scopes,
      expiresAt: credentials.expiration!,
    );
  }

  Future<String> _identify(http.Client client) async {
    final response = await client
        .get(_identityEndpoint)
        .timeout(requestTimeout);
    if (response.statusCode == 401) {
      throw const CalendarConnectionFailure(CalendarFailureKind.invalidGrant);
    }
    if (response.statusCode == 403 || response.statusCode == 404) {
      throw const CalendarConnectionFailure(CalendarFailureKind.apiAccess);
    }
    if (response.statusCode != 200) {
      throw const CalendarConnectionFailure(CalendarFailureKind.response);
    }
    final body = jsonDecode(response.body);
    if (body is! Map ||
        body['primary'] != true ||
        body['id'] is! String ||
        (body['id'] as String).isEmpty) {
      throw const CalendarConnectionFailure(CalendarFailureKind.response);
    }
    return body['id'] as String;
  }

  @override
  Future<bool> revoke(String token) async {
    if (_disposed) return false;
    final client = _clientFactory();
    _clients.add(client);
    try {
      final request =
          http.Request('POST', Uri.https('oauth2.googleapis.com', '/revoke'))
            ..followRedirects = false
            ..bodyFields = {'token': token};
      return await client
          .send(request)
          .then((response) async {
            await response.stream.drain<void>();
            return response.statusCode == 200;
          })
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      return false;
    } finally {
      client.close();
      _clients.remove(client);
    }
  }

  CalendarConnectionFailure _safe(Object error) {
    if (error is CalendarConnectionFailure) return error;
    if (error is TimeoutException) {
      return const CalendarConnectionFailure(CalendarFailureKind.timeout);
    }
    if (error is oauth2.AuthorizationException) {
      return CalendarConnectionFailure(switch (error.error) {
        'invalid_grant' => CalendarFailureKind.invalidGrant,
        'access_denied' => CalendarFailureKind.denied,
        _ => CalendarFailureKind.response,
      });
    }
    if (error is SocketException || error is http.ClientException) {
      return const CalendarConnectionFailure(CalendarFailureKind.network);
    }
    return const CalendarConnectionFailure(CalendarFailureKind.response);
  }

  @override
  Future<void> cancelPending() async {
    ++_epoch;
    for (final client in _clients.toList()) {
      client.close();
    }
    await _attempt?.cancel();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(cancelPending());
  }
}

/// Check raw grant evidence *before* oauth2 can default scopes to the request.
/// It is recreated for every exchange/refresh, including refresh-token omission.
class _GoogleTokenClient extends http.BaseClient {
  _GoogleTokenClient(
    this.inner,
    this.timeout, {
    this.verifiedScopes,
    this.requiredScopes = calendarReadScopes,
    this.exact = false,
    this.requireRefresh = false,
  });
  final http.Client inner;
  final Duration timeout;
  final Set<String>? verifiedScopes;
  final Set<String> requiredScopes;
  final bool exact, requireRefresh;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.followRedirects = false;
    final response = await inner
        .send(request)
        .then(http.Response.fromStream)
        .timeout(timeout);
    if (request.url == _tokenEndpoint && response.statusCode == 200) {
      final body = jsonDecode(response.body);
      if (body is! Map ||
          body['access_token'] is! String ||
          (body['access_token'] as String).isEmpty ||
          body['expires_in'] is! int ||
          (body['expires_in'] as int) <= 0 ||
          (body.containsKey('refresh_token') &&
              (body['refresh_token'] is! String ||
                  (body['refresh_token'] as String).isEmpty))) {
        throw const CalendarConnectionFailure(CalendarFailureKind.response);
      }
      final rawScopes = body['scope'];
      final scopes = rawScopes is String && rawScopes.isNotEmpty
          ? rawScopes.split(' ').toSet()
          : rawScopes == null
          ? verifiedScopes
          : null;
      if (scopes == null ||
          !scopes.containsAll(requiredScopes) ||
          exact && (scopes.length != requiredScopes.length) ||
          requireRefresh &&
              (body['refresh_token'] is! String ||
                  (body['refresh_token'] as String).isEmpty)) {
        throw const CalendarConnectionFailure(CalendarFailureKind.permissions);
      }
    }
    if (response.statusCode >= 500 || response.statusCode == 429) {
      throw const CalendarConnectionFailure(CalendarFailureKind.network);
    }
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() => inner.close();
}

class _LoopbackAttempt {
  _LoopbackAttempt(this.server, this.state) {
    result.ignore();
    server.listen(_receive, onError: (Object _) => cancel());
  }
  static Future<_LoopbackAttempt> bind(String state) async => _LoopbackAttempt(
    await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false),
    state,
  );
  final HttpServer server;
  final String state;
  final _completion = Completer<Map<String, String>>();
  Future<Map<String, String>> get result => _completion.future;
  Uri get redirect =>
      Uri.parse('http://127.0.0.1:${server.port}/oauth2/callback');
  Future<void>? _closing;
  bool _finished = false;
  Future<void> _receive(HttpRequest request) async {
    try {
      final all = request.uri.queryParametersAll;
      final valid =
          !_finished &&
          request.method == 'GET' &&
          request.headers.value(HttpHeaders.hostHeader) ==
              '127.0.0.1:${server.port}' &&
          (!request.uri.hasAuthority ||
              (request.uri.scheme == 'http' &&
                  request.uri.host == '127.0.0.1' &&
                  request.uri.port == server.port &&
                  request.uri.userInfo.isEmpty)) &&
          request.connectionInfo?.remoteAddress.isLoopback == true &&
          request.uri.path == '/oauth2/callback' &&
          all.values.every((values) => values.length == 1) &&
          all['state']?.single == state &&
          ((all['code']?.single.isNotEmpty == true &&
                  !all.containsKey('error')) ||
              (all['error']?.single.isNotEmpty == true &&
                  !all.containsKey('code')));
      request.response
        ..statusCode = valid ? HttpStatus.ok : HttpStatus.badRequest
        ..headers.set('Cache-Control', 'no-store')
        ..headers.set('Referrer-Policy', 'no-referrer')
        ..headers.set('Content-Security-Policy', "default-src 'none'")
        ..headers.contentType = ContentType.text
        ..write(
          valid
              ? 'Return to Poma. You may close this browser tab.'
              : 'This authorization return was not accepted.',
        );
      if (valid) {
        _finished = true;
      }
      await request.response.close();
      if (valid && !_completion.isCompleted) {
        _completion.complete({
          'state': state,
          if (all.containsKey('code')) 'code': all['code']!.single,
          if (all.containsKey('error')) 'error': all['error']!.single,
        });
      }
    } catch (_) {
      // Do not expose request URI, callback parameters, or native exception text.
      try {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
      } catch (_) {
        /* Socket closed. */
      }
    }
  }

  Future<void> close() => _closing ??= server.close(force: true).then((_) {});
  Future<void> cancel() {
    _finished = true;
    if (!_completion.isCompleted) {
      _completion.completeError(
        const CalendarConnectionFailure(CalendarFailureKind.cancelled),
      );
    }
    return close();
  }
}
