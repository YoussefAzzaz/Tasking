import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

const _tabIcons = [
  Icons.today_rounded,
  Icons.check_box_outlined,
  Icons.loop_rounded,
  Icons.edit_note_rounded,
  Icons.person_outline_rounded,
];

const _tabLabels = ['Today', 'Tasks', 'Habits', 'Notes', 'Me'];

/// 5-slot bottom bar: Today | Tasks | [+orb] | Habits | Notes
class AxisBottomBar extends StatelessWidget {
  const AxisBottomBar({super.key, required this.selected, required this.onTap});
  final int selected;   // 0-4 → tab index (excludes orb)
  final ValueChanged<int> onTap; // bar index 0-4 (2 = orb)

  @override
  Widget build(BuildContext context) {
    // Bar slots (5): Today(0) Tasks(1) [+](2) Habits(3) Notes(4)
    // tab indices:     0       1           2       3
    final barSlots = [0, 1, -1, 2, 3]; // -1 = orb

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
        children: List.generate(5, (barIdx) {
          final tabIdx = barSlots[barIdx];

          // Quick-Add orb
          if (tabIdx == -1) {
            return Expanded(
              child: Semantics(
                button: true,
                label: 'Quick Add Task',
                child: GestureDetector(
                  onTap: () => onTap(barIdx),
                  child: Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AxisColors.primary, AxisColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AxisColors.primary.withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: -4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AxisColors.textHigh,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final isSelected = tabIdx == selected;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: '${_tabLabels[tabIdx]} Tab',
              child: GestureDetector(
                onTap: () => onTap(barIdx),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AxisColors.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _tabIcons[tabIdx],
                        size: 22,
                        color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _tabLabels[tabIdx],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
