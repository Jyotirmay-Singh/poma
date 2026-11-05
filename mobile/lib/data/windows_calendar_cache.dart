import 'dart:convert';
import 'package:flutter/services.dart';
import '../application/calendar_read_ports.dart';
import '../domain/calendar_data.dart';

class WindowsCalendarCache implements CalendarCacheStore {
  const WindowsCalendarCache(this.channel);
  final MethodChannel channel;
  @override
  Future<CalendarCacheLease> open(int revision, String accountKey) async {
    try {
      final scope = await channel.invokeMethod<int>('calendarCacheBind', {
        'revision': revision,
        'accountKey': accountKey,
      });
      return CalendarCacheLease(revision, scope!, accountKey);
    } catch (_) {
      throw const CalendarReadFailure(CalendarReadFailureKind.storage);
    }
  }

  @override
  Future<CalendarAccountData?> read(CalendarCacheLease lease) async {
    try {
      final json = await channel.invokeMethod<String>(
        'calendarCacheRead',
        lease.toJson(),
      );
      return json == null
          ? null
          : CalendarAccountData.fromJson(
              jsonDecode(json) as Map,
              lease.accountKey,
            );
    } catch (_) {
      throw const CalendarReadFailure(CalendarReadFailureKind.storage);
    }
  }

  @override
  Future<void> write(CalendarCacheLease lease, CalendarAccountData data) async {
    try {
      if (data.accountKey != lease.accountKey) {
        throw const FormatException('Account mismatch.');
      }
      final document = jsonEncode(data.toJson());
      if (utf8.encode(document).length > 16 * 1024 * 1024) {
        throw const FormatException('Cache limit.');
      }
      await channel.invokeMethod<void>('calendarCacheWrite', {
        ...lease.toJson(),
        'document': document,
      });
    } catch (_) {
      throw const CalendarReadFailure(CalendarReadFailureKind.storage);
    }
  }

  @override
  Future<void> invalidate() async {
    try {
      await channel.invokeMethod<void>('calendarCacheInvalidate');
    } catch (_) {
      throw const CalendarReadFailure(CalendarReadFailureKind.storage);
    }
  }
}
