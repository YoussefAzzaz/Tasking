import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayers/prayer_model.dart';
import 'package:axis/data/prayers/prayer_repository.dart';
import 'package:axis/ui/desktop/screens/calendar/desktop_calendar_screen.dart';
import 'package:axis/ui/calendar/mobile_calendar_screen.dart';

/// Adaptive Calendar Screen dispatcher.
/// Renders [DesktopCalendarScreen] for desktop platforms or wide viewports (>= 1024px),
/// and [MobileCalendarScreen] for phones and compact mobile displays.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({
    super.key,
    this.initialTasks,
    this.initialHabits,
    this.initialPrayers,
    this.initialSelectedDate,
    this.initialCompletedLogs,
    this.taskRepo,
    this.habitRepo,
    this.prayerRepo,
  });

  final List<Task>? initialTasks;
  final List<Habit>? initialHabits;
  final List<Prayer>? initialPrayers;
  final DateTime? initialSelectedDate;
  final Map<String, Set<String>>? initialCompletedLogs;
  final TaskRepository? taskRepo;
  final HabitRepository? habitRepo;
  final PrayerRepository? prayerRepo;

  @override
  Widget build(BuildContext context) {
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final isWideViewport = MediaQuery.sizeOf(context).width >= 1024;

    if (isDesktopPlatform || isWideViewport) {
      return DesktopCalendarScreen(
        initialTasks: initialTasks,
        initialHabits: initialHabits,
        initialPrayers: initialPrayers,
        initialSelectedDate: initialSelectedDate,
        initialCompletedLogs: initialCompletedLogs,
        taskRepo: taskRepo,
        habitRepo: habitRepo,
        prayerRepo: prayerRepo,
      );
    }

    return MobileCalendarScreen(
      initialTasks: initialTasks,
      initialHabits: initialHabits,
      initialPrayers: initialPrayers,
      initialSelectedDate: initialSelectedDate,
      initialCompletedLogs: initialCompletedLogs,
      taskRepo: taskRepo,
      habitRepo: habitRepo,
      prayerRepo: prayerRepo,
    );
  }
}
