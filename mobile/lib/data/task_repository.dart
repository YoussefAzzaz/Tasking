import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/id_generator.dart';


class Task {
  final String id;
  final String? userId;
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
    this.userId,
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

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    String? notes,
    String? status,
    int? priority,
    String? projectId,
    String? tags,
    String? dueDate,
    String? dueTime,
    int? estimateMin,
    String? recurrenceRule,
    String? recurrenceMode,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      projectId: projectId ?? this.projectId,
      tags: tags ?? this.tags,
      dueDate: dueDate ?? this.dueDate,
      dueTime: dueTime ?? this.dueTime,
      estimateMin: estimateMin ?? this.estimateMin,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      recurrenceMode: recurrenceMode ?? this.recurrenceMode,
    );
  }

  factory Task.fromRow(Map<String, dynamic> row) {
    return Task(
      id: row['id'],
      userId: row['user_id'],
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
      'user_id': userId ?? currentUserId,
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
    final uid = currentUserId;
    final query = uid.isNotEmpty
        ? 'SELECT * FROM tasks WHERE user_id = ? ORDER BY created_at DESC'
        : 'SELECT * FROM tasks ORDER BY created_at DESC';
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db.watch(query, parameters: params).map((rows) {
      return rows.map((row) => Task.fromRow(row)).toList();
    });
  }

  Future<void> addTask(Task task) async {
    final uid = task.userId ?? currentUserId;
    try {
      await db.execute('''
        INSERT INTO tasks (
          id, user_id, title, notes, status, priority, project_id, tags, due_date, due_time, estimate_min, recurrence_rule, recurrence_mode, created_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
      ''', [
        task.id,
        uid,
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

      if (task.tags != null && task.tags!.isNotEmpty) {
        CacheService().invalidate('task_tags_list');
      }
    } catch (e) {
      debugPrint('[TaskRepository] Error creating task: $e');
    }

    AppWidgetSyncService().syncTodayTasks();
  }

  Future<void> updateTask(Task task) async {
    final uid = task.userId ?? currentUserId;
    try {
      final current = await db.getOptional('SELECT status FROM tasks WHERE id = ?', [task.id]);
      final oldStatus = current?['status'] as String?;

      await db.execute('''
        UPDATE tasks SET
          user_id = COALESCE(NULLIF(user_id, ''), ?),
          title = ?, notes = ?, status = ?, priority = ?, project_id = ?, tags = ?, due_date = ?, due_time = ?, estimate_min = ?, recurrence_rule = ?, recurrence_mode = ?, updated_at = ?
        WHERE id = ?
      ''', [
        uid,
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

      final now = DateTime.now().toUtc().toIso8601String();
      if (task.status == 'done' && oldStatus != 'done') {
        final xp = task.priority == 1 ? 75 : (task.priority == 2 ? 50 : 25);
        final logId = IdGenerator.generateDeterministicId('xp_task_${task.id}_$now');
        await db.execute('''
          INSERT INTO logs (id, user_id, task_id, event_type, xp_earned, timestamp)
          VALUES (?, ?, ?, 'task_completed', ?, ?)
        ''', [logId, uid, task.id, xp, now]);
      } else if (task.status != 'done' && oldStatus == 'done') {
        final deleteQuery = uid.isNotEmpty
            ? "DELETE FROM logs WHERE task_id = ? AND event_type = 'task_completed' AND (user_id = ? OR user_id IS NULL OR user_id = '')"
            : "DELETE FROM logs WHERE task_id = ? AND event_type = 'task_completed'";
        final deleteParams = uid.isNotEmpty ? [task.id, uid] : [task.id];
        await db.execute(deleteQuery, deleteParams);
      }

      if (task.tags != null && task.tags!.isNotEmpty) {
        CacheService().invalidate('task_tags_list');
      }
    } catch (e) {
      debugPrint('[TaskRepository] Error updating task: $e');
    }

    StatsRepository().invalidateStats();
    await syncGlobalUserLevel();
    AppWidgetSyncService().syncTodayTasks();
  }

  Future<void> deleteTask(String id) async {
    final uid = currentUserId;
    try {
      final deleteLogQuery = uid.isNotEmpty
          ? "DELETE FROM logs WHERE task_id = ? AND (user_id = ? OR user_id IS NULL OR user_id = '')"
          : 'DELETE FROM logs WHERE task_id = ?';
      final deleteLogParams = uid.isNotEmpty ? [id, uid] : [id];
      await db.execute(deleteLogQuery, deleteLogParams);

      await db.execute('DELETE FROM tasks WHERE id = ?', [id]);
    } catch (e) {
      debugPrint('[TaskRepository] Error deleting task: $e');
    }
    StatsRepository().invalidateStats();
    await syncGlobalUserLevel();
    AppWidgetSyncService().syncTodayTasks();
  }

  /// Toggles task completion status, records XP gamification event, and invalidates stats.
  Future<void> toggleTaskStatus(Task task, bool isDone) async {
    final updated = task.copyWith(
      status: isDone ? 'done' : 'todo',
    );

    await updateTask(updated);
  }

  /// Unlinks all tasks matching the specified project identifier in a single batch operation.
  Future<void> unlinkTasksFromProject(String projectId, {String? projectName}) async {
    final name = projectName ?? '';
    final uid = currentUserId;
    try {
      final query = uid.isNotEmpty
          ? '''
            UPDATE tasks 
            SET project_id = NULL 
            WHERE (project_id = ? 
               OR project_id = ? 
               OR LOWER(COALESCE(project_id, '')) = LOWER(?) 
               OR LOWER(COALESCE(project_id, '')) = LOWER(?))
              AND (user_id = ? OR user_id IS NULL OR user_id = '')
          '''
          : '''
            UPDATE tasks 
            SET project_id = NULL 
            WHERE project_id = ? 
               OR project_id = ? 
               OR LOWER(COALESCE(project_id, '')) = LOWER(?) 
               OR LOWER(COALESCE(project_id, '')) = LOWER(?)
          ''';
      final params = uid.isNotEmpty
          ? [projectId, projectId.replaceFirst('discovered_', ''), projectId, name, uid]
          : [projectId, projectId.replaceFirst('discovered_', ''), projectId, name];

      await db.execute(query, params).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[TaskRepository] Error detaching project from tasks: $e');
    }
    AppWidgetSyncService().syncTodayTasks();
  }
}
