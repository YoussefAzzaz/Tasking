import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/id_generator.dart';

class FocusRepository {
  Future<void> logFocusSession({
    String? taskId,
    required int durationMin,
    required int xpEarned,
  }) async {
    if (!isDatabaseInitialized) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = IdGenerator.generateDeterministicId(
        'focus_${DateTime.now().microsecondsSinceEpoch}');
    final uid = currentUserId;

    try {
      await db.execute('''
        INSERT INTO focus_sessions (
          id, user_id, task_id, kind, planned_min, actual_min, started_at, ended_at, completed, xp_earned, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        id,
        uid,
        taskId,
        'pomodoro',
        durationMin,
        durationMin,
        now,
        now,
        1,
        xpEarned,
        now,
        now,
      ]).timeout(const Duration(seconds: 4));

      // Award XP in logs
      final logId = IdGenerator.generateDeterministicId('xp_focus_$id');
      final existingLog = await db.getOptional('SELECT id FROM logs WHERE id = ?', [logId]);
      if (existingLog != null) {
        await db.execute('''
          UPDATE logs SET xp_earned = ?, timestamp = ? WHERE id = ?
        ''', [xpEarned, now, logId]).timeout(const Duration(seconds: 4));
      } else {
        await db.execute('''
          INSERT INTO logs (
            id, user_id, task_id, event_type, xp_earned, timestamp
          ) VALUES (?, ?, ?, ?, ?, ?)
        ''', [logId, uid, taskId ?? 'focus_general', 'focus_completed', xpEarned, now]).timeout(const Duration(seconds: 4));
      }

      StatsRepository().invalidateStats();
      await syncGlobalUserLevel();
    } catch (e) {
      debugPrint('[FocusRepository] Error logging focus session: $e');
    }
  }

  /// Live sum of completed focus minutes logged today, keyed on the same
  /// UTC-date prefix convention used by [StatsRepository].
  Stream<int> watchFocusedMinutesToday() {
    if (!isDatabaseInitialized) {
      return Stream.value(0);
    }
    final uid = currentUserId;
    final todayPattern = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final query = uid.isNotEmpty
        ? 'SELECT COALESCE(SUM(actual_min), 0) AS minutes FROM focus_sessions '
            'WHERE completed = 1 AND started_at LIKE ? AND user_id = ?'
        : 'SELECT COALESCE(SUM(actual_min), 0) AS minutes FROM focus_sessions '
            'WHERE completed = 1 AND started_at LIKE ?';
    final params = uid.isNotEmpty ? [todayPattern, uid] : [todayPattern];

    return db.watch(query, parameters: params).map((rows) {
      if (rows.isEmpty) return 0;
      return (rows.first['minutes'] as num?)?.toInt() ?? 0;
    });
  }
}
