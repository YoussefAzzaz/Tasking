import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/data/friends/friend_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Helper for prayer status queries, daily habit progress aggregation,
/// streak calculations, and remote Supabase synchronization.
class DailyPrayerSyncHelper {
  const DailyPrayerSyncHelper();

  static const validPrayerCodes = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};

  /// Fetches local SQLite prayers and habit_logs completion state for today.
  Future<Map<String, bool>> fetchLocalPrayerDoneMap({
    required String uid,
    required String today,
  }) async {
    final localPrayerDoneMap = <String, bool>{};
    if (!isDatabaseInitialized) return localPrayerDoneMap;

    try {
      final pRows = await db.getAll(
        '''SELECT 
            p.prayer_code,
            p.is_done,
            p.updated_at,
            (SELECT hl.status FROM habit_logs hl
             WHERE (hl.habit_id = p.id OR hl.habit_id = 'prayer_' || p.prayer_code OR hl.habit_id LIKE '%_' || p.prayer_code)
               AND hl.log_date = ? AND hl.status = 'done' LIMIT 1) as habit_status
           FROM prayers p
           WHERE p.user_id = ? OR p.user_id IS NULL OR p.user_id = '' OR p.user_id = 'local_guest'
           ORDER BY p.sort_order ASC''',
        [today, uid],
      );
      for (final r in pRows) {
        final c = (r['prayer_code'] as String? ?? '').toLowerCase().trim();
        var pDone = parseToBool(r['is_done']);
        if (pDone) {
          final updatedAt = (r['updated_at'] as String?) ?? '';
          if (updatedAt.isNotEmpty) {
            try {
              final updatedLocal = DateTime.parse(updatedAt).toLocal();
              final formattedUpdated = DateFormat('yyyy-MM-dd').format(updatedLocal);
              if (formattedUpdated != today) {
                pDone = false;
              }
            } catch (_) {
              if (!updatedAt.startsWith(today)) {
                pDone = false;
              }
            }
          }
        }
        final hDone = (r['habit_status'] as String?)?.toLowerCase() == 'done';
        final done = pDone || hDone;
        if (!localPrayerDoneMap.containsKey(c) || done) {
          localPrayerDoneMap[c] = done;
        }
      }

      // Direct habit_logs check by pattern
      final doneHabitLogs = await db.getAll(
        'SELECT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\' AND (user_id = ? OR user_id IS NULL OR user_id = \'\' OR user_id = \'local_guest\')',
        [today, uid],
      );
      for (final hl in doneHabitLogs) {
        final hId = (hl['habit_id'] as String? ?? '').toLowerCase();
        for (final pName in validPrayerCodes) {
          if (hId.endsWith(pName) ||
              hId.contains('_${pName}_') ||
              hId.contains('prayer_$pName')) {
            localPrayerDoneMap[pName] = true;
          }
        }
      }
    } catch (e) {
      debugPrint('[DailyPrayerSyncHelper] local prayer query notice: $e');
    }

    return localPrayerDoneMap;
  }

  /// Computes total and completed daily habits count for today.
  Future<({int total, int done})> computeDailyHabitsProgress({
    required String uid,
    required String today,
    int? fallbackTotal,
    int? fallbackDone,
  }) async {
    int habitsTotal = 0;
    int habitsDone = 0;

    if (isDatabaseInitialized) {
      try {
        var habitRows = await db.getAll(
          uid.isNotEmpty
              ? "SELECT id, kind, schedule_type, is_enabled FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest') AND (deleted_at IS NULL OR deleted_at = '') AND LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND (is_enabled IS NULL OR is_enabled != 0)"
              : "SELECT id, kind, schedule_type, is_enabled FROM habits WHERE (deleted_at IS NULL OR deleted_at = '') AND LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND (is_enabled IS NULL OR is_enabled != 0)",
          uid.isNotEmpty ? [uid] : <dynamic>[],
        );
        if (habitRows.isEmpty) {
          habitRows = await db.getAll(
            uid.isNotEmpty
                ? "SELECT id, kind, schedule_type, is_enabled FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest') AND LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND (is_enabled IS NULL OR is_enabled != 0)"
                : "SELECT id, kind, schedule_type, is_enabled FROM habits WHERE LOWER(COALESCE(schedule_type, 'daily')) = 'daily' AND (is_enabled IS NULL OR is_enabled != 0)",
            uid.isNotEmpty ? [uid] : <dynamic>[],
          );
        }
        final validHabitIds = <String>{};
        for (final h in habitRows) {
          final hId = (h['id'] as String? ?? '').trim();
          final kind = (h['kind'] as String? ?? '').toLowerCase().trim();
          if (!HabitRepository.isPrayerIdentifier(hId) &&
              kind != 'prayers' &&
              kind != 'prayer' &&
              !HabitRepository.isHabitPaused(hId) &&
              !hId.startsWith('prayer_') &&
              !hId.startsWith('habit_prayer_')) {
            validHabitIds.add(hId);
          }
        }
        habitsTotal = validHabitIds.length;

        final habitDoneRows = await db.getAll(
          uid.isNotEmpty
              ? 'SELECT DISTINCT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\' AND (user_id = ? OR user_id IS NULL OR user_id = \'\' OR user_id = \'local_guest\')'
              : 'SELECT DISTINCT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\'',
          uid.isNotEmpty ? [today, uid] : [today],
        );
        habitsDone = habitDoneRows.where((r) {
          final id = (r['habit_id'] as String? ?? '').trim();
          return validHabitIds.contains(id);
        }).length;
      } catch (e) {
        debugPrint('[DailyPrayerSyncHelper] Error computing habits: $e');
      }
    }

    if (habitsTotal == 0 && fallbackTotal != null && fallbackTotal > 0) {
      habitsTotal = fallbackTotal;
    }
    if (habitsDone == 0 && fallbackDone != null && fallbackDone > 0) {
      habitsDone = fallbackDone;
    }

    return (total: habitsTotal, done: habitsDone);
  }

  /// Calculates effective streak combining habit streak, consecutive prayer streak, and existing streak.
  Future<int> computeEffectiveStreak({
    required String uid,
    required String today,
    required bool allPrayersDoneToday,
    int? localExistingStreak,
  }) async {
    int streakDays = 0;
    try {
      final streakLogs = await HabitRepository().getDailyStreakLogs();
      streakDays = StreakEngine.calculateStreak('daily', streakLogs, today);
    } catch (_) {}

    try {
      final stats = await StatsRepository().getUserStats();
      if (stats.streakDays > streakDays) {
        streakDays = stats.streakDays;
      }
    } catch (_) {}

    int prayerStreak = allPrayersDoneToday ? 1 : 0;
    if (isDatabaseInitialized) {
      try {
        final historyRows = await db.getAll(
          '''SELECT date, fajr, dhuhr, asr, maghrib, isha 
             FROM daily_prayer_status 
             WHERE user_id = ? AND date < ? 
             ORDER BY date DESC LIMIT 60''',
          [uid, today],
        );
        var checkDate = DateTime.parse(today).subtract(const Duration(days: 1));
        for (final r in historyRows) {
          final rDateStr = r['date']?.toString() ?? '';
          final expectedDateStr = DateFormat('yyyy-MM-dd').format(checkDate);
          if (rDateStr != expectedDateStr) break;
          final rAllDone = parseToBool(r['fajr']) &&
              parseToBool(r['dhuhr']) &&
              parseToBool(r['asr']) &&
              parseToBool(r['maghrib']) &&
              parseToBool(r['isha']);
          if (rAllDone) {
            prayerStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
      } catch (_) {}
    }

    final existingStreak = localExistingStreak ?? 0;
    return [streakDays, prayerStreak, existingStreak].reduce((a, b) => a > b ? a : b);
  }

  /// Writes daily prayer status to SQLite ensuring PowerSync view compatibility.
  Future<void> writeLocalDailyPrayerStatus({
    required String statusId,
    required String uid,
    required String today,
    required String nowUtc,
    required bool fajr,
    required bool dhuhr,
    required bool asr,
    required bool maghrib,
    required bool isha,
    required int streakDays,
    required int habitsDone,
    required int habitsTotal,
  }) async {
    if (!isDatabaseInitialized) return;
    try {
      final existing = await db.getOptional(
        'SELECT id FROM daily_prayer_status WHERE id = ? OR (user_id = ? AND date = ?)',
        [statusId, uid, today],
      );
      if (existing != null) {
        await db.execute(
          'UPDATE daily_prayer_status SET date = ?, fajr = ?, dhuhr = ?, asr = ?, maghrib = ?, isha = ?, streak_days = ?, habits_done = ?, habits_total = ?, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
          [today, fajr ? 1 : 0, dhuhr ? 1 : 0, asr ? 1 : 0, maghrib ? 1 : 0, isha ? 1 : 0, streakDays, habitsDone, habitsTotal, nowUtc, statusId, uid, today],
        );
      } else {
        try {
          await db.execute('''
            INSERT INTO daily_prayer_status (
              id, user_id, date, fajr, dhuhr, asr, maghrib, isha, streak_days, habits_done, habits_total, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [statusId, uid, today, fajr ? 1 : 0, dhuhr ? 1 : 0, asr ? 1 : 0, maghrib ? 1 : 0, isha ? 1 : 0, streakDays, habitsDone, habitsTotal, nowUtc, nowUtc]);
        } catch (_) {
          await db.execute(
            'UPDATE daily_prayer_status SET date = ?, fajr = ?, dhuhr = ?, asr = ?, maghrib = ?, isha = ?, streak_days = ?, habits_done = ?, habits_total = ?, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
            [today, fajr ? 1 : 0, dhuhr ? 1 : 0, asr ? 1 : 0, maghrib ? 1 : 0, isha ? 1 : 0, streakDays, habitsDone, habitsTotal, nowUtc, statusId, uid, today],
          );
        }
      }
    } catch (e) {
      debugPrint('[DailyPrayerSyncHelper] SQLite write notice: $e');
    }
  }

  /// Synchronizes prayer toggle to Supabase using RPC or fallback.
  Future<void> syncRemotePrayerToggle({
    required SupabaseClient client,
    required String uid,
    required String today,
    required String nowUtc,
    required String statusId,
    required String prayerCode,
    required bool isDone,
    required bool curFajr,
    required bool curDhuhr,
    required bool curAsr,
    required bool curMaghrib,
    required bool curIsha,
    required int streakDays,
    required int habitsDone,
    required int habitsTotal,
  }) async {
    try {
      final rpcRes = await client.rpc('toggle_user_prayer', params: {
        'p_code': prayerCode,
        'p_done': isDone,
        'p_date': today,
        'p_streak': streakDays,
        'p_habits_done': habitsDone,
        'p_habits_total': habitsTotal,
      }).timeout(const Duration(seconds: 5));
      debugPrint('[DailyPrayerSyncHelper] Atomic toggle_user_prayer RPC success: $prayerCode=$isDone -> $rpcRes');
    } catch (e) {
      debugPrint('[DailyPrayerSyncHelper] RPC toggle_user_prayer fallback notice: $e');
      try {
        final updated = await client
            .from('daily_prayer_status')
            .update({
              prayerCode: isDone,
              'streak_days': streakDays,
              'habits_done': habitsDone,
              'habits_total': habitsTotal,
              'updated_at': nowUtc,
            })
            .eq('user_id', uid)
            .eq('date', today)
            .select('id')
            .timeout(const Duration(seconds: 5));
        if (updated.isEmpty) {
          await client.from('daily_prayer_status').upsert({
            'id': statusId,
            'user_id': uid,
            'date': today,
            'fajr': curFajr,
            'dhuhr': curDhuhr,
            'asr': curAsr,
            'maghrib': curMaghrib,
            'isha': curIsha,
            'streak_days': streakDays,
            'habits_done': habitsDone,
            'habits_total': habitsTotal,
            'updated_at': nowUtc,
          }, onConflict: 'user_id,date').timeout(const Duration(seconds: 5));
        }
      } catch (err) {
        debugPrint('[DailyPrayerSyncHelper] Supabase fallback update/upsert error: $err');
      }
    }
  }

  /// Resets daily prayer flags to false both in SQLite and Supabase.
  Future<void> resetDailyPrayers({
    required String uid,
    required String today,
    required String nowUtc,
    required String statusId,
    required SupabaseClient? supabaseClient,
    required bool isRemoteAuthenticated,
  }) async {
    if (isDatabaseInitialized) {
      try {
        await db.execute(
          'UPDATE daily_prayer_status SET fajr = 0, dhuhr = 0, asr = 0, maghrib = 0, isha = 0, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
          [nowUtc, statusId, uid, today],
        );
      } catch (e) {
        debugPrint('[DailyPrayerSyncHelper] Error resetting daily_prayer_status in SQLite: $e');
      }
    }

    if (isRemoteAuthenticated && supabaseClient != null) {
      try {
        await supabaseClient.rpc('reset_user_prayers', params: {'p_date': today});
      } catch (e) {
        try {
          await supabaseClient.from('daily_prayer_status').update({
            'fajr': false,
            'dhuhr': false,
            'asr': false,
            'maghrib': false,
            'isha': false,
            'updated_at': nowUtc,
          }).match({'user_id': uid, 'date': today});
        } catch (err) {
          debugPrint('[DailyPrayerSyncHelper] Error resetting daily_prayer_status in Supabase: $err');
        }
      }
    }
  }
}
