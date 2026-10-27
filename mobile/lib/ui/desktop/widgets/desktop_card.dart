import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../core/desktop_layout.dart';

/// Reusable obsidian glass card used across all desktop dashboard panels.
class DesktopCard extends StatelessWidget {
  const DesktopCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius,
    this.width,
    this.height,
    this.minHeight,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final double? minHeight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DesktopLayout.borderRadiusCard;
    final cardContent = Container(
      width: width,
      height: height,
      constraints: minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      margin: margin,
      padding: padding ?? const EdgeInsets.all(DesktopLayout.cardPadding),
      decoration: BoxDecoration(
        color: backgroundColor ?? AxisColors.surfaceLow,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? AxisColors.borderSubtle,
          width: 1,
        ),
      ),
      child: child,
    );

    if (onTap == null) {
      return cardContent;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: cardContent,
      ),
    );
  }
}
