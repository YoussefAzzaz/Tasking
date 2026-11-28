import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/habit_repository.dart';
import '../../../../data/prayer_time_service.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/progress_gauge.dart';

/// Top metric cards row: Today's Prayers, Habit Streak, Daily XP, and Next Prayer.
class PrayerHabitsStatsRow extends StatelessWidget {
  const PrayerHabitsStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
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
              if (!h.isEnabled) return false;
              final schedule = h.scheduleType.toLowerCase().trim();
              return schedule == 'daily' || schedule.isEmpty;
            }).toList();
            final maxStreak = habits.where((h) => h.isEnabled).fold<int>(0, (max, h) => h.streakDays > max ? h.streakDays : max);
            final doneDailyHabits = dailyHabits.where((h) => h.isDoneToday).length;

            final isArabic = AppLocalizations.of(context).isArabic;

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
                            isArabic ? 'صلوات اليوم' : "TODAY'S PRAYERS",
                            style: AxisFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AxisColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isArabic ? '$donePrayers / $totalPrayers مكتملة' : '$donePrayers / $totalPrayers Done',
                            style: AxisFonts.spaceGrotesk(
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
                            isArabic
                                ? '${totalPrayers > 0 ? ((donePrayers / totalPrayers) * 100).toInt() : 0}٪ مكتملة اليوم'
                                : '${totalPrayers > 0 ? ((donePrayers / totalPrayers) * 100).toInt() : 0}% completed today',
                            style: AxisFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
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
                            isArabic ? 'تتابع العادات' : 'HABIT STREAK',
                            style: AxisFonts.spaceGrotesk(
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
                                isArabic ? '$maxStreak أيام' : '$maxStreak Days',
                                style: AxisFonts.spaceGrotesk(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isArabic
                                ? '$doneDailyHabits من ${dailyHabits.length} عادات مكتملة اليوم'
                                : '$doneDailyHabits of ${dailyHabits.length} habits completed today',
                            style: AxisFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
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
                            isArabic ? 'نقاط الخبرة اليومية' : 'DAILY XP',
                            style: AxisFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AxisColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isArabic
                                ? '+${doneDailyHabits * 25 + donePrayers * 30} نقطة خبرة'
                                : '+${doneDailyHabits * 25 + donePrayers * 30} XP',
                            style: AxisFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.primarySoft,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isArabic ? 'من إنجاز العادات والصلوات' : 'From habits and prayer completion',
                            style: AxisFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
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
                            isArabic ? 'الصلاة القادمة' : 'NEXT PRAYER',
                            style: AxisFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AxisColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nextPrayer != null
                                ? '${AppLocalizations.of(context).prayerName(nextPrayer.name)} ${nextPrayer.time}'
                                : (isArabic ? 'مكتملة' : 'Completed'),
                            style: AxisFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.tertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextPrayer != null
                                ? (isArabic ? 'الموعد القادم' : 'Upcoming window')
                                : (isArabic ? 'تمت جميع الفرائض' : 'All obligations fulfilled'),
                            style: AxisFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
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
}

