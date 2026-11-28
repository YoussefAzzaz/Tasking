import 'dart:async';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/streak_engine.dart';

/// Service and utilities for habit streak computations, prayer identification,
/// and schedule cycle calculations.
class HabitStreakService {
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
      final lastFriday = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: daysSinceFriday));
      return DateFormat('yyyy-MM-dd').format(lastFriday);
    } else if (type == 'every_3_days' ||
        type == '3days' ||
        type == 'each_3_days') {
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

  /// Computes the daily completion status for each date based on completed habits & prayers.
  /// A date qualifies as 'done' towards the streak if:
  /// - The user completed at least [minHabitsRequired] daily habits (prayers included), OR
  /// - The user completed all scheduled habits (and prayers) when the total scheduled is fewer than [minHabitsRequired].
  static List<StreakLog> computeDailyStreakLogs({
    required List<Map<String, dynamic>> habits,
    required List<Map<String, dynamic>> habitLogs,
    List<Map<String, dynamic>>? prayers,
    int minHabitsRequired = 10,
    bool Function(String id)? isHabitPaused,
  }) {
    // 1. Exclude legacy prayer records and disabled habits
    final validHabits = habits.where((h) {
      final id = (h['id'] as String? ?? '').toLowerCase();
      final kind = (h['kind'] as String? ?? '').toLowerCase();
      final rawId = (h['id'] as String? ?? '');
      final rawEnabled = h['is_enabled'];
      final isPaused = isHabitPaused?.call(rawId) ?? false;
      final isEnabled = !isPaused &&
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
        final isDone =
            rawDone == 1 || rawDone == true || rawDone == 'true' || rawDone == '1';
        if (!isDone) continue;

        final updatedAt = (p['updated_at'] as String?) ?? '';
        bool isToday = false;
        try {
          if (updatedAt.isNotEmpty) {
            final dt = DateTime.parse(updatedAt).toLocal();
            final now = DateTime.now();
            isToday =
                dt.year == now.year && dt.month == now.month && dt.day == now.day;
          }
        } catch (_) {}

        if (isToday || updatedAt.startsWith(todayStr)) {
          final code = canonicalPrayerCode(
              (p['prayer_code'] as String?) ?? (p['id'] as String? ?? ''));
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
          if (createdDateStr.isNotEmpty &&
              createdDateStr.compareTo(dateStr) > 0) {
            continue;
          }
        }

        final sched =
            (h['schedule_type'] as String?)?.toLowerCase().trim() ?? 'daily';
        if (sched == 'weekdays') {
          if (date.weekday == DateTime.saturday ||
              date.weekday == DateTime.sunday) {
            continue;
          }
        }
        scheduledHabitsCount++;
      }

      final hasPrayers =
          donePrayersCount > 0 || (prayers != null && prayers.isNotEmpty);
      final totalScheduled = scheduledHabitsCount + (hasPrayers ? 5 : 0);

      // Qualifies if user completed at least minHabitsRequired (e.g. 10) daily habits (prayers included),
      // OR completed all scheduled habits/prayers if total scheduled is fewer than minHabitsRequired (with at least 1 completed).
      final qualifies = totalCompleted >= minHabitsRequired ||
          (totalScheduled > 0 &&
              totalScheduled < minHabitsRequired &&
              totalCompleted >= totalScheduled);

      if (qualifies) {
        result.add(StreakLog(dateStr, 'done'));
      }
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Fetches daily streak logs where each date is 'done' if the user completed
  /// at least 10 daily habits (prayers included) or all scheduled habits.
  static Future<List<StreakLog>> getDailyStreakLogs({
    required String uid,
    bool Function(String id)? isHabitPaused,
  }) async {
    if (!isDatabaseInitialized) {
      return const [];
    }
    // Root-cause fix: exclude soft-deleted habits and habit logs so archived
    // or deleted items do not distort active streak requirements.
    final habitsQuery = uid.isNotEmpty
        ? "SELECT id, kind, schedule_type, is_enabled, created_at FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND (deleted_at IS NULL OR deleted_at = '')"
        : "SELECT id, kind, schedule_type, is_enabled, created_at FROM habits WHERE (deleted_at IS NULL OR deleted_at = '')";
    final habitsParams = uid.isNotEmpty ? [uid] : <dynamic>[];
    final habitRows = await db.getAll(habitsQuery, habitsParams);

    final logsQuery = uid.isNotEmpty
        ? "SELECT habit_id, log_date, status FROM habit_logs WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND (deleted_at IS NULL OR deleted_at = '') AND status = ?"
        : "SELECT habit_id, log_date, status FROM habit_logs WHERE (deleted_at IS NULL OR deleted_at = '') AND status = ?";
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
      isHabitPaused: isHabitPaused,
    );
  }

  /// Watches streak logs reactively, updating when habits, habit_logs, or prayers change.
  static Stream<List<StreakLog>> watchStreakLogs({
    required String uid,
    bool Function(String id)? isHabitPaused,
  }) {
    if (!isDatabaseInitialized) {
      return Stream.value(const <StreakLog>[]);
    }
    // Root cause: watchQuery lacked deleted_at filtering on habit_logs and habits, causing
    // soft-deleted rows to remain in the watched result set; filter active rows explicitly.
    final watchQuery = uid.isNotEmpty
        ? 'SELECT id FROM habit_logs WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\') AND (deleted_at IS NULL OR deleted_at = \'\') '
            'UNION ALL '
            'SELECT id FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = \'\') AND (deleted_at IS NULL OR deleted_at = \'\') '
            'UNION ALL '
            'SELECT id FROM prayers WHERE user_id = ? OR user_id IS NULL OR user_id = \'\''
        : 'SELECT id FROM habit_logs WHERE deleted_at IS NULL OR deleted_at = \'\' '
            'UNION ALL SELECT id FROM habits WHERE deleted_at IS NULL OR deleted_at = \'\' '
            'UNION ALL SELECT id FROM prayers';
    final watchParams = uid.isNotEmpty ? [uid, uid, uid] : <dynamic>[];

    return db.watch(watchQuery, parameters: watchParams).asyncMap((_) async {
      return getDailyStreakLogs(uid: uid, isHabitPaused: isHabitPaused);
    });
  }
}

