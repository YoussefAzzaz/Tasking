import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/data/habit_notification_service.dart';
import 'package:axis/data/daily_prayer_status_repository.dart';
import 'package:axis/data/habits/habit_state_manager.dart';
import 'package:axis/data/habits/habit_streak_service.dart';
import 'package:axis/domain/models/habit.dart';

export 'package:axis/domain/streak_engine.dart' show StreakLog;
export 'package:axis/data/habits/habit_state_manager.dart';
export 'package:axis/data/habits/habit_streak_service.dart';
export 'package:axis/domain/models/habit.dart';

class HabitRepository {
  /// Returns true if this habit has been explicitly paused locally.
  static bool isHabitPaused(String habitId) =>
      HabitStateManager.isHabitPaused(habitId);

  /// Ensures locally tracked paused habit states are loaded into memory from local storage/db
  static Future<void> ensureStateLoaded() =>
      HabitStateManager.ensureStateLoaded();

  String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Parses human-readable time strings into minutes from midnight.
  static int parseTimeToMinutes(String? timeStr) =>
      HabitStreakService.parseTimeToMinutes(timeStr);

  /// Chronological comparator for habits based on time of day (remindTime).
  static int compareByTime(Habit a, Habit b) {
    final timeA = parseTimeToMinutes(a.remindTime);
    final timeB = parseTimeToMinutes(b.remindTime);
    if (timeA != timeB) return timeA.compareTo(timeB);
    if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Returns the cycle start date ('yyyy-MM-dd') for a habit based on its scheduleType.
  static String calculateCycleStartDate({
    required String scheduleType,
    required DateTime now,
    String? createdAtStr,
  }) =>
      HabitStreakService.calculateCycleStartDate(
        scheduleType: scheduleType,
        now: now,
        createdAtStr: createdAtStr,
      );

  Stream<List<Habit>> watchHabits() {
    if (!isDatabaseInitialized) {
      return Stream.value(const <Habit>[]);
    }
    unawaited(ensureStateLoaded());
    final now = DateTime.now();
    final uid = currentUserId;

    final query = uid.isNotEmpty
        ? 'SELECT * FROM habits '
          'WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\') AND (deleted_at IS NULL OR deleted_at = \'\') '
          'ORDER BY COALESCE(sort_order, 999) ASC, created_at ASC'
        : 'SELECT * FROM habits '
          'WHERE (deleted_at IS NULL OR deleted_at = \'\') '
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

  /// Watches distinct dates where at least one habit was completed during the current week (from Monday).
  Stream<Set<String>> watchWeekDoneDates() {
    if (!isDatabaseInitialized) return Stream.value(const <String>{});
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final mondayStr = DateFormat('yyyy-MM-dd').format(monday);
    final uid = currentUserId;

    final query = uid.isNotEmpty
        ? 'SELECT DISTINCT log_date FROM habit_logs WHERE status = ? AND log_date >= ? AND (user_id = ? OR user_id IS NULL OR user_id = \'\')'
        : 'SELECT DISTINCT log_date FROM habit_logs WHERE status = ? AND log_date >= ?';
    final params = uid.isNotEmpty ? ['done', mondayStr, uid] : ['done', mondayStr];

    return db.watch(query, parameters: params).map((rows) {
      return rows.map((r) => r['log_date'] as String? ?? '').where((s) => s.isNotEmpty).toSet();
    }).handleError((e) {
      debugPrint('[HabitRepository] watchWeekDoneDates error: $e');
      return <String>{};
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

      final prayerQuery = uid.isNotEmpty
          ? "UPDATE prayers SET is_done = 0 WHERE (user_id = ? OR user_id IS NULL OR user_id = '')"
          : 'UPDATE prayers SET is_done = 0';
      final prayerParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      await db.execute(prayerQuery, prayerParams).timeout(const Duration(seconds: 4));
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
          id, user_id, name, kind, icon, color, schedule_type, remind_time, target_value, sort_order, is_enabled, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        habit.isEnabled ? 1 : 0,
        now,
        now,
      ]);
    } catch (e) {
      debugPrint('[HabitRepository] Error adding habit: $e');
    }
    AppWidgetSyncService().syncHabitStreak();
    if (habit.isEnabled) {
      unawaited(HabitNotificationService().scheduleHabitReminders(habit));
    }
  }

  Future<void> updateHabit(Habit habit) async {
    final uid = currentUserId;
    CacheService().invalidate('habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}');
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await db.execute('''
        UPDATE habits SET
          user_id = COALESCE(NULLIF(user_id, ''), ?),
          name = ?, kind = ?, icon = ?, color = ?, schedule_type = ?, remind_time = ?, target_value = ?, sort_order = ?, is_enabled = ?, updated_at = ?
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
        habit.isEnabled ? 1 : 0,
        now,
        habit.id,
      ]);
    } catch (e) {
      debugPrint('[HabitRepository] Error updating habit: $e');
    }
    AppWidgetSyncService().syncHabitStreak();
    if (habit.isEnabled) {
      unawaited(HabitNotificationService().scheduleHabitReminders(habit));
    } else {
      unawaited(HabitNotificationService().cancelHabitReminders(habit.id));
    }
  }

  /// Toggles whether a habit is active or paused/disabled.
  /// When toggled off, it does not count in today habits or streaks, and notifications are stopped.
  Future<void> toggleHabitEnabled(String habitId, bool isEnabled) async {
    final uid = currentUserId;
    CacheService().invalidate('habit_streaks_map_${uid.isNotEmpty ? uid : 'global'}');
    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Update in-memory paused state immediately (immune to remote sync resets)
    HabitStateManager.setHabitPausedInMemory(habitId, !isEnabled);

    // 2. Persist in local_habit_state table
    await HabitStateManager.persistHabitState(habitId, isEnabled, now);

    // 3. Also update SQLite habits table
    if (isDatabaseInitialized) {
      try {
        await db.execute('''
          UPDATE habits SET is_enabled = ?, updated_at = ? WHERE id = ?
        ''', [isEnabled ? 1 : 0, now, habitId]);
      } catch (e) {
        debugPrint('[HabitRepository] Error toggling habit enabled in habits table: $e');
      }
    }

    if (!isEnabled) {
      unawaited(HabitNotificationService().cancelHabitReminders(habitId));
    } else {
      try {
        final row = await db.getOptional('SELECT * FROM habits WHERE id = ?', [habitId]);
        if (row != null) {
          final habit = Habit.fromRow(row);
          unawaited(HabitNotificationService().scheduleHabitReminders(habit));
        }
      } catch (_) {}
    }

    AppWidgetSyncService().syncHabitStreak();
    StatsRepository().invalidateStats();
    unawaited(DailyPrayerStatusRepository().syncMyDailyPrayerStatus());
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

        await db.execute('UPDATE habits SET updated_at = ? WHERE id = ?', [nowUtc, habitId]);
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

        await db.execute('UPDATE habits SET updated_at = ? WHERE id = ?', [nowUtc, habitId]);
      } catch (e) {
        debugPrint('[HabitRepository] Error toggling habit off: $e');
      }
    }

    try {
      await syncGlobalUserLevel();
    } catch (e) {
      debugPrint('[HabitRepository] Error syncing global user level: $e');
    }

    if (done) {
      unawaited(HabitNotificationService().onHabitCompletedToday(habitId));
    } else {
      try {
        final row = await db.getOptional('SELECT * FROM habits WHERE id = ?', [habitId]);
        if (row != null) {
          final habit = Habit.fromRow(row);
          unawaited(HabitNotificationService().scheduleHabitReminders(habit));
        }
      } catch (_) {}
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
    unawaited(HabitNotificationService().cancelHabitReminders(habitId));
  }

  /// Checks whether an identifier represents an Islamic prayer.
  static bool isPrayerIdentifier(String id) =>
      HabitStreakService.isPrayerIdentifier(id);

  /// Normalizes a prayer ID or code to its canonical name (fajr, dhuhr, asr, maghrib, isha).
  static String canonicalPrayerCode(String id) =>
      HabitStreakService.canonicalPrayerCode(id);

  /// Computes the daily completion status for each date based on completed habits & prayers.
  static List<StreakLog> computeDailyStreakLogs({
    required List<Map<String, dynamic>> habits,
    required List<Map<String, dynamic>> habitLogs,
    List<Map<String, dynamic>>? prayers,
    int minHabitsRequired = 10,
  }) =>
      HabitStreakService.computeDailyStreakLogs(
        habits: habits,
        habitLogs: habitLogs,
        prayers: prayers,
        minHabitsRequired: minHabitsRequired,
        isHabitPaused: isHabitPaused,
      );

  /// Fetches daily streak logs where each date is 'done' if the user completed
  /// at least 10 daily habits (prayers included) or all scheduled habits.
  Future<List<StreakLog>> getDailyStreakLogs() =>
      HabitStreakService.getDailyStreakLogs(
        uid: currentUserId,
        isHabitPaused: isHabitPaused,
      );

  /// Watches streak logs reactively, updating when habits, habit_logs, or prayers change.
  Stream<List<StreakLog>> watchStreakLogs() =>
      HabitStreakService.watchStreakLogs(
        uid: currentUserId,
        isHabitPaused: isHabitPaused,
      );
}
