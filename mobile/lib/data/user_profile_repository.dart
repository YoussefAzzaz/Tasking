import 'dart:async';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String name;
  final String title;
  final String avatarColor;
  final String? avatarUrl;
  final int totalXp;
  final int level;
  final String? friendCode;

  const UserProfile({
    this.name = 'Commander',
    this.title = 'Specialist',
    this.avatarColor = '#6366F1',
    this.avatarUrl,
    this.totalXp = 0,
    this.level = 1,
    this.friendCode,
  });

  UserProfile copyWith({
    String? name,
    String? title,
    String? avatarColor,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    int? totalXp,
    int? level,
    String? friendCode,
  }) {
    return UserProfile(
      name: name ?? this.name,
      title: title ?? this.title,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
      friendCode: friendCode ?? this.friendCode,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          title == other.title &&
          avatarColor == other.avatarColor &&
          avatarUrl == other.avatarUrl &&
          totalXp == other.totalXp &&
          level == other.level &&
          friendCode == other.friendCode;

  @override
  int get hashCode => Object.hash(
        name,
        title,
        avatarColor,
        avatarUrl,
        totalXp,
        level,
        friendCode,
      );
}

/// Repository managing user profile data with caching and multi-user isolation.
/// Syncs profile, XP, and Level unique to each user via PowerSync to Supabase.
class UserProfileRepository {
  static final UserProfileRepository _instance = UserProfileRepository._internal();
  factory UserProfileRepository() => _instance;
  UserProfileRepository._internal();

  final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(const UserProfile());

  String? _lastUploadedAvatarHash;

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String get _cacheKey => 'user_profile_data_${currentUserId.isNotEmpty ? currentUserId : "global"}';

  /// Synchronously broadcasts updated XP and Level to profile listeners and clears stale cache.
  void updateNotifierLevelAndXp(int totalXp, int level) {
    CacheService().invalidate(_cacheKey);
    final current = profileNotifier.value;
    if (current.totalXp != totalXp || current.level != level) {
      profileNotifier.value = current.copyWith(
        totalXp: totalXp,
        level: level > 0 ? level : 1,
      );
    }
  }

  /// Retrieves user profile instantly from cache, or fetches from SQLite.
  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_cacheKey);
    }

    final profile = await CacheService().getOrFetch<UserProfile>(
      _cacheKey,
      _fetchProfileFromDb,
      ttl: const Duration(minutes: 15),
      staleWhileRevalidate: true,
      timeout: const Duration(seconds: 6),
      fallback: profileNotifier.value,
    );
    if (profileNotifier.value != profile) {
      profileNotifier.value = profile;
    }
    return profile;
  }

  Future<UserProfile> _fetchProfileFromDb() async {
    if (!isDatabaseInitialized) return const UserProfile();

    try {
      final uid = currentUserId;
      final query = (uid.isNotEmpty && uid != 'local_guest')
          ? 'SELECT id, name, title, avatar_color, avatar_url, total_xp, level, friend_code FROM user_profiles WHERE user_id = ? LIMIT 1'
          : 'SELECT id, name, title, avatar_color, avatar_url, total_xp, level, friend_code FROM user_profiles LIMIT 1';
      final params = (uid.isNotEmpty && uid != 'local_guest') ? [uid] : <dynamic>[];
      final rows = await db.getAll(query, params);

      String dbName = '';
      String dbTitle = '';
      String? dbAvatarUrl;
      String? dbFriendCode;

      String name = '';
      String title = '';
      String avatarColor = '#6366F1';
      String? avatarUrl;
      int totalXp = 0;
      int level = 1;
      String? friendCode;

      if (rows.isNotEmpty) {
        final r = rows.first;
        dbName = (r['name'] as String?) ?? '';
        dbTitle = (r['title'] as String?) ?? '';
        dbAvatarUrl = r['avatar_url'] as String?;
        dbFriendCode = r['friend_code'] as String?;

        name = dbName;
        title = dbTitle;
        avatarColor = (r['avatar_color'] as String?) ?? '#6366F1';
        avatarUrl = dbAvatarUrl;
        totalXp = (r['total_xp'] as num?)?.toInt() ?? 0;
        level = (r['level'] as num?)?.toInt() ?? 1;
        friendCode = dbFriendCode;
      }

      if ((friendCode == null || friendCode.isEmpty) && uid.isNotEmpty) {
        final hashPart = uid.replaceAll('-', '').toUpperCase();
        friendCode = 'AX-${hashPart.length >= 4 ? hashPart.substring(0, 4) : "7842"}';
        if (rows.isNotEmpty) {
          try {
            await db.execute(
              'UPDATE user_profiles SET friend_code = ? WHERE user_id = ?',
              [friendCode, uid],
            );
          } catch (_) {}
        }
      }

      // Synchronize friend_code to Supabase remote user_profiles table only if previously unset
      if ((dbFriendCode == null || dbFriendCode.isEmpty) &&
          friendCode != null &&
          friendCode.isNotEmpty &&
          uid.isNotEmpty &&
          uid != 'local_guest' &&
          _supabaseClient != null) {
        unawaited(() async {
          try {
            await _supabaseClient!.from('user_profiles').update({
              'friend_code': friendCode,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('user_id', uid);
          } catch (e) {
            debugPrint('[UserProfileRepository] Remote friend_code sync notice: $e');
          }
        }());
      }

      // Check Supabase Auth user_metadata (cloud ground truth)
      Map<String, dynamic>? authMeta;
      try {
        authMeta = _supabaseClient?.auth.currentUser?.userMetadata;
      } catch (_) {}

      // 1. Resolve Display Name
      if (name.isEmpty || name == 'Commander' || name == 'Player One' || name == 'Operative') {
        final metaName = authMeta?['display_name'] as String?;
        if (metaName != null && metaName.trim().isNotEmpty) {
          name = metaName.trim();
        } else {
          try {
            final sessionRow = await db.getOptional('SELECT display_name FROM local_auth_session WHERE id = ?', ['active_session']);
            final savedName = sessionRow?['display_name'] as String?;
            if (savedName != null && savedName.trim().isNotEmpty && savedName != 'Operative') {
              name = savedName.trim();
            }
          } catch (_) {}
        }
        if (name.isEmpty) {
          name = 'Commander';
        }
      }

      // 2. Resolve Title / Call-sign Identifier
      if (title.isEmpty || title == 'Disciplined Novice' || title == 'Specialist') {
        final metaTitle = (authMeta?['title'] as String?) ?? (authMeta?['callsign'] as String?);
        if (metaTitle != null && metaTitle.trim().isNotEmpty) {
          title = metaTitle.trim();
        } else if (title.isEmpty) {
          title = 'Specialist';
        }
      }

      // 3. Resolve Avatar URL
      if (avatarUrl == null || avatarUrl.isEmpty) {
        final metaAvatar = authMeta?['avatar_url'] as String?;
        if (metaAvatar != null && metaAvatar.trim().isNotEmpty) {
          avatarUrl = metaAvatar.trim();
        }
      }
      if (avatarUrl == null || avatarUrl.isEmpty) {
        try {
          final sessionRow = await db.getOptional('SELECT avatar_url FROM local_auth_session WHERE id = ?', ['active_session']);
          final saved = sessionRow?['avatar_url'] as String?;
          if (saved != null && saved.trim().isNotEmpty) {
            avatarUrl = saved.trim();
          }
        } catch (_) {}
      }
      if ((avatarUrl == null || avatarUrl.isEmpty) && uid.isNotEmpty && uid != 'local_guest') {
        try {
          final client = _supabaseClient;
          if (client != null) {
            final files = await client.storage
                .from('avatars')
                .list(path: uid)
                .timeout(const Duration(milliseconds: 1500));
            final match = files.where((f) => f.name.startsWith('avatar.')).firstOrNull;
            if (match != null) {
              final raw = client.storage.from('avatars').getPublicUrl('$uid/${match.name}');
              avatarUrl = '$raw?t=${DateTime.now().millisecondsSinceEpoch}';
            }
          }
        } catch (_) {}
      }

      // 4. Self-heal: persist recovered fields locally only when actually changed
      try {
        await db.execute(
          'UPDATE local_auth_session SET avatar_url = COALESCE(?, avatar_url), display_name = ? WHERE id = ?',
          [avatarUrl, name, 'active_session'],
        );
        final profileNeedsUpdate = rows.isNotEmpty &&
            (dbName != name ||
                dbTitle != title ||
                (avatarUrl != null &&
                    avatarUrl.isNotEmpty &&
                    dbAvatarUrl != avatarUrl));
        if (uid.isNotEmpty && uid != 'local_guest' && profileNeedsUpdate) {
          await db.execute(
            'UPDATE user_profiles SET avatar_url = COALESCE(?, avatar_url), name = ?, title = ? WHERE user_id = ?',
            [avatarUrl, name, title, uid],
          );
        }
      } catch (_) {}

      return UserProfile(
        name: name,
        title: title,
        avatarColor: avatarColor,
        avatarUrl: avatarUrl,
        totalXp: totalXp,
        level: level,
        friendCode: friendCode,
      );
    } catch (e) {
      debugPrint('[UserProfileRepository] Error reading profile from db: $e');
    }

    return const UserProfile();
  }

  /// Saves user profile and performs write-through cache update.
  Future<void> saveProfile(
    String newName,
    String newTitle, {
    String? avatarColor,
    String? avatarUrl,
    bool clearAvatarUrl = false,
  }) async {
    final current = await getProfile();
    final uid = currentUserId;
    final targetAvatarUrl = clearAvatarUrl ? null : (avatarUrl ?? current.avatarUrl);

    final updated = current.copyWith(
      name: newName,
      title: newTitle,
      avatarColor: avatarColor ?? current.avatarColor,
      avatarUrl: targetAvatarUrl,
      clearAvatarUrl: clearAvatarUrl,
      level: globalUserLevel.value,
    );

    // 1. Optimistic write-through to cache & reactive notifier
    profileNotifier.value = updated;
    CacheService().set<UserProfile>(_cacheKey, updated, ttl: const Duration(minutes: 15));

    // 2. Persist in local_auth_session table
    try {
      await db.execute('''
        UPDATE local_auth_session SET
          display_name = ?,
          avatar_url = ?
        WHERE id = 'active_session'
      ''', [newName, targetAvatarUrl]);
    } catch (e) {
      debugPrint('[UserProfileRepository] local_auth_session sync error: $e');
    }

    // 3. Persist in Supabase Auth user_metadata (cross-device cloud persistence)
    final client = _supabaseClient;
    if (client?.auth.currentUser != null) {
      try {
        final metaData = <String, dynamic>{
          'display_name': newName,
          'title': newTitle,
          'callsign': newTitle,
        };
        if (targetAvatarUrl != null) {
          metaData['avatar_url'] = targetAvatarUrl;
        }
        await client!.auth.updateUser(
          UserAttributes(data: metaData),
        );
      } catch (e) {
        debugPrint('[UserProfileRepository] Supabase auth updateUser metadata notice: $e');
      }
    }

    if (!isDatabaseInitialized) return;

    // 4. Persist in SQLite user_profiles table (synced by PowerSync)
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final existing = (uid.isNotEmpty && uid != 'local_guest')
          ? await db.getOptional('SELECT id FROM user_profiles WHERE user_id = ? LIMIT 1', [uid])
          : null;

      if (existing != null) {
        final existingId = existing['id'] as String;
        await db.execute('''
          UPDATE user_profiles SET
            name = ?,
            title = ?,
            avatar_color = ?,
            avatar_url = ?,
            updated_at = ?
          WHERE id = ?
        ''', [newName, newTitle, updated.avatarColor, targetAvatarUrl, nowUtc, existingId]).timeout(const Duration(seconds: 4));
      } else {
        final profileId = IdGenerator.generateDeterministicId('profile_${uid.isNotEmpty ? uid : "default"}');
        await db.execute('''
          INSERT INTO user_profiles (id, user_id, name, title, avatar_color, avatar_url, friend_code, total_xp, level, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
        ''', [profileId, uid, newName, newTitle, updated.avatarColor, targetAvatarUrl, updated.friendCode, globalUserLevel.value, nowUtc, nowUtc]).timeout(const Duration(seconds: 4));
      }

      await syncGlobalUserLevel();
    } catch (e) {
      debugPrint('[UserProfileRepository] Error persisting profile: $e');
    }
  }

  /// Uploads avatar binary to Supabase Storage and updates the profile record.
  /// Deduplicates by hashing bytes so identical images are not uploaded multiple times.
  Future<String?> uploadAvatar(Uint8List imageBytes, {String contentType = 'image/jpeg'}) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw Exception('User is not authenticated');
    }

    final hash = sha256.convert(imageBytes).toString();
    final current = await getProfile();
    if (_lastUploadedAvatarHash == hash && current.avatarUrl != null && current.avatarUrl!.isNotEmpty) {
      debugPrint('[UserProfileRepository] Avatar unchanged (hash match), skipping redundant upload');
      return current.avatarUrl;
    }

    final ext = contentType.contains('png')
        ? 'png'
        : (contentType.contains('webp') ? 'webp' : 'jpg');
    final storagePath = '$uid/avatar.$ext';

    final client = _supabaseClient;
    if (client == null) {
      throw StateError('Supabase client is not initialized.');
    }

    // 1. Upload to Supabase Storage
    await client.storage
        .from('avatars')
        .uploadBinary(
          storagePath,
          imageBytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    // 2. Get Public CDN URL with cache-busting timestamp
    final rawUrl = client.storage
        .from('avatars')
        .getPublicUrl(storagePath);
    final cacheBusterUrl = '$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    // 3. Persist in Supabase Auth user_metadata so it is permanently tied to the auth session
    try {
      await client.auth.updateUser(
        UserAttributes(data: {'avatar_url': cacheBusterUrl}),
      );
    } catch (e) {
      debugPrint('[UserProfileRepository] Notice updating auth user metadata: $e');
    }

    // 4. Save to profile (local SQLite + PowerSync + local_auth_session)
    await saveProfile(
      current.name,
      current.title,
      avatarColor: current.avatarColor,
      avatarUrl: cacheBusterUrl,
    );

    _lastUploadedAvatarHash = hash;
    return cacheBusterUrl;
  }

  /// Removes avatar from Supabase Storage and clears avatar_url from profile.
  Future<void> removeAvatar() async {
    _lastUploadedAvatarHash = null;
    final uid = currentUserId;
    final client = _supabaseClient;
    if (client != null && uid.isNotEmpty) {
      try {
        await client.storage.from('avatars').remove([
          '$uid/avatar.jpg',
          '$uid/avatar.png',
          '$uid/avatar.webp',
        ]);
      } catch (e) {
        debugPrint('[UserProfileRepository] Storage avatar remove error: $e');
      }
    }

    if (client != null) {
      try {
        await client.auth.updateUser(
          UserAttributes(data: {'avatar_url': null}),
        );
      } catch (e) {
        debugPrint('[UserProfileRepository] auth.updateUser avatar error: $e');
      }
    }

    final current = await getProfile();
    await saveProfile(
      current.name,
      current.title,
      avatarColor: current.avatarColor,
      clearAvatarUrl: true,
    );
  }
}

