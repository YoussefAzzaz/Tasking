import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';

/// Central kinetic orbital core with rotating rings, counter-rotating gradient arc,
/// diamond glass housing, and glowing Axis infinity emblem.
class KineticOrbitalNexus extends StatelessWidget {
  final AnimationController orbitalCtrl;

  const KineticOrbitalNexus({
    super.key,
    required this.orbitalCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Technical Corner Reticles
              Positioned(
                top: 0,
                left: 0,
                child: Text(
                  '⎡',
                  style: GoogleFonts.jetBrainsMono(
                    color: AxisColors.textDim.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Text(
                  '⎤',
                  style: GoogleFonts.jetBrainsMono(
                    color: AxisColors.textDim.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Text(
                  '⎣',
                  style: GoogleFonts.jetBrainsMono(
                    color: AxisColors.textDim.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Text(
                  '⎦',
                  style: GoogleFonts.jetBrainsMono(
                    color: AxisColors.textDim.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),

              // Outer Dashed Orbital Ring (Rotating Clockwise)
              RotationTransition(
                turns: orbitalCtrl,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AxisColors.secondary.withValues(alpha: 0.16),
                      width: 1.2,
                    ),
                  ),
                ),
              ),

              // Inner Gradient Orbit Arc (Counter-Rotating)
              AnimatedBuilder(
                animation: orbitalCtrl,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -orbitalCtrl.value * 2 * math.pi * 1.5,
                    child: const CustomPaint(
                      size: Size(168, 168),
                      painter: OrbitArcPainter(),
                    ),
                  );
                },
              ),

              // Outer Glass Diamond Housing (Rotated 45 degrees)
              Transform.rotate(
                angle: math.pi / 4,
                child: Container(
                  width: 114,
                  height: 114,
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AxisColors.secondary.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AxisColors.secondary.withValues(alpha: 0.18),
                        blurRadius: 24,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                ),
              ),

              // Nested Diamond Layer with Reverse Tilt (Rotated 12 degrees)
              Transform.rotate(
                angle: math.pi / 15,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AxisColors.primarySofter.withValues(alpha: 0.30),
                      width: 1,
                    ),
                  ),
                ),
              ),

              // Central Glowing Nexus with Axis North Star Emblem
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF273647),
                      Color(0xFF122131),
                    ],
                  ),
                  border: Border.all(
                    color: AxisColors.secondary.withValues(alpha: 0.65),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.secondary.withValues(alpha: 0.35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Image.asset(
                    'assets/logo_mark.png',
                    width: 34,
                    height: 34,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Micro Coordinates Badge
              Positioned(
                bottom: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'AX // 00.98',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: AxisColors.secondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter for animated orbital gradient arc.
class OrbitArcPainter extends CustomPainter {
  const OrbitArcPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          AxisColors.primary,
          AxisColors.secondary,
          Colors.transparent,
        ],
        stops: [0.0, 0.45, 0.85, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, 0, math.pi * 1.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

