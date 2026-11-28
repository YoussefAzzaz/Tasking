import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';

/// Form component for selecting task due date, duration timer and quick presets
class TaskDatePickerRow extends StatelessWidget {
  const TaskDatePickerRow({
    super.key,
    required this.selectedDate,
    required this.estimateMin,
    required this.onPickDate,
    required this.onClearDate,
    required this.onPickDuration,
    required this.onClearDuration,
    required this.onSelectEstimateMin,
    required this.onSelectQuickDate,
    this.selectedTime,
    this.onPickTime,
    this.onClearTime,
  });

  final DateTime? selectedDate;
  final int? estimateMin;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final VoidCallback onPickDuration;
  final VoidCallback onClearDuration;
  final ValueChanged<int> onSelectEstimateMin;
  final ValueChanged<DateTime> onSelectQuickDate;
  final TimeOfDay? selectedTime;
  final VoidCallback? onPickTime;
  final VoidCallback? onClearTime;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FieldLabel(label: context.isArabic ? 'تاريخ الاستحقاق' : 'DUE DATE'),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: FieldLabel(
                label: (estimateMin ?? 15) <= 15
                    ? (context.isArabic
                        ? 'المؤقت (≤15 د مصغرة) *'
                        : 'TIMER (≤15M MICRO) *')
                    : (context.isArabic
                        ? 'مدة المهمة (مؤقت) *'
                        : 'TASK DURATION (TIMER) *'),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: onPickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedDate != null
                          ? AxisColors.secondary
                          : AxisColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: selectedDate != null
                            ? AxisColors.secondary
                            : AxisColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedDate != null
                              ? context.formatDate(selectedDate!, 'EEE, d MMM yyyy')
                              : (context.isArabic ? 'تحديد تاريخ الاستحقاق' : 'Pick Due Date'),
                          style: TextStyle(
                            color: selectedDate != null
                                ? AxisColors.textHigh
                                : AxisColors.textDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedDate != null)
                        GestureDetector(
                          onTap: onClearDate,
                          child: const Icon(Icons.clear_rounded,
                              size: 16, color: AxisColors.textDim),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: InkWell(
                onTap: onPickDuration,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: estimateMin != null
                          ? (estimateMin! <= 15
                              ? AxisColors.secondary
                              : AxisColors.primary)
                          : AxisColors.borderSubtle,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        estimateMin != null && estimateMin! <= 15
                            ? Icons.bolt_rounded
                            : Icons.timer_outlined,
                        size: 18,
                        color: estimateMin != null
                            ? (estimateMin! <= 15
                                ? AxisColors.secondary
                                : AxisColors.primary)
                            : AxisColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.isArabic
                              ? '${estimateMin ?? 15} دقيقة'
                              : '${estimateMin ?? 15} min',
                          style: const TextStyle(
                            color: AxisColors.textHigh,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (estimateMin != null && estimateMin != 15)
                        GestureDetector(
                          onTap: onClearDuration,
                          child: const Icon(Icons.clear_rounded,
                              size: 16, color: AxisColors.textDim),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // Quick Duration Presets for 1-tap micro & session selection
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final min in [5, 10, 15, 25, 30, 45, 60, 90, 120]) ...[
                InkWell(
                  key: ValueKey('duration_preset_$min'),
                  onTap: () => onSelectEstimateMin(min),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: estimateMin == min
                          ? (min <= 15
                              ? AxisColors.secondary.withValues(alpha: 0.25)
                              : AxisColors.primary.withValues(alpha: 0.25))
                          : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: estimateMin == min
                            ? (min <= 15
                                ? AxisColors.secondary
                                : AxisColors.primary)
                            : AxisColors.borderSubtle,
                        width: estimateMin == min ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (min <= 15) ...[
                          const Icon(Icons.bolt_rounded,
                              size: 12, color: AxisColors.secondary),
                          const SizedBox(width: 2),
                        ],
                        Text(
                          context.isArabic ? '$min د' : '${min}m',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: estimateMin == min
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: estimateMin == min
                                ? AxisColors.textHigh
                                : AxisColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Quick Date Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              QuickDateChip(
                label: context.isArabic ? 'اليوم' : 'Today',
                isSelected: selectedDate != null &&
                    selectedDate!.year == now.year &&
                    selectedDate!.month == now.month &&
                    selectedDate!.day == now.day,
                onTap: () => onSelectQuickDate(now),
              ),
              const SizedBox(width: 6),
              QuickDateChip(
                label: context.isArabic ? 'غداً' : 'Tomorrow',
                isSelected: () {
                  if (selectedDate == null) return false;
                  final tmr = now.add(const Duration(days: 1));
                  return selectedDate!.year == tmr.year &&
                      selectedDate!.month == tmr.month &&
                      selectedDate!.day == tmr.day;
                }(),
                onTap: () => onSelectQuickDate(now.add(const Duration(days: 1))),
              ),
              const SizedBox(width: 6),
              QuickDateChip(
                label: context.isArabic ? 'خلال 3 أيام' : 'In 3 Days',
                isSelected: false,
                onTap: () => onSelectQuickDate(now.add(const Duration(days: 3))),
              ),
            ],
          ),
        ),
        if (onPickTime != null) ...[
          const SizedBox(height: 8),
          InkWell(
            key: const ValueKey('task_pick_time_button'),
            onTap: onPickTime,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selectedTime != null
                    ? AxisColors.primary.withValues(alpha: 0.15)
                    : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selectedTime != null ? AxisColors.primary : AxisColors.borderSubtle,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: selectedTime != null ? AxisColors.primary : AxisColors.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    selectedTime != null
                        ? selectedTime!.format(context)
                        : (context.isArabic ? 'وقت المهمة (تلقائي)' : 'Task Time (Auto)'),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: selectedTime != null ? FontWeight.w600 : FontWeight.w500,
                      color: selectedTime != null ? AxisColors.textHigh : AxisColors.textDim,
                    ),
                  ),
                  if (selectedTime != null && onClearTime != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onClearTime,
                      child: const Icon(Icons.clear_rounded, size: 14, color: AxisColors.textDim),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

