import 'dart:convert';
import 'package:flutter/services.dart';
import '../application/calendar_read_ports.dart';
import '../application/calendar_reminder_ports.dart';

class WindowsCalendarReminders
    implements CalendarReminderStore, CalendarReminderPlatform {
  const WindowsCalendarReminders(this.channel);
  final MethodChannel channel;
  @override
  Future<Map<String, Object?>?> read(CalendarCacheLease lease) async {
    final document = await channel.invokeMethod<String>(
      'calendarReminderRead',
      lease.toJson(),
    );
    return document == null
        ? null
        : Map<String, Object?>.from(jsonDecode(document) as Map);
  }

  @override
  Future<void> write(CalendarCacheLease lease, Map<String, Object?> document) =>
      channel.invokeMethod<void>('calendarReminderWrite', {
        ...lease.toJson(),
        'document': jsonEncode(document),
      });
  @override
  Future<String> availability() async =>
      await channel.invokeMethod<String>('calendarReminderAvailability') ??
      'unavailable';
  @override
  Future<void> replace(int generation, Set<String> tokens) =>
      channel.invokeMethod<void>('calendarReminderReplace', {
        'generation': generation,
        'tokens': tokens.toList(),
      });
  @override
  Future<void> arm(int generation, DateTime? deadline) =>
      channel.invokeMethod<void>('calendarReminderArm', {
        'generation': generation,
        'deadline': deadline?.microsecondsSinceEpoch,
      });
  @override
  Future<void> show(int generation, String token, DateTime expires) =>
      channel.invokeMethod<void>('calendarReminderShow', {
        'generation': generation,
        'token': token,
        'expires': expires.microsecondsSinceEpoch,
      });
  @override
  Future<List<Map<String, Object?>>> responses() async =>
      (await channel.invokeListMethod<Object?>('calendarReminderResponses') ??
              [])
          .map((e) => Map<String, Object?>.from(e as Map))
          .toList();
  @override
  Future<void> acknowledge(String token, String action) =>
      channel.invokeMethod<void>('calendarReminderAcknowledge', {
        'token': token,
        'action': action,
      });
}
