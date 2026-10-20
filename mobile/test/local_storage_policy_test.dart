import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/data/local_storage_policy.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.poma.poma/local_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test(
    'iOS excludes the actual database directory through the native bridge',
    () async {
      MethodCall? received;
      messenger.setMockMethodCallHandler(channel, (call) async {
        received = call;
        return null;
      });
      await LocalStoragePolicy(
        platform: TargetPlatform.iOS,
      ).prepareDirectory('/sandbox/Documents');
      expect(received?.method, 'excludeFromBackup');
      expect(received?.arguments, {'directory': '/sandbox/Documents'});
    },
  );

  test('native exclusion failures remain visible to startup', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'backup_exclusion_failed');
    });
    await expectLater(
      LocalStoragePolicy(
        platform: TargetPlatform.iOS,
      ).prepareDirectory('/sandbox/Documents'),
      throwsA(isA<LocalStoragePreparationException>()),
    );
  });

  test('an unavailable iOS bridge cannot silently enable backups', () async {
    await expectLater(
      LocalStoragePolicy(
        platform: TargetPlatform.iOS,
      ).prepareDirectory('/sandbox/Documents'),
      throwsA(isA<LocalStoragePreparationException>()),
    );
  });

  test(
    'Android policy uses manifest rules without a native channel call',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        fail('Android must not call the iOS backup bridge');
      });
      await LocalStoragePolicy(
        platform: TargetPlatform.android,
      ).prepareDirectory('/data/databases');
    },
  );
}
