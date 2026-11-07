import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';

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
    this.forceExpand = false,
  });

  final HabitCategory category;
  final Color color;
  final List<Habit> habits;
  final void Function(Habit habit, bool done) onToggleHabit;
  final void Function(Habit habit) onEditHabit;
  final void Function(Habit habit) onDeleteHabit;
  final VoidCallback onAddHabit;
  final VoidCallback? onDeleteCategory;
  final bool forceExpand;

  @override
  State<HabitCategoryCard> createState() => _HabitCategoryCardState();
}

class _HabitCategoryCardState extends State<HabitCategoryCard> {
  bool _expanded = true;
  final Map<String, bool> _optimisticDone = {};
  final Map<String, bool> _optimisticEnabled = {};

  @override
  void didUpdateWidget(covariant HabitCategoryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceExpand && !_expanded) {
      _expanded = true;
    }
    // Clean up optimistic state when database stream catches up
    for (final habit in widget.habits) {
      if (_optimisticDone.containsKey(habit.id) &&
          _optimisticDone[habit.id] == habit.isDoneToday) {
        _optimisticDone.remove(habit.id);
      }
      if (_optimisticEnabled.containsKey(habit.id) &&
          _optimisticEnabled[habit.id] == habit.isEnabled) {
        _optimisticEnabled.remove(habit.id);
      }
    }
  }

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
      default:
        return Icons.fitness_center_rounded;
    }
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
              AxisSnackBar.showDeleted(context, itemTitle: habit.name, itemType: 'Habit');
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
    final activeHabits = widget.habits.where((h) {
      return _optimisticEnabled.containsKey(h.id)
          ? _optimisticEnabled[h.id]!
          : h.isEnabled;
    }).toList();
    final total = activeHabits.length;
    final done = activeHabits.where((h) {
      return _optimisticDone.containsKey(h.id)
          ? _optimisticDone[h.id]!
          : h.isDoneToday;
    }).length;
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
                                  Text(
                                    widget.category.name,
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
                                    '$done of $total habits finished today',
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
                          if (widget.onDeleteCategory != null &&
                              widget.category.id != 'general_routines')
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 20, color: AxisColors.textDim),
                              tooltip: 'Delete category',
                              constraints: const BoxConstraints(
                                  minWidth: 48, minHeight: 48),
                              onPressed: () => _confirmDeleteCategory(context),
                            ),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AxisColors.textMuted,
                            ),
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

          // Habits breakdown (animated expand and shrink)
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: ExcludeSemantics(
                excluding: !_expanded,
                child: _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        const Divider(color: AxisColors.borderSubtle, height: 1),
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
            else ...[
              Builder(builder: (context) {
                final sortedHabits = List<Habit>.from(widget.habits)
                  ..sort(HabitRepository.compareByTime);

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  itemCount: sortedHabits.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AxisColors.borderGlass2, height: 1),
                  itemBuilder: (context, i) {
                    final habit = sortedHabits[i];
                    final isDone = _optimisticDone.containsKey(habit.id)
                        ? _optimisticDone[habit.id]!
                        : habit.isDoneToday;
                    final isEnabled = _optimisticEnabled.containsKey(habit.id)
                        ? _optimisticEnabled[habit.id]!
                        : habit.isEnabled;

                  return Opacity(
                    opacity: isEnabled ? 1.0 : 0.6,
                    child: InkWell(
                      onTap: () => widget.onEditHabit(habit),
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
                                setState(() {
                                  _optimisticDone[habit.id] = checked;
                                });
                                widget.onToggleHabit(habit, checked);
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
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if ((habit.remindTime != null &&
                                          habit.remindTime!.isNotEmpty) ||
                                      habit.streakDays > 0) ...[
                                    const SizedBox(height: 3),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Wrap(
                                          spacing: 8,
                                          runSpacing: 2,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            if (habit.remindTime != null &&
                                                habit.remindTime!.isNotEmpty)
                                              ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    maxWidth:
                                                        constraints.maxWidth),
                                                child: Text(
                                                  habit.remindTime!,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          AxisColors.textMuted),
                                                ),
                                              ),
                                            if (habit.streakDays > 0 && isEnabled)
                                              ConstrainedBox(
                                                constraints: BoxConstraints(
                                                    maxWidth:
                                                        constraints.maxWidth),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                        Icons
                                                            .local_fire_department_rounded,
                                                        size: 12,
                                                        color:
                                                            AxisColors.warning),
                                                    const SizedBox(width: 2),
                                                    Flexible(
                                                      child: Text(
                                                        '${habit.streakDays}d streak',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              AxisColors.warning,
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                    onTap: () {
                                      setState(() {
                                        _optimisticEnabled[habit.id] = true;
                                      });
                                      HabitRepository().toggleHabitEnabled(habit.id, true);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AxisColors.surfaceHigh
                                            .withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: AxisColors.borderSubtle),
                                      ),
                                      child: const Text(
                                        'PAUSED',
                                        style: TextStyle(
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
                                          : AxisColors.success
                                              .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: isDone
                                            ? AxisColors.borderSubtle
                                            : AxisColors.success
                                                .withValues(alpha: 0.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isDone) ...[
                                          const Icon(Icons.check_rounded,
                                              size: 11,
                                              color: AxisColors.success),
                                          const SizedBox(width: 3),
                                        ],
                                        Text(
                                          isDone
                                              ? 'DONE'
                                              : '+${habit.targetValue} XP',
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
                                  tooltip: 'Habit options',
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
                                    if (action == 'edit') {
                                      widget.onEditHabit(habit);
                                    } else if (action == 'delete') {
                                      _confirmDeleteHabit(context, habit);
                                    } else if (action == 'toggle_enabled') {
                                      final nextVal = !isEnabled;
                                      setState(() {
                                        _optimisticEnabled[habit.id] = nextVal;
                                      });
                                      HabitRepository().toggleHabitEnabled(
                                          habit.id, nextVal);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
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
                                            isEnabled
                                                ? 'Pause Habit'
                                                : 'Resume Habit',
                                            style: const TextStyle(
                                              color: AxisColors.textHigh,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem<String>(
                                    value: 'edit',
                                    height: 38,
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined,
                                            size: 16,
                                            color: AxisColors.primary),
                                        SizedBox(width: 10),
                                        Text(
                                          'Edit Habit',
                                          style: TextStyle(
                                            color: AxisColors.textHigh,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    height: 38,
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded,
                                            size: 16, color: AxisColors.error),
                                        SizedBox(width: 10),
                                        Text(
                                          'Delete Habit',
                                          style: TextStyle(
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
              },
              );
            }),
          ],

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
                      Flexible(
                        child: Text(
                          'Add Habit to ${widget.category.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
                      ],
                    )
                  : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
