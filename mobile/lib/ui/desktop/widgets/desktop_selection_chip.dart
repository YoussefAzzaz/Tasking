import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import 'desktop_pressable.dart';

/// Compact selectable filter/segment chip used across deck, matrix, and vault
/// toolbars. Announces its selected state to screen readers; Enter/Space
/// select; keyboard focus draws the shared emissive ring.
class DesktopSelectionChip extends StatelessWidget {
  const DesktopSelectionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.role = DesktopPressableRole.button,
    this.tooltip,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final DesktopPressableRole role;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return DesktopPressable(
      role: role,
      selected: selected,
      label: label,
      tooltip: tooltip,
      onActivate: onTap,
      builder: (context, visuals) {
        final active = visuals.hovered || visuals.pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? AxisColors.primary.withValues(alpha: 0.2)
                : active
                    ? AxisColors.surfaceHigh.withValues(alpha: 0.35)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? AxisColors.primary : AxisColors.borderSubtle,
              width: 1,
            ),
            boxShadow: desktopFocusRing(visuals.focused),
          ),
          child: Text(
            label,
            style: GoogleFonts.getFont(
              'Geist',
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AxisColors.textHigh : AxisColors.textMuted,
            ),
          ),
        );
      },
    );
  }
}
