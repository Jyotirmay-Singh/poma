import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/application/calendar_connection_controller.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/calendar_event_creation.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:poma/ui/day_clock_dial.dart';

import 'calendar_creation_ui_test.dart' as creation;
import 'calendar_read_test.dart' as reads;
import 'contrast_support.dart';
import 'day_clock_test.dart' as viewing;
import 'desktop_test.dart' show FakeShell;
import 'refinement_test.dart' show fullyVisibleText;

Future<void> checkTask(WidgetTester tester) async {
  final check = find.widgetWithText(OutlinedButton, 'Check task');
  await tester.ensureVisible(check);
  await tester.tap(check);
  await tester.runAsync(reads.settleCalendar);
  await tester.pumpAndSettle();
}

// Dispatch actual pointer gestures in the same real async context as the HTTP
// and storage fixtures. Never invoke an onPressed callback as a substitute.
Future<void> saveTask(WidgetTester tester, {bool twice = false}) async {
  final save = find.widgetWithText(FilledButton, 'Add to Google Calendar');
  await tester.ensureVisible(save);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    await tester.tap(save);
    if (twice) await tester.tap(save);
    await reads.settleCalendar();
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'dial-created form restores a visible opener after the header leaves the sliver tree',
    (tester) async {
      await creation.mount(tester, width: 640, scale: 2, reducedMotion: true);
      final dial = find.byKey(const ValueKey('day-clock-dial'));
      await tester.ensureVisible(dial);
      await tester.pumpAndSettle();
      final rect = tester.getRect(dial);
      await tester.tapAt(rect.center + Offset(rect.width * .28, 0));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-clock-task-form')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final add = find.byKey(const ValueKey('day-clock-add-task'));
      expect(tester.widget<FilledButton>(add).focusNode!.hasFocus, true);
      expect(
        tester.getRect(add).overlaps(Offset.zero & tester.view.physicalSize),
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [400.0, 560.0, 620.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('measured numeral clearances $width / $scale', (
        tester,
      ) async {
        final g = DayClockGeometry(
          Size.square(width),
          TextScaler.linear(scale),
        );
        expect(g.outerRadius, greaterThan(g.hubRadius));
        for (var i = 0; i < g.numeralBoxes.length; i++) {
          final box = g.numeralBoxes[i];
          for (final corner in [
            box.topLeft,
            box.topRight,
            box.bottomLeft,
            box.bottomRight,
          ]) {
            expect(
              (corner - g.center).distance,
              lessThanOrEqualTo(g.radius * .925 + .01),
            );
          }
          final closest = Offset(
            g.center.dx.clamp(box.left, box.right),
            g.center.dy.clamp(box.top, box.bottom),
          );
          expect(
            (closest - g.center).distance - g.overflowRadius,
            greaterThanOrEqualTo(6.9),
          );
          for (var j = 0; j < i; j++) {
            expect(box.overlaps(g.numeralBoxes[j]), false);
          }
        }
      });
    }
  }

  for (final explicitColor in [false, true]) {
    testWidgets(
      'actual fields and double Save create one 10–11 PM event, explicit colour $explicitColor',
      (tester) async {
        final (r, desktop) = await creation.mount(tester);
        final clock = desktop.dayClock!;
        await tester.tap(find.byKey(const ValueKey('day-clock-add-task')));
        await tester.pumpAndSettle();
        for (final entry in {
          'title': 'Fictional evening planning',
          'start-date': '2026-11-10',
          'end-date': '2026-11-10',
          'start-time': '10:00',
          'end-time': '11:00',
        }.entries) {
          await viewing.enter(tester, entry.key, entry.value);
        }
        expect(find.text('Google account: synthetic-primary'), findsOneWidget);
        expect(clock.draft!.startPm && clock.draft!.endPm, true);
        expect(clock.draft!.calendarId, 'synthetic-primary');
        if (explicitColor) {
          await tester.ensureVisible(
            find.byKey(const ValueKey('day-clock-colour-null')),
          );
          await tester.tap(find.byKey(const ValueKey('day-clock-colour-null')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Google colour 2').last);
          await tester.pumpAndSettle();
        }
        await checkTask(tester);
        final intent = clock.review!;
        expect(intent.startUtc, DateTime.utc(2026, 11, 10, 16, 30));
        expect(intent.endUtc, DateTime.utc(2026, 11, 10, 17, 30));
        expect(intent.startOffset, 330);
        expect(intent.endOffset, 330);
        expect(find.text('Duration: 60 minutes'), findsOneWidget);
        await creation.capture(
          tester,
          'gesture-reviewed-${explicitColor ? 'colour' : 'default'}',
        );
        r.google.loseResponse =
            true; // Google accepted it; the response is lost.
        await saveTask(tester, twice: true);
        expect(r.google.inserts, 1);
        expect(r.google.gets, 1);
        expect(r.google.events.length, 1);
        final event = r.google.events.values.single;
        expect(event['summary'], 'Fictional evening planning');
        expect(event['calendarId'], 'synthetic-primary');
        expect(event['eventType'], 'default');
        expect(event['colorId'], explicitColor ? '2' : null);
        expect(clock.operation!.state, CalendarCreationState.saved);
        expect(find.text('Saved to Google Calendar'), findsOneWidget);
        expect(
          find.text('Starts: 2026-11-10, 10:00 PM (UTC+05:30)'),
          findsOneWidget,
        );
        expect(
          find.text('Ends: 2026-11-10, 11:00 PM (UTC+05:30)'),
          findsOneWidget,
        );
        expect(
          find.text('Destination calendar: Personal (primary)'),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);
        await creation.capture(
          tester,
          'gesture-saved-${explicitColor ? 'colour' : 'default'}',
        );
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        final p = clock.projection;
        expect(p.agenda.length, 1);
        expect(p.sectors.length, 1);
        expect(p.sectors.single.startMinute, 600);
        expect(p.sectors.single.endMinute, 660);
        expect(p.sectors.single.sweep, closeTo(math.pi / 6, 1e-9));
        expect(p.scheduled, const Duration(hours: 1));
        expect(
          calendarEventIdentity(p.agenda.single),
          calendarEventIdentity(r.reader.events.single),
        );
        final fill = calendarEventFill(
          p.agenda.single,
          r.reader.sources.firstWhere((s) => s.id == 'synthetic-primary'),
          r.reader.palette,
        );
        expect(fill, explicitColor ? '#33B679' : '#123456');
        await creation.capture(
          tester,
          'gesture-clock-${explicitColor ? 'colour' : 'default'}',
        );
        final opener = tester.widget<FilledButton>(
          find.byKey(const ValueKey('day-clock-add-task')),
        );
        expect(opener.focusNode!.hasFocus, true);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'integrated minute tick retains painted dial and sky without any I/O',
    (tester) async {
      final (r, desktop) = await creation.mount(tester);
      r.google.events['current'] = {
        'id': 'current',
        'calendarId': 'synthetic-primary',
        'summary': 'Fictional current event',
        'status': 'confirmed',
        'start': {'dateTime': '2026-11-09T17:00:00+05:30'},
        'end': {'dateTime': '2026-11-09T18:00:00+05:30'},
      };
      await tester.runAsync(r.reader.refresh);
      desktop.dayClock!.now();
      await tester.pumpAndSettle();
      final face = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('day-clock-face')),
      );
      final sky = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('poma-sky')),
      );
      final hand = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('day-clock-hand')),
      );
      final facePicture = face.debugLayer!.firstChild,
          skyPicture = sky.debugLayer!.firstChild;
      final handPicture = hand.debugLayer!.firstChild;
      final requests = r.google.requests.length, saves = r.store.saves;
      final cache = r.reader.cache as reads.MemoryCalendarCache;
      final writes = cache.writes,
          angle = desktop.dayClock!.projection.handAngle;
      await tester.runAsync(
        () => r.scheduler.advance(const Duration(minutes: 1)),
      );
      await tester.pumpAndSettle();
      expect(desktop.dayClock!.projection.handAngle, isNot(angle));
      expect(face.debugLayer!.firstChild, same(facePicture));
      expect(sky.debugLayer!.firstChild, same(skyPicture));
      expect(hand.debugLayer!.firstChild, isNot(same(handPicture)));
      expect(r.google.requests.length, requests);
      expect(r.store.saves, saves);
      expect(cache.writes, writes);
    },
  );

  testWidgets(
    'reduced-motion form traps traversal and restores focus on Escape',
    (tester) async {
      await creation.mount(tester, reducedMotion: true, width: 640, scale: 2);
      final opener = tester.widget<FilledButton>(
        find.byKey(const ValueKey('day-clock-add-task')),
      );
      opener.focusNode!.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final form = find.byKey(const ValueKey('day-clock-task-form'));
      final context = tester.element(form);
      expect(
        (ModalRoute.of(context)! as TransitionRoute).transitionDuration,
        Duration.zero,
      );
      final scope = FocusScope.of(context);
      for (var i = 0; i < 26; i++) {
        final focused = FocusManager.instance.primaryFocus!;
        expect(focused == scope || focused.ancestors.contains(scope), true);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(form, findsNothing);
      expect(opener.focusNode!.hasFocus, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Saved hidden target and failed refresh keep one truthful result and explicit recovery',
    (tester) async {
      final (r, desktop) = await creation.mount(tester);
      await creation.open(tester, desktop, r);
      await tester.ensureVisible(
        find.byKey(const ValueKey('day-clock-destination-synthetic-primary')),
      );
      await tester.tap(
        find.byKey(const ValueKey('day-clock-destination-synthetic-primary')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Planning').last);
      await tester.pumpAndSettle();
      await checkTask(tester);
      r.google.failList = true;
      await saveTask(tester);
      expect(find.text('Saved to Google Calendar'), findsOneWidget);
      expect(find.textContaining('Its calendar is hidden'), findsOneWidget);
      expect(find.text('Show calendar'), findsOneWidget);
      expect(r.reader.selected, {'synthetic-primary'});
      await creation.capture(tester, 'saved-hidden-refresh-failed');
      r.google.failList = false;
      await tester.runAsync(() async {
        await tester.tap(find.text('Show calendar'));
        await reads.settleCalendar();
      });
      await tester.pumpAndSettle();
      expect(r.reader.selected, {'synthetic-primary', 'owned-secondary'});
      expect(desktop.dayClock!.projection.agenda.length, 1);
      expect(r.google.inserts, 1);
      expect(find.textContaining('calendar is hidden'), findsNothing);
    },
  );

  testWidgets(
    'offline kept draft returns online for renewed review without automatic insertion',
    (tester) async {
      final (r, desktop) = await creation.mount(tester);
      await creation.open(tester, desktop, r);
      final refresh = r.auth.onRefresh;
      r.auth.onRefresh = () =>
          throw const CalendarConnectionFailure(CalendarFailureKind.network);
      await tester.runAsync(
        () => r.connection.refreshRejectedAccess('synthetic-access'),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Keep draft'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Keep draft'));
        await reads.settleCalendar();
      });
      await tester.pumpAndSettle();
      expect(r.controller.journal!.drafts.length, 1);
      expect(r.google.inserts, 0);
      r.auth.onRefresh = refresh;
      await tester.runAsync(r.connection.accessToken);
      await tester.runAsync(r.reader.refresh);
      await tester.runAsync(reads.settleCalendar);
      await tester.pumpAndSettle();
      expect(r.google.inserts, 0);
      await tester.tap(find.byKey(const ValueKey('day-clock-add-task')));
      await tester.pumpAndSettle();
      expect(desktop.dayClock!.review, isNull);
      await checkTask(tester);
      await saveTask(tester);
      expect(r.google.inserts, 1);
      expect(find.text('Saved to Google Calendar'), findsOneWidget);
    },
  );

  for (final scale in [1.0, 1.5, 2.0]) {
    for (final dark in [false, true]) {
      for (final contrast in [false, true]) {
        testWidgets(
          'finished state review scale=$scale dark=$dark contrast=$contrast',
          (tester) async {
            final width = scale == 1.5
                ? 1080.0
                : scale == 2
                ? 640.0
                : 1440.0;
            final r = await viewing.mount(
              tester,
              width: width,
              scale: scale,
              dark: dark,
              highContrast: contrast,
              crowded: true,
            );
            final suffix =
                '${width.toInt()}-${(scale * 100).toInt()}-${dark ? 'dark' : 'light'}${contrast ? '-contrast' : ''}';
            await tester.ensureVisible(
              find.byKey(const ValueKey('day-clock-dial')),
            );
            await tester.pumpAndSettle();
            await viewing.capture(tester, 'finished-dense-$suffix');
            final row = find.byKey(
              ValueKey(
                'day-clock-event-${calendarEventIdentity(r.day.projection.agenda.last)}',
              ),
            );
            await tester.ensureVisible(row);
            await tester.pumpAndSettle();
            expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
            await tester.tap(row);
            await tester.pumpAndSettle();
            expect(r.day.selectedEvent, isNotNull);
            final semantics = tester.ensureSemantics();
            final node = tester.getSemantics(row);
            expect(
              node.getSemanticsData().hasAction(SemanticsAction.tap),
              true,
            );
            semantics.dispose();
            await viewing.capture(tester, 'finished-agenda-$suffix');
            r.provider.errors['work'] = const CalendarReadFailure(
              CalendarReadFailureKind.network,
            );
            await tester.runAsync(r.reader.refresh);
            await tester.pumpAndSettle();
            expect(r.day.projection.agenda, isNotEmpty);
            await viewing.capture(tester, 'finished-stale-$suffix');
            r.provider.errors.clear();
            r.day.browse(r.day.date, DayClockHalf.am);
            await tester.runAsync(r.reader.refresh);
            await tester.pumpAndSettle();
            expect(r.day.projection.agenda, isEmpty);
            await viewing.capture(tester, 'finished-empty-$suffix');
            await tester.runAsync(() => r.connection.disconnect());
            await tester.pumpAndSettle();
            expect(r.day.projection.sectors, isEmpty);
            await viewing.capture(tester, 'finished-disconnected-$suffix');
            await expectLater(
              tester,
              meetsGuideline(
                RenderedTextContrastGuideline(finder: fullyVisibleText(tester)),
              ),
            );
            await viewing.openForm(tester);
            await viewing.enter(tester, 'title', 'Fictional invalid task');
            await viewing.enter(tester, 'start-date', '2026-02-30');
            await checkTask(tester);
            expect(r.day.errors, contains('start'));
            expect(r.day.errors['calendar'], contains('Connect Google'));
            final error = tester.renderObject<RenderParagraph>(
              find.text(r.day.errors['calendar']!),
            );
            expect(
              error.didExceedMaxLines,
              false,
              reason:
                  'The complete recovery instruction must wrap at enlarged text sizes.',
            );
            await viewing.capture(tester, 'finished-form-error-$suffix');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets(
    'sleep and time-change events preserve manual browsing and resume Now across midnight',
    (tester) async {
      final (r, desktop) = await creation.mount(tester);
      final clock = desktop.dayClock!, shell = desktop.shell as FakeShell;
      clock.browse(CalendarDate(2026, 11, 10), DayClockHalf.pm);
      await tester.runAsync(() async {
        await shell.onEvent!('suspend', {});
        r.clock.time = DateTime.utc(2026, 11, 10, 19); // Nov 11, 00:30 IST.
        await shell.onEvent!('resume', {});
        await reads.settleCalendar();
      });
      await tester.pumpAndSettle();
      expect(clock.date.toString(), '2026-11-10');
      expect(clock.half, DayClockHalf.pm);
      expect(clock.projection.handAngle, isNull);
      clock.now();
      expect(clock.date.toString(), '2026-11-11');
      expect(clock.half, DayClockHalf.am);
      expect(clock.projection.handAngle, closeTo(dayClockAngle(30), 1e-9));
      expect(r.google.inserts, 0);
    },
  );
}
