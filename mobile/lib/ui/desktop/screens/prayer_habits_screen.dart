import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/adhan_alarm_service.dart';
import '../../../data/habit_category_repository.dart';
import '../../../data/habit_repository.dart';
import '../../../data/location_service.dart';
import '../../../data/prayer_time_service.dart';
import '../core/desktop_layout.dart';
import '../dialogs/quick_habit_dialog.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_checkbox.dart';
import '../widgets/desktop_horizontal_scroll.dart';
import '../widgets/ghost_button.dart';
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
  final ScrollController _habitsScrollController = ScrollController();

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
    _habitsScrollController.dispose();
    super.dispose();
  }

  void _showPrayerSettingsDialog() {
    final alarmService = AdhanAlarmService();
    final prayerService = PrayerTimeService();
    bool adhanEnabled = alarmService.adhanNotificationsEnabled;
    bool fajrAlarmEnabled = alarmService.fajrAlarmEnabled;
    bool isSyncing = false;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AxisColors.canvasBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AxisColors.borderGlass2, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 18, color: AxisColors.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'Prayer Telemetry & Alarms',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Qibla telemetry card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AxisColors.secondary.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(Icons.explore_rounded, size: 18, color: AxisColors.secondary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QIBLA BEARING',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AxisColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${prayerService.qiblaBearing.toStringAsFixed(1)}° Relative to North',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AxisColors.textHigh,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const TelemetryChip(
                          label: 'MECCA',
                          color: AxisColors.secondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Adhan Notifications Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Adhan Notifications',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textHigh,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Daily notification on every prayer window',
                              style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                            ),
                          ],
                        ),
                        Switch(
                          value: adhanEnabled,
                          activeThumbColor: AxisColors.secondary,
                          onChanged: (val) async {
                            setDialogState(() => adhanEnabled = val);
                            await alarmService.setAdhanNotificationsEnabled(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Smart Fajr Wake-Up Alarm Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Fajr Smart Wake-Up Alarm',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textHigh,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Persistent acoustic wake-up alert at dawn',
                              style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                            ),
                          ],
                        ),
                        Switch(
                          value: fajrAlarmEnabled,
                          activeThumbColor: AxisColors.warning,
                          onChanged: (val) async {
                            setDialogState(() => fajrAlarmEnabled = val);
                            await alarmService.setFajrAlarmEnabled(val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Refresh GPS Location and times
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Location: ${_resolveLocationLabel()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GhostButton(
                        label: isSyncing ? 'Syncing...' : 'Sync GPS',
                        icon: Icons.refresh_rounded,
                        onPressed: isSyncing
                            ? null
                            : () async {
                                setDialogState(() => isSyncing = true);
                                await prayerService.syncPrayers(forceLocation: true);
                                if (dialogCtx.mounted) {
                                  setDialogState(() => isSyncing = false);
                                  setState(() {});
                                }
                              },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateHabitDialog([Habit? habitToEdit]) {
    QuickHabitDialog.show(
      context,
      initialCategory: _selectedCategory == 'All Habits' ? null : _selectedCategory,
      habitToEdit: habitToEdit,
      onHabitCreated: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Padding(
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

              // Main 2-Column Split: Both cards stretch to same height matching page
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
              ),
            ],
          ),
        );

        if (!constraints.hasBoundedHeight || constraints.maxHeight < 640) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SizedBox(
              height: 640,
              child: content,
            ),
          );
        }

        return content;
      },
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
            final dailyHabits = habits.where((h) {
              final schedule = h.scheduleType.toLowerCase().trim();
              return schedule == 'daily' || schedule.isEmpty;
            }).toList();
            final maxStreak = habits.fold<int>(0, (max, h) => h.streakDays > max ? h.streakDays : max);
            final doneDailyHabits = dailyHabits.where((h) => h.isDoneToday).length;

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          const SizedBox(height: 4),
                          Text(
                            '${totalPrayers > 0 ? ((donePrayers / totalPrayers) * 100).toInt() : 0}% completed today',
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
                            '$doneDailyHabits of ${dailyHabits.length} habits completed today',
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
                            '+${doneDailyHabits * 25 + donePrayers * 30} XP',
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
              ),
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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TelemetryChip(
                  label: _resolveLocationLabel(),
                  icon: Icons.location_on_rounded,
                  color: AxisColors.secondary,
                ),
                const SizedBox(width: 8),
                GhostButton(
                  label: 'Settings',
                  icon: Icons.tune_rounded,
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: _showPrayerSettingsDialog,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: StreamBuilder<List<Prayer>>(
                stream: PrayerTimeService().watchPrayers(),
                builder: (context, snapshot) {
                  final prayers = snapshot.data ?? [];
                  return Column(
                    children: prayers.map((p) => _buildPrayerRow(p)).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
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
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return StreamBuilder<Set<String>>(
      stream: HabitRepository().watchWeekDoneDates(),
      builder: (context, logSnap) {
        final doneDates = logSnap.data ?? const <String>{};

        return StreamBuilder<List<Prayer>>(
          stream: PrayerTimeService().watchPrayers(),
          builder: (context, prayerSnap) {
            final prayers = prayerSnap.data ?? [];
            final donePrayers = prayers.where((p) => p.isDone).length;

            return StreamBuilder<List<Habit>>(
              stream: HabitRepository().watchHabits(),
              builder: (context, habitSnap) {
                final habits = habitSnap.data ?? [];
                final doneHabitsToday = habits.where((h) => h.isDoneToday).length;

                final isTodayActive = donePrayers > 0 || doneHabitsToday > 0;
                final currentWeekday = now.weekday; // 1 = Monday, 7 = Sunday

                int completedDaysCount = 0;
                for (int i = 0; i < currentWeekday; i++) {
                  final dayDate = monday.add(Duration(days: i));
                  final dStr = DateFormat('yyyy-MM-dd').format(dayDate);
                  if (i == currentWeekday - 1) {
                    if (isTodayActive) completedDaysCount++;
                  } else {
                    if (doneDates.contains(dStr)) completedDaysCount++;
                  }
                }

                final adherencePct = currentWeekday > 0
                    ? ((completedDaysCount / currentWeekday) * 100).toInt()
                    : 100;

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
                          TelemetryChip(
                            label: '$adherencePct% Adherence',
                            color: adherencePct >= 70 ? AxisColors.tertiary : AxisColors.warning,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(7, (i) {
                          final dayDate = monday.add(Duration(days: i));
                          final dStr = DateFormat('yyyy-MM-dd').format(dayDate);
                          final isToday = i == currentWeekday - 1;
                          final isPast = i < currentWeekday - 1;
                          final isFuture = i > currentWeekday - 1;

                          final bool isDone;
                          if (isToday) {
                            isDone = isTodayActive;
                          } else if (isPast) {
                            isDone = doneDates.contains(dStr);
                          } else {
                            isDone = false;
                          }

                          Color dotBg;
                          Color dotBorder;
                          Widget? iconWidget;

                          if (isToday) {
                            dotBg = isDone
                                ? AxisColors.secondary.withValues(alpha: 0.25)
                                : AxisColors.surfaceLowest;
                            dotBorder = AxisColors.secondary;
                            iconWidget = isDone
                                ? const Icon(Icons.check_rounded, size: 12, color: AxisColors.secondary)
                                : Container(width: 5, height: 5, decoration: const BoxDecoration(color: AxisColors.secondary, shape: BoxShape.circle));
                          } else if (isPast) {
                            dotBg = isDone
                                ? AxisColors.tertiary.withValues(alpha: 0.15)
                                : AxisColors.surfaceHighest.withValues(alpha: 0.3);
                            dotBorder = isDone ? AxisColors.tertiary : AxisColors.borderSubtle;
                            iconWidget = isDone
                                ? const Icon(Icons.check_rounded, size: 12, color: AxisColors.tertiary)
                                : const Icon(Icons.remove_rounded, size: 10, color: AxisColors.textDim);
                          } else {
                            dotBg = Colors.transparent;
                            dotBorder = AxisColors.borderSubtle.withValues(alpha: 0.5);
                            iconWidget = null;
                          }

                          return Column(
                            children: [
                              Text(
                                isToday ? 'Today' : weekDayLetters[i],
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                  color: isToday ? AxisColors.secondary : (isFuture ? AxisColors.textDim : AxisColors.textMuted),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: dotBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: dotBorder, width: 1),
                                ),
                                child: Center(child: iconWidget),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
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
              label: 'New Habit',
              height: 30,
              icon: Icons.add_rounded,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              onPressed: _showCreateHabitDialog,
            ),
          ),
          const SizedBox(height: 6),
          // Category tabs and Habit rows
          Expanded(
            child: StreamBuilder<List<HabitCategory>>(
              stream: HabitCategoryRepository().watchCategories(),
              builder: (context, catSnap) {
                final categories = catSnap.data ?? [];
                final categoryNames = ['All Habits', ...categories.map((c) => c.name)];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DesktopHorizontalScrollView(
                      child: Row(
                        children: categoryNames.map((cat) {
                          final isSel = _selectedCategory == cat;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6.0),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedCategory = cat),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSel ? AxisColors.primary.withValues(alpha: 0.25) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSel ? AxisColors.primary : AxisColors.borderSubtle,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  cat,
                                  style: GoogleFonts.getFont(
                                    'Geist',
                                    fontSize: 12,
                                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                                    color: isSel ? AxisColors.textHigh : AxisColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Habit rows - scrollable filling available card height
                    Expanded(
                      child: StreamBuilder<List<Habit>>(
                        stream: HabitRepository().watchHabits(),
                        builder: (context, snapshot) {
                          final allHabits = snapshot.data ?? [];
                          final habits = _selectedCategory == 'All Habits'
                              ? allHabits
                              : allHabits.where((h) => h.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

                          if (habits.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24.0),
                                child: Text(
                                  'No habits in this category. Click New Habit to create one.',
                                  style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                                ),
                              ),
                            );
                          }

                          return Scrollbar(
                            controller: _habitsScrollController,
                            thumbVisibility: true,
                            child: ListView.builder(
                              controller: _habitsScrollController,
                              padding: const EdgeInsets.only(right: 12.0),
                              itemCount: habits.length,
                              itemBuilder: (context, index) => _buildHabitRow(habits[index], categories),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitRow(Habit habit, [List<HabitCategory>? categories]) {
    final habitColor = HabitCategoryRepository().resolveHabitCategoryColor(habit, categories);

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
            color: habitColor,
            onChanged: (val) {
              HabitRepository().toggleHabit(habit.id, val);
            },
          ),
          const SizedBox(width: 10),
          Container(
            width: 3,
            height: 24,
            decoration: BoxDecoration(
              color: habitColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => _showCreateHabitDialog(habit),
              borderRadius: BorderRadius.circular(4),
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
                    '${habit.scheduleType.isNotEmpty ? habit.scheduleType : "Daily"}  ·  ${habit.category.isNotEmpty ? habit.category : "General"}',
                    style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ),
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
          const SizedBox(width: 8),
          TelemetryChip(
            label: habit.isDoneToday ? 'Done' : 'Scheduled',
            color: habit.isDoneToday ? AxisColors.tertiary : AxisColors.textDim,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          ),
          const SizedBox(width: 4),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _showCreateHabitDialog(habit),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.edit_outlined, size: 15, color: AxisColors.textDim),
              ),
            ),
          ),
          const SizedBox(width: 2),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: AxisColors.canvasBase,
                    title: Text('Delete Habit', style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh)),
                    content: Text('Are you sure you want to delete "${habit.name}"?', style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text('Cancel', style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete', style: TextStyle(color: AxisColors.priorityHigh)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await HabitRepository().deleteHabit(habit.id);
                }
              },
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.delete_outline_rounded, size: 15, color: AxisColors.textDim),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
