import 'dart:convert';

/// Represents a shared item between companions (Task, Habit, Note, or Project).
class CompanionShare {
  final String id;
  final String senderId;
  final String recipientId;
  final String entityType; // 'task', 'habit', 'note', 'project'
  final String entityId;
  final String shareMode; // 'copy', 'collaborate'
  final String status; // 'pending', 'accepted', 'declined', 'cancelled'
  final Map<String, dynamic> previewData;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Hydrated metadata for sender
  final String senderName;
  final String? senderAvatarUrl;
  final String senderAvatarColor;

  const CompanionShare({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.entityType,
    required this.entityId,
    this.shareMode = 'copy',
    this.status = 'pending',
    required this.previewData,
    required this.createdAt,
    required this.updatedAt,
    this.senderName = 'Companion',
    this.senderAvatarUrl,
    this.senderAvatarColor = '#6366F1',
  });

  bool get isTask => entityType == 'task';
  bool get isHabit => entityType == 'habit';
  bool get isNote => entityType == 'note';
  bool get isProject => entityType == 'project';

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
  bool get isCancelled => status == 'cancelled';

  bool get isCopy => shareMode == 'copy';
  bool get isCollaborative => shareMode == 'collaborate';

  String get title {
    if (isTask) return previewData['title']?.toString() ?? 'Shared Task';
    if (isHabit) return previewData['name']?.toString() ?? 'Shared Habit';
    if (isNote) return previewData['title']?.toString() ?? 'Shared Note';
    if (isProject) return previewData['name']?.toString() ?? 'Shared Project';
    return previewData['title']?.toString() ?? 'Shared Item';
  }

  String? get notes => previewData['notes']?.toString() ?? previewData['body_md']?.toString();
  int? get priority => previewData['priority'] is num ? (previewData['priority'] as num).toInt() : null;
  String? get dueDate => previewData['due_date']?.toString();
  String? get dueTime => previewData['due_time']?.toString();
  int? get estimateMin => previewData['estimate_min'] is num ? (previewData['estimate_min'] as num).toInt() : null;
  String? get recurrenceRule => previewData['recurrence_rule']?.toString();

  List<String> get tags {
    final raw = previewData['tags'];
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      return raw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }

  CompanionShare copyWith({
    String? status,
    DateTime? updatedAt,
    String? senderName,
    String? senderAvatarUrl,
    String? senderAvatarColor,
  }) {
    return CompanionShare(
      id: id,
      senderId: senderId,
      recipientId: recipientId,
      entityType: entityType,
      entityId: entityId,
      shareMode: shareMode,
      status: status ?? this.status,
      previewData: previewData,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      senderAvatarColor: senderAvatarColor ?? this.senderAvatarColor,
    );
  }

  factory CompanionShare.fromRow(Map<String, dynamic> row) {
    Map<String, dynamic> parsedPreview = {};
    final rawPreview = row['preview_data'];
    if (rawPreview is Map) {
      parsedPreview = Map<String, dynamic>.from(rawPreview);
    } else if (rawPreview is String && rawPreview.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPreview);
        if (decoded is Map) {
          parsedPreview = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    DateTime parsedCreated;
    try {
      parsedCreated = DateTime.parse(row['created_at']?.toString() ?? '').toLocal();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime parsedUpdated;
    try {
      parsedUpdated = DateTime.parse(row['updated_at']?.toString() ?? '').toLocal();
    } catch (_) {
      parsedUpdated = parsedCreated;
    }

    return CompanionShare(
      id: row['id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      recipientId: row['recipient_id']?.toString() ?? '',
      entityType: row['entity_type']?.toString() ?? 'task',
      entityId: row['entity_id']?.toString() ?? '',
      shareMode: row['share_mode']?.toString() ?? 'copy',
      status: row['status']?.toString() ?? 'pending',
      previewData: parsedPreview,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
      senderName: row['sender_name']?.toString() ?? 'Companion',
      senderAvatarUrl: row['sender_avatar_url']?.toString(),
      senderAvatarColor: row['sender_avatar_color']?.toString() ?? '#6366F1',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'entity_type': entityType,
      'entity_id': entityId,
      'share_mode': shareMode,
      'status': status,
      'preview_data': jsonEncode(previewData),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}

