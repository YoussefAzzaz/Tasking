import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/streak_engine.dart';

export 'package:axis/domain/streak_engine.dart' show StreakLog;

class Habit {
  final String id;
  final String name;
  final String category;
  final String icon;
  final String color;
  final String scheduleType;
  final String? remindTime;
  final int targetValue; // XP reward
  final bool isDoneToday;
  final int streakDays;
  final int sortOrder;

  Habit({
    required this.id,
    required this.name,
    this.category = 'Workout',
    this.icon = 'fitness',
    this.color = '#10B981',
    this.scheduleType = 'daily',
    this.remindTime,
    this.targetValue = 20,
    this.isDoneToday = false,
    this.streakDays = 0,
    this.sortOrder = 999,
  });

  factory Habit.fromRow(Map<String, dynamic> row, {bool isDone = false, int streak = 0}) {
    String cat = (row['kind'] as String?)?.trim() ?? '';
    if (cat.isEmpty) {
      final icon = (row['icon'] as String?) ?? '';
      if (icon == 'book') {
        cat = 'Reading';
      } else if (icon == 'meditation') {
        cat = 'Mindful';
      } else if (icon == 'water') {
        cat = 'Hydrate';
      } else if (icon == 'code') {
        cat = 'Code';
      } else if (icon == 'sleep') {
        cat = 'Rest';
      } else if (icon == 'mosque' ||
          icon == 'prayer' ||
          icon == 'fajr' ||
          icon == 'dhuhr' ||
          icon == 'asr' ||
          icon == 'maghrib' ||
          icon == 'isha') {
        cat = 'Prayers';
      } else {
        cat = 'Workout';
      }
    }

    return Habit(
      id: row['id'] as String,
      name: row['name'] as String,
      category: cat,
      icon: (row['icon'] as String?) ?? 'fitness',
      color: (row['color'] as String?) ?? '#10B981',
      scheduleType: (row['schedule_type'] as String?) ?? 'daily',
      remindTime: row['remind_time'] as String?,
      targetValue: (row['target_value'] as num?)?.toInt() ?? 20,
      isDoneToday: isDone,
      streakDays: streak,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 999,
    );
  }
}

class HabitRepository {
  String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Stream<List<Habit>> watchHabits() {
    final today = _todayStr();
    final uid = currentUserId;

    final query = uid.isNotEmpty
        ? 'SELECT habits.*, habit_logs.status AS today_status '
          'FROM habits '
          'LEFT JOIN habit_logs ON habits.id = habit_logs.habit_id AND habit_logs.log_date = ? AND (habit_logs.user_id = ? OR habit_logs.user_id IS NULL OR habit_logs.user_id = \'\') '
          'WHERE (habits.user_id = ? OR habits.user_id IS NULL OR habits.user_id = \'\') '
          'ORDER BY COALESCE(habits.sort_order, 999) ASC, habits.created_at ASC'
        : 'SELECT habits.*, habit_logs.status AS today_status '
          'FROM habits '
          'LEFT JOIN habit_logs ON habits.id = habit_logs.habit_id AND habit_logs.log_date = ? '
          'ORDER BY COALESCE(habits.sort_order, 999) ASC, habits.created_at ASC';
    final params = uid.isNotEmpty ? [today, uid, uid] : [today];

    return db
        .watch(query, parameters: params)
        .asyncMap((habitRows) async {
      final doneSet = <String>{};
      for (final row in habitRows) {
        if (row['today_status'] == 'done') {
          doneSet.add(row['id'] as String);
        }
      }

      final streakKey = 'habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}';
      final streakMap = await CacheService().getOrFetch<Map<String, int>>(
        streakKey,
        () async {
          final streakQuery = uid.isNotEmpty
              ? 'SELECT habit_id, COUNT(*) as streak FROM habit_logs WHERE status = ? AND user_id = ? GROUP BY habit_id'
              : 'SELECT habit_id, COUNT(*) as streak FROM habit_logs WHERE status = ? GROUP BY habit_id';
          final streakParams = uid.isNotEmpty ? ['done', uid] : ['done'];

          final allDoneLogs = await db.getAll(
            streakQuery,
            streakParams,
          ).timeout(const Duration(seconds: 3));

          final map = <String, int>{};
          for (final row in allDoneLogs) {
            map[row['habit_id'] as String] = (row['streak'] as num?)?.toInt() ?? 0;
          }
          return map;
        },
        ttl: const Duration(minutes: 5),
        staleWhileRevalidate: true,
        fallback: <String, int>{},
      );

      return habitRows.map((row) {
        final id = row['id'] as String;
        return Habit.fromRow(
          row,
          isDone: doneSet.contains(id),
          streak: streakMap[id] ?? 0,
        );
      }).toList();
    });
  }

  Future<void> resetAllStreaks() async {
    final uid = currentUserId;
    CacheService().invalidate('habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}');
    StatsRepository().invalidateStats();
    try {
      final query = uid.isNotEmpty
          ? 'DELETE FROM habit_logs WHERE user_id = ?'
          : 'DELETE FROM habit_logs';
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];
      await db.execute(query, params).timeout(const Duration(seconds: 4));
    } catch (_) {}
    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> addHabit(Habit habit) async {
    final uid = currentUserId;
    CacheService().invalidate('habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}');
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await db.execute('''
        INSERT INTO habits (
          id, user_id, name, kind, icon, color, schedule_type, remind_time, target_value, sort_order, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        habit.id,
        uid,
        habit.name,
        habit.category,
        habit.icon,
        habit.color,
        habit.scheduleType,
        habit.remindTime,
        habit.targetValue,
        habit.sortOrder,
        now,
        now,
      ]);
    } catch (_) {}
    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> updateHabit(Habit habit) async {
    final uid = currentUserId;
    CacheService().invalidate('habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}');
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await db.execute('''
        UPDATE habits SET
          user_id = COALESCE(NULLIF(user_id, ''), ?),
          name = ?, kind = ?, icon = ?, color = ?, schedule_type = ?, remind_time = ?, target_value = ?, sort_order = ?, updated_at = ?
        WHERE id = ?
      ''', [
        uid,
        habit.name,
        habit.category,
        habit.icon,
        habit.color,
        habit.scheduleType,
        habit.remindTime,
        habit.targetValue,
        habit.sortOrder,
        now,
        habit.id,
      ]);
    } catch (e) {
      debugPrint('[HabitRepository] Error updating habit: $e');
    }
    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> toggleHabit(String habitId, bool done) async {
    final uid = currentUserId;
    CacheService().invalidate('habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}');
    StatsRepository().invalidateStats();

    final today = _todayStr();
    final now = DateTime.now().toUtc().toIso8601String();
    final logEventId = IdGenerator.generateDeterministicId('xpevent_${habitId}_$today');

    if (done) {
      final logId = IdGenerator.generateDeterministicId('habitlog_${habitId}_$today');
      try {
        await db.execute('''
          INSERT OR REPLACE INTO habit_logs (
            id, user_id, habit_id, log_date, status, value, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', [logId, uid, habitId, today, 'done', 1, now, now]);

        await db.execute('''
          INSERT OR REPLACE INTO logs (
            id, user_id, task_id, event_type, xp_earned, timestamp
          ) VALUES (?, ?, ?, ?, ?, ?)
        ''', [logEventId, uid, habitId, 'habit_completed', 20, now]);
      } catch (_) {}
    } else {
      try {
        await db.execute('DELETE FROM habit_logs WHERE habit_id = ? AND log_date = ?', [habitId, today]);
        await db.execute(
          "DELETE FROM logs WHERE id = ? OR (task_id = ? AND event_type = 'habit_completed' AND timestamp LIKE ?)",
          [logEventId, habitId, '$today%'],
        );
      } catch (e) {
        // Ignored or logged
      }
    }

    try {
      await syncGlobalUserLevel();
    } catch (_) {}

    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> deleteHabit(String habitId) async {
    final uid = currentUserId;
    CacheService().invalidate('habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}');
    StatsRepository().invalidateStats();
    try {
      await db.execute('DELETE FROM habit_logs WHERE habit_id = ?', [habitId]);
      await db.execute('DELETE FROM habits WHERE id = ?', [habitId]);
    } catch (e) {
      debugPrint('[HabitRepository] Error deleting habit: $e');
    }
    AppWidgetSyncService().syncHabitStreak();
  }

  /// Watches streak logs with optimized indexed query
  Stream<List<StreakLog>> watchStreakLogs() {
    final uid = currentUserId;
    final query = uid.isNotEmpty
        ? 'SELECT log_date, status FROM habit_logs WHERE user_id = ? ORDER BY log_date DESC'
        : 'SELECT log_date, status FROM habit_logs ORDER BY log_date DESC';
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db
        .watch(query, parameters: params)
        .map((rows) => rows
            .map((r) => StreakLog(r['log_date'] as String, r['status'] as String))
            .toList());
  }
}
