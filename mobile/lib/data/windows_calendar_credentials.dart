import 'dart:convert';

import 'package:flutter/services.dart';

import '../application/calendar_connection_controller.dart';
import 'google_calendar_authorization.dart';

class WindowsCalendarCredentials
    implements AtomicProtectedCalendarStore, CalendarBrowser {
  WindowsCalendarCredentials(this.channel);
  final MethodChannel channel;
  @override
  Future<CalendarStoredConnection> read() async {
    try {
      final result = await channel.invokeMapMethod<String, Object?>(
        'calendarCredentialsRead',
      );
      final value = result?['credential'];
      final decoded = value == null ? null : jsonDecode(value as String);
      if (decoded is Map &&
          decoded['version'] == 2 &&
          decoded['retired'] == true) {
        final identity = CalendarAccountIdentity(
          clientId: decoded['clientId'] as String,
          accountId: decoded['accountId'] as String,
        );
        if (identity.clientId.isEmpty || identity.accountId.isEmpty) {
          throw const FormatException('Invalid saved identity.');
        }
        return CalendarStoredConnection(
          result!['revision'] as int,
          null,
          retired: identity,
          commitRevision: result['commitRevision'] as int? ?? 0,
        );
      }
      return CalendarStoredConnection(
        result!['revision'] as int,
        value == null ? null : CalendarCredential.fromJson(decoded),
        commitRevision: result['commitRevision'] as int? ?? 0,
      );
    } catch (_) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
  }

  @override
  Future<int> retire(int revision, CalendarAccountIdentity identity) async {
    try {
      return (await channel.invokeMethod<int>('calendarCredentialsRetire', {
        'revision': revision,
        'identity': jsonEncode(identity.retiredJson()),
      }))!;
    } catch (_) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
  }

  @override
  Future<int> commit(
    int revision,
    int expectedCommitRevision,
    CalendarCredential credential, {
    bool purgeAccountData = false,
  }) async {
    try {
      return (await channel.invokeMethod<int>('calendarCredentialsCommit', {
        'revision': revision,
        'commitRevision': expectedCommitRevision,
        'credential': jsonEncode(credential.toJson()),
        'purgeAccountData': purgeAccountData,
      }))!;
    } catch (_) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
  }

  @override
  Future<void> write(
    int revision,
    CalendarCredential credential, {
    bool purgeAccountData = false,
  }) async {
    try {
      await channel.invokeMethod<void>('calendarCredentialsWrite', {
        'revision': revision,
        'credential': jsonEncode(credential.toJson()),
        'purgeAccountData': purgeAccountData,
      });
    } catch (_) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
  }

  @override
  Future<int> invalidateAndClear() async {
    try {
      return (await channel.invokeMethod<int>('calendarCredentialsClear'))!;
    } catch (_) {
      throw const CalendarConnectionFailure(CalendarFailureKind.storage);
    }
  }

  @override
  Future<void> openAuthorization(Uri uri) async {
    try {
      await channel.invokeMethod<void>(
        'calendarAuthorizationBrowser',
        uri.toString(),
      );
    } catch (_) {
      throw const CalendarConnectionFailure(CalendarFailureKind.browser);
    }
  }
}
