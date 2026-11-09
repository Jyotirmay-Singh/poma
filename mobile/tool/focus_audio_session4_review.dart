// Interactive production app with the native review profile/mutex/tray identity.
// This entry point refuses a production runner before opening any repository.
import 'package:flutter/widgets.dart';
import 'package:poma/data/windows_platform.dart';
import 'package:poma/main.dart' as production;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final host = NativeWindowsHost();
  final isolated = await host.channel.invokeMethod<bool>(
    'reviewAudioEnvironment',
  );
  final environment = await host.initialize();
  if (isolated != true ||
      environment.packaged ||
      !environment.dataDirectory.endsWith('fictional-review-profile')) {
    throw StateError('An isolated Windows review runner is required.');
  }
  production.main();
}
