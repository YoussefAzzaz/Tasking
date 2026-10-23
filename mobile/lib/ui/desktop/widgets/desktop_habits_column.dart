import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';

/// Desktop Column 1: Prayer Cadence & Habit Engine.
class DesktopHabitsColumn extends StatefulWidget {
  const DesktopHabitsColumn({
    super.key,
    this.searchFilter = '',
  });

  final String searchFilter;

  @override
  State<DesktopHabitsColumn> createState() => _DesktopHabitsColumnState();
}

class _DesktopHabitsColumnState extends State<DesktopHabitsColumn> {
  final _prayerService = PrayerTimeService();
  final _habitRepo = HabitRepository();
  final _catRepo = HabitCategoryRepository();

  String _selectedCategory = 'ALL';
  bool _isResettingPrayers = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Prayer Telemetry Section
          _buildPrayerTelemetry(),

          const Divider(color: AxisColors.borderSubtle, height: 1),

          // 2. Active Habits Section Header & Filters
          _buildHabitsHeader(),

          // 3. Habits List
          Expanded(
            child: _buildHabitsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTelemetry() {
    return StreamBuilder<List<Prayer>>(
      stream: _prayerService.watchPrayers(),
      builder: (context, snapshot) {
        final prayers = snapshot.data ?? [];
        final total = prayers.length;
        final done = prayers.where((p) => p.isDone).length;
        final progress = total > 0 ? (done / total) : 0.0;

        // Find next prayer
        final nextPrayer = prayers.firstWhere(
          (p) => !p.isDone,
          orElse: () => prayers.isNotEmpty ? prayers.first : const Prayer(
            id: '',
            userId: '',
            prayerCode: 'fajr',
            name: 'Fajr',
            icon: 'fajr',
            time: '05:22',
            sortOrder: 1,
            isDone: false,
            createdAt: '',
            updatedAt: '',
          ),
        );

        return Container(
          padding: const EdgeInsets.all(14),
          color: const Color(0xFF090E1A),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.wb_twilight_rounded,
                          size: 14,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Prayer Telemetry',
                        style: TextStyle(
                          color: AxisColors.textHigh,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Reset button
                      IconButton(
                        icon: _isResettingPrayers
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 1.5, color: AxisColors.textDim),
                              )
                            : const Icon(Icons.restart_alt_rounded, size: 15, color: AxisColors.textDim),
                        tooltip: 'Reset Today Prayers',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: _isResettingPrayers
                            ? null
                            : () async {
                                setState(() => _isResettingPrayers = true);
                                await _prayerService.resetPrayers();
                                if (mounted) setState(() => _isResettingPrayers = false);
                              },
                      ),
                      // Refresh location
                      IconButton(
                        icon: const Icon(Icons.sync_rounded, size: 15, color: AxisColors.textDim),
                        tooltip: 'Refresh Prayer Times',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        onPressed: () async {
                          await _prayerService.syncPrayers(forceLocation: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Refreshed for ${_prayerService.currentCity}'),
                                backgroundColor: AxisColors.surfaceLow,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Location & Next Prayer Telemetry Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: AxisColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          _prayerService.currentCity,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AxisColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Next: ${nextPrayer.name}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: AxisColors.surfaceHighest,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),

              const SizedBox(height: 10),

              // 5 Prayer Rows
              if (prayers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Loading prayer times...', style: TextStyle(color: AxisColors.textDim, fontSize: 11)),
                  ),
                )
              else
                ...prayers.map((p) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: p.isDone ? const Color(0xFF10B981).withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: p.isDone
                            ? const Color(0xFF10B981).withValues(alpha: 0.25)
                            : AxisColors.borderSubtle.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _prayerService.togglePrayer(p.id, !p.isDone),
                          child: Icon(
                            p.isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                            size: 15,
                            color: p.isDone ? const Color(0xFF10B981) : AxisColors.textDim,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.isDone ? AxisColors.textHigh : AxisColors.textMuted,
                            ),
                          ),
                        ),
                        Text(
                          p.time,
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: AxisColors.textDim,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (p.isDone)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'DONE',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHabitsHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 14, color: AxisColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'Active Habits',
                    style: TextStyle(
                      color: AxisColors.textHigh,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              StreamBuilder<List<Habit>>(
                stream: _habitRepo.watchHabits(),
                builder: (context, snapshot) {
                  final habits = snapshot.data ?? [];
                  final completed = habits.where((h) => h.isDoneToday).length;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$completed/${habits.length} Done',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.primarySoft,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Horizontal Category Filter Slider
          StreamBuilder<List<HabitCategory>>(
            stream: _catRepo.watchCategories(),
            builder: (context, snapshot) {
              final cats = snapshot.data ?? [];
              final allCats = ['ALL', ...cats.map((c) => c.name.toUpperCase())];

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allCats.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AxisColors.primarySoft.withValues(alpha: 0.2)
                              : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isSelected
                                ? AxisColors.primarySoft
                                : AxisColors.borderSubtle,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? AxisColors.primarySoft : AxisColors.textMuted,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHabitsList() {
    return StreamBuilder<List<Habit>>(
      stream: _habitRepo.watchHabits(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        var habits = snapshot.data!;

        // Filter by category
        if (_selectedCategory != 'ALL') {
          habits = habits.where((h) => h.category.toUpperCase() == _selectedCategory).toList();
        }

        // Filter by search query
        if (widget.searchFilter.isNotEmpty) {
          final query = widget.searchFilter.toLowerCase();
          habits = habits.where((h) => h.name.toLowerCase().contains(query)).toList();
        }

        if (habits.isEmpty) {
          return const Center(
            child: Text(
              'No habits in this category',
              style: TextStyle(color: AxisColors.textDim, fontSize: 11),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          itemCount: habits.length,
          itemBuilder: (context, index) {
            final habit = habits[index];
            final isDone = habit.isDoneToday;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDone
                    ? const Color(0xFF10B981).withValues(alpha: 0.06)
                    : AxisColors.surfaceLow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDone
                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                      : AxisColors.borderSubtle,
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _habitRepo.toggleHabit(habit.id, !habit.isDoneToday),
                    child: Icon(
                      isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: isDone ? const Color(0xFF10B981) : AxisColors.textDim,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              '${habit.streakDays}d streak',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.warning,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('🔥', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 8),
                            if (habit.remindTime != null && habit.remindTime!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceHighest,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  habit.remindTime!,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AxisColors.textMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AxisColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '+${habit.targetValue} XP',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
