import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

enum TaskCollisionChoice {
  moveNewTask,
  moveExistingTask,
  cancel,
}

/// Alert dialog displayed when creating a task that collides with an existing task.
/// Gives the user explicit control to either move the new task to the next available slot,
/// or move the existing task to the next empty spot.
class TaskCollisionDialog extends StatelessWidget {
  const TaskCollisionDialog({
    super.key,
    required this.newTaskTitle,
    required this.conflictingTaskTitle,
    required this.requestedTime,
    required this.nextAvailableTime,
  });

  final String newTaskTitle;
  final String conflictingTaskTitle;
  final String requestedTime;
  final String nextAvailableTime;

  static Future<TaskCollisionChoice?> show({
    required BuildContext context,
    required String newTaskTitle,
    required String conflictingTaskTitle,
    required String requestedTime,
    required String nextAvailableTime,
  }) {
    return showDialog<TaskCollisionChoice>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TaskCollisionDialog(
        newTaskTitle: newTaskTitle,
        conflictingTaskTitle: conflictingTaskTitle,
        requestedTime: requestedTime,
        nextAvailableTime: nextAvailableTime,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: AxisColors.surfaceHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.secondary.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Icon and Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AxisColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.schedule_send_rounded,
                      color: AxisColors.secondary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isArabic ? 'تعارض في مواعيد المهام' : 'Schedule Conflict Detected',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textHigh,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description
              Text(
                isArabic
                    ? 'المهمة الجديدة "$newTaskTitle" تتعارض في وقتها ($requestedTime) مع المهمة الحالية "$conflictingTaskTitle".'
                    : 'The new task "$newTaskTitle" ($requestedTime) overlaps with "$conflictingTaskTitle".',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AxisColors.textMuted,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                isArabic
                    ? 'كيف تفضل حل هذا التعارض؟'
                    : 'How would you like to schedule this?',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AxisColors.textHigh,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 16),

              // Option 1: Move new task to next available slot
              _ChoiceTile(
                icon: Icons.trending_flat_rounded,
                title: isArabic
                    ? 'نقل هذه المهمة للفترة المتاحة التالية'
                    : 'Move this task to next available slot',
                subtitle: isArabic
                    ? 'جدولة المهمة الجديدة في $nextAvailableTime وإبقاء المهمة الحالية في مكانها'
                    : 'Place new task at $nextAvailableTime; keep existing task unchanged',
                isPrimary: true,
                onTap: () => Navigator.pop(context, TaskCollisionChoice.moveNewTask),
              ),
              const SizedBox(height: 10),

              // Option 2: Move existing task to next empty spot
              _ChoiceTile(
                icon: Icons.swap_vert_rounded,
                title: isArabic
                    ? 'نقل المهمة الحالية إلى أقرب فترة شاغرة'
                    : 'Move existing task to next empty spot',
                subtitle: isArabic
                    ? 'تحصل المهمة الجديدة على $requestedTime وتُنقل "$conflictingTaskTitle"'
                    : 'New task takes $requestedTime; "$conflictingTaskTitle" moves to next empty slot',
                isPrimary: false,
                onTap: () => Navigator.pop(context, TaskCollisionChoice.moveExistingTask),
              ),
              const SizedBox(height: 16),

              // Cancel button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, TaskCollisionChoice.cancel),
                  child: Text(
                    isArabic ? 'إلغاء' : 'Cancel',
                    style: const TextStyle(color: AxisColors.textMuted),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPrimary
                ? AxisColors.primary.withValues(alpha: 0.12)
                : AxisColors.surfaceLow.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isPrimary
                  ? AxisColors.primary.withValues(alpha: 0.5)
                  : AxisColors.borderSubtle,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isPrimary ? AxisColors.primary : AxisColors.secondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textHigh,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AxisColors.textMuted,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
