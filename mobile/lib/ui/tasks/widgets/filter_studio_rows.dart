import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/tasks/widgets/task_filter_widgets.dart';

/// Row of priority selection chips for the filter studio
class FilterPriorityRow extends StatelessWidget {
  const FilterPriorityRow({
    super.key,
    required this.selectedPriority,
    required this.onSelectPriority,
  });

  final int? selectedPriority;
  final ValueChanged<int?> onSelectPriority;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.isArabic ? 'الأولوية' : 'PRIORITY',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AxisColors.textMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            FilterStudioChip(
              label: context.isArabic ? 'الكل' : 'All',
              isSelected: selectedPriority == null,
              onTap: () => onSelectPriority(null),
            ),
            const SizedBox(width: 6),
            FilterStudioChip(
              label: context.isArabic ? 'P1 حرجة' : 'P1 High',
              color: AxisColors.priorityHigh,
              isSelected: selectedPriority == 1,
              onTap: () => onSelectPriority(1),
            ),
            const SizedBox(width: 6),
            FilterStudioChip(
              label: context.isArabic ? 'P2 متوسطة' : 'P2 Medium',
              color: AxisColors.priorityMed,
              isSelected: selectedPriority == 2,
              onTap: () => onSelectPriority(2),
            ),
            const SizedBox(width: 6),
            FilterStudioChip(
              label: context.isArabic ? 'P3 منخفضة' : 'P3 Low',
              color: AxisColors.priorityLow,
              isSelected: selectedPriority == 3,
              onTap: () => onSelectPriority(3),
            ),
          ],
        ),
      ],
    );
  }
}

/// Horizontal scroll of due date options for the filter studio
class FilterDueDateRow extends StatelessWidget {
  const FilterDueDateRow({
    super.key,
    required this.selectedDueDateOption,
    required this.pickedCustomDate,
    required this.onSelectOption,
    required this.onPickCustomDate,
  });

  final String? selectedDueDateOption;
  final DateTime? pickedCustomDate;
  final ValueChanged<String?> onSelectOption;
  final VoidCallback onPickCustomDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.isArabic ? 'تاريخ الاستحقاق' : 'DUE DATE',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AxisColors.textMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterStudioChip(
                label: context.isArabic ? 'جميع التواريخ' : 'All Dates',
                isSelected: selectedDueDateOption == null,
                onTap: () => onSelectOption(null),
              ),
              const SizedBox(width: 6),
              FilterStudioChip(
                label: context.isArabic ? 'اليوم' : 'Today',
                color: AxisColors.primary,
                isSelected: selectedDueDateOption == 'today',
                onTap: () => onSelectOption('today'),
              ),
              const SizedBox(width: 6),
              FilterStudioChip(
                label: context.isArabic ? 'غداً' : 'Tomorrow',
                color: AxisColors.secondary,
                isSelected: selectedDueDateOption == 'tomorrow',
                onTap: () => onSelectOption('tomorrow'),
              ),
              const SizedBox(width: 6),
              FilterStudioChip(
                label: context.isArabic ? 'قادمة' : 'Upcoming',
                color: AxisColors.tertiary,
                isSelected: selectedDueDateOption == 'upcoming',
                onTap: () => onSelectOption('upcoming'),
              ),
              const SizedBox(width: 6),
              FilterStudioChip(
                label: context.isArabic ? 'متأخرة' : 'Overdue',
                color: AxisColors.error,
                isSelected: selectedDueDateOption == 'overdue',
                onTap: () => onSelectOption('overdue'),
              ),
              const SizedBox(width: 6),
              FilterStudioChip(
                label: pickedCustomDate != null
                    ? context.formatDate(pickedCustomDate!, 'd MMM')
                    : (context.isArabic ? 'تحديد تاريخ...' : 'Pick Date...'),
                icon: Icons.calendar_today_rounded,
                color: AxisColors.secondarySoft,
                isSelected: selectedDueDateOption == 'custom',
                onTap: onPickCustomDate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

