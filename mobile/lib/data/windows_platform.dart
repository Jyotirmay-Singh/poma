import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../application/desktop_controller.dart';
import '../application/calendar_presentation_ports.dart';
import '../domain/calendar_data.dart';
import '../application/local_alerts.dart';
import '../application/local_repository.dart';
import '../domain/alert_state.dart';
import '../domain/desktop_preferences.dart';
import '../domain/models.dart';
import 'local_repository.dart';

class NativeWindowsHost implements DesktopShell, CalendarPresentationPlatform {
  NativeWindowsHost({MethodChannel? channel})
    : channel =
          channel ?? const MethodChannel('dev.poma.poma/windows_desktop') {
    this.channel.setMethodCallHandler(_handle);
  }
  final MethodChannel channel;
  Future<void> Function(String, Map<String, Object?>)? _onEvent;
  final List<(String, Map<String, Object?>)> _waiting = [];
  void Function()? onAlertEvent;

  @override
  set onEvent(Future<void> Function(String, Map<String, Object?>)? handler) {
    _onEvent = handler;
    if (handler != null) {
      for (final event in _waiting) {
        unawaited(handler(event.$1, event.$2));
      }
      _waiting.clear();
    }
  }

  Future<void> _handle(MethodCall call) async {
    if (call.method == 'alertsChanged') {
      onAlertEvent?.call();
      return;
    }
    final args = call.arguments is Map
        ? Map<String, Object?>.from(call.arguments as Map)
        : <String, Object?>{};
    final handler = _onEvent;
    if (handler != null) {
      await handler(call.method, args);
    } else if (call.method == 'quit') {
      // Startup failures still leave a usable Close/Quit path.
      await exit();
    } else if (_waiting.length < 32) {
      _waiting.add((call.method, args));
    }
  }

  Future<DesktopEnvironment> initialize() async {
    final data = await channel.invokeMapMethod<String, Object?>('environment');
    if (data?['dataDirectory'] is! String) {
      throw const FileSystemException('Windows local data path unavailable.');
    }
    return DesktopEnvironment(
      dataDirectory: data!['dataDirectory'] as String,
      version: data['version'] as String? ?? 'Development build',
      packaged: data['packaged'] == true,
      visible: data['visible'] == true,
      sessionState: data['sessionState'] as String? ?? 'unknown',
    );
  }

  Future<SqliteRepository> repository(DesktopEnvironment environment) async {
    final directory = Directory(
      path.join(environment.dataDirectory, 'databases'),
    );
    try {
      await directory.create(recursive: true);
    } on FileSystemException catch (error) {
      // Directory creation precedes the repository's SQLite error boundary.
      // Keep paths and native error text out of the application error contract.
      final full = const [39, 112].contains(error.osError?.errorCode);
      throw StorageFailure(
        full ? StorageFailureKind.full : StorageFailureKind.unreadable,
      );
    }
    sqfliteFfiInit();
    return SqliteRepository(
      factory: databaseFactoryFfi,
      databasePath: path.join(directory.path, 'poma.db'),
    );
  }

  @override
  Future<void> configure(DesktopPreferences preferences) =>
      channel.invokeMethod<void>('configure', preferences.toJson());
  @override
  Future<void> publish(Map<String, Object?> snapshot) =>
      channel.invokeMethod<void>('publish', snapshot);
  @override
  Future<void> armDeadline(TimerSnapshot? snapshot) =>
      channel.invokeMethod<void>(
        'armDeadline',
        snapshot == null
            ? null
            : {
                'runId': snapshot.runId,
                'elapsedDeadlineMicros': snapshot.elapsedDeadlineMicros,
              },
      );
  @override
  Future<void> showMain() => channel.invokeMethod<void>('showMain');
  @override
  Future<void> showPopup({bool preview = false}) =>
      channel.invokeMethod<void>('showPopup', {'preview': preview});
  @override
  Future<Map<String, String>> formatCalendar(
    List<DateTime> instants,
    List<CalendarDate> dates,
  ) async => Map<String, String>.from(
    await channel.invokeMapMethod<String, String>('calendarFormat', {
          'times': instants.map((i) => i.microsecondsSinceEpoch).toList(),
          'dates': dates.map((d) => '$d').toList(),
        }) ??
        const {},
  );
  @override
  Future<void> openCalendarLink(String url, String kind, int generation) =>
      channel.invokeMethod<void>('calendarOpenLink', {
        'url': url,
        'kind': kind,
        'generation': generation,
      });
  @override
  Future<String> startupState() async =>
      await channel.invokeMethod<String>('startupState') ?? 'unavailable';
  @override
  Future<String> setStartup(bool enabled) async =>
      await channel.invokeMethod<String>('setStartup', enabled) ??
      'unavailable';
  @override
  Future<void> exit() => channel.invokeMethod<void>('exit');
}

class WindowsLocalAlerts implements LocalAlerts, CompletionPresenter {
  WindowsLocalAlerts(this.host);
  final NativeWindowsHost host;

  @override
  Future<void> initialize({
    required String? databasePath,
    required void Function() onEvent,
  }) async {
    host.onAlertEvent = onEvent;
    await host.channel.invokeMethod<void>('initializeAlerts');
  }

  @override
  Future<AlertAvailability> synchronize(AlertState state) async {
    final value = await host.channel.invokeMethod<String>('synchronizeAlerts', {
      'enabled': state.enabled,
      'retiredIds': state.retiredIds,
    });
    return AlertAvailability.values.byName(value ?? 'unavailable');
  }

  @override
  Future<void> presentCompletion(AlertRequest request) =>
      host.channel.invokeMethod<void>('showCompletion', {
        'runId': request.runId,
        'generation': request.generation,
        'notificationId': request.notificationId,
        'focus': request.phase == FocusPhase.focus,
      });
  @override
  Future<void> requestPermission() async {}
  @override
  Future<void> openSettings() =>
      host.channel.invokeMethod<void>('notificationSettings');
  @override
  Future<void> requestExactAccess() async {}
  @override
  Future<List<AlertResponse>> responses() async {
    final values =
        await host.channel.invokeListMethod<Object?>('responses') ?? [];
    return values.map((value) {
      final map = Map<String, Object?>.from(value as Map);
      return AlertResponse(
        map['runId'] as String,
        map['generation'] as int,
        map['action'] as String,
      );
    }).toList();
  }

  @override
  Future<void> acknowledgeResponse(AlertResponse response) =>
      host.channel.invokeMethod<void>('acknowledgeResponse', {
        'runId': response.runId,
        'generation': response.generation,
        'action': response.action,
      });
  @override
  Future<void> clearForReset() =>
      host.channel.invokeMethod<void>('clearForReset');
  @override
  void dispose() => host.onAlertEvent = null;
}
