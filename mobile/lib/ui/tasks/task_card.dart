import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/recurrence_engine.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';

/// Full-height task card per DESIGN.md §Task Cards:
/// Glass Tier 1 | 12px vertical, 14px horizontal padding
/// Lead checkbox | Geist title | tags cluster | Space Mono metadata
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    this.onTap,
  });

  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'done';
    final cleanSender = (task.senderUsername ?? '')
        .trim()
        .replaceFirst(RegExp(r'^@+'), '')
        .trim();
    final tags = (task.tags ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) =>
            t.isNotEmpty &&
            (cleanSender.isEmpty ||
                t.replaceFirst(RegExp(r'^@+'), '').toLowerCase() !=
                    cleanSender.toLowerCase()))
        .toList();

    return GestureDetector(
      onTap: onTap,
      onLongPress: isDone
          ? null
          : () {
              HapticFeedback.mediumImpact();
              ShareTaskSheet.show(context, task);
            },
      child: AxisCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lead: custom checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AxisCheckbox(
                checked: isDone,
                onChanged: onToggle,
              ),
            ),
            const SizedBox(width: 12),

            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  AutoDirectionText(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDone
                          ? AxisColors.textDim
                          : AxisColors.textHigh,
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AxisColors.textDim,
                    ),
                  ),

                  // Metadata row
                  if (_hasMeta(task)) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (task.isCollaborative)
                          AxisChip(
                            label: context.isArabic ? 'تعاوني' : 'COLLAB',
                            dotColor: AxisColors.secondary,
                            backgroundColor:
                                AxisColors.secondary.withValues(alpha: 0.14),
                            textColor: AxisColors.secondary,
                          ),
                        if (cleanSender.isNotEmpty)
                          AxisChip(
                            label: '@$cleanSender',
                            backgroundColor:
                                AxisColors.primarySoft.withValues(alpha: 0.16),
                            textColor: AxisColors.primarySoft,
                          ),
                        if (task.priority != null)
                          PriorityChip(priority: task.priority!),
                        if (task.dueDate != null)
                          AxisChip(
                            label: () {
                              final baseDate = task.dueDate == 'today'
                                  ? (context.isArabic ? 'اليوم' : 'today')
                                  : (task.dueDate == 'tmr'
                                      ? (context.isArabic ? 'غداً' : 'tmr')
                                      : task.dueDate!);
                              final time = task.dueTime?.trim() ?? '';
                              return time.isNotEmpty ? '$baseDate · $time' : baseDate;
                            }(),
                            dotColor: _dueDateColor(task.dueDate!),
                            backgroundColor: _dueDateColor(task.dueDate!)
                                .withValues(alpha: 0.10),
                            textColor: _dueDateColor(task.dueDate!),
                          ),
                        if (task.isRecurring)
                          AxisChip(
                            label: RecurrenceEngine.formatHumanReadable(
                              task.recurrenceRule,
                              isArabic: context.isArabic,
                            ),
                            dotColor: AxisColors.success,
                            backgroundColor:
                                AxisColors.success.withValues(alpha: 0.12),
                            textColor: AxisColors.success,
                          ),
                        ...tags.map((t) => AxisChip(
                          label: '@$t',
                          backgroundColor:
                              AxisColors.primary.withValues(alpha: 0.08),
                          textColor: AxisColors.primarySoft,
                        )),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Trailing: estimate in Space Mono
            if (task.estimateMin != null) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatEstimate(task.estimateMin!, context.isArabic),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasMeta(Task t) =>
      t.isCollaborative ||
      (t.senderUsername != null && t.senderUsername!.trim().isNotEmpty) ||
      t.priority != null ||
      t.dueDate != null ||
      t.isRecurring ||
      (t.tags?.isNotEmpty ?? false);

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

  Color _dueDateColor(String date) {
    if (date == 'today') return AxisColors.secondary;
    if (date == 'tmr') return AxisColors.primarySoft;
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (date.compareTo(todayStr) < 0) {
        return AxisColors.error;
      } else if (date == todayStr) {
        return AxisColors.secondary;
      }
    } catch (_) {}
    return AxisColors.textMuted;
  }
}
