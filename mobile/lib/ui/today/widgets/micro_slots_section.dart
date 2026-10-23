import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
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
                      '15M MICRO SLOTS',
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
                  const SnackBar(
                    content: Text('Auto-Scheduler recalculated idle gaps!'),
                    backgroundColor: AxisColors.secondary,
                    duration: Duration(seconds: 2),
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
                      'RESCHEDULE',
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
                            ? 'Auto-Scheduler slotted ${slottedTasks.length} micro-task${slottedTasks.length > 1 ? 's' : ''} into idle gaps.'
                            : 'Auto-Scheduler ready. Tasks with estimated times will be slotted dynamically.',
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
                        slottedTasks.isNotEmpty ? 'OPTIMIZED' : 'READY',
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
                  child: const Row(
                    children: [
                      Icon(Icons.hourglass_empty_rounded,
                          color: AxisColors.secondary, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Micro-Slots Scheduled',
                              style: TextStyle(
                                color: AxisColors.textHigh,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tasks with scheduled times or short estimates appear here.',
                              style: TextStyle(
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
                      : '${t.estimateMin ?? 15}M Micro';
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
