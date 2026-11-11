import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class PlannerTime {
  PlannerTime({this.channel, this.fixedZone});
  final MethodChannel? channel;
  final String? fixedZone;
  static Future<void>? _initializing;
  static Map<String, String> _windowsZones = {};

  Future<void> initialize() => _initializing ??= _initialize();

  static Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    final value =
        jsonDecode(
              await rootBundle.loadString(
                'assets/timezones/windows-zones.json',
              ),
            )
            as Map;
    _windowsZones = value.map((k, v) => MapEntry(k as String, v as String));
  }

  Future<String?> deviceZone() async {
    await initialize();
    if (fixedZone != null) return fixedZone;
    try {
      final value = await channel?.invokeMapMethod<String, Object?>(
        'focusTimeZone',
      );
      final name = value?['zone'] as String?;
      if (name != null && _windowsZones.containsKey(name)) {
        final mapped = _windowsZones[name]!;
        final zone = tz.getLocation(mapped);
        final year = DateTime.now().year;
        if (value?['daylightDisabled'] == true &&
            tz.TZDateTime(zone, year, 1, 15).timeZoneOffset !=
                tz.TZDateTime(zone, year, 7, 15).timeZoneOffset) {
          return null;
        }
        return mapped;
      }
      if (DateTime.now().timeZoneOffset == Duration.zero) return 'Etc/UTC';
    } catch (_) {
      // A missing mapping is an explicit timezone choice in the editor.
    }
    return null;
  }

  List<String> get zones => tz.timeZoneDatabase.locations.keys.toList()..sort();
}
