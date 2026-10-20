import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';
import 'package:axis/ui/habits/widgets/qibla_compass_sheet.dart';

/// EXPANDABLE HABIT CATEGORY CARD
/// Displays habits grouped by category with live progress bar, completion status,
/// checklist items, and quick "+ Add Habit to [Category]" action.
class HabitCategoryCard extends StatefulWidget {
  const HabitCategoryCard({
    super.key,
    required this.category,
    required this.color,
    required this.habits,
    required this.onToggleHabit,
    required this.onEditHabit,
    required this.onDeleteHabit,
    required this.onAddHabit,
    this.onDeleteCategory,
  });

  final HabitCategory category;
  final Color color;
  final List<Habit> habits;
  final void Function(Habit habit, bool done) onToggleHabit;
  final void Function(Habit habit) onEditHabit;
  final void Function(Habit habit) onDeleteHabit;
  final VoidCallback onAddHabit;
  final VoidCallback? onDeleteCategory;

  @override
  State<HabitCategoryCard> createState() => _HabitCategoryCardState();
}

class _HabitCategoryCardState extends State<HabitCategoryCard> {
  bool _expanded = true;

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
      case 'finance':
        return Icons.account_balance_wallet_rounded;
      case 'health':
        return Icons.favorite_rounded;
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

  void _showHabitOptions(BuildContext context, Habit habit) {
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
              title: const Text(
                'Edit Habit',
                style: TextStyle(
                  color: AxisColors.textHigh,
                  fontWeight: FontWeight.w600,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () {
                Navigator.pop(ctx);
                widget.onEditHabit(habit);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AxisColors.error),
              title: const Text(
                'Delete Habit',
                style: TextStyle(
                  color: AxisColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteHabit(context, habit);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteHabit(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          'Delete "${habit.name}"?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: const Text(
          'This will permanently delete this habit and all its streak logs.',
          style: TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              widget.onDeleteHabit(habit);
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          'Delete "${widget.category.name}"?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: Text(
          'Are you sure you want to delete the "${widget.category.name}" category? Habits in this category will remain safe in General Routines.',
          style: const TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              widget.onDeleteCategory?.call();
            },
            child:
                const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.habits.length;
    final done = widget.habits.where((h) => h.isDoneToday).length;
    final progress = total > 0 ? (done / total) : 0.0;
    final percent = (progress * 100).toInt();
    final isComplete = total > 0 && done == total;
    final isPrayers = widget.category.name.toLowerCase() == 'prayers';

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
          // Category Header (Expandable)
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
                              child: Icon(
                                _iconData(widget.category.icon),
                                color: widget.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          widget.category.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AxisColors.textHigh,
                                          ),
                                        ),
                                      ),
                                      if (isPrayers) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: widget.color
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: widget.color
                                                    .withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.location_on_rounded,
                                                  size: 10, color: widget.color),
                                              const SizedBox(width: 2),
                                              Text(
                                                PrayerTimeService().currentCity,
                                                style: TextStyle(
                                                  color: widget.color,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isPrayers
                                        ? '$done of $total prayers completed today'
                                        : '$done of $total habits finished today',
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
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AxisColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AxisColors.success
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Text(
                                'DONE',
                                style: TextStyle(
                                  color: AxisColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                          if (isPrayers) ...[
                            IconButton(
                              icon: const Icon(Icons.explore_rounded,
                                  size: 18, color: AxisColors.success),
                              tooltip: 'Qibla Direction Compass',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 26, minHeight: 26),
                              onPressed: () => QiblaCompassSheet.show(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.sync_rounded,
                                  size: 18, color: AxisColors.textDim),
                              tooltip: 'Refresh Prayer Times & Location',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 26, minHeight: 26),
                              onPressed: () async {
                                await PrayerTimeService()
                                    .syncPrayerHabits(forceLocation: true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Prayer times refreshed for ${PrayerTimeService().currentCity}'),
                                      backgroundColor: AxisColors.surfaceLow,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                          if (widget.onDeleteCategory != null &&
                              widget.category.id != 'general_routines' &&
                              !isPrayers)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AxisColors.textDim),
                              tooltip: 'Delete category',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 26, minHeight: 26),
                              onPressed: () => _confirmDeleteCategory(context),
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
                                    ? [
                                        AxisColors.success,
                                        const Color(0xFF34D399),
                                      ]
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

          // Habits breakdown
          if (_expanded) ...[
            const Divider(color: AxisColors.borderSubtle, height: 1),
            if (isPrayers)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                child: InkWell(
                  onTap: () => QiblaCompassSheet.show(context),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.explore_rounded,
                            size: 16, color: widget.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Qibla Direction (Live GPS & Compass)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: widget.color,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 11,
                          color: widget.color.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (widget.habits.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: Text(
                    'No habits created for ${widget.category.name} yet.',
                    style:
                        const TextStyle(color: AxisColors.textDim, fontSize: 12),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: widget.habits.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: AxisColors.borderGlass2, height: 1),
                itemBuilder: (context, i) {
                  final habit = widget.habits[i];
                  final isDone = habit.isDoneToday;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: AxisCheckbox(
                      checked: isDone,
                      onChanged: (checked) =>
                          widget.onToggleHabit(habit, checked),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color:
                                AxisColors.surfaceHigh.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            _iconData(habit.icon),
                            size: 14,
                            color: isDone ? AxisColors.textDim : widget.color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            habit.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDone
                                  ? AxisColors.textDim
                                  : AxisColors.textHigh,
                              decoration:
                                  isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(left: 27, top: 2),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (habit.remindTime != null &&
                              habit.remindTime!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isPrayers) ...[
                                  const Icon(Icons.access_time_filled_rounded,
                                      size: 11, color: AxisColors.success),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Adan ${habit.remindTime!}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AxisColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    habit.remindTime!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AxisColors.textMuted),
                                  ),
                                ],
                              ],
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
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                                isDone ? 'DONE' : '+${habit.targetValue} XP',
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
                        IconButton(
                          icon: const Icon(Icons.more_vert_rounded,
                              size: 18, color: AxisColors.textDim),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 26, minHeight: 26),
                          onPressed: () => _showHabitOptions(context, habit),
                        ),
                      ],
                    ),
                    onTap: () => widget.onEditHabit(habit),
                  );
                },
              ),

            // Bottom Add Habit button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: InkWell(
                onTap: widget.onAddHabit,
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
                        isPrayers
                            ? 'Add Extra Prayer (e.g. Duha, Tahajjud)'
                            : 'Add Habit to ${widget.category.name}',
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
