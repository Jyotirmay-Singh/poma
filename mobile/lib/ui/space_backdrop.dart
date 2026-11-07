import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The sky is separate from reading surfaces, which remain fully opaque.
@immutable
class PomaBackdropTheme extends ThemeExtension<PomaBackdropTheme> {
  const PomaBackdropTheme({
    required this.canvas,
    required this.purple,
    required this.teal,
    required this.stars,
    required this.decorated,
    required this.dark,
  });

  factory PomaBackdropTheme.fromColors(
    ColorScheme colors, {
    bool highContrast = false,
  }) => PomaBackdropTheme(
    canvas: highContrast
        ? colors.surface
        : colors.brightness == Brightness.dark
        ? const Color(0xFF0D1528)
        : const Color(0xFFF2F5FD),
    purple: colors.primary,
    teal: colors.brightness == Brightness.dark
        ? const Color(0xFF81D4CF)
        : const Color(0xFF147D80),
    stars: colors.onSurface,
    decorated: !highContrast,
    dark: colors.brightness == Brightness.dark,
  );

  final Color canvas;
  final Color purple;
  final Color teal;
  final Color stars;
  final bool decorated;
  final bool dark;

  @override
  PomaBackdropTheme copyWith({
    Color? canvas,
    Color? purple,
    Color? teal,
    Color? stars,
    bool? decorated,
    bool? dark,
  }) => PomaBackdropTheme(
    canvas: canvas ?? this.canvas,
    purple: purple ?? this.purple,
    teal: teal ?? this.teal,
    stars: stars ?? this.stars,
    decorated: decorated ?? this.decorated,
    dark: dark ?? this.dark,
  );

  @override
  PomaBackdropTheme lerp(PomaBackdropTheme? other, double t) => other == null
      ? this
      : PomaBackdropTheme(
          canvas: Color.lerp(canvas, other.canvas, t)!,
          purple: Color.lerp(purple, other.purple, t)!,
          teal: Color.lerp(teal, other.teal, t)!,
          stars: Color.lerp(stars, other.stars, t)!,
          decorated: t < .5 ? decorated : other.decorated,
          dark: t < .5 ? dark : other.dark,
        );

  @override
  bool operator ==(Object other) =>
      other is PomaBackdropTheme &&
      canvas == other.canvas &&
      purple == other.purple &&
      teal == other.teal &&
      stars == other.stars &&
      decorated == other.decorated &&
      dark == other.dark;

  @override
  int get hashCode => Object.hash(canvas, purple, teal, stars, decorated, dark);
}

/// One stationary scene behind the Navigator, including pushed legal routes.
class PomaBackdrop extends StatelessWidget {
  const PomaBackdrop({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette =
        theme.extension<PomaBackdropTheme>() ??
        PomaBackdropTheme.fromColors(
          theme.colorScheme,
          highContrast: MediaQuery.highContrastOf(context),
        );
    final icons = palette.dark ? Brightness.light : Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        statusBarBrightness: theme.brightness,
        systemNavigationBarColor: theme.colorScheme.surface,
        systemNavigationBarIconBrightness: icons,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  key: const ValueKey('poma-sky'),
                  child: CustomPaint(painter: _SkyPainter(palette)),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter(this.palette);
  final PomaBackdropTheme palette;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.canvas);
    if (!palette.decorated) return;

    void wash(Offset center, double radius, Color color, double opacity) {
      final bounds = Rect.fromCircle(center: center, radius: radius);
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }

    final extent = math.max(size.width, size.height);
    wash(
      Offset(size.width * .85, size.height * .12),
      extent * .62,
      palette.purple,
      palette.dark ? .09 : .08,
    );
    wash(
      Offset(size.width * .08, size.height * .86),
      extent * .50,
      palette.teal,
      palette.dark ? .06 : .045,
    );
    // A fixed seed keeps stars stable across rebuilds and screenshot fixtures.
    final random = math.Random(4871);
    final count = (size.width * size.height / 18000).round().clamp(20, 84);
    for (var i = 0; i < count; i++) {
      final point = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = .4 + random.nextDouble() * .65;
      final opacity = palette.dark
          ? .06 + random.nextDouble() * .08
          : .02 + random.nextDouble() * .035;
      canvas.drawCircle(
        point,
        radius,
        Paint()..color = palette.stars.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) => palette != oldDelegate.palette;
}
