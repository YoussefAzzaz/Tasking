import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';

/// Single interactive row representing a habit within a category card.
class HabitItemTile extends StatelessWidget {
  final Habit habit;
  final bool isDone;
  final bool isEnabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleEnabled;

  const HabitItemTile({
    super.key,
    required this.habit,
    required this.isDone,
    required this.isEnabled,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    final cleanSender = (habit.senderUsername ?? '')
        .trim()
        .replaceFirst(RegExp(r'^@+'), '')
        .trim();
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.6,
      child: InkWell(
        onTap: onEdit,
        onLongPress: () => ShareTaskSheet.showForHabit(context, habit),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AxisCheckbox(
                checked: isDone,
                enabled: isEnabled,
                onChanged: (checked) {
                  if (!isEnabled) return;
                  onToggle(checked);
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AutoDirectionText(
                      habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: !isEnabled
                            ? AxisColors.textDim
                            : isDone
                                ? AxisColors.textDim
                                : AxisColors.textHigh,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    if ((habit.remindTime != null &&
                            habit.remindTime!.isNotEmpty) ||
                        habit.streakDays > 0 ||
                        cleanSender.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (cleanSender.isNotEmpty)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AxisColors.primarySoft
                                          .withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '@$cleanSender',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: AxisColors.primarySoft,
                                      ),
                                    ),
                                  ),
                                ),
                              if (habit.remindTime != null &&
                                  habit.remindTime!.isNotEmpty)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth),
                                  child: Text(
                                    habit.remindTime!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AxisColors.textMuted,
                                    ),
                                  ),
                                ),
                              if (habit.streakDays > 0 && isEnabled)
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                      maxWidth: constraints.maxWidth),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 12,
                                        color: AxisColors.warning,
                                      ),
                                      const SizedBox(width: 2),
                                      Flexible(
                                        child: Text(
                                          isArabic
                                              ? '${habit.streakDays} ${habit.streakDays == 1 ? 'يوم' : 'أيام'} تتابع'
                                              : '${habit.streakDays}d streak',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AxisColors.warning,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isEnabled)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onToggleEnabled(true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Text(
                          isArabic ? 'متوقفة' : 'PAUSED',
                          style: const TextStyle(
                            color: AxisColors.textDim,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDone
                            ? AxisColors.surfaceLow
                            : AxisColors.success.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDone
                              ? AxisColors.borderSubtle
                              : AxisColors.success.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isDone) ...[
                            const Icon(Icons.check_rounded,
                                size: 11, color: AxisColors.success),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            isDone
                                ? (isArabic ? 'مكتمل' : 'DONE')
                                : (isArabic
                                    ? '+${habit.targetValue} نقطة'
                                    : '+${habit.targetValue} XP'),
                            style: TextStyle(
                              color: isDone
                                  ? AxisColors.textDim
                                  : AxisColors.success,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 18,
                      color: AxisColors.textDim,
                    ),
                    tooltip: isArabic ? 'خيارات العادة' : 'Habit options',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 26,
                      minHeight: 26,
                    ),
                    color: AxisColors.surfaceHigh,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(
                        color: AxisColors.borderPrimary,
                        width: 1.2,
                      ),
                    ),
                    onSelected: (action) {
                      if (action == 'share') {
                        ShareTaskSheet.showForHabit(context, habit);
                      } else if (action == 'edit') {
                        onEdit();
                      } else if (action == 'delete') {
                        onDelete();
                      } else if (action == 'toggle_enabled') {
                        onToggleEnabled(!isEnabled);
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem<String>(
                        value: 'share',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(Icons.ios_share_rounded,
                                size: 16, color: AxisColors.primarySoft),
                            const SizedBox(width: 10),
                            Text(
                              isArabic ? 'مشاركة مع صاحب' : 'Share with Companion',
                              style: const TextStyle(
                                color: AxisColors.textHigh,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'toggle_enabled',
                        height: 38,
                        child: Row(
                          children: [
                            Icon(
                              isEnabled
                                  ? Icons.pause_circle_outline_rounded
                                  : Icons.play_circle_outline_rounded,
                              size: 16,
                              color: isEnabled
                                  ? AxisColors.warning
                                  : AxisColors.success,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              isArabic
                                  ? (isEnabled ? 'إيقاف مؤقت للعادة' : 'استئناف العادة')
                                  : (isEnabled ? 'Pause Habit' : 'Resume Habit'),
                              style: const TextStyle(
                                color: AxisColors.textHigh,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'edit',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(Icons.edit_outlined,
                                size: 16, color: AxisColors.primary),
                            const SizedBox(width: 10),
                            Text(
                              isArabic ? 'تعديل العادة' : 'Edit Habit',
                              style: const TextStyle(
                                color: AxisColors.textHigh,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        height: 38,
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                size: 16, color: AxisColors.error),
                            const SizedBox(width: 10),
                            Text(
                              isArabic ? 'حذف العادة' : 'Delete Habit',
                              style: const TextStyle(
                                color: AxisColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

