import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> openCalendarTasks(WidgetTester tester) async {
  final destination = find.byKey(const Key('destination-4'));
  await tester.tap(
    destination.evaluate().isNotEmpty
        ? destination
        : find.byTooltip('Calendar').first,
  );
  await tester.pumpAndSettle();
  if (find
      .byKey(const ValueKey('calendar-add-unscheduled'))
      .hitTestable()
      .evaluate()
      .isEmpty) {
    await tester.tap(find.byKey(const ValueKey('calendar-drawer')));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(
    find.byKey(const ValueKey('calendar-add-unscheduled')),
  );
  await tester.pumpAndSettle();
}

Future<void> enterCalendarTask(WidgetTester tester, String title) async {
  await tester.tap(find.byKey(const ValueKey('calendar-add-unscheduled')));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 20)),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('planner-title')), title);
}

Future<void> closeCalendarDrawer(WidgetTester tester) async {
  final scaffold = tester
      .stateList<ScaffoldState>(find.byType(Scaffold))
      .where((state) => state.isDrawerOpen)
      .firstOrNull;
  scaffold?.closeDrawer();
  await tester.pumpAndSettle();
}
