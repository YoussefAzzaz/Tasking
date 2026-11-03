import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/user_profile_repository.dart';
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
  final String status; // 'none', 'pending', 'accepted'
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

  FriendUser copyWith({
    String? id,
    String? userId,
    String? name,
    String? title,
    String? avatarColor,
    String? avatarUrl,
    int? totalXp,
    int? level,
    String? friendCode,
    String? friendshipId,
    String? status,
    bool? isRequester,
  }) {
    return FriendUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      title: title ?? this.title,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      friendCode: friendCode ?? this.friendCode,
      friendshipId: friendshipId ?? this.friendshipId,
      status: status ?? this.status,
      isRequester: isRequester ?? this.isRequester,
    );
  }

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

/// Lightweight activity event to inspire mutual consistency and notify users.
class FriendActivityLog {
  final String id;
  final String userId;
  final String userName;
  final String userAvatarColor;
  final String eventType; // 'friend_request', 'request_accepted', 'request_declined', 'prayer_reminder', 'nudge', 'prayer_done'
  final String title;
  final Map<String, dynamic> metadata;
  final String createdAt;

  const FriendActivityLog({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatarColor,
    required this.eventType,
    required this.title,
    this.metadata = const {},
    required this.createdAt,
  });

  bool get isFriendRequest => eventType == 'friend_request';
  bool get isRequestAccepted => eventType == 'request_accepted';
  bool get isRequestDeclined => eventType == 'request_declined';
  bool get isPrayerReminder => eventType == 'prayer_reminder' || eventType == 'nudge';

  factory FriendActivityLog.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> meta = {};
    if (row['metadata'] != null) {
      if (row['metadata'] is Map) {
        meta = Map<String, dynamic>.from(row['metadata'] as Map);
      } else if (row['metadata'] is String) {
        try {
          meta = Map<String, dynamic>.from(jsonDecode(row['metadata'] as String));
        } catch (_) {}
      }
    }

    return FriendActivityLog(
      id: (row['id'] as String?) ?? '',
      userId: (row['user_id'] as String?) ?? '',
      userName: (row['user_name'] as String?) ?? (row['sender_name'] as String?) ?? 'Companion',
      userAvatarColor: (row['avatar_color'] as String?) ?? (row['sender_avatar_color'] as String?) ?? '#6366F1',
      eventType: (row['event_type'] as String?) ?? 'prayer_reminder',
      title: (row['title'] as String?) ?? '',
      metadata: meta,
      createdAt: (row['created_at'] as String?) ?? '',
    );
  }
}

/// Centralized repository handling friendships, daily prayer checklists,
/// live notifications, and gentle mutual accountability across mobile and desktop.
class FriendRepository {
  static final FriendRepository _instance = FriendRepository._internal();
  factory FriendRepository() => _instance;
  FriendRepository._internal() {
    _initRealtimeListeners();
  }

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// True only when the client has an active, authenticated Supabase session.
  /// Prevents anonymous/unauthorized REST requests that trigger RLS 42501 violations.
  bool get isRemoteAuthenticated {
    final client = _supabaseClient;
    if (client == null) return false;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    return session != null &&
        user != null &&
        user.id.isNotEmpty &&
        user.id != 'local_guest';
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

  RealtimeChannel? _realtimeChannel;

  void _initRealtimeListeners() {
    final client = _supabaseClient;
    if (client == null || _realtimeChannel != null) return;

    if (!isRemoteAuthenticated) {
      // Defer realtime subscriptions until authenticated
      client.auth.onAuthStateChange.listen((data) {
        if (data.session != null && _realtimeChannel == null) {
          _initRealtimeListeners();
        }
      });
      return;
    }

    try {
      _realtimeChannel = client.channel('public_friends_sync');
      _realtimeChannel?.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friendships',
        callback: (_) {
          debugPrint('[FriendRepository] Realtime: friendships updated');
          unawaited(syncFriendshipsFromRemote());
        },
      ).onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'friend_activity_logs',
        callback: (_) {
          debugPrint('[FriendRepository] Realtime: friend_activity_logs updated');
          unawaited(syncActivityLogsFromRemote());
        },
      ).onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'daily_prayer_status',
        callback: (_) {
          debugPrint('[FriendRepository] Realtime: daily_prayer_status updated');
          unawaited(syncMyDailyPrayerStatus());
        },
      ).subscribe();
    } catch (e) {
      debugPrint('[FriendRepository] Notice setting up Realtime subscription: $e');
    }
  }

  // ===========================================================================
  // STREAMS FOR UI
  // ===========================================================================

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

  /// Watches all standings (CURRENT USER + all accepted friends) sorted by XP.
  Stream<List<FriendUser>> watchAllStandings() {
    if (!isDatabaseInitialized) {
      return Stream.value(const []);
    }

    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    // Query both friends and current user
    return watchAcceptedFriends().asyncMap((friends) async {
      // Fetch current user's profile
      final myProfileRow = await db.getOptional(
        'SELECT id, user_id, name, title, avatar_color, avatar_url, total_xp, level, friend_code FROM user_profiles WHERE user_id = ? LIMIT 1',
        [uid],
      );

      final myName = currentUserName;
      final myUser = FriendUser(
        id: myProfileRow?['id']?.toString() ?? 'prof_$uid',
        userId: uid,
        name: (myProfileRow?['name']?.toString() ?? '').trim().isNotEmpty
            ? myProfileRow!['name'].toString()
            : (myName.isNotEmpty ? myName : 'You'),
        title: myProfileRow?['title']?.toString() ?? 'Specialist',
        avatarColor: myProfileRow?['avatar_color']?.toString() ?? '#6366F1',
        avatarUrl: myProfileRow?['avatar_url']?.toString(),
        totalXp: _toInt(myProfileRow?['total_xp']),
        level: _toInt(myProfileRow?['level'], 1),
        friendCode: myProfileRow?['friend_code']?.toString(),
        friendshipId: 'self',
        status: 'accepted',
        isRequester: false,
      );

      final all = <FriendUser>[myUser, ...friends];
      all.sort((a, b) => b.totalXp.compareTo(a.totalXp));
      return all;
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

  /// Watches in-app friend activity notifications and reminders for the current user.
  Stream<List<FriendActivityLog>> watchFriendActivityLogs() {
    if (!isDatabaseInitialized) {
      return Stream.value(const []);
    }

    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    const query = '''
      SELECT 
        l.id,
        l.user_id,
        l.event_type,
        l.title,
        l.metadata,
        l.created_at,
        COALESCE(p.name, 'Companion') AS sender_name,
        COALESCE(p.avatar_color, '#6366F1') AS sender_avatar_color
      FROM friend_activity_logs l
      LEFT JOIN user_profiles p ON p.user_id = json_extract(l.metadata, '\$.sender_id')
      WHERE l.user_id = ?
      ORDER BY l.created_at DESC
      LIMIT 30
    ''';

    return db.watch(query, parameters: [uid]).map((rows) {
      return rows.map((r) => FriendActivityLog.fromRow(r)).toList();
    });
  }

  /// Clears notifications for the current user.
  Future<void> clearFriendNotifications() async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    if (isDatabaseInitialized) {
      await db.execute('DELETE FROM friend_activity_logs WHERE user_id = ?', [uid]);
    }
    if (isRemoteAuthenticated) {
      try {
        await _supabaseClient!.from('friend_activity_logs').delete().eq('user_id', uid);
      } catch (e) {
        debugPrint('[FriendRepository] Notice clearing notifications on Supabase: $e');
      }
    }
  }

  /// Watches today's prayer checklists for current user and all accepted friends.
  /// Guarantees that EVERY accepted friend appears in the list even if they haven't logged today.
  Stream<List<DailyPrayerStatus>> watchTodayChecklist([String? dateStr]) {
    if (!isDatabaseInitialized) {
      return Stream.value(const []);
    }

    final date = dateStr ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    return watchAcceptedFriends().asyncMap((friends) async {
      // 1. Fetch current user prayer status
      final myRow = await db.getOptional(
        '''SELECT 
            d.id, d.user_id, d.date, d.fajr, d.dhuhr, d.asr, d.maghrib, d.isha,
            d.streak_days, d.habits_done, d.habits_total,
            p.name AS user_name, p.avatar_color, p.avatar_url
           FROM daily_prayer_status d
           LEFT JOIN user_profiles p ON p.user_id = d.user_id
           WHERE d.user_id = ? AND d.date = ?
           LIMIT 1''',
        [uid, date],
      );

      final myName = currentUserName;
      DailyPrayerStatus myStatus;
      if (myRow != null) {
        myStatus = DailyPrayerStatus.fromRow(myRow);
      } else {
        // Fallback placeholder for current user
        myStatus = DailyPrayerStatus(
          id: 'prs_${uid}_$date',
          userId: uid,
          userName: myName.isNotEmpty ? myName : 'You',
          date: date,
        );
      }

      // 2. Fetch or synthesize prayer status for each friend
      final friendStatuses = <DailyPrayerStatus>[];
      for (final f in friends) {
        final fRow = await db.getOptional(
          '''SELECT 
              d.id, d.user_id, d.date, d.fajr, d.dhuhr, d.asr, d.maghrib, d.isha,
              d.streak_days, d.habits_done, d.habits_total
             FROM daily_prayer_status d
             WHERE d.user_id = ? AND d.date = ?
             LIMIT 1''',
          [f.userId, date],
        );

        if (fRow != null) {
          friendStatuses.add(DailyPrayerStatus(
            id: fRow['id']?.toString() ?? 'prs_${f.userId}_$date',
            userId: f.userId,
            userName: f.name,
            userAvatarColor: f.avatarColor,
            userAvatarUrl: f.avatarUrl,
            date: date,
            fajr: _toBool(fRow['fajr']),
            dhuhr: _toBool(fRow['dhuhr']),
            asr: _toBool(fRow['asr']),
            maghrib: _toBool(fRow['maghrib']),
            isha: _toBool(fRow['isha']),
            streakDays: _toInt(fRow['streak_days']),
            habitsDone: _toInt(fRow['habits_done']),
            habitsTotal: _toInt(fRow['habits_total']),
          ));
        } else {
          // Friend has not opened app yet today: display with 0 prayers completed so they are visible
          friendStatuses.add(DailyPrayerStatus(
            id: 'prs_${f.userId}_$date',
            userId: f.userId,
            userName: f.name,
            userAvatarColor: f.avatarColor,
            userAvatarUrl: f.avatarUrl,
            date: date,
            fajr: false,
            dhuhr: false,
            asr: false,
            maghrib: false,
            isha: false,
            streakDays: 0,
            habitsDone: 0,
            habitsTotal: 0,
          ));
        }
      }

      // Sort friends by completed count descending
      friendStatuses.sort((a, b) => b.completedCount.compareTo(a.completedCount));

      // Current user is ALWAYS first in the comparison view
      return [myStatus, ...friendStatuses];
    });
  }

  // ===========================================================================
  // CANDIDATE LOOKUP & ADD FRIEND WORKFLOW
  // ===========================================================================

  /// Searches candidate companion by friend code (e.g. AX-7842 or 7842) or username.
  /// Shows real candidate profile preview with friendship status before sending request.
  Future<FriendUser?> searchCandidateCompanion(String query) async {
    final cleanInput = query.trim();
    if (cleanInput.isEmpty) return null;

    final uid = currentUserId;
    final upper = cleanInput.toUpperCase();
    final rawCode = upper.replaceAll('AX-', '').replaceAll('-', '').replaceAll(' ', '');
    final formattedCode = 'AX-$rawCode';

    Map<String, dynamic>? candidateRow;

    // 1. Search local SQLite
    if (isDatabaseInitialized) {
      candidateRow = await db.getOptional(
        '''SELECT id, user_id, name, title, avatar_color, avatar_url, total_xp, level, friend_code
           FROM user_profiles 
           WHERE (UPPER(friend_code) = ? OR UPPER(friend_code) = ? OR UPPER(name) = ? OR (LENGTH(?) >= 4 AND user_id LIKE ?))
             AND user_id != ? 
           LIMIT 1''',
        [upper, formattedCode, upper, rawCode, '${rawCode.toLowerCase()}%', uid],
      );
    }

    // 2. Query Supabase via search_companion RPC
    if (candidateRow == null && _supabaseClient != null) {
      try {
        final rpcRes = await _supabaseClient!.rpc(
          'search_companion',
          params: {'search_query': cleanInput},
        );
        if (rpcRes is List && rpcRes.isNotEmpty) {
          candidateRow = Map<String, dynamic>.from(rpcRes.first as Map);
        }
      } catch (e) {
        debugPrint('[FriendRepository] search_companion RPC notice: $e');
      }
    }

    // 3. Fallback: Query Supabase user_profiles table directly
    if (candidateRow == null && _supabaseClient != null) {
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
            .select('id, user_id, name, title, avatar_color, avatar_url, total_xp, level, friend_code')
            .or(orFilters.join(','))
            .neq('user_id', uid)
            .limit(1)
            .maybeSingle();

        if (res != null) {
          candidateRow = Map<String, dynamic>.from(res);
        }
      } catch (e) {
        debugPrint('[FriendRepository] Direct user_profiles query notice: $e');
      }
    }

    if (candidateRow == null) return null;

    final targetUid = candidateRow['user_id']?.toString() ?? '';
    if (targetUid.isEmpty || targetUid == uid) return null;

    // Cache candidate profile in local SQLite
    await _cacheProfileLocally(candidateRow);

    // Check existing friendship status
    String existingStatus = 'none';
    String existingFriendshipId = '';
    bool isRequester = false;

    if (isDatabaseInitialized) {
      final fRow = await db.getOptional(
        '''SELECT id, status, requester_id, addressee_id FROM friendships
           WHERE (requester_id = ? AND addressee_id = ?) OR (requester_id = ? AND addressee_id = ?)
           LIMIT 1''',
        [uid, targetUid, targetUid, uid],
      );
      if (fRow != null) {
        existingStatus = fRow['status']?.toString() ?? 'none';
        existingFriendshipId = fRow['id']?.toString() ?? '';
        isRequester = fRow['requester_id']?.toString() == uid;
      }
    }

    if (existingStatus == 'none' && isRemoteAuthenticated) {
      try {
        final remoteF = await _supabaseClient!
            .from('friendships')
            .select('id, status, requester_id, addressee_id')
            .or('and(requester_id.eq.$uid,addressee_id.eq.$targetUid),and(requester_id.eq.$targetUid,addressee_id.eq.$uid)')
            .maybeSingle();
        if (remoteF != null) {
          existingStatus = remoteF['status']?.toString() ?? 'none';
          existingFriendshipId = remoteF['id']?.toString() ?? '';
          isRequester = remoteF['requester_id']?.toString() == uid;
        }
      } catch (_) {}
    }

    return FriendUser(
      id: candidateRow['id']?.toString() ?? 'prof_$targetUid',
      userId: targetUid,
      name: (candidateRow['name']?.toString() ?? '').trim().isNotEmpty
          ? candidateRow['name'].toString()
          : 'Companion',
      title: candidateRow['title']?.toString() ?? 'Specialist',
      avatarColor: candidateRow['avatar_color']?.toString() ?? '#6366F1',
      avatarUrl: candidateRow['avatar_url']?.toString(),
      totalXp: _toInt(candidateRow['total_xp']),
      level: _toInt(candidateRow['level'], 1),
      friendCode: candidateRow['friend_code']?.toString(),
      friendshipId: existingFriendshipId,
      status: existingStatus,
      isRequester: isRequester,
    );
  }

  /// Sends a friend request to a candidate companion.
  Future<bool> sendFriendRequestToCandidate(FriendUser candidate) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Must be logged in to add friends');

    final targetUserId = candidate.userId;
    if (targetUserId.isEmpty || targetUserId == uid) return false;

    final friendshipId = IdGenerator.generateDeterministicId('friendship_${uid}_$targetUserId');
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final myName = currentUserName;

    // 1. Write to local SQLite
    if (isDatabaseInitialized) {
      final existing = await db.getOptional('SELECT id FROM friendships WHERE id = ?', [friendshipId]);
      if (existing != null) {
        await db.execute('UPDATE friendships SET status = \'pending\', updated_at = ? WHERE id = ?', [nowUtc, friendshipId]);
      } else {
        await db.execute(
          'INSERT INTO friendships (id, requester_id, addressee_id, status, created_at, updated_at) VALUES (?, ?, ?, \'pending\', ?, ?)',
          [friendshipId, uid, targetUserId, nowUtc, nowUtc],
        );
      }
    }

    // 2. Direct Supabase write
    if (isRemoteAuthenticated) {
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
        debugPrint('[FriendRepository] Supabase friendship upsert notice: $e');
      }

      // 3. Write notification for candidate in Supabase & SQLite
      final logId = 'log_${uid}_${targetUserId}_${DateTime.now().millisecondsSinceEpoch}';
      final meta = jsonEncode({
        'sender_id': uid,
        'sender_name': myName,
        'friendship_id': friendshipId,
      });

      try {
        await _supabaseClient!.from('friend_activity_logs').insert({
          'id': logId,
          'user_id': targetUserId,
          'event_type': 'friend_request',
          'title': '$myName sent you a companion request',
          'metadata': {
            'sender_id': uid,
            'sender_name': myName,
            'friendship_id': friendshipId,
          },
          'created_at': nowUtc,
        });
      } catch (e) {
        debugPrint('[FriendRepository] Remote friend_request notification notice: $e');
      }

      if (isDatabaseInitialized) {
        try {
          await db.execute(
            'INSERT INTO friend_activity_logs (id, user_id, event_type, title, metadata, created_at) VALUES (?, ?, \'friend_request\', ?, ?, ?)',
            [logId, targetUserId, '$myName sent you a companion request', meta, nowUtc],
          );
        } catch (_) {}
      }
    }

    // Cache candidate profile locally
    unawaited(syncSingleProfileFromRemote(targetUserId));
    return true;
  }

  /// Sends a friend request given a code or username string.
  Future<bool> sendFriendRequest(String codeOrUsername) async {
    final candidate = await searchCandidateCompanion(codeOrUsername);
    if (candidate == null) return false;
    return sendFriendRequestToCandidate(candidate);
  }

  // ===========================================================================
  // REQUEST RESPONSE (ACCEPT / REFUSE)
  // ===========================================================================

  /// Accepts an incoming friend request and notifies the requester.
  Future<void> acceptFriendRequest(String friendshipId, [String? requesterId]) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final myName = currentUserName;

    String reqId = requesterId ?? '';
    if (reqId.isEmpty && isDatabaseInitialized) {
      final row = await db.getOptional('SELECT requester_id FROM friendships WHERE id = ?', [friendshipId]);
      reqId = row?['requester_id']?.toString() ?? '';
    }

    // 1. Update local SQLite
    if (isDatabaseInitialized) {
      await db.execute('UPDATE friendships SET status = \'accepted\', updated_at = ? WHERE id = ?', [nowUtc, friendshipId]);
    }

    // 2. Update Supabase
    if (isRemoteAuthenticated) {
      try {
        await _supabaseClient!.from('friendships').update({
          'status': 'accepted',
          'updated_at': nowUtc,
        }).eq('id', friendshipId);
      } catch (e) {
        debugPrint('[FriendRepository] Supabase acceptFriendRequest update notice: $e');
      }

      // Also call RPC helper if present
      try {
        await _supabaseClient!.rpc('respond_companion_request', params: {
          'p_friendship_id': friendshipId,
          'p_action': 'accept',
        });
      } catch (_) {}

      // 3. Send acceptance notification to requester
      if (reqId.isNotEmpty) {
        final logId = 'log_${uid}_${reqId}_${DateTime.now().millisecondsSinceEpoch}';
        final meta = jsonEncode({
          'sender_id': uid,
          'sender_name': myName,
          'friendship_id': friendshipId,
        });

        try {
          await _supabaseClient!.from('friend_activity_logs').insert({
            'id': logId,
            'user_id': reqId,
            'event_type': 'request_accepted',
            'title': '$myName accepted your companion request! 🎉',
            'metadata': {
              'sender_id': uid,
              'sender_name': myName,
              'friendship_id': friendshipId,
            },
            'created_at': nowUtc,
          });
        } catch (e) {
          debugPrint('[FriendRepository] Remote accept notification notice: $e');
        }

        if (isDatabaseInitialized) {
          try {
            await db.execute(
              'INSERT INTO friend_activity_logs (id, user_id, event_type, title, metadata, created_at) VALUES (?, ?, \'request_accepted\', ?, ?, ?)',
              [logId, reqId, '$myName accepted your companion request! 🎉', meta, nowUtc],
            );
          } catch (_) {}
        }
      }
    }

    if (reqId.isNotEmpty) {
      unawaited(syncSingleProfileFromRemote(reqId));
    }
    unawaited(syncMyDailyPrayerStatus());
  }

  /// Refuses / Declines an incoming friend request and notifies the requester.
  Future<void> declineFriendRequest(String friendshipId, [String? requesterId]) async {
    final uid = currentUserId;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final myName = currentUserName;

    String reqId = requesterId ?? '';
    if (reqId.isEmpty && isDatabaseInitialized) {
      final row = await db.getOptional('SELECT requester_id FROM friendships WHERE id = ?', [friendshipId]);
      reqId = row?['requester_id']?.toString() ?? '';
    }

    // 1. Remove from local SQLite
    if (isDatabaseInitialized) {
      await db.execute('DELETE FROM friendships WHERE id = ?', [friendshipId]);
    }

    // 2. Remove / Update on Supabase
    if (isRemoteAuthenticated) {
      try {
        await _supabaseClient!.from('friendships').delete().eq('id', friendshipId);
      } catch (e) {
        debugPrint('[FriendRepository] Supabase decline delete notice: $e');
      }

      // Also call RPC helper if present
      try {
        await _supabaseClient!.rpc('respond_companion_request', params: {
          'p_friendship_id': friendshipId,
          'p_action': 'decline',
        });
      } catch (_) {}

      // 3. Send decline notification to requester so they know
      if (reqId.isNotEmpty) {
        final logId = 'log_${uid}_${reqId}_${DateTime.now().millisecondsSinceEpoch}';
        final meta = jsonEncode({
          'sender_id': uid,
          'sender_name': myName,
          'friendship_id': friendshipId,
        });

        try {
          await _supabaseClient!.from('friend_activity_logs').insert({
            'id': logId,
            'user_id': reqId,
            'event_type': 'request_declined',
            'title': '$myName declined your companion request',
            'metadata': {
              'sender_id': uid,
              'sender_name': myName,
              'friendship_id': friendshipId,
            },
            'created_at': nowUtc,
          });
        } catch (e) {
          debugPrint('[FriendRepository] Remote decline notification notice: $e');
        }

        if (isDatabaseInitialized) {
          try {
            await db.execute(
              'INSERT INTO friend_activity_logs (id, user_id, event_type, title, metadata, created_at) VALUES (?, ?, \'request_declined\', ?, ?, ?)',
              [logId, reqId, '$myName declined your companion request', meta, nowUtc],
            );
          } catch (_) {}
        }
      }
    }
  }

  /// Removes an existing friendship.
  Future<void> removeFriendship(String friendshipId) async {
    if (isDatabaseInitialized) {
      await db.execute('DELETE FROM friendships WHERE id = ?', [friendshipId]);
    }
    if (isRemoteAuthenticated) {
      try {
        await _supabaseClient!.from('friendships').delete().eq('id', friendshipId);
      } catch (e) {
        debugPrint('[FriendRepository] Supabase removeFriendship notice: $e');
      }
    }
  }

  // ===========================================================================
  // PRAYER REMINDERS & NUDGES
  // ===========================================================================

  /// Sends a gentle reminder / salam to a friend for an upcoming or pending prayer.
  Future<void> sendPrayerReminder(String friendUserId, String prayerName) async {
    final uid = currentUserId;
    if (uid.isEmpty || friendUserId.isEmpty) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final logId = IdGenerator.generateDeterministicId('nudge_${uid}_${friendUserId}_$nowUtc');
    final myName = currentUserName;
    final meta = jsonEncode({
      'sender_id': uid,
      'sender_name': myName,
      'prayer_name': prayerName,
    });

    // 1. Write to local SQLite
    if (isDatabaseInitialized) {
      await db.execute('''
        INSERT INTO friend_activity_logs (id, user_id, event_type, title, metadata, created_at)
        VALUES (?, ?, 'prayer_reminder', ?, ?, ?)
      ''', [logId, friendUserId, '$myName reminded you to pray $prayerName 🕌', meta, nowUtc]);
    }

    // 2. Write to Supabase remote
    if (isRemoteAuthenticated) {
      try {
        await _supabaseClient!.from('friend_activity_logs').insert({
          'id': logId,
          'user_id': friendUserId,
          'event_type': 'prayer_reminder',
          'title': '$myName reminded you to pray $prayerName 🕌',
          'metadata': {
            'sender_id': uid,
            'sender_name': myName,
            'prayer_name': prayerName,
          },
          'created_at': nowUtc,
        });
      } catch (e) {
        debugPrint('[FriendRepository] Supabase sendPrayerReminder notice: $e');
      }

      // Also call RPC helper
      try {
        await _supabaseClient!.rpc('send_prayer_reminder_rpc', params: {
          'p_target_user_id': friendUserId,
          'p_prayer_name': prayerName,
        });
      } catch (_) {}
    }
  }

  // ===========================================================================
  // REMOTE SYNCHRONIZATION HELPERS
  // ===========================================================================

  /// Synchronizes a specific companion profile from Supabase into local SQLite
  Future<void> syncSingleProfileFromRemote(String otherUid) async {
    final client = _supabaseClient;
    if (!isRemoteAuthenticated || client == null || otherUid.isEmpty || !isDatabaseInitialized) return;

    try {
      Map<String, dynamic>? prof;
      // 1. Direct query
      try {
        final res = await client.from('user_profiles').select('*').eq('user_id', otherUid).maybeSingle();
        if (res != null) prof = Map<String, dynamic>.from(res);
      } catch (_) {}

      // 2. RPC helper
      if (prof == null) {
        try {
          final rpcRes = await client.rpc('get_companion_profile', params: {'target_uid': otherUid});
          if (rpcRes is List && rpcRes.isNotEmpty) {
            prof = Map<String, dynamic>.from(rpcRes.first as Map);
          }
        } catch (_) {}
      }

      if (prof != null) {
        await _cacheProfileLocally(prof);
      }
    } catch (e) {
      debugPrint('[FriendRepository] syncSingleProfileFromRemote notice: $e');
    }
  }

  Future<void> _cacheProfileLocally(Map<String, dynamic> prof) async {
    if (!isDatabaseInitialized) return;
    try {
      final otherUid = prof['user_id']?.toString() ?? '';
      if (otherUid.isEmpty) return;

      final profId = prof['id']?.toString() ?? 'prof_$otherUid';
      final name = (prof['name']?.toString() ?? '').trim().isNotEmpty ? prof['name'].toString() : 'Companion';
      final title = prof['title']?.toString() ?? 'Specialist';
      final color = prof['avatar_color']?.toString() ?? '#6366F1';
      final url = prof['avatar_url']?.toString();
      final xp = _toInt(prof['total_xp']);
      final lvl = _toInt(prof['level'], 1);
      final hashPart = otherUid.replaceAll('-', '').toUpperCase();
      final fCode = prof['friend_code']?.toString() ?? 'AX-${hashPart.length >= 4 ? hashPart.substring(0, 4) : "7842"}';
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
    } catch (e) {
      debugPrint('[FriendRepository] _cacheProfileLocally error: $e');
    }
  }

  /// Pulls active friendships and pending requests directly from Supabase for instant real-time sync
  Future<void> syncFriendshipsFromRemote() async {
    final client = _supabaseClient;
    final uid = currentUserId;
    if (!isRemoteAuthenticated || client == null || uid.isEmpty || !isDatabaseInitialized) return;

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
        await syncSingleProfileFromRemote(otherUid);
      }
    } catch (e) {
      debugPrint('[FriendRepository] syncFriendshipsFromRemote notice: $e');
    }
  }

  /// Pulls friend activity logs and notifications from Supabase
  Future<void> syncActivityLogsFromRemote() async {
    final client = _supabaseClient;
    final uid = currentUserId;
    if (!isRemoteAuthenticated || client == null || uid.isEmpty || !isDatabaseInitialized) return;

    try {
      final remoteLogs = await client
          .from('friend_activity_logs')
          .select('*')
          .eq('user_id', uid)
          .order('created_at', ascending: false)
          .limit(30);

      for (final r in remoteLogs) {
        final lId = r['id']?.toString() ?? '';
        if (lId.isEmpty) continue;
        final evType = r['event_type']?.toString() ?? 'prayer_reminder';
        final title = r['title']?.toString() ?? '';
        final meta = r['metadata'] != null ? jsonEncode(r['metadata']) : '{}';
        final created = r['created_at']?.toString() ?? DateTime.now().toUtc().toIso8601String();

        final existing = await db.getOptional('SELECT id FROM friend_activity_logs WHERE id = ?', [lId]);
        if (existing == null) {
          await db.execute(
            'INSERT INTO friend_activity_logs (id, user_id, event_type, title, metadata, created_at) VALUES (?, ?, ?, ?, ?, ?)',
            [lId, uid, evType, title, meta, created],
          );
        }
      }
    } catch (e) {
      debugPrint('[FriendRepository] syncActivityLogsFromRemote notice: $e');
    }
  }

  /// Synchronizes the current user's prayers and daily habit progress into `daily_prayer_status`
  /// and pulls friends' statuses from Supabase.
  Future<void> syncMyDailyPrayerStatus() async {
    if (!isDatabaseInitialized) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final nowUtc = now.toUtc().toIso8601String();
    final statusId = IdGenerator.generateDeterministicId('prs_${uid}_$today');

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
      if (isRemoteAuthenticated) {
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

  /// Performs full sync of friendships, prayer checklists, and activity logs.
  Future<void> syncAllFriendData() async {
    await syncFriendshipsFromRemote();
    await syncActivityLogsFromRemote();
    await syncMyDailyPrayerStatus();
  }
}
