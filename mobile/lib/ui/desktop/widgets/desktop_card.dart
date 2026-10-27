import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../core/desktop_layout.dart';
import 'desktop_pressable.dart';

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
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? DesktopLayout.borderRadiusCard;
    final cardContent = Container(
      width: width,
      height: height,
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
    return DesktopPressable(
      onActivate: onTap,
      label: semanticLabel,
      builder: (context, visuals) {
        final hovered = visuals.hovered || visuals.pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          height: height,
          margin: margin,
          padding: padding ?? const EdgeInsets.all(DesktopLayout.cardPadding),
          decoration: BoxDecoration(
            color: hovered
                ? (backgroundColor ?? AxisColors.surfaceLow).withValues(
                    alpha: 0.82,
                  )
                : backgroundColor ?? AxisColors.surfaceLow,
            borderRadius: radius,
            border: Border.all(
              color: hovered ? AxisColors.borderGlass2 : AxisColors.borderSubtle,
              width: 1,
            ),
            boxShadow: desktopFocusRing(visuals.focused),
          ),
          child: child,
        );
      },
    );
  }
}
