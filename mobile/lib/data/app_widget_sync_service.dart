import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/streak_engine.dart';

/// Centralized service to keep Android Home Screen widgets synchronized
/// with local database changes in real time.
class AppWidgetSyncService {
  static final AppWidgetSyncService _instance = AppWidgetSyncService._();
  factory AppWidgetSyncService() => _instance;
  AppWidgetSyncService._();

  StreamSubscription? _tasksSub;
  StreamSubscription? _habitsSub;
  StreamSubscription? _habitLogsSub;
  Timer? _tasksDebounceTimer;
  Timer? _habitsDebounceTimer;

  /// Starts listening to real-time database changes and keeps widgets synchronized
  void startAutoSync() {
    stopAutoSync();

    try {
      _tasksSub =
          db.watch('SELECT id FROM tasks').listen((_) => _debouncedSyncTasks());
      _habitsSub = db
          .watch('SELECT id FROM habits')
          .listen((_) => _debouncedSyncHabits());
      _habitLogsSub = db
          .watch('SELECT id FROM habit_logs')
          .listen((_) => _debouncedSyncHabits());
    } catch (e) {
      debugPrint('Error starting AppWidget auto-sync listeners: $e');
    }
  }

  void stopAutoSync() {
    _tasksSub?.cancel();
    _habitsSub?.cancel();
    _habitLogsSub?.cancel();
    _tasksDebounceTimer?.cancel();
    _habitsDebounceTimer?.cancel();
  }

  void _debouncedSyncTasks() {
    _tasksDebounceTimer?.cancel();
    _tasksDebounceTimer =
        Timer(const Duration(milliseconds: 250), () => syncTodayTasks());
  }

  void _debouncedSyncHabits() {
    _habitsDebounceTimer?.cancel();
    _habitsDebounceTimer =
        Timer(const Duration(milliseconds: 250), () => syncHabitStreak());
  }

  Future<void> syncAll() async {
    await syncTodayTasks();
    await syncHabitStreak();
  }

  Future<void> syncTodayTasks() async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final formattedDate =
          DateFormat('EEEE, MMM d').format(now).toUpperCase();

      final rows = await db.getAll(
        "SELECT title, status, due_date, priority FROM tasks ORDER BY CASE WHEN status = 'done' THEN 1 ELSE 0 END, CASE WHEN priority IS NULL THEN 4 ELSE priority END ASC, created_at DESC",
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
        final title = (t['title'] as String? ?? '').replaceAll('\n', ' ').trim();
        lines.add('$symbol $title');
      }

      final content = lines.isEmpty
          ? 'No tasks scheduled for today.'
          : lines.join('\n');

      await HomeWidget.saveWidgetData<String>(
          'today_tasks_title', 'AXIS • TODAY');
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_date', formattedDate);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_count', '$done/$total DONE');
      await HomeWidget.saveWidgetData<String>('today_tasks_content', content);

      await HomeWidget.updateWidget(
        name: 'TodayTasksWidgetProvider',
        androidName: 'TodayTasksWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error syncing today tasks widget: $e');
    }
  }

  Future<void> syncHabitStreak() async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final habitRows = await db.getAll(
        'SELECT id, name, icon, color FROM habits ORDER BY created_at ASC',
      );

      final habitLogRows = await db.getAll(
        'SELECT log_date, status, habit_id FROM habit_logs',
      );

      final streakLogs = habitLogRows
          .map((r) => StreakLog(r['log_date'] as String, r['status'] as String))
          .toList();

      final streak =
          StreakEngine.calculateStreak('daily', streakLogs, todayStr);

      final todayDoneHabitIds = habitLogRows
          .where((r) => r['log_date'] == todayStr && r['status'] == 'done')
          .map((r) => r['habit_id'] as String)
          .toSet();

      final totalHabits = habitRows.length;
      final todayDoneCount = habitRows
          .where((h) => todayDoneHabitIds.contains(h['id'] as String))
          .length;
      final percent =
          totalHabits > 0 ? ((todayDoneCount / totalHabits) * 100).toInt() : 0;

      final lines = <String>[];
      for (final h in habitRows.take(5)) {
        final isDone = todayDoneHabitIds.contains(h['id'] as String);
        final symbol = isDone ? '✓' : '○';
        final name = (h['name'] as String? ?? '').replaceAll('\n', ' ').trim();
        lines.add('$symbol $name');
      }

      final content = lines.isEmpty
          ? 'No habits created yet. Tap to add.'
          : lines.join('\n');

      await HomeWidget.saveWidgetData<String>(
        'habit_streak_days',
        '🔥 $streak ${streak == 1 ? 'DAY' : 'DAYS'}',
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_streak_badge',
        '$todayDoneCount/$totalHabits DONE',
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_streak_progress',
        '$todayDoneCount of $totalHabits habits completed today ($percent%)',
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_streak_content',
        content,
      );
      await HomeWidget.saveWidgetData<String>(
        'habit_streak_quote',
        streak > 0
            ? '🔥 $streak-day streak active • Tap to open'
            : 'Consistency creates mastery • Tap to open',
      );
      await HomeWidget.saveWidgetData<int>('habit_streak_percent', percent);

      await HomeWidget.updateWidget(
        name: 'HabitStreakWidgetProvider',
        androidName: 'HabitStreakWidgetProvider',
      );
    } catch (e) {
      debugPrint('Error syncing habit streak widget: $e');
    }
  }
}
