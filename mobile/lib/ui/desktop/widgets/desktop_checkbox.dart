import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// 20x20 rounded desktop checkbox with emissive glow on completion.
class DesktopCheckbox extends StatelessWidget {
  const DesktopCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.color,
    this.size = 20.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(6.0)),
    this.isCircle = false,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? color;
  final double size;
  final BorderRadius borderRadius;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AxisColors.tertiary;

    return MouseRegion(
      cursor: onChanged != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onChanged != null ? () => onChanged!(!value) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: value ? activeColor : Colors.transparent,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : borderRadius,
            border: Border.all(
              color: value
                  ? activeColor
                  : (color != null ? color!.withValues(alpha: 0.6) : AxisColors.borderGlass2),
              width: 1.5,
            ),
            boxShadow: value
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.45),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: value
              ? Center(
                  child: Icon(
                    Icons.check_rounded,
                    size: size * 0.75,
                    color: AxisColors.canvasBase,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
