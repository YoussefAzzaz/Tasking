import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
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
    final barDecoration = BoxDecoration(
      color: gradient == null ? (color ?? AxisColors.secondary) : null,
      gradient: gradient,
      borderRadius: borderRadius,
    );

    final fillBar = SizedBox(
      height: height,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              color: backgroundColor ?? AxisColors.surfaceHighest.withValues(alpha: 0.5),
              borderRadius: borderRadius,
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: clampedValue,
            child: Container(
              height: height,
              decoration: barDecoration,
            ),
          ),
        ],
      ),
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
                style: AxisFonts.spaceGrotesk(
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
                style: AxisFonts.spaceGrotesk(
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
