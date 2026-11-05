import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/friends/friend_models.dart';
import 'package:axis/data/friends/friend_search_repository.dart';

/// Service dedicated to real-time, cloud-native streaming of companion prayer accountability.
///
/// Implements Method 1 (Direct Supabase Native Realtime Stream):
/// 1. Zero local SQLite writes on companion viewer devices (prevents PowerSync mutation conflicts).
/// 2. Stream-based single source of truth: Supabase PostgreSQL Realtime.
/// 3. Offline isolation: companion data is only shown when connected to the internet;
///    offline state clearly informs the user that companion data is available once online.
class CompanionPrayerService {
  static final CompanionPrayerService _instance = CompanionPrayerService._internal();
  factory CompanionPrayerService() => _instance;
  CompanionPrayerService._internal();

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isOnline => NetworkService().isOnline;

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

  @visibleForTesting
  Stream<List<DailyPrayerStatus>>? mockCompanionStream;

  /// Retrieves accepted companion metadata (userId, name, avatarColor, avatarUrl)
  /// from local friendships & user_profiles.
  Future<Map<String, Map<String, dynamic>>> getAcceptedCompanionProfiles() async {
    final uid = currentUserId;
    if (uid.isEmpty || !isDatabaseInitialized) return {};

    try {
      const friendsQuery = '''
        SELECT 
          f.id AS friendship_id,
          f.requester_id,
          f.addressee_id,
          p.user_id,
          COALESCE(p.name, 'Companion') AS name,
          COALESCE(p.avatar_color, '#6366F1') AS avatar_color,
          p.avatar_url,
          p.friend_code,
          COALESCE(p.level, 1) AS level,
          COALESCE(p.total_xp, 0) AS total_xp
        FROM friendships f
        LEFT JOIN user_profiles p ON p.user_id = CASE WHEN f.requester_id = ? THEN f.addressee_id ELSE f.requester_id END
        WHERE (f.requester_id = ? OR f.addressee_id = ?) AND f.status = 'accepted'
      ''';
      final friendRows = await db.getAll(friendsQuery, [uid, uid, uid]);
      final profileCache = FriendSearchRepository().inMemoryProfileCache;

      final map = <String, Map<String, dynamic>>{};
      for (final r in friendRows) {
        final req = r['requester_id']?.toString() ?? '';
        final add = r['addressee_id']?.toString() ?? '';
        final cUid = req == uid ? add : req;
        if (cUid.isEmpty || cUid == uid) continue;

        final cached = profileCache[cUid];
        final effName = (cached?['name']?.toString() ?? '').trim().isNotEmpty
            ? cached!['name'].toString()
            : (r['name']?.toString() ?? 'Companion');
        final effColor = cached?['avatar_color']?.toString() ?? r['avatar_color']?.toString() ?? '#6366F1';
        final effAvatarUrl = cached?['avatar_url']?.toString() ?? r['avatar_url']?.toString();

        map[cUid] = {
          'user_id': cUid,
          'name': effName,
          'avatar_color': effColor,
          'avatar_url': effAvatarUrl,
          'level': parseToInt(cached?['level'] ?? r['level'], 1),
          'total_xp': parseToInt(cached?['total_xp'] ?? r['total_xp']),
          'friend_code': cached?['friend_code']?.toString() ?? r['friend_code']?.toString(),
        };
      }
      return map;
    } catch (e) {
      debugPrint('[CompanionPrayerService] Error querying companion profiles: $e');
      return {};
    }
  }

  /// Cache of latest companion prayer statuses to enable zero-data-loss delta merging
  final Map<String, DailyPrayerStatus> _companionStatusMap = {};

  void _emitSorted(
    StreamController<List<DailyPrayerStatus>> controller,
    Map<String, Map<String, dynamic>> companions,
    String today,
  ) {
    if (controller.isClosed) return;
    final list = <DailyPrayerStatus>[];
    for (final entry in companions.entries) {
      final cUid = entry.key;
      final profile = entry.value;
      final existing = _companionStatusMap[cUid];
      if (existing != null) {
        list.add(existing);
      } else {
        list.add(DailyPrayerStatus(
          id: 'prs_${cUid}_$today',
          userId: cUid,
          userName: profile['name']?.toString() ?? 'Companion',
          userAvatarColor: profile['avatar_color']?.toString() ?? '#6366F1',
          userAvatarUrl: profile['avatar_url']?.toString(),
          date: today,
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
    list.sort((a, b) => b.completedCount.compareTo(a.completedCount));
    controller.add(list);
  }

  /// Live Supabase Realtime Stream of companions' prayer statuses for today.
  ///
  /// Subscribes directly to PostgreSQL Realtime stream when online.
  /// Emits an empty list when offline so the UI displays the offline notice.
  Stream<List<DailyPrayerStatus>> watchCompanionPrayers() {
    if (mockCompanionStream != null) {
      return mockCompanionStream!;
    }

    late StreamController<List<DailyPrayerStatus>> controller;
    RealtimeChannel? realtimeChannel;
    VoidCallback? networkListener;

    void startStreaming() async {
      if (controller.isClosed) return;
      final client = _supabaseClient;
      final uid = currentUserId;

      if (!isOnline || client == null || !isRemoteAuthenticated || uid.isEmpty) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }

      final companions = await getAcceptedCompanionProfiles();
      if (companions.isEmpty) {
        if (!controller.isClosed) controller.add(const []);
        return;
      }

      final companionIds = companions.keys.toSet();
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);
      final todayUtc = DateFormat('yyyy-MM-dd').format(now.toUtc());

      // 1. Initial authoritative REST query for full rows
      try {
        final res = await client
            .from('daily_prayer_status')
            .select('*')
            .inFilter('user_id', companionIds.toList())
            .or('date.eq.$today,date.eq.$todayUtc')
            .order('updated_at', ascending: false);

        for (final row in res) {
          final rUid = row['user_id']?.toString() ?? '';
          if (!companionIds.contains(rUid)) continue;
          if (_companionStatusMap.containsKey(rUid)) continue;

          final profile = companions[rUid]!;
          _companionStatusMap[rUid] = DailyPrayerStatus(
            id: row['id']?.toString() ?? 'prs_${rUid}_$today',
            userId: rUid,
            userName: profile['name']?.toString() ?? 'Companion',
            userAvatarColor: profile['avatar_color']?.toString() ?? '#6366F1',
            userAvatarUrl: profile['avatar_url']?.toString(),
            date: today,
            fajr: parseToBool(row['fajr']),
            dhuhr: parseToBool(row['dhuhr']),
            asr: parseToBool(row['asr']),
            maghrib: parseToBool(row['maghrib']),
            isha: parseToBool(row['isha']),
            streakDays: parseToInt(row['streak_days']),
            habitsDone: parseToInt(row['habits_done']),
            habitsTotal: parseToInt(row['habits_total']),
            updatedAt: row['updated_at']?.toString(),
          );
        }

        _emitSorted(controller, companions, today);
      } catch (e) {
        debugPrint('[CompanionPrayerService] Initial REST query notice: $e');
      }

      // 2. Real-time PostgreSQL subscription with intelligent delta merging
      try {
        if (realtimeChannel != null) {
          await client.removeChannel(realtimeChannel!);
          realtimeChannel = null;
        }

        final channelName = 'companion_prayers_${uid}_${DateTime.now().millisecondsSinceEpoch}';
        realtimeChannel = client.channel(channelName);

        realtimeChannel!
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'daily_prayer_status',
              callback: (payload) {
                if (controller.isClosed) return;
                final record = payload.newRecord;
                if (record.isEmpty) return;

                // Resolve companion userId from record or deterministic ID
                var rUid = record['user_id']?.toString() ?? '';
                if (rUid.isEmpty) {
                  final recId = record['id']?.toString() ?? '';
                  if (recId.startsWith('prs_')) {
                    final parts = recId.split('_');
                    if (parts.length >= 2 && parts[1].isNotEmpty) {
                      rUid = parts[1];
                    }
                  }
                }

                if (rUid.isEmpty || !companionIds.contains(rUid)) return;

                final prev = _companionStatusMap[rUid];
                final profile = companions[rUid]!;

                // Targeted column preservation: if column is omitted or null in payload,
                // NEVER wipe out the previous known state!
                final bool fajr = record.containsKey('fajr') && record['fajr'] != null
                    ? parseToBool(record['fajr'])
                    : (prev?.fajr ?? false);
                final bool dhuhr = record.containsKey('dhuhr') && record['dhuhr'] != null
                    ? parseToBool(record['dhuhr'])
                    : (prev?.dhuhr ?? false);
                final bool asr = record.containsKey('asr') && record['asr'] != null
                    ? parseToBool(record['asr'])
                    : (prev?.asr ?? false);
                final bool maghrib = record.containsKey('maghrib') && record['maghrib'] != null
                    ? parseToBool(record['maghrib'])
                    : (prev?.maghrib ?? false);
                final bool isha = record.containsKey('isha') && record['isha'] != null
                    ? parseToBool(record['isha'])
                    : (prev?.isha ?? false);

                int streak = prev?.streakDays ?? 0;
                if (record.containsKey('streak_days') && record['streak_days'] != null) {
                  final s = parseToInt(record['streak_days']);
                  if (s > 0) streak = s;
                }

                int hDone = prev?.habitsDone ?? 0;
                if (record.containsKey('habits_done') && record['habits_done'] != null) {
                  hDone = parseToInt(record['habits_done']);
                }

                int hTotal = prev?.habitsTotal ?? 0;
                if (record.containsKey('habits_total') && record['habits_total'] != null) {
                  final ht = parseToInt(record['habits_total']);
                  if (ht > 0) hTotal = ht;
                }

                _companionStatusMap[rUid] = DailyPrayerStatus(
                  id: record['id']?.toString() ?? prev?.id ?? 'prs_${rUid}_$today',
                  userId: rUid,
                  userName: profile['name']?.toString() ?? 'Companion',
                  userAvatarColor: profile['avatar_color']?.toString() ?? '#6366F1',
                  userAvatarUrl: profile['avatar_url']?.toString(),
                  date: today,
                  fajr: fajr,
                  dhuhr: dhuhr,
                  asr: asr,
                  maghrib: maghrib,
                  isha: isha,
                  streakDays: streak,
                  habitsDone: hDone,
                  habitsTotal: hTotal,
                  updatedAt: record['updated_at']?.toString() ?? prev?.updatedAt,
                );

                _emitSorted(controller, companions, today);
              },
            )
            .subscribe((status, [error]) {
              if (status == RealtimeSubscribeStatus.channelError || status == RealtimeSubscribeStatus.timedOut) {
                debugPrint('[CompanionPrayerService] Realtime channel status notice: $status, err: $error');
              }
            });
      } catch (e) {
        debugPrint('[CompanionPrayerService] Notice setting up Realtime channel: $e');
      }
    }

    controller = StreamController<List<DailyPrayerStatus>>.broadcast(
      onListen: () {
        startStreaming();
        networkListener = () {
          startStreaming();
        };
        NetworkService().isOnlineNotifier.addListener(networkListener!);
      },
      onCancel: () {
        if (realtimeChannel != null && _supabaseClient != null) {
          _supabaseClient?.removeChannel(realtimeChannel!);
          realtimeChannel = null;
        }
        if (networkListener != null) {
          NetworkService().isOnlineNotifier.removeListener(networkListener!);
        }
      },
    );

    return controller.stream;
  }

  /// Authoritatively fetches a single companion's prayer status directly from Supabase.
  Future<DailyPrayerStatus> fetchCompanionStatus(FriendUser friend) async {
    final client = _supabaseClient;
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final todayUtc = DateFormat('yyyy-MM-dd').format(now.toUtc());

    if (!isOnline || client == null || !isRemoteAuthenticated || friend.userId.isEmpty) {
      return DailyPrayerStatus(
        id: 'prs_${friend.userId}_$today',
        userId: friend.userId,
        userName: friend.name.isNotEmpty && friend.name != 'Companion' ? friend.name : 'Companion',
        userAvatarColor: friend.avatarColor,
        userAvatarUrl: friend.avatarUrl,
        date: today,
        fajr: false,
        dhuhr: false,
        asr: false,
        maghrib: false,
        isha: false,
        streakDays: 0,
        habitsDone: 0,
        habitsTotal: 0,
      );
    }

    final cached = _companionStatusMap[friend.userId];
    if (cached != null && cached.completedCount > 0) {
      return cached;
    }

    try {
      final res = await client
          .from('daily_prayer_status')
          .select('*')
          .eq('user_id', friend.userId)
          .or('date.eq.$today,date.eq.$todayUtc')
          .order('updated_at', ascending: false)
          .limit(1);

      if (res.isNotEmpty) {
        final row = res.first;
        final status = DailyPrayerStatus(
          id: row['id']?.toString() ?? 'prs_${friend.userId}_$today',
          userId: friend.userId,
          userName: friend.name.isNotEmpty && friend.name != 'Companion' ? friend.name : 'Companion',
          userAvatarColor: friend.avatarColor,
          userAvatarUrl: friend.avatarUrl,
          date: row['date']?.toString() ?? today,
          fajr: parseToBool(row['fajr']),
          dhuhr: parseToBool(row['dhuhr']),
          asr: parseToBool(row['asr']),
          maghrib: parseToBool(row['maghrib']),
          isha: parseToBool(row['isha']),
          streakDays: parseToInt(row['streak_days']),
          habitsDone: parseToInt(row['habits_done']),
          habitsTotal: parseToInt(row['habits_total']),
          updatedAt: row['updated_at']?.toString(),
        );
        _companionStatusMap[friend.userId] = status;
        return status;
      }
    } catch (e) {
      debugPrint('[CompanionPrayerService] fetchCompanionStatus error notice: $e');
    }

    return cached ??
        DailyPrayerStatus(
          id: 'prs_${friend.userId}_$today',
          userId: friend.userId,
          userName: friend.name.isNotEmpty && friend.name != 'Companion' ? friend.name : 'Companion',
          userAvatarColor: friend.avatarColor,
          userAvatarUrl: friend.avatarUrl,
          date: today,
          fajr: false,
          dhuhr: false,
          asr: false,
          maghrib: false,
          isha: false,
          streakDays: 0,
          habitsDone: 0,
          habitsTotal: 0,
        );
  }
}

