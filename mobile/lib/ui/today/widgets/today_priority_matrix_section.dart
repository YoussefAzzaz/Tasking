import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'priority_task_card.dart';

/// Priority Matrix section for TodayScreen showing remaining active tasks sorted by priority
/// or an empty state card with quick task creation.
class TodayPriorityMatrixSection extends StatelessWidget {
  final List<Task> pendingTasks;
  final Future<void> Function(Task task, bool isDone) onToggleTask;
  final VoidCallback onTaskCreated;
  final VoidCallback onTaskUpdated;

  const TodayPriorityMatrixSection({
    super.key,
    required this.pendingTasks,
    required this.onToggleTask,
    required this.onTaskCreated,
    required this.onTaskUpdated,
  });

  Widget _buildPriorityMatrixHeader(BuildContext context, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.view_timeline_rounded,
                  color: AxisColors.primarySoft, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context.isArabic ? 'مصفوفة الأولويات' : 'PRIORITY MATRIX',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.isArabic ? 'متبقي $count' : '$count REMAINING',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AxisColors.textMuted,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyPriorityMatrix(BuildContext context) {
    return AxisCard(
      tier: GlassTier.one,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AxisColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AxisColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(Icons.done_all_rounded,
                  color: AxisColors.primary, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              context.isArabic ? 'لا توجد مهام لليوم' : 'No Tasks For Today',
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.isArabic
                  ? 'مصفوفة الأولويات لليوم فارغة. أضف مهمة للبدء.'
                  : 'Your priority matrix for today is clean. Add a task to get started.',
              style: const TextStyle(
                color: AxisColors.textMuted,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => CreateTaskSheet(
                    onTaskCreated: onTaskCreated,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      AxisColors.primary,
                      Color(0xFF6366F1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      context.isArabic ? 'إنشاء مهمة' : 'Create Task',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPriorityMatrixHeader(context, pendingTasks.length),
        const SizedBox(height: 10),
        if (pendingTasks.isEmpty)
          _buildEmptyPriorityMatrix(context)
        else
          ...pendingTasks.map((task) {
            final isDone = task.status == 'done';
            final isArabic = context.isArabic;
            final badge = task.priority == 1
                ? (isArabic ? 'P1 حرجة' : 'P1 CRITICAL')
                : (task.priority == 2 ? (isArabic ? 'P2 متوسطة' : 'P2 MEDIUM') : (isArabic ? 'P3 منخفضة' : 'P3 LOW'));
            final xp = task.priority == 1
                ? 75
                : (task.priority == 2 ? 50 : 25);
            final tag = task.tags != null && task.tags!.isNotEmpty
                ? '@${task.tags!.split(',').first.trim().replaceAll('@', '')}'
                : (task.projectId != null ? '#${task.projectId}' : (isArabic ? 'مهمة' : 'Task'));
            final estimate = '${task.estimateMin ?? 15}${isArabic ? "د" : "m"}';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PriorityTaskCard(
                priority: task.priority ?? 3,
                badge: badge,
                estimate: estimate,
                tag: tag,
                title: task.title,
                subtitle: task.notes ??
                    (task.dueDate != null
                        ? (isArabic ? 'الاستحقاق: ${task.dueDate}' : 'Due: ${task.dueDate}')
                        : (isArabic ? 'لا توجد ملاحظات' : 'No notes added')),
                xp: xp,
                isDone: isDone,
                onToggle: (v) => onToggleTask(task, v),
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TaskDetailSheet(
                      task: task,
                      onTaskUpdated: (_) => onTaskUpdated(),
                    ),
                  );
                },
              ),
            );
          }),
      ],
    );
  }
}

