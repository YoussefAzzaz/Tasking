import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/friends/friend_models.dart';
import 'package:axis/data/friends/daily_prayer_checklist_builder.dart';
import 'package:axis/data/prayer/daily_prayer_sync_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:axis/data/prayer/daily_prayer_sync_helper.dart';

/// Single authoritative repository for daily prayer completion status and companion sync.
class DailyPrayerStatusRepository {
  static final DailyPrayerStatusRepository _instance = DailyPrayerStatusRepository._();
  factory DailyPrayerStatusRepository() => _instance;
  DailyPrayerStatusRepository._();

  final Map<String, bool> _currentUserPrayerCache = {};
  String? _currentUserPrayerCacheDate;
  Future<void>? _pendingPrayerUpdate;
  Future<void> _pendingRemoteUpdate = Future<void>.value();

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
      // 1. Local-first resolution: Use local SQLite and cache as ground truth for instant UI
      // avoiding blocking network pre-fetches that stall offline or slow-connection users.

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

      const syncHelper = DailyPrayerSyncHelper();
      final localPrayerDoneMap = await syncHelper.fetchLocalPrayerDoneMap(uid: uid, today: today);

      // 4. Resolve the definitive boolean state for EACH of the 5 prayers:
      bool resolvePrayer(String p) {
        if (p == code) {
          return isDone;
        }
        if (_currentUserPrayerCache.containsKey(p)) {
          return _currentUserPrayerCache[p] == true;
        }
        final localStatusDone = localStatusRow != null && parseToBool(localStatusRow[p]);
        final localDone = localPrayerDoneMap[p] == true;
        return localStatusDone || localDone;
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
      final habitsProgress = await syncHelper.computeDailyHabitsProgress(
        uid: uid,
        today: today,
        fallbackTotal: localStatusRow != null ? parseToInt(localStatusRow['habits_total']) : null,
        fallbackDone: localStatusRow != null ? parseToInt(localStatusRow['habits_done']) : null,
      );
      final habitsTotal = habitsProgress.total;
      final habitsDone = habitsProgress.done;

      final streakDays = await syncHelper.computeEffectiveStreak(
        uid: uid,
        today: today,
        allPrayersDoneToday: curFajr && curDhuhr && curAsr && curMaghrib && curIsha,
        localExistingStreak: localStatusRow != null ? parseToInt(localStatusRow['streak_days']) : null,
      );

      // 6. Persist to local SQLite daily_prayer_status
      await syncHelper.writeLocalDailyPrayerStatus(
        statusId: statusId,
        uid: uid,
        today: today,
        nowUtc: nowUtc,
        fajr: curFajr,
        dhuhr: curDhuhr,
        asr: curAsr,
        maghrib: curMaghrib,
        isha: curIsha,
        streakDays: streakDays,
        habitsDone: habitsDone,
        habitsTotal: habitsTotal,
      );

      // 7. Authoritatively persist to Supabase asynchronously:
      if (isRemoteAuthenticated && _supabaseClient != null) {
        final originUid = uid;
        _pendingRemoteUpdate = _pendingRemoteUpdate.then((_) async {
          if (currentUserId != originUid) {
            debugPrint('[DailyPrayerStatusRepository] User changed from $originUid to $currentUserId; discarding stale remote toggle.');
            return;
          }
          await syncHelper.syncRemotePrayerToggle(
            client: _supabaseClient!,
            uid: originUid,
            today: today,
            nowUtc: nowUtc,
            statusId: statusId,
            prayerCode: code,
            isDone: isDone,
            curFajr: curFajr,
            curDhuhr: curDhuhr,
            curAsr: curAsr,
            curMaghrib: curMaghrib,
            curIsha: curIsha,
            streakDays: streakDays,
            habitsDone: habitsDone,
            habitsTotal: habitsTotal,
          );
        }).catchError((_) {});
        unawaited(_pendingRemoteUpdate);
      }

      notifyChecklistChanged();
    } catch (e) {
      debugPrint('[DailyPrayerStatusRepository] Error in updateSinglePrayerStatus: $e');
    }
  }

  /// Synchronizes user prayers and habit progress into daily_prayer_status.
  /// Preserves completed prayer flags from being accidentally wiped.
  Future<void> syncMyDailyPrayerStatus({bool notify = true}) async {
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

      const syncHelper = DailyPrayerSyncHelper();
      final habitsProgress = await syncHelper.computeDailyHabitsProgress(
        uid: uid,
        today: today,
        fallbackTotal: existing != null ? parseToInt(existing['habits_total']) : null,
        fallbackDone: existing != null ? parseToInt(existing['habits_done']) : null,
      );
      final totalDailyHabits = habitsProgress.total;
      final doneDailyHabits = habitsProgress.done;

      final streakDays = await syncHelper.computeEffectiveStreak(
        uid: uid,
        today: today,
        allPrayersDoneToday: fajr && dhuhr && asr && maghrib && isha,
        localExistingStreak: existing != null ? parseToInt(existing['streak_days']) : null,
      );

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
        await syncHelper.writeLocalDailyPrayerStatus(
          statusId: statusId,
          uid: uid,
          today: today,
          nowUtc: nowUtc,
          fajr: fajr,
          dhuhr: dhuhr,
          asr: asr,
          maghrib: maghrib,
          isha: isha,
          streakDays: streakDays,
          habitsDone: doneDailyHabits,
          habitsTotal: totalDailyHabits,
        );

        if (isRemoteAuthenticated && _supabaseClient != null) {
          await _pendingRemoteUpdate.timeout(const Duration(seconds: 10), onTimeout: () {});
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

      if (notify) {
        notifyChecklistChanged();
      }
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

    await _pendingRemoteUpdate.timeout(const Duration(seconds: 10), onTimeout: () {});
    await const DailyPrayerSyncHelper().resetDailyPrayers(
      uid: uid,
      today: today,
      nowUtc: nowUtc,
      statusId: statusId,
      supabaseClient: _supabaseClient,
      isRemoteAuthenticated: isRemoteAuthenticated,
    );

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
          onMissingCurrentUserStatus: () => syncMyDailyPrayerStatus(notify: false),
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
