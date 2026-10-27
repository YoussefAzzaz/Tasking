import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../core/desktop_layout.dart';
import 'desktop_pressable.dart';

/// Clean hairline bordered button for secondary actions.
/// Keyboard-operable (Enter/Space), focus-ringed, and screen-reader labelled.
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.shortcutLabel,
    this.color,
    this.borderColor,
    this.hoverBackgroundColor,
    this.height = 34.0,
    this.isFullWidth = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0),
    this.tooltip,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? shortcutLabel;
  final Color? color;
  final Color? borderColor;
  final Color? hoverBackgroundColor;
  final double height;
  final bool isFullWidth;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return DesktopPressable(
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      tooltip: tooltip,
      label: label,
      onActivate: onPressed,
      builder: (context, visuals) {
        final active = visuals.hovered || visuals.pressed;
        final textColor = color ?? (active ? AxisColors.textHigh : AxisColors.textMuted);
        final border = borderColor ?? (active ? AxisColors.borderGlass2 : AxisColors.borderSubtle);
        final bg = visuals.pressed
            ? (hoverBackgroundColor ?? AxisColors.surfaceHigh.withValues(alpha: 0.9))
            : visuals.hovered
                ? (hoverBackgroundColor ?? AxisColors.surfaceHigh.withValues(alpha: 0.6))
                : Colors.transparent;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: isFullWidth ? double.infinity : null,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DesktopLayout.borderRadiusBadge,
            border: Border.all(color: border, width: 1),
            boxShadow: desktopFocusRing(visuals.focused),
          ),
          child: Row(
            mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: textColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.getFont(
                  'Geist',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
              if (shortcutLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  shortcutLabel!,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AxisColors.textDim,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
