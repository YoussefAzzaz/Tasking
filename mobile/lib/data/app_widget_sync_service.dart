import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/data/location_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/habit_repository.dart';

/// Centralized service to keep Android Home Screen widgets synchronized
/// with local database changes in real time.
class AppWidgetSyncService {
  static final AppWidgetSyncService _instance = AppWidgetSyncService._();
  factory AppWidgetSyncService() => _instance;
  AppWidgetSyncService._();

  /// Only Android and iOS provide native home screen widget frameworks supported by home_widget
  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  StreamSubscription? _tasksSub;
  StreamSubscription? _habitsSub;
  StreamSubscription? _habitLogsSub;
  Timer? _tasksDebounceTimer;
  Timer? _habitsDebounceTimer;

  /// Starts listening to real-time database changes and keeps widgets synchronized
  void startAutoSync() {
    if (!isSupportedPlatform) return;
    stopAutoSync();

    try {
      _tasksSub = db
          .watch('SELECT * FROM tasks')
          .listen((_) => _debouncedSyncTasks());
      _habitsSub = db
          .watch('SELECT * FROM habits')
          .listen((_) => _debouncedSyncHabits());
      _habitLogsSub = db
          .watch('SELECT * FROM habit_logs')
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
    if (!isSupportedPlatform) return;
    await syncTodayTasks();
    await syncHabitStreak();
  }

  Future<void> syncTodayTasks() async {
    if (!isSupportedPlatform) return;
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final formattedDate =
          DateFormat('EEEE, MMM d').format(now).toUpperCase();

      final uid = currentUserId;
      final taskQuery = uid.isNotEmpty
          ? "SELECT title, status, due_date, priority FROM tasks WHERE (user_id = ? OR user_id IS NULL OR user_id = '') ORDER BY CASE WHEN status = 'done' THEN 1 ELSE 0 END, CASE WHEN priority IS NULL THEN 4 ELSE priority END ASC, created_at DESC"
          : "SELECT title, status, due_date, priority FROM tasks ORDER BY CASE WHEN status = 'done' THEN 1 ELSE 0 END, CASE WHEN priority IS NULL THEN 4 ELSE priority END ASC, created_at DESC";
      final taskParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rows = await db.getAll(taskQuery, taskParams);

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

      // Resolve city name from LocationService (GPS / IP / Fallback) or PrayerTimeService
      String cityName = '';
      try {
        final loc = await LocationService().getLocation();
        if (loc.city.isNotEmpty &&
            loc.city != 'Local' &&
            loc.city != 'Auto' &&
            loc.city != 'GPS Location') {
          cityName = loc.city;
        }
      } catch (_) {}

      if (cityName.isEmpty) {
        final prayerCity = PrayerTimeService().currentCity;
        if (prayerCity.isNotEmpty &&
            prayerCity != 'Local' &&
            prayerCity != 'Auto' &&
            prayerCity != 'GPS Location') {
          cityName = prayerCity;
        }
      }

      // Clean up any region/GMT suffixes if present, e.g. "North Africa (GMT+1)" -> "North Africa"
      final cleanCity = cityName.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

      final dateWithCity = cleanCity.isNotEmpty
          ? '$formattedDate • ${cleanCity.toUpperCase()}'
          : formattedDate;

      await HomeWidget.saveWidgetData<String>(
          'today_tasks_title', 'AXIS • TODAY');
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_date', dateWithCity);
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_city', cleanCity.toUpperCase());
      await HomeWidget.saveWidgetData<String>(
          'today_tasks_count', '$done/$total DONE');
      await HomeWidget.saveWidgetData<String>('today_tasks_content', content);

      await HomeWidget.updateWidget(
        name: 'TodayTasksWidgetProvider',
        androidName: 'TodayTasksWidgetProvider',
        qualifiedAndroidName: 'com.axis.axis.TodayTasksWidgetProvider',
      );
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Error syncing today tasks widget: $e');
      }
    }
  }

  Future<void> syncHabitStreak() async {
    if (!isSupportedPlatform) return;
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final uid = currentUserId;

      // Filter strictly for daily frequency habits, excluding prayers and non-daily frequencies
      final habitQuery = uid.isNotEmpty
          ? "SELECT id, name, icon, color FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND LOWER(COALESCE(kind, '')) != 'prayers' AND id NOT LIKE 'habit_prayer_%' ORDER BY COALESCE(sort_order, 999) ASC, created_at ASC"
          : "SELECT id, name, icon, color FROM habits WHERE LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND LOWER(COALESCE(kind, '')) != 'prayers' AND id NOT LIKE 'habit_prayer_%' ORDER BY COALESCE(sort_order, 999) ASC, created_at ASC";
      final habitParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final habitRows = await db.getAll(habitQuery, habitParams);

      final habitLogQuery = uid.isNotEmpty
          ? "SELECT log_date, status, habit_id FROM habit_logs WHERE (user_id = ? OR user_id IS NULL OR user_id = '')"
          : "SELECT log_date, status, habit_id FROM habit_logs";
      final habitLogParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final habitLogRows = await db.getAll(habitLogQuery, habitLogParams);

      final streakLogs = await HabitRepository().getDailyStreakLogs();
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
          ? 'No daily habits created yet. Tap to add.'
          : lines.join('\n');

      await HomeWidget.saveWidgetData<String>(
        'habit_streak_days',
        '$streak ${streak == 1 ? 'DAY' : 'DAYS'}',
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
            ? '$streak-day streak active • Tap to open'
            : 'Consistency creates mastery • Tap to open',
      );
      await HomeWidget.saveWidgetData<int>('habit_streak_percent', percent);

      await HomeWidget.updateWidget(
        name: 'HabitStreakWidgetProvider',
        androidName: 'HabitStreakWidgetProvider',
        qualifiedAndroidName: 'com.axis.axis.HabitStreakWidgetProvider',
      );
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('Error syncing habit streak widget: $e');
      }
    }
  }
}
