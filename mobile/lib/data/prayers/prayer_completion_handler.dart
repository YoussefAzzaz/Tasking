import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:powersync/powersync.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/daily_prayer_status_repository.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/domain/id_generator.dart';
import 'prayer_repository.dart';

/// Service dedicated to prayer checkoff, EXP gamification, habit log tracking, and companion sync.
class PrayerCompletionHandler {
  static const int kPrayerExpAmount = 25;

  final PowerSyncDatabase Function() _getDb;
  final bool Function() _isInitialized;

  PrayerCompletionHandler({
    PowerSyncDatabase Function()? getDb,
    bool Function()? isInitialized,
  })  : _getDb = getDb ?? (() => db),
        _isInitialized = isInitialized ?? (() => isDatabaseInitialized);

  PowerSyncDatabase get _db => _getDb();
  bool get _ready => _isInitialized();

  /// Extracts the canonical prayer code ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha') from a prayer ID
  static String extractPrayerCode(String prayerId) {
    final lowerId = prayerId.toLowerCase();
    for (final c in ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']) {
      if (lowerId.endsWith(c) || lowerId.contains(c)) {
        return c;
      }
    }
    return 'fajr';
  }

  /// Toggles completion of a single prayer and awards/reverts EXP without recreating any records.
  Future<void> togglePrayer({
    required String prayerId,
    required bool isDone,
    String? userId,
  }) async {
    if (!_ready) return;
    final uid = userId ?? currentUserId;
    final now = DateTime.now();
    final nowUtc = now.toUtc().toIso8601String();
    final today = DateFormat('yyyy-MM-dd').format(now);

    final code = extractPrayerCode(prayerId);
    final canonicalId = PrayerRepository.prayerIdForCode(code, uid);
    final logEventId = IdGenerator.generateDeterministicId('xpevent_${canonicalId}_$today');
    final habitLogId = IdGenerator.generateDeterministicId('habitlog_prayer_${canonicalId}_$today');

    try {
      if (uid.isNotEmpty) {
        // Ensure guest/orphan rows are claimed by active uid
        await _db.execute(
          "UPDATE prayers SET user_id = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')",
          [uid],
        );
        await _db.execute(
          "UPDATE habit_logs SET user_id = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')",
          [uid],
        );
      }

      // 1. Ensure canonical prayer record exists
      final defaultPrayer = PrayerRepository.defaultPrayers(uid).firstWhere((p) => p.prayerCode == code);
      final existingCanonical = await _db.getOptional('SELECT id FROM prayers WHERE id = ?', [canonicalId]);
      if (existingCanonical == null) {
        await _db.execute('''
          INSERT INTO prayers (
            id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          canonicalId,
          uid,
          code,
          defaultPrayer.name,
          defaultPrayer.icon,
          defaultPrayer.time,
          defaultPrayer.sortOrder,
          isDone ? 1 : 0,
          nowUtc,
          nowUtc,
        ]);
      }

      // 2. Update completion state across all matching rows for this prayer code
      await _db.execute('''
        UPDATE prayers SET
          is_done = ?,
          user_id = CASE WHEN user_id IS NULL OR user_id = '' OR user_id = 'local_guest' THEN ? ELSE user_id END,
          updated_at = ?
        WHERE id = ? OR (prayer_code = ? AND (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest'))
      ''', [isDone ? 1 : 0, uid, nowUtc, canonicalId, code, uid]);

      // 3. Purge obsolete non-canonical orphan duplicate rows for this code
      if (uid.isNotEmpty) {
        await _db.execute('''
          DELETE FROM prayers
          WHERE prayer_code = ? AND id != ? AND (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest')
        ''', [code, canonicalId, uid]);
      }

      // 4. Award or remove XP in logs table & sync habit_logs for real-time multi-device sync
      if (isDone) {
        final existingLog = await _db.getOptional('SELECT id FROM logs WHERE id = ?', [logEventId]);
        if (existingLog != null) {
          await _db.execute(
            'UPDATE logs SET xp_earned = ?, timestamp = ? WHERE id = ?',
            [kPrayerExpAmount, nowUtc, logEventId],
          );
        } else {
          await _db.execute('''
            INSERT INTO logs (
              id, user_id, task_id, event_type, xp_earned, timestamp
            ) VALUES (?, ?, ?, 'prayer_completed', ?, ?)
          ''', [logEventId, uid, canonicalId, kPrayerExpAmount, nowUtc]);
        }

        final existingHabitLog = await _db.getOptional('SELECT id FROM habit_logs WHERE id = ?', [habitLogId]);
        if (existingHabitLog != null) {
          await _db.execute(
            'UPDATE habit_logs SET status = ?, value = 1, updated_at = ? WHERE id = ?',
            ['done', nowUtc, habitLogId],
          );
        } else {
          await _db.execute('''
            INSERT INTO habit_logs (
              id, user_id, habit_id, log_date, status, value, created_at, updated_at
            ) VALUES (?, ?, ?, ?, 'done', 1, ?, ?)
          ''', [habitLogId, uid, canonicalId, today, nowUtc, nowUtc]);
        }
      } else {
        await _db.execute('DELETE FROM logs WHERE id = ?', [logEventId]);
        await _db.execute('DELETE FROM habit_logs WHERE id = ?', [habitLogId]);
        final deleteQuery = uid.isNotEmpty
            ? 'DELETE FROM habit_logs WHERE (habit_id = ? OR habit_id = ? OR habit_id LIKE ?) AND log_date = ? AND (user_id = ? OR user_id IS NULL OR user_id = \'\')'
            : 'DELETE FROM habit_logs WHERE (habit_id = ? OR habit_id = ? OR habit_id LIKE ?) AND log_date = ?';
        final deleteParams = uid.isNotEmpty
            ? [canonicalId, prayerId, '%_$code', today, uid]
            : [canonicalId, prayerId, '%_$code', today];
        await _db.execute(deleteQuery, deleteParams);
      }

      // 5. Directly update daily_prayer_status in DailyPrayerStatusRepository for instant atomic sync
      await DailyPrayerStatusRepository().updateSinglePrayerStatus(code, isDone);

      StatsRepository().invalidateStats();
      await syncGlobalUserLevel();
      AppWidgetSyncService().syncHabitStreak();
    } catch (e) {
      debugPrint('[PrayerCompletionHandler] Error toggling prayer: $e');
    }
  }
}
