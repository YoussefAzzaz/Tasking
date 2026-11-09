import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/today/widgets/time_slot_card.dart';

/// 15M Micro Slots AI auto-scheduler section
class MicroSlotsSection extends StatelessWidget {
  const MicroSlotsSection({
    super.key,
    required this.slottedTasks,
    required this.onToggleTask,
  });

  final List<Task> slottedTasks;
  final void Function(Task task, bool isDone) onToggleTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AxisColors.secondary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.isArabic ? 'الفترات المصغرة 15 د' : '15M MICRO SLOTS',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context.isArabic
                          ? 'أعاد المجدول التلقائي حساب الفترات الخاملة!'
                          : 'Auto-Scheduler recalculated idle gaps!',
                    ),
                    backgroundColor: AxisColors.secondary,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AxisColors.secondary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_fix_high_rounded,
                      color: AxisColors.secondary,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.isArabic ? 'إعادة الجدولة' : 'RESCHEDULE',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AxisColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AxisCard(
          tier: GlassTier.two,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // AI insight banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AxisColors.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: AxisColors.secondary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        slottedTasks.isNotEmpty
                            ? (context.isArabic
                                ? 'وزّع المجدول التلقائي ${slottedTasks.length} مهام مصغرة في الفترات الشاغرة.'
                                : 'Auto-Scheduler slotted ${slottedTasks.length} micro-task${slottedTasks.length > 1 ? 's' : ''} into idle gaps.')
                            : (context.isArabic
                                ? 'المجدول التلقائي جاهز. سيتم توزيع المهام ذات الأوقات المقدرة ديناميكياً.'
                                : 'Auto-Scheduler ready. Tasks with estimated times will be slotted dynamically.'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AxisColors.textHigh,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AxisColors.tertiary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        slottedTasks.isNotEmpty
                            ? (context.isArabic ? 'محسّن' : 'OPTIMIZED')
                            : (context.isArabic ? 'جاهز' : 'READY'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AxisColors.tertiary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (slottedTasks.isEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_empty_rounded,
                          color: AxisColors.secondary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.isArabic ? 'لا توجد فترات مصغرة مجدولة' : 'No Micro-Slots Scheduled',
                              style: const TextStyle(
                                color: AxisColors.textHigh,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.isArabic
                                  ? 'المهام ذات الأوقات المحددة أو التقديرات القصيرة ستظهر هنا.'
                                  : 'Tasks with scheduled times or short estimates appear here.',
                              style: const TextStyle(
                                color: AxisColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...slottedTasks.map((t) {
                  final isDone = t.status == 'done';
                  final timeStr = t.dueTime != null
                      ? t.dueTime!
                      : (context.isArabic ? '${t.estimateMin ?? 15} د مصغرة' : '${t.estimateMin ?? 15}M Micro');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TimeSlotCard(
                      time: timeStr,
                      title: t.title,
                      xp: t.priority == 1 ? 30 : 20,
                      isDone: isDone,
                      onToggle: (v) => onToggleTask(t, v),
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }
}
