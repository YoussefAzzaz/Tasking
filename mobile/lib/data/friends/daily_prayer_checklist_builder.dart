import 'dart:async';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/data/friends/friend_models.dart';
import 'package:axis/data/friends/friend_search_repository.dart';
import 'package:axis/data/daily_prayer_status_repository.dart';

/// Builder responsible for computing the active user's daily prayer and habit checklist.
///
/// Under Method 1 (Direct Supabase Native Realtime Stream), companion prayers are streamed
/// cloud-natively by [CompanionPrayerService], while the active user's status is computed
/// authoritatively from their local SQLite machine (100% offline-compatible).
class DailyPrayerChecklistBuilder {
  const DailyPrayerChecklistBuilder();

  /// Computes the active user's daily prayer status from authoritative local machine state.
  Future<DailyPrayerStatus> computeMyStatus({
    required String date,
    required String uid,
    required String currentUserName,
  }) async {
    final myProfile = UserProfileRepository().profileNotifier.value;
    bool fDone = false, dDone = false, aDone = false, mDone = false, iDone = false;

    if (isDatabaseInitialized) {
      final myPrayerRows = await db.getAll(
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
        [date, uid],
      );
      for (final p in myPrayerRows) {
        final code = (p['prayer_code'] as String? ?? '').toLowerCase().trim();
        var pDone = (p['is_done'] as num?)?.toInt() == 1 || p['is_done'] == true;
        if (pDone) {
          final updatedAt = (p['updated_at'] as String?) ?? '';
          if (updatedAt.isNotEmpty) {
            try {
              final updatedLocal = DateTime.parse(updatedAt).toLocal();
              final formattedUpdated = DateFormat('yyyy-MM-dd').format(updatedLocal);
              if (formattedUpdated != date) {
                pDone = false;
              }
            } catch (_) {
              if (!updatedAt.startsWith(date)) {
                pDone = false;
              }
            }
          }
        }
        final hDone = (p['habit_status'] as String?)?.toLowerCase() == 'done';
        final done = pDone || hDone;
        if (code == 'fajr' && done) fDone = true;
        if (code == 'dhuhr' && done) dDone = true;
        if (code == 'asr' && done) aDone = true;
        if (code == 'maghrib' && done) mDone = true;
        if (code == 'isha' && done) iDone = true;
      }

      // Merge completions, streak, and habit counts from local daily_prayer_status
      try {
        final myStatusRow = await db.getOptional(
          "SELECT fajr, dhuhr, asr, maghrib, isha, streak_days, habits_done, habits_total FROM daily_prayer_status WHERE (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest') AND date = ?",
          [uid, date],
        );
        if (myStatusRow != null) {
          if (parseToBool(myStatusRow['fajr'])) fDone = true;
          if (parseToBool(myStatusRow['dhuhr'])) dDone = true;
          if (parseToBool(myStatusRow['asr'])) aDone = true;
          if (parseToBool(myStatusRow['maghrib'])) mDone = true;
          if (parseToBool(myStatusRow['isha'])) iDone = true;
        }
      } catch (_) {}
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (date == todayStr) {
      final cache = DailyPrayerStatusRepository().currentUserPrayerCache;
      if (cache.containsKey('fajr')) fDone = cache['fajr']!;
      if (cache.containsKey('dhuhr')) dDone = cache['dhuhr']!;
      if (cache.containsKey('asr')) aDone = cache['asr']!;
      if (cache.containsKey('maghrib')) mDone = cache['maghrib']!;
      if (cache.containsKey('isha')) iDone = cache['isha']!;
    }

    int doneDailyHabits = 0;
    int totalDailyHabits = 0;
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
              !hId.startsWith('prayer_') &&
              !hId.startsWith('habit_prayer_')) {
            validHabitIds.add(hId);
          }
        }
        totalDailyHabits = validHabitIds.length;

        final habitDoneRows = await db.getAll(
          uid.isNotEmpty
              ? 'SELECT DISTINCT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\' AND (user_id = ? OR user_id IS NULL OR user_id = \'\' OR user_id = \'local_guest\')'
              : 'SELECT DISTINCT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\'',
          uid.isNotEmpty ? [date, uid] : [date],
        );
        doneDailyHabits = habitDoneRows.where((r) {
          final id = (r['habit_id'] as String? ?? '').trim();
          return validHabitIds.contains(id);
        }).length;
      } catch (_) {}
    }

    int actualStreak = 0;
    try {
      final streakLogs = await HabitRepository().getDailyStreakLogs();
      actualStreak = StreakEngine.calculateStreak('daily', streakLogs, date);
    } catch (_) {}
    try {
      final stats = await StatsRepository().getUserStats();
      if (stats.streakDays > actualStreak) {
        actualStreak = stats.streakDays;
      }
    } catch (_) {}

    int prayerStreak = (fDone && dDone && aDone && mDone && iDone) ? 1 : 0;
    if (isDatabaseInitialized) {
      try {
        final historyRows = await db.getAll(
          '''SELECT date, fajr, dhuhr, asr, maghrib, isha 
             FROM daily_prayer_status 
             WHERE (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest') AND date < ? 
             ORDER BY date DESC LIMIT 60''',
          [uid, date],
        );
        var checkDate = DateTime.parse(date).subtract(const Duration(days: 1));
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
    if (prayerStreak > actualStreak) actualStreak = prayerStreak;

    if (isDatabaseInitialized) {
      try {
        final currentStatus = await db.getOptional(
          "SELECT streak_days, habits_done, habits_total FROM daily_prayer_status WHERE (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest') AND date = ?",
          [uid, date],
        );
        if (currentStatus != null) {
          final s = parseToInt(currentStatus['streak_days']);
          if (s > actualStreak) actualStreak = s;
          if (totalDailyHabits == 0) {
            totalDailyHabits = parseToInt(currentStatus['habits_total']);
          }
          if (doneDailyHabits == 0) {
            doneDailyHabits = parseToInt(currentStatus['habits_done']);
          }
        }
      } catch (_) {}
    }

    return DailyPrayerStatus(
      id: 'prs_${uid}_$date',
      userId: uid,
      userName: currentUserName.isNotEmpty && currentUserName != 'Companion'
          ? currentUserName
          : (myProfile.name.isNotEmpty && myProfile.name != 'Commander' ? myProfile.name : 'You'),
      userAvatarColor: myProfile.avatarColor,
      userAvatarUrl: myProfile.avatarUrl,
      date: date,
      fajr: fDone,
      dhuhr: dDone,
      asr: aDone,
      maghrib: mDone,
      isha: iDone,
      streakDays: actualStreak,
      habitsDone: doneDailyHabits,
      habitsTotal: totalDailyHabits,
    );
  }

  /// Aggregates current user and companions' daily prayer checklists.
  Future<List<DailyPrayerStatus>> computeTodayChecklist({
    required String date,
    required String uid,
    required String currentUserName,
    Map<String, DailyPrayerStatus>? inMemoryFriendPrayerCache,
    bool isRemoteAuthenticated = false,
    Future<void> Function()? onMissingCurrentUserStatus,
    Future<void> Function()? onMissingFriendStatus,
  }) async {
    final myStatus = await computeMyStatus(
      date: date,
      uid: uid,
      currentUserName: currentUserName,
    );

    if (!isDatabaseInitialized || uid.isEmpty) {
      return [myStatus];
    }

    const friendsQuery = '''
      SELECT 
        f.id AS friendship_id,
        f.requester_id,
        f.addressee_id,
        f.status,
        p.id AS profile_id,
        p.user_id,
        COALESCE(p.name, 'Companion') AS name,
        COALESCE(p.title, 'Specialist') AS title,
        COALESCE(p.avatar_color, '#6366F1') AS avatar_color,
        p.avatar_url,
        COALESCE(p.total_xp, 0) AS total_xp,
        COALESCE(p.level, 1) AS level,
        p.friend_code
      FROM friendships f
      LEFT JOIN user_profiles p ON p.user_id = CASE WHEN f.requester_id = ? THEN f.addressee_id ELSE f.requester_id END
      WHERE (f.requester_id = ? OR f.addressee_id = ?) AND f.status = 'accepted'
    ''';

    List<Map<String, dynamic>> friendRows = const [];
    try {
      friendRows = await db.getAll(friendsQuery, [uid, uid, uid]);
    } catch (_) {}

    if (friendRows.isEmpty && isRemoteAuthenticated) {
      unawaited(FriendSearchRepository().syncFriendshipsFromRemote());
    }

    final friendStatuses = <DailyPrayerStatus>[];
    final profileCache = FriendSearchRepository().inMemoryProfileCache;
    final seenUserIds = <String>{};

    for (final r in friendRows) {
      final reqId = r['requester_id']?.toString() ?? '';
      final addId = r['addressee_id']?.toString() ?? '';
      final companionUid = reqId == uid ? addId : reqId;
      if (companionUid.isEmpty || companionUid == uid || seenUserIds.contains(companionUid)) {
        continue;
      }
      seenUserIds.add(companionUid);

      final prof = profileCache[companionUid];
      final dbName = (r['name']?.toString() ?? '').trim();
      final effectiveName = (prof?['name']?.toString() ?? '').trim().isNotEmpty
          ? prof!['name'].toString()
          : (dbName.isNotEmpty && dbName != 'Companion' ? dbName : 'Companion');

      final effectiveColor = prof?['avatar_color']?.toString() ??
          (r['avatar_color']?.toString() ?? '#6366F1');
      final effectiveAvatarUrl = prof?['avatar_url']?.toString() ??
          r['avatar_url']?.toString();

      int effectiveLevel = parseToInt(r['level'], 1);
      if (prof != null && prof['level'] != null) {
        final profLvl = parseToInt(prof['level'], 1);
        if (profLvl > effectiveLevel) effectiveLevel = profLvl;
      }

      final status = DailyPrayerStatus(
        id: 'prs_${companionUid}_$date',
        userId: companionUid,
        userName: effectiveName,
        userAvatarColor: effectiveColor,
        userAvatarUrl: effectiveAvatarUrl,
        date: date,
        level: effectiveLevel,
      );

      friendStatuses.add(status);
    }

    friendStatuses.sort((a, b) => b.level.compareTo(a.level));
    return [myStatus, ...friendStatuses];
  }
}
