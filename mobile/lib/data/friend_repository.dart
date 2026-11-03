import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _toBool(dynamic val) {
  if (val == null) return false;
  if (val is bool) return val;
  if (val is num) return val.toInt() == 1;
  if (val is String) {
    final s = val.trim().toLowerCase();
    return s == '1' || s == 'true';
  }
  return false;
}

int _toInt(dynamic val, [int fallback = 0]) {
  if (val == null) return fallback;
  if (val is num) return val.toInt();
  if (val is String) return int.tryParse(val) ?? fallback;
  return fallback;
}

/// Data model representing a connected friend or incoming friend request.
class FriendUser {
  final String id;
  final String userId;
  final String name;
  final String title;
  final String avatarColor;
  final String? avatarUrl;
  final int totalXp;
  final int level;
  final String? friendCode;
  final String friendshipId;
  final String status; // 'pending', 'accepted'
  final bool isRequester;

  const FriendUser({
    required this.id,
    required this.userId,
    required this.name,
    this.title = 'Specialist',
    this.avatarColor = '#6366F1',
    this.avatarUrl,
    this.totalXp = 0,
    this.level = 1,
    this.friendCode,
    required this.friendshipId,
    this.status = 'accepted',
    this.isRequester = false,
  });

  factory FriendUser.fromRow(Map<String, dynamic> row, String currentUid) {
    final reqId = row['requester_id']?.toString() ?? '';
    final isReq = reqId == currentUid;
    return FriendUser(
      id: row['profile_id']?.toString() ?? row['friendship_id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? (isReq ? row['addressee_id']?.toString() ?? '' : reqId),
      name: (row['name']?.toString() ?? '').trim().isNotEmpty ? row['name'].toString() : 'Companion',
      title: row['title']?.toString() ?? 'Specialist',
      avatarColor: row['avatar_color']?.toString() ?? '#6366F1',
      avatarUrl: row['avatar_url']?.toString(),
      totalXp: _toInt(row['total_xp']),
      level: _toInt(row['level'], 1),
      friendCode: row['friend_code']?.toString(),
      friendshipId: row['friendship_id']?.toString() ?? '',
      status: row['status']?.toString() ?? 'accepted',
      isRequester: isReq,
    );
  }
}

/// Data model for today's 5 prayers and habit progress for a user.
class DailyPrayerStatus {
  final String id;
  final String userId;
  final String userName;
  final String userAvatarColor;
  final String? userAvatarUrl;
  final String date;
  final bool fajr;
  final bool dhuhr;
  final bool asr;
  final bool maghrib;
  final bool isha;
  final int streakDays;
  final int habitsDone;
  final int habitsTotal;

  const DailyPrayerStatus({
    required this.id,
    required this.userId,
    this.userName = 'Companion',
    this.userAvatarColor = '#6366F1',
    this.userAvatarUrl,
    required this.date,
    this.fajr = false,
    this.dhuhr = false,
    this.asr = false,
    this.maghrib = false,
    this.isha = false,
    this.streakDays = 0,
    this.habitsDone = 0,
    this.habitsTotal = 0,
  });

  int get completedCount =>
      (fajr ? 1 : 0) + (dhuhr ? 1 : 0) + (asr ? 1 : 0) + (maghrib ? 1 : 0) + (isha ? 1 : 0);

  bool isPrayerDone(String prayerCode) {
    switch (prayerCode.toLowerCase()) {
      case 'fajr':
        return fajr;
      case 'dhuhr':
        return dhuhr;
      case 'asr':
        return asr;
      case 'maghrib':
        return maghrib;
      case 'isha':
        return isha;
      default:
        return false;
    }
  }

  factory DailyPrayerStatus.fromRow(Map<String, dynamic> row) {
    return DailyPrayerStatus(
      id: row['id']?.toString() ?? '',
      userId: row['user_id']?.toString() ?? '',
      userName: row['user_name']?.toString() ?? 'Companion',
      userAvatarColor: row['avatar_color']?.toString() ?? '#6366F1',
      userAvatarUrl: row['avatar_url']?.toString(),
      date: row['date']?.toString() ?? '',
      fajr: _toBool(row['fajr']),
      dhuhr: _toBool(row['dhuhr']),
      asr: _toBool(row['asr']),
      maghrib: _toBool(row['maghrib']),
      isha: _toBool(row['isha']),
      streakDays: _toInt(row['streak_days']),
      habitsDone: _toInt(row['habits_done']),
      habitsTotal: _toInt(row['habits_total']),
    );
  }
}

/// Lightweight activity event to inspire mutual consistency.
class FriendActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String userAvatarColor;
  final String eventType;
  final String title;
  final String createdAt;

  const FriendActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatarColor,
    required this.eventType,
    required this.title,
    required this.createdAt,
  });

  factory FriendActivityLog.fromRow(Map<String, dynamic> row) {
    return FriendActivityLog(
      id: (row['id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      userName: (row['user_name'] as String?) ?? 'Companion',
      userAvatarColor: (row['avatar_color'] as String?) ?? '#6366F1',
      eventType: (row['event_type'] as String?) ?? 'prayer_done',
      title: (row['title'] as String?) ?? '',
      createdAt: (row['created_at'] as String?) ?? '',
    );
  }
}

/// Centralized repository handling friendships, daily prayer checklists,
/// and gentle mutual accountability across mobile and desktop.
class FriendRepository {
  static final FriendRepository _instance = FriendRepository._internal();
  factory FriendRepository() => _instance;
  FriendRepository._internal();

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String get currentUserId {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null && uid.isNotEmpty) return uid;
    } catch (_) {}
    return AuthService().currentUserId ?? '';
  }

  /// Watches all accepted friends with their profiles and current levels.
  Stream<List<FriendUser>> watchAcceptedFriends() {
    if (!isDatabaseInitialized) {
      return Stream.value(const []);
    }

    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    const query = '''
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
      ORDER BY p.total_xp DESC
    ''';

    return db.watch(query, parameters: [uid, uid, uid]).map((rows) {
      return rows.map((r) => FriendUser.fromRow(r, uid)).toList();
    });
  }

  /// Watches pending incoming friend requests for the current user.
  Stream<List<FriendUser>> watchPendingRequests() {
    if (!isDatabaseInitialized) {
      return Stream.value(const []);
    }

    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    const query = '''
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
      LEFT JOIN user_profiles p ON p.user_id = f.requester_id
      WHERE f.addressee_id = ? AND f.status = 'pending'
      ORDER BY f.created_at DESC
    ''';

    return db.watch(query, parameters: [uid]).map((rows) {
      return rows.map((r) => FriendUser.fromRow(r, uid)).toList();
    });
  }

  /// Watches today's prayer checklists for current user and all accepted friends.
  Stream<List<DailyPrayerStatus>> watchTodayChecklist([String? dateStr]) {
    if (!isDatabaseInitialized) {
      return Stream.value(const []);
    }

    final date = dateStr ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final uid = currentUserId;

    const query = '''
      SELECT 
        d.id,
        d.user_id,
        COALESCE(p.name, CASE WHEN d.user_id = ? THEN 'You' ELSE 'Companion' END) AS user_name,
        COALESCE(p.avatar_color, '#6366F1') AS avatar_color,
        p.avatar_url,
        d.date,
        d.fajr,
        d.dhuhr,
        d.asr,
        d.maghrib,
        d.isha,
        d.streak_days,
        d.habits_done,
        d.habits_total
      FROM daily_prayer_status d
      LEFT JOIN user_profiles p ON p.user_id = d.user_id
      WHERE d.date = ?
      ORDER BY CASE WHEN d.user_id = ? THEN 0 ELSE 1 END, d.streak_days DESC
    ''';

    return db.watch(query, parameters: [uid, date, uid]).map((rows) {
      return rows.map((r) => DailyPrayerStatus.fromRow(r)).toList();
    });
  }

  /// Sends a friend request given a friend code (e.g. AX-7842) or username.
  Future<bool> sendFriendRequest(String codeOrUsername) async {
    final cleanInput = codeOrUsername.trim();
    if (cleanInput.isEmpty) return false;

    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Must be logged in to add friends');

    final upper = cleanInput.toUpperCase();
    final rawCode = upper.replaceAll('AX-', '').replaceAll('-', '').replaceAll(' ', '');
    final formattedCode = 'AX-$rawCode';

    // 1. Look up profile locally or in Supabase
    String? targetUserId;

    // A. Local SQLite lookup
    if (isDatabaseInitialized) {
      final local = await db.getOptional(
        '''SELECT user_id FROM user_profiles 
           WHERE (UPPER(friend_code) = ? OR UPPER(friend_code) = ? OR UPPER(name) = ? OR (LENGTH(?) >= 4 AND user_id LIKE ?))
             AND user_id != ? LIMIT 1''',
        [upper, formattedCode, upper, rawCode, '${rawCode.toLowerCase()}%', uid],
      );
      if (local != null) {
        targetUserId = local['user_id'] as String?;
      }
    }

    // B. Supabase RPC: search_companion
    if ((targetUserId == null || targetUserId.isEmpty) && _supabaseClient != null) {
      try {
        final rpcRes = await _supabaseClient!.rpc(
          'search_companion',
          params: {'search_query': cleanInput},
        );
        if (rpcRes is List && rpcRes.isNotEmpty) {
          targetUserId = rpcRes.first['user_id'] as String?;
        }
      } catch (e) {
        debugPrint('[FriendRepository] Remote RPC search_companion notice: $e');
      }
    }

    // C. Supabase RPC: send_companion_request directly
    if ((targetUserId == null || targetUserId.isEmpty) && _supabaseClient != null) {
      try {
        final rpcRes = await _supabaseClient!.rpc(
          'send_companion_request',
          params: {'target_code_or_name': cleanInput},
        );
        if (rpcRes is Map && rpcRes['success'] == true) {
          targetUserId = rpcRes['target_user_id'] as String?;
        }
      } catch (e) {
        debugPrint('[FriendRepository] Remote RPC send_companion_request notice: $e');
      }
    }

    // D. Supabase direct table query with multi-condition fallback
    if ((targetUserId == null || targetUserId.isEmpty) && _supabaseClient != null) {
      try {
        final orFilters = <String>[
          'friend_code.ilike.$cleanInput',
          'friend_code.ilike.$formattedCode',
          'name.ilike.$cleanInput',
        ];
        if (rawCode.isNotEmpty) {
          orFilters.add('friend_code.ilike.%$rawCode%');
        }
        if (rawCode.length >= 4) {
          orFilters.add('user_id.ilike.${rawCode.toLowerCase()}%');
        }

        final res = await _supabaseClient!
            .from('user_profiles')
            .select('user_id, friend_code, name')
            .or(orFilters.join(','))
            .neq('user_id', uid)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          targetUserId = res['user_id'] as String?;
        }
      } catch (e) {
        debugPrint('[FriendRepository] Remote direct table lookup notice: $e');
      }
    }

    if (targetUserId == null || targetUserId.isEmpty) {
      return false;
    }

    // 2. Prevent duplicate friend requests
    final friendshipId = IdGenerator.generateDeterministicId('friendship_${uid}_$targetUserId');
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    // Local SQLite write
    if (isDatabaseInitialized) {
      final existing = await db.getOptional(
        'SELECT id FROM friendships WHERE id = ?',
        [friendshipId],
      );
      if (existing != null) {
        await db.execute('''
          UPDATE friendships SET updated_at = ? WHERE id = ?
        ''', [nowUtc, friendshipId]);
      } else {
        await db.execute('''
          INSERT INTO friendships (id, requester_id, addressee_id, status, created_at, updated_at)
          VALUES (?, ?, ?, 'pending', ?, ?)
        ''', [friendshipId, uid, targetUserId, nowUtc, nowUtc]);
      }
    }

    // Supabase remote direct write
    if (_supabaseClient != null) {
      try {
        await _supabaseClient!.from('friendships').upsert({
          'id': friendshipId,
          'requester_id': uid,
          'addressee_id': targetUserId,
          'status': 'pending',
          'created_at': nowUtc,
          'updated_at': nowUtc,
        });
      } catch (e) {
        debugPrint('[FriendRepository] Supabase direct friendship write notice: $e');
      }
    }

    // Fetch and cache target companion profile locally
    unawaited(syncSingleProfileFromRemote(targetUserId));

    return true;
  }

  /// Synchronizes a specific companion profile from Supabase into local SQLite
  Future<void> syncSingleProfileFromRemote(String otherUid) async {
    final client = _supabaseClient;
    if (client == null || otherUid.isEmpty || !isDatabaseInitialized) return;

    try {
      final prof = await client.from('user_profiles').select('*').eq('user_id', otherUid).maybeSingle();
      if (prof != null) {
        final profId = prof['id'] as String? ?? 'prof_$otherUid';
        final name = prof['name'] as String? ?? 'Companion';
        final title = prof['title'] as String? ?? 'Specialist';
        final color = prof['avatar_color'] as String? ?? '#6366F1';
        final url = prof['avatar_url'] as String?;
        final xp = (prof['total_xp'] as num?)?.toInt() ?? 0;
        final lvl = (prof['level'] as num?)?.toInt() ?? 1;
        final hashPart = otherUid.replaceAll('-', '').toUpperCase();
        final fCode = prof['friend_code'] as String? ?? 'AX-${hashPart.length >= 4 ? hashPart.substring(0, 4) : "7842"}';
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        final existing = await db.getOptional('SELECT id FROM user_profiles WHERE user_id = ?', [otherUid]);
        if (existing != null) {
          await db.execute('''
            UPDATE user_profiles SET
              name = ?, title = ?, avatar_color = ?, avatar_url = ?, total_xp = ?, level = ?, friend_code = ?, updated_at = ?
            WHERE user_id = ?
          ''', [name, title, color, url, xp, lvl, fCode, nowUtc, otherUid]);
        } else {
          await db.execute('''
            INSERT INTO user_profiles (id, user_id, name, title, avatar_color, avatar_url, total_xp, level, friend_code, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [profId, otherUid, name, title, color, url, xp, lvl, fCode, nowUtc, nowUtc]);
        }
      }
    } catch (e) {
      debugPrint('[FriendRepository] syncSingleProfileFromRemote notice: $e');
    }
  }

  /// Pulls active friendships and pending requests directly from Supabase for instant real-time sync
  Future<void> syncFriendshipsFromRemote() async {
    final client = _supabaseClient;
    final uid = currentUserId;
    if (client == null || uid.isEmpty || !isDatabaseInitialized) return;

    try {
      final remoteRows = await client
          .from('friendships')
          .select('*')
          .or('requester_id.eq.$uid,addressee_id.eq.$uid');

      for (final r in remoteRows) {
        final fId = r['id'] as String? ?? '';
        final reqId = r['requester_id'] as String? ?? '';
        final addId = r['addressee_id'] as String? ?? '';
        final status = r['status'] as String? ?? 'pending';
        final createdAt = r['created_at'] as String? ?? DateTime.now().toUtc().toIso8601String();
        final updatedAt = r['updated_at'] as String? ?? createdAt;
        if (fId.isEmpty) continue;

        final existing = await db.getOptional('SELECT id FROM friendships WHERE id = ?', [fId]);
        if (existing != null) {
          await db.execute('UPDATE friendships SET status = ?, updated_at = ? WHERE id = ?', [status, updatedAt, fId]);
        } else {
          await db.execute(
            'INSERT INTO friendships (id, requester_id, addressee_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
            [fId, reqId, addId, status, createdAt, updatedAt],
          );
        }

        final otherUid = (reqId == uid) ? addId : reqId;
        unawaited(syncSingleProfileFromRemote(otherUid));
      }
    } catch (e) {
      debugPrint('[FriendRepository] syncFriendshipsFromRemote notice: $e');
    }
  }

  /// Accepts an incoming friend request.
  Future<void> acceptFriendRequest(String friendshipId) async {
    if (!isDatabaseInitialized) return;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await db.execute('''
      UPDATE friendships SET status = 'accepted', updated_at = ? WHERE id = ?
    ''', [nowUtc, friendshipId]);

    if (_supabaseClient != null) {
      try {
        await _supabaseClient!.from('friendships').update({
          'status': 'accepted',
          'updated_at': nowUtc,
        }).eq('id', friendshipId);
      } catch (e) {
        debugPrint('[FriendRepository] Supabase acceptFriendRequest notice: $e');
      }
    }
  }

  /// Declines or removes a friendship.
  Future<void> removeFriendship(String friendshipId) async {
    if (!isDatabaseInitialized) return;
    await db.execute('DELETE FROM friendships WHERE id = ?', [friendshipId]);

    if (_supabaseClient != null) {
      try {
        await _supabaseClient!.from('friendships').delete().eq('id', friendshipId);
      } catch (e) {
        debugPrint('[FriendRepository] Supabase removeFriendship notice: $e');
      }
    }
  }

  /// Synchronizes the current user's prayers and daily habit progress into `daily_prayer_status`
  /// so friends can immediately view today's checklist.
  Future<void> syncMyDailyPrayerStatus() async {
    if (!isDatabaseInitialized) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final nowUtc = now.toUtc().toIso8601String();
    final statusId = IdGenerator.generateDeterministicId('prs_${uid}_$today');

    // Run remote friendships sync in background
    unawaited(syncFriendshipsFromRemote());

    try {
      // 1. Fetch current 5 prayers
      final prayerRows = await db.getAll(
        'SELECT prayer_code, is_done FROM prayers WHERE user_id = ? OR user_id IS NULL OR user_id = \'\'',
        [uid],
      );

      bool fajr = false, dhuhr = false, asr = false, maghrib = false, isha = false;
      for (final r in prayerRows) {
        final code = (r['prayer_code'] as String? ?? '').toLowerCase();
        final done = (r['is_done'] as num?)?.toInt() == 1;
        if (code == 'fajr') fajr = done;
        if (code == 'dhuhr') dhuhr = done;
        if (code == 'asr') asr = done;
        if (code == 'maghrib') maghrib = done;
        if (code == 'isha') isha = done;
      }

      // 2. Fetch habits done count
      final habitRows = await db.getAll(
        'SELECT id FROM habits WHERE (schedule_type = \'daily\' OR schedule_type IS NULL OR schedule_type = \'\') AND (user_id = ? OR user_id IS NULL OR user_id = \'\')',
        [uid],
      );
      final totalDailyHabits = habitRows.length;

      final habitDoneRows = await db.getAll(
        'SELECT DISTINCT habit_id FROM habit_logs WHERE log_date = ? AND status = \'done\' AND (user_id = ? OR user_id IS NULL OR user_id = \'\')',
        [today, uid],
      );
      final doneDailyHabits = habitDoneRows.length;

      // 3. Compute continuous streak days (5/5 prayers)
      final allPrayersDoneToday = fajr && dhuhr && asr && maghrib && isha;
      int streakDays = allPrayersDoneToday ? 1 : 0;
      try {
        final logs = await HabitRepository().getDailyStreakLogs();
        if (logs.isNotEmpty) {
          streakDays = logs.length;
        }
      } catch (_) {}

      // Write locally to SQLite
      final existing = await db.getOptional(
        'SELECT id FROM daily_prayer_status WHERE id = ?',
        [statusId],
      );

      if (existing != null) {
        await db.execute('''
          UPDATE daily_prayer_status SET
            fajr = ?,
            dhuhr = ?,
            asr = ?,
            maghrib = ?,
            isha = ?,
            streak_days = ?,
            habits_done = ?,
            habits_total = ?,
            updated_at = ?
          WHERE id = ?
        ''', [
          fajr ? 1 : 0,
          dhuhr ? 1 : 0,
          asr ? 1 : 0,
          maghrib ? 1 : 0,
          isha ? 1 : 0,
          streakDays,
          doneDailyHabits,
          totalDailyHabits,
          nowUtc,
          statusId,
        ]);
      } else {
        await db.execute('''
          INSERT INTO daily_prayer_status (
            id, user_id, date, fajr, dhuhr, asr, maghrib, isha, streak_days, habits_done, habits_total, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          statusId,
          uid,
          today,
          fajr ? 1 : 0,
          dhuhr ? 1 : 0,
          asr ? 1 : 0,
          maghrib ? 1 : 0,
          isha ? 1 : 0,
          streakDays,
          doneDailyHabits,
          totalDailyHabits,
          nowUtc,
          nowUtc,
        ]);
      }

      // Also sync to Supabase remote daily_prayer_status
      if (_supabaseClient != null) {
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
          });

          // Pull friends' today's prayer status
          final remoteStatuses = await _supabaseClient!
              .from('daily_prayer_status')
              .select('*')
              .eq('date', today);

          for (final row in remoteStatuses) {
            final rId = row['id'] as String? ?? '';
            final rUid = row['user_id'] as String? ?? '';
            if (rId.isEmpty || rUid == uid) continue;

            final existingStatus = await db.getOptional('SELECT id FROM daily_prayer_status WHERE id = ?', [rId]);
            if (existingStatus != null) {
              await db.execute('''
                UPDATE daily_prayer_status SET
                  fajr = ?, dhuhr = ?, asr = ?, maghrib = ?, isha = ?,
                  streak_days = ?, habits_done = ?, habits_total = ?, updated_at = ?
                WHERE id = ?
              ''', [
                row['fajr'] == true ? 1 : 0,
                row['dhuhr'] == true ? 1 : 0,
                row['asr'] == true ? 1 : 0,
                row['maghrib'] == true ? 1 : 0,
                row['isha'] == true ? 1 : 0,
                row['streak_days'] ?? 0,
                row['habits_done'] ?? 0,
                row['habits_total'] ?? 0,
                row['updated_at'] ?? nowUtc,
                rId,
              ]);
            } else {
              await db.execute('''
                INSERT INTO daily_prayer_status (
                  id, user_id, date, fajr, dhuhr, asr, maghrib, isha,
                  streak_days, habits_done, habits_total, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''', [
                rId,
                rUid,
                today,
                row['fajr'] == true ? 1 : 0,
                row['dhuhr'] == true ? 1 : 0,
                row['asr'] == true ? 1 : 0,
                row['maghrib'] == true ? 1 : 0,
                row['isha'] == true ? 1 : 0,
                row['streak_days'] ?? 0,
                row['habits_done'] ?? 0,
                row['habits_total'] ?? 0,
                row['created_at'] ?? nowUtc,
                row['updated_at'] ?? nowUtc,
              ]);
            }
          }
        } catch (e) {
          debugPrint('[FriendRepository] Remote daily_prayer_status sync notice: $e');
        }
      }
    } catch (e) {
      debugPrint('[FriendRepository] Error syncing daily prayer status: $e');
    }
  }

  /// Sends a gentle reminder / salam to a friend for an upcoming or pending prayer.
  Future<void> sendPrayerReminder(String friendUserId, String prayerName) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final logId = IdGenerator.generateDeterministicId('nudge_${uid}_${friendUserId}_$nowUtc');

    if (isDatabaseInitialized) {
      await db.execute('''
        INSERT INTO friend_activity_logs (id, user_id, event_type, title, created_at)
        VALUES (?, ?, 'nudge', ?, ?)
      ''', [logId, friendUserId, 'Gentle reminder to pray $prayerName 🕌', nowUtc]);
    }
  }
}
