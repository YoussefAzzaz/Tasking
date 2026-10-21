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
  final String? createdAt;

  Habit({
    required this.id,
    required this.name,
    this.category = '',
    this.icon = 'fitness',
    this.color = '#10B981',
    this.scheduleType = 'daily',
    this.remindTime,
    this.targetValue = 20,
    this.isDoneToday = false,
    this.streakDays = 0,
    this.sortOrder = 999,
    this.createdAt,
  });

  factory Habit.fromRow(Map<String, dynamic> row, {bool isDone = false, int streak = 0}) {
    String cat = (row['kind'] as String?)?.trim() ?? '';
    if (cat.isEmpty) {
      final icon = (row['icon'] as String?) ?? '';
      if (icon == 'mosque' ||
          icon == 'prayer' ||
          icon == 'fajr' ||
          icon == 'dhuhr' ||
          icon == 'asr' ||
          icon == 'maghrib' ||
          icon == 'isha') {
        cat = 'Prayers';
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
      createdAt: row['created_at'] as String?,
    );
  }
}

class HabitRepository {
  String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Returns the cycle start date ('yyyy-MM-dd') for a habit based on its scheduleType.
  /// - 'daily' & 'weekdays': resets at 00:00 every day (start = todayStr).
  /// - 'weekly': resets every Friday at 00:00.
  /// - 'every_3_days': resets every 3 days at 00:00 from creation date.
  static String calculateCycleStartDate({
    required String scheduleType,
    required DateTime now,
    String? createdAtStr,
  }) {
    final type = scheduleType.toLowerCase().trim();
    if (type == 'weekly') {
      int daysSinceFriday = (now.weekday - DateTime.friday) % 7;
      if (daysSinceFriday < 0) daysSinceFriday += 7;
      final lastFriday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceFriday));
      return DateFormat('yyyy-MM-dd').format(lastFriday);
    } else if (type == 'every_3_days' || type == '3days' || type == 'each_3_days') {
      DateTime createdDate;
      try {
        final dt = DateTime.parse(createdAtStr ?? '').toLocal();
        createdDate = DateTime(dt.year, dt.month, dt.day);
      } catch (_) {
        createdDate = DateTime(now.year, now.month, now.day);
      }
      final todayDate = DateTime(now.year, now.month, now.day);
      final daysDiff = todayDate.difference(createdDate).inDays;
      final cycleIndex = daysDiff >= 0 ? daysDiff ~/ 3 : 0;
      final currentCycleStart = createdDate.add(Duration(days: cycleIndex * 3));
      return DateFormat('yyyy-MM-dd').format(currentCycleStart);
    } else {
      return DateFormat('yyyy-MM-dd').format(now);
    }
  }

  Stream<List<Habit>> watchHabits() {
    final now = DateTime.now();
    final uid = currentUserId;

    final query = uid.isNotEmpty
        ? 'SELECT * FROM habits '
          'WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\') '
          'ORDER BY COALESCE(sort_order, 999) ASC, created_at ASC'
        : 'SELECT * FROM habits '
          'ORDER BY COALESCE(sort_order, 999) ASC, created_at ASC';
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db
        .watch(query, parameters: params)
        .asyncMap((habitRows) async {
      // Fetch recent completed logs (last 14 days) for schedule cycle completion check
      final cutoffStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 14)));
      final logsQuery = uid.isNotEmpty
          ? 'SELECT habit_id, log_date FROM habit_logs WHERE status = ? AND log_date >= ? AND (user_id = ? OR user_id IS NULL OR user_id = \'\')'
          : 'SELECT habit_id, log_date FROM habit_logs WHERE status = ? AND log_date >= ?';
      final logsParams = uid.isNotEmpty ? ['done', cutoffStr, uid] : ['done', cutoffStr];

      final recentLogs = await db.getAll(logsQuery, logsParams);
      final logsByHabit = <String, Set<String>>{};
      for (final r in recentLogs) {
        final hId = r['habit_id'] as String? ?? '';
        final lDate = r['log_date'] as String? ?? '';
        if (hId.isNotEmpty && lDate.isNotEmpty) {
          logsByHabit.putIfAbsent(hId, () => {}).add(lDate);
        }
      }

      final streakKey = 'habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}';
      final streakMap = await CacheService().getOrFetch<Map<String, int>>(
        streakKey,
        () async {
          final streakLogsQuery = uid.isNotEmpty
              ? 'SELECT habit_id, log_date, status FROM habit_logs WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\') ORDER BY log_date DESC'
              : 'SELECT habit_id, log_date, status FROM habit_logs ORDER BY log_date DESC';
          final streakLogsParams = uid.isNotEmpty ? [uid] : <dynamic>[];

          final allDoneLogs = await db.getAll(
            streakLogsQuery,
            streakLogsParams,
          ).timeout(const Duration(seconds: 3));

          final habitLogsMap = <String, List<StreakLog>>{};
          for (final row in allDoneLogs) {
            final hId = row['habit_id'] as String? ?? '';
            final d = row['log_date'] as String? ?? '';
            final s = row['status'] as String? ?? '';
            if (hId.isNotEmpty && d.isNotEmpty) {
              habitLogsMap.putIfAbsent(hId, () => []).add(StreakLog(d, s));
            }
          }

          final todayStr = DateFormat('yyyy-MM-dd').format(now);
          final map = <String, int>{};
          for (final row in habitRows) {
            final hId = row['id'] as String;
            final sched = (row['schedule_type'] as String?) ?? 'daily';
            final logs = habitLogsMap[hId] ?? [];
            map[hId] = StreakEngine.calculateStreak(sched, logs, todayStr);
          }
          return map;
        },
        ttl: const Duration(minutes: 5),
        staleWhileRevalidate: true,
        fallback: <String, int>{},
      );

      return habitRows.map((row) {
        final id = row['id'] as String;
        final scheduleType = (row['schedule_type'] as String?) ?? 'daily';
        final createdAtStr = row['created_at'] as String?;
        final cycleStart = calculateCycleStartDate(
          scheduleType: scheduleType,
          now: now,
          createdAtStr: createdAtStr,
        );

        final doneDates = logsByHabit[id] ?? const {};
        final isDone = doneDates.any((d) => d.compareTo(cycleStart) >= 0);

        return Habit.fromRow(
          row,
          isDone: isDone,
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
    } catch (e) {
      debugPrint('[HabitRepository] Error resetting streak logs: $e');
    }
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
    } catch (e) {
      debugPrint('[HabitRepository] Error adding habit: $e');
    }
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
    final now = DateTime.now();
    final nowUtc = now.toUtc().toIso8601String();
    final logEventId = IdGenerator.generateDeterministicId('xpevent_${habitId}_$today');

    if (done) {
      final logId = IdGenerator.generateDeterministicId('habitlog_${habitId}_$today');
      try {
        final existingLog = await db.getOptional('SELECT id FROM habit_logs WHERE id = ?', [logId]);
        if (existingLog != null) {
          await db.execute('''
            UPDATE habit_logs SET status = 'done', value = 1, updated_at = ? WHERE id = ?
          ''', [nowUtc, logId]);
        } else {
          await db.execute('''
            INSERT INTO habit_logs (
              id, user_id, habit_id, log_date, status, value, created_at, updated_at
            ) VALUES (?, ?, ?, ?, 'done', 1, ?, ?)
          ''', [logId, uid, habitId, today, nowUtc, nowUtc]);
        }

        final existingXp = await db.getOptional('SELECT id FROM logs WHERE id = ?', [logEventId]);
        if (existingXp != null) {
          await db.execute('''
            UPDATE logs SET xp_earned = 20, timestamp = ? WHERE id = ?
          ''', [nowUtc, logEventId]);
        } else {
          await db.execute('''
            INSERT INTO logs (
              id, user_id, task_id, event_type, xp_earned, timestamp
            ) VALUES (?, ?, ?, 'habit_completed', 20, ?)
          ''', [logEventId, uid, habitId, nowUtc]);
        }
      } catch (e) {
        debugPrint('[HabitRepository] Error toggling habit on: $e');
      }
    } else {
      try {
        final habitRow = await db.getOptional('SELECT schedule_type, created_at FROM habits WHERE id = ?', [habitId]);
        final scheduleType = (habitRow?['schedule_type'] as String?) ?? 'daily';
        final createdAtStr = habitRow?['created_at'] as String?;
        final cycleStart = calculateCycleStartDate(
          scheduleType: scheduleType,
          now: now,
          createdAtStr: createdAtStr,
        );

        await db.execute(
          'DELETE FROM habit_logs WHERE habit_id = ? AND log_date >= ?',
          [habitId, cycleStart],
        );
        await db.execute(
          "DELETE FROM logs WHERE id = ? OR (task_id = ? AND event_type = 'habit_completed' AND timestamp >= ?)",
          [logEventId, habitId, cycleStart],
        );
      } catch (e) {
        debugPrint('[HabitRepository] Error toggling habit off: $e');
      }
    }

    try {
      await syncGlobalUserLevel();
    } catch (e) {
      debugPrint('[HabitRepository] Error syncing global user level: $e');
    }

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
