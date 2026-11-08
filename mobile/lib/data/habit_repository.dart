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
  final bool isEnabled;
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
    this.isEnabled = true,
    this.createdAt,
  });

  Habit copyWith({
    String? id,
    String? name,
    String? category,
    String? icon,
    String? color,
    String? scheduleType,
    String? remindTime,
    int? targetValue,
    bool? isDoneToday,
    int? streakDays,
    int? sortOrder,
    bool? isEnabled,
    String? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      scheduleType: scheduleType ?? this.scheduleType,
      remindTime: remindTime ?? this.remindTime,
      targetValue: targetValue ?? this.targetValue,
      isDoneToday: isDoneToday ?? this.isDoneToday,
      streakDays: streakDays ?? this.streakDays,
      sortOrder: sortOrder ?? this.sortOrder,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Habit.fromRow(Map<String, dynamic> row, {bool isDone = false, int streak = 0}) {
    String cat = (row['kind'] as String?)?.trim() ?? '';
    if (cat.toLowerCase() == 'boolean' || cat.toLowerCase() == 'numeric') {
      cat = '';
    }
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

    final id = row['id'] as String;
    final bool isEnabled;
    if (HabitRepository.isHabitPaused(id)) {
      isEnabled = false;
    } else {
      final rawEnabled = row['is_enabled'];
      isEnabled = rawEnabled == null ||
          rawEnabled == 1 ||
          rawEnabled == true ||
          rawEnabled == '1' ||
          rawEnabled == 'true';
    }

    return Habit(
      id: id,
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
      isEnabled: isEnabled,
      createdAt: row['created_at'] as String?,
    );
  }
}

class HabitRepository {
  static final Set<String> _pausedHabitIds = {};
  static bool _stateLoaded = false;

  /// Returns true if this habit has been explicitly paused locally.
  static bool isHabitPaused(String habitId) {
    return _pausedHabitIds.contains(habitId);
  }

  /// Ensures locally tracked paused habit states are loaded into memory from local storage/db
  static Future<void> ensureStateLoaded() async {
    if (_stateLoaded || !isDatabaseInitialized) return;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_habit_state (
          habit_id TEXT PRIMARY KEY,
          is_enabled INTEGER NOT NULL DEFAULT 1,
          updated_at TEXT NOT NULL
        )
      ''');
      final rows = await db.getAll('SELECT habit_id, is_enabled FROM local_habit_state');
      for (final r in rows) {
        final hId = r['habit_id'] as String? ?? '';
        final enabled = (r['is_enabled'] as num?)?.toInt() ?? 1;
        if (hId.isNotEmpty) {
          if (enabled == 0) {
            _pausedHabitIds.add(hId);
          } else {
            _pausedHabitIds.remove(hId);
          }
        }
      }
      _stateLoaded = true;
    } catch (e) {
      debugPrint('[HabitRepository] ensureStateLoaded notice: $e');
    }
  }

  String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// Parses human-readable time strings like '07:30 AM', '2:15 PM', or '14:00' into minutes from midnight.
  /// If null or unparseable, returns a large sentinel (1440 + 999) so unscheduled habits sort to the end.
  static int parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) {
      return 24 * 60 + 999;
    }
    final clean = timeStr.trim().toUpperCase();
    try {
      final isPm = clean.contains('PM');
      final isAm = clean.contains('AM');
      final stripped = clean.replaceAll('AM', '').replaceAll('PM', '').trim();
      final parts = stripped.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0].trim());
        final minute = int.parse(parts[1].trim());
        if (isPm && hour != 12) hour += 12;
        if (isAm && hour == 12) hour = 0;
        return (hour * 60) + minute;
      }
    } catch (_) {}
    return 24 * 60 + 999;
  }

  /// Chronological comparator for habits based on time of day (remindTime).
  /// Habits with earlier times come first; ties are broken by sortOrder, then name.
  static int compareByTime(Habit a, Habit b) {
    final timeA = parseTimeToMinutes(a.remindTime);
    final timeB = parseTimeToMinutes(b.remindTime);
    if (timeA != timeB) return timeA.compareTo(timeB);
    if (a.sortOrder != b.sortOrder) return a.sortOrder.compareTo(b.sortOrder);
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

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
    if (!isEnabled) {
      _pausedHabitIds.add(habitId);
    } else {
      _pausedHabitIds.remove(habitId);
    }

    // 2. Persist in local_habit_state table
    if (isDatabaseInitialized) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS local_habit_state (
            habit_id TEXT PRIMARY KEY,
            is_enabled INTEGER NOT NULL DEFAULT 1,
            updated_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          INSERT INTO local_habit_state (habit_id, is_enabled, updated_at)
          VALUES (?, ?, ?)
          ON CONFLICT(habit_id) DO UPDATE SET
            is_enabled = excluded.is_enabled,
            updated_at = excluded.updated_at
        ''', [habitId, isEnabled ? 1 : 0, now]);
      } catch (e) {
        debugPrint('[HabitRepository] Error persisting local_habit_state: $e');
      }

      // 3. Also update SQLite habits table
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
  static bool isPrayerIdentifier(String id) {
    final lower = id.toLowerCase();
    return lower.startsWith('prayer_') ||
        lower.startsWith('habit_prayer_') ||
        lower == 'fajr' ||
        lower == 'dhuhr' ||
        lower == 'asr' ||
        lower == 'maghrib' ||
        lower == 'isha';
  }

  /// Normalizes a prayer ID or code to its canonical name (fajr, dhuhr, asr, maghrib, isha).
  static String canonicalPrayerCode(String id) {
    final lower = id.toLowerCase();
    for (final code in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (lower == code || lower.endsWith('_$code') || lower.contains(code)) {
        return code;
      }
    }
    return lower;
  }

  /// Computes the daily completion status for each date based on completed habits & prayers.
  /// A date qualifies as 'done' towards the streak if:
  /// - The user completed at least [minHabitsRequired] daily habits (prayers included), OR
  /// - The user completed all scheduled habits (and prayers) when the total scheduled is fewer than [minHabitsRequired].
  static List<StreakLog> computeDailyStreakLogs({
    required List<Map<String, dynamic>> habits,
    required List<Map<String, dynamic>> habitLogs,
    List<Map<String, dynamic>>? prayers,
    int minHabitsRequired = 10,
  }) {
    // 1. Exclude legacy prayer records and disabled habits
    final validHabits = habits.where((h) {
      final id = (h['id'] as String? ?? '').toLowerCase();
      final kind = (h['kind'] as String? ?? '').toLowerCase();
      final rawId = (h['id'] as String? ?? '');
      final rawEnabled = h['is_enabled'];
      final isEnabled = !HabitRepository.isHabitPaused(rawId) &&
          (rawEnabled == null ||
              rawEnabled == 1 ||
              rawEnabled == true ||
              rawEnabled == '1' ||
              rawEnabled == 'true');
      return !isPrayerIdentifier(id) && kind != 'prayers' && isEnabled;
    }).toList();

    final validHabitIds = validHabits.map((h) => h['id'] as String).toSet();

    // 2. Track distinct completed habits & prayers per date
    final completedHabitsByDate = <String, Set<String>>{};
    final completedPrayersByDate = <String, Set<String>>{};
    final allDatesWithActivity = <String>{};

    for (final row in habitLogs) {
      final status = (row['status'] as String? ?? '').toLowerCase();
      if (status != 'done') continue;

      final habitId = row['habit_id'] as String? ?? '';
      final logDate = row['log_date'] as String? ?? '';
      if (habitId.isEmpty || logDate.isEmpty) continue;

      if (isPrayerIdentifier(habitId)) {
        final code = canonicalPrayerCode(habitId);
        completedPrayersByDate.putIfAbsent(logDate, () => {}).add(code);
        allDatesWithActivity.add(logDate);
      } else if (validHabitIds.isEmpty || validHabitIds.contains(habitId)) {
        completedHabitsByDate.putIfAbsent(logDate, () => {}).add(habitId);
        allDatesWithActivity.add(logDate);
      }
    }

    // 3. Incorporate completions from dedicated prayers table if provided
    if (prayers != null && prayers.isNotEmpty) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      for (final p in prayers) {
        final rawDone = p['is_done'];
        final isDone = rawDone == 1 || rawDone == true || rawDone == 'true' || rawDone == '1';
        if (!isDone) continue;

        final updatedAt = (p['updated_at'] as String?) ?? '';
        bool isToday = false;
        try {
          if (updatedAt.isNotEmpty) {
            final dt = DateTime.parse(updatedAt).toLocal();
            final now = DateTime.now();
            isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
          }
        } catch (_) {}

        if (isToday || updatedAt.startsWith(todayStr)) {
          final code = canonicalPrayerCode((p['prayer_code'] as String?) ?? (p['id'] as String? ?? ''));
          if (code.isNotEmpty) {
            completedPrayersByDate.putIfAbsent(todayStr, () => {}).add(code);
            allDatesWithActivity.add(todayStr);
          }
        }
      }
    }

    if (allDatesWithActivity.isEmpty) {
      return const [];
    }

    final result = <StreakLog>[];

    for (final dateStr in allDatesWithActivity) {
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      final doneHabitsCount = completedHabitsByDate[dateStr]?.length ?? 0;
      final donePrayersCount = completedPrayersByDate[dateStr]?.length ?? 0;
      final totalCompleted = doneHabitsCount + donePrayersCount;

      int scheduledHabitsCount = 0;
      for (final h in validHabits) {
        final createdAtStr = h['created_at'] as String?;
        if (createdAtStr != null && createdAtStr.isNotEmpty) {
          final createdDateStr = createdAtStr.length >= 10
              ? createdAtStr.substring(0, 10)
              : '';
          if (createdDateStr.isNotEmpty && createdDateStr.compareTo(dateStr) > 0) {
            continue;
          }
        }

        final sched = (h['schedule_type'] as String?)?.toLowerCase().trim() ?? 'daily';
        if (sched == 'weekdays') {
          if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday) {
            continue;
          }
        }
        scheduledHabitsCount++;
      }

      final hasPrayers = donePrayersCount > 0 || (prayers != null && prayers.isNotEmpty);
      final totalScheduled = scheduledHabitsCount + (hasPrayers ? 5 : 0);

      // Qualifies if user completed at least minHabitsRequired (e.g. 10) daily habits (prayers included),
      // OR completed all scheduled habits/prayers if total scheduled is fewer than minHabitsRequired (with at least 1 completed).
      final qualifies = totalCompleted >= minHabitsRequired ||
          (totalScheduled > 0 && totalScheduled < minHabitsRequired && totalCompleted >= totalScheduled);

      if (qualifies) {
        result.add(StreakLog(dateStr, 'done'));
      }
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Fetches daily streak logs where each date is 'done' if the user completed
  /// at least 10 daily habits (prayers included) or all scheduled habits.
  Future<List<StreakLog>> getDailyStreakLogs() async {
    if (!isDatabaseInitialized) {
      return const [];
    }
    final uid = currentUserId;
    final habitsQuery = uid.isNotEmpty
        ? 'SELECT id, kind, schedule_type, created_at FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\')'
        : 'SELECT id, kind, schedule_type, created_at FROM habits';
    final habitsParams = uid.isNotEmpty ? [uid] : <dynamic>[];
    final habitRows = await db.getAll(habitsQuery, habitsParams);

    final logsQuery = uid.isNotEmpty
        ? 'SELECT habit_id, log_date, status FROM habit_logs WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\') AND status = ?'
        : 'SELECT habit_id, log_date, status FROM habit_logs WHERE status = ?';
    final logsParams = uid.isNotEmpty ? [uid, 'done'] : ['done'];
    final logRows = await db.getAll(logsQuery, logsParams);

    List<Map<String, dynamic>> prayerRows = [];
    try {
      final prayersQuery = uid.isNotEmpty
          ? 'SELECT id, prayer_code, is_done, updated_at FROM prayers WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\')'
          : 'SELECT id, prayer_code, is_done, updated_at FROM prayers';
      final prayersParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      prayerRows = await db.getAll(prayersQuery, prayersParams);
    } catch (_) {}

    return computeDailyStreakLogs(
      habits: habitRows,
      habitLogs: logRows,
      prayers: prayerRows,
      minHabitsRequired: 10,
    );
  }

  /// Watches streak logs reactively, updating when habits, habit_logs, or prayers change,
  /// ensuring streak accurately increments when at least 10 daily habits (prayers included) are done.
  Stream<List<StreakLog>> watchStreakLogs() {
    if (!isDatabaseInitialized) {
      return Stream.value(const <StreakLog>[]);
    }
    final uid = currentUserId;
    final watchQuery = uid.isNotEmpty
        ? 'SELECT id FROM habit_logs WHERE user_id = ? OR user_id IS NULL OR user_id = \'\' '
          'UNION ALL '
          'SELECT id FROM habits WHERE user_id = ? OR user_id IS NULL OR user_id = \'\' '
          'UNION ALL '
          'SELECT id FROM prayers WHERE user_id = ? OR user_id IS NULL OR user_id = \'\''
        : 'SELECT id FROM habit_logs UNION ALL SELECT id FROM habits UNION ALL SELECT id FROM prayers';
    final watchParams = uid.isNotEmpty ? [uid, uid, uid] : <dynamic>[];

    return db.watch(watchQuery, parameters: watchParams).asyncMap((_) async {
      return getDailyStreakLogs();
    });
  }
}
