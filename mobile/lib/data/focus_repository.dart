import 'dart:async';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/id_generator.dart';

class FocusRepository {
  Future<void> logFocusSession({
    String? taskId,
    required int durationMin,
    required int xpEarned,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final id = IdGenerator.generateDeterministicId(
        'focus_${DateTime.now().microsecondsSinceEpoch}');

    try {
      await db.execute('''
        INSERT INTO focus_sessions (
          id, task_id, kind, planned_min, actual_min, started_at, ended_at, completed, xp_earned, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        id,
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
      await db.execute('''
        INSERT OR REPLACE INTO logs (
          id, task_id, event_type, xp_earned, timestamp
        ) VALUES (?, ?, ?, ?, ?)
      ''', [logId, taskId ?? 'focus_general', 'focus_completed', xpEarned, now]).timeout(const Duration(seconds: 4));

      StatsRepository().invalidateStats();
      await syncGlobalUserLevel();
    } catch (_) {}
  }
}
