import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/focus_block_controller.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/app_shell.dart';
import 'package:poma/ui/calendar_screen.dart';
import 'calendar_connection_test.dart' as auth;
import 'focus_blocks_test.dart' as f;
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

void main() {
  setUpAll(() async {
    if (const String.fromEnvironment('POMA_FOCUS_SCREENSHOTS').isEmpty) return;
    for (final entry in [
      ('Segoe UI', 'C:/Windows/Fonts/segoeui.ttf'),
      (
        'MaterialIcons',
        'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      ),
    ]) {
      final font = FontLoader(entry.$1)
        ..addFont(
          Future.value(ByteData.sublistView(File(entry.$2).readAsBytesSync())),
        );
      await font.load();
    }
  });
  Future<void> capture(WidgetTester tester, String name) async {
    const folder = String.fromEnvironment('POMA_FOCUS_SCREENSHOTS');
    if (folder.isEmpty) return;
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('focus-review-capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$folder/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Calendar preview and persistent status at ${scale * 100}% text; repeated confirm sends once',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final dir = Directory.systemTemp.createTempSync('poma-focus-ui-');
        final app = await AppController.create(
          MemoryRepository(),
          clock: FakeClock(),
        );
        final shell = FakeShell();
        final connection = CalendarConnectionController(
          configuration: auth.configured,
          authorization: auth.FakeAuthorization(),
          store: auth.MemoryCredentials()..value = auth.credential(),
        );
        await connection.initialize();
        final desktop = DesktopController(
          app,
          shell,
          const DesktopEnvironment(
            dataDirectory: 'synthetic',
            version: 'test',
            packaged: false,
            sessionState: 'unlocked',
          ),
          connection: connection,
        );
        await desktop.initialize();
        final google = f.GoogleStore();
        final focus = FocusBlockController(
          session: f.WriteSession(),
          store: f.JournalStore(dir),
          writer: google,
          time: f.Times(),
          now: () => f.instant,
        );
        await focus.initialize();
        await focus.bind(f.binding());
        desktop.attachFocusBlocks(focus);
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('focus-review-capture'),
            child: PomaApp(controller: app, desktop: desktop),
          ),
        );
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(AppShell));
        unawaited(
          showFocusBlockDialog(
            context,
            desktop,
            taskTitle: 'Private Unicode 😀 focus',
          ),
        );
        await tester.pumpAndSettle();
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(1), '2026-11-03 16:00');
        await tester.enterText(fields.at(2), '2026-11-03 16:25');
        await tester.ensureVisible(find.text('Review block'));
        await tester.tap(find.text('Review block'));
        await tester.pumpAndSettle();
        expect(google.inserts, 0);
        expect(find.text('Private Unicode 😀 focus'), findsOneWidget);
        expect(find.textContaining('UTC+05:30'), findsWidgets);
        await capture(tester, 'focus-preview-${(scale * 100).toInt()}');
        final send = find.widgetWithText(FilledButton, 'Schedule focus block');
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.tap(send, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(google.inserts, 1);
        expect(google.events.length, 1);
        expect(focus.journal!.operations.values.single.status.name, 'saved');
        expect(tester.takeException(), isNull);
        await capture(tester, 'focus-status-${(scale * 100).toInt()}');
        await tester.pumpWidget(const SizedBox());
        desktop.dispose();
        app.dispose();
        dir.deleteSync(recursive: true);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );
  }
  testWidgets(
    'Lock hides a reviewed payload and requires a fresh preview',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('poma-focus-ui-lock-');
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final desktop = DesktopController(
        app,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'synthetic',
          version: 'test',
          packaged: false,
          sessionState: 'unlocked',
        ),
      );
      await desktop.initialize();
      final google = f.GoogleStore();
      final focus = FocusBlockController(
        session: f.WriteSession(),
        store: f.JournalStore(dir),
        writer: google,
        time: f.Times(),
        now: () => f.instant,
      );
      await focus.initialize();
      await focus.bind(f.binding());
      desktop.attachFocusBlocks(focus);
      await tester.pumpWidget(PomaApp(controller: app, desktop: desktop));
      await tester.pumpAndSettle();
      unawaited(
        showFocusBlockDialog(
          tester.element(find.byType(AppShell)),
          desktop,
          taskTitle: 'Private block for lock check',
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(1), '2026-11-03 16:00');
      await tester.enterText(find.byType(TextField).at(2), '2026-11-03 16:25');
      await tester.tap(find.text('Review block'));
      await tester.pumpAndSettle();
      await shell.onEvent!('sessionState', {'state': 'locked'});
      await tester.pumpAndSettle();
      expect(find.text('Private block for lock check'), findsNothing);
      expect(google.inserts, 0);
      await shell.onEvent!('sessionState', {'state': 'unlocked'});
      await tester.pumpAndSettle();
      expect(find.text('Review block'), findsOneWidget);
      expect(google.inserts, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      desktop.dispose();
      app.dispose();
      dir.deleteSync(recursive: true);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}
