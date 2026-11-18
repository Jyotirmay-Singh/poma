import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'space_backdrop.dart';

abstract final class NebulaColors {
  static const canvas = Color(0xFF100B1B);
  static const surface = Color(0xFF1B142B);
  static const panel = Color(0xEB1B142B);
  static const text = Color(0xFFF5F1FC);
  static const secondaryText = Color(0xFFC9BEDB);
  static const lavender = Color(0xFFCDB7FF);
  static const breakAccent = Color(0xFF8DD6CA);
}

bool usesNebulaAppearance(BuildContext context) =>
    Theme.of(context).extension<PomaBackdropTheme>()?.nebula ?? false;

ThemeData nebulaTheme(ThemeData base) {
  final colors = base.colorScheme.copyWith(
    primary: NebulaColors.lavender,
    onPrimary: NebulaColors.canvas,
    primaryContainer: const Color(0xFF39264F),
    onPrimaryContainer: NebulaColors.text,
    secondary: NebulaColors.breakAccent,
    onSecondary: NebulaColors.canvas,
    secondaryContainer: const Color(0xFF30243E),
    onSecondaryContainer: NebulaColors.text,
    surface: NebulaColors.surface,
    surfaceContainerLowest: NebulaColors.canvas,
    surfaceContainerLow: NebulaColors.surface,
    surfaceContainer: NebulaColors.surface,
    surfaceContainerHigh: const Color(0xFF261C37),
    surfaceContainerHighest: const Color(0xFF30243E),
    onSurface: NebulaColors.text,
    onSurfaceVariant: NebulaColors.secondaryText,
    outline: const Color(0xFF9B88B5),
    outlineVariant: const Color(0xFF77628E),
    surfaceTint: Colors.transparent,
  );
  final text = base.textTheme.apply(
    bodyColor: colors.onSurface,
    displayColor: colors.onSurface,
  );
  final backdrop =
      base.extension<PomaBackdropTheme>() ??
      PomaBackdropTheme.fromColors(base.colorScheme);
  return base.copyWith(
    colorScheme: colors,
    canvasColor: colors.surface,
    textTheme: text,
    extensions: [
      ...base.extensions.values.where((value) => value is! PomaBackdropTheme),
      backdrop.copyWith(
        canvas: NebulaColors.canvas,
        purple: NebulaColors.lavender,
        teal: NebulaColors.breakAccent,
        stars: NebulaColors.text,
        nebula: true,
      ),
    ],
    chipTheme: base.chipTheme.copyWith(
      labelStyle: base.chipTheme.labelStyle?.copyWith(color: colors.onSurface),
      side: BorderSide(color: colors.outline),
    ),
    listTileTheme: base.listTileTheme.copyWith(
      titleTextStyle: base.listTileTheme.titleTextStyle?.copyWith(
        color: colors.onSurface,
      ),
      subtitleTextStyle: base.listTileTheme.subtitleTextStyle?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      labelStyle: base.inputDecorationTheme.labelStyle?.copyWith(
        color: colors.onSurface,
      ),
      helperStyle: base.inputDecorationTheme.helperStyle?.copyWith(
        color: colors.onSurface,
      ),
      errorStyle: base.inputDecorationTheme.errorStyle?.copyWith(
        color: colors.error,
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: colors.surface,
      titleTextStyle: base.dialogTheme.titleTextStyle?.copyWith(
        color: colors.onSurface,
      ),
      contentTextStyle: base.dialogTheme.contentTextStyle?.copyWith(
        color: colors.onSurface,
      ),
    ),
    popupMenuTheme: base.popupMenuTheme.copyWith(
      color: colors.surface,
      textStyle: base.popupMenuTheme.textStyle?.copyWith(
        color: colors.onSurface,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      foregroundColor: colors.onSurface,
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(
        color: colors.onSurface,
      ),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      backgroundColor: NebulaColors.canvas,
      indicatorColor: colors.primary.withValues(alpha: .18),
      selectedIconTheme: IconThemeData(color: colors.primary),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
      selectedLabelTextStyle: base.navigationRailTheme.selectedLabelTextStyle
          ?.copyWith(color: colors.primary),
      unselectedLabelTextStyle: base
          .navigationRailTheme
          .unselectedLabelTextStyle
          ?.copyWith(color: colors.onSurfaceVariant),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: NebulaColors.canvas,
      indicatorColor: colors.primary.withValues(alpha: .18),
    ),
    dividerTheme: base.dividerTheme.copyWith(
      color: colors.outlineVariant.withValues(alpha: .4),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
      ),
    ),
  );
}

/// The shell keeps the same structure when the appearance or destination changes.
class PomaNebulaScene extends StatelessWidget {
  const PomaNebulaScene({
    required this.enabled,
    required this.child,
    super.key,
  });
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final active =
        enabled &&
        base.brightness == Brightness.dark &&
        !MediaQuery.highContrastOf(context) &&
        base.extension<PomaBackdropTheme>()?.decorated != false;
    final theme = active ? nebulaTheme(base) : base;
    final icons = theme.brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: icons,
          statusBarBrightness: theme.brightness,
          systemNavigationBarColor: active
              ? NebulaColors.canvas
              : theme.colorScheme.surface,
          systemNavigationBarIconBrightness: icons,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: active
                  ? const IgnorePointer(
                      child: ExcludeSemantics(
                        child: RepaintBoundary(
                          key: ValueKey('poma-nebula'),
                          child: _NebulaImage(),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _NebulaImage extends StatelessWidget {
  const _NebulaImage();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final portrait = size.maxHeight > size.maxWidth;
      final aspectRatio = portrait ? 9 / 16 : 16 / 9;
      final physicalWidth =
          math.max(size.maxWidth, size.maxHeight * aspectRatio) *
          MediaQuery.devicePixelRatioOf(context);
      // Bucket resizing so a window drag does not fill the image cache.
      final decodeWidth = ((physicalWidth / 256).ceil() * 256).clamp(
        1,
        portrait ? 941 : 1672,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: NebulaColors.canvas),
          Image.asset(
            portrait
                ? 'assets/backgrounds/nebula-portrait.webp'
                : 'assets/backgrounds/nebula-landscape.webp',
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            gaplessPlayback: true,
            excludeFromSemantics: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          ColoredBox(color: NebulaColors.canvas.withValues(alpha: .5)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.05,
                colors: [
                  Colors.transparent,
                  NebulaColors.canvas.withValues(alpha: .48),
                ],
                stops: const [.35, 1],
              ),
            ),
          ),
        ],
      );
    },
  );
}
