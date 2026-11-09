import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/task_repository.dart';
import 'package:intl/intl.dart';

void main() {
  group('Task Due Date Grouping and Partitioning Tests', () {
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

