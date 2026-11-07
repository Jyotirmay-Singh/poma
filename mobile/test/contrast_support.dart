import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG evaluates the configured foreground, not a frequent antialiased edge
/// shade. Flutter's histogram-only guideline can choose an edge instead of the
/// text color for short or struck-through labels on Linux. Keep the same 4.5:1
/// requirement and sample the actual painted backing, excluding solid glyphs.
/// https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
class RenderedTextContrastGuideline extends AccessibilityGuideline {
  const RenderedTextContrastGuideline({required this.finder});
  final Finder finder;

  @override
  String get description =>
      'Text colors contrast with their painted background';

  @override
  Future<Evaluation> evaluate(WidgetTester tester) async {
    final images = <ui.FlutterView, ui.Image>{};
    final data = <ui.FlutterView, ByteData>{};
    var result = const Evaluation.pass();
    try {
      for (final element in finder.evaluate().toList()) {
        final text = element.widget as Text;
        final inherited = DefaultTextStyle.of(element).style;
        final style = text.style == null
            ? inherited
            : text.style!.inherit
            ? inherited.merge(text.style)
            : text.style!;
        if (style.foreground?.shader != null) {
          result += Evaluation.fail(
            'Shader text needs a dedicated contrast check: ${text.data}',
          );
          continue;
        }
        var foreground = style.foreground?.color ?? style.color ?? Colors.black;
        var opacity = 1.0;
        element.visitAncestorElements((ancestor) {
          final widget = ancestor.widget;
          if (widget is Opacity) opacity *= widget.opacity;
          if (widget is AnimatedOpacity) opacity *= widget.opacity;
          if (widget is FadeTransition) opacity *= widget.opacity.value;
          return true;
        });
        foreground = foreground.withValues(alpha: foreground.a * opacity);
        final view = tester.viewOf(
          find.byElementPredicate((e) => e == element),
        );
        if (!images.containsKey(view)) {
          final renderView = tester.binding.renderViews.firstWhere(
            (r) => r.flutterView == view,
          );
          final layer = renderView.debugLayer! as OffsetLayer;
          await tester.runAsync(() async {
            final image = images[view] = await layer.toImage(
              renderView.paintBounds,
              pixelRatio: 1 / view.devicePixelRatio,
            );
            data[view] = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
          });
        }
        final image = images[view]!;
        final raw = data[view]!;
        final pixels = raw.buffer.asUint8List(
          raw.offsetInBytes,
          raw.lengthInBytes,
        );
        final render = element.renderObject! as RenderBox;
        final bounds = MatrixUtils.transformRect(
          render.getTransformTo(null),
          render.paintBounds.inflate(4),
        );
        final histogram = <int, int>{};
        for (
          var y = math.max(0, bounds.top.floor());
          y < math.min(image.height, bounds.bottom.ceil());
          y++
        ) {
          for (
            var x = math.max(0, bounds.left.floor());
            x < math.min(image.width, bounds.right.ceil());
            x++
          ) {
            final i = (y * image.width + x) * 4;
            final color = Color.fromARGB(
              pixels[i + 3],
              pixels[i],
              pixels[i + 1],
              pixels[i + 2],
            ).toARGB32();
            if (color != foreground.toARGB32())
              histogram.update(color, (n) => n + 1, ifAbsent: () => 1);
          }
        }
        if (histogram.isEmpty) {
          result += Evaluation.fail(
            'No contrasting background for ${text.data}',
          );
          continue;
        }
        final backing = histogram.entries.reduce(
          (a, b) => a.value >= b.value ? a : b,
        );
        final background = Color(backing.key);
        final ink = Color.alphaBlend(foreground, background).computeLuminance();
        final surface = background.computeLuminance();
        final ratio =
            (math.max(ink, surface) + .05) / (math.min(ink, surface) + .05);
        if (ratio < 4.5)
          result += Evaluation.fail(
            '${text.data}: configured contrast ${ratio.toStringAsFixed(3)}:1 is below 4.5:1.',
          );
      }
      return result;
    } finally {
      for (final image in images.values) {
        image.dispose();
      }
    }
  }
}
