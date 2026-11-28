import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/focus_repository.dart';
import '../../../../data/habit_repository.dart';
import '../../../../data/prayer_time_service.dart';
import '../../../../data/task_repository.dart';
import '../../widgets/desktop_card.dart';

/// Top stats metrics row displaying Daily Tasks, Habit Streak, Focus Time, and Next Prayer.
class CommandDeckStatsRow extends StatelessWidget {
  const CommandDeckStatsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, taskSnapshot) {
        final tasks = taskSnapshot.data ?? [];
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayTasks = tasks.where((t) => t.dueDate == todayStr).toList();
        final completedTasks = todayTasks.where((t) => t.isCompleted).length;
        final totalTasks = todayTasks.isNotEmpty ? todayTasks.length : tasks.length;
        final completedCount = todayTasks.isNotEmpty ? completedTasks : tasks.where((t) => t.isCompleted).length;

        return StreamBuilder<List<Habit>>(
          stream: HabitRepository().watchHabits(),
          builder: (context, habitSnapshot) {
            final habits = habitSnapshot.data ?? [];
            final maxStreak = habits.fold<int>(0, (prev, h) => h.streakDays > prev ? h.streakDays : prev);

            return StreamBuilder<List<Prayer>>(
              stream: PrayerTimeService().watchPrayers(),
              builder: (context, prayerSnapshot) {
                final prayers = prayerSnapshot.data ?? [];
                final nextPrayer = prayers.where((p) => !p.isDone).firstOrNull;
                final isArabic = AppLocalizations.of(context).isArabic;

                return Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: isArabic ? 'المهام اليومية' : 'DAILY TASKS',
                        value: '$completedCount / $totalTasks',
                        caption: isArabic ? 'الهدف المنجز' : 'Tasks target',
                        icon: Icons.check_circle_outline_rounded,
                        accentColor: AxisColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: isArabic ? 'تتابع العادات' : 'HABIT STREAK',
                        value: isArabic ? '$maxStreak أيام' : '$maxStreak Days',
                        caption: isArabic ? 'أفضل التزام' : 'Best adherence',
                        icon: Icons.local_fire_department_rounded,
                        accentColor: AxisColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: FocusRepository().watchTodayFocusMinutes(),
                        builder: (context, focusSnap) {
                          final totalMin = focusSnap.data ?? 0;
                          final hours = totalMin ~/ 60;
                          final mins = totalMin % 60;
                          final formatted = isArabic
                              ? (hours > 0 && mins > 0
                                  ? '$hoursس $minsد'
                                  : (hours > 0 ? '$hoursس' : '$minsد'))
                              : (hours > 0 && mins > 0
                                  ? '${hours}h ${mins}m'
                                  : (hours > 0 ? '${hours}h' : '${mins}m'));

                          return _MetricCard(
                            title: isArabic ? 'التركيز اليوم' : 'FOCUS TODAY',
                            value: formatted,
                            caption: totalMin > 0
                                ? (isArabic ? 'جلسات العمل العميق' : 'Deep work sprints')
                                : (isArabic ? 'لم تسجل جلسات بعد' : 'No focus sprints yet'),
                            icon: Icons.bolt_rounded,
                            accentColor: AxisColors.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: isArabic ? 'الصلاة القادمة' : 'NEXT PRAYER',
                        value: nextPrayer != null
                            ? '${AppLocalizations.of(context).prayerName(nextPrayer.name)} ${nextPrayer.time}'
                            : (isArabic ? 'تمت جميعاً' : 'All Done'),
                        caption: nextPrayer != null
                            ? (isArabic ? 'الموعد المجدول' : 'Obligation scheduled')
                            : (isArabic ? 'تمت جميع الفرائض' : 'All obligations met'),
                        icon: Icons.schedule_rounded,
                        accentColor: AxisColors.tertiary,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.accentColor,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DesktopCard(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AxisFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AxisColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AxisFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AxisColors.textHigh,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
          ),
        ],
      ),
    );
  }
}
