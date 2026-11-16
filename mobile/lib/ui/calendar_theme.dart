import 'package:flutter/material.dart';
import 'package:kalender/kalender.dart' as k;

ThemeData calendarWorkspaceTheme(BuildContext context) {
  final theme = Theme.of(context);
  if (MediaQuery.highContrastOf(context)) return theme;
  final dark = theme.brightness == Brightness.dark;
  final colors = theme.colorScheme.copyWith(
    primary: dark ? const Color(0xFFA8C7FA) : const Color(0xFF1A73E8),
    onPrimary: dark ? const Color(0xFF062E6F) : Colors.white,
    primaryContainer: dark ? const Color(0xFF004A77) : const Color(0xFFD3E3FD),
    onPrimaryContainer: dark
        ? const Color(0xFFC2E7FF)
        : const Color(0xFF041E49),
    surface: dark ? const Color(0xFF1E1F20) : Colors.white,
    surfaceContainerLowest: dark ? const Color(0xFF131314) : Colors.white,
    surfaceContainerLow: dark
        ? const Color(0xFF1E1F20)
        : const Color(0xFFF8FAFD),
    surfaceContainer: dark ? const Color(0xFF282A2C) : const Color(0xFFF0F4F9),
    surfaceContainerHigh: dark
        ? const Color(0xFF303134)
        : const Color(0xFFE9EEF6),
    surfaceContainerHighest: dark
        ? const Color(0xFF3C4043)
        : const Color(0xFFE3E9F1),
    onSurface: dark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
    onSurfaceVariant: dark ? const Color(0xFFC4C7C5) : const Color(0xFF444746),
    outline: dark ? const Color(0xFF8E918F) : const Color(0xFF747775),
    outlineVariant: dark ? const Color(0xFF444746) : const Color(0xFFDADCE0),
  );
  return theme.copyWith(
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surfaceContainerLow,
    dialogTheme: theme.dialogTheme.copyWith(backgroundColor: colors.surface),
    bottomSheetTheme: theme.bottomSheetTheme.copyWith(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: theme.textButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(
          dark ? colors.primary : const Color(0xFF174EA6),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: theme.outlinedButtonTheme.style?.copyWith(
        foregroundColor: WidgetStatePropertyAll(
          dark ? colors.primary : const Color(0xFF174EA6),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    extensions: [
      ...theme.extensions.values.where(
        (extension) => extension is! k.KalenderThemeData,
      ),
      k.KalenderThemeData(
        hourLinesStyle: k.HourLinesStyle(
          color: colors.outlineVariant,
          thickness: 1,
        ),
        daySeparatorStyle: k.DaySeparatorStyle(
          color: colors.outlineVariant,
          width: 1,
        ),
        monthGridStyle: k.MonthGridStyle(
          color: colors.outlineVariant,
          thickness: 1,
        ),
        timeIndicatorStyle: const k.TimeIndicatorStyle(
          lineColor: Color(0xFFEA4335),
          thickness: 1.5,
          circleSize: Size(8, 8),
        ),
        dayHeaderStyle: k.DayHeaderStyle(
          textStyle: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          numberTextStyle: theme.textTheme.titleLarge?.copyWith(
            color: colors.onSurface,
            fontSize: 26,
          ),
        ),
        dayNumberStyle: k.DayNumberStyle(
          todayBackgroundColor: colors.primary,
          todayForegroundColor: colors.onPrimary,
        ),
        timelineStyle: k.TimelineStyle(
          textStyle: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ),
    ],
    textTheme: theme.textTheme.apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primaryContainer,
        foregroundColor: colors.onPrimaryContainer,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
  );
}
