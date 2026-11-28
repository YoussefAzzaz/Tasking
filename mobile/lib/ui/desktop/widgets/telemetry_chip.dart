import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../core/theme.dart';
import '../core/desktop_layout.dart';

/// Compact telemetry pill chip indicating system, network, or entity state.
class TelemetryChip extends StatelessWidget {
  const TelemetryChip({
    super.key,
    required this.label,
    this.dotColor,
    this.icon,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.textColor,
    this.isMonospace = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
  });

  final String label;
  final Color? dotColor;
  final IconData? icon;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? textColor;
  final bool isMonospace;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AxisColors.secondary;
    final effectiveBg = backgroundColor ?? effectiveColor.withValues(alpha: 0.12);
    final effectiveBorder = borderColor ?? effectiveColor.withValues(alpha: 0.28);
    final effectiveText = textColor ?? effectiveColor;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: DesktopLayout.borderRadiusBadge,
        border: Border.all(color: effectiveBorder, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: dotColor!.withValues(alpha: 0.6),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: effectiveText,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: isMonospace
                ? AxisFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: effectiveText,
                  )
                : AxisFonts.getFont(
                    'Geist',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: effectiveText,
                  ),
          ),
        ],
      ),
    );
  }
}
