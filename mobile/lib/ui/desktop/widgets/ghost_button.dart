import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../core/theme.dart';
import '../core/desktop_layout.dart';

/// Clean hairline bordered button for secondary actions.
class GhostButton extends StatefulWidget {
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

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final textColor = widget.color ?? (_isHovered ? AxisColors.textHigh : AxisColors.textMuted);
    final border = widget.borderColor ?? (_isHovered ? AxisColors.borderGlass2 : AxisColors.borderSubtle);
    final bg = _isHovered
        ? (widget.hoverBackgroundColor ?? AxisColors.surfaceHigh.withValues(alpha: 0.6))
        : Colors.transparent;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.isFullWidth ? double.infinity : null,
          height: widget.height,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: DesktopLayout.borderRadiusBadge,
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 15,
                  color: textColor,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AxisFonts.getFont(
                    'Geist',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ),
              if (widget.shortcutLabel != null) ...[
                const SizedBox(width: 8),
                Text(
                  widget.shortcutLabel!,
                  style: AxisFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AxisColors.textDim,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
