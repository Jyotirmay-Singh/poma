import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/timer_engine.dart';
import '../domain/models.dart';
import 'copy.dart';

class TimerDial extends StatelessWidget {
  const TimerDial({required this.timer, required this.color, super.key});
  final TimerEngine timer;
  final Color color;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final diameter = min(320.0, constraints.maxWidth);
      final seconds = timer.remainingSeconds;
      final time =
          '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
      final timeStyle = DefaultTextStyle.of(context).style.copyWith(
        fontSize: diameter / 6.5,
        fontWeight: FontWeight.w500,
        letterSpacing: -1.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
      final phaseStyle = DefaultTextStyle.of(context).style.copyWith(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      );
      final numberMetrics = TextPainter(
        text: TextSpan(text: time, style: timeStyle),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout();
      final phaseMetrics = TextPainter(
        text: TextSpan(
          text: phaseName(context.copy, timer.phase),
          style: phaseStyle,
        ),
        textScaler: MediaQuery.textScalerOf(context),
        textDirection: Directionality.of(context),
      )..layout(maxWidth: diameter - 40);
      final contentWidth = max(numberMetrics.width, phaseMetrics.width);
      final contentHeight = numberMetrics.height + phaseMetrics.height + 43;
      final innerRadius = max(0.0, diameter / 2 - 40);
      // Keep the text block inside the tick marks, including its corners.
      final fits =
          pow(contentWidth / 2, 2) + pow(contentHeight / 2, 2) <=
          pow(innerRadius, 2);
      numberMetrics.dispose();
      phaseMetrics.dispose();
      final icon = Icon(
        timer.phase == FocusPhase.focus
            ? Icons.spa_outlined
            : Icons.coffee_outlined,
        color: color,
        size: 27,
      );
      final number = Text(time, textAlign: TextAlign.center, style: timeStyle);
      final phase = Text(
        phaseName(context.copy, timer.phase),
        textAlign: TextAlign.center,
        style: phaseStyle,
      );
      return Semantics(
        label:
            '${phaseName(context.copy, timer.phase)}, ${switch (timer.status) {
              RunStatus.ready => context.copy.ready,
              RunStatus.running => context.copy.running,
              RunStatus.paused => context.copy.paused,
            }}',
        value: context.copy.remaining(seconds ~/ 60, seconds % 60),
        child: ExcludeSemantics(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: diameter,
                child: CustomPaint(
                  painter: _DialPainter(
                    color: color,
                    track: Theme.of(context).colorScheme.outlineVariant,
                    progress: timer.progress,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          icon,
                          const SizedBox(height: 12),
                          if (fits) number,
                          const SizedBox(height: 4),
                          phase,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (!fits) ...[const SizedBox(height: 12), number],
            ],
          ),
        ),
      );
    },
  );
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.color,
    required this.track,
    required this.progress,
  });
  final Color color;
  final Color track;
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7;
    canvas.drawCircle(
      center,
      radius,
      paint..color = track.withValues(alpha: .45),
    );
    final remaining = max(0.0, 1 - progress);
    if (remaining > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * remaining,
        false,
        paint..color = color,
      );
    }
    for (var i = 0; i < 60; i++) {
      final angle = i * pi / 30 - pi / 2;
      final major = i % 5 == 0;
      final outer = radius - 13;
      final inner = outer - (major ? 8 : 3);
      canvas.drawLine(
        center + Offset(cos(angle), sin(angle)) * inner,
        center + Offset(cos(angle), sin(angle)) * outer,
        Paint()
          ..color = track
          ..strokeWidth = major ? 2 : 1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
