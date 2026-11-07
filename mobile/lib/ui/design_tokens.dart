import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Logical units at 100% text scaling. Use roles rather than screen-specific
/// sizes so changes remain consistent across the mobile and desktop surfaces.
abstract final class PomaSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

abstract final class PomaLayout {
  static const double readingWidth = 800;
  static const double workspaceWidth = 1120;
  static const double navigationRail = 700;
  static const double extendedRail = 1000;
  static const double splitFocus = 900;
  static const double controlRadius = 8;
  static const double panelRadius = 12;
  static const double controlHeight = 48;

  static double pageInset(double width, {double maxWidth = readingWidth}) =>
      math.max(
        width < 600 ? PomaSpace.md : PomaSpace.lg,
        (width - maxWidth) / 2,
      );
}

abstract final class PomaType {
  static const family = 'Source Sans 3';
  static const displayFamily = 'Sora';
  // Fallback is only used for characters absent from the bundled family.
  // Flutter retains the platform's final fallback for other writing systems.
  static const fallback = [
    'Segoe UI',
    'Roboto',
    'Arial',
    'Yu Gothic',
    'Noto Sans CJK JP',
  ];
  static const pageTitle = TextStyle(
    fontFamily: displayFamily,
    letterSpacing: 0,
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeight.w600,
  );
  static const sectionTitle = TextStyle(
    fontFamily: displayFamily,
    letterSpacing: 0,
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeight.w600,
  );
  static const body = TextStyle(
    fontFamily: family,
    letterSpacing: 0,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );
  static const bodyStrong = TextStyle(
    fontFamily: family,
    letterSpacing: 0,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w600,
  );
  static const secondary = TextStyle(
    fontFamily: family,
    letterSpacing: 0,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w500,
  );
  static const control = TextStyle(
    fontFamily: family,
    letterSpacing: 0,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
  );
  static const caption = TextStyle(
    fontFamily: family,
    letterSpacing: 0,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
  );
  static const countdown = TextStyle(
    fontFamily: displayFamily,
    fontSize: 48,
    height: 1.15,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static TextTheme get textTheme => const TextTheme(
    displayLarge: countdown,
    displayMedium: countdown,
    displaySmall: countdown,
    headlineLarge: pageTitle,
    headlineMedium: pageTitle,
    headlineSmall: pageTitle,
    titleLarge: sectionTitle,
    titleMedium: sectionTitle,
    titleSmall: bodyStrong,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: secondary,
    labelLarge: control,
    labelMedium: control,
    labelSmall: caption,
  ).apply(fontFamilyFallback: fallback);
}
