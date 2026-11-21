import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/local_repository.dart';
import 'package:poma/domain/desktop_preferences.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/focus_screen.dart';

import 'desktop_test.dart' show FakeShell;
import 'planner_ui_test.dart' as planner_ui show mount, settlePlanner;
import 'support.dart';

const _sidebar = Key('desktop-sidebar');
const _hide = Key('hide-sidebar');
const _show = Key('show-sidebar');

class _GatedRepository extends MemoryRepository {
  Completer<void>? gate;

  @override
  Future<int> commit(LocalCommit request) async {
    await gate?.future;
    return super.commit(request);
  }
}

Future<(AppController, DesktopController)> _mount(
  WidgetTester tester, {
  double width = 1080,
  double height = 900,
  double scale = 1,
  String appearance = 'dark',
  bool highContrast = false,
  bool reducedMotion = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        highContrast: highContrast,
        disableAnimations: reducedMotion,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final app = await AppController.create(
    MemoryRepository(
      SavedState(settings: TimerSettings(appearance: appearance)),
    ),
    clock: FakeClock(),
  );
  final desktop = (await tester.runAsync(
    () async => DesktopController(
      app,
      FakeShell(),
      const DesktopEnvironment(
        dataDirectory: 'sidebar-test',
        version: 'sidebar-test',
        packaged: false,
        visible: true,
        sessionState: 'unlocked',
      ),
    ),
  ))!;
  await desktop.initialize();
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('sidebar-capture'),
      child: PomaApp(controller: app, desktop: desktop),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    desktop.dispose();
    app.dispose();
  });
  return (app, desktop);
}

Future<void> _shortcut(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
}

Future<void> _capture(WidgetTester tester, String name) async {
  const folder = String.fromEnvironment('POMA_SIDEBAR_SCREENSHOTS');
  if (folder.isEmpty) return;
  for (final element in find.byType(Image).evaluate()) {
    await tester.runAsync(
      () => precacheImage((element.widget as Image).image, element),
    );
  }
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('sidebar-capture')),
    );
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$folder/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  test(
    'sidebar preference is additive and tolerates old or invalid values',
    () {
      for (final json in <Map<String, dynamic>>[
        {},
        {'sidebarCollapsed': 'true'},
        {'sidebarCollapsed': null},
      ]) {
        expect(DesktopPreferences.fromJson(json).sidebarCollapsed, isFalse);
      }
      const prefs = DesktopPreferences(sidebarCollapsed: true);
      expect(
        DesktopPreferences.fromJson(prefs.toJson()).sidebarCollapsed,
        isTrue,
      );
      expect(prefs.copyWith(tooltipTitles: false).sidebarCollapsed, isTrue);
    },
  );

  test(
    'rapid preference changes merge while an earlier write is pending',
    () async {
      final repository = _GatedRepository();
      final app = await AppController.create(repository, clock: FakeClock());
      addTearDown(app.dispose);
      await app.setForeground(false);
      final gate = repository.gate = Completer<void>();
      const bounds = DesktopBounds(30, 40, 1080, 900);
      final changes = [
        app.patchDesktopPreferences(sidebarCollapsed: true),
        app.patchDesktopPreferences(bounds: bounds),
        app.patchDesktopPreferences(tooltipTitles: false),
        app.patchDesktopPreferences(sidebarCollapsed: false),
        app.patchDesktopPreferences(sidebarCollapsed: true),
      ];
      expect(app.desktopPreferences.sidebarCollapsed, isTrue);
      gate.complete();
      await Future.wait(changes);
      expect(repository.state.desktopPreferences!.sidebarCollapsed, isTrue);
      expect(repository.state.desktopPreferences!.tooltipTitles, isFalse);
      expect(repository.state.desktopPreferences!.bounds!.width, 1080);
    },
  );

  test(
    'failed sidebar save remains usable and retries the latest choice',
    () async {
      final repository = MemoryRepository();
      final app = await AppController.create(repository, clock: FakeClock());
      addTearDown(app.dispose);
      await app.setForeground(false);
      repository.failWrites = true;
      await app.patchDesktopPreferences(sidebarCollapsed: true);
      expect(app.desktopPreferences.sidebarCollapsed, isTrue);
      expect(app.saveError, isNotNull);
      await app.patchDesktopPreferences(sidebarCollapsed: false);
      repository.failWrites = false;
      await app.retrySave();
      expect(app.saveError, isNull);
      expect(repository.state.desktopPreferences!.sidebarCollapsed, isFalse);
    },
  );

  testWidgets(
    'sidebar slides away, transfers focus, and preserves page and timer',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final (app, _) = await _mount(tester, width: 1440);
        final pageState = tester.state(find.byType(FocusScreen));
        final initialPageWidth = tester.getSize(find.byType(FocusScreen)).width;
        await app.toggleTimer();
        final run = app.timer.runId;
        await tester.pumpAndSettle();
        await _capture(tester, 'expanded');
        await tester.tap(find.byKey(_hide));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final midway = tester.getSize(find.byKey(_sidebar)).width;
        expect(midway, greaterThan(0));
        expect(midway, lessThan(217));
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(_sidebar)).width, 0);
        expect(
          tester.getSize(find.byType(FocusScreen)).width,
          initialPageWidth + 217,
        );
        expect(tester.state(find.byType(FocusScreen)), same(pageState));
        expect(app.timer.runId, run);
        expect(app.timer.status, RunStatus.running);
        expect(
          tester.widget<IconButton>(find.byKey(_show)).focusNode!.hasFocus,
          isTrue,
        );
        expect(
          tester
              .widget<IconButton>(find.byKey(_hide))
              .focusNode!
              .canRequestFocus,
          isFalse,
        );
        expect(
          tester.semantics.simulatedAccessibilityTraversal().map(
            (node) => node.label,
          ),
          isNot(contains('Hide sidebar (Ctrl+B)')),
        );
        await _capture(tester, 'hidden');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(tester.getSize(find.byKey(_sidebar)).width, 217);
        expect(
          tester.widget<IconButton>(find.byKey(_hide)).focusNode!.hasFocus,
          isTrue,
        );
        expect(app.timer.runId, run);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('hidden navigation works and every destination can reopen it', (
    tester,
  ) async {
    final (app, desktop) = await _mount(tester);
    await _shortcut(tester, LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    for (final key in [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
    ]) {
      await _shortcut(tester, key);
      await tester.pumpAndSettle();
      expect(
        find.byKey(_show),
        findsOneWidget,
        reason:
            'Destination ${desktop.destination}, key ${key.debugName}, collapsed ${app.desktopPreferences.sidebarCollapsed}',
      );
      expect(app.desktopPreferences.sidebarCollapsed, isTrue);
      await tester.tap(find.byKey(_show));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(_sidebar)).width, 217);
      await tester.tap(find.byKey(_hide));
      await tester.pumpAndSettle();
    }
    expect(desktop.destination, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sidebar toggle preserves the current scroll position', (
    tester,
  ) async {
    await _mount(tester, width: 1440, height: 560);
    final scroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(FocusScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    scroll.position.jumpTo(100);
    await tester.pump();
    final offset = scroll.position.pixels;
    await tester.tap(find.byKey(_hide));
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, offset);
    await _shortcut(tester, LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(scroll.position.pixels, offset);
  });

  testWidgets('Ctrl+B leaves text fields and open dialogs alone', (
    tester,
  ) async {
    final (app, desktop) = await _mount(tester);
    desktop.navigate(3);
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, '42');
    await _shortcut(tester, LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(app.desktopPreferences.sidebarCollapsed, isFalse);
    expect(tester.widget<TextField>(field).controller!.text, '42');
    FocusManager.instance.primaryFocus?.unfocus();
    unawaited(
      showDialog<void>(
        context: tester.element(field),
        builder: (_) => const AlertDialog(title: Text('Test dialog')),
      ),
    );
    await tester.pumpAndSettle();
    await _shortcut(tester, LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(app.desktopPreferences.sidebarCollapsed, isFalse);
    expect(find.text('Test dialog'), findsOneWidget);
  });

  testWidgets('compact layout retains the desktop choice across resizing', (
    tester,
  ) async {
    final (app, _) = await _mount(tester);
    await tester.tap(find.byKey(_hide));
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(640, 900);
    await tester.pumpAndSettle();
    expect(find.byKey(_sidebar), findsNothing);
    expect(find.byKey(_show), findsNothing);
    expect(find.byKey(const Key('destination-0')), findsOneWidget);
    await _shortcut(tester, LogicalKeyboardKey.keyB);
    expect(app.desktopPreferences.sidebarCollapsed, isTrue);
    tester.view.physicalSize = const Size(1080, 900);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(_sidebar)).width, 0);
    expect(find.byKey(_show), findsOneWidget);
  });

  for (final (width, scale, appearance, contrast) in [
    (700.0, 1.0, 'light', false),
    (999.0, 2.0, 'dark', true),
    (1000.0, 1.0, 'light', true),
    (1440.0, 2.0, 'dark', false),
  ]) {
    testWidgets(
      'sidebar reduced motion width=$width scale=$scale $appearance contrast=$contrast',
      (tester) async {
        await _mount(
          tester,
          width: width,
          scale: scale,
          appearance: appearance,
          highContrast: contrast,
          reducedMotion: true,
        );
        await tester.tap(find.byKey(_hide));
        await tester.pump();
        expect(tester.getSize(find.byKey(_sidebar)).width, 0);
        expect(
          tester.getSize(find.byKey(_show)).shortestSide,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(_show));
        await tester.pump();
        expect(
          tester.getSize(find.byKey(_sidebar)).width,
          width < 1000 || scale >= 1.5 ? 81 : 217,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('live Calendar and Day Clock toolbars both restore the sidebar', (
    tester,
  ) async {
    final (rig, desktop) = await planner_ui.mount(tester, width: 1440);
    for (final destination in [5, 4]) {
      desktop.navigate(destination);
      await planner_ui.settlePlanner(tester);
      await tester.tap(find.byKey(_hide));
      await planner_ui.settlePlanner(tester);
      expect(find.byKey(_show), findsOneWidget);
      expect(rig.app.desktopPreferences.sidebarCollapsed, isTrue);
      await tester.tap(find.byKey(_show));
      await planner_ui.settlePlanner(tester);
      expect(rig.app.desktopPreferences.sidebarCollapsed, isFalse);
      expect(tester.takeException(), isNull);
    }
  });
}
