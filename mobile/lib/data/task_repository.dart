import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/sharing/companion_share_repository.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/domain/domain_events.dart';
import 'package:axis/domain/auto_scheduler.dart';

export 'package:axis/domain/auto_scheduler.dart';


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
  final bool isCollaborative;
  final String? shareId;
  final String? senderId;
  final String? senderUsername;
  final String? recipientUsername;

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
    this.isCollaborative = false,
    this.shareId,
    this.senderId,
    this.senderUsername,
    this.recipientUsername,
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
    bool? isCollaborative,
    String? shareId,
    String? senderId,
    String? senderUsername,
    String? recipientUsername,
    bool clearDueDate = false,
    bool clearDueTime = false,
    bool clearNotes = false,
    bool clearProjectId = false,
    bool clearTags = false,
    bool clearEstimateMin = false,
    bool clearRecurrenceRule = false,
    bool clearRecurrenceMode = false,
    bool clearPriority = false,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: clearNotes ? null : (notes ?? this.notes),
      status: status ?? this.status,
      priority: clearPriority ? null : (priority ?? this.priority),
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      tags: clearTags ? null : (tags ?? this.tags),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      dueTime: clearDueTime ? null : (dueTime ?? this.dueTime),
      estimateMin: clearEstimateMin ? null : (estimateMin ?? this.estimateMin),
      recurrenceRule: clearRecurrenceRule ? null : (recurrenceRule ?? this.recurrenceRule),
      recurrenceMode: clearRecurrenceMode ? null : (recurrenceMode ?? this.recurrenceMode),
      isCollaborative: isCollaborative ?? this.isCollaborative,
      shareId: shareId ?? this.shareId,
      senderId: senderId ?? this.senderId,
      senderUsername: senderUsername ?? this.senderUsername,
      recipientUsername: recipientUsername ?? this.recipientUsername,
    );
  }

  static String? _cleanUsername(dynamic raw) {
    final val = raw?.toString().trim() ?? '';
    if (val.isEmpty) return null;
    final cleaned = val.replaceFirst(RegExp(r'^@+'), '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  factory Task.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> preview = const {};
    final rawPreview = row['share_preview_data'];
    if (rawPreview is Map) {
      preview = Map<String, dynamic>.from(rawPreview);
    } else if (rawPreview is String && rawPreview.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPreview);
        if (decoded is Map) {
          preview = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    final shareIdRaw = row['share_id']?.toString().trim();
    final shareMode = row['share_mode']?.toString().trim();
    final shareStatus = row['share_status']?.toString().trim();
    final isCollab = shareMode == 'collaborate' &&
        (shareStatus == 'accepted' || shareStatus == 'pending');

    final previewSender = _cleanUsername(preview['sender_name']);
    final rowSender = _cleanUsername(row['sender_username']);
    final resolvedSender = (rowSender != null && rowSender != 'Companion')
        ? rowSender
        : (previewSender ?? rowSender);
    final resolvedRecipient = _cleanUsername(row['recipient_username']);

    final localUpdated =
        DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toUtc();
    final previewUpdated =
        DateTime.tryParse(preview['task_updated_at']?.toString() ?? '')?.toUtc();
    final useNewerPreview = isCollab &&
        preview.isNotEmpty &&
        previewUpdated != null &&
        (localUpdated == null || previewUpdated.isAfter(localUpdated));

    final effectiveTitle = useNewerPreview &&
            preview['title']?.toString().trim().isNotEmpty == true
        ? preview['title'].toString()
        : (row['title']?.toString() ?? '');
    final effectiveNotes = useNewerPreview && preview.containsKey('notes')
        ? preview['notes']?.toString()
        : row['notes']?.toString();
    final effectiveStatus = useNewerPreview && preview['status'] != null
        ? preview['status'].toString()
        : (row['status']?.toString() ?? 'todo');
    final effectivePriority = useNewerPreview && preview['priority'] is num
        ? (preview['priority'] as num).toInt()
        : (row['priority'] is num
            ? (row['priority'] as num).toInt()
            : row['priority'] as int?);
    final effectiveTags = useNewerPreview && preview.containsKey('tags')
        ? preview['tags']?.toString()
        : row['tags']?.toString();
    final effectiveDueDate = useNewerPreview && preview.containsKey('due_date')
        ? preview['due_date']?.toString()
        : row['due_date']?.toString();
    final effectiveDueTime = useNewerPreview && preview.containsKey('due_time')
        ? preview['due_time']?.toString()
        : row['due_time']?.toString();
    final effectiveEstimateMin =
        useNewerPreview && preview.containsKey('estimate_min')
            ? (preview['estimate_min'] is num
                ? (preview['estimate_min'] as num).toInt()
                : null)
            : (row['estimate_min'] is num
                ? (row['estimate_min'] as num).toInt()
                : row['estimate_min'] as int?);
    final effectiveRecurrenceRule =
        useNewerPreview && preview.containsKey('recurrence_rule')
            ? preview['recurrence_rule']?.toString()
            : row['recurrence_rule']?.toString();
    final effectiveRecurrenceMode =
        useNewerPreview && preview.containsKey('recurrence_mode')
            ? preview['recurrence_mode']?.toString()
            : row['recurrence_mode']?.toString();

    return Task(
      id: row['id'],
      userId: row['user_id'],
      title: effectiveTitle,
      notes: effectiveNotes,
      status: effectiveStatus,
      priority: effectivePriority,
      projectId: row['project_id'],
      tags: effectiveTags,
      dueDate: effectiveDueDate,
      dueTime: effectiveDueTime,
      estimateMin: effectiveEstimateMin,
      recurrenceRule: effectiveRecurrenceRule,
      recurrenceMode: effectiveRecurrenceMode,
      isCollaborative: isCollab,
      shareId: (shareIdRaw != null && shareIdRaw.isNotEmpty) ? shareIdRaw : null,
      senderId: row['share_sender_id']?.toString(),
      senderUsername: resolvedSender,
      recipientUsername: resolvedRecipient,
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

  bool get isCompleted => status == 'done' || status == 'completed';
  bool get isSharedTask =>
      isCollaborative ||
      (senderUsername != null && senderUsername!.trim().isNotEmpty);
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
  static String? mergeSenderTag(String? tags, String? senderUsername) {
    final cleanSender =
        (senderUsername ?? '').trim().replaceFirst(RegExp(r'^@+'), '').trim();
    final parts = (tags ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleanSender.isNotEmpty &&
        !parts.any((t) =>
            t.replaceFirst(RegExp(r'^@+'), '').toLowerCase() ==
            cleanSender.toLowerCase())) {
      parts.add(cleanSender);
    }
    if (parts.isEmpty) return null;
    return parts.join(',');
  }

  /// Removes [senderUsername] (with or without leading '@', case-insensitive)
  /// from a comma-separated tag list.
  static String? removeSenderTag(String? tags, String? senderUsername) {
    final cleanSender =
        (senderUsername ?? '').trim().replaceFirst(RegExp(r'^@+'), '').trim();
    final parts = (tags ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) =>
            e.isNotEmpty &&
            (cleanSender.isEmpty ||
                e.replaceFirst(RegExp(r'^@+'), '').toLowerCase() !=
                    cleanSender.toLowerCase()))
        .toList();
    if (parts.isEmpty) return null;
    return parts.join(',');
  }

  static int _taskRichnessScore(Task task) {
    var score = 0;
    if (task.isCollaborative) score += 4;
    if (task.senderUsername != null &&
        task.senderUsername!.trim().isNotEmpty) {
      score += 2;
    }
    if (task.shareId != null && task.shareId!.trim().isNotEmpty) score += 1;
    return score;
  }

  /// Deduplicates tasks by id, non-empty shareId, and normalized task fields,
  /// preferring collaborative / sender-tagged entries when upgrading duplicates.
  static List<Task> deduplicateTasks(List<Task> tasks) {
    if (tasks.length <= 1) return tasks;

    final result = <Task>[];
    final seenIds = <String, int>{};
    final seenShareIds = <String, int>{};
    final seenSignatures = <String, int>{};

    for (final task in tasks) {
      final shareId = task.shareId?.trim() ?? '';
      final normalizedTitle = task.title.trim().toLowerCase();
      final signature =
          '${task.userId ?? ''}|$normalizedTitle|${task.dueDate ?? ''}|${task.status}';

      int? existingIdx = seenIds[task.id];
      if (existingIdx == null && shareId.isNotEmpty) {
        existingIdx = seenShareIds[shareId];
      }
      if (existingIdx == null && normalizedTitle.isNotEmpty) {
        existingIdx = seenSignatures[signature];
      }

      if (existingIdx == null) {
        final idx = result.length;
        result.add(task);
        seenIds[task.id] = idx;
        if (shareId.isNotEmpty) {
          seenShareIds[shareId] = idx;
        }
        if (normalizedTitle.isNotEmpty) {
          seenSignatures[signature] = idx;
        }
      } else {
        final existing = result[existingIdx];
        if (_taskRichnessScore(task) > _taskRichnessScore(existing)) {
          result[existingIdx] = task;
          seenIds[task.id] = existingIdx;
          if (shareId.isNotEmpty) {
            seenShareIds[shareId] = existingIdx;
          }
          if (normalizedTitle.isNotEmpty) {
            seenSignatures[signature] = existingIdx;
          }
        }
      }
    }

    return result;
  }

  static const String _joinedSelectPrefix = '''
    SELECT
      t.*,
      cs.id AS share_id,
      cs.share_mode AS share_mode,
      cs.status AS share_status,
      cs.sender_id AS share_sender_id,
      cs.recipient_id AS share_recipient_id,
      cs.preview_data AS share_preview_data,
      sp.name AS sender_username,
      rp.name AS recipient_username
    FROM tasks t
    LEFT JOIN companion_shares cs
      ON cs.id = (
        SELECT cs2.id
        FROM companion_shares cs2
        WHERE cs2.entity_type = 'task'
          AND (
            (
              cs2.share_mode = 'collaborate'
              AND cs2.status IN ('accepted', 'pending')
              AND (cs2.entity_id = t.id OR cs2.accepted_entity_id = t.id)
              AND NOT EXISTS (
                SELECT 1 FROM tasks t_del
                WHERE (t_del.id = cs2.entity_id OR t_del.id = cs2.accepted_entity_id)
                  AND t_del.deleted_at IS NOT NULL AND t_del.deleted_at != ''
              )
            )
            OR (
              cs2.share_mode = 'copy'
              AND cs2.status = 'accepted'
              AND cs2.accepted_entity_id = t.id
              AND cs2.sender_id != COALESCE(t.user_id, '')
            )
          )
        ORDER BY
          CASE WHEN cs2.share_mode = 'collaborate' THEN 0 ELSE 1 END,
          CASE WHEN cs2.status = 'accepted' THEN 0 ELSE 1 END,
          cs2.updated_at DESC
        LIMIT 1
      )
    LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
    LEFT JOIN user_profiles rp ON rp.user_id = cs.recipient_id
  ''';

  Future<bool> _hasShareJoinTables() async {
    if (!isDatabaseInitialized) return false;
    try {
      final rows = await db.getAll('''
        SELECT name FROM sqlite_master
        WHERE type IN ('table', 'view')
          AND name IN ('companion_shares', 'user_profiles')
      ''');
      return rows.length >= 2;
    } catch (_) {
      return false;
    }
  }

  Stream<List<Task>> watchTasks({int? limit, int? offset}) {
    if (!isDatabaseInitialized) {
      return Stream.value(const <Task>[]);
    }
    return _watchTasksInternal(limit: limit, offset: offset);
  }

  Stream<List<Task>> _watchTasksInternal({int? limit, int? offset}) async* {
    final uid = currentUserId;
    final hasJoin = await _hasShareJoinTables();
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];
    final limitClause = (limit != null && limit > 0)
        ? " LIMIT $limit${(offset != null && offset > 0) ? ' OFFSET $offset' : ''}"
        : '';

    if (hasJoin) {
      final whereClause = uid.isNotEmpty
          ? "WHERE t.user_id = ? AND (t.deleted_at IS NULL OR t.deleted_at = '')"
          : "WHERE (t.deleted_at IS NULL OR t.deleted_at = '')";
      final query =
          "$_joinedSelectPrefix $whereClause ORDER BY t.created_at DESC$limitClause";
      yield* db
          .watch(query, parameters: params)
          .map((rows) => deduplicateTasks(rows.map((row) => Task.fromRow(row)).toList()));
    } else {
      final whereClause = uid.isNotEmpty
          ? "WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '')"
          : "WHERE (deleted_at IS NULL OR deleted_at = '')";
      final query =
          "SELECT * FROM tasks $whereClause ORDER BY created_at DESC$limitClause";
      yield* db
          .watch(query, parameters: params)
          .map((rows) => deduplicateTasks(rows.map((row) => Task.fromRow(row)).toList()));
    }
  }

  /// Fetches tasks directly from SQLite with optional limit and offset pagination.
  Future<List<Task>> getTasks({int? limit, int? offset}) async {
    if (!isDatabaseInitialized) return const [];
    final uid = currentUserId;
    final hasJoin = await _hasShareJoinTables();
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];
    final limitClause = (limit != null && limit > 0)
        ? " LIMIT $limit${(offset != null && offset > 0) ? ' OFFSET $offset' : ''}"
        : '';

    if (hasJoin) {
      try {
        final whereClause = uid.isNotEmpty
            ? "WHERE t.user_id = ? AND (t.deleted_at IS NULL OR t.deleted_at = '')"
            : "WHERE (t.deleted_at IS NULL OR t.deleted_at = '')";
        final query =
            "$_joinedSelectPrefix $whereClause ORDER BY t.created_at DESC$limitClause";
        final rows = await db.getAll(query, params);
        return deduplicateTasks(rows.map((row) => Task.fromRow(row)).toList());
      } catch (e) {
        debugPrint('[TaskRepository] Joined getTasks fallback notice: $e');
      }
    }

    final whereClause = uid.isNotEmpty
        ? "WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '')"
        : "WHERE (deleted_at IS NULL OR deleted_at = '')";
    final query =
        "SELECT * FROM tasks $whereClause ORDER BY created_at DESC$limitClause";
    final rows = await db.getAll(query, params);
    return deduplicateTasks(rows.map((row) => Task.fromRow(row)).toList());
  }

  /// Fetches total count of active tasks for user.
  Future<int> getTasksCount() async {
    if (!isDatabaseInitialized) return 0;
    final uid = currentUserId;
    final query = uid.isNotEmpty
        ? "SELECT COUNT(*) as count FROM tasks WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '')"
        : "SELECT COUNT(*) as count FROM tasks WHERE (deleted_at IS NULL OR deleted_at = '')";
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];
    final row = await db.getOptional(query, params);
    return (row?['count'] as num?)?.toInt() ?? 0;
  }

  /// Fetches a single task by ID from SQLite if available.
  Future<Task?> getTaskById(String id) async {
    if (!isDatabaseInitialized) return null;
    try {
      if (await _hasShareJoinTables()) {
        final row = await db.getOptional(
          "$_joinedSelectPrefix WHERE t.id = ? AND (t.deleted_at IS NULL OR t.deleted_at = '') LIMIT 1",
          [id],
        );
        if (row == null) return null;
        return Task.fromRow(row);
      }
      final row = await db.getOptional(
        "SELECT * FROM tasks WHERE id = ? AND (deleted_at IS NULL OR deleted_at = '') LIMIT 1",
        [id],
      );
      if (row == null) return null;
      return Task.fromRow(row);
    } catch (e) {
      debugPrint('[TaskRepository] Error fetching task by id: $e');
      return null;
    }
  }

  Future<void> addTask(Task task) async {
    if (!isDatabaseInitialized) return;
    final uid = task.userId ?? currentUserId;
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.execute('''
        INSERT OR REPLACE INTO tasks (
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
        nowUtc,
        nowUtc,
      ]);

      if (task.tags != null && task.tags!.isNotEmpty) {
        CacheService().invalidate('task_tags_list');
      }
      DomainEvents.emit(TaskCreatedEvent(task.id));
      AppWidgetSyncService().syncTodayTasks();
    } catch (e) {
      debugPrint('[TaskRepository] Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(Task task) async {
    if (!isDatabaseInitialized) return;
    final uid = task.userId ?? currentUserId;
    try {
      final current = await db.getOptional('SELECT status FROM tasks WHERE id = ?', [task.id]);
      final oldStatus = current?['status'] as String?;

      var effectiveTask = task;
      Map<String, dynamic>? collabShareRow;
      if (await _hasShareJoinTables()) {
        try {
          collabShareRow = await db.getOptional('''
            SELECT cs.*, sp.name AS sender_username
            FROM companion_shares cs
            LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
            WHERE cs.entity_type = 'task'
              AND cs.share_mode = 'collaborate'
              AND cs.status IN ('accepted', 'pending')
              AND (cs.entity_id = ? OR cs.accepted_entity_id = ?)
            ORDER BY CASE WHEN cs.status = 'accepted' THEN 0 ELSE 1 END, cs.updated_at DESC
            LIMIT 1
          ''', [task.id, task.id]);
        } catch (_) {
          collabShareRow = null;
        }
      }

      if (collabShareRow != null) {
        Map<String, dynamic> existingPreview = {};
        final rawPreview = collabShareRow['preview_data'];
        if (rawPreview is String && rawPreview.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawPreview);
            if (decoded is Map) {
              existingPreview = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
        final rawSenderUsername = collabShareRow['sender_username']?.toString().trim();
        final senderName = (rawSenderUsername != null &&
                rawSenderUsername.isNotEmpty &&
                rawSenderUsername != 'Companion')
            ? rawSenderUsername
            : (existingPreview['sender_name']?.toString().trim() ?? task.senderUsername);
        final acceptedIdVal = collabShareRow['accepted_entity_id']?.toString() ?? '';
        final isRecipientTask = acceptedIdVal.isNotEmpty && task.id == acceptedIdVal;
        final senderCleanTags = removeSenderTag(task.tags, senderName);
        final recipientMergedTags = mergeSenderTag(senderCleanTags, senderName);
        effectiveTask = task.copyWith(
          tags: isRecipientTask ? recipientMergedTags : senderCleanTags,
          clearTags: !isRecipientTask && senderCleanTags == null,
          isCollaborative: true,
          shareId: task.shareId ?? collabShareRow['id']?.toString(),
          senderId: task.senderId ?? collabShareRow['sender_id']?.toString(),
          senderUsername: task.senderUsername ?? senderName,
        );
      }

      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.execute('''
        UPDATE tasks SET
          user_id = COALESCE(NULLIF(user_id, ''), ?),
          title = ?, notes = ?, status = ?, priority = ?, project_id = ?, tags = ?, due_date = ?, due_time = ?, estimate_min = ?, recurrence_rule = ?, recurrence_mode = ?, updated_at = ?
        WHERE id = ?
      ''', [
        uid,
        effectiveTask.title,
        effectiveTask.notes,
        effectiveTask.status,
        effectiveTask.priority,
        effectiveTask.projectId,
        effectiveTask.tags,
        effectiveTask.dueDate,
        effectiveTask.dueTime,
        effectiveTask.estimateMin,
        effectiveTask.recurrenceRule,
        effectiveTask.recurrenceMode,
        nowUtc,
        effectiveTask.id,
      ]);

      // Propagate collaborative task updates to companion_shares.preview_data + any local partner task + Supabase RPC
      if (collabShareRow != null) {
        Map<String, dynamic> updatedPreview = {};
        final rawPreview = collabShareRow['preview_data'];
        if (rawPreview is String && rawPreview.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawPreview);
            if (decoded is Map) {
              updatedPreview = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
        final senderIdVal = collabShareRow['sender_id']?.toString() ?? '';
        final entityIdVal = collabShareRow['entity_id']?.toString() ?? '';
        final acceptedIdVal = collabShareRow['accepted_entity_id']?.toString() ?? '';
        final partnerTaskId = (entityIdVal == effectiveTask.id) ? acceptedIdVal : entityIdVal;
        final partnerIsRecipient = partnerTaskId == acceptedIdVal;
        final senderNameVal = effectiveTask.senderUsername ??
            updatedPreview['sender_name']?.toString() ??
            'Companion';
        final cleanPreviewTags = removeSenderTag(effectiveTask.tags, senderNameVal);
        final partnerTags = partnerIsRecipient
            ? mergeSenderTag(cleanPreviewTags, senderNameVal)
            : cleanPreviewTags;

        updatedPreview.addAll({
          'sender_id': senderIdVal,
          'sender_name': senderNameVal,
          'title': effectiveTask.title,
          'notes': effectiveTask.notes,
          'status': effectiveTask.status,
          'priority': effectiveTask.priority ?? 0,
          'tags': cleanPreviewTags,
          'due_date': effectiveTask.dueDate,
          'due_time': effectiveTask.dueTime,
          'estimate_min': effectiveTask.estimateMin,
          'recurrence_rule': effectiveTask.recurrenceRule,
          'recurrence_mode': effectiveTask.recurrenceMode ?? 'fixed',
          'task_updated_at': nowUtc,
        });

        try {
          await db.execute('''
            UPDATE companion_shares
            SET preview_data = ?, updated_at = ?
            WHERE id = ?
          ''', [jsonEncode(updatedPreview), nowUtc, collabShareRow['id']]);
        } catch (e) {
          debugPrint('[TaskRepository] Local collaborative share preview update notice: $e');
        }

        if (partnerTaskId.isNotEmpty) {
          try {
            final partnerExists = await db.getOptional(
              "SELECT id FROM tasks WHERE id = ? AND (deleted_at IS NULL OR deleted_at = '')",
              [partnerTaskId],
            );
            if (partnerExists != null) {
              await db.execute('''
                UPDATE tasks SET
                  title = ?, notes = ?, status = ?, priority = ?, tags = ?, due_date = ?, due_time = ?, estimate_min = ?, recurrence_rule = ?, recurrence_mode = ?, updated_at = ?
                WHERE id = ?
              ''', [
                effectiveTask.title,
                effectiveTask.notes,
                effectiveTask.status,
                effectiveTask.priority,
                partnerTags,
                effectiveTask.dueDate,
                effectiveTask.dueTime,
                effectiveTask.estimateMin,
                effectiveTask.recurrenceRule,
                effectiveTask.recurrenceMode,
                nowUtc,
                partnerTaskId,
              ]);
            }
          } catch (_) {}
        }

        unawaited(CompanionShareRepository().syncCollaborativeTaskUpdate(effectiveTask));
      }

      final now = nowUtc;
      if (effectiveTask.status == 'done' && oldStatus != 'done') {
        int xp = 5;
        if (effectiveTask.priority == 1) {
          xp = 20; // P1 High
        } else if (effectiveTask.priority == 2) {
          xp = 10; // P2 Medium
        }
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        if (effectiveTask.dueDate != null && effectiveTask.dueDate!.isNotEmpty) {
          if (today.compareTo(effectiveTask.dueDate!) <= 0) {
            xp += 5; // +5 bonus if completed on or before due date (SPEC §6.6)
          }
        }
        final logId = IdGenerator.generateDeterministicId('xp_task_${effectiveTask.id}_$today');
        final existingLog = await db.getOptional('SELECT id FROM logs WHERE id = ?', [logId]);
        if (existingLog != null) {
          await db.execute(
            'UPDATE logs SET xp_earned = ?, updated_at = ?, deleted_at = NULL WHERE id = ?',
            [xp, now, logId],
          );
        } else {
          await db.execute('''
            INSERT INTO logs (id, user_id, task_id, event_type, xp_earned, timestamp, created_at, updated_at)
            VALUES (?, ?, ?, 'task_completed', ?, ?, ?, ?)
          ''', [logId, uid, effectiveTask.id, xp, now, now, now]);
        }
        DomainEvents.emit(TaskCompletedEvent(effectiveTask.id, xp));
      } else if (effectiveTask.status != 'done' && oldStatus == 'done') {
        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayLogId = IdGenerator.generateDeterministicId('xp_task_${effectiveTask.id}_$today');
        final deleteQuery = uid.isNotEmpty
            ? "UPDATE logs SET deleted_at = ?, updated_at = ? WHERE (id = ? OR (task_id = ? AND timestamp LIKE ?)) AND (user_id = ? OR user_id IS NULL OR user_id = '')"
            : "UPDATE logs SET deleted_at = ?, updated_at = ? WHERE id = ? OR (task_id = ? AND timestamp LIKE ?)";
        final deleteParams = uid.isNotEmpty ? [now, now, todayLogId, effectiveTask.id, '$today%', uid] : [now, now, todayLogId, effectiveTask.id, '$today%'];
        await db.execute(deleteQuery, deleteParams);
      }

      if (effectiveTask.tags != null && effectiveTask.tags!.isNotEmpty) {
        CacheService().invalidate('task_tags_list');
      }

      StatsRepository().invalidateStats();
      await syncGlobalUserLevel();
      AppWidgetSyncService().syncTodayTasks();
    } catch (e) {
      debugPrint('[TaskRepository] Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String id) async {
    if (!isDatabaseInitialized) return;
    final uid = currentUserId;
    try {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final deleteLogQuery = uid.isNotEmpty
          ? "UPDATE logs SET deleted_at = ?, updated_at = ? WHERE task_id = ? AND (user_id = ? OR user_id IS NULL OR user_id = '')"
          : 'UPDATE logs SET deleted_at = ?, updated_at = ? WHERE task_id = ?';
      final deleteLogParams = uid.isNotEmpty ? [nowUtc, nowUtc, id, uid] : [nowUtc, nowUtc, id];
      await db.execute(deleteLogQuery, deleteLogParams);

      await db.execute(
        'UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?',
        [nowUtc, nowUtc, id],
      );
      await CompanionShareRepository().cancelSharesForTask(id);

      StatsRepository().invalidateStats();
      await syncGlobalUserLevel();
      AppWidgetSyncService().syncTodayTasks();
    } catch (e) {
      debugPrint('[TaskRepository] Error deleting task: $e');
      rethrow;
    }
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
    if (!isDatabaseInitialized) return;
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
      AppWidgetSyncService().syncTodayTasks();
    } catch (e) {
      debugPrint('[TaskRepository] Error detaching project from tasks: $e');
      rethrow;
    }
  }

  /// Schedules tasks into available day slots using the AutoScheduler domain engine.
  SchedulerResult autoScheduleTasks({
    required List<Task> tasks,
    String workStart = '09:00',
    String workEnd = '18:00',
    int bufferMin = 10,
    int defaultEstimateMin = 30,
    List<BusyBlock> busyBlocks = const [],
  }) {
    final now = DateTime.now();
    final nowTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final date = now.toIso8601String().substring(0, 10);
    final schedulable = tasks
        .where((t) => !t.isCompleted)
        .map((t) => SchedulableTask(t.id, t.estimateMin))
        .toList();

    return AutoScheduler.schedule(
      date,
      nowTime,
      workStart,
      workEnd,
      bufferMin,
      defaultEstimateMin,
      busyBlocks,
      schedulable,
    );
  }
}
