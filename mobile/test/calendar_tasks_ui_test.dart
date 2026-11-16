import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/application/planner_controller.dart';
import 'package:poma/data/local_repository.dart';
import 'package:poma/data/planner_time.dart';
import 'package:poma/domain/planner.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/planner_scope.dart';
import 'package:poma/ui/task_color_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'calendar_read_test.dart' show TestCalendarClock, TestCalendarScheduler;
import 'calendar_ui_support.dart';
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

Future<PlannerController> localPlanner(
  AppController app, {
  PlannerCalendarView view = PlannerCalendarView.day,
}) async {
  final clock = TestCalendarClock(time: DateTime(2026, 11, 15, 10).toUtc());
  final planner = PlannerController.local(
    app: app,
    clock: clock,
    scheduler: TestCalendarScheduler(clock),
    time: PlannerTime(fixedZone: 'Etc/UTC'),
    initialView: view,
  );
  await planner.initialize();
  return planner;
}

Future<void> captureCalendar(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('POMA_SCREENSHOTS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('calendar-capture')),
  );
  await tester.runAsync(() async {
    final output = Directory(
      const String.fromEnvironment(
        'POMA_SCREENSHOT_DIR',
        defaultValue: '../artifacts/calendar-redesign',
      ),
    );
    await output.create(recursive: true);
    final image = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '${output.path}/$name.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(sqfliteFfiInit);

  test('mobile timezone lookup accepts an IANA identifier', () async {
    const channel = MethodChannel('test/poma/calendar_timezone');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'focusTimeZone');
          return {'zone': 'Asia/Kolkata'};
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    expect(await PlannerTime(channel: channel).deviceZone(), 'Asia/Kolkata');
  });

  test('local calendar follows midnight after resetting local data', () async {
    final app = await AppController.create(
      MemoryRepository(),
      clock: FakeClock(),
    );
    final planner = await localPlanner(app);
    try {
      final clock = planner.clock as TestCalendarClock;
      final scheduler = planner.scheduler as TestCalendarScheduler;
      clock.time = DateTime(2026, 11, 15, 23, 59).toUtc();
      expect(await app.deleteAllLocalData(), isTrue);
      await scheduler.advance(const Duration(minutes: 2));
      expect(planner.selectedDate.toString(), '2026-11-16');
    } finally {
      planner.dispose();
      app.dispose();
    }
  });

  test(
    'local task colors survive scheduling, edits, undo and SQLite reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'poma-task-colors-',
      );
      final path = '${directory.path}/poma.db';
      var repository = SqliteRepository(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: path,
      );
      var app = await AppController.create(repository, clock: FakeClock());
      var planner = await localPlanner(app);
      try {
        final draft = await planner.beginDraft(scheduled: false);
        draft.addAll({'title': 'Read the brief', 'colorId': '2'});
        expect(await planner.saveDraft(draft), isTrue);
        final taskId = app.tasks.single.id;
        expect(app.tasks.single.colorId, '2');
        final scheduled = await planner.beginDraft(task: app.tasks.single);
        expect(scheduled['colorId'], '2');
        expect(await planner.saveDraft(scheduled), isTrue);
        final schedule = planner.taskSchedule(taskId)!;
        expect(schedule.fields['colorId'], '2');
        final edited = planner.editSchedule(schedule)..['colorId'] = '11';
        expect(await planner.saveDraft(edited), isTrue);
        expect(app.tasks.single.colorId, '11');
        await planner.undoChange(schedule.id);
        expect(app.tasks.single.colorId, '2');
        expect(planner.taskSchedule(taskId)!.fields['colorId'], '2');
        planner.dispose();
        await app.flush();
        app.dispose();
        await repository.close();
        repository = SqliteRepository(
          factory: databaseFactoryFfiNoIsolate,
          databasePath: path,
        );
        app = await AppController.create(repository, clock: FakeClock());
        planner = await localPlanner(app);
        expect(app.tasks.single.colorId, '2');
        expect(planner.taskSchedule(taskId)!.fields['colorId'], '2');
        final remove = planner.editSchedule(planner.taskSchedule(taskId)!)
          ..['scheduled'] = false
          ..['colorId'] = null;
        expect(await planner.saveDraft(remove), isTrue);
        expect(app.tasks.single.colorId, isNull);
        expect(planner.taskSchedule(taskId), isNull);
        expect(planner.supportsGoogle, isFalse);
        expect(planner.data.operations, isEmpty);
      } finally {
        planner.dispose();
        await app.flush();
        app.dispose();
        await repository.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'phone creates a colored task in Calendar and selects it for Focus',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final planner = await localPlanner(app);
      addTearDown(planner.dispose);
      addTearDown(app.dispose);
      await tester.pumpWidget(PomaApp(controller: app));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('destination-1')), findsNothing);
      await openCalendarTasks(tester);
      await enterCalendarTask(tester, 'Prepare the presentation');
      expect(find.byType(TaskColorPicker), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('task-color-3')));
      await tester.tap(find.byKey(const ValueKey('task-color-3')));
      await tester.tap(find.byKey(const ValueKey('planner-save')));
      await tester.pumpAndSettle();
      expect(app.tasks.single.colorId, '3');
      expect(planner.data.operations, isEmpty);
      await closeCalendarDrawer(tester);
      await tester.tap(find.byKey(const Key('destination-0')));
      await tester.pumpAndSettle();
      app.selectTask(null);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Choose a task'));
      await tester.tap(find.text('Choose a task'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(ValueKey('focus-pick-${app.tasks.single.id}')),
      );
      await tester.pumpAndSettle();
      expect(app.selectedTaskId, app.tasks.single.id);
      expect(find.text('Prepare the presentation'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  for (final spec in [
    ('desktop-light', const Size(1600, 1000), Brightness.light, 1.0, false),
    ('desktop-dark', const Size(1600, 1000), Brightness.dark, 1.0, false),
    ('tablet', const Size(1024, 800), Brightness.light, 1.0, false),
    ('phone-light', const Size(390, 844), Brightness.light, 1.0, false),
    ('phone-dark', const Size(390, 844), Brightness.dark, 1.0, false),
    ('phone-large-text', const Size(320, 700), Brightness.light, 2.0, true),
  ]) {
    testWidgets('calendar layout ${spec.$1}', (tester) async {
      tester.view.physicalSize = spec.$2;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = spec.$4;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(highContrast: spec.$5);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final planner = await localPlanner(
        app,
        view: spec.$2.width >= 720
            ? PlannerCalendarView.week
            : PlannerCalendarView.day,
      );
      DesktopController? desktop;
      if (spec.$1.startsWith('desktop')) {
        desktop = (await tester.runAsync(
          () async => DesktopController(
            app,
            FakeShell(),
            const DesktopEnvironment(
              dataDirectory: 'calendar-preview',
              version: 'preview',
              packaged: false,
              visible: true,
              sessionState: 'unlocked',
            ),
          ),
        ))!;
        await desktop.initialize();
        desktop.attachPlanner(planner);
        addTearDown(desktop.dispose);
      } else {
        addTearDown(planner.dispose);
      }
      addTearDown(app.dispose);
      await app.updateSettings(
        app.settings.copyWith(
          appearance: spec.$3 == Brightness.dark ? 'dark' : 'light',
        ),
      );
      for (final entry in [
        ('Product strategy', 9, 60, '9'),
        ('Design review', 10, 45, '2'),
        ('Lunch', 12, 60, '6'),
        ('Focus time', 14, 90, '3'),
      ]) {
        final start = DateTime(2026, 11, 15, entry.$2).toUtc();
        final draft = await planner.beginDraft(
          startUtc: start,
          endUtc: start.add(Duration(minutes: entry.$3)),
        );
        draft.addAll({'title': entry.$1, 'colorId': entry.$4});
        expect(await planner.saveDraft(draft), isTrue);
      }
      final unscheduled = await planner.beginDraft(scheduled: false);
      unscheduled.addAll({'title': 'Plan next week', 'colorId': '7'});
      await planner.saveDraft(unscheduled);
      await tester.pumpWidget(
        RepaintBoundary(
          key: const Key('calendar-capture'),
          child: PomaApp(controller: app, desktop: desktop),
        ),
      );
      await tester.pumpAndSettle();
      if (desktop == null) {
        await tester.tap(find.byKey(const Key('destination-4')));
      } else {
        desktop.navigate(4);
      }
      await tester.pumpAndSettle();
      expect(
        PlannerScope.maybeOf(tester.element(find.byType(Scaffold).first)),
        same(planner),
      );
      expect(tester.takeException(), isNull);
      await captureCalendar(tester, spec.$1);
      if (spec.$1 == 'phone-light') {
        final semantics = tester.ensureSemantics();
        final agendaAction = find.byKey(
          const ValueKey('calendar-accessible-agenda'),
        );
        expect(tester.getSemantics(agendaAction).label, 'Calendar schedule');
        tester.widget<Semantics>(agendaAction).properties.onTap!();
        await tester.pumpAndSettle();
        expect(planner.calendarView, PlannerCalendarView.agenda);
        expect(find.text('Product strategy'), findsOneWidget);
        semantics.dispose();
      }
      if (spec.$2.width < 1100 || spec.$4 >= 1.5) {
        await tester.tap(find.byKey(const ValueKey('calendar-drawer')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('calendar-add-unscheduled')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Plan next week'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
