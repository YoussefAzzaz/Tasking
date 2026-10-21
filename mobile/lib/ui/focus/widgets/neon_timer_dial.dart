import 'dart:math';
import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

/// Custom painter for glowing multi-color gradient circular timer arc
class NeonProgressPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0

  NeonProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    // Track
    final trackPaint = Paint()
      ..color = AxisColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    final sweepAngle = 2 * pi * progress;
    final arcPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AxisColors.primary,
          AxisColors.secondary,
          AxisColors.tertiary,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant NeonProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Neon Radial Glow Timer Dial featuring custom progress ring and time display
class NeonTimerDial extends StatelessWidget {
  const NeonTimerDial({
    super.key,
    required this.progress,
    required this.timeDisplay,
    required this.isBreak,
  });

  final double progress;
  final String timeDisplay;
  final bool isBreak;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isBreak ? 'Break countdown timer' : 'Focus session timer',
      value: timeDisplay,
      child: Center(
        child: SizedBox(
          width: 250,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient glow shadow
              ExcludeSemantics(
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AxisColors.secondary.withValues(alpha: 0.12),
                        blurRadius: 50,
                        spreadRadius: 20,
                      ),
                    ],
                  ),
                ),
              ),
              // Ring painter
              ExcludeSemantics(
                child: CustomPaint(
                  size: const Size(250, 250),
                  painter: NeonProgressPainter(progress: progress),
                ),
              ),
              // Center Time Display
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'DEEP WAVE BETA',
                  style: TextStyle(
                    fontSize: 11,
                    color: AxisColors.secondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeDisplay,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 52,
                    fontWeight: FontWeight.bold,
                    color: AxisColors.textHigh,
                    letterSpacing: -2,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Text(
                    isBreak ? 'REBOOT BREAK' : 'QUANTUM 01/02',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.primarySoft,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      )),
    );
  }
}
