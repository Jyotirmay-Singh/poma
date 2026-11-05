import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'local_reset_participant.dart';
import 'focus_block_ports.dart';
import '../domain/focus_blocks.dart';

const calendarReadScopes = {
  'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  'https://www.googleapis.com/auth/calendar.events.readonly',
};
const calendarFocusScopes = {...calendarReadScopes, focusWriteScope};

class CalendarWriteReceipt {
  const CalendarWriteReceipt({required this.generation, required this.enabled});
  final String generation;
  final bool enabled;
}

class GoogleCalendarConfiguration {
  const GoogleCalendarConfiguration({
    this.clientId = '',
    this.desktopSecret = '',
    this.audience = 'external_testing',
  });
  const GoogleCalendarConfiguration.environment()
    : clientId = const String.fromEnvironment('POMA_GOOGLE_CLIENT_ID'),
      desktopSecret = const String.fromEnvironment(
        'POMA_GOOGLE_DESKTOP_CLIENT_SECRET',
      ),
      audience = const String.fromEnvironment(
        'POMA_GOOGLE_OAUTH_AUDIENCE',
        defaultValue: 'external_testing',
      );
  final String clientId, desktopSecret, audience;
  bool get configured =>
      RegExp(
        r'^\d+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$',
      ).hasMatch(clientId) &&
      !clientId.toLowerCase().contains('placeholder') &&
      const {
        'external_testing',
        'internal',
        'external_production',
      }.contains(audience) &&
      !desktopSecret.contains(RegExp(r'[\r\n]'));
}

enum CalendarConnectionStatus {
  unconfigured,
  restoring,
  disconnected,
  connecting,
  connected,
  offline,
  incompletePermissions,
  reconnectRequired,
  storageError,
  unavailable,
}

enum CalendarFailureKind {
  cancelled,
  denied,
  timeout,
  browser,
  callback,
  network,
  apiAccess,
  permissions,
  invalidGrant,
  response,
  storage,
}

/// Deliberately contains no provider exception, body, URL or credential value.
class CalendarConnectionFailure implements Exception {
  const CalendarConnectionFailure(this.kind);
  final CalendarFailureKind kind;
  @override
  String toString() => 'Calendar connection failed (${kind.name}).';
}

class CalendarAccountIdentity {
  const CalendarAccountIdentity({
    required this.clientId,
    required this.accountId,
  });
  final String clientId, accountId;
  String get accountKey =>
      sha256.convert(utf8.encode(jsonEncode([clientId, accountId]))).toString();
  Map<String, Object?> retiredJson() => {
    'version': 2,
    'retired': true,
    'clientId': clientId,
    'accountId': accountId,
  };
}

class CalendarCredential extends CalendarAccountIdentity {
  const CalendarCredential({
    required super.clientId,
    required super.accountId,
    required this.refreshToken,
    required this.scopes,
    this.focusReceipt,
  });
  final String refreshToken;
  final Set<String> scopes;
  final CalendarWriteReceipt? focusReceipt;
  Map<String, Object?> toJson() => {
    'version': focusReceipt == null ? 1 : 3,
    'clientId': clientId,
    'accountId': accountId,
    'refreshToken': refreshToken,
    'scopes': scopes.toList(),
    if (focusReceipt != null)
      'focusReceipt': {
        'version': 1,
        'generation': focusReceipt!.generation,
        'enabled': focusReceipt!.enabled,
        'clientId': clientId,
        'accountId': accountId,
        'scopes': scopes.toList(),
      },
  };
  static CalendarCredential fromJson(Object? value) {
    try {
      final map = value as Map;
      CalendarWriteReceipt? receipt;
      final r = map['focusReceipt'];
      if (map['version'] == 3 &&
          r is Map &&
          r['version'] == 1 &&
          r['clientId'] == map['clientId'] &&
          r['accountId'] == map['accountId'] &&
          r['generation'] is String &&
          validFocusUuid(r['generation'] as String) &&
          r['enabled'] is bool &&
          r['scopes'] is List) {
        final granted = Set<String>.from(r['scopes'] as List),
            actual = Set<String>.from(map['scopes'] as List);
        if (setEquals(granted, calendarFocusScopes) &&
            setEquals(actual, calendarFocusScopes)) {
          receipt = CalendarWriteReceipt(
            generation: r['generation'] as String,
            enabled: r['enabled'] as bool,
          );
        }
      }
      final result = CalendarCredential(
        clientId: map['clientId'] as String,
        accountId: map['accountId'] as String,
        refreshToken: map['refreshToken'] as String,
        scopes: Set<String>.from(map['scopes'] as List),
        focusReceipt: receipt,
      );
      if (!const {1, 3}.contains(map['version']) ||
          result.accountId.isEmpty ||
          result.refreshToken.isEmpty ||
          !result.scopes.containsAll(calendarReadScopes)) {
        throw const CalendarConnectionFailure(CalendarFailureKind.storage);
      }
      return result;
    } catch (_) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
  }
}

class CalendarStoredConnection {
  const CalendarStoredConnection(
    this.revision,
    this.credential, {
    this.retired,
    this.commitRevision = 0,
  });
  final int revision;
  final CalendarCredential? credential;
  final CalendarAccountIdentity? retired;
  final int commitRevision;
  CalendarAccountIdentity? get identity => credential ?? retired;
}

abstract interface class ProtectedCalendarStore {
  Future<CalendarStoredConnection> read();
  Future<void> write(
    int revision,
    CalendarCredential credential, {
    bool purgeAccountData = false,
  });

  /// Invalidates older writes, persists a disconnected marker, then deletes.
  Future<int> invalidateAndClear();

  /// Remove the unusable grant, retaining only verified identity and stale cache.
  Future<int> retire(int revision, CalendarAccountIdentity identity);
}

abstract interface class AtomicProtectedCalendarStore
    implements ProtectedCalendarStore {
  Future<int> commit(
    int revision,
    int expectedCommitRevision,
    CalendarCredential credential, {
    bool purgeAccountData = false,
  });
}

abstract interface class GoogleFocusAuthorization {
  Future<CalendarAuthorization> authorizeFocus(
    GoogleCalendarConfiguration config,
  );
  Future<CalendarAuthorization> refreshFocus(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  );
}

class CalendarAuthorization {
  const CalendarAuthorization({
    required this.accountId,
    required this.accessToken,
    required this.scopes,
    required this.expiresAt,
    this.refreshToken,
  });
  final String accountId, accessToken;
  final String? refreshToken;
  final Set<String> scopes;
  final DateTime expiresAt;
}

abstract interface class GoogleCalendarAuthorization {
  Future<CalendarAuthorization> authorize(GoogleCalendarConfiguration config);
  Future<CalendarAuthorization> refresh(
    GoogleCalendarConfiguration config,
    CalendarCredential credential,
  );
  Future<bool> revoke(String token);
  Future<void> cancelPending();
  void dispose();
}

/// Independent of the timer queue, repository, fixture display and event APIs.
abstract interface class CalendarReadAccess {
  Future<T?> withAccess<T>(Future<T> Function(String token) operation);
  Future<bool> refreshRejectedAccess(String token);
  void requireReconnect();
}

class CalendarConnectionController extends ChangeNotifier
    implements LocalResetParticipant, CalendarReadAccess, FocusWriteSession {
  CalendarConnectionController({
    required this.configuration,
    required this.authorization,
    required this.store,
    DateTime Function()? now,
    this.onDisconnected,
    this.writeAuthorization,
  }) : _now = now ?? DateTime.now,
       status = configuration.configured
           ? CalendarConnectionStatus.restoring
           : CalendarConnectionStatus.unconfigured;

  final GoogleCalendarConfiguration configuration;
  final GoogleCalendarAuthorization authorization;
  final GoogleCalendarAuthorization? writeAuthorization;
  final ProtectedCalendarStore store;
  final DateTime Function() _now;
  final void Function()? onDisconnected;
  CalendarConnectionStatus status;
  String? message;
  bool revoking = false;
  bool cleanupPending = false;
  bool _disposed = false;
  int _epoch = 0, _storageRevision = 0;
  int _commitRevision = 0, _writeAttempt = 0;
  Future<void> _credentialCommits = Future.value();
  CalendarWriteCapability _writeStatus = CalendarWriteCapability.disabled;
  String? writeMessage;
  bool _writeBlocked = false;
  @override
  String get focusClientId => configuration.clientId;
  @override
  String? get credentialGeneration => _credential?.focusReceipt?.generation;
  @override
  bool get focusOnline => operationsEnabled;
  @override
  bool get focusWriteEnabled =>
      !_disposed &&
      !cleanupPending &&
      !_writeBlocked &&
      !const {
        CalendarWriteCapability.granting,
        CalendarWriteCapability.verifying,
      }.contains(_writeStatus) &&
      _credential?.focusReceipt?.enabled == true;
  @override
  CalendarWriteCapability get writeCapability =>
      const {
        CalendarWriteCapability.granting,
        CalendarWriteCapability.verifying,
        CalendarWriteCapability.blocked,
      }.contains(_writeStatus)
      ? _writeStatus
      : focusWriteEnabled
      ? CalendarWriteCapability.setupRequired
      : CalendarWriteCapability.disabled;
  CalendarCredential? _credential;
  CalendarAccountIdentity? _identity;
  CalendarAuthorization? _access;
  Future<void>? _initializing, _disconnecting;
  Future<void>? _localCleanup;
  Future<String?>? _refreshing;
  bool get canConnect =>
      configuration.configured &&
      !revoking &&
      !cleanupPending &&
      status != CalendarConnectionStatus.connecting &&
      status != CalendarConnectionStatus.restoring;
  bool get operationsEnabled =>
      !_disposed &&
      status == CalendarConnectionStatus.connected &&
      _access != null &&
      _access!.expiresAt.isAfter(_now()) &&
      !cleanupPending;
  String? get accountKey => operationsEnabled ? _credential?.accountKey : null;
  @override
  String? get verifiedAccountKey => _identity?.accountKey;
  String? get verifiedAccountLabel => _identity?.accountId;
  int get sessionGeneration => _epoch;
  int get storageRevision => _storageRevision;
  bool get mayRead =>
      !_disposed &&
      configuration.configured &&
      !cleanupPending &&
      !revoking &&
      _credential != null &&
      status != CalendarConnectionStatus.connecting &&
      status != CalendarConnectionStatus.restoring &&
      status != CalendarConnectionStatus.storageError;
  bool _current(int epoch) => !_disposed && epoch == _epoch;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _restore();
  Future<void> _restore() async {
    final epoch = _epoch;
    try {
      final saved = await store.read();
      if (!_current(epoch)) return;
      _storageRevision = saved.revision;
      _commitRevision = saved.commitRevision;
      if (saved.identity != null &&
          saved.identity!.clientId != configuration.clientId) {
        final revision = await store.invalidateAndClear();
        if (!_current(epoch)) return;
        _storageRevision = revision;
      } else {
        _credential = saved.credential;
        _identity = saved.identity;
      }
      if (!configuration.configured) {
        status = CalendarConnectionStatus.unconfigured;
      } else if (_credential == null) {
        status = _identity == null
            ? CalendarConnectionStatus.disconnected
            : CalendarConnectionStatus.reconnectRequired;
      } else {
        _notify(); // Saved account cache can be restored while Google is offline.
        await accessToken();
      }
    } catch (_) {
      if (_current(epoch)) {
        status = CalendarConnectionStatus.storageError;
        message =
            'Protected calendar credentials could not be read. Disconnect to remove them, or retry after repairing storage.';
      }
    }
    _notify();
  }

  Future<void> connect() async {
    if (!canConnect || _disposed) return;
    final epoch = ++_epoch;
    _refreshing = null;
    _access = null;
    status = CalendarConnectionStatus.connecting;
    message = null;
    _notify();
    try {
      final result = await authorization.authorize(configuration);
      if (!_current(epoch)) return;
      if (!result.scopes.containsAll(calendarReadScopes)) {
        throw const CalendarConnectionFailure(CalendarFailureKind.permissions);
      }
      final previous = _credential;
      final refresh =
          result.refreshToken ??
          (previous?.clientId == configuration.clientId &&
                  previous?.accountId == result.accountId
              ? previous?.refreshToken
              : null);
      if (refresh == null || refresh.isEmpty) {
        throw const CalendarConnectionFailure(CalendarFailureKind.invalidGrant);
      }
      final credential = CalendarCredential(
        clientId: configuration.clientId,
        accountId: result.accountId,
        refreshToken: refresh,
        scopes: result.scopes,
      );
      try {
        await _persistCredential(
          credential,
          expected: previous,
          epoch: epoch,
          purge: _identity?.accountKey != credential.accountKey,
        );
      } catch (_) {
        throw const CalendarConnectionFailure(CalendarFailureKind.storage);
      }
      if (!_current(epoch)) return;
      _credential = credential;
      _identity = credential;
      _access = result;
      status = CalendarConnectionStatus.connected;
      message =
          'Connected. Choose calendars below before Poma loads event contents.';
    } catch (error) {
      if (_current(epoch)) _fail(error);
    }
    _notify();
  }

  Future<void> cancel() async {
    ++_epoch;
    _refreshing = null;
    _access = null;
    status = _credential == null
        ? (_identity == null
              ? CalendarConnectionStatus.disconnected
              : CalendarConnectionStatus.reconnectRequired)
        : CalendarConnectionStatus.offline;
    message = 'Connection cancelled. No new connection was saved.';
    _notify();
    await authorization.cancelPending();
  }

  /// Token consumers must use [withAccess] so late account responses are dropped.
  Future<String?> accessToken() {
    if (_disposed ||
        cleanupPending ||
        !configuration.configured ||
        _credential == null ||
        revoking ||
        status == CalendarConnectionStatus.connecting) {
      return Future.value(null);
    }
    if (_access != null &&
        _access!.expiresAt.isAfter(_now().add(const Duration(seconds: 60)))) {
      return Future.value(_access!.accessToken);
    }
    return _refreshing ??= _refresh(_epoch);
  }

  Future<String?> _refresh(int epoch) async {
    final credential = _credential!;
    try {
      final result = await authorization.refresh(configuration, credential);
      if (!_current(epoch) || _credential != credential) return null;
      if (result.accountId != credential.accountId ||
          !result.scopes.containsAll(calendarReadScopes)) {
        throw const CalendarConnectionFailure(CalendarFailureKind.permissions);
      }
      final updated = CalendarCredential(
        clientId: credential.clientId,
        accountId: credential.accountId,
        refreshToken: result.refreshToken ?? credential.refreshToken,
        scopes: result.scopes,
        focusReceipt: setEquals(result.scopes, calendarFocusScopes)
            ? credential.focusReceipt
            : null,
      );
      try {
        await _persistCredential(updated, expected: credential, epoch: epoch);
      } catch (_) {
        throw const CalendarConnectionFailure(CalendarFailureKind.storage);
      }
      if (!_current(epoch) || _credential != updated) return null;
      _credential = updated;
      _access = result;
      status = CalendarConnectionStatus.connected;
      message = null;
      _notify();
      return result.accessToken;
    } catch (error) {
      if (_current(epoch) && _credential != credential) {
        return _access?.accessToken;
      }
      if (_current(epoch)) {
        _access = null;
        _fail(error);
        _notify();
      }
      return null;
    } finally {
      if (_current(epoch)) _refreshing = null;
    }
  }

  @override
  Future<T?> withAccess<T>(Future<T> Function(String token) operation) async {
    final epoch = _epoch;
    final token = await accessToken();
    if (!_current(epoch) || token == null || !operationsEnabled) return null;
    final key = _credential!.accountKey;
    final result = await operation(token);
    return _current(epoch) &&
            operationsEnabled &&
            _credential?.accountKey == key
        ? result
        : null;
  }

  Future<void> _persistCredential(
    CalendarCredential candidate, {
    required CalendarCredential? expected,
    required int epoch,
    bool purge = false,
    bool Function()? valid,
  }) {
    final result = _credentialCommits.then((_) async {
      if (!_current(epoch) ||
          _credential != expected ||
          cleanupPending ||
          valid?.call() == false) {
        throw const CalendarConnectionFailure(CalendarFailureKind.cancelled);
      }
      try {
        if (store is AtomicProtectedCalendarStore) {
          _commitRevision = await (store as AtomicProtectedCalendarStore)
              .commit(
                _storageRevision,
                _commitRevision,
                candidate,
                purgeAccountData: purge,
              );
        } else {
          await store.write(
            _storageRevision,
            candidate,
            purgeAccountData: purge,
          );
        }
      } catch (error) {
        final saved = await store.read();
        if (!_current(epoch) ||
            saved.revision != _storageRevision ||
            saved.credential == null ||
            jsonEncode(saved.credential!.toJson()) !=
                jsonEncode(candidate.toJson())) {
          rethrow;
        }
        _commitRevision = saved.commitRevision;
      }
      if (!_current(epoch) || _credential != expected) {
        throw const CalendarConnectionFailure(CalendarFailureKind.cancelled);
      }
      _credential = candidate;
    });
    _credentialCommits = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> enableFocusScheduling() async {
    if (_disposed ||
        !operationsEnabled ||
        const {
          CalendarWriteCapability.granting,
          CalendarWriteCapability.verifying,
        }.contains(_writeStatus)) {
      return;
    }
    final auth = writeAuthorization;
    if (auth is! GoogleFocusAuthorization ||
        store is! AtomicProtectedCalendarStore) {
      writeMessage = 'Focus scheduling is unavailable in this build.';
      _notify();
      return;
    }
    final attempt = ++_writeAttempt,
        epoch = _epoch,
        key = _identity!.accountKey;
    _writeStatus = CalendarWriteCapability.granting;
    writeMessage = null;
    _notify();
    bool current() =>
        _current(epoch) &&
        attempt == _writeAttempt &&
        _identity?.accountKey == key;
    try {
      final candidate = await (auth as GoogleFocusAuthorization).authorizeFocus(
        configuration,
      );
      if (!current()) return;
      if (candidate.accountId != _identity!.accountId ||
          !setEquals(candidate.scopes, calendarFocusScopes) ||
          candidate.refreshToken?.isNotEmpty != true ||
          candidate.accessToken.isEmpty ||
          !candidate.expiresAt.isAfter(_now())) {
        throw const CalendarConnectionFailure(CalendarFailureKind.permissions);
      }
      _writeStatus = CalendarWriteCapability.verifying;
      _notify();
      var credential = CalendarCredential(
        clientId: configuration.clientId,
        accountId: candidate.accountId,
        refreshToken: candidate.refreshToken!,
        scopes: candidate.scopes,
      );
      final verified = await (auth as GoogleFocusAuthorization).refreshFocus(
        configuration,
        credential,
      );
      if (!current()) return;
      if (verified.accountId != candidate.accountId ||
          !setEquals(verified.scopes, calendarFocusScopes) ||
          verified.accessToken.isEmpty ||
          !verified.expiresAt.isAfter(_now())) {
        throw const CalendarConnectionFailure(CalendarFailureKind.permissions);
      }
      credential = CalendarCredential(
        clientId: configuration.clientId,
        accountId: candidate.accountId,
        refreshToken: verified.refreshToken ?? credential.refreshToken,
        scopes: verified.scopes,
        focusReceipt: CalendarWriteReceipt(
          generation: focusUuid(),
          enabled: true,
        ),
      );
      await _persistCredential(
        credential,
        expected: _credential,
        epoch: epoch,
        valid: current,
      );
      if (!current()) return;
      final committed = await store.read();
      if (!current()) return;
      if (committed.credential?.focusReceipt?.generation !=
              credential.focusReceipt!.generation ||
          committed.credential?.focusReceipt?.enabled != true ||
          !setEquals(committed.credential?.scopes, calendarFocusScopes)) {
        _writeBlocked = true;
        throw const CalendarConnectionFailure(CalendarFailureKind.storage);
      }
      _access = verified;
      _identity = credential;
      _writeBlocked = false;
      _writeStatus = CalendarWriteCapability.setupRequired;
      writeMessage =
          'Focus scheduling enabled. Review calendar setup before scheduling a block.';
    } catch (_) {
      if (current()) {
        _writeBlocked = true;
        _writeStatus = CalendarWriteCapability.disabled;
        writeMessage =
            'Focus scheduling was not enabled. Your previous calendar connection and selection are retained.';
      }
    }
    _notify();
  }

  Future<void> cancelFocusConsent() async {
    ++_writeAttempt;
    _writeBlocked = true;
    _writeStatus = CalendarWriteCapability.disabled;
    writeMessage = 'Focus scheduling setup cancelled.';
    _notify();
    await writeAuthorization?.cancelPending();
    await _credentialCommits;
    if (_credential?.focusReceipt?.enabled == true) {
      await disableFocusScheduling();
    }
  }

  void blockFocusWrites() {
    _writeBlocked = true;
    _writeStatus = CalendarWriteCapability.blocked;
    writeMessage =
        'Google refused focus scheduling. Calendar viewing is independent; review access before enabling scheduling again.';
    _notify();
  }

  Future<void> disableFocusScheduling() async {
    ++_writeAttempt;
    _writeBlocked = true;
    _writeStatus = CalendarWriteCapability.disabled;
    _notify();
    final old = _credential;
    final receipt = old?.focusReceipt;
    if (old == null || receipt == null) return;
    try {
      await _persistCredential(
        CalendarCredential(
          clientId: old.clientId,
          accountId: old.accountId,
          refreshToken: old.refreshToken,
          scopes: old.scopes,
          focusReceipt: CalendarWriteReceipt(
            generation: receipt.generation,
            enabled: false,
          ),
        ),
        expected: old,
        epoch: _epoch,
      );
      writeMessage =
          'Focus scheduling disabled on this device. Existing Google blocks are preserved.';
    } catch (_) {
      _writeStatus = CalendarWriteCapability.blocked;
      writeMessage =
          'Scheduling stopped, but saving disablement needs attention. Retry before closing Poma.';
    }
    _notify();
  }

  @override
  Future<bool> refreshRejectedAccess(String token) async {
    if (!mayRead) return false;
    // Concurrent 401s for an older token reuse the single newer refresh.
    if (_access?.accessToken == token) _access = null;
    return await accessToken() != null;
  }

  @override
  void requireReconnect() {
    if (_disposed || _credential == null) return;
    _access = null;
    _fail(const CalendarConnectionFailure(CalendarFailureKind.invalidGrant));
    _notify();
  }

  void _fail(Object error) {
    final kind = error is CalendarConnectionFailure
        ? error.kind
        : CalendarFailureKind.response;
    status = switch (kind) {
      CalendarFailureKind.permissions =>
        CalendarConnectionStatus.incompletePermissions,
      CalendarFailureKind.invalidGrant =>
        CalendarConnectionStatus.reconnectRequired,
      CalendarFailureKind.storage => CalendarConnectionStatus.storageError,
      CalendarFailureKind.network => CalendarConnectionStatus.offline,
      CalendarFailureKind.cancelled || CalendarFailureKind.denied =>
        _credential == null
            ? CalendarConnectionStatus.disconnected
            : CalendarConnectionStatus.offline,
      _ => CalendarConnectionStatus.unavailable,
    };
    if (kind == CalendarFailureKind.invalidGrant ||
        kind == CalendarFailureKind.permissions) {
      _credential = null;
      _access = null;
      _refreshing = null;
      // Retire invalid grants durably; no repeated automatic token requests.
      cleanupPending = true;
      final epoch = ++_epoch;
      unawaited(_retireCredential(epoch));
    }
    message = switch (kind) {
      CalendarFailureKind.permissions =>
        'Both read permissions are required. Reconnect and review the permissions in Google.',
      CalendarFailureKind.invalidGrant =>
        'Google authorization is no longer usable. Reconnect explicitly. External Testing access may expire after seven days; revocation or account policy can also cause this.',
      CalendarFailureKind.storage =>
        'Protected credential storage failed. Calendar access is disabled. Disconnect to clear saved credentials or repair storage before reconnecting.',
      CalendarFailureKind.network =>
        _credential == null
            ? 'Google could not be reached. No new connection was saved. Retry when online.'
            : 'Google could not be reached. Saved refresh credentials are retained. Retry when online.',
      CalendarFailureKind.apiAccess =>
        'Google Calendar API access was refused. Confirm Google Calendar API is enabled in your Google Cloud project and this account can use Calendar, then reconnect. No new connection was saved.',
      CalendarFailureKind.cancelled || CalendarFailureKind.denied =>
        'Connection was cancelled or permission was denied.',
      CalendarFailureKind.timeout =>
        'Connection timed out. Try Connect again when ready.',
      CalendarFailureKind.browser =>
        'The default browser could not be opened. Check Windows default apps and try again.',
      _ =>
        'Google connection could not be completed. Try again. Timers, tasks and history remain available.',
    };
  }

  Future<void> _retireCredential(int epoch) async {
    try {
      final identity = _identity;
      final revision = identity == null
          ? await store.invalidateAndClear()
          : await store.retire(_storageRevision, identity);
      if (_current(epoch)) {
        _storageRevision = revision;
        cleanupPending = false;
      }
    } catch (_) {
      if (_current(epoch)) {
        message =
            'Calendar access is disabled, but credential retirement failed. Disconnect to retry removal.';
      }
    }
    if (_current(epoch)) _notify();
  }

  Future<void> _retire(int epoch) async {
    try {
      final revision = await store.invalidateAndClear();
      if (_current(epoch)) {
        _storageRevision = revision;
        cleanupPending = false;
      }
    } catch (_) {
      if (_current(epoch)) {
        message =
            'Calendar access is disabled, but local credential cleanup failed. Disconnect to retry removal.';
      }
    }
    if (_current(epoch)) _notify();
  }

  /// Synchronous invalidation occurs before any disk or provider work.
  Future<void> disconnect() {
    if (_disconnecting != null) return _disconnecting!;
    final token = _credential?.refreshToken ?? _access?.accessToken;
    final epoch = ++_epoch;
    ++_writeAttempt;
    _writeBlocked = true;
    _writeStatus = CalendarWriteCapability.disabled;
    unawaited(writeAuthorization?.cancelPending());
    _credential = null;
    _identity = null;
    _access = null;
    _refreshing = null;
    status = configuration.configured
        ? CalendarConnectionStatus.disconnected
        : CalendarConnectionStatus.unconfigured;
    cleanupPending = true;
    revoking = true;
    message = 'Disconnected locally. Removing saved calendar data…';
    onDisconnected?.call();
    _notify();
    final result = _disconnect(epoch, token);
    _disconnecting = result;
    return result;
  }

  Future<void> _disconnect(int epoch, String? token) async {
    final cleanup = _localCleanup = _retire(epoch);
    try {
      await authorization.cancelPending();
    } catch (_) {
      /* Access already invalidated. */
    }
    await cleanup;
    if (!_current(epoch)) return;
    bool revoked = false;
    if (token != null) {
      try {
        revoked = await authorization
            .revoke(token)
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        /* Local disconnection does not depend on Google. */
      }
    }
    // In particular, close a timed-out revocation transport before fresh consent.
    try {
      await authorization.cancelPending();
    } catch (_) {
      /* No access restored. */
    }
    if (_current(epoch)) {
      revoking = false;
      if (!cleanupPending) {
        message = revoked
            ? 'Disconnected. Google accepted the revocation request; propagation can take time.'
            : 'Disconnected locally. Google revocation could not be confirmed (for example, while offline). Remove Poma access in Google Account → Third-party connections.';
      }
      _disconnecting = null;
      _notify();
    }
  }

  @override
  void invalidateForReset() {
    unawaited(disconnect());
  }

  @override
  Future<void> clearForReset() async {
    if (_localCleanup == null || cleanupPending && _disconnecting == null) {
      unawaited(disconnect());
    }
    await _localCleanup;
    if (cleanupPending) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_epoch;
    ++_writeAttempt;
    writeAuthorization?.dispose();
    authorization.dispose();
    super.dispose();
  }
}
