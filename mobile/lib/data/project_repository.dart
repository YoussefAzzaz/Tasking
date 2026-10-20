import 'package:axis/data/powersync_db.dart';

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
  Stream<List<Project>> watchProjects() {
    return db.watch('SELECT * FROM projects ORDER BY created_at ASC').map((rows) {
      return rows.map((r) => Project.fromRow(r)).toList();
    });
  }

  Future<List<Project>> getProjects() async {
    final rows = await db.getAll('SELECT * FROM projects ORDER BY created_at ASC');
    return rows.map((r) => Project.fromRow(r)).toList();
  }

  Future<void> addProject(Project project) async {
    await db.execute('''
      INSERT INTO projects (id, name, color, created_at)
      VALUES (?, ?, ?, ?)
    ''', [
      project.id,
      project.name,
      project.color,
      project.createdAt.toUtc().toIso8601String(),
    ]);
  }

  Future<void> deleteProject(String id) async {
    await db.execute('DELETE FROM projects WHERE id = ?', [id]);
  }
}
