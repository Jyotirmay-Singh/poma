import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class LocalStoragePreparationException implements Exception {
  const LocalStoragePreparationException();

  @override
  String toString() => 'Local storage backup exclusions could not be applied.';
}

/// Android exclusions are declared in the manifest and backup XML resources.
/// iOS requires a resource attribute on the directory containing SQLite files.
class LocalStoragePolicy {
  LocalStoragePolicy({
    TargetPlatform? platform,
    this.channel = const MethodChannel('dev.poma.poma/local_storage'),
  }) : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;
  final MethodChannel channel;

  Future<void> prepareDirectory(String directory) async {
    if (_platform != TargetPlatform.iOS) return;
    try {
      await channel.invokeMethod<void>('excludeFromBackup', {
        'directory': directory,
      });
    } on PlatformException {
      throw const LocalStoragePreparationException();
    } on MissingPluginException {
      throw const LocalStoragePreparationException();
    }
  }
}
