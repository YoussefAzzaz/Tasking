import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'friend_models.dart';

/// Repository managing companion search, profile resolution, and remote friendship sync.
class FriendSearchRepository {
  static final FriendSearchRepository _instance = FriendSearchRepository._();
  factory FriendSearchRepository() => _instance;
  FriendSearchRepository._();

  final Map<String, Map<String, dynamic>> _inMemoryProfileCache = {};
  Map<String, Map<String, dynamic>> get inMemoryProfileCache => _inMemoryProfileCache;

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

  /// Searches candidate companion by friend code or username.
  Future<FriendUser?> searchCandidateCompanion(String query) async {
    final cleanInput = query.trim();
    if (cleanInput.isEmpty) return null;

    final uid = currentUserId;
    final upper = cleanInput.toUpperCase();
    final rawCode = upper.replaceAll('AX-', '').replaceAll('-', '').replaceAll(' ', '');
    final formattedCode = 'AX-$rawCode';

    Map<String, dynamic>? candidateRow;

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
        debugPrint('[FriendSearchRepository] search_companion RPC notice: $e');
      }
    }

    if (candidateRow == null && _supabaseClient != null) {
      try {
        final sanitizedInput = cleanInput.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\s]'), '').trim();
        final sanitizedRaw = rawCode.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
        final sanitizedFormatted = 'AX-$sanitizedRaw';

        final orFilters = <String>[];
        if (sanitizedInput.isNotEmpty) {
          orFilters.add('friend_code.ilike.$sanitizedInput');
          orFilters.add('name.ilike.$sanitizedInput');
        }
        if (sanitizedRaw.isNotEmpty) {
          orFilters.add('friend_code.ilike.$sanitizedFormatted');
          orFilters.add('friend_code.ilike.%$sanitizedRaw%');
        }
        if (sanitizedRaw.length >= 4) {
          orFilters.add('user_id.ilike.${sanitizedRaw.toLowerCase()}%');
        }

        if (orFilters.isNotEmpty) {
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
        }
      } catch (e) {
        debugPrint('[FriendSearchRepository] Direct user_profiles query notice: $e');
      }
    }

    if (candidateRow == null) return null;

    final targetUid = candidateRow['user_id']?.toString() ?? '';
    if (targetUid.isEmpty || targetUid == uid) return null;

    await cacheProfileLocally(candidateRow);

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
      totalXp: parseToInt(candidateRow['total_xp']),
      level: parseToInt(candidateRow['level'], 1),
      friendCode: candidateRow['friend_code']?.toString(),
      friendshipId: existingFriendshipId,
      status: existingStatus,
      isRequester: isRequester,
    );
  }

  /// Caches companion profile in memory and updates local SQLite row for active user.
  Future<void> cacheProfileLocally(Map<String, dynamic> prof) async {
    final otherUid = prof['user_id']?.toString() ?? '';
    if (otherUid.isEmpty) return;

    _inMemoryProfileCache[otherUid] = prof;

    // Only persist manually in local SQLite if this is the active user's own profile.
    // Companion profiles are synced read-only from Supabase via PowerSync sync rules,
    // and keeping companions in _inMemoryProfileCache prevents generating spurious foreign upload mutations.
    if (otherUid != currentUserId) return;

    if (!isDatabaseInitialized) return;

    try {
      final profId = prof['id']?.toString() ?? 'prof_$otherUid';
      final name = (prof['name']?.toString() ?? '').trim().isNotEmpty ? prof['name'].toString() : 'Commander';
      final title = prof['title']?.toString() ?? 'Specialist';
      final color = prof['avatar_color']?.toString() ?? '#6366F1';
      final url = prof['avatar_url']?.toString();
      final xp = parseToInt(prof['total_xp']);
      final lvl = parseToInt(prof['level'], 1);
      final hashPart = otherUid.replaceAll('-', '').toUpperCase();
      final fCode = prof['friend_code']?.toString() ?? 'AX-${hashPart.length >= 4 ? hashPart.substring(0, 4) : "7842"}';
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      // Check if row already exists by id or user_id
      final existing = await db.getOptional(
        'SELECT id FROM user_profiles WHERE id = ? OR user_id = ? LIMIT 1',
        [profId, otherUid],
      );
      if (existing != null) {
        final existingId = existing['id']?.toString() ?? profId;
        await db.execute('''
          UPDATE user_profiles SET
            user_id = ?, name = ?, title = ?, avatar_color = ?, avatar_url = ?, total_xp = ?, level = ?, friend_code = ?, updated_at = ?
          WHERE id = ?
        ''', [otherUid, name, title, color, url, xp, lvl, fCode, nowUtc, existingId]);
      } else {
        try {
          await db.execute('''
            INSERT INTO user_profiles (id, user_id, name, title, avatar_color, avatar_url, total_xp, level, friend_code, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [profId, otherUid, name, title, color, url, xp, lvl, fCode, nowUtc, nowUtc]);
        } catch (_) {
          await db.execute('''
            UPDATE user_profiles SET
              name = ?, title = ?, avatar_color = ?, avatar_url = ?, total_xp = ?, level = ?, updated_at = ?
            WHERE user_id = ?
          ''', [name, title, color, url, xp, lvl, nowUtc, otherUid]);
        }
      }
    } catch (e) {
      // In case of any concurrent race condition conflict, gracefully update by user_id
      try {
        final name = (prof['name']?.toString() ?? '').trim().isNotEmpty ? prof['name'].toString() : 'Commander';
        final title = prof['title']?.toString() ?? 'Specialist';
        final color = prof['avatar_color']?.toString() ?? '#6366F1';
        final url = prof['avatar_url']?.toString();
        final xp = parseToInt(prof['total_xp']);
        final lvl = parseToInt(prof['level'], 1);
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await db.execute('''
          UPDATE user_profiles SET
            name = ?, title = ?, avatar_color = ?, avatar_url = ?, total_xp = ?, level = ?, updated_at = ?
          WHERE user_id = ?
        ''', [name, title, color, url, xp, lvl, nowUtc, otherUid]);
      } catch (_) {}
    }
  }

  /// Synchronizes a specific companion profile from Supabase into memory and SQLite.
  Future<void> syncSingleProfileFromRemote(String otherUid) async {
    final client = _supabaseClient;
    if (!isRemoteAuthenticated || client == null || otherUid.isEmpty || !isDatabaseInitialized) return;

    try {
      Map<String, dynamic>? prof;
      try {
        final res = await client.from('user_profiles').select('*').eq('user_id', otherUid).maybeSingle();
        if (res != null) prof = Map<String, dynamic>.from(res);
      } catch (_) {}

      if (prof == null) {
        try {
          final rpcRes = await client.rpc('get_companion_profile', params: {'target_uid': otherUid});
          if (rpcRes is List && rpcRes.isNotEmpty) {
            prof = Map<String, dynamic>.from(rpcRes.first as Map);
          }
        } catch (_) {}
      }

      if (prof != null) {
        await cacheProfileLocally(prof);
      }
    } catch (e) {
      debugPrint('[FriendSearchRepository] syncSingleProfileFromRemote notice: $e');
    }
  }

  /// Pulls active friendships and pending requests directly from Supabase.
  Future<void> syncFriendshipsFromRemote() async {
    await AuthService().ensureAuthenticatedSession();
    final client = _supabaseClient;
    final uid = currentUserId;
    if (!isRemoteAuthenticated || client == null || uid.isEmpty || !isDatabaseInitialized) return;

    try {
      List<dynamic> remoteRows = [];
      try {
        final res = await client
            .from('friendships')
            .select('*')
            .or('requester_id.eq.$uid,addressee_id.eq.$uid');
        remoteRows = res;
      } catch (e) {
        debugPrint('[FriendSearchRepository] Filtered friendships select notice: $e');
        try {
          final res = await client.from('friendships').select('*');
          remoteRows = res;
        } catch (e2) {
          debugPrint('[FriendSearchRepository] Unfiltered friendships select notice: $e2');
        }
      }

      final remoteIds = <String>{};
      for (final r in remoteRows) {
        final fId = r['id'] as String? ?? '';
        final reqId = r['requester_id'] as String? ?? '';
        final addId = r['addressee_id'] as String? ?? '';
        final status = r['status'] as String? ?? 'pending';
        final createdAt = r['created_at'] as String? ?? DateTime.now().toUtc().toIso8601String();
        final updatedAt = r['updated_at'] as String? ?? createdAt;
        if (fId.isEmpty) continue;
        remoteIds.add(fId);

        final existing = await db.getOptional('SELECT id, status FROM friendships WHERE id = ?', [fId]);
        if (existing != null) {
          if (existing['status'] != status) {
            await db.execute('UPDATE friendships SET status = ?, updated_at = ? WHERE id = ?', [status, updatedAt, fId]);
          }
        } else {
          await db.execute(
            'INSERT INTO friendships (id, requester_id, addressee_id, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
            [fId, reqId, addId, status, createdAt, updatedAt],
          );
        }

        final otherUid = (reqId == uid) ? addId : reqId;
        if (otherUid.isNotEmpty) {
          await syncSingleProfileFromRemote(otherUid);
        }
      }

      // ONLY delete local friendships if remote successfully returned rows and confirmed deletions
      if (remoteIds.isNotEmpty) {
        final localRows = await db.getAll('SELECT id FROM friendships WHERE requester_id = ? OR addressee_id = ?', [uid, uid]);
        for (final l in localRows) {
          final lId = l['id']?.toString() ?? '';
          if (lId.isNotEmpty && !remoteIds.contains(lId)) {
            await db.execute('DELETE FROM friendships WHERE id = ?', [lId]);
          }
        }
      }
    } catch (e) {
      debugPrint('[FriendSearchRepository] syncFriendshipsFromRemote notice: $e');
    }
  }
}
