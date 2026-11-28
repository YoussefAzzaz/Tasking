import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/task_repository.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/section_header.dart';
import '../../widgets/task_status_rail.dart';
import '../../widgets/telemetry_chip.dart';

/// Execution stream card listing all scheduled tasks for today.
class ExecutionStreamCard extends StatelessWidget {
  const ExecutionStreamCard({
    super.key,
    required this.onTaskPreview,
  });

  final ValueChanged<Task> onTaskPreview;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        final todayTasks = tasks.where((t) {
          if (t.dueDate == null || t.dueDate!.trim().isEmpty) return false;
          return t.dueDate == todayStr || t.dueDate!.startsWith(todayStr);
        }).toList()
          ..sort((a, b) {
            if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
            final pA = a.priority ?? 3;
            final pB = b.priority ?? 3;
            if (pA != pB) return pA.compareTo(pB);
            return (a.dueTime ?? '').compareTo(b.dueTime ?? '');
          });

        final pendingCount = todayTasks.where((t) => !t.isCompleted).length;
        final isArabic = AppLocalizations.of(context).isArabic;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isArabic ? 'مسار تنفيذ اليوم' : "TODAY'S EXECUTION STREAM",
                trailing: TelemetryChip(
                  label: isArabic ? 'متبقي $pendingCount' : '$pendingCount REMAINING',
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              if (todayTasks.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      isArabic ? 'لا توجد مهام مجدولة لليوم' : 'No tasks scheduled for today',
                      style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: todayTasks.length,
                    itemBuilder: (context, index) => _TaskRow(
                      task: todayTasks[index],
                      onTap: () => onTaskPreview(todayTasks[index]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onTap,
  });

  final Task task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDone = task.isCompleted;
    final railColor = isDone
        ? AxisColors.tertiary
        : switch (task.priority) {
            1 => AxisColors.priorityHigh,
            2 => AxisColors.priorityMed,
            3 => AxisColors.priorityLow,
            _ => AxisColors.secondary,
          };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        hoverColor: AxisColors.surfaceHigh.withValues(alpha: 0.35),
        onTap: onTap,
        onLongPress: isDone ? null : () => ShareTaskSheet.show(context, task),
        onSecondaryTap: isDone ? null : () => ShareTaskSheet.show(context, task),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3.0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AxisColors.borderSubtle, width: 1),
          ),
          child: Row(
            children: [
              TaskStatusRail(color: railColor, height: 20),
              const SizedBox(width: 10),
              DesktopCheckbox(
                value: isDone,
                onChanged: (val) {
                  TaskRepository().toggleTaskStatus(task, val);
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AxisFonts.getFont(
                    'Geist',
                    fontSize: 13,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                  ),
                ),
              ),
              if (task.priority != null && !isDone) ...[
                const SizedBox(width: 8),
                PriorityBadge(priority: task.priority, compact: true),
              ],
              if (task.dueTime != null) ...[
                const SizedBox(width: 8),
                Text(
                  task.dueTime!,
                  style: AxisFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                ),
              ],
              if (!isDone) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: AppLocalizations.of(context).isArabic ? 'مشاركة المهمة' : 'Share Task',
                  child: InkWell(
                    key: ValueKey('execution_stream_share_${task.id}'),
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => ShareTaskSheet.show(context, task),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.ios_share_rounded,
                        size: 15,
                        color: AxisColors.secondary,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Icon(
                AppLocalizations.of(context).isArabic
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                size: 16,
                color: AxisColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
