import 'package:flutter/material.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/core/typography.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/focus_session_service.dart';
import '../../../../data/task_repository.dart';
import '../../../../domain/recurrence_engine.dart';
import '../../../common/axis_markdown_viewer.dart';
import '../../core/task_checklist_mixin.dart';
import '../../dialogs/quick_task_dialog.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/telemetry_chip.dart';

/// Right inspector panel displaying selected task details, context markdown, checklist, and focus trigger.
class ProjectsTaskInspectorPane extends StatefulWidget {
  const ProjectsTaskInspectorPane({
    super.key,
    required this.selectedTaskId,
    required this.selectedTask,
    required this.taskRepo,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    required this.onNavigateToTab,
  });

  final String? selectedTaskId;
  final Task? selectedTask;
  final TaskRepository taskRepo;
  final ValueChanged<Task> onTaskUpdated;
  final VoidCallback onTaskDeleted;
  final ValueChanged<int> onNavigateToTab;

  @override
  State<ProjectsTaskInspectorPane> createState() => _ProjectsTaskInspectorPaneState();
}

class _ProjectsTaskInspectorPaneState extends State<ProjectsTaskInspectorPane> with TaskChecklistMixin {
  void _editTask(Task task) {
    QuickTaskDialog.show(
      context,
      taskToEdit: task,
      onTaskUpdated: (updated) {
        widget.onTaskUpdated(updated);
      },
    );
  }

  Future<void> _toggleChecklist(Task task, int lineIndex) async {
    final updated = await toggleTaskChecklist(task, lineIndex);
    if (mounted) {
      widget.onTaskUpdated(updated);
    }
  }

  Future<void> _promptAddSubtask(Task task) async {
    final isArabic = AppLocalizations.of(context).isArabic;
    final controller = TextEditingController();
    // Root cause: local TextEditingController was never disposed after dialog completion.
    final String? subtask;
    try {
      subtask = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AxisColors.canvasBase,
          title: Text(
            isArabic ? 'إضافة مهمة فرعية' : 'Add Subtask Checkpoint',
            style: AxisFonts.spaceGrotesk(color: AxisColors.textHigh),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: AxisFonts.getFont('Geist', color: AxisColors.textHigh),
            decoration: InputDecoration(
              hintText: isArabic ? 'مثال: كتابة اختبارات التكامل' : 'e.g. Write integration test suite',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(isArabic ? 'إلغاء' : 'Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(
                isArabic ? 'إضافة' : 'Add',
                style: const TextStyle(color: AxisColors.secondary),
              ),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
    if (subtask != null && subtask.isNotEmpty) {
      final current = task.notes ?? '';
      final updatedNotes = current.isEmpty ? '- [ ] $subtask' : '$current\n- [ ] $subtask';
      final updated = task.copyWith(notes: updatedNotes);
      await widget.taskRepo.updateTask(updated);
      if (mounted) {
        widget.onTaskUpdated(updated);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: widget.taskRepo.watchTasks(),
      builder: (context, taskSnap) {
        final tasks = taskSnap.data ?? [];
        final currentId = widget.selectedTaskId ?? widget.selectedTask?.id;
        final task = currentId != null
            ? tasks.cast<Task?>().firstWhere((t) => t?.id == currentId, orElse: () => widget.selectedTask)
            : widget.selectedTask;
        final isArabic = AppLocalizations.of(context).isArabic;

        if (task == null) {
          return DesktopCard(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.touch_app_outlined, size: 36, color: AxisColors.textDim),
                  const SizedBox(height: 10),
                  Text(
                    isArabic
                        ? 'اختر مهمة لمعاينة التفاصيل وقائمة المهام الفرعية'
                        : 'Select a task to inspect details and checklist',
                    style: AxisFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                  ),
                ],
              ),
            ),
          );
        }

        final isDone = task.isCompleted;
        final cleanSender = (task.senderUsername ?? '')
            .trim()
            .replaceFirst(RegExp(r'^@+'), '')
            .trim();

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    isArabic ? 'فاحص المهام' : 'TASK INSPECTOR',
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AxisColors.secondary,
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (task.isCollaborative)
                        TelemetryChip(
                          label: isArabic ? 'تعاوني' : 'COLLABORATIVE',
                          color: AxisColors.secondary,
                        ),
                      if (cleanSender.isNotEmpty)
                        TelemetryChip(
                          label: '@$cleanSender',
                          color: AxisColors.primarySoft,
                        ),
                      if (task.priority != null) PriorityBadge(priority: task.priority),
                      if (task.isRecurring)
                        TelemetryChip(
                          label: RecurrenceEngine.formatHumanReadable(
                            task.recurrenceRule,
                            isArabic: isArabic,
                          ),
                          color: AxisColors.tertiary,
                          icon: Icons.repeat_rounded,
                        ),
                      TelemetryChip(
                        label: isDone
                            ? (isArabic ? 'منتهية' : 'FINISHED')
                            : (isArabic ? 'قيد التنفيذ' : 'IN PROGRESS'),
                        color: isDone ? AxisColors.tertiary : AxisColors.secondary,
                      ),
                      if (!isDone)
                        GhostButton(
                          label: isArabic ? 'مشاركة' : 'Share',
                          icon: Icons.ios_share_rounded,
                          height: 26,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          color: AxisColors.secondary,
                          borderColor: AxisColors.secondary.withValues(alpha: 0.35),
                          onPressed: () => ShareTaskSheet.show(context, task),
                        ),
                      GhostButton(
                        label: isArabic ? 'تعديل' : 'Edit',
                        icon: Icons.edit_outlined,
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: () => _editTask(task),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                task.title,
                style: AxisFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Description / notes
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AxisColors.borderSubtle, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'الملاحظات والسياق' : 'NOTES & CONTEXT',
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AxisColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Builder(
                              builder: (context) {
                                final displayNotes = stripChecklistFromNotes(task.notes);
                                if (displayNotes.isNotEmpty) {
                                  return AxisMarkdownViewer(
                                    markdown: displayNotes,
                                    selectable: true,
                                    baseStyle: AxisFonts.getFont('Geist', fontSize: 13, height: 1.4, color: AxisColors.textHigh),
                                  );
                                }
                                return Text(
                                  isArabic
                                      ? 'لا توجد ملاحظات إضافية مسجلة لهذه المهمة.'
                                      : 'No additional notes provided for this deliverable.',
                                  style: AxisFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Checklist
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AxisColors.borderSubtle, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final checklist = parseTaskChecklist(task.notes);
                                final doneCount = checklist.where((c) => c.isDone).length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          checklist.isNotEmpty
                                              ? (isArabic
                                                  ? 'قائمة المهام الفرعية ($doneCount/${checklist.length})'
                                                  : 'DELIVERABLE CHECKLIST ($doneCount/${checklist.length})')
                                              : (isArabic ? 'قائمة المهام الفرعية' : 'DELIVERABLE CHECKLIST'),
                                          style: AxisFonts.spaceGrotesk(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: AxisColors.textMuted,
                                          ),
                                        ),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () => _promptAddSubtask(task),
                                            child: Text(
                                              isArabic ? '+ إضافة مهمة فرعية' : '+ Add Subtask',
                                              style: AxisFonts.spaceGrotesk(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AxisColors.secondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    if (checklist.isEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Text(
                                          isArabic
                                              ? 'لا توجد عناصر بعد. انقر على + إضافة مهمة فرعية لإضافة خطوات.'
                                              : 'No checklist items yet. Click + Add Subtask to add checkpoints.',
                                          style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                                        ),
                                      )
                                    else
                                      Column(
                                        children: checklist.map((item) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                                            child: InkWell(
                                              onTap: () => _toggleChecklist(task, item.lineIndex),
                                              borderRadius: BorderRadius.circular(6),
                                              hoverColor: AxisColors.surfaceHigh.withValues(alpha: 0.3),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
                                                child: Row(
                                                  children: [
                                                    DesktopCheckbox(
                                                      value: item.isDone,
                                                      size: 18,
                                                      color: AxisColors.secondary,
                                                      onChanged: (_) => _toggleChecklist(task, item.lineIndex),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        item.text,
                                                        style: AxisFonts.getFont(
                                                          'Geist',
                                                          fontSize: 12,
                                                          decoration: item.isDone ? TextDecoration.lineThrough : null,
                                                          color: item.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Actions
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!isDone)
                        GhostButton(
                          key: const ValueKey('inspector_bottom_share_task_button'),
                          label: isArabic ? 'مشاركة المهمة' : 'Share Task',
                          icon: Icons.ios_share_rounded,
                          color: AxisColors.secondary,
                          borderColor: AxisColors.secondary.withValues(alpha: 0.35),
                          onPressed: () => ShareTaskSheet.show(context, task),
                        ),
                      GhostButton(
                        label: isDone
                            ? (isArabic ? 'تعيين كغير مكتملة' : 'Mark as Incomplete')
                            : (isArabic ? 'تعيين كمكتملة' : 'Mark Completed'),
                        icon: isDone ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                        onPressed: () {
                          widget.taskRepo.toggleTaskStatus(task, !isDone);
                          widget.onTaskUpdated(task.copyWith(status: isDone ? 'todo' : 'done'));
                        },
                      ),
                      GhostButton(
                        label: isArabic ? 'حذف' : 'Delete',
                        icon: Icons.delete_outline_rounded,
                        onPressed: () async {
                          final taskTitle = task.title;
                          await widget.taskRepo.deleteTask(task.id);
                          widget.onTaskDeleted();
                          if (context.mounted) {
                            AxisSnackBar.showDeleted(context, itemTitle: taskTitle, itemType: 'Task');
                          }
                        },
                      ),
                    ],
                  ),
                  AccentButton(
                    label: isArabic ? '▶ بدء جلسة تركيز' : '▶ Start Focus Session',
                    onPressed: () {
                      FocusSessionService().setAttachedTask(task);
                      FocusSessionService().startTimer();
                      widget.onNavigateToTab(4); // Navigate to Focus Timers
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

