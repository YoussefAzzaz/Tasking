import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';

enum OutdatedFilterMode { all, outdated, finished }

/// Filter pills selector (All | Outdated | Finished) with count badges.
class OutdatedFilterPills extends StatelessWidget {
  const OutdatedFilterPills({
    super.key,
    required this.allCount,
    required this.outdatedCount,
    required this.finishedCount,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  final int allCount;
  final int outdatedCount;
  final int finishedCount;
  final OutdatedFilterMode activeFilter;
  final ValueChanged<OutdatedFilterMode> onFilterChanged;

  Widget _buildPillItem({
    required String label,
    required int count,
    required bool isSelected,
    required Color activeColor,
    Color? dotColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AxisColors.textDim,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.3)
                      : AxisColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AxisColors.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        children: [
          _buildPillItem(
            label: context.isArabic ? 'الكل' : 'All',
            count: allCount,
            isSelected: activeFilter == OutdatedFilterMode.all,
            activeColor: AxisColors.primary,
            onTap: () => onFilterChanged(OutdatedFilterMode.all),
          ),
          const SizedBox(width: 4),
          _buildPillItem(
            label: context.isArabic ? 'فائتة' : 'Outdated',
            count: outdatedCount,
            isSelected: activeFilter == OutdatedFilterMode.outdated,
            activeColor: AxisColors.error,
            dotColor: AxisColors.error,
            onTap: () => onFilterChanged(OutdatedFilterMode.outdated),
          ),
          const SizedBox(width: 4),
          _buildPillItem(
            label: context.isArabic ? 'مكتملة' : 'Finished',
            count: finishedCount,
            isSelected: activeFilter == OutdatedFilterMode.finished,
            activeColor: AxisColors.tertiary,
            dotColor: AxisColors.tertiary,
            onTap: () => onFilterChanged(OutdatedFilterMode.finished),
          ),
        ],
      ),
    );
  }
}

/// Cyber-styled placeholder for empty lists in the Outdated / Finished tab.
class OutdatedEmptyStateCard extends StatelessWidget {
  const OutdatedEmptyStateCard({
    super.key,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, size: 28, color: accentColor),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

