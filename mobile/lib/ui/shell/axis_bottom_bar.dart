import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Clean 5-slot bottom bar with elevated, prominent center TODAY cockpit button:
/// Tasks(0) | Habits(1) | TODAY(2 - Highlighted) | Notes(3) | Friends(4)
class AxisBottomBar extends StatelessWidget {
  const AxisBottomBar({super.key, required this.selected, required this.onTap});
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Container(
      height: 68 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AxisColors.glassTier1.withValues(alpha: 0.96),
        border: const Border(
          top: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 0: Tasks
          _buildStandardTab(
            context,
            index: 0,
            icon: Icons.check_box_outlined,
            label: l10n.tasks,
            isSelected: selected == 0,
          ),
          // 1: Habits
          _buildStandardTab(
            context,
            index: 1,
            icon: Icons.loop_rounded,
            label: l10n.habits,
            isSelected: selected == 1,
          ),
          // 2: TODAY (Center highlighted cockpit button)
          _buildCenterTodayButton(
            context,
            isSelected: selected == 2,
            label: l10n.today,
          ),
          // 3: Notes
          _buildStandardTab(
            context,
            index: 3,
            icon: Icons.edit_note_rounded,
            label: l10n.notes,
            isSelected: selected == 3,
          ),
          // 4: Friends (Companions)
          _buildStandardTab(
            context,
            index: 4,
            icon: Icons.people_alt_rounded,
            label: l10n.friends,
            isSelected: selected == 4,
          ),
        ],
      ),
    );
  }

  /// Prominently elevated center Today cockpit button with glowing aura
  Widget _buildCenterTodayButton(
    BuildContext context, {
    required bool isSelected,
    required String label,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label Tab',
        child: GestureDetector(
          onTap: () => onTap(2),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: 52,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AxisColors.primary, AxisColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : AxisColors.surfaceHigh.withValues(alpha: 0.75),
                  border: Border.all(
                    color: isSelected
                        ? AxisColors.secondarySoft.withValues(alpha: 0.85)
                        : AxisColors.borderGlass2,
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AxisColors.primary.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: AxisColors.secondary.withValues(alpha: 0.35),
                            blurRadius: 8,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                ),
                child: Icon(
                  Icons.today_rounded,
                  size: 22,
                  color: isSelected ? Colors.white : AxisColors.primarySoft,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: 0.4,
                  color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Standard bottom navigation tab item
  Widget _buildStandardTab(
    BuildContext context, {
    required int index,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '$label Tab',
        child: GestureDetector(
          onTap: () => onTap(index),
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AxisColors.primary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 21,
                  color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
