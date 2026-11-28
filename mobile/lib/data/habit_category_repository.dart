import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';

/// Represents a user habit category
class HabitCategory {
  final String id;
  final String name;
  final String icon;
  final String color;

  const HabitCategory({
    required this.id,
    required this.name,
    this.icon = 'fitness',
    this.color = '#10B981',
  });
}

/// Repository managing habit categories with caching, reactive streams, and decoupled queries.
class HabitCategoryRepository {
  static final HabitCategoryRepository _instance = HabitCategoryRepository._internal();
  factory HabitCategoryRepository() => _instance;
  HabitCategoryRepository._internal();

  static const String _cacheKey = 'habit_categories_list';

  /// Broadcasts newly added category names so UI components can clear any local deletion exclusions.
  static final ValueNotifier<String?> categoryAddedNotifier = ValueNotifier<String?>(null);

  /// Resolves the display color for a habit based on its category or color attribute.
  Color resolveHabitCategoryColor(Habit habit, [List<HabitCategory>? categories]) {
    if (categories != null && habit.category.trim().isNotEmpty) {
      final catName = habit.category.trim().toLowerCase();
      for (final c in categories) {
        if (c.name.trim().toLowerCase() == catName || c.id.trim().toLowerCase() == catName) {
          if (c.color.isNotEmpty) {
            try {
              return Color(int.parse(c.color.replaceFirst('#', '0xFF')));
            } catch (_) {}
          }
        }
      }
    }
    if (habit.color.isNotEmpty) {
      try {
        return Color(int.parse(habit.color.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }
    return AxisColors.tertiary;
  }

  /// Watches habit categories stream for real-time reactive UI.
  Stream<List<HabitCategory>> watchCategories() {
    if (!isDatabaseInitialized) {
      return Stream.value(<HabitCategory>[]);
    }
    final uid = currentUserId;
    final query = uid.isNotEmpty
        ? "SELECT id, name, icon, color FROM habit_categories WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND LOWER(name) != 'prayers' AND id != 'cat_prayers' ORDER BY sort_order ASC, name ASC"
        : "SELECT id, name, icon, color FROM habit_categories WHERE LOWER(name) != 'prayers' AND id != 'cat_prayers' ORDER BY sort_order ASC, name ASC";
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db
        .watch(query, parameters: params)
        .asyncMap((rows) async {
      final categories = <HabitCategory>[];
      final knownNames = <String>{};

      for (final r in rows) {
        final name = (r['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty && !knownNames.contains(name.toLowerCase())) {
          knownNames.add(name.toLowerCase());
          categories.add(HabitCategory(
            id: r['id'] as String,
            name: name,
            icon: (r['icon'] as String?) ?? 'fitness',
            color: (r['color'] as String?) ?? '#10B981',
          ));
        }
      }

      // Keep cache updated with latest stream emission
      CacheService().set<List<HabitCategory>>(_cacheKey, categories, ttl: const Duration(minutes: 5));
      return categories;
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
      ttl: const Duration(minutes: 2),
      staleWhileRevalidate: !forceRefresh,
      timeout: const Duration(seconds: 3),
      fallback: <HabitCategory>[],
    );
  }

  static String deterministicId(String uid, String name) =>
      IdGenerator.generateDeterministicId(
          'cat_${uid.isNotEmpty ? uid : "local"}_${name.trim().toLowerCase()}');

  /// Builds a real deterministic category model for orphaned habit kinds without
  /// fabricating synthetic `discovered_` IDs.
  static HabitCategory reconciledCategory(
    String name, {
    String icon = 'fitness',
    String color = '#10B981',
  }) {
    final clean = name.trim();
    return HabitCategory(
      id: deterministicId(currentUserId, clean),
      name: clean,
      icon: icon,
      color: color,
    );
  }

  /// Persists any non-built-in habit category kinds missing from habit_categories
  /// once into local SQLite so they sync as first-class records.
  Future<void> _reconcileOrphanHabitCategories(
    String uid,
    List<dynamic> params,
    List<HabitCategory> categories,
    Set<String> knownNames,
  ) async {
    final habitQuery = uid.isNotEmpty
        ? "SELECT DISTINCT kind, icon, color FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND kind IS NOT NULL AND kind != '' AND LOWER(kind) != 'prayers' AND (deleted_at IS NULL OR deleted_at = '')"
        : "SELECT DISTINCT kind, icon, color FROM habits WHERE kind IS NOT NULL AND kind != '' AND LOWER(kind) != 'prayers' AND (deleted_at IS NULL OR deleted_at = '')";
    final habitRows = await db.getAll(habitQuery, params);
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    for (final hr in habitRows) {
      final catName = (hr['kind'] as String?)?.trim() ?? '';
      if (catName.isNotEmpty &&
          catName.toLowerCase() != 'general routines' &&
          !knownNames.contains(catName.toLowerCase())) {
        knownNames.add(catName.toLowerCase());
        final cat = HabitCategory(
          id: deterministicId(uid, catName),
          name: catName,
          icon: (hr['icon'] as String?) ?? 'fitness',
          color: (hr['color'] as String?) ?? '#10B981',
        );
        categories.add(cat);
        try {
          await db.execute(
            'INSERT OR IGNORE INTO habit_categories (id, user_id, name, icon, color, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [cat.id, uid, cat.name, cat.icon, cat.color, 99, nowUtc, nowUtc],
          );
        } catch (e) {
          debugPrint('[HabitCategoryRepository] Reconcile category notice: $e');
        }
      }
    }
  }

  Future<List<HabitCategory>> _fetchCategoriesFromDb() async {
    if (!isDatabaseInitialized) return [];

    try {
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? "SELECT id, name, icon, color FROM habit_categories WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND LOWER(name) != 'prayers' AND id != 'cat_prayers' ORDER BY sort_order ASC, name ASC"
          : "SELECT id, name, icon, color FROM habit_categories WHERE LOWER(name) != 'prayers' AND id != 'cat_prayers' ORDER BY sort_order ASC, name ASC";
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rows = await db.getAll(query, params);
      final categories = <HabitCategory>[];
      final knownNames = <String>{};

      for (final r in rows) {
        final name = (r['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty && !knownNames.contains(name.toLowerCase())) {
          knownNames.add(name.toLowerCase());
          categories.add(HabitCategory(
            id: r['id'] as String,
            name: name,
            icon: (r['icon'] as String?) ?? 'fitness',
            color: (r['color'] as String?) ?? '#10B981',
          ));
        }
      }

      await _reconcileOrphanHabitCategories(uid, params, categories, knownNames);

      return categories;
    } catch (e) {
      debugPrint('[HabitCategoryRepository] Error fetching categories: $e');
      return [];
    }
  }

  /// Adds a new habit category, writes to local persistent table, syncs with PowerSync and Supabase.
  Future<void> addCategory({
    required String name,
    String icon = 'fitness',
    String color = '#10B981',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    if (cleanName.toLowerCase() == 'prayers') return;

    final uid = currentUserId;
    final id = deterministicId(uid, cleanName);
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      // 1. Save into PowerSync habit_categories (persists in SQLite offline and syncs automatically)
      final existing = await db.getOptional(
        'SELECT id FROM habit_categories WHERE id = ? OR (LOWER(name) = LOWER(?) AND (user_id = ? OR user_id IS NULL OR user_id = \'\'))',
        [id, cleanName, uid],
      );
      if (existing != null) {
        await db.execute(
          'UPDATE habit_categories SET name = ?, icon = ?, color = ?, updated_at = ? WHERE id = ?',
          [cleanName, icon, color, nowUtc, existing['id']],
        );
      } else {
        await db.execute(
          'INSERT INTO habit_categories (id, user_id, name, icon, color, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [id, uid, cleanName, icon, color, 99, nowUtc, nowUtc],
        );
      }

      // Notify UI that a category was added
      categoryAddedNotifier.value = cleanName;
    } catch (e) {
      debugPrint('[HabitCategoryRepository] Error adding category: $e');
    }
  }

  /// Deletes a habit category and disassociates habits in a clean, non-blocking operation.
  Future<void> deleteCategory(String id, {String? name}) async {
    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      final uid = currentUserId;
      final detId = name != null && name.trim().isNotEmpty
          ? deterministicId(uid, name)
          : id;
      String catName = (name ?? '').trim();
      if (catName.isEmpty) {
        final existing = await db.getOptional(
          'SELECT name FROM habit_categories WHERE id = ? OR id = ?',
          [id, detId],
        );
        catName = (existing?['name'] as String? ?? '').trim();
      }

      // 1. Delete from PowerSync habit_categories (automatically queued and synced)
      final deleteQuery = catName.isNotEmpty
          ? (uid.isNotEmpty
              ? "DELETE FROM habit_categories WHERE (id = ? OR id = ? OR LOWER(name) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : 'DELETE FROM habit_categories WHERE id = ? OR id = ? OR LOWER(name) = LOWER(?)')
          : (uid.isNotEmpty
              ? "DELETE FROM habit_categories WHERE (id = ? OR id = ?) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : 'DELETE FROM habit_categories WHERE id = ? OR id = ?');
      final deleteParams = catName.isNotEmpty
          ? (uid.isNotEmpty ? [id, detId, catName, uid] : [id, detId, catName])
          : (uid.isNotEmpty ? [id, detId, uid] : [id, detId]);
      await db.execute(deleteQuery, deleteParams);

      // 2. Unset category from habits table so habits move cleanly to General Routines
      final updateQuery = catName.isNotEmpty
          ? (uid.isNotEmpty
              ? "UPDATE habits SET kind = NULL WHERE (LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : "UPDATE habits SET kind = NULL WHERE LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?)")
          : (uid.isNotEmpty
              ? "UPDATE habits SET kind = NULL WHERE (LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : "UPDATE habits SET kind = NULL WHERE LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?)");
      final updateParams = catName.isNotEmpty
          ? (uid.isNotEmpty ? [catName, id, detId, uid] : [catName, id, detId])
          : (uid.isNotEmpty ? [id, detId, uid] : [id, detId]);
      await db.execute(updateQuery, updateParams);
    } catch (e) {
      debugPrint('[HabitCategoryRepository] Error deleting category: $e');
    }
  }
}
