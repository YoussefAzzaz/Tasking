import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';

/// Clean linear progress gauge with optional label and percentage readout.
class ProgressGauge extends StatelessWidget {
  const ProgressGauge({
    super.key,
    required this.value,
    this.label,
    this.valueLabel,
    this.color,
    this.gradient,
    this.backgroundColor,
    this.height = 6.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(3.0)),
    this.animate = true,
  });

  /// Normalized value between 0.0 and 1.0
  final double value;
  final String? label;
  final String? valueLabel;
  final Color? color;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double height;
  final BorderRadius borderRadius;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    final fillBar = LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final targetWidth = totalWidth * clampedValue;

        final barContent = Container(
          width: targetWidth,
          height: height,
          decoration: BoxDecoration(
            color: gradient == null ? (color ?? AxisColors.secondary) : null,
            gradient: gradient,
            borderRadius: borderRadius,
          ),
        );

        return Stack(
          children: [
            Container(
              width: totalWidth,
              height: height,
              decoration: BoxDecoration(
                color: backgroundColor ?? AxisColors.surfaceHighest.withValues(alpha: 0.5),
                borderRadius: borderRadius,
              ),
            ),
            if (animate)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: targetWidth,
                height: height,
                decoration: BoxDecoration(
                  color: gradient == null ? (color ?? AxisColors.secondary) : null,
                  gradient: gradient,
                  borderRadius: borderRadius,
                ),
              )
            else
              barContent,
          ],
        );
      },
    );

    if (label == null && valueLabel == null) {
      return fillBar;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (label != null)
              Text(
                label!,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: AxisColors.textMuted,
                ),
              )
            else
              const SizedBox.shrink(),
            if (valueLabel != null)
              Text(
                valueLabel!,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color ?? AxisColors.secondary,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        const SizedBox(height: 6),
        fillBar,
      ],
    );
  }
}
