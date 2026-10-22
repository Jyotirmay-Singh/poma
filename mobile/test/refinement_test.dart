import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/local_alerts.dart';
import 'package:poma/domain/alert_state.dart';
import 'package:poma/domain/models.dart';
import 'package:poma/l10n/poma_localizations.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/copy.dart';
import 'package:poma/ui/theme.dart';
import 'package:poma/ui/timer_dial.dart';
import 'alert_support.dart';
import 'support.dart';

const capture = bool.fromEnvironment('POMA_SCREENSHOTS');
const captureDirectory = String.fromEnvironment(
  'POMA_SCREENSHOT_DIR',
  defaultValue: '../artifacts/session-5',
);
const longTitle =
    'Read the next chapter, make careful notes, and review the important ideas before moving on. Read the next chapter, make clear notes, and review important ideas.';
final evidence = <Map<String, Object?>>[];

SavedState populated(String appearance) => SavedState(
  settings: TimerSettings(focusMinutes: 120, appearance: appearance),
  alerts: const AlertState(permissionRequested: true),
  tasks: const [
    FocusTask(id: 'one', title: longTitle),
    FocusTask(id: 'two', title: 'Plan tomorrow'),
    FocusTask(id: 'done', title: 'Read a chapter', done: true),
  ],
  selectedTaskId: 'one',
  sessions: List.generate(
    7,
    (i) => FocusSession(
      id: 'history-$i',
      startedAt: DateTime.utc(2026, 10, 14 + i, 9),
      endedAt: DateTime.utc(2026, 10, 14 + i, 9, 25),
      focusSeconds: 1500,
      taskTitle: i == 6 ? longTitle : 'Read a chapter',
    ),
  ),
);

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> scanPage(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  for (var i = 0; i < 45; i++) {
    expect(tester.takeException(), isNull);
    if (scroll.position.pixels >= scroll.position.maxScrollExtent) break;
    await tester.drag(find.byType(ListView), const Offset(0, -450));
    await tester.pumpAndSettle();
  }
  expect(tester.takeException(), isNull);
}

/// Fully clipped text can share coordinates with the navigation bar. Sample
/// painted text only; the separate token checks do not depend on rasterization.
Finder fullyVisibleText(WidgetTester tester) => find.byElementPredicate((
  element,
) {
  if (element.widget is! Text) return false;
  final render = element.findRenderObject();
  if (render is! RenderBox || !render.hasSize) return false;
  final bounds = MatrixUtils.transformRect(
    render.getTransformTo(null),
    render.paintBounds,
  );
  final viewport = RenderAbstractViewport.maybeOf(render);
  final clip = viewport == null
      ? Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio)
      : MatrixUtils.transformRect(
          viewport.getTransformTo(null),
          viewport.paintBounds,
        );
  return clip.contains(bounds.topLeft) && clip.contains(bounds.bottomRight);
});

Future<void> screenshot(
  WidgetTester tester,
  String name,
  Map<String, Object?> settings,
) async {
  if (!capture) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('preview')),
  );
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 2);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$captureDirectory/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
  evidence.add({
    'file': '$name.png',
    'renderScale': 2,
    'source':
        'Flutter widget renderer; seeded local app records; SDK Roboto preview substitute',
    'devicePixelRatio': tester.view.devicePixelRatio,
    'locale': tester.platformDispatcher.locale.toString(),
    'safeInsets': {
      'top': tester.view.padding.top,
      'bottom': tester.view.padding.bottom,
    },
    'textScale': tester.platformDispatcher.textScaleFactor,
    'reducedMotion':
        tester.platformDispatcher.accessibilityFeatures.disableAnimations,
    ...settings,
  });
}

void main() {
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await DeviceFormats.initialize();
    if (!capture) return;
    final root = Platform.environment['FLUTTER_ROOT']!;
    final fonts = '$root/bin/cache/artifacts/material_fonts';
    final body = FontLoader('Roboto');
    for (final file in [
      'roboto-regular.ttf',
      'roboto-medium.ttf',
      'roboto-bold.ttf',
    ]) {
      body.addFont(
        Future.value(
          ByteData.sublistView(await File('$fonts/$file').readAsBytes()),
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
  tearDownAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = false;
    if (capture) {
      await File(
        '$captureDirectory/screenshots.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(evidence));
    }
  });

  Future<void> mount(
    WidgetTester tester,
    AppController app, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const Key('preview'),
        child: PomaApp(controller: app),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final viewport in <String, Size>{
    'compact': const Size(320, 700),
    'tall': const Size(390, 844),
    'landscape': const Size(700, 320),
  }.entries) {
    for (final appearance in ['light', 'dark']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          '${viewport.key} $appearance ${scale}x populated screens remain usable',
          (tester) async {
            final semantics = tester.ensureSemantics();
            final app = await AppController.create(
              MemoryRepository(populated(appearance)),
              clock: FakeClock(),
            );
            addTearDown(app.dispose);
            try {
              await mount(tester, app, size: viewport.value, scale: scale);
              for (var tab = 0; tab < 4; tab++) {
                await tester.tap(find.byKey(Key('destination-$tab')));
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(
                    CustomMinimumContrastGuideline(
                      finder: fullyVisibleText(tester),
                    ),
                  ),
                );
                final settings = <String, Object?>{
                  'viewport': viewport.key,
                  'logicalWidth': viewport.value.width,
                  'logicalHeight': viewport.value.height,
                  'devicePixelRatio': 1,
                  'textScale': scale,
                  'theme': appearance,
                  'locale': tester.platformDispatcher.locale.toString(),
                  'safeInsets': {'top': 24, 'bottom': 24},
                  'reducedMotion': true,
                  'tab': tab,
                  'dataSetup':
                      'Three tasks (one complete, one 160-character title); seven 25-minute sessions; maximum focus duration 120 minutes.',
                };
                if (viewport.key == 'tall' && scale == 1 ||
                    viewport.key == 'compact' && scale == 2 ||
                    viewport.key == 'landscape' && scale == 2) {
                  await screenshot(
                    tester,
                    '${viewport.key}-$appearance-${scale.toInt()}x-$tab',
                    settings,
                  );
                }
                await scanPage(tester);
                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
              }
              await tester.pumpWidget(const SizedBox());
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }

  for (final appearance in ['light', 'dark']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'current modes remain accessible in $appearance at ${scale}x text',
        (tester) async {
          final clock = FakeClock();
          final app = await AppController.create(
            MemoryRepository(
              SavedState(
                settings: TimerSettings(rounds: 2, appearance: appearance),
              ),
            ),
            clock: clock,
          );
          addTearDown(app.dispose);
          final size = scale == 1 ? const Size(390, 844) : const Size(320, 700);
          final semantics = tester.ensureSemantics();
          try {
            await mount(tester, app, size: size, scale: scale);

            Future<void> showStartAction() async {
              tester
                  .state<ScrollableState>(find.byType(Scrollable).first)
                  .position
                  .jumpTo(0);
              await tester.pumpAndSettle();
              await tester.scrollUntilVisible(
                find.byKey(const Key('timer-toggle')),
                200,
              );
              await tester.pumpAndSettle();
            }

            Future<void> expectPhase(
              FocusPhase phase,
              String time,
              String action,
            ) async {
              final scroll = tester.state<ScrollableState>(
                find.byType(Scrollable).first,
              );
              scroll.position.jumpTo(0);
              await tester.pumpAndSettle();
              expect(app.timer.phase, phase);
              expect(app.timer.status, RunStatus.ready);
              expect(find.byType(ChoiceChip), findsNothing);
              expect(find.byType(DropdownButton<FocusPhase>), findsNothing);
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
                find.bySemanticsLabel('${phase.label}, Ready'),
                findsOneWidget,
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(
                  CustomMinimumContrastGuideline(
                    finder: fullyVisibleText(tester),
                  ),
                ),
              );
              await screenshot(
                tester,
                'current-mode-${phase.name}-$appearance-${scale.toInt()}x',
                {
                  'logicalWidth': size.width,
                  'logicalHeight': size.height,
                  'theme': appearance,
                  'phase': phase.name,
                  'dataSetup':
                      'UI-started focus/break cycle; two rounds; injected elapsed clock',
                },
              );
              await showStartAction();
              expect(
                find.descendant(
                  of: find.byKey(const Key('timer-toggle')),
                  matching: find.text(action),
                ),
                findsOneWidget,
              );
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await scanPage(tester);
            }

            Future<void> finishPhase(int minutes) async {
              await showStartAction();
              await tapVisible(tester, find.byKey(const Key('timer-toggle')));
              expect(app.timer.status, RunStatus.running);
              clock.advance(Duration(minutes: minutes));
              await app.reconcile();
              await tester.pumpAndSettle();
            }

            await expectPhase(FocusPhase.focus, '25:00', 'Start focus');
            await finishPhase(25);
            await expectPhase(
              FocusPhase.shortBreak,
              '05:00',
              'Start short break',
            );
            await finishPhase(5);
            expect(app.timer.phase, FocusPhase.focus);
            expect(app.timer.status, RunStatus.ready);
            await finishPhase(25);
            await expectPhase(
              FocusPhase.longBreak,
              '15:00',
              'Start long break',
            );
            await finishPhase(15);
            expect(app.timer.phase, FocusPhase.focus);
            expect(app.timer.status, RunStatus.ready);
            expect(app.timer.displayedRounds, 0);
            expect(app.sessions, hasLength(2));
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }

  testWidgets(
    'task input validates, submits with keyboard, and reopens a completed task',
    (tester) async {
      final app = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      addTearDown(app.dispose);
      await mount(tester, app, size: const Size(320, 700), scale: 2);
      await tester.tap(find.byKey(const Key('destination-1')));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Add a task'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Enter a task name.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), longTitle);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(app.tasks.single.title, longTitle);
      expect(longTitle.length, 160);
      final semantics = tester.ensureSemantics();
      await tapVisible(tester, find.byType(Checkbox));
      expect(app.tasks.single.done, isTrue);
      await tester.scrollUntilVisible(find.text('All tasks completed'), -300);
      await tester.pumpAndSettle();
      expect(find.text('All tasks completed'), findsOneWidget);
      await tester.scrollUntilVisible(find.byType(Checkbox), 300);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byType(Checkbox)).label,
        contains('incomplete'),
      );
      await tapVisible(tester, find.byType(Checkbox));
      expect(app.tasks.single.done, isFalse);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'current task snapshot, completion notice and manual break action agree',
    (tester) async {
      final clock = FakeClock();
      final app = await AppController.create(
        MemoryRepository(
          SavedState(
            settings: const TimerSettings(focusMinutes: 1),
            tasks: const [
              FocusTask(id: 'a', title: 'Original title'),
              FocusTask(id: 'b', title: 'Next task'),
            ],
            selectedTaskId: 'a',
          ),
        ),
        clock: clock,
      );
      addTearDown(app.dispose);
      await mount(tester, app);
      await tapVisible(tester, find.byKey(const Key('timer-toggle')));
      app.editTask('a', 'Renamed title');
      app.selectTask('b');
      await app.flush();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Original title'), 200);
      await tester.pumpAndSettle();
      expect(app.activeTaskTitle, 'Original title');
      expect(find.text('Original title'), findsOneWidget);
      clock.advance(const Duration(minutes: 1));
      await app.reconcile();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Start short break'), -200);
      await tester.pumpAndSettle();
      expect(app.sessions.single.taskTitle, 'Original title');
      expect(app.timer.status, RunStatus.ready);
      expect(app.lastPhaseCompletion?.phase, FocusPhase.focus);
      final notice = app.lastPhaseCompletion;
      await app.reconcile();
      expect(identical(notice, app.lastPhaseCompletion), isTrue);
      await screenshot(tester, 'completion-inline', {
        'viewport': 'tall',
        'logicalWidth': 390,
        'logicalHeight': 844,
        'textScale': 1,
        'theme': 'light',
        'data':
            'UI-started 1-minute focus; injected elapsed time; original task snapshot',
      });
      await tapVisible(tester, find.byKey(const Key('timer-toggle')));
      expect(app.timer.phase, FocusPhase.shortBreak);
      expect(app.timer.status, RunStatus.running);
      expect(app.lastPhaseCompletion, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final availability in AlertAvailability.values) {
    testWidgets(
      'alert state $availability offers honest recovery without auto permission prompts',
      (tester) async {
        final alerts = FakeAlerts()..mode = availability;
        final app = await AppController.create(
          MemoryRepository(
            SavedState(
              alerts: AlertState(
                enabled: availability != AlertAvailability.disabled,
                permissionRequested: true,
              ),
            ),
          ),
          clock: FakeClock(),
          alerts: alerts,
        );
        addTearDown(app.dispose);
        await mount(tester, app);
        await tester.tap(find.byKey(const Key('destination-3')));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Completion alerts'), 300);
        await tester.pumpAndSettle();
        final copy = PomaLocalizations.of(
          tester.element(find.byType(SwitchListTile).last),
        )!;
        await tester.scrollUntilVisible(find.text(alertStatus(copy, app)), 180);
        await tester.pumpAndSettle();
        expect(alerts.permissionRequests, 0);
        if (availability == AlertAvailability.denied) {
          await tester.scrollUntilVisible(
            find.text('Phone notification settings'),
            100,
          );
          await tester.pumpAndSettle();
          await tapVisible(tester, find.text('Phone notification settings'));
          expect(alerts.settingsOpens, 1);
          await screenshot(tester, 'permission-denied', {
            'viewport': 'tall',
            'logicalWidth': 390,
            'logicalHeight': 844,
            'textScale': 1,
            'theme': 'light',
            'data': 'Fake OS denial; settings link action asserted',
          });
          alerts.mode = AlertAvailability.ready;
          await app.setForeground(false);
          await app.setForeground(true);
          expect(app.alertAvailability, AlertAvailability.ready);
        }
        if (availability == AlertAvailability.delayed) {
          await tester.scrollUntilVisible(
            find.text('Allow precise alerts'),
            100,
          );
          await tester.pumpAndSettle();
          await tapVisible(tester, find.text('Allow precise alerts'));
          expect(alerts.exactRequests, 1);
        }
        if (availability == AlertAvailability.failed ||
            availability == AlertAvailability.unavailable) {
          await tester.scrollUntilVisible(find.text('Retry alerts'), 100);
          await tester.pumpAndSettle();
          final before = alerts.syncs;
          await tapVisible(tester, find.text('Retry alerts'));
          expect(alerts.syncs, greaterThan(before));
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'chart data has dated semantic totals and uses device date/time preferences',
    (tester) async {
      final app = await AppController.create(
        MemoryRepository(populated('light')),
        clock: FakeClock(),
      );
      addTearDown(app.dispose);
      await mount(tester, app);
      tester.platformDispatcher.localeTestValue = const Locale('de', 'DE');
      final semantics = tester.ensureSemantics();
      await tester.tap(find.byKey(const Key('destination-2')));
      await tester.pumpAndSettle();
      final context = tester.element(find.text('Daily focus totals'));
      expect(
        DeviceFormats.date(context, DateTime(2026, 10, 20)),
        DateFormat.yMMMd('de_DE').format(DateTime(2026, 10, 20)),
      );
      expect(
        find.bySemanticsLabel(RegExp('.*1 session, 25 minutes focused')),
        findsWidgets,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      final tasksLabel = find.descendant(
        of: find.byKey(const Key('destination-1')),
        matching: find.text('Tasks'),
      );
      final node = Focus.of(tester.element(tasksLabel));
      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Add a task'), findsOneWidget);
      // Set the actual inherited preference explicitly: changing the test
      // dispatcher's flag does not replace the FlutterView's MediaQuery data.
      for (final use24 in [true, false]) {
        String? formatted;
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(alwaysUse24HourFormat: use24),
            child: Builder(
              builder: (context) {
                formatted = DeviceFormats.time(
                  context,
                  DateTime(2026, 10, 20, 21, 5),
                );
                return const SizedBox();
              },
            ),
          ),
        );
        expect(
          formatted,
          use24
              ? '21:05'
              : DateFormat(
                  'h:mm a',
                  'de',
                ).format(DateTime(2026, 10, 20, 21, 5)),
        );
      }
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'strict mode locks timer controls while stacked errors remain scrollable',
    (tester) async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(strictMode: true)),
      );
      final clock = FakeClock();
      final app = await AppController.create(repository, clock: clock);
      addTearDown(app.dispose);
      await app.toggleTimer();
      repository.failWrites = true;
      app.addTask('Still editable during strict mode');
      await app.flush();
      clock.failReads = true;
      await app.reconcile();
      await mount(tester, app, size: const Size(320, 700), scale: 2);
      expect(app.saveError, isNotNull);
      expect(app.clockError, isNotNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('timer-toggle')),
        300,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('timer-toggle')))
            .onPressed,
        isNull,
      );
      await scanPage(tester);
      await tester.tap(find.byKey(const Key('destination-3')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byTooltip('Increase Focus duration'),
        300,
      );
      await tester.pumpAndSettle();
      final increase = find
          .widgetWithIcon(IconButton, Icons.add_circle_outline)
          .first;
      expect(tester.widget<IconButton>(increase).onPressed, isNull);
      await scanPage(tester);
      expect(app.tasks.single.title, 'Still editable during strict mode');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'overdue recovery has a real completion notice; manual phase changes do not',
    () async {
      final repository = MemoryRepository(
        SavedState(settings: const TimerSettings(focusMinutes: 1)),
      );
      final clock = FakeClock();
      final first = await AppController.create(repository, clock: clock);
      await first.toggleTimer();
      final run = first.timer.runId;
      await first.flush();
      first.dispose();
      clock.advance(const Duration(minutes: 2));
      final reopened = await AppController.create(repository, clock: clock);
      expect(reopened.lastPhaseCompletion?.runId, run);
      expect(reopened.lastPhaseCompletion?.phase, FocusPhase.focus);
      expect(reopened.timer.status, RunStatus.ready);
      expect(reopened.sessions.single.id, run);
      await reopened.skipTimer();
      expect(reopened.lastPhaseCompletion, isNull);
      await reopened.flush();
      reopened.dispose();
      final ready = await AppController.create(repository, clock: clock);
      expect(ready.lastPhaseCompletion, isNull);
      await ready.selectPhase(FocusPhase.longBreak);
      expect(ready.lastPhaseCompletion, isNull);
      ready.dispose();
    },
  );

  testWidgets(
    'completion region stops announcing after the first presentation',
    (tester) async {
      final clock = FakeClock();
      final app = await AppController.create(
        MemoryRepository(
          SavedState(settings: const TimerSettings(focusMinutes: 1)),
        ),
        clock: clock,
      );
      addTearDown(app.dispose);
      await mount(tester, app);
      await app.toggleTimer();
      final run = app.timer.runId;
      clock.advance(const Duration(minutes: 1));
      await app.reconcile();
      await tester.pumpAndSettle();
      final notice = find.byKey(ValueKey('completion-$run'));
      await tester.scrollUntilVisible(notice, 250);
      await tester.pumpAndSettle();
      await app.reconcile();
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(notice).properties.liveRegion, isTrue);
      await tester.tap(find.byKey(const Key('destination-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('destination-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(notice, 250);
      await tester.pumpAndSettle();
      expect(tester.widget<Semantics>(notice).properties.liveRegion, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test('palette text and essential accents meet contrast ratios', () {
    double ratio(Color a, Color b) {
      final first = a.computeLuminance();
      final second = b.computeLuminance();
      return (first > second
          ? (first + .05) / (second + .05)
          : (second + .05) / (first + .05));
    }

    for (final brightness in Brightness.values) {
      final colors = pomaTheme(brightness).colorScheme;
      for (final foreground in [colors.onSurface, colors.onSurfaceVariant]) {
        expect(ratio(foreground, colors.surface), greaterThanOrEqualTo(4.5));
      }
      expect(
        ratio(colors.onPrimary, colors.primary),
        greaterThanOrEqualTo(4.5),
      );
      final teal = brightness == Brightness.dark
          ? const Color(0xFF81D4CF)
          : pomaTeal;
      expect(ratio(colors.onPrimary, teal), greaterThanOrEqualTo(4.5));
      expect(ratio(colors.primary, colors.surface), greaterThanOrEqualTo(3));
    }
  });
}
