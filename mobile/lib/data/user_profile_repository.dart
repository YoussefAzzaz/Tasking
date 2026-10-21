import 'dart:async';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';

class UserProfile {
  final String name;
  final String title;
  final String avatarColor;
  final int totalXp;
  final int level;

  const UserProfile({
    this.name = 'Commander',
    this.title = 'Specialist',
    this.avatarColor = '#6366F1',
    this.totalXp = 0,
    this.level = 1,
  });
}

/// Repository managing user profile data with caching and multi-user isolation.
/// Syncs profile, XP, and Level unique to each user via PowerSync to Supabase.
class UserProfileRepository {
  static final UserProfileRepository _instance = UserProfileRepository._internal();
  factory UserProfileRepository() => _instance;
  UserProfileRepository._internal();

  String get _cacheKey => 'user_profile_data_${currentUserId.isNotEmpty ? currentUserId : "global"}';

  /// Retrieves user profile instantly from cache, or fetches from SQLite.
  Future<UserProfile> getProfile({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_cacheKey);
    }

    return CacheService().getOrFetch<UserProfile>(
      _cacheKey,
      _fetchProfileFromDb,
      ttl: const Duration(minutes: 15),
      staleWhileRevalidate: true,
      timeout: const Duration(seconds: 3),
      fallback: const UserProfile(),
    );
  }

  Future<UserProfile> _fetchProfileFromDb() async {
    if (!isDatabaseInitialized) return const UserProfile();

    try {
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? 'SELECT name, title, avatar_color, total_xp, level FROM user_profiles WHERE user_id = ? LIMIT 1'
          : 'SELECT name, title, avatar_color, total_xp, level FROM user_profiles LIMIT 1';
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rows = await db.getAll(query, params);
      if (rows.isNotEmpty) {
        final r = rows.first;
        return UserProfile(
          name: (r['name'] as String?) ?? 'Commander',
          title: (r['title'] as String?) ?? 'Specialist',
          avatarColor: (r['avatar_color'] as String?) ?? '#6366F1',
          totalXp: (r['total_xp'] as num?)?.toInt() ?? 0,
          level: (r['level'] as num?)?.toInt() ?? 1,
        );
      }
    } catch (_) {}

    return const UserProfile();
  }

  /// Saves user profile and performs write-through cache update.
  Future<void> saveProfile(String newName, String newTitle, {String? avatarColor}) async {
    final uid = currentUserId;
    final updated = UserProfile(
      name: newName,
      title: newTitle,
      avatarColor: avatarColor ?? '#6366F1',
      totalXp: 0,
      level: globalUserLevel.value,
    );

    // Optimistic write-through to cache
    CacheService().set<UserProfile>(_cacheKey, updated, ttl: const Duration(minutes: 15));

    if (!isDatabaseInitialized) return;

    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final profileId = IdGenerator.generateDeterministicId('profile_${uid.isNotEmpty ? uid : "default"}');
      await db.execute('''
        INSERT INTO user_profiles (id, user_id, name, title, avatar_color, total_xp, level, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 0, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          name = excluded.name,
          title = excluded.title,
          avatar_color = excluded.avatar_color,
          updated_at = excluded.updated_at
      ''', [profileId, uid, newName, newTitle, updated.avatarColor, globalUserLevel.value, nowUtc, nowUtc]).timeout(const Duration(seconds: 4));

      await syncGlobalUserLevel();
    } catch (_) {}
  }
}
