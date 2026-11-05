import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

const pomaPurple = Color(0xFF6854C8);
const pomaTeal = Color(0xFF147D80);

ThemeData pomaTheme(Brightness brightness, {bool highContrast = false}) {
  final dark = brightness == Brightness.dark;
  final standardColors =
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
  final colors = highContrast
      ? (dark
            ? const ColorScheme.dark(
                primary: Colors.yellow,
                onPrimary: Colors.black,
                surface: Colors.black,
                onSurface: Colors.white,
                onSurfaceVariant: Colors.white,
                outline: Colors.white,
                outlineVariant: Colors.white,
              )
            : const ColorScheme.light(
                primary: Color(0xFF000080),
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
                onSurfaceVariant: Colors.black,
                outline: Colors.black,
                outlineVariant: Colors.black,
              ))
      : standardColors;
  final textTheme = ThemeData(brightness: brightness).textTheme.apply(
    fontFamily: defaultTargetPlatform == TargetPlatform.windows
        ? 'Segoe UI'
        : null,
    bodyColor: colors.onSurface,
    displayColor: colors.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: const ChipThemeData(side: BorderSide(color: Color(0xFF747B8C))),
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
