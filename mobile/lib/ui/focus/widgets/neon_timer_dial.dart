import 'dart:math';
import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

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
    this.size = 250,
    this.isRunning = false,
  });

  final double progress;
  final String timeDisplay;
  final bool isBreak;
  final double size;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final innerGlow = size * 0.76;
    final fontSize = size * 0.208;

    return Semantics(
      label: isBreak ? 'Break countdown timer' : 'Focus session timer',
      value: timeDisplay,
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ambient glow shadow
              ExcludeSemantics(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  width: innerGlow,
                  height: innerGlow,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isBreak ? AxisColors.warning : AxisColors.secondary)
                            .withValues(alpha: isRunning ? 0.22 : 0.12),
                        blurRadius: isRunning ? 65 : 45,
                        spreadRadius: isRunning ? 25 : 15,
                      ),
                    ],
                  ),
                ),
              ),
              // Ring painter
              ExcludeSemantics(
                child: CustomPaint(
                  size: Size(size, size),
                  painter: NeonProgressPainter(progress: progress),
                ),
              ),
              // Center Time Display
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isBreak
                        ? (context.isArabic
                            ? 'راحة واستعادة نشاط'
                            : 'REST & RECOVER')
                        : (isRunning
                            ? (context.isArabic
                                ? 'حالة التدفق نشطة'
                                : 'FLOW STATE ACTIVE')
                            : (context.isArabic
                                ? 'موجة التركيز العميق'
                                : 'DEEP WAVE BETA')),
                    style: TextStyle(
                      fontSize: size > 260 ? 12 : 11,
                      color: isBreak ? AxisColors.warning : AxisColors.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeDisplay,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: fontSize,
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
                      isBreak
                          ? (context.isArabic ? 'استراحة' : 'REBOOT BREAK')
                          : (context.isArabic ? 'تركيز كمي' : 'QUANTUM FOCUS'),
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
        ),
      ),
    );
  }
}
