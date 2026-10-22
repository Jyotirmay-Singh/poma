import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/main.dart';
import 'package:poma/release_metadata.dart';
import 'package:poma/ui/legal_screen.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled policy explains backup metadata and logical deletion offline',
    () async {
      final policy = await rootBundle.loadString('assets/legal/privacy.txt');
      final notices = await rootBundle.loadString('assets/legal/notices.txt');
      expect(policy, contains('UserDefaults'));
      expect(policy, contains('not guaranteed forensic erasure'));
      expect(policy, contains('does not encrypt'));
      expect(policy, contains(pomaSupport));
      expect(notices, contains('Pomatez'));
      expect(notices, contains('Permission is hereby granted'));
    },
  );

  testWidgets('About shows release version and public support from Settings', (
    tester,
  ) async {
    final controller = await AppController.create(
      MemoryRepository(),
      clock: FakeClock(),
    );
    await tester.pumpWidget(PomaApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('destination-3')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('About Poma'), 300);
    await tester.tap(find.text('About Poma'));
    await tester.pumpAndSettle();
    expect(find.text('$pomaVersion ($pomaBuild)'), findsOneWidget);
    expect(find.text('$pomaOwner\n$pomaSupport'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Privacy policy'));
    await tester.tap(find.text('Privacy policy'));
    // Build the pushed route before allowing real asset I/O to complete.
    await tester.pump();
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await controller.flush();
  });

  testWidgets('offline legal text remains scrollable at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const LegalScreen(
          title: 'Privacy policy',
          asset: 'assets/legal/privacy.txt',
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SelectableText), findsOneWidget);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
}
