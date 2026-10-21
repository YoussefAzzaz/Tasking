import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';

/// Repository managing task tags with caching, tag discovery, and non-blocking operations.
class TagRepository {
  static final TagRepository _instance = TagRepository._internal();
  factory TagRepository() => _instance;
  TagRepository._internal();

  static const String _cacheKey = 'task_tags_list';

  static const List<String> defaultTags = [
    'urgent',
    'deepwork',
    'meeting',
    'review',
    'errand',
    'backend',
    'frontend'
  ];

  /// Retrieves all available tags from cache or database in a non-blocking manner.
  Future<List<String>> getTags({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_cacheKey);
    }

    return CacheService().getOrFetch<List<String>>(
      _cacheKey,
      _fetchTagsFromDb,
      ttl: const Duration(minutes: 10),
      staleWhileRevalidate: true,
      timeout: const Duration(seconds: 3),
      fallback: defaultTags,
    );
  }

  Future<List<String>> _fetchTagsFromDb() async {
    if (!isDatabaseInitialized) return defaultTags;

    final tagSet = <String>{...defaultTags};
    final uid = currentUserId;

    try {
      final tagQuery = uid.isNotEmpty
          ? 'SELECT name FROM tags WHERE user_id = ? ORDER BY name ASC'
          : 'SELECT name FROM tags ORDER BY name ASC';
      final tagParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final tagRows = await db.getAll(tagQuery, tagParams);

      for (final r in tagRows) {
        final name = (r['name'] as String?)?.trim().replaceAll('@', '');
        if (name != null && name.isNotEmpty) tagSet.add(name);
      }
    } catch (_) {}

    try {
      final taskQuery = uid.isNotEmpty
          ? 'SELECT tags FROM tasks WHERE tags IS NOT NULL AND user_id = ?'
          : 'SELECT tags FROM tasks WHERE tags IS NOT NULL';
      final taskParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final taskRows = await db.getAll(taskQuery, taskParams);

      for (final r in taskRows) {
        final tagsStr = r['tags'] as String?;
        if (tagsStr != null && tagsStr.isNotEmpty) {
          for (final t in tagsStr.split(',')) {
            final clean = t.trim().replaceAll('@', '');
            if (clean.isNotEmpty) tagSet.add(clean);
          }
        }
      }
    } catch (_) {}

    final result = tagSet.toList()..sort();
    return result;
  }

  /// Adds a new tag to the database and invalidates the tag cache.
  Future<void> addTag(String tagName) async {
    final clean = tagName.trim().replaceAll('@', '');
    if (clean.isEmpty) return;

    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    final uid = currentUserId;
    try {
      final tagId = IdGenerator.generateDeterministicId('tag_${clean.toLowerCase()}');
      await db.execute('''
        INSERT OR IGNORE INTO tags (id, user_id, name, color, created_at)
        VALUES (?, ?, ?, '#6366F1', ?)
      ''', [
        tagId,
        uid,
        clean,
        DateTime.now().toUtc().toIso8601String(),
      ]).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[TagRepository] Error adding tag: $e');
    }
  }

  /// Deletes a tag from the database and invalidates the tag cache.
  Future<void> deleteTag(String tagName) async {
    final clean = tagName.trim().replaceAll('@', '');
    if (clean.isEmpty) return;

    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      await db.execute('DELETE FROM tags WHERE name = ?', [clean]);
    } catch (e) {
      debugPrint('[TagRepository] Error deleting tag: $e');
    }
  }
}
