import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/task_repository.dart';
import '../../../common/axis_markdown_viewer.dart';
import '../../core/task_checklist_mixin.dart';
import '../../dialogs/quick_task_dialog.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/priority_badge.dart';
import '../../widgets/telemetry_chip.dart';

/// Modal dialog showing full details, notes, and checklist for a selected task.
class DesktopTaskPreviewDialog extends StatefulWidget {
  const DesktopTaskPreviewDialog({
    super.key,
    required this.initialTask,
    this.onTaskUpdated,
  });

  final Task initialTask;
  final ValueChanged<Task>? onTaskUpdated;

  static Future<void> show(
    BuildContext context, {
    required Task initialTask,
    ValueChanged<Task>? onTaskUpdated,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) => DesktopTaskPreviewDialog(
        initialTask: initialTask,
        onTaskUpdated: onTaskUpdated,
      ),
    );
  }

  @override
  State<DesktopTaskPreviewDialog> createState() => _DesktopTaskPreviewDialogState();
}

class _DesktopTaskPreviewDialogState extends State<DesktopTaskPreviewDialog> with TaskChecklistMixin {
  late Task _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.initialTask;
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _currentTask.isCompleted;
    final checklist = parseTaskChecklist(_currentTask.notes);
    final displayNotes = stripChecklistFromNotes(_currentTask.notes);
    final isArabic = AppLocalizations.of(context).isArabic;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: AxisColors.canvasBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AxisColors.borderGlass2, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AxisColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.preview_rounded,
                          color: AxisColors.secondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isArabic
                            ? "معاينة المهمة // مسار اليوم"
                            : "TASK PREVIEW // TODAY'S STREAM",
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          color: AxisColors.secondary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GhostButton(
                        label: isArabic ? 'تعديل' : 'Edit',
                        icon: Icons.edit_outlined,
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: () {
                          Navigator.of(context).pop();
                          QuickTaskDialog.show(
                            context,
                            taskToEdit: _currentTask,
                            onTaskUpdated: (updatedTask) {
                              widget.onTaskUpdated?.call(updatedTask);
                            },
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: AxisColors.borderSubtle, height: 1),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title & Completion
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DesktopCheckbox(
                          value: isDone,
                          onChanged: (val) async {
                            final updated = _currentTask.copyWith(status: val ? 'done' : 'todo');
                            setState(() {
                              _currentTask = updated;
                            });
                            await TaskRepository().toggleTaskStatus(_currentTask, val);
                            widget.onTaskUpdated?.call(updated);
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentTask.title,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  if (_currentTask.priority != null)
                                    PriorityBadge(priority: _currentTask.priority),
                                  if (_currentTask.dueDate != null)
                                    TelemetryChip(
                                      label: isArabic
                                          ? 'الاستحقاق: ${_currentTask.dueDate}${_currentTask.dueTime != null ? " ${_currentTask.dueTime}" : ""}'
                                          : 'Due ${_currentTask.dueDate}${_currentTask.dueTime != null ? " ${_currentTask.dueTime}" : ""}',
                                      color: AxisColors.secondary,
                                      icon: Icons.calendar_today_rounded,
                                    ),
                                  if (_currentTask.estimateMin != null)
                                    TelemetryChip(
                                      label: isArabic
                                          ? 'تقدير ${_currentTask.estimateMin} د'
                                          : '${_currentTask.estimateMin}m Estimate',
                                      color: AxisColors.primary,
                                      icon: Icons.timer_outlined,
                                    ),
                                  TelemetryChip(
                                    label: isDone
                                        ? (isArabic ? 'مكتملة' : 'COMPLETED')
                                        : (isArabic ? 'قيد التنفيذ' : 'IN PROGRESS'),
                                    color: isDone ? AxisColors.tertiary : AxisColors.warning,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Notes section
                    if (displayNotes.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'الملاحظات والسياق' : 'NOTES & CONTEXT',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AxisColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AxisMarkdownViewer(
                              markdown: displayNotes,
                              selectable: true,
                              baseStyle: GoogleFonts.getFont('Geist', fontSize: 13, height: 1.4, color: AxisColors.textHigh),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Interactive Checklist Subtasks
                    if (checklist.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic
                                  ? 'المهام الفرعية (${checklist.where((c) => c.isDone).length}/${checklist.length})'
                                  : 'CHECKLIST SUBTASKS (${checklist.where((c) => c.isDone).length}/${checklist.length})',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AxisColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...checklist.map((item) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    DesktopCheckbox(
                                      value: item.isDone,
                                      size: 18,
                                      color: AxisColors.secondary,
                                      onChanged: (val) async {
                                        final updated = await toggleTaskChecklist(_currentTask, item.lineIndex);
                                        if (mounted) {
                                          setState(() {
                                            _currentTask = updated;
                                          });
                                          widget.onTaskUpdated?.call(updated);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.text,
                                        style: GoogleFonts.getFont(
                                          'Geist',
                                          fontSize: 13,
                                          decoration: item.isDone ? TextDecoration.lineThrough : null,
                                          color: item.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Divider(color: AxisColors.borderSubtle, height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GhostButton(
                    label: isArabic ? 'إغلاق' : 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  AccentButton(
                    label: isDone
                        ? (isArabic ? 'تعيين كغير مكتملة' : 'Mark Incomplete')
                        : (isArabic ? 'إكمال المهمة' : 'Complete Task'),
                    icon: isDone ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                    onPressed: () async {
                      await TaskRepository().toggleTaskStatus(_currentTask, !isDone);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
