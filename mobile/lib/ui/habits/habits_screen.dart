import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/ui/habits/create_habit_sheet.dart';
import 'package:axis/ui/habits/widgets/habit_continuity_card.dart';
import 'package:axis/ui/habits/widgets/habit_category_card.dart';
import 'package:axis/ui/habits/widgets/prayer_times_card.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/common/category_filter_slider.dart';
import 'package:axis/ui/common/cyber_search_bar.dart';

export 'package:axis/ui/habits/widgets/habit_continuity_card.dart';
export 'package:axis/ui/habits/widgets/habit_category_card.dart';
export 'package:axis/ui/habits/widgets/prayer_times_card.dart';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  final _repo = HabitRepository();
  late final Stream<List<StreakLog>> _habitLogsStream;
  late final Stream<List<HabitCategory>> _habitCategoriesStream;
  late final Stream<List<Habit>> _habitsStream;
  late final Stream<List<Prayer>> _prayersStream;
  static final Set<String> _locallyDeletedCategories = {};
  List<HabitCategory> _latestCategories = [];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryId = 'all';

  void _onCategoryAdded() {
    final added = HabitCategoryRepository.categoryAddedNotifier.value;
    if (added != null && added.isNotEmpty) {
      setState(() {
        _locallyDeletedCategories.remove(added.toLowerCase().trim());
        _locallyDeletedCategories.remove('discovered_${added.toLowerCase().trim()}');
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _habitLogsStream = _repo.watchStreakLogs();
    _habitCategoriesStream = HabitCategoryRepository().watchCategories();
    _habitsStream = _repo.watchHabits();
    _prayersStream = PrayerTimeService().watchPrayers();
    HabitCategoryRepository.categoryAddedNotifier.addListener(_onCategoryAdded);
  }

  @override
  void dispose() {
    HabitCategoryRepository.categoryAddedNotifier.removeListener(_onCategoryAdded);
    _searchController.dispose();
    super.dispose();
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

  void _openCreateHabit({String? initialCategory, List<HabitCategory>? existingCategories}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateHabitSheet(
        initialCategory: initialCategory,
        existingCategories: existingCategories ?? _latestCategories,
        onHabitCreated: () => setState(() {}),
      ),
    );
  }

  Widget _buildEmptySearchState({
    required String query,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AxisColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 32, color: AxisColors.success),
            ),
            const SizedBox(height: 14),
            Text(
              'No habits found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try checking your spelling or search with a different keyword.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AxisColors.success.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.close_rounded,
                  size: 14, color: AxisColors.success),
              label: const Text(
                'Clear Search',
                style: TextStyle(
                  color: AxisColors.success,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
          StreamBuilder<List<StreakLog>>(
            stream: _habitLogsStream,
            builder: (context, snapshot) {
              final streakLogs = snapshot.data ?? [];

              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);
              final currentStreak =
                  StreakEngine.calculateStreak('daily', streakLogs, todayStr);

              // Calculate best streak historically
              final doneDates = streakLogs
                  .where((r) => r.status == 'done')
                  .map((r) => r.date)
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

          const SizedBox(height: 16),

          // DEDICATED ISLAMIC PRAYERS CARD (Fixed 5 prayers from dedicated table)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: StreamBuilder<List<Prayer>>(
              stream: _prayersStream,
              builder: (context, prayerSnapshot) {
                final prayers = (prayerSnapshot.data != null && prayerSnapshot.data!.isNotEmpty)
                    ? prayerSnapshot.data!
                    : PrayerTimeService.defaultPrayers();
                return PrayerTimesCard(
                  prayers: prayers,
                  onTogglePrayer: (prayer, done) =>
                      PrayerTimeService().togglePrayer(prayer.id, done),
                  onResetPrayers: () =>
                      PrayerTimeService().resetPrayers(),
                  onRefreshLocation: () =>
                      PrayerTimeService().syncPrayers(forceLocation: true),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

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
          StreamBuilder<List<HabitCategory>>(
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

                  final customCategories = catSnapshot.data ?? [];
                  final allHabits = habitSnapshot.data ?? [];

                  // Discovered categories from habits' category if not in DB
                  final categoryNames = <String>{};
                  for (final c in customCategories) {
                    categoryNames.add(c.name.toLowerCase());
                  }

                  final discoveredCategories = <HabitCategory>[];
                  for (final h in allHabits) {
                    final catTrimmed = h.category.trim();
                    final catLower = catTrimmed.toLowerCase();
                    if (catTrimmed.isNotEmpty &&
                        catLower != 'general routines' &&
                        catLower != 'prayers' &&
                        catLower != 'workout' &&
                        catLower != 'reading' &&
                        catLower != 'mindful' &&
                        catLower != 'hydrate' &&
                        catLower != 'code' &&
                        catLower != 'rest' &&
                        !categoryNames.contains(catLower)) {
                      categoryNames.add(catLower);
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
                    return idLower != 'cat_prayers' &&
                        nameLower != 'prayers' &&
                        idLower != 'cat_workout' &&
                        nameLower != 'workout' &&
                        idLower != 'cat_reading' &&
                        nameLower != 'reading' &&
                        idLower != 'cat_mindful' &&
                        nameLower != 'mindful' &&
                        idLower != 'cat_hydrate' &&
                        nameLower != 'hydrate' &&
                        idLower != 'cat_code' &&
                        nameLower != 'code' &&
                        idLower != 'cat_rest' &&
                        nameLower != 'rest' &&
                        idLower != 'general_routines' &&
                        nameLower != 'general routines' &&
                        !_locallyDeletedCategories.contains(idLower) &&
                        !_locallyDeletedCategories.contains(nameLower) &&
                        !_locallyDeletedCategories
                            .contains(idLower.replaceFirst('discovered_', ''));
                  }).toList();

                  // Sort categories alphabetically
                  allCategories.sort((a, b) => a.name.compareTo(b.name));
                  _latestCategories = allCategories;

                  // Separate habits by category
                  final Map<String, List<Habit>> habitsByCategory = {};
                  final unassignedHabits = <Habit>[];

                  for (final h in allHabits) {
                    final catTrimmed = h.category.trim();
                    if (catTrimmed.toLowerCase() == 'prayers') {
                      continue;
                    }

                    final matchedCat = catTrimmed.isNotEmpty
                        ? allCategories.firstWhere(
                            (c) =>
                                c.id == catTrimmed ||
                                c.name.toLowerCase() == catTrimmed.toLowerCase(),
                            orElse: () => const HabitCategory(id: '', name: ''),
                          )
                        : const HabitCategory(id: '', name: '');

                    if (matchedCat.name.isNotEmpty) {
                      habitsByCategory
                          .putIfAbsent(matchedCat.name, () => [])
                          .add(h);
                    } else {
                      unassignedHabits.add(h);
                    }
                  }

                  // Sort habits in each category chronologically by time
                  for (final list in habitsByCategory.values) {
                    list.sort(HabitRepository.compareByTime);
                  }
                  unassignedHabits.sort(HabitRepository.compareByTime);

                  // Build horizontal category filter slider items
                  final sliderItems = <CategorySliderItem>[
                    CategorySliderItem(
                      id: 'all',
                      label: 'All Habits',
                      iconData: Icons.apps_rounded,
                      color: AxisColors.success,
                      count: allHabits.where((h) => h.category.trim().toLowerCase() != 'prayers').length,
                    ),
                    ...allCategories.map((category) {
                      final habits = habitsByCategory[category.name] ?? [];
                      return CategorySliderItem(
                        id: category.id,
                        label: category.name,
                        icon: category.icon,
                        color: _parseHex(category.color),
                        count: habits.length,
                      );
                    }),
                    if (unassignedHabits.isNotEmpty)
                      CategorySliderItem(
                        id: 'general_routines',
                        label: 'General Routines',
                        iconData: Icons.fitness_center_rounded,
                        color: const Color(0xFF64748B),
                        count: unassignedHabits.length,
                      ),
                  ];

                  // Filter categories based on slider selection and search query
                  final displayedCategories = allCategories.where((category) {
                    if (_selectedCategoryId != 'all') {
                      final matches = category.id.toLowerCase() == _selectedCategoryId.toLowerCase() ||
                          category.name.toLowerCase() == _selectedCategoryId.toLowerCase();
                      if (!matches) return false;
                    }

                    if (_searchQuery.isNotEmpty) {
                      final habits = habitsByCategory[category.name] ?? [];
                      final hasMatchingHabit = habits.any((h) =>
                          h.name.toLowerCase().contains(_searchQuery));
                      final matchesCategory = category.name.toLowerCase().contains(_searchQuery);
                      return hasMatchingHabit || matchesCategory;
                    }

                    return true;
                  }).toList();

                  final showUnassignedCategory = (_selectedCategoryId == 'all' ||
                          _selectedCategoryId.toLowerCase() == 'general_routines') &&
                      unassignedHabits.isNotEmpty;

                  final displayedUnassignedHabits = showUnassignedCategory
                      ? (_searchQuery.isEmpty
                          ? unassignedHabits
                          : unassignedHabits
                              .where((h) => h.name.toLowerCase().contains(_searchQuery))
                              .toList())
                      : <Habit>[];

                  // Count total matching habits across displayed categories
                  int totalMatchingHabits = displayedUnassignedHabits.length;
                  for (final cat in displayedCategories) {
                    final raw = habitsByCategory[cat.name] ?? [];
                    final filtered = (_searchQuery.isEmpty || cat.name.toLowerCase().contains(_searchQuery))
                        ? raw
                        : raw.where((h) => h.name.toLowerCase().contains(_searchQuery)).toList();
                    totalMatchingHabits += filtered.length;
                  }

                  final isSearching = _searchQuery.isNotEmpty;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search bar for habits
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: CyberSearchBar(
                          controller: _searchController,
                          hintText: 'Search habits or categories...',
                          accentColor: AxisColors.success,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val.trim().toLowerCase();
                            });
                          },
                          onClear: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Horizontal category filter slider
                      if (sliderItems.length > 1) ...[
                        CategoryFilterSlider(
                          items: sliderItems,
                          selectedId: _selectedCategoryId,
                          onSelected: (id) {
                            setState(() {
                              if (_selectedCategoryId == id && id != 'all') {
                                _selectedCategoryId = 'all';
                              } else {
                                _selectedCategoryId = id;
                              }
                            });
                          },
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Empty search results state
                      if (isSearching && totalMatchingHabits == 0)
                        _buildEmptySearchState(
                          query: _searchController.text.trim(),
                          onClear: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      // No habit categories created state
                      else if (!isSearching && allCategories.isEmpty && unassignedHabits.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.category_outlined, size: 36, color: AxisColors.textDim),
                                SizedBox(height: 12),
                                Text(
                                  'No Habit Categories Yet',
                                  style: TextStyle(
                                    color: AxisColors.textHigh,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Tap "+ Add Habit" above to create your first habit or custom category.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AxisColors.textDim,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      // Render filtered category cards
                      else ...[
                        ...displayedCategories.map((category) {
                          final rawHabits = habitsByCategory[category.name] ?? [];
                          final habits = (!isSearching || category.name.toLowerCase().contains(_searchQuery))
                              ? rawHabits
                              : rawHabits.where((h) => h.name.toLowerCase().contains(_searchQuery)).toList();
                          final color = _parseHex(category.color);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: HabitCategoryCard(
                              category: category,
                              color: color,
                              habits: habits,
                              forceExpand: isSearching,
                              onToggleHabit: (habit, done) =>
                                  _repo.toggleHabit(habit.id, done),
                              onEditHabit: (habit) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => CreateHabitSheet(
                                    habitToEdit: habit,
                                    existingCategories: allCategories,
                                    onHabitCreated: () => setState(() {}),
                                  ),
                                );
                              },
                              onDeleteHabit: (habit) =>
                                  _repo.deleteHabit(habit.id),
                              onAddHabit: () => _openCreateHabit(
                                  initialCategory: category.name,
                                  existingCategories: allCategories),
                              onDeleteCategory: () async {
                                setState(() {
                                  if (_selectedCategoryId == category.id ||
                                      _selectedCategoryId.toLowerCase() == category.name.toLowerCase()) {
                                    _selectedCategoryId = 'all';
                                  }
                                  _locallyDeletedCategories
                                      .add(category.id.toLowerCase());
                                  _locallyDeletedCategories
                                      .add(category.name.toLowerCase());
                                  final raw = category.id
                                      .toLowerCase()
                                      .replaceFirst('discovered_', '');
                                  _locallyDeletedCategories.add(raw);
                                });

                                await HabitCategoryRepository().deleteCategory(
                                  category.id,
                                  name: category.name,
                                );
                              },
                            ),
                          );
                        }),

                        // Unassigned / General Routines section if any
                        if (displayedUnassignedHabits.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: HabitCategoryCard(
                              category: const HabitCategory(
                                id: 'general_routines',
                                name: 'General Routines',
                                icon: 'fitness',
                                color: '#64748B',
                              ),
                              color: const Color(0xFF64748B),
                              habits: displayedUnassignedHabits,
                              forceExpand: isSearching,
                              onToggleHabit: (habit, done) =>
                                  _repo.toggleHabit(habit.id, done),
                              onEditHabit: (habit) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => CreateHabitSheet(
                                    habitToEdit: habit,
                                    existingCategories: allCategories,
                                    onHabitCreated: () => setState(() {}),
                                  ),
                                );
                              },
                              onDeleteHabit: (habit) =>
                                  _repo.deleteHabit(habit.id),
                              onAddHabit: () => _openCreateHabit(
                                  initialCategory: 'General Routines',
                                  existingCategories: allCategories),
                            ),
                          ),
                        ],
                      ],
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
