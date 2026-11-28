import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/domain/recurrence_engine.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';

/// Form component for configuring one-time vs weekly repeating tasks with
/// interactive day-of-week selection (e.g., every Wednesday at 08:30 for 90m).
class TaskRecurrenceSelector extends StatelessWidget {
  const TaskRecurrenceSelector({
    super.key,
    required this.isWeekly,
    required this.selectedWeekdays,
    required this.onWeeklyChanged,
    required this.onToggleWeekday,
    this.otherRecurrenceRule,
    this.onClearOtherRecurrence,
    this.selectedTime,
    this.estimateMin,
  });

  final bool isWeekly;
  final Set<int> selectedWeekdays;
  final ValueChanged<bool> onWeeklyChanged;
  final ValueChanged<int> onToggleWeekday;
  final String? otherRecurrenceRule;
  final VoidCallback? onClearOtherRecurrence;
  final TimeOfDay? selectedTime;
  final int? estimateMin;

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabic;
    final hasOtherRule = !isWeekly &&
        otherRecurrenceRule != null &&
        otherRecurrenceRule!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(
          label: isAr ? 'جدول التكرار' : 'REPEAT SCHEDULE',
        ),
        Row(
          children: [
            Expanded(
              child: _ScheduleModeChip(
                chipKey: const ValueKey('recurrence_mode_once'),
                icon: Icons.event_available_rounded,
                label: isAr ? 'مرة واحدة' : 'One-time',
                isSelected: !isWeekly && !hasOtherRule,
                accentColor: AxisColors.secondary,
                onTap: () {
                  if (hasOtherRule) {
                    onClearOtherRecurrence?.call();
                  }
                  if (isWeekly) {
                    onWeeklyChanged(false);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ScheduleModeChip(
                chipKey: const ValueKey('recurrence_mode_weekly'),
                icon: Icons.event_repeat_rounded,
                label: isAr ? 'أسبوعياً (أيام محددة)' : 'Weekly',
                isSelected: isWeekly,
                accentColor: AxisColors.primary,
                onTap: () {
                  if (!isWeekly) {
                    onWeeklyChanged(true);
                  }
                },
              ),
            ),
          ],
        ),
        if (hasOtherRule) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AxisColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AxisColors.success.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.repeat_rounded,
                    size: 14, color: AxisColors.success),
                const SizedBox(width: 6),
                Text(
                  RecurrenceEngine.formatHumanReadable(
                    otherRecurrenceRule,
                    isArabic: isAr,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AxisColors.textHigh,
                  ),
                ),
                if (onClearOtherRecurrence != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: onClearOtherRecurrence,
                    child: const Icon(Icons.clear_rounded,
                        size: 14, color: AxisColors.textDim),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (isWeekly) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final weekday in RecurrenceEngine.orderedWeekdays)
                _WeekdayPill(
                  pillKey: ValueKey('weekly_day_$weekday'),
                  label: RecurrenceEngine.weekdayShortLabel(
                    weekday,
                    isArabic: isAr,
                  ),
                  isSelected: selectedWeekdays.contains(weekday),
                  onTap: () => onToggleWeekday(weekday),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AxisColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AxisColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.repeat_rounded,
                  size: 14,
                  color: AxisColors.primarySoft,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _buildSummaryText(context, isAr),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.primarySoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _buildSummaryText(BuildContext context, bool isAr) {
    final sortedDays = selectedWeekdays.toList()..sort();
    final daysStr = sortedDays.isEmpty
        ? (isAr ? 'اختر يوماً' : 'Select a day')
        : sortedDays
            .map((d) => RecurrenceEngine.weekdayFullLabel(d, isArabic: isAr))
            .join(isAr ? '، ' : ', ');
    final timePart = selectedTime != null
        ? (isAr
            ? ' الساعة ${selectedTime!.format(context)}'
            : ' at ${selectedTime!.format(context)}')
        : '';
    final durPart = (estimateMin != null && estimateMin! > 0)
        ? (isAr ? ' • $estimateMin د' : ' • ${estimateMin}m')
        : '';
    return isAr
        ? 'يتكرر كل $daysStr$timePart$durPart'
        : 'Repeats every $daysStr$timePart$durPart';
  }
}

class _ScheduleModeChip extends StatelessWidget {
  const _ScheduleModeChip({
    required this.chipKey,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final Key chipKey;
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: chipKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.2)
              : AxisColors.surfaceHigh.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? accentColor : AxisColors.borderSubtle,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? accentColor : AxisColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AxisColors.textHigh : AxisColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayPill extends StatelessWidget {
  const _WeekdayPill({
    required this.pillKey,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final Key pillKey;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: pillKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.primary.withValues(alpha: 0.25)
              : AxisColors.surfaceHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AxisColors.textMuted,
          ),
        ),
      ),
    );
  }
}
