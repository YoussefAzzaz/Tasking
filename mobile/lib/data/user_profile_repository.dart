import 'dart:async';
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

  const UserProfile({
    this.name = 'Commander',
    this.title = 'Specialist',
    this.avatarColor = '#6366F1',
    this.avatarUrl,
    this.totalXp = 0,
    this.level = 1,
  });

  UserProfile copyWith({
    String? name,
    String? title,
    String? avatarColor,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    int? totalXp,
    int? level,
  }) {
    return UserProfile(
      name: name ?? this.name,
      title: title ?? this.title,
      avatarColor: avatarColor ?? this.avatarColor,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      totalXp: totalXp ?? this.totalXp,
      level: level ?? this.level,
    );
  }
}

/// Repository managing user profile data with caching and multi-user isolation.
/// Syncs profile, XP, and Level unique to each user via PowerSync to Supabase.
class UserProfileRepository {
  static final UserProfileRepository _instance = UserProfileRepository._internal();
  factory UserProfileRepository() => _instance;
  UserProfileRepository._internal();

  final ValueNotifier<UserProfile> profileNotifier =
      ValueNotifier<UserProfile>(const UserProfile());

  String get _cacheKey => 'user_profile_data_${currentUserId.isNotEmpty ? currentUserId : "global"}';

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
      timeout: const Duration(seconds: 3),
      fallback: const UserProfile(),
    );
    profileNotifier.value = profile;
    return profile;
  }

  Future<UserProfile> _fetchProfileFromDb() async {
    if (!isDatabaseInitialized) return const UserProfile();

    try {
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? 'SELECT name, title, avatar_color, avatar_url, total_xp, level FROM user_profiles WHERE user_id = ? LIMIT 1'
          : 'SELECT name, title, avatar_color, avatar_url, total_xp, level FROM user_profiles LIMIT 1';
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rows = await db.getAll(query, params);

      String name = 'Commander';
      String title = 'Specialist';
      String avatarColor = '#6366F1';
      String? avatarUrl;
      int totalXp = 0;
      int level = 1;

      if (rows.isNotEmpty) {
        final r = rows.first;
        name = (r['name'] as String?) ?? 'Commander';
        title = (r['title'] as String?) ?? 'Specialist';
        avatarColor = (r['avatar_color'] as String?) ?? '#6366F1';
        avatarUrl = r['avatar_url'] as String?;
        totalXp = (r['total_xp'] as num?)?.toInt() ?? 0;
        level = (r['level'] as num?)?.toInt() ?? 1;
      }

      // Multi-layer fallback to prevent avatar from ever disappearing on restart:
      // 1. Check Supabase Auth user_metadata (cached locally by Supabase Auth SDK)
      if (avatarUrl == null || avatarUrl.isEmpty) {
        try {
          final authMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
          if (authMeta != null && authMeta['avatar_url'] is String && (authMeta['avatar_url'] as String).isNotEmpty) {
            avatarUrl = authMeta['avatar_url'] as String;
          }
        } catch (_) {}
      }

      // 2. Check local_auth_session table
      if (avatarUrl == null || avatarUrl.isEmpty) {
        try {
          final sessionRow = await db.getOptional('SELECT avatar_url FROM local_auth_session WHERE id = ?', ['active_session']);
          if (sessionRow != null && sessionRow['avatar_url'] != null) {
            final saved = sessionRow['avatar_url'] as String?;
            if (saved != null && saved.isNotEmpty) {
              avatarUrl = saved;
            }
          }
        } catch (_) {}
      }

      // 3. Fallback: if user is signed in, check Supabase Storage directly
      if ((avatarUrl == null || avatarUrl.isEmpty) && uid.isNotEmpty) {
        try {
          final files = await Supabase.instance.client.storage
              .from('avatars')
              .list(path: uid)
              .timeout(const Duration(milliseconds: 1500));
          final match = files.where((f) => f.name.startsWith('avatar.')).firstOrNull;
          if (match != null) {
            final raw = Supabase.instance.client.storage.from('avatars').getPublicUrl('$uid/${match.name}');
            avatarUrl = '$raw?t=${DateTime.now().millisecondsSinceEpoch}';
          }
        } catch (_) {
          try {
            avatarUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl('$uid/avatar.png');
          } catch (_) {}
        }
      }

      // 4. Self-heal: persist recovered avatarUrl locally so subsequent reads are immediate
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        try {
          await db.execute(
            'UPDATE local_auth_session SET avatar_url = ? WHERE id = ?',
            [avatarUrl, 'active_session'],
          );
          if (uid.isNotEmpty) {
            await db.execute(
              'UPDATE user_profiles SET avatar_url = ? WHERE user_id = ?',
              [avatarUrl, uid],
            );
          }
        } catch (_) {}
      }

      return UserProfile(
        name: name,
        title: title,
        avatarColor: avatarColor,
        avatarUrl: avatarUrl,
        totalXp: totalXp,
        level: level,
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

    final updated = UserProfile(
      name: newName,
      title: newTitle,
      avatarColor: avatarColor ?? current.avatarColor,
      avatarUrl: targetAvatarUrl,
      totalXp: current.totalXp,
      level: globalUserLevel.value,
    );

    // Optimistic write-through to cache & reactive notifier
    profileNotifier.value = updated;
    CacheService().set<UserProfile>(_cacheKey, updated, ttl: const Duration(minutes: 15));

    // Save avatar_url into local_auth_session table so it survives any PowerSync remote table resets
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

    if (!isDatabaseInitialized) return;

    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final profileId = IdGenerator.generateDeterministicId('profile_${uid.isNotEmpty ? uid : "default"}');
      final existing = await db.getOptional('SELECT id FROM user_profiles WHERE id = ?', [profileId]);
      if (existing != null) {
        await db.execute('''
          UPDATE user_profiles SET
            name = ?,
            title = ?,
            avatar_color = ?,
            avatar_url = ?,
            updated_at = ?
          WHERE id = ?
        ''', [newName, newTitle, updated.avatarColor, targetAvatarUrl, nowUtc, profileId]).timeout(const Duration(seconds: 4));
      } else {
        await db.execute('''
          INSERT INTO user_profiles (id, user_id, name, title, avatar_color, avatar_url, total_xp, level, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?, ?)
        ''', [profileId, uid, newName, newTitle, updated.avatarColor, targetAvatarUrl, globalUserLevel.value, nowUtc, nowUtc]).timeout(const Duration(seconds: 4));
      }

      await syncGlobalUserLevel();
    } catch (e) {
      debugPrint('[UserProfileRepository] Error persisting profile: $e');
    }
  }

  /// Uploads avatar binary to Supabase Storage and updates the profile record.
  Future<String?> uploadAvatar(Uint8List imageBytes, {String contentType = 'image/jpeg'}) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw Exception('User is not authenticated');
    }

    final ext = contentType.contains('png')
        ? 'png'
        : (contentType.contains('webp') ? 'webp' : 'jpg');
    final storagePath = '$uid/avatar.$ext';

    // 1. Upload to Supabase Storage
    await Supabase.instance.client.storage
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
    final rawUrl = Supabase.instance.client.storage
        .from('avatars')
        .getPublicUrl(storagePath);
    final cacheBusterUrl = '$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}';

    // 3. Persist in Supabase Auth user_metadata so it is permanently tied to the auth session
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': cacheBusterUrl}),
      );
    } catch (e) {
      debugPrint('[UserProfileRepository] Notice updating auth user metadata: $e');
    }

    // 4. Save to profile (local SQLite + PowerSync + local_auth_session)
    final current = await getProfile();
    await saveProfile(
      current.name,
      current.title,
      avatarColor: current.avatarColor,
      avatarUrl: cacheBusterUrl,
    );

    return cacheBusterUrl;
  }

  /// Removes avatar from Supabase Storage and clears avatar_url from profile.
  Future<void> removeAvatar() async {
    final uid = currentUserId;
    if (uid.isNotEmpty) {
      try {
        await Supabase.instance.client.storage.from('avatars').remove([
          '$uid/avatar.jpg',
          '$uid/avatar.png',
          '$uid/avatar.webp',
        ]);
      } catch (e) {
        debugPrint('[UserProfileRepository] Storage avatar remove error: $e');
      }
    }

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );
    } catch (e) {
      debugPrint('[UserProfileRepository] auth.updateUser avatar error: $e');
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

