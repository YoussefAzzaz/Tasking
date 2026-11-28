import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/id_generator.dart';

class Project {
  final String id;
  final String? userId;
  final String name;
  final String color;
  final DateTime createdAt;

  Project({
    required this.id,
    this.userId,
    required this.name,
    this.color = '#6366F1',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Project.fromRow(Map<String, dynamic> row) {
    return Project(
      id: row['id'] as String,
      userId: row['user_id'] as String?,
      name: row['name'] as String,
      color: (row['color'] as String?) ?? '#6366F1',
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'user_id': userId ?? currentUserId,
      'name': name,
      'color': color,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class ProjectRepository {
  static const String _cacheKey = 'projects_list';

  static String deterministicId(String uid, String name) =>
      IdGenerator.generateDeterministicId(
          'proj_${uid.isNotEmpty ? uid : "local"}_${name.trim().toLowerCase()}');

  /// Builds a deterministic Project model for unlinked task project names without
  /// fabricating synthetic `discovered_` prefixes.
  static Project reconciledProject(String name, {String color = '#0EA5E9'}) {
    final clean = name.trim();
    return Project(
      id: deterministicId(currentUserId, clean),
      name: clean,
      color: color,
    );
  }

  String get _scopedCacheKey {
    final uid = currentUserId;
    return uid.isEmpty ? _cacheKey : '${_cacheKey}_$uid';
  }

  Stream<List<Project>> watchProjects() {
    if (!isDatabaseInitialized) {
      return Stream.value(const <Project>[]);
    }
    final uid = currentUserId;
    // Root-cause fix: filter out soft-deleted projects and namespace caches by
    // account UID so deleted or foreign projects never flash after switching accounts.
    final query = uid.isNotEmpty
        ? "SELECT * FROM projects WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '') ORDER BY created_at ASC"
        : "SELECT * FROM projects WHERE (deleted_at IS NULL OR deleted_at = '') ORDER BY created_at ASC";
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db.watch(query, parameters: params).map((rows) {
      final list = rows.map((r) => Project.fromRow(r)).toList();
      CacheService().set<List<Project>>(_scopedCacheKey, list, ttl: const Duration(minutes: 5));
      return list;
    });
  }

  Future<List<Project>> getProjects({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_scopedCacheKey);
    }

    return CacheService().getOrFetch<List<Project>>(
      _scopedCacheKey,
      _fetchProjectsFromDb,
      ttl: const Duration(minutes: 5),
      staleWhileRevalidate: true,
      timeout: const Duration(seconds: 3),
      fallback: <Project>[],
    );
  }

  Future<List<Project>> _fetchProjectsFromDb() async {
    if (!isDatabaseInitialized) return [];
    try {
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? "SELECT * FROM projects WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '') ORDER BY created_at ASC"
          : "SELECT * FROM projects WHERE (deleted_at IS NULL OR deleted_at = '') ORDER BY created_at ASC";
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];

      final rows = await db.getAll(query, params);
      return rows.map((r) => Project.fromRow(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addProject(Project project) async {
    CacheService().invalidate(_scopedCacheKey);
    if (!isDatabaseInitialized) return;

    final uid = project.userId ?? currentUserId;
    try {
      await db.execute('''
        INSERT INTO projects (id, user_id, name, color, created_at)
        VALUES (?, ?, ?, ?, ?)
      ''', [
        project.id,
        uid,
        project.name,
        project.color,
        project.createdAt.toUtc().toIso8601String(),
      ]).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[ProjectRepository] Error adding project: $e');
    }
  }

  /// Deletes a project, unlinks any associated tasks, and cleans the cache without N+1 queries.
  Future<void> deleteProject(String id, {String? projectName}) async {
    CacheService().invalidate(_scopedCacheKey);
    if (!isDatabaseInitialized) return;

    // Root cause: retired synthetic 'discovered_' prefixes in favor of deterministic project IDs.
    final name = projectName ?? '';
    final uid = currentUserId;
    final detId = name.trim().isNotEmpty ? deterministicId(uid, name) : id;

    // First unlink tasks cleanly
    await TaskRepository().unlinkTasksFromProject(id, projectName: projectName);

    try {
      final query = uid.isNotEmpty
          ? '''
            DELETE FROM projects 
            WHERE (id = ? 
               OR id = ?
               OR LOWER(name) = LOWER(?))
              AND (user_id = ? OR user_id IS NULL OR user_id = '')
          '''
          : '''
            DELETE FROM projects 
            WHERE id = ? 
               OR id = ?
               OR LOWER(name) = LOWER(?)
          ''';
      final params = uid.isNotEmpty ? [id, detId, name, uid] : [id, detId, name];

      await db.execute(query, params).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[ProjectRepository] Error deleting project: $e');
    }
  }
}
