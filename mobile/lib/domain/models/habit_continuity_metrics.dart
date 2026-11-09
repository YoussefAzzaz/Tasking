import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/streak_engine.dart';
import '../../ui/habits/widgets/habit_continuity_card.dart';

/// Metrics payload for the habit continuity and weekly pulse hero card.
class HabitContinuityMetrics {
  final int currentStreak;
  final int bestStreak;
  final String multiplierStr;
  final int monthlyRate;
  final List<Widget> weekDayWidgets;

  const HabitContinuityMetrics({
    required this.currentStreak,
    required this.bestStreak,
    required this.multiplierStr,
    required this.monthlyRate,
    required this.weekDayWidgets,
  });
}

/// Calculator computing streak continuity, best streak, multiplier, and week day pill states.
class HabitContinuityCalculator {
  HabitContinuityCalculator._();

  static HabitContinuityMetrics calculate(List<StreakLog> streakLogs, {bool isArabic = false}) {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final currentStreak =
        StreakEngine.calculateStreak('daily', streakLogs, todayStr);

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
        if (d1 != null && d2 != null && d2.difference(d1).inDays == 1) {
          run++;
          if (run > maxRun) maxRun = run;
        } else if (d1 != null && d2 != null && d2.difference(d1).inDays > 1) {
          run = 1;
        }
      }
      if (maxRun > bestStreak) bestStreak = maxRun;
    }

    final multiplier = (1.0 + (currentStreak * 0.1)).clamp(1.0, 3.0);
    final multiplierStr = '${multiplier.toStringAsFixed(1)}X';

    int doneDaysIn30 = 0;
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      final dKey = DateFormat('yyyy-MM-dd').format(d);
      if (doneDates.contains(dKey)) doneDaysIn30++;
    }
    final monthlyRate = (doneDaysIn30 / 30.0 * 100).round();

    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekDayLabels = isArabic
        ? ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح']
        : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
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

      weekDayWidgets.add(Expanded(child: DayPill(day: label, state: state)));
    }

    return HabitContinuityMetrics(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      multiplierStr: multiplierStr,
      monthlyRate: monthlyRate,
      weekDayWidgets: weekDayWidgets,
    );
  }
}
