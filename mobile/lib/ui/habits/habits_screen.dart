import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _repo = HabitRepository();
  late final Stream<List<Map<String, dynamic>>> _habitLogsStream;

  @override
  void initState() {
    super.initState();
    _habitLogsStream = db.watch('SELECT * FROM habit_logs ORDER BY log_date DESC');
  }

  void _openCreateHabit() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateHabitSheet(
        onHabitCreated: () => setState(() {}),
      ),
    );
  }

  Future<void> _confirmResetStreak() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: const Text('Reset Habit Streak?',
            style: TextStyle(color: AxisColors.textHigh)),
        content: const Text(
          'This will reset your current habit streak to 0 days. All habit definitions will be preserved.',
          style: TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset to 0', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.resetAllStreaks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Habit streak has been reset to 0 days'),
          backgroundColor: AxisColors.surfaceLow,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // STREAK & CONTINUITY PULSE HERO (DYNAMIC FROM HABIT LOGS)
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _habitLogsStream,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? [];
              final streakLogs = rows
                  .map((r) => StreakLog(r['log_date'] as String, r['status'] as String))
                  .toList();

              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);
              final currentStreak = StreakEngine.calculateStreak('daily', streakLogs, todayStr);

              // Calculate best streak historically
              final doneDates = rows
                  .where((r) => r['status'] == 'done')
                  .map((r) => r['log_date'] as String)
                  .toSet();

              int bestStreak = currentStreak;
              if (doneDates.isNotEmpty) {
                final sortedDates = doneDates.toList()..sort();
                int maxRun = 1;
                int run = 1;
                for (int i = 1; i < sortedDates.length; i++) {
                  final d1 = DateTime.tryParse(sortedDates[i - 1]);
                  final d2 = DateTime.tryParse(sortedDates[i]);
                  if (d1 != null && d2 != null && d2.difference(d1).inDays == 1) {
                    run++;
                    if (run > maxRun) maxRun = run;
                  } else if (d1 != null && d2 != null && d2.difference(d1).inDays > 1) {
                    run = 1;
                  }
                }
                if (maxRun > bestStreak) bestStreak = maxRun;
              }

              // Multiplier dynamically based on streak
              final multiplier = (1.0 + (currentStreak * 0.1)).clamp(1.0, 3.0);
              final multiplierStr = '${multiplier.toStringAsFixed(1)}X';

              // 30-day Completion Rate
              int doneDaysIn30 = 0;
              for (int i = 0; i < 30; i++) {
                final d = now.subtract(Duration(days: i));
                final dKey = DateFormat('yyyy-MM-dd').format(d);
                if (doneDates.contains(dKey)) doneDaysIn30++;
              }
              final monthlyRate = (doneDaysIn30 / 30.0 * 100).round();

              // Monday through Sunday of current week
              final monday = now.subtract(Duration(days: now.weekday - 1));
              final weekDayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final weekDayWidgets = <Widget>[];

              for (int i = 0; i < 7; i++) {
                final dayDate = monday.add(Duration(days: i));
                final dayStr = DateFormat('yyyy-MM-dd').format(dayDate);
                final label = weekDayLabels[i];

                String state;
                if (dayStr.compareTo(todayStr) > 0) {
                  state = 'upcoming';
                } else if (dayStr == todayStr) {
                  state = doneDates.contains(todayStr) ? 'done' : 'today';
                } else {
                  state = doneDates.contains(dayStr) ? 'done' : 'missed';
                }

                weekDayWidgets.add(Expanded(child: _DayPill(day: label, state: state)));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Streak Status Summary Pill Row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceHigh.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: AxisColors.surfaceLow, blurRadius: 4)],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: AxisColors.success, size: 16),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'MULTIPLIER $multiplierStr',
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AxisColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceHigh.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [BoxShadow(color: AxisColors.surfaceLow, blurRadius: 4)],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AxisColors.secondary, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '$monthlyRate% MONTHLY RATE',
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AxisColors.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // STREAK HERO COCKPIT CARD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AxisCard(
                      tier: GlassTier.two,
                      padding: const EdgeInsets.all(16),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: -40, right: -40,
                            child: Container(
                              width: 140, height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AxisColors.success.withValues(alpha: 0.1),
                                boxShadow: [
                                  BoxShadow(
                                    color: AxisColors.success.withValues(alpha: 0.1),
                                    blurRadius: 40,
                                    spreadRadius: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('CONTINUITY PULSE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.textMuted)),
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.baseline,
                                            textBaseline: TextBaseline.alphabetic,
                                            children: [
                                              Text('$currentStreak', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 4),
                                              Text(currentStreak == 1 ? 'Day' : 'Days', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AxisColors.success, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.local_fire_department_rounded,
                                                color: currentStreak > 0 ? AxisColors.success : AxisColors.textDim,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          currentStreak == 0
                                              ? 'Start your streak today 🔥'
                                              : 'Current Best: $bestStreak ${bestStreak == 1 ? 'Day' : 'Days'} Unbroken 🔥',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AxisColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Reset Streak Action Button
                                  InkWell(
                                    onTap: _confirmResetStreak,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AxisColors.surfaceLow,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AxisColors.borderSubtle),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.restart_alt_rounded, color: AxisColors.warning, size: 14),
                                          SizedBox(width: 4),
                                          Text(
                                            'Reset',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: AxisColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Weekly Streak Matrix
                              Row(
                                children: weekDayWidgets,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 20),
          
          // HABIT LIST HEADER WITH "+ Add Habit" BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AxisColors.textMuted, size: 16),
                    const SizedBox(width: 8),
                    Text('DAILY ROUTINES',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AxisColors.textMuted,
                              fontWeight: FontWeight.bold,
                            )),
                  ],
                ),
                InkWell(
                  onTap: _openCreateHabit,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AxisColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AxisColors.success.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add, size: 14, color: AxisColors.success),
                        SizedBox(width: 4),
                        Text(
                          'Add Habit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // DYNAMIC HABIT STREAM LIST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<Habit>>(
              stream: _repo.watchHabits(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AxisColors.success),
                    ),
                  );
                }

                final habits = snapshot.data ?? [];
                if (habits.isEmpty) {
                  return AxisCard(
                    tier: GlassTier.two,
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.local_fire_department_outlined,
                              size: 40, color: AxisColors.textDim),
                          const SizedBox(height: 8),
                          Text('No habits created yet',
                              style: TextStyle(color: AxisColors.textDim)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _openCreateHabit,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create First Habit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AxisColors.success,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: habits.map((habit) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LiveHabitCard(
                        habit: habit,
                        onToggle: (done) => _repo.toggleHabit(habit.id, done),
                        onEdit: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => CreateHabitSheet(
                              habitToEdit: habit,
                              onHabitCreated: () => setState(() {}),
                            ),
                          );
                        },
                        onDelete: () => _repo.deleteHabit(habit.id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.state});
  final String day;
  final String state; // done, today, missed, upcoming

  @override
  Widget build(BuildContext context) {
    Color labelColor = AxisColors.textMuted;
    Color boxColor = AxisColors.canvasBase;
    Widget child = const SizedBox();

    if (state == 'done') {
      labelColor = AxisColors.success;
      boxColor = AxisColors.success.withValues(alpha: 0.15);
      child = const Icon(Icons.check_rounded, color: AxisColors.success, size: 14);
    } else if (state == 'today') {
      labelColor = AxisColors.primary;
      boxColor = AxisColors.primary.withValues(alpha: 0.12);
      child = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AxisColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AxisColors.primary.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      );
    } else if (state == 'missed') {
      labelColor = AxisColors.textDim;
      boxColor = AxisColors.surfaceLow.withValues(alpha: 0.3);
      child = const Icon(Icons.remove_rounded, color: AxisColors.textDim, size: 12);
    } else if (state == 'upcoming') {
      labelColor = AxisColors.textDim;
      boxColor = AxisColors.canvasBase;
      child = Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: AxisColors.borderSubtle,
          shape: BoxShape.circle,
        ),
      );
    }

    return Column(
      children: [
        Text(
          day,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: state == 'today' || state == 'done'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: state == 'done'
                  ? AxisColors.success.withValues(alpha: 0.4)
                  : (state == 'today'
                      ? AxisColors.primary.withValues(alpha: 0.5)
                      : AxisColors.borderSubtle.withValues(alpha: 0.4)),
            ),
            boxShadow: state == 'done'
                ? [
                    BoxShadow(
                      color: AxisColors.success.withValues(alpha: 0.3),
                      blurRadius: 8,
                    )
                  ]
                : (state == 'today'
                    ? [
                        BoxShadow(
                          color: AxisColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ]
                    : null),
          ),
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _LiveHabitCard extends StatelessWidget {
  const _LiveHabitCard({
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
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AxisColors.borderGlass2,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AxisColors.secondary),
              title: const Text('Edit Habit', style: TextStyle(color: AxisColors.textHigh, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () {
                Navigator.pop(ctx);
                onEdit();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AxisColors.error),
              title: const Text('Delete Habit', style: TextStyle(color: AxisColors.error, fontWeight: FontWeight.w600)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                                decoration: isDone ? TextDecoration.lineThrough : null,
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
                        color: isDone ? AxisColors.textDim : AxisColors.success,
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
