import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/data/local_storage_policy.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/main.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('startup privacy failure offers retry and retains saved tasks', (
    tester,
  ) async {
    final repository = PreparationFailureRepository(
      SavedState(
        tasks: const [FocusTask(id: 'kept', title: 'Saved task')],
      ),
    );
    await tester.pumpWidget(PomaLoader(repositoryFactory: () => repository));
    await tester.pumpAndSettle();
    expect(
      find.text('Local storage privacy settings could not be applied.'),
      findsOneWidget,
    );
    expect(
      find.text('Try again. Your existing data will be kept.'),
      findsOneWidget,
    );
    expect(repository.state.tasks.single.title, 'Saved task');
    repository.failPreparation = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    expect(find.text('Saved task'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  setUpAll(() async {
    if (!const bool.fromEnvironment('POMA_SCREENSHOTS')) return;
    final sdk = Platform.environment['FLUTTER_ROOT'];
    if (sdk == null) {
      throw StateError('Set FLUTTER_ROOT to render preview fonts.');
    }
    final fonts = '$sdk/bin/cache/artifacts/material_fonts';
    final body = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      body.addFont(
        Future.value(
          ByteData.sublistView(await File('$fonts/$name').readAsBytes()),
        ),
      );
    }
    await body.load();
    await (FontLoader('MaterialIcons')..addFont(
          Future.value(
            ByteData.sublistView(
              await File('$fonts/materialicons-regular.otf').readAsBytes(),
            ),
          ),
        ))
        .load();
  });
  Future<AppController> mount(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = await AppController.create(
      MemoryRepository(),
      clock: FakeClock(),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('capture'),
        child: PomaApp(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(controller.dispose);
    return controller;
  }

  testWidgets('focus controls and the real task form work', (tester) async {
    final controller = await mount(tester);
    expect(find.text('25:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-toggle')));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.tap(find.byKey(const Key('timer-toggle')));
    await tester.pump();
    expect(find.text('Resume'), findsOneWidget);
    await tester.tap(find.text('Tasks').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Read one chapter');
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.title, 'Read one chapter');
    expect(find.text('Read one chapter'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    expect(controller.tasks.single.done, isTrue);
  });
  testWidgets('all four screens fit a small phone with 200 percent text', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await mount(tester, size: const Size(320, 700));
    for (final label in ['Tasks', 'Insights', 'Settings', 'Focus']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$label overflows at 200 percent text',
      );
    }
  });
  testWidgets('light and dark focus previews', (tester) async {
    final controller = await mount(tester);
    if (!const bool.fromEnvironment('POMA_SCREENSHOTS')) return;
    for (final appearance in ['light', 'dark']) {
      controller.updateSettings(
        controller.settings.copyWith(appearance: appearance),
      );
      await tester.pumpAndSettle();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('capture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('../artifacts/poma-$appearance.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}

class PreparationFailureRepository extends MemoryRepository {
  PreparationFailureRepository(super.initial);
  bool failPreparation = true;

  @override
  Future<SavedState> load() async {
    if (failPreparation) throw const LocalStoragePreparationException();
    return super.load();
  }
}
