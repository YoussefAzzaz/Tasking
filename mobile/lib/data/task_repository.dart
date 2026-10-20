import 'package:axis/data/powersync_db.dart';


class Task {
  final String id;
  final String title;
  final String? notes;
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
    this.notes,
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
      notes: row['notes'],
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
      'notes': notes,
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

/// Sort comparator: Earliest due date first, then priority, then alphabetical.
int compareTasksByDueDate(Task a, Task b) {
  // 1. Incomplete tasks before completed tasks
  final aDone = a.status == 'done';
  final bDone = b.status == 'done';
  if (aDone != bDone) {
    return aDone ? 1 : -1;
  }

  // 2. Earliest due date first (tasks with dates appear before tasks without)
  final aDue = a.dueDate;
  final bDue = b.dueDate;
  final aHasDue = aDue != null && aDue.trim().isNotEmpty;
  final bHasDue = bDue != null && bDue.trim().isNotEmpty;

  if (aHasDue && !bHasDue) return -1;
  if (!aHasDue && bHasDue) return 1;

  if (aHasDue && bHasDue) {
    final cmpDate = aDue.compareTo(bDue);
    if (cmpDate != 0) return cmpDate;

    // 3. Same date: earlier due time first
    final aTime = a.dueTime ?? '';
    final bTime = b.dueTime ?? '';
    if (aTime.isNotEmpty && bTime.isNotEmpty) {
      final cmpTime = aTime.compareTo(bTime);
      if (cmpTime != 0) return cmpTime;
    } else if (aTime.isNotEmpty) {
      return -1;
    } else if (bTime.isNotEmpty) {
      return 1;
    }
  }

  // 4. Secondary sort by priority: P1 (1) < P2 (2) < P3 (3)
  final aPri = a.priority ?? 99;
  final bPri = b.priority ?? 99;
  if (aPri != bPri) {
    return aPri.compareTo(bPri);
  }

  // 5. Tertiary sort alphabetically by title
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
}

/// Sort comparator: Priority first (P1 < P2 < P3), then due time, then alphabetical.
int compareTasksByPriority(Task a, Task b) {
  // 1. Incomplete tasks before completed tasks
  final aDone = a.status == 'done';
  final bDone = b.status == 'done';
  if (aDone != bDone) {
    return aDone ? 1 : -1;
  }

  // 2. Priority: P1 (1) < P2 (2) < P3 (3)
  final aPri = a.priority ?? 99;
  final bPri = b.priority ?? 99;
  if (aPri != bPri) {
    return aPri.compareTo(bPri);
  }

  // 3. Earlier due time first
  final aTime = a.dueTime ?? '';
  final bTime = b.dueTime ?? '';
  if (aTime.isNotEmpty && bTime.isNotEmpty) {
    final cmpTime = aTime.compareTo(bTime);
    if (cmpTime != 0) return cmpTime;
  } else if (aTime.isNotEmpty) {
    return -1;
  } else if (bTime.isNotEmpty) {
    return 1;
  }

  // 4. Alphabetical by title
  return a.title.toLowerCase().compareTo(b.title.toLowerCase());
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
        id, title, notes, status, priority, project_id, tags, due_date, due_time, estimate_min, recurrence_rule, recurrence_mode, created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    ''', [
      task.id,
      task.title,
      task.notes,
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
        title = ?, notes = ?, status = ?, priority = ?, project_id = ?, tags = ?, due_date = ?, due_time = ?, estimate_min = ?, recurrence_rule = ?, recurrence_mode = ?, updated_at = ?
      WHERE id = ?
    ''', [
      task.title,
      task.notes,
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
