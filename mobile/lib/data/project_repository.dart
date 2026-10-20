import 'dart:async';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/task_repository.dart';

class Project {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    this.color = '#6366F1',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Project.fromRow(Map<String, dynamic> row) {
    return Project(
      id: row['id'] as String,
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
      'name': name,
      'color': color,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

class ProjectRepository {
  static const String _cacheKey = 'projects_list';

  Stream<List<Project>> watchProjects() {
    return db.watch('SELECT * FROM projects ORDER BY created_at ASC').map((rows) {
      final list = rows.map((r) => Project.fromRow(r)).toList();
      CacheService().set<List<Project>>(_cacheKey, list, ttl: const Duration(minutes: 5));
      return list;
    });
  }

  Future<List<Project>> getProjects({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_cacheKey);
    }

    return CacheService().getOrFetch<List<Project>>(
      _cacheKey,
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
      final rows = await db.getAll('SELECT * FROM projects ORDER BY created_at ASC');
      return rows.map((r) => Project.fromRow(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addProject(Project project) async {
    CacheService().invalidate(_cacheKey);
    if (!isDatabaseInitialized) return;

    try {
      await db.execute('''
        INSERT INTO projects (id, name, color, created_at)
        VALUES (?, ?, ?, ?)
      ''', [
        project.id,
        project.name,
        project.color,
        project.createdAt.toUtc().toIso8601String(),
      ]).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  /// Deletes a project, unlinks any associated tasks, and cleans the cache without N+1 queries.
  Future<void> deleteProject(String id, {String? projectName}) async {
    CacheService().invalidate(_cacheKey);
    if (!isDatabaseInitialized) return;

    final rawId = id.replaceFirst('discovered_', '');
    final name = projectName ?? '';

    // First unlink tasks cleanly
    await TaskRepository().unlinkTasksFromProject(id, projectName: projectName);

    try {
      await db.execute('''
        DELETE FROM projects 
        WHERE id = ? 
           OR id = ?
           OR LOWER(name) = LOWER(?)
      ''', [id, rawId, name]).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
