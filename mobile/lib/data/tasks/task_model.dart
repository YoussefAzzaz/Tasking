import 'dart:convert';
import 'package:axis/data/powersync_db.dart';

/// Core Task entity with collaborative share preview overlay reconciliation.
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

  /// Non-null only for virtual projected recurring occurrences on future calendar dates.
  final String? sourceTaskId;

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
    this.sourceTaskId,
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
    String? sourceTaskId,
    bool clearDueDate = false,
    bool clearDueTime = false,
    bool clearNotes = false,
    bool clearProjectId = false,
    bool clearTags = false,
    bool clearEstimateMin = false,
    bool clearRecurrenceRule = false,
    bool clearRecurrenceMode = false,
    bool clearPriority = false,
    bool clearSourceTaskId = false,
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
      sourceTaskId: clearSourceTaskId ? null : (sourceTaskId ?? this.sourceTaskId),
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
        if (decoded is Map) preview = Map<String, dynamic>.from(decoded);
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

    final localUpdated = DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toUtc();
    final previewUpdated =
        DateTime.tryParse(preview['task_updated_at']?.toString() ?? '')?.toUtc();
    final useNewerPreview = isCollab &&
        preview.isNotEmpty &&
        previewUpdated != null &&
        (localUpdated == null || previewUpdated.isAfter(localUpdated));

    return Task(
      id: row['id'],
      userId: row['user_id'],
      title: useNewerPreview && preview['title']?.toString().trim().isNotEmpty == true
          ? preview['title'].toString()
          : (row['title']?.toString() ?? ''),
      notes: useNewerPreview && preview.containsKey('notes')
          ? preview['notes']?.toString()
          : row['notes']?.toString(),
      status: useNewerPreview && preview['status'] != null
          ? preview['status'].toString()
          : (row['status']?.toString() ?? 'todo'),
      priority: useNewerPreview && preview['priority'] is num
          ? (preview['priority'] as num).toInt()
          : (row['priority'] is num ? (row['priority'] as num).toInt() : row['priority'] as int?),
      projectId: row['project_id'],
      tags: useNewerPreview && preview.containsKey('tags')
          ? preview['tags']?.toString()
          : row['tags']?.toString(),
      dueDate: useNewerPreview && preview.containsKey('due_date')
          ? preview['due_date']?.toString()
          : row['due_date']?.toString(),
      dueTime: useNewerPreview && preview.containsKey('due_time')
          ? preview['due_time']?.toString()
          : row['due_time']?.toString(),
      estimateMin: useNewerPreview && preview.containsKey('estimate_min')
          ? (preview['estimate_min'] is num ? (preview['estimate_min'] as num).toInt() : null)
          : (row['estimate_min'] is num
              ? (row['estimate_min'] as num).toInt()
              : row['estimate_min'] as int?),
      recurrenceRule: useNewerPreview && preview.containsKey('recurrence_rule')
          ? preview['recurrence_rule']?.toString()
          : row['recurrence_rule']?.toString(),
      recurrenceMode: useNewerPreview && preview.containsKey('recurrence_mode')
          ? preview['recurrence_mode']?.toString()
          : row['recurrence_mode']?.toString(),
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
  bool get isRecurring => recurrenceRule != null && recurrenceRule!.trim().isNotEmpty;
  bool get isProjectedOccurrence => sourceTaskId != null && sourceTaskId!.trim().isNotEmpty;
  bool get isSharedTask =>
      isCollaborative || (senderUsername != null && senderUsername!.trim().isNotEmpty);
}
