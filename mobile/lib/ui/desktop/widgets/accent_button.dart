import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../core/theme.dart';
import '../core/desktop_layout.dart';

/// Primary gradient CTA button with optional icon and keyboard shortcut pill.
class AccentButton extends StatefulWidget {
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

  @override
  State<AccentButton> createState() => _AccentButtonState();
}

class _AccentButtonState extends State<AccentButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;

    final defaultGradient = LinearGradient(
      colors: _isHovered
          ? [const Color(0xFF7478FF), const Color(0xFF6366F1)]
          : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        gradient: widget.color == null ? (widget.gradient ?? defaultGradient) : null,
        borderRadius: DesktopLayout.borderRadiusBadge,
        boxShadow: enabled && _isHovered
            ? [
                BoxShadow(
                  color: (widget.color ?? AxisColors.primary).withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: widget.isLoading
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
              mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(
                    widget.icon,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AxisFonts.getFont(
                      'Geist',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (widget.shortcutLabel != null) ...[
                  if (widget.isFullWidth) const Spacer() else const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
                    ),
                    child: Text(
                      widget.shortcutLabel!,
                      style: AxisFonts.spaceGrotesk(
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

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: widget.isFullWidth ? SizedBox(width: double.infinity, child: content) : content,
        ),
      ),
    );
  }
}
