import 'package:flutter/widgets.dart';

import '../application/planner_controller.dart';

class PlannerScope extends InheritedNotifier<PlannerController> {
  const PlannerScope({
    required PlannerController planner,
    required super.child,
    super.key,
  }) : super(notifier: planner);

  static PlannerController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlannerScope>()?.notifier;
}
