import 'dart:async';
import 'package:flutter/foundation.dart';
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

  /// Watches the total completed focus minutes logged for today.
  Stream<int> watchTodayFocusMinutes() {
    if (!isDatabaseInitialized) return Stream.value(0);
    final now = DateTime.now();
    final localStartOfDay = DateTime(now.year, now.month, now.day);
    final startOfDay = localStartOfDay.toUtc().toIso8601String();
    final uid = currentUserId;

    final query = uid.isNotEmpty
        ? '''
          SELECT COALESCE(SUM(actual_min), 0) AS total_min
          FROM focus_sessions
          WHERE completed = 1 AND started_at >= ? AND (user_id = ? OR user_id IS NULL OR user_id = '')
          '''
        : '''
          SELECT COALESCE(SUM(actual_min), 0) AS total_min
          FROM focus_sessions
          WHERE completed = 1 AND started_at >= ?
          ''';
    final params = uid.isNotEmpty ? [startOfDay, uid] : [startOfDay];

    return db.watch(query, parameters: params).map((rows) {
      if (rows.isEmpty) return 0;
      return (rows.first['total_min'] as num?)?.toInt() ?? 0;
    }).handleError((e) {
      debugPrint('[FocusRepository] watchTodayFocusMinutes error: $e');
      return 0;
    });
  }

  /// Watches the focus sessions recorded today, joining task title if available.
  Stream<List<Map<String, dynamic>>> watchTodayFocusSessions() {
    if (!isDatabaseInitialized) return Stream.value([]);
    final now = DateTime.now();
    final localStartOfDay = DateTime(now.year, now.month, now.day);
    final startOfDay = localStartOfDay.toUtc().toIso8601String();
    final uid = currentUserId;

    final query = uid.isNotEmpty
        ? '''
          SELECT fs.id, fs.task_id, fs.actual_min, fs.started_at, fs.ended_at, fs.completed, t.title AS task_title
          FROM focus_sessions fs
          LEFT JOIN tasks t ON fs.task_id = t.id
          WHERE fs.started_at >= ? AND (fs.user_id = ? OR fs.user_id IS NULL OR fs.user_id = '')
          ORDER BY fs.started_at DESC
          '''
        : '''
          SELECT fs.id, fs.task_id, fs.actual_min, fs.started_at, fs.ended_at, fs.completed, t.title AS task_title
          FROM focus_sessions fs
          LEFT JOIN tasks t ON fs.task_id = t.id
          WHERE fs.started_at >= ?
          ORDER BY fs.started_at DESC
          ''';
    final params = uid.isNotEmpty ? [startOfDay, uid] : [startOfDay];

    return db.watch(query, parameters: params).map((rows) {
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    }).handleError((e) {
      debugPrint('[FocusRepository] watchTodayFocusSessions error: $e');
      return <Map<String, dynamic>>[];
    });
  }
}
