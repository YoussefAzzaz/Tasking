import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/qibla_service.dart';
import 'qibla_metrics_widgets.dart';

/// Interactive compass gauge with rotating outer ring, Kaaba marker, and navigation needle.
class QiblaCompassDial extends StatelessWidget {
  const QiblaCompassDial({
    super.key,
    required this.status,
  });

  final QiblaStatus status;

  @override
  Widget build(BuildContext context) {
    final isFacing = status.isFacingQibla;
    final headingRad = -(status.deviceHeading * (math.pi / 180.0));
    final qiblaRad = (status.qiblaBearing * (math.pi / 180.0));
    final isArabic = context.isArabic;

    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating outer compass dial (North, East, South, West)
          Transform.rotate(
            angle: headingRad,
            child: SizedBox(
              width: 250,
              height: 250,
              child: CustomPaint(
                painter: CompassDialPainter(
                  isAligned: isFacing,
                  isArabic: isArabic,
                ),
              ),
            ),
          ),

          // Kaaba Marker on the outer rim
          Transform.rotate(
            angle: headingRad + qiblaRad,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isFacing ? AxisColors.success : const Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: (isFacing
                              ? AxisColors.success
                              : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.6),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.mosque_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          // Central Arrow pointing towards Kaaba relative to phone
          Transform.rotate(
            angle: (status.qiblaOffset * (math.pi / 180.0)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.navigation_rounded,
                  size: 44,
                  color: isFacing ? AxisColors.success : AxisColors.secondary,
                  shadows: [
                    Shadow(
                      color: (isFacing
                              ? AxisColors.success
                              : AxisColors.secondary)
                          .withValues(alpha: 0.6),
                      blurRadius: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),

          // Center Hub
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFF0F1A2B),
              shape: BoxShape.circle,
              border: Border.all(
                color: isFacing ? AxisColors.success : AxisColors.borderPrimary,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${status.deviceHeading.round()}°',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color:
                          isFacing ? AxisColors.success : AxisColors.textHigh,
                    ),
                  ),
                  Text(
                    QiblaAlignmentBanner.localizedCardinal(
                        status.cardinalDirection, isArabic),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color:
                          isFacing ? AxisColors.success : AxisColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that draws accurate compass tick marks and cardinal points
class CompassDialPainter extends CustomPainter {
  final bool isAligned;
  final bool isArabic;

  const CompassDialPainter({
    required this.isAligned,
    this.isArabic = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer circle
    final outerPaint = Paint()
      ..color = isAligned
          ? AxisColors.success.withValues(alpha: 0.5)
          : AxisColors.borderPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius - 4, outerPaint);

    // Degree tick marks
    final majorTickPaint = Paint()
      ..color = AxisColors.textHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final minorTickPaint = Paint()
      ..color = AxisColors.borderGlass2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int degree = 0; degree < 360; degree += 5) {
      final rad = degree * (math.pi / 180.0);
      final isMajor = degree % 30 == 0;
      final isCardinal = degree % 90 == 0;

      if (isCardinal) continue; // Drawn as text below

      final tickLength = isMajor ? 8.0 : 4.0;
      final startR = radius - 6;
      final endR = startR - tickLength;

      final start = Offset(
        center.dx + startR * math.sin(rad),
        center.dy - startR * math.cos(rad),
      );
      final end = Offset(
        center.dx + endR * math.sin(rad),
        center.dy - endR * math.cos(rad),
      );

      canvas.drawLine(start, end, isMajor ? majorTickPaint : minorTickPaint);
    }

    // Cardinal Points (N, E, S, W)
    final northLabel = isArabic ? 'ش' : 'N';
    final eastLabel = isArabic ? 'ق' : 'E';
    final southLabel = isArabic ? 'ج' : 'S';
    final westLabel = isArabic ? 'غ' : 'W';

    _drawCardinal(canvas, center, radius - 20, northLabel, const Color(0xFFEF4444));
    _drawCardinal(canvas, center, radius - 20, eastLabel, AxisColors.textHigh,
        angle: 90);
    _drawCardinal(canvas, center, radius - 20, southLabel, AxisColors.textHigh,
        angle: 180);
    _drawCardinal(canvas, center, radius - 20, westLabel, AxisColors.textHigh,
        angle: 270);
  }

  void _drawCardinal(
      Canvas canvas, Offset center, double r, String text, Color color,
      {double angle = 0}) {
    final rad = angle * (math.pi / 180.0);
    final pos = Offset(
      center.dx + r * math.sin(rad),
      center.dy - r * math.cos(rad),
    );

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );

    final tp = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CompassDialPainter oldDelegate) =>
      oldDelegate.isAligned != isAligned || oldDelegate.isArabic != isArabic;
}

