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

  /// Predefined system tag identifiers excluded from custom user tag lists.
  static const List<String> systemTags = [
    'urgent',
    'deepwork',
    'meeting',
    'review',
    'errand',
    'backend',
    'frontend',
  ];

  static final String _systemTagsSql =
      systemTags.map((t) => "'$t'").join(', ');

  /// Watches tags stream for real-time reactive UI.
  Stream<List<String>> watchTags() {
    if (!isDatabaseInitialized) {
      return Stream.value(<String>[]);
    }
    final uid = currentUserId;
    final tagQuery = uid.isNotEmpty
        ? "SELECT name FROM tags WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND LOWER(name) NOT IN ($_systemTagsSql) ORDER BY name ASC"
        : "SELECT name FROM tags WHERE LOWER(name) NOT IN ($_systemTagsSql) ORDER BY name ASC";
    final tagParams = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db.watch(tagQuery, parameters: tagParams).map((rows) {
      final tagSet = <String>{};
      for (final r in rows) {
        final name = (r['name'] as String?)?.trim().replaceAll('@', '');
        if (name != null && name.isNotEmpty) tagSet.add(name);
      }
      final result = tagSet.toList()..sort();
      CacheService().set<List<String>>(_cacheKey, result, ttl: const Duration(minutes: 10));
      return result;
    });
  }

  /// Retrieves all available user-created tags from cache or database in a non-blocking manner.
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
      fallback: <String>[],
    );
  }

  Future<List<String>> _fetchTagsFromDb() async {
    if (!isDatabaseInitialized) return [];

    final tagSet = <String>{};
    final uid = currentUserId;

    try {
      final tagQuery = uid.isNotEmpty
          ? "SELECT name FROM tags WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND LOWER(name) NOT IN ($_systemTagsSql) ORDER BY name ASC"
          : "SELECT name FROM tags WHERE LOWER(name) NOT IN ($_systemTagsSql) ORDER BY name ASC";
      final tagParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final tagRows = await db.getAll(tagQuery, tagParams);

      for (final r in tagRows) {
        final name = (r['name'] as String?)?.trim().replaceAll('@', '');
        if (name != null && name.isNotEmpty) tagSet.add(name);
      }
    } catch (e) {
      debugPrint('[TagRepository] Error fetching custom tags: $e');
    }

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

  /// Deletes a tag from the database and any task associations, then invalidates the tag cache.
  Future<void> deleteTag(String tagName) async {
    final clean = tagName.trim().replaceAll('@', '');
    if (clean.isEmpty) return;

    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      await db.writeTransaction((tx) async {
        // 1. Delete from tags table
        await tx.execute('DELETE FROM tags WHERE LOWER(name) = LOWER(?)', [clean]);

        // 2. Disassociate this tag from any tasks that currently have it
        final uid = currentUserId;
        final taskQuery = uid.isNotEmpty
            ? "SELECT id, tags FROM tasks WHERE tags LIKE ? AND (user_id = ? OR user_id IS NULL OR user_id = '')"
            : "SELECT id, tags FROM tasks WHERE tags LIKE ?";
        final taskParams = uid.isNotEmpty ? ['%$clean%', uid] : <dynamic>['%$clean%'];
        final taskRows = await tx.getAll(taskQuery, taskParams);

        for (final row in taskRows) {
          final id = row['id'] as String;
          final tagsStr = row['tags'] as String? ?? '';
          final tagsList = tagsStr
              .split(',')
              .map((t) => t.trim().replaceAll('@', ''))
              .where((t) => t.isNotEmpty)
              .toList();
          if (tagsList.any((t) => t.toLowerCase() == clean.toLowerCase())) {
            tagsList.removeWhere((t) => t.toLowerCase() == clean.toLowerCase());
            final newTags = tagsList.isEmpty ? null : tagsList.join(',');
            await tx.execute('UPDATE tasks SET tags = ? WHERE id = ?', [newTags, id]);
          }
        }
      });
    } catch (e) {
      debugPrint('[TagRepository] Error deleting tag: $e');
    }
  }
}
