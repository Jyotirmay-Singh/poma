import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:poma/application/calendar_read_ports.dart';
import 'package:poma/data/google_calendar_reader.dart';
import 'package:poma/domain/calendar_data.dart';
import 'package:poma/domain/day_clock.dart';
import 'package:poma/main.dart';
import 'package:poma/ui/day_clock_dial.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'calendar_read_test.dart' as f;
import 'day_clock_support.dart';
import 'contrast_support.dart';
import 'refinement_test.dart' show fullyVisibleText;
import 'desktop_test.dart' show FakeShell;

const folder = String.fromEnvironment('POMA_DAY_CLOCK_SCREENSHOTS');
Future<void> capture(WidgetTester tester, String name) async {
  if (folder.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('day-clock-capture')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$folder/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<DayClockRig> mount(
  WidgetTester tester, {
  double width = 1440,
  double height = 1100,
  double pixelRatio = 1,
  double scale = 1,
  bool dark = false,
  bool highContrast = false,
  bool crowded = false,
}) async {
  tester.view.physicalSize = Size(width, height) * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(highContrast: highContrast);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final r = (await tester.runAsync(() => dayClockRig(crowded: crowded)))!;
  if (dark) {
    await tester.runAsync(
      () => r.app.updateSettings(r.app.settings.copyWith(appearance: 'dark')),
    );
  }
  await tester.pumpWidget(
    RepaintBoundary(
      key: const ValueKey('day-clock-capture'),
      child: PomaApp(controller: r.app, desktop: r.desktop),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    r.dispose();
  });
  return r;
}

Future<void> openForm(WidgetTester tester) async {
  if (find.byKey(const ValueKey('day-clock-add-task')).evaluate().isEmpty) {
    final scrollable = find
        .ancestor(
          of: find.byKey(const ValueKey('day-clock-dial')),
          matching: find.byType(Scrollable),
        )
        .first;
    tester.state<ScrollableState>(scrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(const ValueKey('day-clock-add-task')));
  await tester.tap(find.byKey(const ValueKey('day-clock-add-task')));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final field = find.byKey(ValueKey('day-clock-$key'));
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

void main() {
  setUpAll(tz_data.initializeTimeZones);
  test(
    'shared presentation ticks perform no new network or storage work',
    () async {
      final r = await dayClockRig();
      addTearDown(r.dispose);
      final lists = r.provider.lists,
          writes = r.cache.writes,
          palettes = r.provider.paletteReads;
      final before = r.day.projection.handAngle;
      await r.scheduler.advance(const Duration(minutes: 1));
      expect(r.provider.lists, lists);
      expect(r.cache.writes, writes);
      expect(r.provider.paletteReads, palettes);
      expect(r.day.projection.handAngle, isNot(before));
      expect(r.day.projection.agenda.length, 5);
      expect(r.day.projection.allDay.length, 1);
      expect(r.day.destinations.map((s) => s.id), [
        'personal',
        'work',
        'reading',
      ]);
    },
  );
  test(
    'manual browsing survives refresh and expiry; Now follows noon and midnight',
    () async {
      final r = await dayClockRig();
      addTearDown(r.dispose);
      r.day.browse(CalendarDate(2026, 11, 10), DayClockHalf.am);
      await r.reader.refresh();
      expect(r.day.date.toString(), '2026-11-10');
      expect(r.day.half, DayClockHalf.am);
      r.clock.time = DateTime(2026, 11, 9, 11, 59).toUtc();
      r.day.now();
      expect(r.day.half, DayClockHalf.am);
      r.clock.time = DateTime(2026, 11, 9, 12).toUtc();
      r.day.timeContextChanged();
      expect(r.day.half, DayClockHalf.pm);
      r.day.browse(CalendarDate(2026, 11, 9), DayClockHalf.pm);
      r.clock.time = DateTime(2026, 11, 11, 0, 1).toUtc();
      await r.reader.lifecycleChanged();
      await f.settleCalendar();
      expect(r.day.date.toString(), '2026-11-09');
      expect(r.day.covered, isFalse);
      expect(r.day.projection.agenda, isEmpty);
      r.day.now();
      expect(r.day.date.toString(), '2026-11-11');
      expect(r.day.half, DayClockHalf.am);
    },
  );
  test(
    'draft validation freezes 10–11 PM, rejects bad dates/overnight/DST and keeps raw values',
    () async {
      final r = await dayClockRig();
      addTearDown(r.dispose);
      final d = r.day.beginDraft();
      d.title = 'Fictional late task';
      d.startDate = '2026-11-10';
      d.endDate = d.startDate;
      d.startTime = '10:00';
      d.endTime = '11:00';
      d.startPm = true;
      d.endPm = true;
      await r.day.validateDraft();
      final reviewed = r.day.review!;
      expect(reviewed.startUtc, DateTime(2026, 11, 10, 22).toUtc());
      expect(reviewed.endUtc, DateTime(2026, 11, 10, 23).toUtc());
      expect(reviewed.calendarId, 'personal');
      expect(r.day.creationConnected, isFalse);
      expect(r.day.overlapMessage, contains('0 known'));
      d.endTime = '1:00';
      d.endPm = false;
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.errors['end'], contains('explicitly change'));
      expect(d.endDate, '2026-11-10');
      d.endDate = '2026-11-11';
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.review, isNotNull);
      d.startDate = '2026-02-30';
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.errors['start'], isNotNull);
      expect(r.day.beginDraft().startDate, '2026-02-30');
      d.startDate = '2026-11-10';
      r.resolver.reject = true;
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.validationMessage, contains('skipped or repeated'));
      expect(d.title, 'Fictional late task');
    },
  );
  test(
    'draft destination, future-start and supported colour validation remain independent of focus writes',
    () async {
      final r = await dayClockRig();
      addTearDown(r.dispose);
      final d = r.day.beginDraft();
      d.title = 'Fictional';
      d.startDate = '2026-11-10';
      d.endDate = d.startDate;
      d.startTime = '10:00';
      d.endTime = '11:00';
      d.startPm = true;
      d.endPm = true;
      d.calendarId = 'team';
      await r.day.validateDraft();
      expect(r.day.errors['calendar'], isNotNull);
      d.calendarId = 'personal';
      d.colorId = '#112233';
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.errors['color'], isNotNull);
      d.colorId = '2';
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.review!.colorId, '2');
      d.startDate = '2026-11-08';
      d.endDate = d.startDate;
      r.day.touchDraft();
      await r.day.validateDraft();
      expect(r.day.errors['start'], contains('future'));
      expect(r.desktop.focusBlocks, isNull);
      expect(r.day.creationConnected, isFalse);
    },
  );
  test(
    'palette cache is optional, damaged palette retains events, and assigned colours remain authoritative',
    () async {
      final r = await dayClockRig();
      addTearDown(r.dispose);
      final json = r.cache.accounts[r.reader.accountKey]!.toJson();
      final old = Map<String, Object?>.from(json)..remove('eventPalette');
      expect(
        CalendarAccountData.fromJson(old, r.reader.accountKey!).palette,
        isNull,
      );
      old['eventPalette'] = {'colors': 'damaged'};
      expect(
        CalendarAccountData.fromJson(
          old,
          r.reader.accountKey!,
        ).snapshots.length,
        5,
      );
      final base = r.day.projection.agenda.first;
      final assigned = CalendarEvent.fromJson({
        ...base.toJson(),
        'colorId': '2',
      });
      expect(
        calendarEventFill(assigned, r.reader.sources.first, r.reader.palette),
        '#33B679',
      );
      final unknown = CalendarEvent.fromJson({
        ...base.toJson(),
        'colorId': 'unknown',
      });
      expect(
        calendarEventFill(unknown, r.reader.sources.first, r.reader.palette),
        isNull,
      );
      final label = CalendarEvent.fromJson({
        ...base.toJson(),
        'eventLabelId': 'custom-label',
      });
      expect(
        calendarEventFill(label, r.reader.sources.first, r.reader.palette),
        isNull,
      );
      r.provider.failPalette = true;
      r.clock.time = r.clock.time.add(const Duration(days: 1));
      await r.reader.refresh();
      expect(r.reader.paletteFailure, isNotNull);
      expect(r.reader.palette!.colors['2']!.background, '#33B679');
      expect(r.reader.events.length, 6);
    },
  );
  test(
    'Google reader retains IDs and fetches palette using GET with existing access',
    () async {
      final clock = f.TestCalendarClock(),
          scheduler = f.TestCalendarScheduler(f.TestCalendarClock());
      final requests = <String>[];
      final provider = GoogleCalendarReader(
        access: f.TestAccess(),
        clock: clock,
        scheduler: scheduler,
        clientFactory: () => MockClient((request) async {
          expect(request.method, 'GET');
          requests.add(request.url.path);
          if (request.url.path.endsWith('/colors')) {
            return f.jsonReply({
              'event': {
                '2': {'background': '#33B679', 'foreground': '#000000'},
              },
            });
          }
          expect(
            request.url.queryParameters['fields'],
            contains('colorId,eventLabelId'),
          );
          return f.jsonReply({
            'items': [
              {
                'id': 'fictional',
                'summary': 'Fictional',
                'colorId': '2',
                'eventLabelId': 'label-id',
                'start': {'dateTime': '2026-10-25T13:00:00Z'},
                'end': {'dateTime': '2026-10-25T14:00:00Z'},
              },
            ],
          });
        }),
      );
      addTearDown(provider.dispose);
      final events = await provider.events(
        const CalendarSource(
          id: 'fictional',
          name: 'Fictional',
          accessRole: 'owner',
          timeZone: 'UTC',
        ),
        clock.window(),
      );
      expect(events.single.colorId, '2');
      expect(events.single.eventLabelId, 'label-id');
      final palette = await provider.eventPalette();
      expect(palette.colors['2']!.background, '#33B679');
      expect(requests.length, 2);
    },
  );
  testWidgets(
    'sector selection links agenda and empty space prefills an editable draft',
    (tester) async {
      final r = await mount(tester);
      final dial = find.byKey(const ValueKey('day-clock-dial'));
      var rect = tester.getRect(dial),
          center = rect.center,
          radius = rect.width / 2 - 4;
      final angle = dayClockAngle(210);
      await tester.tapAt(
        center + Offset(math.cos(angle), math.sin(angle)) * radius * .55,
      );
      await tester.pumpAndSettle();
      expect(r.day.selectedEvent!.id, 'travel');
      expect(find.textContaining('Starts:'), findsOneWidget);
      await tester.ensureVisible(dial);
      await tester.pumpAndSettle();
      rect = tester.getRect(dial);
      center = rect.center;
      radius = rect.width / 2 - 4;
      final gap = dayClockAngle(372);
      await tester.tapAt(
        center + Offset(math.cos(gap), math.sin(gap)) * radius * .55,
      );
      await tester.pumpAndSettle();
      expect(r.day.draft!.startTime, '6:10');
      expect(r.day.draft!.startPm, isTrue);
      expect(find.text('Add to Google Calendar'), findsOneWidget);
      final finalAction = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add to Google Calendar'),
      );
      expect(finalAction.onPressed, isNull);
    },
  );
  testWidgets(
    'form keeps fields across Escape and navigation; lock removes private content',
    (tester) async {
      final r = await mount(tester);
      await openForm(tester);
      await enter(tester, 'title', 'Fictional saved draft');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(r.day.draft!.title, 'Fictional saved draft');
      r.desktop.navigate(0);
      await tester.pumpAndSettle();
      r.desktop.navigate(5);
      await tester.pumpAndSettle();
      await openForm(tester);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('day-clock-title')))
            .controller!
            .text,
        'Fictional saved draft',
      );
      await tester.runAsync(
        () => (r.desktop.shell as FakeShell).onEvent!('sessionState', {
          'state': 'locked',
        }),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-clock-task-form')), findsNothing);
      expect(find.text('Fictional saved draft'), findsNothing);
      expect(r.day.draft!.title, 'Fictional saved draft');
      await tester.runAsync(
        () => (r.desktop.shell as FakeShell).onEvent!('sessionState', {
          'state': 'unlocked',
        }),
      );
      await tester.pumpAndSettle();
      await openForm(tester);
      await tester.runAsync(r.connection.disconnect);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('day-clock-task-form')), findsNothing);
      expect(find.text('Fictional saved draft'), findsNothing);
      expect(r.day.draft, isNull);
    },
  );
  testWidgets(
    'checked form exposes elapsed duration and no save action is connected',
    (tester) async {
      final r = await mount(tester);
      await openForm(tester);
      await enter(tester, 'title', 'Fictional late task');
      await enter(tester, 'start-date', '2026-11-10');
      await enter(tester, 'end-date', '2026-11-10');
      await enter(tester, 'start-time', '10:00');
      await enter(tester, 'end-time', '11:00');
      await tester.ensureVisible(find.text('Check task'));
      await tester.tap(find.text('Check task'));
      await tester.pumpAndSettle();
      expect(r.day.review, isNotNull);
      expect(find.text('Duration: 60 minutes'), findsOneWidget);
      expect(r.day.creationConnected, isFalse);
    },
  );
  test(
    'refresh retains sectors, deselection clears details, disconnect purges the account draft',
    () async {
      final r = await dayClockRig();
      addTearDown(r.dispose);
      final gate = Completer<List<CalendarEvent>>();
      r.provider.onEvents = (_, _) => gate.future;
      final refresh = r.reader.refresh();
      await f.settleCalendar();
      expect(r.reader.refreshing, isTrue);
      expect(r.day.projection.agenda.length, 5);
      gate.complete(r.provider.items['personal']!);
      r.provider.onEvents = null;
      await refresh;
      r.day.select(
        r.day.projection.agenda.singleWhere((e) => e.id == 'travel'),
      );
      await r.reader.select({...r.reader.selected}..remove('travel'));
      expect(r.day.selectedEvent, isNull);
      expect(r.day.projection.agenda.length, 4);
      r.day.beginDraft().title = 'Fictional draft';
      final result = await r.day.submitReviewed();
      expect(result.event, isNull);
      expect(result.message, contains('unavailable'));
      expect(r.day.draft!.title, 'Fictional draft');
      await r.connection.disconnect();
      await f.settleCalendar();
      expect(r.day.draft, isNull);
      expect(r.day.projection.agenda, isEmpty);
    },
  );
  test(
    'an explicit new dial position updates draft times while retaining title and duration',
    () async {
      final r = await dayClockRig();
      addTearDown(r.dispose);
      final d = r.day.beginDraft();
      d.title = 'Fictional retained title';
      d.startTime = '4:00';
      d.endTime = '6:00';
      d.startPm = true;
      d.endPm = true;
      r.day.beginDraft(minute: 600);
      expect(d.title, 'Fictional retained title');
      expect(d.startTime, '10:00');
      expect(d.endTime, '12:00');
      expect(d.endDate, '2026-11-10');
      expect(d.endPm, isFalse);
    },
  );
  testWidgets(
    'keyboard traverses time fields and chooses AM/PM with labelled controls',
    (tester) async {
      final r = await mount(tester);
      final semantics = tester.ensureSemantics();
      try {
        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('day-clock-add-task')))
              .label,
          contains('Add task'),
        );
        await openForm(tester);
        EditableText editable(String key) => tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey('day-clock-$key')),
            matching: find.byType(EditableText),
          ),
        );
        expect(editable('title').focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(editable('start-date').focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(editable('start-time').focusNode.hasFocus, isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('day-clock-task-form')),
          findsOneWidget,
        );
        expect(r.day.draft!.startPm, isFalse);
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'partial snapshots remain visible and empty/unselected halves retain honest coverage',
    (tester) async {
      final r = await mount(tester);
      r.provider.errors['work'] = const CalendarReadFailure(
        CalendarReadFailureKind.network,
      );
      await tester.runAsync(() => r.reader.refresh());
      await tester.pumpAndSettle();
      expect(r.day.projection.agenda.length, 5);
      expect(r.day.agenda.verified(r.reader.window), isFalse);
      r.day.select(
        r.day.projection.agenda.firstWhere((e) => e.calendarId == 'work'),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Saved or incomplete schedule'),
        findsOneWidget,
      );
      await capture(tester, 'partial-retained-light');
      r.day.browse(r.day.date, DayClockHalf.am);
      await tester.pumpAndSettle();
      expect(r.day.projection.handAngle, isNull);
      expect(r.day.projection.agenda, isEmpty);
      expect(
        find.text('No retained timed events. Availability is unknown.'),
        findsOneWidget,
      );
      await capture(tester, 'empty-am-unknown-light');
      await tester.runAsync(() => r.reader.select({}));
      await tester.pumpAndSettle();
      expect(r.day.projection.allDay, isEmpty);
      expect(find.text('Choose calendars'), findsOneWidget);
      await capture(tester, 'unselected-light');
    },
  );
  for (final width in [640.0, 1080.0, 1440.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('ordinary clock $width / $scale / dark=$dark', (
          tester,
        ) async {
          final r = await mount(tester, width: width, scale: scale, dark: dark);
          expect(find.byKey(const ValueKey('day-clock-dial')), findsOneWidget);
          expect(r.day.projection.agenda.length, 5);
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            'ordinary-${width.toInt()}-${(scale * 100).round()}-${dark ? 'dark' : 'light'}',
          );
          if (width == 640 || scale > 1) {
            await tester.ensureVisible(
              find.byKey(const ValueKey('day-clock-dial')),
            );
            await tester.pumpAndSettle();
            await capture(
              tester,
              'ordinary-${width.toInt()}-${(scale * 100).round()}-${dark ? 'dark' : 'light'}-dial',
            );
          }
          if (width == 1440 && scale == 1) {
            await expectLater(
              tester,
              meetsGuideline(
                RenderedTextContrastGuideline(finder: fullyVisibleText(tester)),
              ),
            );
          }
        });
      }
    }
  }
  for (final dark in [false, true]) {
    for (final width in [640.0, 1440.0]) {
      testWidgets('crowded clock $width / dark=$dark', (tester) async {
        final r = await mount(tester, width: width, dark: dark, crowded: true);
        expect(r.day.projection.sectors.any((s) => s.lane >= 4), isTrue);
        final overflow = r.day.projection.sectors
            .firstWhere((s) => s.lane >= 4)
            .event;
        r.day.select(overflow);
        await tester.pumpAndSettle();
        expect(r.day.selectedEvent, overflow);
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'crowded-${width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await tester.ensureVisible(
          find.byKey(
            ValueKey(
              'day-clock-event-${calendarEventIdentity(r.day.projection.agenda.last)}',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(
          tester,
          'crowded-${width.toInt()}-${dark ? 'dark' : 'light'}-agenda',
        );
      });
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets('task form $width / $scale / dark=$dark', (tester) async {
          final r = await mount(tester, width: width, scale: scale, dark: dark);
          await openForm(tester);
          await enter(tester, 'title', 'Fictional evening planning');
          await enter(tester, 'start-date', '2026-11-10');
          await enter(tester, 'end-date', '2026-11-10');
          await enter(tester, 'start-time', '10:00');
          await enter(tester, 'end-time', '11:00');
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Check task'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Check task'));
          await tester.pumpAndSettle();
          expect(
            r.day.review!.endUtc.difference(r.day.review!.startUtc),
            const Duration(hours: 1),
          );
          await tester.ensureVisible(
            find.descendant(
              of: find.byKey(const ValueKey('day-clock-task-form')),
              matching: find.text('Add task'),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final name =
              'form-${width.toInt()}-${(scale * 100).round()}-${dark ? 'dark' : 'light'}';
          await capture(tester, '$name-top');
          await tester.ensureVisible(find.text('Add to Google Calendar'));
          await tester.pumpAndSettle();
          await capture(tester, '$name-bottom');
          if (width == 1440 && scale == 1) {
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
          }
          expect(tester.takeException(), isNull);
        });
      }
      testWidgets('high contrast clock $width / dark=$dark', (tester) async {
        final r = await mount(
          tester,
          width: width,
          scale: 2,
          dark: dark,
          highContrast: true,
          crowded: true,
        );
        final overflow = r.day.projection.sectors
            .firstWhere((s) => s.lane >= 4)
            .event;
        r.day.select(overflow);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          'high-contrast-${width.toInt()}-${dark ? 'dark' : 'light'}',
        );
        await expectLater(
          tester,
          meetsGuideline(
            RenderedTextContrastGuideline(finder: fullyVisibleText(tester)),
          ),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('day-clock-dial')),
        );
        await tester.pumpAndSettle();
        await capture(
          tester,
          'high-contrast-${width.toInt()}-${dark ? 'dark' : 'light'}-dial',
        );
        await openForm(tester);
        await enter(tester, 'title', 'Fictional high-contrast draft');
        await tester.ensureVisible(
          find.descendant(
            of: find.byKey(const ValueKey('day-clock-task-form')),
            matching: find.text('Add task'),
          ),
        );
        await tester.pumpAndSettle();
        await capture(
          tester,
          'form-high-contrast-${width.toInt()}-${dark ? 'dark' : 'light'}-top',
        );
        await tester.ensureVisible(find.text('Add to Google Calendar'));
        await tester.pumpAndSettle();
        await capture(
          tester,
          'form-high-contrast-${width.toInt()}-${dark ? 'dark' : 'light'}-bottom',
        );
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
      });
    }
  }
}
