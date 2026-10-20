import 'package:home_widget/home_widget.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/streak_engine.dart';

class AppWidgetSyncService {
  static final AppWidgetSyncService _instance = AppWidgetSyncService._();
  factory AppWidgetSyncService() => _instance;
  AppWidgetSyncService._();

  Future<void> syncAll() async {
    await syncTodayTasks();
    await syncHabitStreak();
  }

  Future<void> syncTodayTasks() async {
    try {
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final rows = await db.getAll(
        "SELECT title, status, due_date FROM tasks WHERE status != 'archived' ORDER BY CASE WHEN status = 'done' THEN 1 ELSE 0 END, created_at DESC",
      );

      final todayTasks = rows.where((r) {
        final due = r['due_date'] as String?;
        return due != null && (due == todayStr || due.startsWith(todayStr));
      }).toList();

      final total = todayTasks.length;
      final done = todayTasks.where((r) => r['status'] == 'done').length;

      final lines = <String>[];
      for (final t in todayTasks.take(5)) {
        final isDone = t['status'] == 'done';
        final symbol = isDone ? '✓' : '○';
        lines.add('$symbol ${t['title']}');
      }

      final content = lines.isEmpty
          ? 'No tasks scheduled for today.'
          : lines.join('\n');

      await HomeWidget.saveWidgetData<String>(
          'today_tasks_title', 'AXIS • TODAY');
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_count', '$done/$total DONE');
      await HomeWidget.saveWidgetData<String>('today_tasks_content', content);
      await HomeWidget.updateWidget(
        androidName: 'TodayTasksWidgetProvider',
      );
    } catch (_) {}
  }

  Future<void> syncHabitStreak() async {
    try {
      final now = DateTime.now();
      final todayStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      final habitRows = await db.getAll(
        "SELECT id, name FROM habits WHERE archived = 0 OR archived IS NULL",
      );

      final habitLogRows = await db.getAll(
        "SELECT log_date, status, habit_id FROM habit_logs",
      );

      final streakLogs = habitLogRows
          .map((r) => StreakLog(r['log_date'] as String, r['status'] as String))
          .toList();

      final streak =
          StreakEngine.calculateStreak('daily', streakLogs, todayStr);

      final todayDoneHabits = habitLogRows
          .where(
              (r) => r['log_date'] == todayStr && r['status'] == 'completed')
          .length;

      final totalHabits = habitRows.length;

      final quote = streak > 0
          ? 'Consistency builds mastery. Keep going!'
          : 'Complete your first habit today!';

      await HomeWidget.saveWidgetData<String>(
        'habit_streak_days',
        '🔥 $streak ${streak == 1 ? 'DAY' : 'DAYS'}',
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_streak_progress',
        '$todayDoneHabits of $totalHabits habits completed today',
      );
      await HomeWidget.saveWidgetData<String>('habit_streak_quote', quote);

      await HomeWidget.updateWidget(
        androidName: 'HabitStreakWidgetProvider',
      );
    } catch (_) {}
  }
}
