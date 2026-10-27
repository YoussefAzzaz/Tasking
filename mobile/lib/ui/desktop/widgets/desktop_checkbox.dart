import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'desktop_pressable.dart';

/// 20x20 rounded desktop checkbox with emissive glow on completion.
/// Keyboard-operable (Space), screen-reader announced via checked state.
class DesktopCheckbox extends StatelessWidget {
  const DesktopCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.color,
    this.size = 20.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(6.0)),
    this.isCircle = false,
    this.semanticLabel,
    this.autofocus = false,
    this.focusNode,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? color;
  final double size;
  final BorderRadius borderRadius;
  final bool isCircle;

  /// Screen-reader label describing what the checkbox controls.
  final String? semanticLabel;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AxisColors.tertiary;

    return DesktopPressable(
      enabled: onChanged != null,
      role: DesktopPressableRole.checkbox,
      checked: value,
      label: semanticLabel,
      autofocus: autofocus,
      focusNode: focusNode,
      onActivate: onChanged != null ? () => onChanged!(!value) : null,
      builder: (context, visuals) {
        final borderColor = value
            ? activeColor
            : (visuals.hovered ? const Color(0x59FFFFFF) : AxisColors.borderGlass2);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: value ? activeColor : Colors.transparent,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : borderRadius,
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              ...desktopFocusRing(visuals.focused),
              if (value)
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.45),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
            ],
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
        );
      },
    );
  }
}
