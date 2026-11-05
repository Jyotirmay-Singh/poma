import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:poma/main.dart';
import 'package:poma/application/calendar_controller.dart';
import 'package:poma/application/app_controller.dart';
import 'package:poma/application/desktop_controller.dart';
import 'package:poma/domain/calendar_preview.dart';
import 'package:poma/domain/desktop_preferences.dart';
import 'package:poma/domain/models.dart';
import 'desktop_test.dart' show FakeShell;
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all fictional scenarios serialize seven dates and explicit local actions',
    () {
      final calendar = CalendarController(
        now: () => DateTime(2026, 10, 25, 14, 22),
        scheduleUpdates: false,
      );
      addTearDown(calendar.dispose);
      expect(calendar.fixture, CalendarFixture.disconnected);
      for (final fixture in CalendarFixture.values) {
        calendar.select(fixture);
        final data = calendar.display(unlocked: true, tooltipTitles: true);
        expect(data['calendarDates'], hasLength(7));
        expect(data['secondarySections'], isNotEmpty);
        expect(data.toString(), isNot(contains('https://')));
        expect(
          calendar.display(
            unlocked: false,
            tooltipTitles: true,
          )['secondarySections'],
          isEmpty,
        );
        expect(
          calendar.display(
            unlocked: false,
            tooltipTitles: true,
          )['calendarTooltip'],
          '',
        );
      }
    },
  );
  test(
    'overlaps use earliest end, and time advancement never changes fixture authority',
    () {
      var now = DateTime(2026, 10, 25, 14, 22);
      final calendar = CalendarController(
        now: () => now,
        scheduleUpdates: false,
      );
      addTearDown(calendar.dispose);
      calendar.select(CalendarFixture.overlapping);
      expect(calendar.active.map((e) => e.id), ['review', 'overlap']);
      expect(calendar.next?.id, 'planning');
      expect(calendar.act('overlaps', calendar.generation), isTrue);
      expect(
        calendar.sections.any((s) => s.title.contains('ALSO NOW')),
        isTrue,
      );
      now = now.add(const Duration(minutes: 8));
      expect(calendar.active.single.id, 'overlap');
      expect(calendar.fixture, CalendarFixture.overlapping);
    },
  );
  test(
    'all-day exclusive dates, Unicode titles and stale recovery stay distinct',
    () {
      final calendar = CalendarController(
        now: () => DateTime(2026, 10, 25, 14, 22),
        scheduleUpdates: false,
      );
      addTearDown(calendar.dispose);
      calendar.select(CalendarFixture.allDay);
      final rows = calendar.sections
          .where((s) => s.title.contains('ALL DAY'))
          .toList();
      expect(rows.map((s) => s.day), ['2026-10-25', '2026-10-26']);
      expect(calendar.active, isEmpty);
      calendar.select(CalendarFixture.longTitles);
      expect(
        calendar.sections.any((s) => s.title.contains('日本語 🧭 Café')),
        isTrue,
      );
      calendar.select(CalendarFixture.stale);
      expect(calendar.sections.first.id, 'stale-warning');
      final old = calendar.generation;
      expect(calendar.sections.any((s) => s.title.contains('Stale')), isTrue);
      expect(calendar.act('refresh', old), isTrue);
      expect(calendar.fixture, CalendarFixture.normal);
      expect(calendar.act('join:review', old), isFalse);
      expect(calendar.act('arbitrary', calendar.generation), isFalse);
      expect(calendar.act('join:review', calendar.generation), isTrue);
      expect(calendar.message, contains('no browser opened'));
    },
  );
  test(
    'connection cancellation and error retry are local fixture transitions',
    () {
      final calendar = CalendarController(scheduleUpdates: false);
      addTearDown(calendar.dispose);
      expect(calendar.act('connect', calendar.generation), isTrue);
      expect(calendar.fixture, CalendarFixture.connecting);
      expect(calendar.act('cancel', calendar.generation), isTrue);
      expect(calendar.fixture, CalendarFixture.disconnected);
      calendar.select(CalendarFixture.error);
      expect(calendar.act('retry', calendar.generation), isTrue);
      expect(calendar.fixture, CalendarFixture.normal);
    },
  );
  test(
    'desktop lock redacts snapshots, rejects delayed actions and retains the timer owner',
    () async {
      final controller = await AppController.create(
        MemoryRepository(),
        clock: FakeClock(),
      );
      final shell = FakeShell();
      final calendar = CalendarController(scheduleUpdates: false);
      final desktop = DesktopController(
        controller,
        shell,
        const DesktopEnvironment(
          dataDirectory: 'test-only',
          version: 'test',
          packaged: false,
          sessionState: 'unlocked',
        ),
        calendar: calendar,
      );
      addTearDown(() {
        desktop.dispose();
        controller.dispose();
      });
      await desktop.initialize();
      calendar.select(CalendarFixture.normal);
      await Future<void>.delayed(Duration.zero);
      expect(shell.snapshot['calendarTooltip'], isNotEmpty);
      final generation = calendar.generation;
      await shell.send('sessionState', {'state': 'locked'});
      expect(shell.snapshot['secondarySections'], isEmpty);
      expect(shell.snapshot['calendarTooltip'], '');
      await shell.send('calendarAction', {
        'generation': generation,
        'actionId': 'join:review',
      });
      expect(calendar.message, isEmpty);
      await shell.send('sessionState', {'state': 'unknown'});
      expect(shell.snapshot['secondarySections'], isEmpty);
      await shell.send('sessionState', {'state': 'unlocked'});
      expect(shell.snapshot['secondarySections'], isNotEmpty);
      await controller.updateDesktopPreferences(
        const DesktopPreferences(tooltipTitles: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(shell.snapshot['calendarTooltip'], '');
      await controller.toggleTimer();
      final run = controller.timer.runId;
      desktop.navigate(3);
      await shell.send('open');
      expect(desktop.destination, 0);
      expect(controller.timer.runId, run);
      expect(controller.timer.status, RunStatus.running);
      await desktop.showPopup();
      expect(controller.timer.runId, run);
    },
  );
  for (final appearance in ['light', 'dark']) {
    testWidgets(
      'calendar settings return exposes real agenda entry with 200% text and high contrast $appearance',
      (tester) async {
        tester.view.physicalSize = const Size(640, 1000);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(highContrast: true);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final controller = await AppController.create(
          MemoryRepository(
            SavedState(settings: TimerSettings(appearance: appearance)),
          ),
          clock: FakeClock(),
        );
        final shell = FakeShell();
        final desktop = DesktopController(
          controller,
          shell,
          const DesktopEnvironment(
            dataDirectory: 'test-only',
            version: 'test',
            packaged: false,
          ),
        );
        await desktop.initialize();
        await tester.pumpWidget(
          PomaApp(controller: controller, desktop: desktop),
        );
        desktop.navigate(3);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Quit Poma'),
          400,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('calendar-fixture')).hitTestable(),
          findsNothing,
        );
        await shell.onEvent!('sessionState', {'state': 'unlocked'});
        final opening = shell.onEvent!('settings', const {});
        await tester.pumpAndSettle();
        await opening;
        expect(find.text('Open calendar agenda').hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('calendar-fixture')),
          250,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('calendar-fixture')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        desktop.dispose();
        controller.dispose();
      },
    );
  }
  test(
    'old desktop preferences gain the title default without resetting existing choices',
    () {
      final preferences = DesktopPreferences.fromJson({
        'closeToTray': false,
        'closeExplained': true,
        'bounds': null,
      });
      expect(preferences.tooltipTitles, isTrue);
      expect(preferences.closeToTray, isFalse);
      expect(
        DesktopPreferences.fromJson(
          preferences.copyWith(tooltipTitles: false).toJson(),
        ).tooltipTitles,
        isFalse,
      );
    },
  );
}
