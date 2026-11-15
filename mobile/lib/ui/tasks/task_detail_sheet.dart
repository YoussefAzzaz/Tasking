import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/focus/focus_screen.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/reading_font_size_control.dart';
import 'package:axis/data/reading_preferences_service.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';

/// Task detail bottom sheet — glass tier 2, full DESIGN.md spec
class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({super.key, required this.task, this.onTaskUpdated});
  final Task task;
  final ValueChanged<Task>? onTaskUpdated;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late Task _task;
  final _repo = TaskRepository();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  void _openEditTask() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTaskSheet(
        taskToEdit: _task,
        onTaskCreated: () {},
        onTaskUpdated: (updated) {
          setState(() => _task = updated);
          widget.onTaskUpdated?.call(updated);
        },
      ),
    );
  }

  Future<void> _toggleDone() async {
    HapticFeedback.mediumImpact();
    final updated = _task.copyWith(
      status: _task.status == 'done' ? 'todo' : 'done',
    );
    await _repo.updateTask(updated);
    setState(() => _task = updated);
    widget.onTaskUpdated?.call(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _task.status == 'done';
    final cleanSender = (_task.senderUsername ?? '')
        .trim()
        .replaceFirst(RegExp(r'^@+'), '')
        .trim();
    final tags = (_task.tags ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) =>
            t.isNotEmpty &&
            (cleanSender.isEmpty ||
                t.replaceFirst(RegExp(r'^@+'), '').toLowerCase() !=
                    cleanSender.toLowerCase()))
        .toList();

    return ModalSheetScaffold(
      alignment: null,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollCtrl) {
          return AxisCard(
            tier: GlassTier.two,
            borderRadius: 20,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              bottom: true,
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top handle and action bar (tap to close automatically)
                    ModalSheetTopBar(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 36, height: 4,
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AxisColors.borderSubtle,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                          ),

                          // Top actions row (Edit & Close)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AxisColors.primary
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _task.projectId != null
                                            ? '#${_task.projectId}'
                                            : (context.isArabic
                                                ? 'تفاصيل المهمة'
                                                : 'TASK DETAILS'),
                                        style: const TextStyle(
                                          color: AxisColors.primarySoft,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                    if (_task.isCollaborative)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AxisColors.secondary
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          context.isArabic
                                              ? 'تعاوني'
                                              : 'COLLAB',
                                          style: const TextStyle(
                                            color: AxisColors.secondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    if (cleanSender.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AxisColors.primarySoft
                                              .withValues(alpha: 0.16),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '@$cleanSender',
                                          style: const TextStyle(
                                            color: AxisColors.primarySoft,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isDone)
                                    IconButton(
                                      icon: const Icon(Icons.share_outlined, size: 20, color: AxisColors.primarySoft),
                                      tooltip: context.isArabic ? 'مشاركة مع صاحب' : 'Share with Companion',
                                      onPressed: () => ShareTaskSheet.show(context, _task),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: AxisColors.secondary),
                                    tooltip: context.isArabic ? 'تعديل المهمة' : 'Edit Task',
                                    onPressed: _openEditTask,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 22, color: AxisColors.textMuted),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                // Title row + checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AxisCheckbox(
                      checked: isDone,
                      onChanged: (_) => _toggleDone(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AutoDirectionText(
                        _task.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: AxisColors.textDim,
                          color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Task Description Section
                _MetaSection(
                  title: context.isArabic ? 'الوصف' : 'Description',
                  trailing: _task.notes != null && _task.notes!.trim().isNotEmpty
                      ? const ReadingFontSizeControl()
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _task.notes != null && _task.notes!.trim().isNotEmpty
                          ? ValueListenableBuilder<double>(
                              valueListenable:
                                  ReadingPreferencesService().fontScaleNotifier,
                              builder: (context, fontScale, _) {
                                return AxisMarkdownViewer(
                                  markdown: _task.notes!,
                                  fontScale: fontScale,
                                  onMarkdownChanged: (updatedNotes) async {
                                    final updated =
                                        _task.copyWith(notes: updatedNotes);
                                    setState(() => _task = updated);
                                    await _repo.updateTask(updated);
                                    widget.onTaskUpdated?.call(updated);
                                  },
                                );
                              },
                            )
                          : InkWell(
                              onTap: _openEditTask,
                              child: Row(
                                children: [
                                  const Icon(Icons.add_circle_outline_rounded,
                                      size: 16, color: AxisColors.textDim),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.isArabic
                                        ? 'لم تتم إضافة وصف. انقر لإضافة التفاصيل...'
                                        : 'No description added. Tap to add details...',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AxisColors.textDim, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metadata section
                _MetaSection(title: context.isArabic ? 'التفاصيل' : 'Details', children: [
                  if (cleanSender.isNotEmpty)
                    _MetaRow(
                      icon: _task.isCollaborative
                          ? Icons.handshake_rounded
                          : Icons.person_outline_rounded,
                      iconColor: AxisColors.secondary,
                      label: context.isArabic ? 'مشارك بواسطة' : 'Shared by',
                      value: '@$cleanSender',
                    ),
                  if (_task.priority != null)
                    _MetaRow(
                      icon: Icons.flag_rounded,
                      iconColor: _priorityColor(_task.priority!),
                      label: context.isArabic ? 'الأولوية' : 'Priority',
                      value: 'P${_task.priority}',
                    ),
                  if (_task.projectId != null)
                    _MetaRow(
                      icon: Icons.folder_outlined,
                      iconColor: AxisColors.primary,
                      label: context.isArabic ? 'المشروع' : 'Project',
                      value: _task.projectId!,
                    ),
                  if (_task.dueDate != null)
                    _MetaRow(
                      icon: Icons.calendar_today_rounded,
                      iconColor: AxisColors.secondary,
                      label: context.isArabic ? 'تاريخ الاستحقاق' : 'Due Date',
                      value: _task.dueDate!,
                    ),
                  if (_task.dueTime != null)
                    _MetaRow(
                      icon: Icons.access_time_rounded,
                      iconColor: AxisColors.primarySoft,
                      label: context.isArabic ? 'الوقت' : 'Time',
                      value: _task.dueTime!,
                    ),
                  if (_task.estimateMin != null)
                    _MetaRow(
                      icon: Icons.timer_outlined,
                      iconColor: AxisColors.secondary,
                      label: context.isArabic ? 'الوقت التقديري' : 'Estimate',
                      value: _formatEstimate(_task.estimateMin!, context.isArabic),
                    ),
                  if (_task.recurrenceRule != null)
                    _MetaRow(
                      icon: Icons.repeat_rounded,
                      iconColor: AxisColors.success,
                      label: context.isArabic ? 'التكرار' : 'Recurrence',
                      value: _formatRecurrenceValue(_task.recurrenceRule!, context.isArabic),
                    ),
                ]),

                // Tags
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _MetaSection(title: context.isArabic ? 'الوسوم' : 'Tags', children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wrap(
                        spacing: 8, runSpacing: 6,
                        children: tags.map((t) => AxisChip(
                          label: '@$t',
                          backgroundColor: AxisColors.primary.withValues(alpha: 0.08),
                          textColor: AxisColors.primarySoft,
                        )).toList(),
                      ),
                    ),
                  ]),
                ],

                const SizedBox(height: 24),

                // Action buttons: Edit Task + Start Focus
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _openEditTask,
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text(
                          context.isArabic ? 'تعديل المهمة' : 'Edit Task',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AxisColors.secondary,
                          side: const BorderSide(color: AxisColors.secondary, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FocusScreen(initialTask: _task),
                            ),
                          );
                        },
                        icon: const Icon(Icons.timer_outlined, size: 16),
                        label: Text(
                          context.isArabic ? 'تركيز' : 'Focus',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AxisColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final taskTitle = _task.title;
                      await _repo.deleteTask(_task.id);
                      if (context.mounted) {
                        Navigator.pop(context);
                        AxisSnackBar.showDeleted(
                          context,
                          itemTitle: taskTitle,
                          itemType: context.isArabic ? 'مهمة' : 'Task',
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AxisColors.error, size: 18),
                    label: Text(
                      context.isArabic ? 'حذف المهمة' : 'Delete Task',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AxisColors.error),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AxisColors.error.withValues(alpha: 0.3), width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  ),
);
}

  Color _priorityColor(int p) {
    return switch (p) {
      1 => AxisColors.warning,
      2 => AxisColors.primary,
      _ => AxisColors.textMuted,
    };
  }

  String _formatEstimate(int minutes, bool isArabic) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0
          ? '$h${isArabic ? "س " : "h "}$m${isArabic ? "د" : "m"}'
          : '$h${isArabic ? "س" : "h"}';
    }
    return '$minutes${isArabic ? "د" : "m"}';
  }

  String _formatRecurrenceValue(String rule, bool isArabic) {
    final clean = rule.replaceAll('RRULE:FREQ=', '').toLowerCase();
    if (!isArabic) return clean;
    switch (clean) {
      case 'daily':
        return 'يومي';
      case 'weekly':
        return 'أسبوعي';
      case 'monthly':
        return 'شهري';
      default:
        return clean;
    }
  }
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({
    required this.title,
    required this.children,
    this.trailing,
  });
  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium),
            ?trailing,
          ],
        ),
        const SizedBox(height: 8),
        AxisCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AxisColors.textMuted)),
          const Spacer(),
          Text(value,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AxisColors.textHigh)),
        ],
      ),
    );
  }
}
