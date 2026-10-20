import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';
import 'package:axis/ui/habits/widgets/live_habit_card.dart';
import 'package:axis/ui/habits/widgets/habit_continuity_card.dart';

export 'package:axis/ui/habits/widgets/live_habit_card.dart';
export 'package:axis/ui/habits/widgets/habit_continuity_card.dart';

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
    _habitLogsStream =
        db.watch('SELECT * FROM habit_logs ORDER BY log_date DESC');
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
        title: const Text(
          'Reset Habit Streak?',
          style: TextStyle(color: AxisColors.textHigh),
        ),
        content: const Text(
          'This will reset your current habit streak to 0 days. All habit definitions will be preserved.',
          style: TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Reset to 0', style: TextStyle(color: Colors.white)),
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
          // STREAK & CONTINUITY PULSE HERO
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _habitLogsStream,
            builder: (context, snapshot) {
              final rows = snapshot.data ?? [];
              final streakLogs = rows
                  .map((r) =>
                      StreakLog(r['log_date'] as String, r['status'] as String))
                  .toList();

              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);
              final currentStreak =
                  StreakEngine.calculateStreak('daily', streakLogs, todayStr);

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
                  if (d1 != null &&
                      d2 != null &&
                      d2.difference(d1).inDays == 1) {
                    run++;
                    if (run > maxRun) maxRun = run;
                  } else if (d1 != null &&
                      d2 != null &&
                      d2.difference(d1).inDays > 1) {
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

                weekDayWidgets
                    .add(Expanded(child: DayPill(day: label, state: state)));
              }

              return HabitContinuityCard(
                currentStreak: currentStreak,
                bestStreak: bestStreak,
                multiplierStr: multiplierStr,
                monthlyRate: monthlyRate,
                weekDayWidgets: weekDayWidgets,
                onResetStreak: _confirmResetStreak,
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
                    const Icon(Icons.tune_rounded,
                        color: AxisColors.textMuted, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'DAILY ROUTINES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AxisColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: _openCreateHabit,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AxisColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AxisColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                      child:
                          CircularProgressIndicator(color: AxisColors.success),
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
                          const Icon(Icons.local_fire_department_outlined,
                              size: 40, color: AxisColors.textDim),
                          const SizedBox(height: 8),
                          const Text('No habits created yet',
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
                      child: LiveHabitCard(
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
