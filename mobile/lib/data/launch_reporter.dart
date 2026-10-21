import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One platform launch marker, after restored timer controls have painted.
/// It schedules no recurring work and is not a timer or persistence dependency.
Future<void> reportFirstUsableFrame() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await const MethodChannel(
      'dev.poma.poma/launch_metrics',
    ).invokeMethod<void>('firstUsableFrame');
  } on PlatformException {
    // Measurement failure must never prevent using the offline app.
  } on MissingPluginException {
    // Host tests and other embeddings need not implement launch reporting.
  }
}
