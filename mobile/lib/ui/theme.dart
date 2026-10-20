import 'package:flutter/material.dart';

const pomaPurple = Color(0xFF6854C8);
const pomaTeal = Color(0xFF147D80);

ThemeData pomaTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: pomaPurple,
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFC9BFFF) : pomaPurple,
        onPrimary: dark ? const Color(0xFF281B5C) : Colors.white,
        surface: dark ? const Color(0xFF1C2332) : const Color(0xFFF8F9FD),
        onSurface: dark ? const Color(0xFFF1F3FC) : const Color(0xFF252D43),
        onSurfaceVariant: dark
            ? const Color(0xFFB7BFD2)
            : const Color(0xFF5F687E),
      );
  final textTheme = ThemeData(brightness: brightness).textTheme.apply(
    bodyColor: colors.onSurface,
    displayColor: colors.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    visualDensity: VisualDensity.standard,
    // System type works offline and adds no font assets to the app.
    textTheme: textTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        textStyle: textTheme.labelLarge?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primary.withValues(alpha: .12),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant.withValues(alpha: .55),
    ),
  );
}
