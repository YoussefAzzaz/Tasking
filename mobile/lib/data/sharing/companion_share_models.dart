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
  final String? acceptedEntityId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Hydrated metadata for sender / counterpart
  final String senderName;
  final String? senderAvatarUrl;
  final String senderAvatarColor;
  final String recipientName;
  final String? recipientAvatarUrl;
  final String recipientAvatarColor;
  final bool isDeclinedDismissed;

  const CompanionShare({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.entityType,
    required this.entityId,
    this.shareMode = 'copy',
    this.status = 'pending',
    required this.previewData,
    this.acceptedEntityId,
    required this.createdAt,
    required this.updatedAt,
    this.senderName = 'Companion',
    this.senderAvatarUrl,
    this.senderAvatarColor = '#6366F1',
    this.recipientName = 'Companion',
    this.recipientAvatarUrl,
    this.recipientAvatarColor = '#6366F1',
    this.isDeclinedDismissed = false,
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

  bool get isCollaborativeTaskDeleted =>
      status == 'cancelled' &&
      shareMode == 'collaborate' &&
      entityType == 'task' &&
      (previewData['cancellation_reason'] == 'collaborative_task_deleted' ||
          (previewData['cancelled_by'] != null &&
              previewData['cancelled_by'].toString().trim().isNotEmpty));

  String? get cancelledByUserId {
    final val = previewData['cancelled_by']?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : null;
  }

  String? get cancelledByName {
    final val = previewData['cancelled_by_name']?.toString().trim();
    return (val != null && val.isNotEmpty) ? val : null;
  }

  String get title {
    if (isTask) return previewData['title']?.toString() ?? 'Shared Task';
    if (isHabit) {
      return previewData['title']?.toString() ??
          previewData['name']?.toString() ??
          'Shared Habit';
    }
    if (isNote) return previewData['title']?.toString() ?? 'Shared Note';
    if (isProject) {
      return previewData['title']?.toString() ??
          previewData['name']?.toString() ??
          'Shared Project';
    }
    return previewData['title']?.toString() ?? 'Shared Item';
  }

  String? get notes =>
      previewData['notes']?.toString() ?? previewData['body_md']?.toString();
  int? get priority => previewData['priority'] is num
      ? (previewData['priority'] as num).toInt()
      : null;
  String? get dueDate => previewData['due_date']?.toString();
  String? get dueTime => previewData['due_time']?.toString();
  int? get estimateMin => previewData['estimate_min'] is num
      ? (previewData['estimate_min'] as num).toInt()
      : null;
  String? get recurrenceRule => previewData['recurrence_rule']?.toString();
  String? get recurrenceMode => previewData['recurrence_mode']?.toString();
  String? get taskStatus => previewData['status']?.toString();
  String? get previewSenderName => previewData['sender_name']?.toString();

  // Habit preview helpers
  String? get habitIcon => previewData['icon']?.toString();
  String? get habitColor => previewData['color']?.toString();
  String? get habitKind => previewData['kind']?.toString();
  String? get scheduleType => previewData['schedule_type']?.toString();
  String? get remindTime => previewData['remind_time']?.toString();
  int? get targetValue => previewData['target_value'] is num
      ? (previewData['target_value'] as num).toInt()
      : int.tryParse(previewData['target_value']?.toString() ?? '');

  // Note preview helpers
  String? get noteBody =>
      previewData['body_md']?.toString() ?? previewData['notes']?.toString();
  String? get noteCategory => previewData['category']?.toString();
  String? get mood => previewData['mood']?.toString();
  String? get energy => previewData['energy']?.toString();

  List<String> get tags {
    final raw = previewData['tags'];
    if (raw == null) return const [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      return raw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  CompanionShare copyWith({
    String? status,
    String? acceptedEntityId,
    DateTime? updatedAt,
    String? senderName,
    String? senderAvatarUrl,
    String? senderAvatarColor,
    String? recipientName,
    String? recipientAvatarUrl,
    String? recipientAvatarColor,
    bool? isDeclinedDismissed,
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
      acceptedEntityId: acceptedEntityId ?? this.acceptedEntityId,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      senderAvatarColor: senderAvatarColor ?? this.senderAvatarColor,
      recipientName: recipientName ?? this.recipientName,
      recipientAvatarUrl: recipientAvatarUrl ?? this.recipientAvatarUrl,
      recipientAvatarColor: recipientAvatarColor ?? this.recipientAvatarColor,
      isDeclinedDismissed: isDeclinedDismissed ?? this.isDeclinedDismissed,
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
      parsedCreated =
          DateTime.parse(row['created_at']?.toString() ?? '').toLocal();
    } catch (_) {
      parsedCreated = DateTime.now();
    }

    DateTime parsedUpdated;
    try {
      parsedUpdated =
          DateTime.parse(row['updated_at']?.toString() ?? '').toLocal();
    } catch (_) {
      parsedUpdated = parsedCreated;
    }

    final acceptedEntityRaw = row['accepted_entity_id']?.toString();
    final rawSenderName = row['sender_name']?.toString().trim();
    final previewSender = parsedPreview['sender_name']?.toString().trim();
    final effectiveSenderName = (rawSenderName != null &&
            rawSenderName.isNotEmpty &&
            rawSenderName != 'Companion')
        ? rawSenderName
        : ((previewSender != null && previewSender.isNotEmpty)
            ? previewSender
            : 'Companion');

    final rawRecipientName = row['recipient_name']?.toString().trim();
    final previewRecipient = parsedPreview['recipient_name']?.toString().trim();
    final effectiveRecipientName = (rawRecipientName != null &&
            rawRecipientName.isNotEmpty &&
            rawRecipientName != 'Companion')
        ? rawRecipientName
        : ((previewRecipient != null && previewRecipient.isNotEmpty)
            ? previewRecipient
            : (rawSenderName != null &&
                    rawSenderName.isNotEmpty &&
                    rawSenderName != effectiveSenderName)
                ? rawSenderName
                : 'Companion');

    final dismissedVal = parsedPreview['declined_notice_dismissed'];
    final isDeclinedDismissed =
        dismissedVal == true || dismissedVal == 'true' || dismissedVal == 1;

    return CompanionShare(
      id: row['id']?.toString() ?? '',
      senderId: row['sender_id']?.toString() ?? '',
      recipientId: row['recipient_id']?.toString() ?? '',
      entityType: row['entity_type']?.toString() ?? 'task',
      entityId: row['entity_id']?.toString() ?? '',
      shareMode: row['share_mode']?.toString() ?? 'copy',
      status: row['status']?.toString() ?? 'pending',
      previewData: parsedPreview,
      acceptedEntityId:
          (acceptedEntityRaw != null && acceptedEntityRaw.isNotEmpty)
              ? acceptedEntityRaw
              : null,
      createdAt: parsedCreated,
      updatedAt: parsedUpdated,
      senderName: effectiveSenderName,
      senderAvatarUrl: row['sender_avatar_url']?.toString(),
      senderAvatarColor: row['sender_avatar_color']?.toString() ?? '#6366F1',
      recipientName: effectiveRecipientName,
      recipientAvatarUrl: row['recipient_avatar_url']?.toString(),
      recipientAvatarColor:
          row['recipient_avatar_color']?.toString() ?? '#6366F1',
      isDeclinedDismissed: isDeclinedDismissed,
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
      'accepted_entity_id': acceptedEntityId,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
