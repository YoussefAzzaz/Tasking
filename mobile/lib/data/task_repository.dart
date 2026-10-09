import 'package:axis/data/powersync_db.dart';


class Task {
  final String id;
  final String title;
  final String status;
  final int? priority;
  final String? projectId;
  final String? tags;
  final String? dueDate;
  final String? dueTime;
  final int? estimateMin;
  final String? recurrenceRule;
  final String? recurrenceMode;

  Task({
    required this.id,
    required this.title,
    this.status = 'todo',
    this.priority,
    this.projectId,
    this.tags,
    this.dueDate,
    this.dueTime,
    this.estimateMin,
    this.recurrenceRule,
    this.recurrenceMode,
  });

  factory Task.fromRow(Map<String, dynamic> row) {
    return Task(
      id: row['id'],
      title: row['title'],
      status: row['status'] ?? 'todo',
      priority: row['priority'],
      projectId: row['project_id'],
      tags: row['tags'],
      dueDate: row['due_date'],
      dueTime: row['due_time'],
      estimateMin: row['estimate_min'],
      recurrenceRule: row['recurrence_rule'],
      recurrenceMode: row['recurrence_mode'],
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'priority': priority,
      'project_id': projectId,
      'tags': tags,
      'due_date': dueDate,
      'due_time': dueTime,
      'estimate_min': estimateMin,
      'recurrence_rule': recurrenceRule,
      'recurrence_mode': recurrenceMode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}

class TaskRepository {
  Stream<List<Task>> watchTasks() {
    return db.watch('SELECT * FROM tasks ORDER BY created_at DESC').map((rows) {
      return rows.map((row) => Task.fromRow(row)).toList();
    });
  }

  Future<void> addTask(Task task) async {
    await db.execute('''
      INSERT INTO tasks (
        id, title, status, priority, project_id, tags, due_date, due_time, estimate_min, recurrence_rule, recurrence_mode, created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    ''', [
      task.id,
      task.title,
      task.status,
      task.priority,
      task.projectId,
      task.tags,
      task.dueDate,
      task.dueTime,
      task.estimateMin,
      task.recurrenceRule,
      task.recurrenceMode,
      DateTime.now().toUtc().toIso8601String(),
      DateTime.now().toUtc().toIso8601String(),
    ]);
  }

  Future<void> updateTask(Task task) async {
    await db.execute('''
      UPDATE tasks SET
        title = ?, status = ?, priority = ?, project_id = ?, tags = ?, due_date = ?, due_time = ?, estimate_min = ?, recurrence_rule = ?, recurrence_mode = ?, updated_at = ?
      WHERE id = ?
    ''', [
      task.title,
      task.status,
      task.priority,
      task.projectId,
      task.tags,
      task.dueDate,
      task.dueTime,
      task.estimateMin,
      task.recurrenceRule,
      task.recurrenceMode,
      DateTime.now().toUtc().toIso8601String(),
      task.id,
    ]);
  }

  Future<void> deleteTask(String id) async {
    await db.execute('DELETE FROM tasks WHERE id = ?', [id]);
  }
}
