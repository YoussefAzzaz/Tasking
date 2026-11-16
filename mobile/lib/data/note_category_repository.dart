import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoteCategory {
  final String id;
  final String name;
  final String icon;
  final String color;

  const NoteCategory({
    required this.id,
    required this.name,
    this.icon = 'article',
    this.color = '#0EA5E9',
  });

  NoteCategory copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
  }) {
    return NoteCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }
}

/// Repository managing note categories with caching, reactive streams, and decoupled queries.
class NoteCategoryRepository {
  static final NoteCategoryRepository _instance = NoteCategoryRepository._internal();
  factory NoteCategoryRepository() => _instance;
  NoteCategoryRepository._internal();

  static const String _cacheKey = 'note_categories_list';

  /// Broadcasts newly added category names so UI components can clear any local deletion exclusions.
  static final ValueNotifier<String?> categoryAddedNotifier = ValueNotifier<String?>(null);

  /// Watches note categories stream for real-time reactive UI.
  Stream<List<NoteCategory>> watchCategories() {
    if (!isDatabaseInitialized) {
      return Stream.value(<NoteCategory>[]);
    }
    final uid = currentUserId;
    final query = uid.isNotEmpty
        ? "SELECT id, name, icon, color FROM note_categories WHERE (user_id = ? OR user_id IS NULL OR user_id = '') ORDER BY sort_order ASC, name ASC"
        : "SELECT id, name, icon, color FROM note_categories ORDER BY sort_order ASC, name ASC";
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db.watch(query, parameters: params).asyncMap((rows) async {
      final categories = <NoteCategory>[];
      final knownNames = <String>{};

      for (final r in rows) {
        final name = (r['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty && !knownNames.contains(name.toLowerCase())) {
          knownNames.add(name.toLowerCase());
          categories.add(NoteCategory(
            id: r['id'] as String,
            name: name,
            icon: (r['icon'] as String?) ?? 'article',
            color: (r['color'] as String?) ?? '#0EA5E9',
          ));
        }
      }

      // Discover categories from notes table in real-time as well
      try {
        final noteQuery = uid.isNotEmpty
            ? "SELECT DISTINCT category FROM notes WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND category IS NOT NULL AND category != '' AND LOWER(category) != 'note' AND LOWER(category) != 'journal'"
            : "SELECT DISTINCT category FROM notes WHERE category IS NOT NULL AND category != '' AND LOWER(category) != 'note' AND LOWER(category) != 'journal'";
        final noteRows = await db.getAll(noteQuery, params);

        for (final nr in noteRows) {
          final catName = (nr['category'] as String?)?.trim() ?? '';
          if (catName.isNotEmpty && !knownNames.contains(catName.toLowerCase())) {
            knownNames.add(catName.toLowerCase());
            categories.add(
              NoteCategory(
                id: 'discovered_$catName',
                name: catName,
                icon: 'article',
                color: '#0EA5E9',
              ),
            );
          }
        }
      } catch (_) {}

      CacheService().set<List<NoteCategory>>(_cacheKey, categories, ttl: const Duration(minutes: 5));
      return categories;
    });
  }

  /// Retrieves note categories with cache-first strategy.
  Future<List<NoteCategory>> getCategories({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_cacheKey);
    }

    return CacheService().getOrFetch<List<NoteCategory>>(
      _cacheKey,
      _fetchCategoriesFromDb,
      ttl: const Duration(minutes: 2),
      staleWhileRevalidate: !forceRefresh,
      timeout: const Duration(seconds: 3),
      fallback: <NoteCategory>[],
    );
  }

  Future<List<NoteCategory>> _fetchCategoriesFromDb() async {
    if (!isDatabaseInitialized) return [];

    try {
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? "SELECT id, name, icon, color FROM note_categories WHERE (user_id = ? OR user_id IS NULL OR user_id = '') ORDER BY sort_order ASC, name ASC"
          : "SELECT id, name, icon, color FROM note_categories ORDER BY sort_order ASC, name ASC";
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rows = await db.getAll(query, params);
      final categories = <NoteCategory>[];
      final knownNames = <String>{};

      for (final r in rows) {
        final name = (r['name'] as String?)?.trim() ?? '';
        if (name.isNotEmpty && !knownNames.contains(name.toLowerCase())) {
          knownNames.add(name.toLowerCase());
          categories.add(NoteCategory(
            id: r['id'] as String,
            name: name,
            icon: (r['icon'] as String?) ?? 'article',
            color: (r['color'] as String?) ?? '#0EA5E9',
          ));
        }
      }

      // Discover categories from notes table as well
      final noteQuery = uid.isNotEmpty
          ? "SELECT DISTINCT category FROM notes WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND category IS NOT NULL AND category != '' AND LOWER(category) != 'note' AND LOWER(category) != 'journal'"
          : "SELECT DISTINCT category FROM notes WHERE category IS NOT NULL AND category != '' AND LOWER(category) != 'note' AND LOWER(category) != 'journal'";
      final noteRows = await db.getAll(noteQuery, params);

      for (final nr in noteRows) {
        final catName = (nr['category'] as String?)?.trim() ?? '';
        if (catName.isNotEmpty && !knownNames.contains(catName.toLowerCase())) {
          knownNames.add(catName.toLowerCase());
          categories.add(
            NoteCategory(
              id: 'discovered_$catName',
              name: catName,
              icon: 'article',
              color: '#0EA5E9',
            ),
          );
        }
      }

      // If connected to Supabase and authenticated, pull any remotely saved note_categories
      // to guarantee instant multi-device sync
      if (Supabase.instance.client.auth.currentSession != null && uid.isNotEmpty) {
        try {
          final supaRows = await Supabase.instance.client
              .from('note_categories')
              .select('id, name, icon, color, sort_order')
              .eq('user_id', uid)
              .order('sort_order', ascending: true);
          for (final sr in supaRows) {
            final name = (sr['name'] as String?)?.trim() ?? '';
            if (name.isNotEmpty && !knownNames.contains(name.toLowerCase())) {
              knownNames.add(name.toLowerCase());
              final cat = NoteCategory(
                id: sr['id'] as String,
                name: name,
                icon: (sr['icon'] as String?) ?? 'article',
                color: (sr['color'] as String?) ?? '#0EA5E9',
              );
              categories.add(cat);
              try {
                final nowUtc = DateTime.now().toUtc().toIso8601String();
                await db.execute(
                  'INSERT OR REPLACE INTO note_categories (id, user_id, name, icon, color, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
                  [cat.id, uid, cat.name, cat.icon, cat.color, sr['sort_order'] ?? 0, nowUtc, nowUtc],
                );
              } catch (_) {}
            }
          }
        } catch (e) {
          debugPrint('[NoteCategoryRepository] Remote Supabase categories fetch notice: $e');
        }
      }

      return categories;
    } catch (e) {
      debugPrint('[NoteCategoryRepository] Error fetching categories: $e');
      return [];
    }
  }

  /// Adds a new note category, writes to local persistent table, syncs with PowerSync and Supabase.
  Future<void> addCategory({
    required String name,
    String icon = 'article',
    String color = '#0EA5E9',
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;

    final uid = currentUserId;
    final id = IdGenerator.generateDeterministicId(
        'notecat_${uid.isNotEmpty ? uid : "local"}_${cleanName.toLowerCase()}');
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      final existing = await db.getOptional(
        'SELECT id FROM note_categories WHERE id = ? OR (LOWER(name) = LOWER(?) AND (user_id = ? OR user_id IS NULL OR user_id = \'\'))',
        [id, cleanName, uid],
      );
      if (existing != null) {
        await db.execute(
          'UPDATE note_categories SET name = ?, icon = ?, color = ?, updated_at = ? WHERE id = ?',
          [cleanName, icon, color, nowUtc, existing['id']],
        );
      } else {
        await db.execute(
          'INSERT INTO note_categories (id, user_id, name, icon, color, sort_order, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [id, uid, cleanName, icon, color, 99, nowUtc, nowUtc],
        );
      }

      categoryAddedNotifier.value = cleanName;
    } catch (e) {
      debugPrint('[NoteCategoryRepository] Error adding category: $e');
    }
  }

  /// Deletes a note category and resets notes in this category to 'note' (General) so no notes are lost.
  Future<void> deleteCategory(String id, {String? name}) async {
    CacheService().invalidate(_cacheKey);

    if (!isDatabaseInitialized) return;

    try {
      final uid = currentUserId;
      final rawId = id.replaceFirst('discovered_', '');
      String catName = (name ?? '').trim();
      if (catName.isEmpty) {
        final existing = await db.getOptional('SELECT name FROM note_categories WHERE id = ? OR id = ?', [id, rawId]);
        catName = (existing?['name'] as String? ?? '').trim();
      }

      // 1. Delete from note_categories (PowerSync records and syncs automatically)
      final deleteQuery = catName.isNotEmpty
          ? (uid.isNotEmpty
              ? "DELETE FROM note_categories WHERE (id = ? OR id = ? OR LOWER(name) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : 'DELETE FROM note_categories WHERE id = ? OR id = ? OR LOWER(name) = LOWER(?)')
          : (uid.isNotEmpty
              ? "DELETE FROM note_categories WHERE (id = ? OR id = ?) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : 'DELETE FROM note_categories WHERE id = ? OR id = ?');
      final deleteParams = catName.isNotEmpty
          ? (uid.isNotEmpty ? [id, rawId, catName, uid] : [id, rawId, catName])
          : (uid.isNotEmpty ? [id, rawId, uid] : [id, rawId]);
      await db.execute(deleteQuery, deleteParams);

      // 2. Disassociate notes (set category to 'note' so they remain safe in General Notes)
      final updateQuery = catName.isNotEmpty
          ? (uid.isNotEmpty
              ? "UPDATE notes SET category = 'note' WHERE (LOWER(COALESCE(category, '')) = LOWER(?) OR LOWER(COALESCE(category, '')) = LOWER(?) OR LOWER(COALESCE(category, '')) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : "UPDATE notes SET category = 'note' WHERE LOWER(COALESCE(category, '')) = LOWER(?) OR LOWER(COALESCE(category, '')) = LOWER(?) OR LOWER(COALESCE(category, '')) = LOWER(?)")
          : (uid.isNotEmpty
              ? "UPDATE notes SET category = 'note' WHERE (LOWER(COALESCE(category, '')) = LOWER(?) OR LOWER(COALESCE(category, '')) = LOWER(?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
              : "UPDATE notes SET category = 'note' WHERE LOWER(COALESCE(category, '')) = LOWER(?) OR LOWER(COALESCE(category, '')) = LOWER(?)");
      final updateParams = catName.isNotEmpty
          ? (uid.isNotEmpty ? [catName, id, rawId, uid] : [catName, id, rawId])
          : (uid.isNotEmpty ? [id, rawId, uid] : [id, rawId]);
      await db.execute(updateQuery, updateParams);
    } catch (e) {
      debugPrint('[NoteCategoryRepository] Error deleting category: $e');
    }
  }
}
