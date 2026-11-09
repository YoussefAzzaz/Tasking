import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Date Filter Toolbar with custom date picker trigger, Today, and Yesterday chips
class NoteDateFilterToolbar extends StatelessWidget {
  const NoteDateFilterToolbar({
    super.key,
    required this.filterDate,
    required this.onPickDate,
    required this.onClearDate,
    required this.onSelectDate,
  });

  final DateTime? filterDate;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final ValueChanged<DateTime?> onSelectDate;

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final isTodaySelected =
        filterDate != null && _isSameDay(filterDate!, today);
    final isYesterdaySelected =
        filterDate != null && _isSameDay(filterDate!, yesterday);

    return Row(
      children: [
        // Active / Pick Date filter button
        InkWell(
          onTap: onPickDate,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: filterDate != null
                  ? AxisColors.secondary.withValues(alpha: 0.2)
                  : AxisColors.surfaceHigh.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: filterDate != null
                    ? AxisColors.secondary
                    : AxisColors.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: filterDate != null
                      ? AxisColors.secondary
                      : AxisColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  filterDate != null
                      ? context.formatDate(filterDate!, 'd MMM yyyy')
                      : (isArabic ? 'تصفية بالتاريخ' : 'Filter by Date'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: filterDate != null
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: filterDate != null
                        ? AxisColors.textHigh
                        : AxisColors.textMuted,
                  ),
                ),
                if (filterDate != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onClearDate,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AxisColors.secondary,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 16,
                    color: AxisColors.textDim,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Quick Today Chip
        _FilterChip(
          label: isArabic ? 'اليوم' : 'Today',
          isSelected: isTodaySelected,
          onTap: () {
            if (isTodaySelected) {
              onClearDate();
            } else {
              onSelectDate(today);
            }
          },
        ),
        const SizedBox(width: 6),

        // Quick Yesterday Chip
        _FilterChip(
          label: isArabic ? 'أمس' : 'Yesterday',
          isSelected: isYesterdaySelected,
          onTap: () {
            if (isYesterdaySelected) {
              onClearDate();
            } else {
              onSelectDate(yesterday);
            }
          },
        ),
        if (filterDate != null) ...[
          const Spacer(),
          TextButton(
            onPressed: onClearDate,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isArabic ? 'عرض الكل' : 'Show All',
              style: const TextStyle(color: AxisColors.secondary, fontSize: 11),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.secondary.withValues(alpha: 0.22)
              : AxisColors.surfaceHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isSelected ? AxisColors.secondary : AxisColors.textDim,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
