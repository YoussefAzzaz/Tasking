import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';
import 'package:axis/ui/habits/widgets/habit_continuity_card.dart';
import 'package:axis/ui/habits/widgets/habit_category_card.dart';

export 'package:axis/ui/habits/widgets/habit_continuity_card.dart';
export 'package:axis/ui/habits/widgets/habit_category_card.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _repo = HabitRepository();
  late final Stream<List<Map<String, dynamic>>> _habitLogsStream;
  late final Stream<List<Map<String, dynamic>>> _habitCategoriesStream;
  late final Stream<List<Habit>> _habitsStream;
  static final Set<String> _locallyDeletedCategories = {};

  @override
  void initState() {
    super.initState();
    _habitLogsStream =
        db.watch('SELECT * FROM habit_logs ORDER BY log_date DESC');
    _habitCategoriesStream =
        db.watch('SELECT * FROM habit_categories ORDER BY name ASC');
    _habitsStream = _repo.watchHabits();
  }

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.success;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.success;
    }
  }

  void _openCreateHabit({String? initialCategory}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateHabitSheet(
        initialCategory: initialCategory,
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

          // HABIT CATEGORIES HEADER BANNER WITH "+ Add Habit" BUTTON
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: const [
                        Icon(Icons.tune_rounded,
                            color: AxisColors.success, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'HABIT ROUTINES BY CATEGORY',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.success,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _openCreateHabit(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      backgroundColor:
                          AxisColors.success.withValues(alpha: 0.15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add_rounded,
                        size: 14, color: AxisColors.success),
                    label: const Text(
                      'Add Habit',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // DYNAMIC HABIT CATEGORY STREAM & LIST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _habitCategoriesStream,
              builder: (context, catSnapshot) {
                return StreamBuilder<List<Habit>>(
                  stream: _habitsStream,
                  builder: (context, habitSnapshot) {
                    if (catSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        habitSnapshot.connectionState ==
                            ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: AxisColors.success),
                        ),
                      );
                    }

                    final catRows = catSnapshot.data ?? [];
                    final allHabits = habitSnapshot.data ?? [];

                    final customCategories = catRows
                        .map((r) => HabitCategory(
                              id: r['id'] as String,
                              name: r['name'] as String,
                              icon: (r['icon'] as String?) ?? 'fitness',
                              color: (r['color'] as String?) ?? '#10B981',
                            ))
                        .toList();

                    // Discovered categories from habits' category if not in DB
                    final categoryNames = <String>{};
                    for (final c in customCategories) {
                      categoryNames.add(c.name.toLowerCase());
                    }

                    final discoveredCategories = <HabitCategory>[];
                    for (final h in allHabits) {
                      final catTrimmed = h.category.trim();
                      if (catTrimmed.isNotEmpty &&
                          !categoryNames.contains(catTrimmed.toLowerCase())) {
                        categoryNames.add(catTrimmed.toLowerCase());
                        discoveredCategories.add(
                          HabitCategory(
                            id: 'discovered_$catTrimmed',
                            name: catTrimmed,
                            icon: h.icon,
                            color: h.color,
                          ),
                        );
                      }
                    }

                    final allCategories = [
                      ...customCategories,
                      ...discoveredCategories
                    ].where((c) {
                      final idLower = c.id.toLowerCase();
                      final nameLower = c.name.toLowerCase();
                      return !_locallyDeletedCategories.contains(idLower) &&
                          !_locallyDeletedCategories.contains(nameLower) &&
                          !_locallyDeletedCategories
                              .contains(idLower.replaceFirst('discovered_', ''));
                    }).toList();

                    // Defaults if empty
                    if (allCategories.isEmpty) {
                      final defaults = const [
                        HabitCategory(
                            id: 'cat_prayers',
                            name: 'Prayers',
                            icon: 'mosque',
                            color: '#10B981'),
                        HabitCategory(
                            id: 'cat_workout',
                            name: 'Workout',
                            icon: 'fitness',
                            color: '#10B981'),
                        HabitCategory(
                            id: 'cat_reading',
                            name: 'Reading',
                            icon: 'book',
                            color: '#38BDF8'),
                        HabitCategory(
                            id: 'cat_mindful',
                            name: 'Mindful',
                            icon: 'meditation',
                            color: '#A855F7'),
                        HabitCategory(
                            id: 'cat_hydrate',
                            name: 'Hydrate',
                            icon: 'water',
                            color: '#06B6D4'),
                        HabitCategory(
                            id: 'cat_code',
                            name: 'Code',
                            icon: 'code',
                            color: '#6366F1'),
                        HabitCategory(
                            id: 'cat_rest',
                            name: 'Rest',
                            icon: 'sleep',
                            color: '#F59E0B'),
                      ]
                          .where((c) =>
                              !_locallyDeletedCategories
                                  .contains(c.id.toLowerCase()) &&
                              !_locallyDeletedCategories
                                  .contains(c.name.toLowerCase()))
                          .toList();
                      allCategories.addAll(defaults);
                    }

                    // Prioritize Prayers category at the top
                    allCategories.sort((a, b) {
                      final aIsPrayer = a.name.toLowerCase() == 'prayers';
                      final bIsPrayer = b.name.toLowerCase() == 'prayers';
                      if (aIsPrayer && !bIsPrayer) return -1;
                      if (!aIsPrayer && bIsPrayer) return 1;
                      return a.name.compareTo(b.name);
                    });

                    // Separate habits by category
                    final Map<String, List<Habit>> habitsByCategory = {};
                    final unassignedHabits = <Habit>[];

                    for (final h in allHabits) {
                      final catTrimmed = h.category.trim();
                      if (catTrimmed.isEmpty) {
                        unassignedHabits.add(h);
                        continue;
                      }

                      final matchedCat = allCategories.firstWhere(
                        (c) =>
                            c.id == catTrimmed ||
                            c.name.toLowerCase() == catTrimmed.toLowerCase(),
                        orElse: () => const HabitCategory(id: '', name: ''),
                      );

                      if (matchedCat.name.isNotEmpty) {
                        habitsByCategory
                            .putIfAbsent(matchedCat.name, () => [])
                            .add(h);
                      } else {
                        unassignedHabits.add(h);
                      }
                    }

                    return Column(
                      children: [
                        ...allCategories.map((category) {
                          final habits = habitsByCategory[category.name] ?? [];
                          final color = _parseHex(category.color);

                          return HabitCategoryCard(
                            category: category,
                            color: color,
                            habits: habits,
                            onToggleHabit: (habit, done) =>
                                _repo.toggleHabit(habit.id, done),
                            onEditHabit: (habit) {
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
                            onDeleteHabit: (habit) =>
                                _repo.deleteHabit(habit.id),
                            onAddHabit: () => _openCreateHabit(
                                initialCategory: category.name),
                            onDeleteCategory: () async {
                              setState(() {
                                _locallyDeletedCategories
                                    .add(category.id.toLowerCase());
                                _locallyDeletedCategories
                                    .add(category.name.toLowerCase());
                                final raw = category.id
                                    .toLowerCase()
                                    .replaceFirst('discovered_', '');
                                _locallyDeletedCategories.add(raw);
                              });

                              try {
                                await db.execute('''
                                  DELETE FROM habit_categories
                                  WHERE id = ? 
                                     OR id = ?
                                     OR LOWER(name) = LOWER(?)
                                ''', [
                                  category.id,
                                  category.id.replaceFirst('discovered_', ''),
                                  category.name
                                ]);
                                await db.execute('''
                                  UPDATE habits 
                                  SET kind = NULL 
                                  WHERE LOWER(COALESCE(kind, '')) = LOWER(?)
                                ''', [category.name]);
                              } catch (e) {
                                debugPrint('Error deleting category: $e');
                              }
                            },
                          );
                        }),

                        // Unassigned / General Routines section if any
                        if (unassignedHabits.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          HabitCategoryCard(
                            category: const HabitCategory(
                              id: 'general_routines',
                              name: 'General Routines',
                              icon: 'fitness',
                              color: '#64748B',
                            ),
                            color: const Color(0xFF64748B),
                            habits: unassignedHabits,
                            onToggleHabit: (habit, done) =>
                                _repo.toggleHabit(habit.id, done),
                            onEditHabit: (habit) {
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
                            onDeleteHabit: (habit) =>
                                _repo.deleteHabit(habit.id),
                            onAddHabit: () => _openCreateHabit(
                                initialCategory: 'General Routines'),
                          ),
                        ],
                      ],
                    );
                  },
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
