import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

/// Ambient background layer with technical coordinate grid and chromatic fog radials.
class SplashTechnicalGrid extends StatelessWidget {
  const SplashTechnicalGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      children: [
        // 1. Ambient Technical Coordinate Grid
        const Positioned.fill(
          child: CustomPaint(
            painter: TechnicalGridPainter(),
          ),
        ),

        // 2. Atmospheric Chromatic Fog Radials
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AxisColors.secondary.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.secondary.withValues(alpha: 0.18),
                  blurRadius: 110,
                  spreadRadius: 40,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: screenHeight * 0.32,
          left: screenWidth * 0.5 - 140,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AxisColors.primary.withValues(alpha: 0.14),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.primary.withValues(alpha: 0.16),
                  blurRadius: 120,
                  spreadRadius: 30,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -60,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AxisColors.secondary.withValues(alpha: 0.08),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.secondary.withValues(alpha: 0.10),
                  blurRadius: 90,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for subtle 28px technical coordinate grid.
class TechnicalGridPainter extends CustomPainter {
  const TechnicalGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AxisColors.secondary.withValues(alpha: 0.035)
      ..strokeWidth = 1.0;

    const step = 28.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
