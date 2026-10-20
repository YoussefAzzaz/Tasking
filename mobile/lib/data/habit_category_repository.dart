import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';

export 'package:axis/ui/habits/widgets/habit_form_widgets.dart' show HabitCategory;

/// Repository managing habit categories with caching, reactive streams, and decoupled queries.
class HabitCategoryRepository {
  static final HabitCategoryRepository _instance = HabitCategoryRepository._internal();
  factory HabitCategoryRepository() => _instance;
  HabitCategoryRepository._internal();

  static const String _cacheKey = 'habit_categories_list';

  /// Watches habit categories stream for real-time reactive UI.
  Stream<List<HabitCategory>> watchCategories() {
    return db
        .watch('SELECT id, name, icon, color FROM habit_categories ORDER BY name ASC')
        .map((rows) {
      final list = rows
          .map((r) => HabitCategory(
                id: r['id'] as String,
                name: r['name'] as String,
                icon: (r['icon'] as String?) ?? 'fitness',
                color: (r['color'] as String?) ?? '#10B981',
              ))
          .toList();
      // Keep cache updated with latest stream emission
      CacheService().set<List<HabitCategory>>(_cacheKey, list, ttl: const Duration(minutes: 10));
      return list;
    });
  }

  /// Retrieves habit categories with cache-first strategy.
  Future<List<HabitCategory>> getCategories({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_cacheKey);
    }

    return CacheService().getOrFetch<List<HabitCategory>>(
      _cacheKey,
      _fetchCategoriesFromDb,
      ttl: const Duration(minutes: 10),
      staleWhileRevalidate: true,
      timeout: const Duration(seconds: 3),
      fallback: <HabitCategory>[],
    );
  }

  Future<List<HabitCategory>> _fetchCategoriesFromDb() async {
    if (!isDatabaseInitialized) return [];

    try {
      final rows = await db.getAll('SELECT id, name, icon, color FROM habit_categories ORDER BY name ASC');
      return rows
          .map((r) => HabitCategory(
                id: r['id'] as String,
                name: r['name'] as String,
                icon: (r['icon'] as String?) ?? 'fitness',
                color: (r['color'] as String?) ?? '#10B981',
              ))
          .toList();
    } catch (e) {
      debugPrint('[HabitCategoryRepository] Error fetching categories: $e');
      return [];
    }
  }

  /// Adds a new habit category and updates the cache.
  Future<void> addCategory({
    required String name,
    String icon = 'fitness',
    String color = '#10B981',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final id = 'cat_${DateTime.now().microsecondsSinceEpoch}';

    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      await db.execute(
        'INSERT OR IGNORE INTO habit_categories (id, name, icon, color) VALUES (?, ?, ?, ?)',
        [id, cleanName, icon, color],
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[HabitCategoryRepository] Error adding category: $e');
    }
  }

  /// Deletes a habit category and disassociates habits in a clean, non-blocking operation.
  Future<void> deleteCategory(String id, {String? name}) async {
    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      final rawId = id.replaceFirst('discovered_', '');
      final catName = name ?? '';

      await db.execute('''
        DELETE FROM habit_categories
        WHERE id = ? OR id = ? OR LOWER(name) = LOWER(?)
      ''', [id, rawId, catName]).timeout(const Duration(seconds: 4));

      if (catName.isNotEmpty) {
        await db.execute('''
          UPDATE habits 
          SET kind = NULL 
          WHERE LOWER(COALESCE(kind, '')) = LOWER(?)
        ''', [catName]).timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('[HabitCategoryRepository] Error deleting category: $e');
    }
  }
}
