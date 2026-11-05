import 'package:flutter/material.dart';
import '../application/desktop_controller.dart';

class DesktopScope extends InheritedNotifier<DesktopController> {
  const DesktopScope({
    required DesktopController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static DesktopController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesktopScope>()?.notifier;
}
