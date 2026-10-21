import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

export 'package:axis/ui/habits/widgets/habit_form_widgets.dart' show HabitCategory;

/// Repository managing habit categories with caching, reactive streams, and decoupled queries.
class HabitCategoryRepository {
  static final HabitCategoryRepository _instance = HabitCategoryRepository._internal();
  factory HabitCategoryRepository() => _instance;
  HabitCategoryRepository._internal();

  static const String _cacheKey = 'habit_categories_list';

  /// Broadcasts newly added category names so UI components can clear any local deletion exclusions.
  static final ValueNotifier<String?> categoryAddedNotifier = ValueNotifier<String?>(null);

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



      // Discover categories from habits table as well
      final habitQuery = uid.isNotEmpty
          ? "SELECT DISTINCT kind, icon, color FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND kind IS NOT NULL AND kind != '' AND LOWER(kind) != 'prayers'"
          : "SELECT DISTINCT kind, icon, color FROM habits WHERE kind IS NOT NULL AND kind != '' AND LOWER(kind) != 'prayers'";
      final habitRows = await db.getAll(habitQuery, params);

      for (final hr in habitRows) {
        final catName = (hr['kind'] as String?)?.trim() ?? '';
        if (catName.isNotEmpty &&
            catName.toLowerCase() != 'general routines' &&
            !knownNames.contains(catName.toLowerCase())) {
          knownNames.add(catName.toLowerCase());
          categories.add(
            HabitCategory(
              id: 'discovered_$catName',
              name: catName,
              icon: (hr['icon'] as String?) ?? 'fitness',
              color: (hr['color'] as String?) ?? '#10B981',
            ),
          );
        }
      }

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
    final id = IdGenerator.generateDeterministicId(
        'cat_${uid.isNotEmpty ? uid : "local"}_${cleanName.toLowerCase()}');
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

      // 2. Direct upsert to Supabase if connected
      if (Supabase.instance.client.auth.currentSession != null && uid.isNotEmpty) {
        try {
          await Supabase.instance.client.from('habit_categories').upsert({
            'id': id,
            'user_id': uid,
            'name': cleanName,
            'icon': icon,
            'color': color,
            'sort_order': 99,
            'created_at': nowUtc,
            'updated_at': nowUtc,
          });
        } catch (e) {
          debugPrint('[HabitCategoryRepository] Direct Supabase upsert notice: $e');
        }
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
      final rawId = id.replaceFirst('discovered_', '');
      final catName = (name ?? '').trim();

      // 1. Delete from PowerSync habit_categories
      final deleteQuery = uid.isNotEmpty
          ? "DELETE FROM habit_categories WHERE (id = ? OR id = ? OR LOWER(name) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
          : 'DELETE FROM habit_categories WHERE id = ? OR id = ? OR LOWER(name) = LOWER(?)';
      final deleteParams = uid.isNotEmpty ? [id, rawId, catName, uid] : [id, rawId, catName];
      await db.execute(deleteQuery, deleteParams);

      // 2. Unset category from habits table so habits move cleanly to General Routines
      final updateQuery = uid.isNotEmpty
          ? "UPDATE habits SET kind = NULL WHERE (LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
          : "UPDATE habits SET kind = NULL WHERE LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?) OR LOWER(COALESCE(kind, '')) = LOWER(?)";
      final updateParams = uid.isNotEmpty ? [catName, id, rawId, uid] : [catName, id, rawId];
      await db.execute(updateQuery, updateParams);

      // 3. Delete directly from Supabase if connected
      if (Supabase.instance.client.auth.currentSession != null && uid.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('habit_categories')
              .delete()
              .eq('user_id', uid)
              .or('id.eq.$id,id.eq.$rawId,name.ilike.$catName');
          await Supabase.instance.client
              .from('habits')
              .update({'kind': null})
              .eq('user_id', uid)
              .or('kind.ilike.$catName,kind.eq.$id,kind.eq.$rawId');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[HabitCategoryRepository] Error deleting category: $e');
    }
  }
}
