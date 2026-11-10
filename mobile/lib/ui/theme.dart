import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'space_backdrop.dart';

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
        surface: dark ? const Color(0xFF18233B) : Colors.white,
        surfaceContainerLowest: dark ? const Color(0xFF18233B) : Colors.white,
        surfaceContainerLow: dark ? const Color(0xFF18233B) : Colors.white,
        surfaceContainer: dark ? const Color(0xFF18233B) : Colors.white,
        surfaceContainerHigh: dark ? const Color(0xFF18233B) : Colors.white,
        surfaceContainerHighest: dark
            ? const Color(0xFF22304C)
            : const Color(0xFFE9EDF8),
        surfaceTint: Colors.transparent,
        onSurface: dark ? const Color(0xFFEDF2FF) : const Color(0xFF202A43),
        onSurfaceVariant: dark
            ? const Color(0xFFB8C5DC)
            : const Color(0xFF52627A),
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
  final textTheme = PomaType.textTheme.apply(
    bodyColor: colors.onSurface,
    displayColor: colors.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    fontFamily: PomaType.family,
    fontFamilyFallback: PomaType.fallback,
    scaffoldBackgroundColor: highContrast ? colors.surface : Colors.transparent,
    canvasColor: colors.surface,
    extensions: [
      PomaBackdropTheme.fromColors(colors, highContrast: highContrast),
    ],
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(PomaLayout.controlHeight),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size.square(PomaLayout.controlHeight),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: PomaSpace.md,
          vertical: PomaSpace.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: textTheme.labelLarge,
      side: BorderSide(color: colors.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
      ),
    ),
    // The same bundled font works offline on every supported platform.
    textTheme: textTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, PomaLayout.controlHeight),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: PomaSpace.md,
          vertical: PomaSpace.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, PomaLayout.controlHeight),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: PomaSpace.md,
          vertical: PomaSpace.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: textTheme.bodySmall,
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall?.copyWith(color: colors.error),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: PomaSpace.md,
        vertical: PomaSpace.sm,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
      ),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: textTheme.bodyMedium,
      subtitleTextStyle: textTheme.bodySmall?.copyWith(
        color: colors.onSurfaceVariant,
      ),
      horizontalTitleGap: PomaSpace.sm,
      minVerticalPadding: PomaSpace.xs,
      contentPadding: const EdgeInsets.symmetric(horizontal: PomaSpace.sm),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PomaLayout.panelRadius),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.labelLarge,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PomaLayout.controlRadius),
      ),
    ),
    appBarTheme: AppBarTheme(
      titleTextStyle: textTheme.headlineSmall,
      backgroundColor: highContrast ? colors.surface : Colors.transparent,
      foregroundColor: colors.onSurface,
      scrolledUnderElevation: 0,
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: textTheme.labelLarge,
      dataTextStyle: textTheme.bodyMedium,
      horizontalMargin: PomaSpace.sm,
      columnSpacing: PomaSpace.lg,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.surface,
      indicatorColor: highContrast
          ? colors.primary
          : colors.primary.withValues(alpha: .10),
      selectedIconTheme: highContrast
          ? IconThemeData(color: colors.onPrimary)
          : null,
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: colors.primary,
      ),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: colors.onSurfaceVariant,
      ),
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
