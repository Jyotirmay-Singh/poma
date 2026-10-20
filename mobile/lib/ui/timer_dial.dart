import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/timer_engine.dart';

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
      return Semantics(
        label:
            '${timer.phase.label}, ${seconds ~/ 60} minutes ${seconds % 60} seconds remaining',
        child: ExcludeSemantics(
          child: SizedBox.square(
            dimension: diameter,
            child: CustomPaint(
              painter: _DialPainter(
                color: color,
                track: Theme.of(context).colorScheme.outlineVariant,
                progress: timer.progress,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        timer.phase.name == 'focus'
                            ? Icons.spa_outlined
                            : Icons.coffee_outlined,
                        color: color,
                        size: 27,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: diameter / 7.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timer.phase.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
