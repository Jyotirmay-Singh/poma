import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'contrast_support.dart';

void main() {
  for (final sample in [
    (
      name: 'Tasks',
      color: const Color(0xFF52627A),
      background: Colors.white,
      strike: false,
      opacity: 1.0,
      passes: true,
    ),
    (
      name: 'Read a chapter',
      color: const Color(0xFF202A43),
      background: Colors.white,
      strike: true,
      opacity: 1.0,
      passes: true,
    ),
    (
      name: 'Low contrast',
      color: const Color(0xFFAAAABB),
      background: Colors.white,
      strike: false,
      opacity: 1.0,
      passes: false,
    ),
    (
      name: 'Translucent ink',
      color: const Color(0x33202A43),
      background: Colors.white,
      strike: false,
      opacity: 1.0,
      passes: false,
    ),
    (
      name: 'Dark ink on dark',
      color: const Color(0xFF52627A),
      background: const Color(0xFF18233B),
      strike: false,
      opacity: 1.0,
      passes: false,
    ),
    (
      name: 'Faded parent',
      color: const Color(0xFF202A43),
      background: Colors.white,
      strike: false,
      opacity: .2,
      passes: false,
    ),
  ]) {
    testWidgets('painted-background contrast: ${sample.name}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: sample.background,
            body: Center(
              child: Opacity(
                opacity: sample.opacity,
                child: Text(
                  sample.name,
                  style: TextStyle(
                    fontFamily: 'Source Sans 3',
                    fontSize: sample.strike ? 16 : 14,
                    fontWeight: sample.strike
                        ? FontWeight.w400
                        : FontWeight.w600,
                    color: sample.color,
                    decoration: sample.strike
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final result = await RenderedTextContrastGuideline(
        finder: find.text(sample.name),
      ).evaluate(tester);
      expect(result.passed, sample.passes, reason: result.reason);
    });
  }
}
