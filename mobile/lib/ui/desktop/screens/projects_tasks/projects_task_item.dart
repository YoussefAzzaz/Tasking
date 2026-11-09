import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/task_repository.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/task_status_rail.dart';

/// Single item in the projects task list with completion toggle and selection highlighting.
class ProjectsTaskItem extends StatelessWidget {
  const ProjectsTaskItem({
    super.key,
    required this.task,
    required this.isSelected,
    required this.onTap,
    required this.taskRepo,
    this.todayStr,
  });

  final Task task;
  final bool isSelected;
  final VoidCallback onTap;
  final TaskRepository taskRepo;
  final String? todayStr;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final isDone = task.isCompleted;
    final railColor = isDone
        ? AxisColors.tertiary
        : switch (task.priority) {
            1 => AxisColors.priorityHigh,
            2 => AxisColors.priorityMed,
            3 => AxisColors.priorityLow,
            _ => AxisColors.secondary,
          };

    final isOverdue = !isDone &&
        task.dueDate != null &&
        task.dueDate!.trim().isNotEmpty &&
        todayStr != null &&
        task.dueDate!.compareTo(todayStr!) < 0;

    final dueDateLabel = isOverdue
        ? (isArabic ? 'متأخرة • ${task.dueDate} ${task.dueTime ?? ""}' : 'Overdue • ${task.dueDate} ${task.dueTime ?? ""}')
        : isDone
            ? (isArabic ? 'منتهية • ${task.dueDate} ${task.dueTime ?? ""}' : 'Finished • ${task.dueDate} ${task.dueTime ?? ""}')
            : (isArabic ? 'الاستحقاق: ${task.dueDate} ${task.dueTime ?? ""}' : 'Due ${task.dueDate} ${task.dueTime ?? ""}');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3.0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.primary.withValues(alpha: 0.16)
              : AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            TaskStatusRail(color: railColor, height: 20),
            const SizedBox(width: 10),
            DesktopCheckbox(
              value: isDone,
              onChanged: (val) {
                taskRepo.toggleTaskStatus(task, val);
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.getFont(
                      'Geist',
                      fontSize: 13,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                    ),
                  ),
                  if (task.dueDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      dueDateLabel.trim(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        color: isOverdue
                            ? AxisColors.error
                            : isDone
                                ? AxisColors.tertiary
                                : AxisColors.textDim,
                        fontWeight: (isOverdue || isDone) ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isDone) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AxisColors.tertiary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AxisColors.tertiary.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  isArabic ? 'منتهية' : 'FINISHED',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AxisColors.tertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ] else if (task.priority != null) ...[
              const SizedBox(width: 8),
              PriorityBadge(priority: task.priority, compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

