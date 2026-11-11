import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/calendar_event_creation.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:poma/application/calendar_read_ports.dart';

import 'calendar_creation_ui_test.dart' as creation;
import 'calendar_read_test.dart' show settleCalendar;
import 'day_clock_completion_test.dart' show checkTask, saveTask;
import 'day_clock_test.dart' as viewing;
import 'contrast_support.dart';
import 'refinement_test.dart' show fullyVisibleText;

const repairCaptures = String.fromEnvironment(
  'POMA_DAY_CLOCK_REPAIR_SCREENSHOTS',
);

Future<void> captureRepair(
  WidgetTester tester,
  String name, {
  bool created = false,
}) async {
  if (repairCaptures.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(ValueKey(created ? 'creation-capture' : 'day-clock-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$repairCaptures/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> enterEveningTask(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('day-clock-add-task')));
  await tester.pumpAndSettle();
  for (final entry in {
    'title': 'Fictional repair evening',
    'start-date': '2026-11-10',
    'end-date': '2026-11-10',
    'start-time': '10:00',
    'end-time': '11:00',
  }.entries) {
    await viewing.enter(tester, entry.key, entry.value);
  }
  for (final endpoint in ['start', 'end']) {
    final period = find.byKey(ValueKey('day-clock-$endpoint-period'));
    await tester.ensureVisible(period);
    await tester.pumpAndSettle();
    await tester.tap(period);
    await tester.pumpAndSettle();
    await tester.tap(find.text('PM').last);
    await tester.pumpAndSettle();
  }
}

void main() {
  // Heights below are Flutter client heights. The 1067×754 normal Windows
  // baseline includes 30 units of chrome; maximized baseline includes 24.
  for (final spec in [
    (1067.0, 724.0),
    (1280.0, 770.0),
    (1536.0, 816.0),
    (1536.0, 1000.0),
  ]) {
    testWidgets('complete first viewport at ${spec.$1}x${spec.$2}', (
      tester,
    ) async {
      final r = await viewing.mount(
        tester,
        width: spec.$1,
        height: spec.$2,
        dark: true,
      );
      for (final source in r.provider.items.keys.toList()) {
        r.provider.items[source] = r.provider.items[source]!
            .where((e) => !e.allDay)
            .toList();
      }
      await tester.runAsync(r.reader.refresh);
      await tester.pumpAndSettle();
      await captureRepair(
        tester,
        'concept-${spec.$1.toInt()}-${spec.$2.toInt()}',
      );
      final rect = tester.getRect(find.byKey(const ValueKey('day-clock-dial')));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
        rect.bottom,
        lessThanOrEqualTo(spec.$2),
        reason: 'Complete circle must fit the first viewport.',
      );
      expect(rect.width, greaterThanOrEqualTo(400));
      final agenda = find.text('Agenda');
      expect(agenda, findsOneWidget);
      expect(tester.getRect(agenda).top, lessThan(spec.$2));
      expect(tester.takeException(), isNull);
    });
  }

  for (final ratio in [1.25, 2.0]) {
    testWidgets(
      'complete normal logical viewport at device pixel ratio $ratio',
      (tester) async {
        await viewing.mount(
          tester,
          width: 1067,
          height: 724,
          pixelRatio: ratio,
          dark: true,
        );
        final rect = tester.getRect(
          find.byKey(const ValueKey('day-clock-dial')),
        );
        expect(rect.bottom, lessThanOrEqualTo(724));
        expect(rect.width, greaterThanOrEqualTo(400));
        await captureRepair(tester, 'dpi-${(ratio * 100).toInt()}');
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [1067.0, 1536.0]) {
    testWidgets('desktop empty hidden and stale first viewports $width', (
      tester,
    ) async {
      final height = width == 1067 ? 724.0 : 816.0;
      final r = await viewing.mount(
        tester,
        width: width,
        height: height,
        dark: true,
      );
      final original = {
        for (final e in r.provider.items.entries)
          e.key: List<CalendarEvent>.of(e.value),
      };
      void completeCircle() {
        final rect = tester.getRect(
          find.byKey(const ValueKey('day-clock-dial')),
        );
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(height));
        expect(tester.getRect(find.text('Agenda')).top, lessThan(height));
      }

      for (final id in r.provider.items.keys.toList()) {
        r.provider.items[id] = [];
      }
      await tester.runAsync(r.reader.refresh);
      await tester.pumpAndSettle();
      expect(r.day.projection.sectors, isEmpty);
      completeCircle();
      await captureRepair(tester, 'empty-${width.toInt()}');
      await tester.runAsync(() => r.reader.select({}));
      await tester.pumpAndSettle();
      expect(find.text('Choose calendars'), findsOneWidget);
      completeCircle();
      await captureRepair(tester, 'hidden-${width.toInt()}');
      r.provider.items.addAll(original);
      await tester.runAsync(() => r.reader.select(original.keys.toSet()));
      r.provider.errors['personal'] = const CalendarReadFailure(
        CalendarReadFailureKind.network,
      );
      await tester.runAsync(r.reader.refresh);
      await tester.pumpAndSettle();
      expect(r.day.projection.sectors, isNotEmpty);
      completeCircle();
      await captureRepair(tester, 'stale-${width.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'hidden saved task reveals the correct PM date and selected event once',
    (tester) async {
      final (r, desktop) = await creation.mount(
        tester,
        width: 1067,
        height: 724,
      );
      final clock = desktop.dayClock!;
      await tester.runAsync(() => r.reader.select({}));
      clock.browse(CalendarDate(2026, 11, 9), DayClockHalf.am);
      await tester.pumpAndSettle();
      await enterEveningTask(tester);
      await checkTask(tester);
      expect(clock.review!.startUtc, DateTime.utc(2026, 11, 10, 16, 30));
      expect(clock.review!.endUtc, DateTime.utc(2026, 11, 10, 17, 30));
      await saveTask(tester, twice: true);
      expect(r.google.inserts, 1);
      expect(r.google.events.length, 1);
      expect(clock.operation!.state, CalendarCreationState.saved);
      await captureRepair(tester, 'saved-hidden', created: true);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await captureRepair(tester, 'revealed-evening', created: true);
      expect(clock.date.toString(), '2026-11-10');
      expect(clock.half, DayClockHalf.pm);
      expect(r.reader.selected, {'synthetic-primary'});
      expect(clock.projection.sectors, hasLength(1));
      final sector = clock.projection.sectors.single;
      expect(sector.startMinute, 600);
      expect(sector.endMinute, 660);
      expect(sector.sweep, closeTo(math.pi / 6, 1e-9));
      expect(clock.projection.agenda, hasLength(1));
      expect(clock.selectedIdentity, calendarEventIdentity(sector.event));
      final row = find.byKey(
        ValueKey('day-clock-event-${clock.selectedIdentity}'),
      );
      expect(row, findsOneWidget);
      expect(tester.getRect(row).bottom, lessThanOrEqualTo(724));
      await tester.runAsync(r.reader.refresh);
      await tester.runAsync(settleCalendar);
      expect(r.google.inserts, 1);
    },
  );

  testWidgets(
    'unchecked save keeps browsing, then the persistent receipt reveals without resubmitting',
    (tester) async {
      final (r, desktop) = await creation.mount(
        tester,
        width: 1067,
        height: 724,
        reducedMotion: true,
      );
      final clock = desktop.dayClock!;
      await tester.runAsync(() => r.reader.select({}));
      clock.browse(CalendarDate(2026, 11, 9), DayClockHalf.am);
      await tester.pumpAndSettle();
      await enterEveningTask(tester);
      final showChoice = find.byKey(
        const ValueKey('day-clock-show-after-saving'),
      );
      await tester.ensureVisible(showChoice);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(showChoice).value, true);
      await tester.tap(showChoice);
      await tester.pumpAndSettle();
      await checkTask(tester);
      await captureRepair(tester, 'reviewed-opt-out', created: true);
      await saveTask(tester);
      await captureRepair(tester, 'saved-opt-out', created: true);
      expect(clock.date.toString(), '2026-11-09');
      expect(r.reader.selected, isEmpty);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('day-clock-saved-receipt')),
        findsOneWidget,
      );
      expect(find.byTooltip('Open in Google Calendar'), findsOneWidget);
      await captureRepair(tester, 'receipt-hidden', created: true);
      desktop.navigate(0);
      await tester.pumpAndSettle();
      desktop.navigate(5);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('day-clock-saved-receipt')),
        findsOneWidget,
      );
      final show = find.byKey(const ValueKey('day-clock-receipt-show'));
      await tester.runAsync(() async {
        await tester.tap(show);
        await settleCalendar();
      });
      await tester.pumpAndSettle();
      expect(clock.date.toString(), '2026-11-10');
      expect(clock.half, DayClockHalf.pm);
      expect(clock.selectedEvent!.id, clock.savedReceipt!.eventId);
      expect(r.google.inserts, 1);
      await captureRepair(tester, 'receipt-revealed', created: true);
      await tester.tap(find.byKey(const ValueKey('day-clock-add-task')));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('day-clock-saved-receipt')),
        findsOneWidget,
      );
      final add = tester.widget<FilledButton>(
        find.byKey(const ValueKey('day-clock-add-task')),
      );
      expect(add.focusNode!.hasFocus, true);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Show scrolls the matching late agenda row into the bounded desktop viewport',
    (tester) async {
      final (r, desktop) = await creation.mount(
        tester,
        width: 1067,
        height: 724,
      );
      final clock = desktop.dayClock!;
      for (var i = 0; i < 18; i++) {
        r.google.events['earlier-$i'] = {
          'id': 'earlier-$i',
          'calendarId': 'synthetic-primary',
          'summary': 'Fictional earlier item $i',
          'status': 'confirmed',
          'start': {
            'dateTime':
                '2026-11-10T${(12 + i ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '00' : '30'}:00+05:30',
          },
          'end': {
            'dateTime':
                '2026-11-10T${(12 + i ~/ 2).toString().padLeft(2, '0')}:${i.isEven ? '15' : '45'}:00+05:30',
          },
        };
      }
      final draft = r.draft();
      await tester.runAsync(() => r.controller.submit(draft, r.intent(draft)));
      final op = r.controller.journal!.operations[draft.id]!;
      await tester.pumpAndSettle();
      await tester.runAsync(() => clock.revealSaved(op));
      await tester.pumpAndSettle();
      final row = find.byKey(
        ValueKey('day-clock-event-${clock.selectedIdentity}'),
      );
      final bounds = tester.getRect(row);
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(724));
      expect(clock.projection.agenda, hasLength(19));
      expect(r.google.inserts, 1);
      final dial = tester.getRect(find.byKey(const ValueKey('day-clock-dial')));
      expect(dial.top, greaterThanOrEqualTo(0));
      expect(dial.bottom, lessThanOrEqualTo(724));
      await captureRepair(tester, 'selected-scrolled-agenda', created: true);
    },
  );

  for (final spec in [
    for (final width in [640.0, 1067.0, 1536.0])
      for (final scale in [1.0, 1.5, 2.0])
        for (final appearance in [
          (false, false),
          (true, false),
          (true, true),
          (false, true),
        ])
          (width, scale, appearance.$1, appearance.$2),
  ]) {
    testWidgets('repair accessible viewport $spec', (tester) async {
      final r = await viewing.mount(
        tester,
        width: spec.$1,
        height: spec.$1 == 1536 ? 816 : 724,
        scale: spec.$2,
        dark: spec.$3,
        highContrast: spec.$4,
        crowded: spec.$2 >= 1.5,
      );
      expect(tester.takeException(), isNull);
      final label =
          '${spec.$1.toInt()}-${(spec.$2 * 100).toInt()}-${spec.$3 ? 'dark' : 'light'}${spec.$4 ? '-contrast' : ''}';
      await captureRepair(tester, 'matrix-$label');
      final add = find.byKey(const ValueKey('day-clock-add-task'));
      await tester.ensureVisible(add);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: add, matching: fullyVisibleText(tester)),
        findsOneWidget,
      );
      final semantics = tester.ensureSemantics();
      await expectLater(
        tester,
        meetsGuideline(
          RenderedTextContrastGuideline(finder: fullyVisibleText(tester)),
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('day-clock-dial')));
      await tester.pumpAndSettle();
      await captureRepair(tester, 'matrix-dial-$label');
      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('day-clock-dial'))).label,
        contains('chronological agenda'),
      );
      semantics.dispose();
      await tester.ensureVisible(find.text('Agenda'));
      await tester.pumpAndSettle();
      await captureRepair(tester, 'matrix-agenda-$label');
      expect(
        fullyVisibleText(
          tester,
        ).evaluate().any((e) => (e.widget as Text).data == 'Agenda'),
        true,
      );
      if (spec.$2 == 1 && spec.$1 >= 1067) {
        final rect = tester.getRect(
          find.byKey(const ValueKey('day-clock-dial')),
        );
        expect(rect.bottom, lessThanOrEqualTo(spec.$1 == 1536 ? 816 : 724));
      }
      expect(r.day.projection.sectors, isNotEmpty);
    });
    testWidgets('repair creation viewport $spec', (tester) async {
      final (r, desktop) = await creation.mount(
        tester,
        width: spec.$1,
        height: spec.$1 == 1536 ? 816 : 724,
        scale: spec.$2,
        dark: spec.$3,
        highContrast: spec.$4,
        reducedMotion: true,
      );
      await creation.open(tester, desktop, r);
      final suffix =
          '${spec.$1.toInt()}-${(spec.$2 * 100).toInt()}-${spec.$3 ? 'dark' : 'light'}${spec.$4 ? '-contrast' : ''}';
      await captureRepair(tester, 'form-$suffix', created: true);
      final showChoice = find.byKey(
        const ValueKey('day-clock-show-after-saving'),
      );
      await tester.ensureVisible(showChoice);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(showChoice).value, true);
      await checkTask(tester);
      await captureRepair(tester, 'review-$suffix', created: true);
      await expectLater(
        tester,
        meetsGuideline(
          RenderedTextContrastGuideline(
            finder: find.descendant(
              of: find.byKey(const ValueKey('day-clock-task-form')),
              matching: fullyVisibleText(tester),
            ),
          ),
        ),
      );
      await saveTask(tester);
      final dialog = find.byKey(const ValueKey('day-clock-task-form'));
      final heading = find.descendant(
        of: dialog,
        matching: find.text('Saved to Google Calendar'),
      );
      await tester.ensureVisible(heading);
      await tester.pumpAndSettle();
      expect(heading, findsOneWidget);
      await captureRepair(tester, 'saved-$suffix', created: true);
      for (final element
          in find
              .descendant(of: dialog, matching: find.byType(Text))
              .evaluate()) {
        final paragraph = element.renderObject;
        if (paragraph is RenderParagraph) {
          expect(paragraph.didExceedMaxLines, false);
        }
      }
      await tester.ensureVisible(find.text('Close'));
      await tester.pumpAndSettle();
      await captureRepair(tester, 'saved-actions-$suffix', created: true);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      final clock = desktop.dayClock!;
      expect(clock.projection.sectors, hasLength(1));
      expect(clock.selectedIdentity, isNotNull);
      expect(r.google.inserts, 1);
      final row = find.byKey(
        ValueKey('day-clock-event-${clock.selectedIdentity}'),
      );
      final addFinder = find.byKey(const ValueKey('day-clock-add-task'));
      final addFocused =
          addFinder.evaluate().isNotEmpty &&
          tester.widget<FilledButton>(addFinder).focusNode!.hasFocus;
      final selected = tester.widget<InkWell>(row);
      await captureRepair(tester, 'form-result-$suffix', created: true);
      expect(
        addFocused || selected.focusNode!.hasFocus,
        true,
        reason:
            'Focus should return to a visible action: primary=${FocusManager.instance.primaryFocus?.debugLabel}; rowCanFocus=${selected.focusNode!.canRequestFocus}',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
