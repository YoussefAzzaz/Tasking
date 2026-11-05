import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:intl/intl.dart';

void main() {
  group('Habit isEnabled Toggle and Filtering Tests', () {
    test('Habit fromRow defaults isEnabled to true and parses 0 as false', () {
      final defaultHabit = Habit.fromRow({
        'id': 'h1',
        'name': 'Read Quran',
        'category': 'Spiritual',
        'icon': 'book',
        'color': '#10B981',
        'schedule_type': 'daily',
        'target_value': 10,
        'is_done': 0,
        'streak_days': 5,
        'sort_order': 0,
      });
      expect(defaultHabit.isEnabled, isTrue);

      final disabledHabit = Habit.fromRow({
        'id': 'h2',
        'name': 'Gym Workout',
        'category': 'Fitness',
        'icon': 'fitness',
        'color': '#38BDF8',
        'schedule_type': 'daily',
        'target_value': 15,
        'is_done': 1,
        'streak_days': 3,
        'sort_order': 1,
        'is_enabled': 0,
      });
      expect(disabledHabit.isEnabled, isFalse);

      final enabledHabit = disabledHabit.copyWith(isEnabled: true);
      expect(enabledHabit.isEnabled, isTrue);
    });

    test('Toggled off habits are excluded when calculating active habit counts', () {
      final habits = [
        Habit(id: '1', name: 'Habit 1', category: 'General', icon: 'check', color: '#FFF', scheduleType: 'daily', isEnabled: true, isDoneToday: true),
        Habit(id: '2', name: 'Habit 2', category: 'General', icon: 'check', color: '#FFF', scheduleType: 'daily', isEnabled: false, isDoneToday: true),
        Habit(id: '3', name: 'Habit 3', category: 'General', icon: 'check', color: '#FFF', scheduleType: 'daily', isEnabled: true, isDoneToday: false),
      ];

      final activeHabits = habits.where((h) => h.isEnabled).toList();
      final totalActive = activeHabits.length;
      final doneActive = activeHabits.where((h) => h.isDoneToday).length;

      expect(totalActive, 2);
      expect(doneActive, 1);
    });
  });

  group('Desktop Task Due Date Grouping Tests', () {
    test('Tasks are partitioned chronologically into OVERDUE, TODAY, TOMORROW, UPCOMING, and NO DUE DATE', () {
      final now = DateTime.now();
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));
      final nextWeekStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 7)));

      final tasks = [
        Task(id: 't1', title: 'Overdue task', dueDate: yesterdayStr, status: 'todo'),
        Task(id: 't2', title: 'Today task', dueDate: todayStr, status: 'todo'),
        Task(id: 't3', title: 'Tomorrow task', dueDate: tomorrowStr, status: 'todo'),
        Task(id: 't4', title: 'Upcoming task', dueDate: nextWeekStr, status: 'todo'),
        Task(id: 't5', title: 'Unscheduled task', dueDate: null, status: 'todo'),
      ];

      final overdueTasks = <Task>[];
      final todayTasks = <Task>[];
      final tomorrowTasks = <Task>[];
      final upcomingTasks = <Task>[];
      final noDateTasks = <Task>[];

      for (final task in tasks) {
        final d = task.dueDate;
        if (d == null || d.trim().isEmpty) {
          noDateTasks.add(task);
        } else if (d.compareTo(todayStr) < 0) {
          overdueTasks.add(task);
        } else if (d == todayStr) {
          todayTasks.add(task);
        } else if (d == tomorrowStr) {
          tomorrowTasks.add(task);
        } else {
          upcomingTasks.add(task);
        }
      }

      expect(overdueTasks.map((t) => t.id), ['t1']);
      expect(todayTasks.map((t) => t.id), ['t2']);
      expect(tomorrowTasks.map((t) => t.id), ['t3']);
      expect(upcomingTasks.map((t) => t.id), ['t4']);
      expect(noDateTasks.map((t) => t.id), ['t5']);
    });
  });
}

