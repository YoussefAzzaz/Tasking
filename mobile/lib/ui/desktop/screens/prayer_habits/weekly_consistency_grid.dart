import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/habit_repository.dart';
import '../../../../data/prayer_time_service.dart';
import '../../widgets/telemetry_chip.dart';

/// 7-day adherence grid combining habit completions and prayer fulfillments.
class WeeklyConsistencyGrid extends StatelessWidget {
  const WeeklyConsistencyGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final isArabic = AppLocalizations.of(context).isArabic;
    final weekDayLetters = isArabic
        ? ['إ', 'ث', 'أ', 'خ', 'ج', 'س', 'ح']
        : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

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
                final doneHabitsToday = habits.where((h) => h.isEnabled && h.isDoneToday).length;

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
                            isArabic ? 'تناسق هذا الأسبوع' : 'THIS WEEK CONSISTENCY',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AxisColors.textMuted,
                            ),
                          ),
                          TelemetryChip(
                            label: isArabic ? '$adherencePct٪ الالتزام' : '$adherencePct% Adherence',
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
                                isToday ? (isArabic ? 'اليوم' : 'Today') : weekDayLetters[i],
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
}

