import 'dart:async';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';

class UserProfile {
  final String name;
  final String title;
  final String avatarColor;

  const UserProfile({
    this.name = 'Commander',
    this.title = 'Specialist',
    this.avatarColor = '#6366F1',
  });
}

/// Repository managing user profile data with caching and non-blocking updates.
class UserProfileRepository {
  static final UserProfileRepository _instance = UserProfileRepository._internal();
  factory UserProfileRepository() => _instance;
  UserProfileRepository._internal();

  static const String _cacheKey = 'user_profile_data';

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
      final rows = await db.getAll('SELECT name, title, avatar_color FROM user_profile LIMIT 1');
      if (rows.isNotEmpty) {
        final r = rows.first;
        return UserProfile(
          name: (r['name'] as String?) ?? 'Commander',
          title: (r['title'] as String?) ?? 'Specialist',
          avatarColor: (r['avatar_color'] as String?) ?? '#6366F1',
        );
      }
    } catch (_) {}

    return const UserProfile();
  }

  /// Saves user profile and performs write-through cache update.
  Future<void> saveProfile(String newName, String newTitle, {String? avatarColor}) async {
    final updated = UserProfile(
      name: newName,
      title: newTitle,
      avatarColor: avatarColor ?? '#6366F1',
    );

    // Optimistic write-through to cache
    CacheService().set<UserProfile>(_cacheKey, updated, ttl: const Duration(minutes: 15));

    if (!isDatabaseInitialized) return;

    try {
      await db.execute('''
        INSERT OR REPLACE INTO user_profile (id, name, title, avatar_color)
        VALUES ('singleton_profile', ?, ?, ?)
      ''', [newName, newTitle, updated.avatarColor]).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
