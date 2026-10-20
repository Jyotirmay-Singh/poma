import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../application/local_alerts.dart';
import '../domain/alert_state.dart';

/// The package owns permission UI; native one-shot adapters own timer triggers.
/// No package-private channels, notification models or background isolates.
class NativeLocalAlerts implements LocalAlerts {
  NativeLocalAlerts({
    MethodChannel? channel,
    FlutterLocalNotificationsPlugin? plugin,
  }) : _channel = channel ?? const MethodChannel('dev.poma.poma/local_alerts'),
       _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final MethodChannel _channel;
  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> initialize({
    required String? databasePath,
    required void Function() onEvent,
  }) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') onEvent();
    });
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_poma'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    await _channel.invokeMethod<void>('configure', {
      'databasePath': databasePath,
    });
  }

  @override
  Future<AlertAvailability> synchronize(AlertState state) async {
    final allowed = defaultTargetPlatform == TargetPlatform.android
        ? await _android?.areNotificationsEnabled()
        : (await _ios?.checkPermissions())?.isEnabled;
    final result = await _channel.invokeMethod<String>('synchronize', {
      'state': jsonEncode(state.toJson()),
      'permitted': allowed == true,
    });
    return AlertAvailability.values.byName(result ?? 'unavailable');
  }

  @override
  Future<void> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _android?.requestNotificationsPermission();
    } else {
      await _ios?.requestPermissions(alert: true, sound: true);
    }
  }

  @override
  Future<void> openSettings() async => _plugin.openAppNotificationSettings();
  @override
  Future<void> requestExactAccess() async =>
      _android?.requestExactAlarmsPermission();

  @override
  Future<List<AlertResponse>> responses() async {
    final values = await _channel.invokeListMethod<Object?>('responses') ?? [];
    return values.map((value) {
      final map = Map<String, dynamic>.from(value as Map);
      return AlertResponse(
        map['runId'] as String,
        map['generation'] as int,
        map['action'] as String,
      );
    }).toList();
  }

  @override
  Future<void> acknowledgeResponse(AlertResponse response) async =>
      _channel.invokeMethod<void>('acknowledgeResponse', {'key': response.key});
  @override
  void dispose() => _channel.setMethodCallHandler(null);
}
