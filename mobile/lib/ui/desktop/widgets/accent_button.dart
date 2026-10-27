import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme.dart';
import '../core/desktop_layout.dart';
import 'desktop_pressable.dart';

/// Primary gradient CTA button with optional icon and keyboard shortcut pill.
/// Keyboard-operable (Enter/Space), focus-ringed, and screen-reader labelled.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.shortcutLabel,
    this.gradient,
    this.color,
    this.height = 38.0,
    this.isLoading = false,
    this.isFullWidth = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14.0),
    this.tooltip,
    this.autofocus = false,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? shortcutLabel;
  final Gradient? gradient;
  final Color? color;
  final double height;
  final bool isLoading;
  final bool isFullWidth;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    const idleGradient = LinearGradient(
      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const hoverGradient = LinearGradient(
      colors: [Color(0xFF7478FF), Color(0xFF6366F1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    const pressedGradient = LinearGradient(
      colors: [Color(0xFF4F46E5), Color(0xFF4338CA)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return DesktopPressable(
      enabled: enabled,
      autofocus: autofocus,
      focusNode: focusNode,
      tooltip: tooltip,
      label: label,
      onActivate: onPressed,
      builder: (context, visuals) {
        final Gradient? effectiveGradient = color != null
            ? null
            : (gradient ??
                  (visuals.pressed
                      ? pressedGradient
                      : visuals.hovered
                      ? hoverGradient
                      : idleGradient));

        final content = AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: color,
            gradient: effectiveGradient,
            borderRadius: DesktopLayout.borderRadiusBadge,
            boxShadow: [
              ...desktopFocusRing(visuals.focused),
              if (enabled && visuals.hovered && !visuals.pressed)
                BoxShadow(
                  color: (color ?? AxisColors.primary).withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: isFullWidth
                      ? MainAxisSize.max
                      : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 16, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.getFont(
                          'Geist',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (shortcutLabel != null) ...[
                      if (isFullWidth)
                        const Spacer()
                      else
                        const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          shortcutLabel!,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        );

        return Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: isFullWidth
              ? SizedBox(width: double.infinity, child: content)
              : content,
        );
      },
    );
  }
}
