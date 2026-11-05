import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'friends/friend_models.dart';
import 'daily_prayer_status_repository.dart';
import 'friends/friend_activity_repository.dart';
import 'friends/friend_search_repository.dart';
import 'friends/companion_badge_service.dart';
import 'friends/companion_prayer_service.dart';

export 'friends/friend_models.dart';
export 'daily_prayer_status_repository.dart';
export 'friends/friend_activity_repository.dart';
export 'friends/friend_search_repository.dart';
export 'friends/companion_badge_service.dart';
export 'friends/companion_prayer_service.dart';

/// Centralized facade repository handling friendships, companions, and mutual accountability.
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

  bool get isRemoteAuthenticated => FriendActivityRepository().isRemoteAuthenticated;

  String get currentUserId => DailyPrayerStatusRepository().currentUserId;

  String get currentUserName => DailyPrayerStatusRepository().currentUserName;

  void notifyChecklistChanged() => DailyPrayerStatusRepository().notifyChecklistChanged();

  RealtimeChannel? _realtimeChannel;

  void _initRealtimeListeners() {
    final client = _supabaseClient;
    if (client == null || _realtimeChannel != null) return;

    client.auth.onAuthStateChange.listen((data) {
      if (data.session != null && !data.session!.isExpired) {
        if (_realtimeChannel == null) {
          _initRealtimeListeners();
        }
        unawaited(syncAllFriendData());
      }
    });

    if (!isRemoteAuthenticated) {
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
      ).subscribe();
    } catch (e) {
      debugPrint('[FriendRepository] Notice setting up Realtime subscription: $e');
    }
  }

  /// Watches all accepted friends with their profiles and current levels.
  Stream<List<FriendUser>> watchAcceptedFriends() {
    late StreamController<List<FriendUser>> controller;
    StreamSubscription? dbSub;
    StreamSubscription? triggerSub;
    VoidCallback? authListener;

    Future<void> emitFriends() async {
      if (controller.isClosed) return;
      if (!isDatabaseInitialized) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }
      final uid = currentUserId;
      if (uid.isEmpty) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }

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

      try {
        final rows = await db.getAll(query, [uid, uid, uid]);
        if (rows.isEmpty && isRemoteAuthenticated) {
          unawaited(syncFriendshipsFromRemote());
        }

        final profileCache = FriendSearchRepository().inMemoryProfileCache;
        final friends = rows.map((r) {
          final friend = FriendUser.fromRow(r, uid);
          if ((friend.name == 'Companion' || friend.name.isEmpty) && profileCache.containsKey(friend.userId)) {
            final prof = profileCache[friend.userId]!;
            final inMemName = prof['name']?.toString();
            if (inMemName != null && inMemName.isNotEmpty) {
              return friend.copyWith(
                name: inMemName,
                avatarColor: prof['avatar_color']?.toString() ?? friend.avatarColor,
                avatarUrl: prof['avatar_url']?.toString() ?? friend.avatarUrl,
                totalXp: (prof['total_xp'] is num) ? (prof['total_xp'] as num).toInt() : friend.totalXp,
                level: (prof['level'] is num) ? (prof['level'] as num).toInt() : friend.level,
                friendCode: prof['friend_code']?.toString() ?? friend.friendCode,
              );
            }
          }
          return friend;
        }).toList();

        if (!controller.isClosed) {
          controller.add(friends);
        }
      } catch (e) {
        debugPrint('[FriendRepository] watchAcceptedFriends notice: $e');
        if (!controller.isClosed) controller.add(const []);
      }
    }

    controller = StreamController<List<FriendUser>>(
      onListen: () {
        emitFriends();
        if (isDatabaseInitialized) {
          try {
            dbSub = db.watch('SELECT id, updated_at FROM friendships UNION ALL SELECT id, updated_at FROM user_profiles').listen((_) => emitFriends());
          } catch (_) {}
        }
        triggerSub = DailyPrayerStatusRepository().checklistTriggerStream.listen((_) => emitFriends());
        authListener = () => emitFriends();
        AuthService().authStateNotifier.addListener(authListener!);
      },
      onCancel: () {
        dbSub?.cancel();
        triggerSub?.cancel();
        if (authListener != null) {
          AuthService().authStateNotifier.removeListener(authListener!);
        }
      },
    );

    return controller.stream;
  }

  /// Watches all standings (current user + all accepted friends) sorted by XP.
  Stream<List<FriendUser>> watchAllStandings() {
    return watchAcceptedFriends().asyncMap((friends) async {
      final uid = currentUserId;
      if (uid.isEmpty || !isDatabaseInitialized) return friends;

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
        totalXp: parseToInt(myProfileRow?['total_xp']),
        level: parseToInt(myProfileRow?['level'], 1),
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
    late StreamController<List<FriendUser>> controller;
    StreamSubscription? dbSub;
    StreamSubscription? triggerSub;
    VoidCallback? authListener;

    Future<void> emitPending() async {
      if (controller.isClosed) return;
      if (!isDatabaseInitialized) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }
      final uid = currentUserId;
      if (uid.isEmpty) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }

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

      try {
        final rows = await db.getAll(query, [uid]);
        final profileCache = FriendSearchRepository().inMemoryProfileCache;
        final pending = rows.map((r) {
          final friend = FriendUser.fromRow(r, uid);
          if ((friend.name == 'Companion' || friend.name.isEmpty) && profileCache.containsKey(friend.userId)) {
            final prof = profileCache[friend.userId]!;
            final inMemName = prof['name']?.toString();
            if (inMemName != null && inMemName.isNotEmpty) {
              return friend.copyWith(
                name: inMemName,
                avatarColor: prof['avatar_color']?.toString() ?? friend.avatarColor,
                avatarUrl: prof['avatar_url']?.toString() ?? friend.avatarUrl,
                totalXp: (prof['total_xp'] is num) ? (prof['total_xp'] as num).toInt() : friend.totalXp,
                level: (prof['level'] is num) ? (prof['level'] as num).toInt() : friend.level,
                friendCode: prof['friend_code']?.toString() ?? friend.friendCode,
              );
            }
          }
          return friend;
        }).toList();

        if (!controller.isClosed) controller.add(pending);
      } catch (e) {
        debugPrint('[FriendRepository] watchPendingRequests notice: $e');
        if (!controller.isClosed) controller.add(const []);
      }
    }

    controller = StreamController<List<FriendUser>>(
      onListen: () {
        emitPending();
        if (isDatabaseInitialized) {
          try {
            dbSub = db.watch('SELECT id, updated_at FROM friendships WHERE status = \'pending\'').listen((_) => emitPending());
          } catch (_) {}
        }
        triggerSub = DailyPrayerStatusRepository().checklistTriggerStream.listen((_) => emitPending());
        authListener = () => emitPending();
        AuthService().authStateNotifier.addListener(authListener!);
      },
      onCancel: () {
        dbSub?.cancel();
        triggerSub?.cancel();
        if (authListener != null) {
          AuthService().authStateNotifier.removeListener(authListener!);
        }
      },
    );

    return controller.stream;
  }

  Stream<List<FriendActivityLog>> watchFriendActivityLogs() =>
      FriendActivityRepository().watchFriendActivityLogs();

  Future<void> clearFriendNotifications() =>
      FriendActivityRepository().clearFriendNotifications();

  Stream<List<DailyPrayerStatus>> watchTodayChecklist([String? dateStr]) =>
      DailyPrayerStatusRepository().watchTodayChecklist(dateStr);

  Future<FriendUser?> searchCandidateCompanion(String query) =>
      FriendSearchRepository().searchCandidateCompanion(query);

  Future<bool> sendFriendRequestToCandidate(FriendUser candidate) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception('Must be logged in to add friends');

    final targetUserId = candidate.userId;
    if (targetUserId.isEmpty || targetUserId == uid) return false;

    final friendshipId = IdGenerator.generateDeterministicId('friendship_${uid}_$targetUserId');
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final myName = currentUserName;

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

      final logId = 'log_${uid}_${targetUserId}_${DateTime.now().millisecondsSinceEpoch}';
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
    }

    unawaited(syncSingleProfileFromRemote(targetUserId));
    return true;
  }

  Future<bool> sendFriendRequest(String codeOrUsername) async {
    final candidate = await searchCandidateCompanion(codeOrUsername);
    if (candidate == null) return false;
    return sendFriendRequestToCandidate(candidate);
  }

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

    if (isDatabaseInitialized) {
      await db.execute('UPDATE friendships SET status = \'accepted\', updated_at = ? WHERE id = ?', [nowUtc, friendshipId]);
    }

    if (isRemoteAuthenticated) {
      bool rpcHandled = false;
      try {
        final res = await _supabaseClient!.rpc('respond_companion_request', params: {
          'p_friendship_id': friendshipId,
          'p_action': 'accept',
        });
        if (res is Map && res['success'] == true) {
          rpcHandled = true;
        }
      } catch (e) {
        debugPrint('[FriendRepository] RPC respond_companion_request error, falling back to direct write: $e');
      }

      // Only perform direct table update & insert if the atomic RPC was not handled
      if (!rpcHandled) {
        try {
          await _supabaseClient!.from('friendships').update({
            'status': 'accepted',
            'updated_at': nowUtc,
          }).eq('id', friendshipId);
        } catch (e) {
          debugPrint('[FriendRepository] Supabase acceptFriendRequest update notice: $e');
        }

        if (reqId.isNotEmpty) {
          final logId = 'log_${uid}_${reqId}_${DateTime.now().millisecondsSinceEpoch}';
          try {
            await _supabaseClient!.from('friend_activity_logs').insert({
              'id': logId, 'user_id': reqId, 'event_type': 'request_accepted',
              'title': '$myName accepted your companion request',
              'metadata': {'sender_id': uid, 'sender_name': myName, 'friendship_id': friendshipId},
              'created_at': nowUtc,
            });
          } catch (e) {
            debugPrint('[FriendRepository] Remote accept notification notice: $e');
          }
        }
      }
    }

    if (reqId.isNotEmpty) {
      unawaited(syncSingleProfileFromRemote(reqId));
    }
    unawaited(syncMyDailyPrayerStatus());
  }

  Future<void> declineFriendRequest(String friendshipId, [String? requesterId]) async {
    final uid = currentUserId;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final myName = currentUserName;

    String reqId = requesterId ?? '';
    if (reqId.isEmpty && isDatabaseInitialized) {
      final row = await db.getOptional('SELECT requester_id FROM friendships WHERE id = ?', [friendshipId]);
      reqId = row?['requester_id']?.toString() ?? '';
    }

    if (isDatabaseInitialized) {
      await db.execute('DELETE FROM friendships WHERE id = ?', [friendshipId]);
    }

    if (isRemoteAuthenticated) {
      bool rpcHandled = false;
      try {
        final res = await _supabaseClient!.rpc('respond_companion_request', params: {
          'p_friendship_id': friendshipId,
          'p_action': 'decline',
        });
        if (res is Map && res['success'] == true) {
          rpcHandled = true;
        }
      } catch (e) {
        debugPrint('[FriendRepository] RPC decline error, falling back to direct write: $e');
      }

      if (!rpcHandled) {
        try {
          await _supabaseClient!.from('friendships').delete().eq('id', friendshipId);
        } catch (e) {
          debugPrint('[FriendRepository] Supabase decline delete notice: $e');
        }

        if (reqId.isNotEmpty) {
          final logId = 'log_${uid}_${reqId}_${DateTime.now().millisecondsSinceEpoch}';
          try {
            await _supabaseClient!.from('friend_activity_logs').insert({
              'id': logId, 'user_id': reqId, 'event_type': 'request_declined',
              'title': '$myName declined your companion request',
              'metadata': {'sender_id': uid, 'sender_name': myName, 'friendship_id': friendshipId},
              'created_at': nowUtc,
            });
          } catch (e) {
            debugPrint('[FriendRepository] Remote decline notification notice: $e');
          }
        }
      }
    }
  }

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

  Future<void> sendPrayerReminder(String friendUserId, String prayerName) =>
      FriendActivityRepository().sendPrayerReminder(friendUserId, prayerName);

  Future<void> syncSingleProfileFromRemote(String otherUid) =>
      FriendSearchRepository().syncSingleProfileFromRemote(otherUid);

  Future<void> syncFriendshipsFromRemote() =>
      FriendSearchRepository().syncFriendshipsFromRemote();

  Future<void> syncActivityLogsFromRemote() =>
      FriendActivityRepository().syncActivityLogsFromRemote();

  Future<void> updateSinglePrayerStatus(String prayerCode, bool isDone) =>
      DailyPrayerStatusRepository().updateSinglePrayerStatus(prayerCode, isDone);

  Future<DailyPrayerStatus> getStatusForCompanion(FriendUser friend) =>
      CompanionPrayerService().fetchCompanionStatus(friend);

  Future<void> syncMyDailyPrayerStatus() =>
      DailyPrayerStatusRepository().syncMyDailyPrayerStatus();

  Future<void> syncAllFriendData() async {
    await AuthService().ensureAuthenticatedSession();
    await syncFriendshipsFromRemote();
    await syncActivityLogsFromRemote();
    await syncMyDailyPrayerStatus();
    notifyChecklistChanged();
  }

  Future<List<MasteryBadgeData>> getBadgesForCompanion(
    String companionUserId, {
    int level = 1,
    int totalXp = 0,
    int streakDays = 0,
  }) =>
      CompanionBadgeService().getBadgesForCompanion(
        companionUserId,
        level: level,
        totalXp: totalXp,
        streakDays: streakDays,
      );
}
