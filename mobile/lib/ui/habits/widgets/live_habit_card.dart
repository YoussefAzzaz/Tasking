import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/habit_repository.dart';

/// Interactive habit card featuring XP rewards, custom habit icons, options sheet and check toggle
class LiveHabitCard extends StatelessWidget {
  const LiveHabitCard({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Habit habit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  IconData _iconData(String icon) {
    switch (icon) {
      case 'book':
        return Icons.menu_book_rounded;
      case 'meditation':
        return Icons.self_improvement_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'code':
        return Icons.terminal_rounded;
      case 'sleep':
        return Icons.bedtime_rounded;
      case 'mosque':
      case 'prayer':
      case 'prayers':
        return Icons.mosque_rounded;
      case 'fajr':
        return Icons.wb_twilight_rounded;
      case 'dhuhr':
        return Icons.wb_sunny_rounded;
      case 'asr':
        return Icons.brightness_medium_rounded;
      case 'maghrib':
        return Icons.wb_twilight_rounded;
      case 'isha':
        return Icons.dark_mode_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xF50D1524),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AxisColors.borderGlass2,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: AxisColors.secondary),
              title: const Text('Edit Habit',
                  style: TextStyle(
                      color: AxisColors.textHigh, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AxisColors.error),
              title: const Text('Delete Habit',
                  style: TextStyle(
                      color: AxisColors.error, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    backgroundColor: AxisColors.surfaceHigh,
                    title: Text('Delete "${habit.name}"?',
                        style: const TextStyle(color: AxisColors.textHigh)),
                    content: const Text(
                        'This will delete the habit and its streak history.',
                        style: TextStyle(color: AxisColors.textMuted)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx),
                        child: const Text('Cancel',
                            style: TextStyle(color: AxisColors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogCtx);
                          onDelete();
                        },
                        child: const Text('Delete',
                            style: TextStyle(color: AxisColors.error)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDone = habit.isDoneToday;

    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AxisCheckbox(
            checked: isDone,
            onChanged: (v) => onToggle(v),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _iconData(habit.icon),
                      size: 16,
                      color: isDone ? AxisColors.textDim : AxisColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          habit.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: isDone
                                    ? AxisColors.textDim
                                    : AxisColors.textHigh,
                                decoration:
                                    isDone ? TextDecoration.lineThrough : null,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (habit.remindTime != null)
                              Text(
                                habit.remindTime!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AxisColors.textMuted),
                              ),
                            if (habit.streakDays > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department_rounded,
                                      size: 12, color: AxisColors.warning),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${habit.streakDays}d streak',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AxisColors.warning,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDone
                  ? AxisColors.surfaceLow
                  : AxisColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDone) ...[
                  const Icon(Icons.check_rounded,
                      size: 12, color: AxisColors.success),
                  const SizedBox(width: 4),
                ],
                Text(
                  isDone ? 'DONE' : '+${habit.targetValue} XP',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color:
                            isDone ? AxisColors.textDim : AxisColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                size: 18, color: AxisColors.textDim),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            splashRadius: 18,
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
    );
  }
}
