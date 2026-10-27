import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/habit_category_repository.dart';
import '../../../data/habit_repository.dart';
import '../../../data/location_service.dart';
import '../../../data/prayer_time_service.dart';
import '../../../domain/id_generator.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_checkbox.dart';
import '../widgets/desktop_selection_chip.dart';
import '../widgets/progress_gauge.dart';
import '../widgets/section_header.dart';
import '../widgets/telemetry_chip.dart';

/// Prayer & Habits Telemetry Screen (Tab 1).
class PrayerHabitsScreen extends StatefulWidget {
  const PrayerHabitsScreen({super.key});

  @override
  State<PrayerHabitsScreen> createState() => _PrayerHabitsScreenState();
}

class _PrayerHabitsScreenState extends State<PrayerHabitsScreen> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  String _selectedCategory = 'All Habits';

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _showCreateHabitDialog() {
    final titleController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AxisColors.borderGlass2, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create New Habit',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: titleController,
                autofocus: true,
                style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
                decoration: InputDecoration(
                  hintText: 'e.g. 20m Morning Reading',
                  hintStyle: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                  filled: true,
                  fillColor: AxisColors.surfaceLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AccentButton(
                    label: 'Create Habit',
                    onPressed: () async {
                      final name = titleController.text.trim();
                      if (name.isNotEmpty) {
                        final newHabit = Habit(
                          id: IdGenerator.generateDeterministicId('habit_${DateTime.now().microsecondsSinceEpoch}'),
                          name: name,
                          category: _selectedCategory == 'All Habits' ? 'General' : _selectedCategory,
                          color: '#6366F1',
                          createdAt: DateTime.now().toIso8601String(),
                        );
                        await HabitRepository().addHabit(newHabit);
                      }
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3.2 Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prayer & Habits',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AxisColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track daily prayer times and personal habit consistency',
                    style: GoogleFonts.getFont(
                      'Geist',
                      fontSize: 13,
                      color: AxisColors.textMuted,
                    ),
                  ),
                ],
              ),
              Text(
                timeStr,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),
            ],
          ),

          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 3.3 Top 4 Stats Row
          _buildTopStatsRow(),

          const SizedBox(height: DesktopLayout.sectionSpacing),

          // Main 2-Column Split
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildDailyPrayersCard(),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                flex: 5,
                child: _buildDailyHabitsCard(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatsRow() {
    return StreamBuilder<List<Prayer>>(
      stream: PrayerTimeService().watchPrayers(),
      builder: (context, prayerSnap) {
        final prayers = prayerSnap.data ?? [];
        final donePrayers = prayers.where((p) => p.isDone).length;
        final totalPrayers = prayers.isNotEmpty ? prayers.length : 5;
        final nextPrayer = prayers.where((p) => !p.isDone).firstOrNull;

        return StreamBuilder<List<Habit>>(
          stream: HabitRepository().watchHabits(),
          builder: (context, habitSnap) {
            final habits = habitSnap.data ?? [];
            final maxStreak = habits.fold<int>(0, (max, h) => h.streakDays > max ? h.streakDays : max);
            final doneHabits = habits.where((h) => h.isDoneToday).length;

            return Row(
              children: [
                Expanded(
                  child: DesktopCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TODAY'S PRAYERS",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AxisColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$donePrayers / $totalPrayers Done',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ProgressGauge(
                          value: (donePrayers / totalPrayers).clamp(0.0, 1.0),
                          height: 4.0,
                          color: AxisColors.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DesktopCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HABIT STREAK',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AxisColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 18, color: AxisColors.warning),
                            const SizedBox(width: 4),
                            Text(
                              '$maxStreak Days',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$doneHabits of ${habits.length} habits completed today',
                          style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DesktopCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DAILY XP',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AxisColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '+${doneHabits * 25 + donePrayers * 30} XP',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.primarySoft,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'From habits and prayer completion',
                          style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DesktopCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NEXT PRAYER',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AxisColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nextPrayer != null ? '${nextPrayer.name} ${nextPrayer.time}' : 'Completed',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.tertiary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          nextPrayer != null ? 'Upcoming window' : 'All obligations fulfilled',
                          style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _resolveLocationLabel() {
    final prayerService = PrayerTimeService();
    if (prayerService.currentCity.isNotEmpty && prayerService.currentCity != 'Auto') {
      if (prayerService.currentCountry.isNotEmpty) {
        return '${prayerService.currentCity}, ${prayerService.currentCountry}';
      }
      return prayerService.currentCity;
    }
    final cached = LocationService().cachedLocation;
    if (cached != null && cached.city.isNotEmpty) {
      if (cached.country.isNotEmpty) {
        return '${cached.city}, ${cached.country}';
      }
      return cached.city;
    }
    return 'Local Station';
  }

  Widget _buildDailyPrayersCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Daily Prayers',
            trailing: TelemetryChip(
              label: _resolveLocationLabel(),
              icon: Icons.location_on_rounded,
              color: AxisColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Prayer>>(
            stream: PrayerTimeService().watchPrayers(),
            builder: (context, snapshot) {
              final prayers = snapshot.data ?? [];
              return Column(
                children: prayers.map((p) => _buildPrayerRow(p)).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          // 3.4 Bottom Weekly Grid
          _buildWeeklyConsistencyGrid(),
        ],
      ),
    );
  }

  Widget _buildPrayerRow(Prayer prayer) {
    final arabicSubtitle = switch (prayer.prayerCode.toLowerCase()) {
      'fajr' => 'الفجر · Dawn',
      'dhuhr' => 'الظهر · Noon',
      'asr' => 'العصر · Afternoon',
      'maghrib' => 'المغرب · Sunset',
      'isha' => 'العشاء · Night',
      _ => 'الصلاة',
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: prayer.isDone ? AxisColors.surfaceLowest : AxisColors.surfaceHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: prayer.isDone ? AxisColors.borderEmerald : AxisColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          DesktopCheckbox(
            value: prayer.isDone,
            color: AxisColors.tertiary,
            onChanged: (val) {
              PrayerTimeService().togglePrayer(prayer.id, val);
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.name,
                  style: GoogleFonts.getFont(
                    'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: prayer.isDone ? AxisColors.textDim : AxisColors.textHigh,
                  ),
                ),
                Text(
                  arabicSubtitle,
                  style: GoogleFonts.getFont(
                    'Geist',
                    fontSize: 11,
                    color: AxisColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          Text(
            prayer.time,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AxisColors.textHigh,
            ),
          ),
          const SizedBox(width: 10),
          TelemetryChip(
            label: prayer.isDone ? 'Completed' : 'Scheduled',
            color: prayer.isDone ? AxisColors.tertiary : AxisColors.textDim,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyConsistencyGrid() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'Today'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AxisColors.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'THIS WEEK CONSISTENCY',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AxisColors.textMuted,
                ),
              ),
              const TelemetryChip(
                label: '95% Adherence',
                color: AxisColors.tertiary,
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) {
              final isToday = d == 'Today';
              return Column(
                children: [
                  Text(
                    d,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday ? AxisColors.secondary : AxisColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AxisColors.secondary.withValues(alpha: 0.2)
                          : AxisColors.tertiary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday ? AxisColors.secondary : AxisColors.tertiary,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check_rounded,
                        size: 13,
                        color: isToday ? AxisColors.secondary : AxisColors.tertiary,
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyHabitsCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Daily Habits',
            trailing: AccentButton(
              label: '+ New Habit',
              height: 30,
              icon: Icons.add_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: _showCreateHabitDialog,
            ),
          ),
          const SizedBox(height: 6),
          // Category tabs
          StreamBuilder<List<HabitCategory>>(
            stream: HabitCategoryRepository().watchCategories(),
            builder: (context, catSnap) {
              final categories = catSnap.data ?? [];
              final categoryNames = ['All Habits', ...categories.map((c) => c.name)];

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: categoryNames.map((cat) {
                    final isSel = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: DesktopSelectionChip(
                        label: cat,
                        selected: isSel,
                        onTap: () => setState(() => _selectedCategory = cat),
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          // Habit rows
          StreamBuilder<List<Habit>>(
            stream: HabitRepository().watchHabits(),
            builder: (context, snapshot) {
              final allHabits = snapshot.data ?? [];
              final habits = _selectedCategory == 'All Habits'
                  ? allHabits
                  : allHabits.where((h) => h.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

              if (habits.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No habits in this category. Click + New Habit to create one.',
                      style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return Column(
                children: habits.map((h) => _buildHabitRow(h)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow(Habit habit) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AxisColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          DesktopCheckbox(
            value: habit.isDoneToday,
            color: AxisColors.warning,
            onChanged: (val) {
              HabitRepository().toggleHabit(habit.id, val);
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.name,
                  style: GoogleFonts.getFont(
                    'Geist',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: habit.isDoneToday ? TextDecoration.lineThrough : null,
                    color: habit.isDoneToday ? AxisColors.textDim : AxisColors.textHigh,
                  ),
                ),
                Text(
                  'Daily  ·  ${habit.category.isNotEmpty ? habit.category : "General"}',
                  style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 14, color: AxisColors.warning),
              const SizedBox(width: 2),
              Text(
                '${habit.streakDays}d streak',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AxisColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          TelemetryChip(
            label: habit.isDoneToday ? 'Done' : 'Scheduled',
            color: habit.isDoneToday ? AxisColors.tertiary : AxisColors.textDim,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          ),
        ],
      ),
    );
  }
}
