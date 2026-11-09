import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';

/// Form section for configuring habit frequency schedule and optional reminder times
class HabitScheduleReminderPicker extends StatelessWidget {
  const HabitScheduleReminderPicker({
    super.key,
    required this.scheduleType,
    required this.reminderTime,
    required this.onPickTime,
    required this.onClearTime,
    required this.onScheduleTypeChanged,
    required this.isEdit,
  });

  final String scheduleType;
  final TimeOfDay? reminderTime;
  final VoidCallback onPickTime;
  final VoidCallback onClearTime;
  final ValueChanged<String> onScheduleTypeChanged;
  final bool isEdit;

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Frequency
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(label: isArabic ? 'التكرار' : 'FREQUENCY'),
                  DropdownButtonFormField<String>(
                    initialValue: scheduleType,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AxisColors.borderSubtle),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AxisColors.borderSubtle),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                    ),
                    dropdownColor: AxisColors.surfaceHigh,
                    style: const TextStyle(
                        color: AxisColors.textHigh, fontSize: 13),
                    items: [
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text(
                          isArabic ? 'يومياً (00:00)' : 'Daily (00:00)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text(
                          isArabic ? 'أسبوعياً (الجمعة)' : 'Weekly (Fri)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'every_3_days',
                        child: Text(
                          isArabic ? 'كل 3 أيام' : 'Every 3 Days',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'weekdays',
                        child: Text(
                          isArabic ? 'أيام العمل' : 'Weekdays',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        onScheduleTypeChanged(v);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Time of Day (Optional for non-daily habits)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FieldLabel(
                    label: scheduleType == 'daily'
                        ? (isArabic ? 'الوقت *' : 'TIME *')
                        : (isArabic ? 'الوقت (اختياري)' : 'TIME (OPTIONAL)'),
                  ),
                  InkWell(
                    onTap: onPickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: reminderTime != null
                              ? AxisColors.success.withValues(alpha: 0.5)
                              : AxisColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.alarm_rounded,
                            size: 18,
                            color: reminderTime != null
                                ? AxisColors.success
                                : AxisColors.textDim,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              reminderTime != null
                                  ? '${reminderTime!.hourOfPeriod == 0 ? 12 : reminderTime!.hourOfPeriod}:${reminderTime!.minute.toString().padLeft(2, '0')} ${isArabic ? (reminderTime!.period == DayPeriod.am ? 'ص' : 'م') : (reminderTime!.period == DayPeriod.am ? 'AM' : 'PM')}'
                                  : (scheduleType == 'daily'
                                      ? (isArabic ? 'تحديد الوقت' : 'Set Time')
                                      : (isArabic ? 'أي وقت' : 'Anytime')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: reminderTime != null
                                    ? AxisColors.textHigh
                                    : AxisColors.textDim,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (reminderTime != null)
                            GestureDetector(
                              onTap: onClearTime,
                              child: const Padding(
                                padding: EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded,
                                    size: 16, color: AxisColors.textDim),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (reminderTime != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AxisColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AxisColors.success.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded,
                      size: 13, color: AxisColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isArabic
                          ? 'التذكيرات: قبل 10 دقائق و 5 دقائق من الوقت'
                          : 'Reminders: 10m & 5m before habit time',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AxisColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (scheduleType != 'daily')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AxisColors.textDim),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'العادات غير اليومية لا تتطلب وقتاً محدداً في اليوم.'
                        : 'Non-daily habits do not require an exact time of day.',
                    style:
                        const TextStyle(fontSize: 11, color: AxisColors.textDim),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

