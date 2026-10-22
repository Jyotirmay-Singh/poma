import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/data/launch_reporter.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.poma.poma/launch_metrics');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'one Android call reports usability without awaiting any timer work',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      await reportFirstUsableFrame();
      expect(calls, ['firstUsableFrame']);
    },
  );

  test('missing or failed launch reporting cannot fail startup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await reportFirstUsableFrame();
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'unsupported');
    });
    await reportFirstUsableFrame();
  });

  test('other platforms perform no Android launch call', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messenger.setMockMethodCallHandler(channel, (_) async {
      fail('Android-only marker invoked on iOS');
    });
    await reportFirstUsableFrame();
  });

  testWidgets(
    'usability waits for restored UI and is not reported on rebuild',
    (tester) async {
      final repository = _DelayedInitialRepository();
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return null;
      });
      await tester.pumpWidget(
        PomaLoader(
          repositoryFactory: () => repository,
          clockFactory: FakeClock.new,
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(calls, isEmpty);

      repository.ready.complete();
      await tester.pumpAndSettle();
      expect(find.byType(PomaApp), findsOneWidget);
      expect(calls, ['firstUsableFrame']);
      await tester.scrollUntilVisible(find.text('Start focus'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Start focus'), findsOneWidget);
      final app = tester.widget<PomaApp>(find.byType(PomaApp));
      app.controller.addTask('Synthetic launch test');
      await tester.pumpAndSettle();
      expect(calls, ['firstUsableFrame']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

class _DelayedInitialRepository extends MemoryRepository {
  final ready = Completer<void>();

  @override
  Future<SavedState> loadInitial() async {
    await ready.future;
    return super.loadInitial();
  }
}
