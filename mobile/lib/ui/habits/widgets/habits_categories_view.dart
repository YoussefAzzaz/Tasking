import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/habit_category_repository.dart';
import '../../../../data/habit_repository.dart';
import '../../common/category_filter_slider.dart';
import '../../common/cyber_search_bar.dart';
import '../create_habit_sheet.dart';
import 'habit_category_card.dart';
import 'habits_empty_state.dart';

Color parseCategoryHex(String? hex) {
  if (hex == null || hex.isEmpty) return AxisColors.success;
  try {
    final clean = hex.replaceAll('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  } catch (_) {
    return AxisColors.success;
  }
}

/// Dynamic habit category list with real-time stream updates, category filter slider,
/// search bar filtering, and inline category creation/deletion.
class HabitCategoriesView extends StatefulWidget {
  const HabitCategoriesView({
    super.key,
    required this.repo,
    required this.habitCategoriesStream,
    required this.habitsStream,
    required this.onCategoriesUpdated,
    required this.onOpenCreateHabit,
  });

  final HabitRepository repo;
  final Stream<List<HabitCategory>> habitCategoriesStream;
  final Stream<List<Habit>> habitsStream;
  final ValueChanged<List<HabitCategory>> onCategoriesUpdated;
  final void Function({String? initialCategory, List<HabitCategory>? existingCategories}) onOpenCreateHabit;

  @override
  State<HabitCategoriesView> createState() => _HabitCategoriesViewState();
}

class _HabitCategoriesViewState extends State<HabitCategoriesView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategoryId = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<HabitCategory>>(
      stream: widget.habitCategoriesStream,
      builder: (context, catSnapshot) {
        return StreamBuilder<List<Habit>>(
          stream: widget.habitsStream,
          builder: (context, habitSnapshot) {
            if (catSnapshot.connectionState == ConnectionState.waiting &&
                habitSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child:
                      CircularProgressIndicator(color: AxisColors.success),
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
                  HabitCategoryRepository.reconciledCategory(
                    catTrimmed,
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
                  nameLower != 'general routines';
            }).toList();

            // Sort categories alphabetically
            allCategories.sort((a, b) => a.name.compareTo(b.name));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.onCategoriesUpdated(allCategories);
            });

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
                label: context.isArabic ? 'كل العادات' : 'All Habits',
                iconData: Icons.apps_rounded,
                color: AxisColors.success,
                count: allHabits
                    .where((h) =>
                        h.category.trim().toLowerCase() != 'prayers' &&
                        h.isEnabled)
                    .length,
              ),
              ...allCategories.map((category) {
                final habits = habitsByCategory[category.name] ?? [];
                return CategorySliderItem(
                  id: category.id,
                  label: context.l10n.localizedHabitCategory(category.name),
                  icon: category.icon,
                  color: parseCategoryHex(category.color),
                  count: habits.where((h) => h.isEnabled).length,
                );
              }),
              if (unassignedHabits.isNotEmpty)
                CategorySliderItem(
                  id: 'general_routines',
                  label: context.isArabic ? 'روتين عام' : 'General Routines',
                  iconData: Icons.fitness_center_rounded,
                  color: const Color(0xFF64748B),
                  count: unassignedHabits.where((h) => h.isEnabled).length,
                ),
            ];

            // Filter categories based on slider selection and search query
            final displayedCategories = allCategories.where((category) {
              if (_selectedCategoryId != 'all') {
                final matches = category.id.toLowerCase() ==
                        _selectedCategoryId.toLowerCase() ||
                    category.name.toLowerCase() ==
                        _selectedCategoryId.toLowerCase();
                if (!matches) return false;
              }

              if (_searchQuery.isNotEmpty) {
                final habits = habitsByCategory[category.name] ?? [];
                final hasMatchingHabit = habits.any((h) =>
                    h.name.toLowerCase().contains(_searchQuery));
                final matchesCategory =
                    category.name.toLowerCase().contains(_searchQuery);
                return hasMatchingHabit || matchesCategory;
              }

              return true;
            }).toList();

            final showUnassignedCategory = (_selectedCategoryId == 'all' ||
                    _selectedCategoryId.toLowerCase() ==
                        'general_routines') &&
                unassignedHabits.isNotEmpty;

            final displayedUnassignedHabits = showUnassignedCategory
                ? (_searchQuery.isEmpty
                    ? unassignedHabits
                    : unassignedHabits
                        .where((h) =>
                            h.name.toLowerCase().contains(_searchQuery))
                        .toList())
                : <Habit>[];

            // Count total matching habits across displayed categories
            int totalMatchingHabits = displayedUnassignedHabits.length;
            for (final cat in displayedCategories) {
              final raw = habitsByCategory[cat.name] ?? [];
              final filtered = (_searchQuery.isEmpty ||
                      cat.name.toLowerCase().contains(_searchQuery))
                  ? raw
                  : raw
                      .where(
                          (h) => h.name.toLowerCase().contains(_searchQuery))
                      .toList();
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
                    hintText: context.isArabic
                        ? 'البحث في العادات أو التصنيفات...'
                        : 'Search habits or categories...',
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
                  HabitSearchEmptyState(
                    query: _searchController.text.trim(),
                    onClear: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                // No habit categories created state
                else if (!isSearching &&
                    allCategories.isEmpty &&
                    unassignedHabits.isEmpty)
                  const HabitsNoCategoriesEmptyState()
                // Render filtered category cards
                else ...[
                  ...displayedCategories.map((category) {
                    final rawHabits =
                        habitsByCategory[category.name] ?? [];
                    final habits = (!isSearching ||
                            category.name
                                .toLowerCase()
                                .contains(_searchQuery))
                        ? rawHabits
                        : rawHabits
                            .where((h) => h.name
                                .toLowerCase()
                                .contains(_searchQuery))
                            .toList();
                    final color = parseCategoryHex(category.color);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: HabitCategoryCard(
                        key: ValueKey(category.id),
                        category: category,
                        color: color,
                        habits: habits,
                        forceExpand: isSearching,
                        onToggleHabit: (habit, done) =>
                            widget.repo.toggleHabit(habit.id, done),
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
                            widget.repo.deleteHabit(habit.id),
                        onAddHabit: () => widget.onOpenCreateHabit(
                            initialCategory: category.name,
                            existingCategories: allCategories),
                        onDeleteCategory: () async {
                          setState(() {
                            if (_selectedCategoryId == category.id ||
                                _selectedCategoryId.toLowerCase() ==
                                    category.name.toLowerCase()) {
                              _selectedCategoryId = 'all';
                            }
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
                        key: const ValueKey('general_routines'),
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
                            widget.repo.toggleHabit(habit.id, done),
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
                            widget.repo.deleteHabit(habit.id),
                        onAddHabit: () => widget.onOpenCreateHabit(
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
    );
  }
}
