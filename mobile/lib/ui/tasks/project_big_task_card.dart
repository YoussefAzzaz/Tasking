import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';

class ProjectBigTaskCard extends StatefulWidget {
  const ProjectBigTaskCard({
    super.key,
    required this.project,
    required this.color,
    required this.subtasks,
    required this.taskRepo,
    required this.projectRepo,
    required this.onAddSubtask,
    this.onDelete,
  });

  final Project project;
  final Color color;
  final List<Task> subtasks;
  final TaskRepository taskRepo;
  final ProjectRepository projectRepo;
  final VoidCallback onAddSubtask;
  final VoidCallback? onDelete;

  @override
  State<ProjectBigTaskCard> createState() => _ProjectBigTaskCardState();
}

class _ProjectBigTaskCardState extends State<ProjectBigTaskCard> {
  bool _expanded = true;

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1:
        return AxisColors.priorityHigh;
      case 2:
        return AxisColors.priorityMed;
      case 3:
        return AxisColors.priorityLow;
      default:
        return AxisColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedSubtasks = List<Task>.from(widget.subtasks)..sort(compareTasksByDueDate);
    final total = sortedSubtasks.length;
    final done = sortedSubtasks.where((t) => t.status == 'done').length;
    final progress = total > 0 ? (done / total) : 0.0;
    final percent = (progress * 100).toInt();
    final isComplete = total > 0 && done == total;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? AxisColors.success.withValues(alpha: 0.6)
              : widget.color.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Main Header (Treating Project as a Big Task)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.folder_open_rounded,
                                  color: widget.color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.project.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AxisColors.textHigh,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$done of $total subtasks finished',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AxisColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isComplete)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AxisColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AxisColors.success.withValues(alpha: 0.5)),
                              ),
                              child: const Text('DONE',
                                  style: TextStyle(
                                      color: AxisColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            )
                          else
                            Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: widget.color,
                              ),
                            ),
                          const SizedBox(width: 6),
                          if (widget.project.id != 'inbox_general')
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 20, color: AxisColors.textDim),
                              tooltip: 'Delete project',
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 48),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AxisColors.surfaceLow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                          color: AxisColors.borderPrimary),
                                    ),
                                    title: const Text('Delete Project?',
                                        style: TextStyle(
                                            color: AxisColors.textHigh)),
                                    content: Text(
                                      'Are you sure you want to delete "${widget.project.name}"? Subtasks will be unassigned but not deleted.',
                                      style: const TextStyle(
                                          color: AxisColors.textMuted),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel',
                                            style: TextStyle(
                                                color: AxisColors.textDim)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AxisColors.error),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          await widget.projectRepo.deleteProject(
                                            widget.project.id,
                                            projectName: widget.project.name,
                                          );
                                          widget.onDelete?.call();

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Project "${widget.project.name}" deleted'),
                                                backgroundColor: AxisColors.surfaceLow,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('Delete',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AxisColors.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar track
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 6,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isComplete
                                    ? [AxisColors.success, const Color(0xFF34D399)]
                                    : [
                                        widget.color,
                                        widget.color.withValues(alpha: 0.8),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: (isComplete
                                          ? AxisColors.success
                                          : widget.color)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subtasks breakdown
          if (_expanded) ...[
            const Divider(color: AxisColors.borderSubtle, height: 1),
            if (sortedSubtasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: Text(
                    'No subtasks created for this project yet.',
                    style: TextStyle(color: AxisColors.textDim, fontSize: 12),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: sortedSubtasks.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: AxisColors.borderGlass2, height: 1),
                itemBuilder: (context, i) {
                  final task = sortedSubtasks[i];
                  final isDone = task.status == 'done';

                  return InkWell(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => TaskDetailSheet(task: task),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AxisCheckbox(
                            checked: isDone,
                            onChanged: (checked) async {
                              final updated = Task(
                                id: task.id,
                                title: task.title,
                                notes: task.notes,
                                status: checked ? 'done' : 'todo',
                                priority: task.priority,
                                projectId: task.projectId,
                                tags: task.tags,
                                dueDate: task.dueDate,
                                dueTime: task.dueTime,
                                estimateMin: task.estimateMin,
                                recurrenceRule: task.recurrenceRule,
                                recurrenceMode: task.recurrenceMode,
                              );
                              await widget.taskRepo.updateTask(updated);
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDone
                                        ? AxisColors.textDim
                                        : AxisColors.textHigh,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (task.dueDate != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Due: ${task.dueDate}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AxisColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (task.priority != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getPriorityColor(task.priority!)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'P${task.priority}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _getPriorityColor(task.priority!),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            // Bottom Add Subtask button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: InkWell(
                onTap: widget.onAddSubtask,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 14, color: widget.color),
                      const SizedBox(width: 6),
                      Text(
                        'Add Subtask to ${widget.project.name}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
