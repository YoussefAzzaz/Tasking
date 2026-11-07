import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/data/friends/friend_models.dart';
import 'package:axis/data/friends/daily_prayer_checklist_builder.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Single authoritative repository for daily prayer completion status and companion sync.
class DailyPrayerStatusRepository {
  static final DailyPrayerStatusRepository _instance = DailyPrayerStatusRepository._();
  factory DailyPrayerStatusRepository() => _instance;
  DailyPrayerStatusRepository._();

  final Map<String, bool> _currentUserPrayerCache = {};
  String? _currentUserPrayerCacheDate;
  Future<void>? _pendingPrayerUpdate;

  Map<String, bool> get currentUserPrayerCache => Map.unmodifiable(_currentUserPrayerCache);

  @visibleForTesting
  void setCacheForTesting(String code, bool isDone) {
    _currentUserPrayerCache[code] = isDone;
  }

  final StreamController<void> _checklistTrigger = StreamController<void>.broadcast();
  Stream<void> get checklistTriggerStream => _checklistTrigger.stream;

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isRemoteAuthenticated {
    final client = _supabaseClient;
    if (client == null) return false;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (session != null && user != null && user.id.isNotEmpty && user.id != 'local_guest') {
      return true;
    }
    final savedUid = AuthService().currentUserId;
    return savedUid != null && savedUid.isNotEmpty && savedUid != 'local_guest';
  }

  String get currentUserId {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    return AuthService().currentUserId ?? '';
  }

  String get currentUserName {
    try {
      final profileName = UserProfileRepository().profileNotifier.value.name;
      if (profileName.trim().isNotEmpty && profileName != 'Commander') {
        return profileName;
      }
    } catch (_) {}
    try {
      final authName = Supabase.instance.client.auth.currentUser?.userMetadata?['name']?.toString();
      if (authName != null && authName.trim().isNotEmpty) return authName;
    } catch (_) {}
    final authServiceDisplayName = AuthService().displayName;
    if (authServiceDisplayName.trim().isNotEmpty) {
      return authServiceDisplayName;
    }
    return 'Companion';
  }

  void notifyChecklistChanged() {
    if (!_checklistTrigger.isClosed) {
      _checklistTrigger.add(null);
    }
  }

  /// Updates a single prayer status atomically in SQLite and Supabase.
  /// Strictly mutates ONLY the specified prayer column and preserves all other completed prayers.
  Future<void> updateSinglePrayerStatus(String prayerCode, bool isDone) async {
    final prev = _pendingPrayerUpdate;
    final completer = Completer<void>();
    _pendingPrayerUpdate = completer.future;
    try {
      if (prev != null) {
        await prev;
      }
      await _executeSinglePrayerStatusUpdate(prayerCode, isDone);
    } finally {
      completer.complete();
    }
  }

  Future<void> _executeSinglePrayerStatusUpdate(String prayerCode, bool isDone) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final code = prayerCode.toLowerCase().trim();
    const validCodes = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};
    if (!validCodes.contains(code)) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final nowUtc = now.toUtc().toIso8601String();
    final statusId = 'prs_${uid}_$today';

    if (_currentUserPrayerCacheDate != today) {
      _currentUserPrayerCache.clear();
      _currentUserPrayerCacheDate = today;
    }

    // Immediately record the user's explicit intent for the toggled prayer
    _currentUserPrayerCache[code] = isDone;

    try {
      // 1. Fetch remote Supabase record for today to preserve already checked prayers
      Map<String, dynamic>? remoteRow;
      final todayUtc = DateFormat('yyyy-MM-dd').format(now.toUtc());
      if (isRemoteAuthenticated && _supabaseClient != null) {
        try {
          final res = await _supabaseClient!
              .from('daily_prayer_status')
              .select('*')
              .eq('user_id', uid)
              .or('date.eq.$today,date.eq.$todayUtc')
              .order('updated_at', ascending: false)
              .limit(1);
          if (res.isNotEmpty) {
            remoteRow = Map<String, dynamic>.from(res.first);
          }
        } catch (e) {
          debugPrint('[DailyPrayerStatusRepository] Supabase pre-fetch notice: $e');
        }
      }

      // 2. Fetch local SQLite daily_prayer_status record for today
      Map<String, dynamic>? localStatusRow;
      if (isDatabaseInitialized) {
        try {
          localStatusRow = await db.getOptional(
            'SELECT fajr, dhuhr, asr, maghrib, isha, streak_days, habits_done, habits_total FROM daily_prayer_status WHERE (user_id = ? OR id = ?) AND (date = ? OR date LIKE ?) ORDER BY updated_at DESC LIMIT 1',
            [uid, statusId, today, '$today%'],
          );
        } catch (_) {}
      }

      // 3. Fetch local SQLite prayers and habit_logs completion state
      final localPrayerDoneMap = <String, bool>{};
      if (isDatabaseInitialized) {
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
            for (final pName in validCodes) {
              if (hId.endsWith(pName) || hId.contains('_${pName}_') || hId.contains('prayer_$pName')) {
                localPrayerDoneMap[pName] = true;
              }
            }
          }
        } catch (e) {
          debugPrint('[DailyPrayerStatusRepository] local prayer query notice: $e');
        }
      }

      // 4. Resolve the definitive boolean state for EACH of the 5 prayers:
      // - The actively toggled prayer `code` STRICTLY equals `isDone`
      // - Non-active prayers retain their completed status if completed in ANY authoritative source
      bool resolvePrayer(String p) {
        if (p == code) {
          return isDone;
        }
        if (_currentUserPrayerCache.containsKey(p)) {
          return _currentUserPrayerCache[p] == true;
        }
        final remoteDone = remoteRow != null && parseToBool(remoteRow[p]);
        final localStatusDone = localStatusRow != null && parseToBool(localStatusRow[p]);
        final localDone = localPrayerDoneMap[p] == true;
        return remoteDone || localStatusDone || localDone;
      }

      final bool curFajr = resolvePrayer('fajr');
      final bool curDhuhr = resolvePrayer('dhuhr');
      final bool curAsr = resolvePrayer('asr');
      final bool curMaghrib = resolvePrayer('maghrib');
      final bool curIsha = resolvePrayer('isha');

      // Update in-memory cache with all 5 definitive values
      _currentUserPrayerCache['fajr'] = curFajr;
      _currentUserPrayerCache['dhuhr'] = curDhuhr;
      _currentUserPrayerCache['asr'] = curAsr;
      _currentUserPrayerCache['maghrib'] = curMaghrib;
      _currentUserPrayerCache['isha'] = curIsha;

      // 5. Calculate streak & habit progress directly from authoritative local sources:
      // Strictly retrieves ONLY daily habits (schedule_type = 'daily' or default)
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
          debugPrint('[DailyPrayerStatusRepository] Error computing habits: $e');
        }
      }

      if (habitsTotal == 0 && localStatusRow != null && parseToInt(localStatusRow['habits_total']) > 0) {
        habitsTotal = parseToInt(localStatusRow['habits_total']);
      }
      if (habitsTotal == 0 && remoteRow != null && parseToInt(remoteRow['habits_total']) > 0) {
        habitsTotal = parseToInt(remoteRow['habits_total']);
      }
      if (habitsDone == 0 && localStatusRow != null && parseToInt(localStatusRow['habits_done']) > 0) {
        habitsDone = parseToInt(localStatusRow['habits_done']);
      }
      if (habitsDone == 0 && remoteRow != null && parseToInt(remoteRow['habits_done']) > 0) {
        habitsDone = parseToInt(remoteRow['habits_done']);
      }

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
      if (localStatusRow != null && parseToInt(localStatusRow['streak_days']) > streakDays) {
        streakDays = parseToInt(localStatusRow['streak_days']);
      }
      if (remoteRow != null && parseToInt(remoteRow['streak_days']) > streakDays) {
        streakDays = parseToInt(remoteRow['streak_days']);
      }

      // 6. Persist to local SQLite daily_prayer_status
      // PowerSync views in SQLite do NOT support ON CONFLICT(id) DO UPDATE (cannot UPSERT a view).
      // We check for existing row and use standard UPDATE or INSERT with catch fallback.
      if (isDatabaseInitialized) {
        try {
          final existing = await db.getOptional(
            'SELECT id FROM daily_prayer_status WHERE id = ? OR (user_id = ? AND date = ?)',
            [statusId, uid, today],
          );
          if (existing != null) {
            await db.execute(
              'UPDATE daily_prayer_status SET date = ?, fajr = ?, dhuhr = ?, asr = ?, maghrib = ?, isha = ?, streak_days = ?, habits_done = ?, habits_total = ?, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
              [today, curFajr ? 1 : 0, curDhuhr ? 1 : 0, curAsr ? 1 : 0, curMaghrib ? 1 : 0, curIsha ? 1 : 0, streakDays, habitsDone, habitsTotal, nowUtc, statusId, uid, today],
            );
          } else {
            try {
              await db.execute('''
                INSERT INTO daily_prayer_status (
                  id, user_id, date, fajr, dhuhr, asr, maghrib, isha, streak_days, habits_done, habits_total, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''', [statusId, uid, today, curFajr ? 1 : 0, curDhuhr ? 1 : 0, curAsr ? 1 : 0, curMaghrib ? 1 : 0, curIsha ? 1 : 0, streakDays, habitsDone, habitsTotal, nowUtc, nowUtc]);
            } catch (_) {
              await db.execute(
                'UPDATE daily_prayer_status SET date = ?, fajr = ?, dhuhr = ?, asr = ?, maghrib = ?, isha = ?, streak_days = ?, habits_done = ?, habits_total = ?, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
                [today, curFajr ? 1 : 0, curDhuhr ? 1 : 0, curAsr ? 1 : 0, curMaghrib ? 1 : 0, curIsha ? 1 : 0, streakDays, habitsDone, habitsTotal, nowUtc, statusId, uid, today],
              );
            }
          }
        } catch (e) {
          debugPrint('[DailyPrayerStatusRepository] SQLite write notice: $e');
        }
      }

      // 7. Authoritatively persist to Supabase:
      // Uses the atomic PostgreSQL function `toggle_user_prayer` to eliminate race conditions,
      // preserve untouched prayer flags server-side, and immediately broadcast via Realtime.
      if (isRemoteAuthenticated && _supabaseClient != null) {
        try {
          final rpcRes = await _supabaseClient!.rpc('toggle_user_prayer', params: {
            'p_code': code,
            'p_done': isDone,
            'p_date': today,
            'p_streak': streakDays,
            'p_habits_done': habitsDone,
            'p_habits_total': habitsTotal,
          });
          debugPrint('[DailyPrayerStatusRepository] Atomic toggle_user_prayer RPC success: $code=$isDone -> $rpcRes');
        } catch (e) {
          debugPrint('[DailyPrayerStatusRepository] RPC toggle_user_prayer fallback notice: $e');
          try {
            await _supabaseClient!.from('daily_prayer_status').upsert({
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
            }, onConflict: 'user_id,date');
            debugPrint('[DailyPrayerStatusRepository] Supabase fallback prayer upsert successful: $code=$isDone');
          } catch (err) {
            debugPrint('[DailyPrayerStatusRepository] Supabase fallback upsert error: $err');
          }
        }
      }

      notifyChecklistChanged();
    } catch (e) {
      debugPrint('[DailyPrayerStatusRepository] Error in updateSinglePrayerStatus: $e');
    }
  }

  /// Synchronizes user prayers and habit progress into daily_prayer_status.
  /// Preserves completed prayer flags from being accidentally wiped.
  Future<void> syncMyDailyPrayerStatus() async {
    if (!isDatabaseInitialized) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final nowUtc = now.toUtc().toIso8601String();
    final statusId = 'prs_${uid}_$today';

    if (_currentUserPrayerCacheDate != today) {
      _currentUserPrayerCache.clear();
      _currentUserPrayerCacheDate = today;
    }

    try {
      await db.execute(
        "UPDATE prayers SET user_id = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')",
        [uid],
      );
      await db.execute(
        "UPDATE habit_logs SET user_id = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')",
        [uid],
      );

      final existing = await db.getOptional(
        'SELECT id, fajr, dhuhr, asr, maghrib, isha, streak_days, habits_done, habits_total FROM daily_prayer_status WHERE id = ? OR (user_id = ? AND date = ?)',
        [statusId, uid, today],
      );

      final prayerRows = await db.getAll(
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

      final prayerMap = <String, bool>{};
      for (final r in prayerRows) {
        final code = (r['prayer_code'] as String? ?? '').toLowerCase();
        var pDone = (r['is_done'] as num?)?.toInt() == 1 || r['is_done'] == true;
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
        final isDone = pDone || hDone;
        if (!prayerMap.containsKey(code) || (!prayerMap[code]! && isDone)) {
          prayerMap[code] = isDone;
        }
      }

      // Pre-fetch remote status so checkoffs from another device are not overwritten
      Map<String, dynamic>? remoteRow;
      if (isRemoteAuthenticated && _supabaseClient != null) {
        try {
          final todayUtc = DateFormat('yyyy-MM-dd').format(now.toUtc());
          final res = await _supabaseClient!
              .from('daily_prayer_status')
              .select('*')
              .eq('user_id', uid)
              .or('date.eq.$today,date.eq.$todayUtc')
              .order('updated_at', ascending: false)
              .limit(1);
          if (res.isNotEmpty) {
            remoteRow = res.first;
          }
        } catch (_) {}
      }

      bool resolvePrayer(String p) {
        if (_currentUserPrayerCache.containsKey(p)) {
          return _currentUserPrayerCache[p] == true;
        }
        final localPrayer = prayerMap[p] == true;
        final localStatus = existing != null && parseToBool(existing[p]);
        final remoteStatus = remoteRow != null && parseToBool(remoteRow[p]);
        return localPrayer || localStatus || remoteStatus;
      }

      final bool fajr = resolvePrayer('fajr');
      final bool dhuhr = resolvePrayer('dhuhr');
      final bool asr = resolvePrayer('asr');
      final bool maghrib = resolvePrayer('maghrib');
      final bool isha = resolvePrayer('isha');

      _currentUserPrayerCache['fajr'] = fajr;
      _currentUserPrayerCache['dhuhr'] = dhuhr;
      _currentUserPrayerCache['asr'] = asr;
      _currentUserPrayerCache['maghrib'] = maghrib;
      _currentUserPrayerCache['isha'] = isha;

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
      int totalDailyHabits = validHabitIds.length;

      final habitDoneRows = await db.getAll(
        uid.isNotEmpty
            ? 'SELECT DISTINCT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\' AND (user_id = ? OR user_id IS NULL OR user_id = \'\' OR user_id = \'local_guest\')'
            : 'SELECT DISTINCT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\'',
        uid.isNotEmpty ? [today, uid] : [today],
      );
      int doneDailyHabits = habitDoneRows.where((r) {
        final id = (r['habit_id'] as String? ?? '').trim();
        return validHabitIds.contains(id);
      }).length;

      if (totalDailyHabits == 0 && existing != null && parseToInt(existing['habits_total']) > 0) {
        totalDailyHabits = parseToInt(existing['habits_total']);
      }
      if (doneDailyHabits == 0 && existing != null && parseToInt(existing['habits_done']) > 0) {
        doneDailyHabits = parseToInt(existing['habits_done']);
      }

      int streakDays = 0;
      try {
        final streakLogs = await HabitRepository().getDailyStreakLogs();
        streakDays = StreakEngine.calculateStreak('daily', streakLogs, today);
      } catch (e) {
        debugPrint('[DailyPrayerStatusRepository] Error calculating habit streak: $e');
      }

      int prayerStreak = (fajr && dhuhr && asr && maghrib && isha) ? 1 : 0;
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

      final existingStreak = existing != null ? parseToInt(existing['streak_days']) : 0;
      streakDays = [streakDays, prayerStreak, existingStreak].reduce((a, b) => a > b ? a : b);

      final hasChanged = existing == null ||
          parseToBool(existing['fajr']) != fajr ||
          parseToBool(existing['dhuhr']) != dhuhr ||
          parseToBool(existing['asr']) != asr ||
          parseToBool(existing['maghrib']) != maghrib ||
          parseToBool(existing['isha']) != isha ||
          parseToInt(existing['streak_days']) != streakDays ||
          parseToInt(existing['habits_done']) != doneDailyHabits ||
          parseToInt(existing['habits_total']) != totalDailyHabits;

      if (hasChanged) {
        final existingCheck = await db.getOptional(
          'SELECT id FROM daily_prayer_status WHERE id = ? OR (user_id = ? AND date = ?)',
          [statusId, uid, today],
        );
        if (existingCheck != null) {
          await db.execute(
            'UPDATE daily_prayer_status SET date = ?, fajr = ?, dhuhr = ?, asr = ?, maghrib = ?, isha = ?, streak_days = ?, habits_done = ?, habits_total = ?, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
            [today, fajr ? 1 : 0, dhuhr ? 1 : 0, asr ? 1 : 0, maghrib ? 1 : 0, isha ? 1 : 0, streakDays, doneDailyHabits, totalDailyHabits, nowUtc, statusId, uid, today],
          );
        } else {
          try {
            await db.execute('''
              INSERT INTO daily_prayer_status (
                id, user_id, date, fajr, dhuhr, asr, maghrib, isha, streak_days, habits_done, habits_total, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [statusId, uid, today, fajr ? 1 : 0, dhuhr ? 1 : 0, asr ? 1 : 0, maghrib ? 1 : 0, isha ? 1 : 0, streakDays, doneDailyHabits, totalDailyHabits, nowUtc, nowUtc]);
          } catch (_) {
            await db.execute(
              'UPDATE daily_prayer_status SET date = ?, fajr = ?, dhuhr = ?, asr = ?, maghrib = ?, isha = ?, streak_days = ?, habits_done = ?, habits_total = ?, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
              [today, fajr ? 1 : 0, dhuhr ? 1 : 0, asr ? 1 : 0, maghrib ? 1 : 0, isha ? 1 : 0, streakDays, doneDailyHabits, totalDailyHabits, nowUtc, statusId, uid, today],
            );
          }
        }

        if (isRemoteAuthenticated && _supabaseClient != null) {
          try {
            await _supabaseClient!.rpc('toggle_user_prayer', params: {
              'p_code': null,
              'p_done': false,
              'p_date': today,
              'p_streak': streakDays,
              'p_habits_done': doneDailyHabits,
              'p_habits_total': totalDailyHabits,
            });
            debugPrint('[DailyPrayerStatusRepository] Supabase atomic progress sync success');
          } catch (e) {
            debugPrint('[DailyPrayerStatusRepository] Supabase atomic progress sync fallback notice: $e');
            try {
              await _supabaseClient!.from('daily_prayer_status').upsert({
                'id': statusId,
                'user_id': uid,
                'date': today,
                'fajr': fajr,
                'dhuhr': dhuhr,
                'asr': asr,
                'maghrib': maghrib,
                'isha': isha,
                'streak_days': streakDays,
                'habits_done': doneDailyHabits,
                'habits_total': totalDailyHabits,
                'updated_at': nowUtc,
              }, onConflict: 'user_id,date');
            } catch (err) {
              debugPrint('[DailyPrayerStatusRepository] Supabase sync notice: $err');
            }
          }
        }
      }

      notifyChecklistChanged();
    } catch (e) {
      debugPrint('[DailyPrayerStatusRepository] Error syncing daily prayer status: $e');
    }
  }

  /// Resets daily prayer status flags for today to false both locally and in Supabase.
  Future<void> resetDailyPrayerStatusForToday([String? userId]) async {
    final uid = userId ?? currentUserId;
    if (uid.isEmpty) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final statusId = 'prs_${uid}_$today';

    _currentUserPrayerCache.clear();
    _currentUserPrayerCacheDate = today;

    if (isDatabaseInitialized) {
      try {
        await db.execute(
          'UPDATE daily_prayer_status SET fajr = 0, dhuhr = 0, asr = 0, maghrib = 0, isha = 0, updated_at = ? WHERE id = ? OR (user_id = ? AND date = ?)',
          [nowUtc, statusId, uid, today],
        );
      } catch (e) {
        debugPrint('[DailyPrayerStatusRepository] Error resetting daily_prayer_status in SQLite: $e');
      }
    }

    if (isRemoteAuthenticated && _supabaseClient != null) {
      try {
        await _supabaseClient!.rpc('reset_user_prayers', params: {
          'p_date': today,
        });
        debugPrint('[DailyPrayerStatusRepository] reset_user_prayers RPC success');
      } catch (e) {
        debugPrint('[DailyPrayerStatusRepository] reset_user_prayers RPC fallback notice: $e');
        try {
          await _supabaseClient!.from('daily_prayer_status').update({
            'fajr': false,
            'dhuhr': false,
            'asr': false,
            'maghrib': false,
            'isha': false,
            'updated_at': nowUtc,
          }).match({'user_id': uid, 'date': today});
        } catch (err) {
          debugPrint('[DailyPrayerStatusRepository] Error resetting daily_prayer_status in Supabase: $err');
        }
      }
    }

    notifyChecklistChanged();
  }

  /// Streams today's prayer checklist:
  /// - Current user's own status is computed authoritatively from their local SQLite machine (offline-capable).
  /// - Companions are queried directly from local SQLite (friendships + user_profiles).
  Stream<List<DailyPrayerStatus>> watchTodayChecklist([String? dateStr]) {
    late StreamController<List<DailyPrayerStatus>> controller;
    StreamSubscription? dbSub;
    StreamSubscription? triggerSub;
    void Function()? authUnlisten;

    Future<void> emitLatest() async {
      if (controller.isClosed) return;
      final activeUid = currentUserId;
      if (activeUid.isEmpty) {
        if (!controller.isClosed) {
          controller.add(const []);
        }
        return;
      }
      final date = dateStr ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
      try {
        final list = await const DailyPrayerChecklistBuilder().computeTodayChecklist(
          date: date,
          uid: activeUid,
          currentUserName: currentUserName,
          isRemoteAuthenticated: isRemoteAuthenticated,
          onMissingCurrentUserStatus: () => syncMyDailyPrayerStatus(),
        );
        if (!controller.isClosed) {
          controller.add(list);
        }
      } catch (e) {
        debugPrint('[DailyPrayerStatusRepository] computeTodayChecklist notice: $e');
        if (!controller.isClosed) {
          controller.add(const []);
        }
      }
    }

    controller = StreamController<List<DailyPrayerStatus>>.broadcast(
      onListen: () {
        emitLatest();

        if (isDatabaseInitialized) {
          try {
            const watchQuery = '''
              SELECT id, updated_at FROM friendships
              UNION ALL
              SELECT id, updated_at FROM user_profiles
              UNION ALL
              SELECT id, updated_at FROM prayers
              UNION ALL
              SELECT id, updated_at FROM habit_logs
              UNION ALL
              SELECT id, updated_at FROM daily_prayer_status
            ''';
            dbSub = db.watch(watchQuery).listen((_) => emitLatest());
          } catch (_) {}
        }

        triggerSub = _checklistTrigger.stream.listen((_) => emitLatest());

        void authListener() => emitLatest();
        AuthService().authStateNotifier.addListener(authListener);
        authUnlisten = () => AuthService().authStateNotifier.removeListener(authListener);
      },
      onCancel: () {
        dbSub?.cancel();
        triggerSub?.cancel();
        authUnlisten?.call();
      },
    );

    return controller.stream;
  }
}
