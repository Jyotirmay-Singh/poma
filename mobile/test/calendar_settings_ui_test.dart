import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/calendar_controller.dart';
import 'package:poma/application/calendar_reminder_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/calendar_settings_heading.dart';

import 'calendar_read_test.dart' show settleCalendar;
import 'calendar_reminder_test.dart' show ReminderAdapter, drain;
import 'contrast_support.dart';
import 'desktop_test.dart' show FakeShell;
import 'planner_support.dart';

void main() {
  Future<
    ({
      PlannerRig rig,
      DesktopController desktop,
      FakeShell shell,
      ReminderAdapter reminders,
    })
  >
  mount(
    WidgetTester tester, {
    bool dark = false,
    bool highContrast = false,
    double width = 1080,
    double scale = 1,
    bool sync = false,
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(highContrast: highContrast);
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final rig = (await tester.runAsync(() => plannerRig(sync: sync)))!;
    rig.creation.day.dispose();
    rig.creation.agenda.dispose();
    final shell = FakeShell();
    final desktop = DesktopController(
      rig.app,
      shell,
      const DesktopEnvironment(
        dataDirectory: 'fictional-calendar-settings',
        version: 'test',
        packaged: false,
        sessionState: 'unlocked',
      ),
      calendar: CalendarController(scheduleUpdates: false),
      connection: rig.creation.connection,
      calendarData: rig.creation.reader,
    );
    final reminders = ReminderAdapter();
    await tester.runAsync(() async {
      await desktop.initialize();
      desktop.attachPlanner(rig.planner);
      desktop.attachCreation(rig.creation.controller);
      desktop.attachReminders(
        CalendarReminderController(
          reader: rig.creation.reader,
          store: reminders,
          platform: reminders,
          openAgenda: () async {},
        ),
      );
      await drain(desktop.reminders!);
      await rig.app.updateSettings(
        rig.app.settings.copyWith(appearance: dark ? 'dark' : 'light'),
      );
    });
    desktop.openCalendarSection(CalendarPageSection.settings);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('calendar-settings-capture'),
        child: PomaApp(controller: rig.app, desktop: desktop),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() {
      desktop.dispose();
      rig.app.dispose();
    });
    return (rig: rig, desktop: desktop, shell: shell, reminders: reminders);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    const directory = String.fromEnvironment(
      'POMA_CALENDAR_SETTINGS_SCREENSHOTS',
    );
    if (directory.isEmpty) return;
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/branding/google-g.png'),
        tester.element(find.byKey(const ValueKey('calendar-settings-capture'))),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('calendar-settings-capture')),
      );
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Calendar settings presents essential controls and account navigation',
    (tester) async {
      final fixture = await mount(tester);
      expect(find.text('Calendar settings'), findsOneWidget);
      expect(find.text('Selected calendars'), findsOneWidget);
      expect(find.text('Default calendar'), findsNothing);
      expect(find.text('Calendar preview'), findsNothing);
      expect(find.byKey(const ValueKey('calendar-fixture')), findsNothing);
      expect(
        find.byKey(const ValueKey('google-calendar-connect')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('google-calendar-disconnect')),
        findsNothing,
      );
      expect(find.text('Event editing'), findsNothing);
      expect(find.text('Remind before meeting'), findsNothing);
      for (final heading in tester.widgetList<CalendarSettingsHeading>(
        find.byType(CalendarSettingsHeading),
      )) {
        final text = find.descendant(
          of: find.byWidget(heading),
          matching: find.byType(Text),
        );
        expect(tester.widget<Text>(text).style!.fontSize, 16);
      }
      await tester.tap(find.byKey(const ValueKey('calendar-account-settings')));
      await tester.pumpAndSettle();
      expect(fixture.desktop.destination, 3);
      expect(
        find.byKey(const ValueKey('settings-google-account')),
        findsOneWidget,
      );
      expect(fixture.rig.google.inserts, 0);
    },
  );

  testWidgets(
    'sync reveals its saved destination and preserves default duration',
    (tester) async {
      final fixture = await mount(tester);
      final duration = find.byKey(const ValueKey('planner-duration-60'));
      await tester.ensureVisible(duration);
      await tester.enterText(duration, '45');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(fixture.rig.planner.preferences.durationMinutes, 45);
      await tester.ensureVisible(
        find.byKey(const ValueKey('planner-sync-enabled')),
      );
      await tester.tap(find.byKey(const ValueKey('planner-sync-enabled')));
      await tester.runAsync(settleCalendar);
      await tester.pumpAndSettle();
      expect(fixture.rig.planner.preferences.syncEnabled, isTrue);
      expect(find.text('Default calendar'), findsOneWidget);
      expect(fixture.rig.planner.preferences.calendarId, 'synthetic-primary');
      expect(fixture.rig.google.inserts, 0);
    },
  );

  testWidgets('optional event access and tray controls expand on demand', (
    tester,
  ) async {
    final fixture = await mount(tester);
    final more = find.byKey(const ValueKey('calendar-more-options'));
    await tester.ensureVisible(more);
    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.text('Event editing'), findsOneWidget);
    expect(find.text('Disable calendar editing'), findsOneWidget);
    expect(find.text('Show event titles'), findsOneWidget);
    await capture(tester, 'expanded-light');
    expect(fixture.rig.google.inserts, 0);
    expect(fixture.rig.creation.auth.authorizations, 0);
  });

  testWidgets(
    'reminder controls appear when enabled and retain cleanup errors',
    (tester) async {
      final fixture = await mount(tester);
      final toggle = find.byKey(const ValueKey('calendar-reminder-enabled'));
      await tester.ensureVisible(toggle);
      await tester.runAsync(() async {
        tester.widget<SwitchListTile>(toggle).onChanged!(true);
        await drain(fixture.desktop.reminders!);
      });
      await tester.pumpAndSettle();
      expect(fixture.desktop.reminders!.preferences.enabled, isTrue);
      expect(find.text('Remind before meeting'), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey('calendar-reminder-source-synthetic-primary'),
        ),
        findsOneWidget,
      );
      fixture.reminders.fail = true;
      await tester.runAsync(() async {
        tester.widget<SwitchListTile>(toggle).onChanged!(false);
        await drain(fixture.desktop.reminders!);
      });
      await tester.pumpAndSettle();
      expect(find.text('Remind before meeting'), findsNothing);
      expect(find.text(fixture.desktop.reminders!.error!), findsOneWidget);
      expect(find.text('Retry reminders'), findsOneWidget);
      fixture.reminders.fail = false;
      await tester.ensureVisible(find.text('Retry reminders'));
      await tester.runAsync(() async {
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Retry reminders'),
            )
            .onPressed!();
        await drain(fixture.desktop.reminders!);
      });
      await tester.pumpAndSettle();
      expect(fixture.desktop.reminders!.error, isNull);
    },
  );

  testWidgets('Windows lock hides calendar names and account details', (
    tester,
  ) async {
    final fixture = await mount(tester);
    await fixture.shell.onEvent!('sessionState', {'state': 'locked'});
    await tester.pumpAndSettle();
    expect(find.text('synthetic-primary'), findsNothing);
    expect(find.text('Personal'), findsNothing);
    expect(
      find.text(
        'Calendar details are hidden while Windows is locked or its lock state is unknown.',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('calendar-account-settings')),
      findsNothing,
    );
  });

  for (final dark in [false, true]) {
    for (final contrast in [false, true]) {
      for (final width in [640.0, 1080.0]) {
        for (final scale in [1.0, 2.0]) {
          testWidgets(
            'Calendar settings dark=$dark contrast=$contrast width=$width scale=$scale',
            (tester) async {
              final semantics = tester.ensureSemantics();
              await mount(
                tester,
                dark: dark,
                highContrast: contrast,
                width: width,
                scale: scale,
                sync: true,
              );
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
                  RenderedTextContrastGuideline(
                    finder: find.byType(Text).hitTestable(),
                  ),
                ),
              );
              if (!contrast) {
                await capture(
                  tester,
                  '${dark ? 'dark' : 'light'}-${width.toInt()}-${scale.toInt()}x',
                );
              }
              final more = find.byKey(const ValueKey('calendar-more-options'));
              await tester.scrollUntilVisible(
                more,
                250,
                scrollable: find
                    .descendant(
                      of: find.byType(ListView).last,
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              await tester.pumpAndSettle();
              await tester.tap(more);
              await tester.pumpAndSettle();
              await tester.ensureVisible(find.text('Show event titles'));
              await tester.pumpAndSettle();
              expect(
                find.text('Show event titles').hitTestable(),
                findsOneWidget,
              );
              expect(tester.takeException(), isNull);
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              if (!contrast && width == 1080 && scale == 1) {
                await capture(tester, 'more-${dark ? 'dark' : 'light'}');
              }
              semantics.dispose();
            },
          );
        }
      }
    }
  }
}
