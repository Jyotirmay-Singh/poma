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
import 'package:poma/ui/timer_dial.dart';
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
    await tester.pumpWidget(
      PomaLoader(
        repositoryFactory: () => repository,
        clockFactory: FakeClock.new,
      ),
    );
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
  testWidgets(
    'callbacks from the previous frame cannot start, reset or skip the successor',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clock = FakeClock();
      final app = await AppController.create(MemoryRepository(), clock: clock);
      await tester.pumpWidget(PomaApp(controller: app));
      await app.toggleTimer();
      await tester.pump();
      final oldToggle = tester
          .widget<FilledButton>(find.byKey(const Key('timer-toggle')))
          .onPressed!;
      final oldReset = tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.replay))
          .onPressed!;
      final oldSkip = tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.skip_next))
          .onPressed!;
      clock.advance(const Duration(minutes: 25));
      await app.reconcile();
      // Do not repaint: these callbacks still represent the old running frame.
      oldToggle();
      oldReset();
      oldSkip();
      await app.flush();
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.ready);
      expect(app.sessions, hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await app.flush();
      app.dispose();
    },
  );
  for (final rounds in [1, 3, 4]) {
    testWidgets(
      'current mode follows a $rounds-round cycle and waits for Start',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final clock = FakeClock();
        final settings = TimerSettings(
          focusMinutes: 2,
          shortBreakMinutes: 1,
          longBreakMinutes: 3,
          rounds: rounds,
        );
        final app = await AppController.create(
          MemoryRepository(SavedState(settings: settings)),
          clock: clock,
        );
        addTearDown(app.dispose);
        await tester.pumpWidget(PomaApp(controller: app));
        await tester.pumpAndSettle();

        void expectReady(FocusPhase phase, String time, String action) {
          expect(app.timer.phase, phase);
          expect(app.timer.status, RunStatus.ready);
          final dial = find.byType(TimerDial);
          expect(
            find.descendant(of: dial, matching: find.text(phase.label)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: dial, matching: find.text(time)),
            findsOneWidget,
          );
          expect(
            find.descendant(
              of: find.byKey(const Key('timer-toggle')),
              matching: find.text(action),
            ),
            findsOneWidget,
          );
          expect(find.byType(ChoiceChip), findsNothing);
          expect(find.byType(DropdownButton<FocusPhase>), findsNothing);
        }

        Future<void> finishPhase(int minutes) async {
          final toggle = find.byKey(const Key('timer-toggle'));
          await tester.ensureVisible(toggle);
          await tester.pumpAndSettle();
          await tester.tap(toggle);
          await tester.pumpAndSettle();
          expect(app.timer.status, RunStatus.running);
          clock.advance(Duration(minutes: minutes));
          await app.reconcile();
          await tester.pumpAndSettle();
        }

        expectReady(FocusPhase.focus, '02:00', 'Start focus');
        for (var round = 1; round <= rounds; round++) {
          await finishPhase(2);
          final lastRound = round == rounds;
          expectReady(
            lastRound ? FocusPhase.longBreak : FocusPhase.shortBreak,
            lastRound ? '03:00' : '01:00',
            lastRound ? 'Start long break' : 'Start short break',
          );
          expect(app.timer.displayedRounds, round);
          expect(app.sessions, hasLength(round));
          await finishPhase(lastRound ? 3 : 1);
          expectReady(FocusPhase.focus, '02:00', 'Start focus');
          expect(app.timer.displayedRounds, lastRound ? 0 : round);
          expect(app.sessions, hasLength(round));
        }
        expect(
          app.sessions.map((session) => session.id).toSet(),
          hasLength(rounds),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await app.flush();
      },
    );
  }
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
