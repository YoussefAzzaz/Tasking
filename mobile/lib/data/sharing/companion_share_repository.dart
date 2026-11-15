import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/friends/friend_search_repository.dart';
import 'companion_share_models.dart';

export 'companion_share_models.dart';

/// Centralized repository for sharing tasks, habits, notes, and projects between companions.
class CompanionShareRepository {
  static final CompanionShareRepository _instance =
      CompanionShareRepository._internal();
  factory CompanionShareRepository() => _instance;
  CompanionShareRepository._internal();

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isRemoteAuthenticated {
    if (isSigningOut) return false;
    final client = _supabaseClient;
    if (client == null) return false;
    final session = client.auth.currentSession;
    return session != null && !session.isExpired;
  }

  Future<String> _resolveAuthoritativeSenderName() async {
    try {
      final profName = UserProfileRepository().profileNotifier.value.name.trim();
      if (profName.isNotEmpty &&
          profName != 'Commander' &&
          profName != 'Companion') {
        return profName;
      }
    } catch (_) {}
    final uid = currentUserId;
    if (isDatabaseInitialized && uid.isNotEmpty) {
      try {
        final row = await db.getOptional(
          'SELECT name FROM user_profiles WHERE user_id = ? LIMIT 1',
          [uid],
        );
        final dbName = row?['name']?.toString().trim() ?? '';
        if (dbName.isNotEmpty && dbName != 'Commander' && dbName != 'Companion') {
          return dbName;
        }
      } catch (_) {}
    }
    try {
      final user = _supabaseClient?.auth.currentUser;
      final metaDisplay = user?.userMetadata?['display_name']?.toString().trim();
      if (metaDisplay != null && metaDisplay.isNotEmpty) return metaDisplay;
      final metaName = user?.userMetadata?['name']?.toString().trim();
      if (metaName != null && metaName.isNotEmpty) return metaName;
      final email = user?.email?.trim() ?? '';
      if (email.contains('@')) return email.split('@').first;
    } catch (_) {}
    return 'Companion';
  }

  String _resolveSenderDisplayName() {
    try {
      final profName = UserProfileRepository().profileNotifier.value.name.trim();
      if (profName.isNotEmpty && profName != 'Commander') {
        return profName;
      }
    } catch (_) {}
    try {
      final user = _supabaseClient?.auth.currentUser;
      final metaDisplay = user?.userMetadata?['display_name']?.toString();
      if (metaDisplay != null && metaDisplay.trim().isNotEmpty) {
        return metaDisplay.trim();
      }
      final metaName = user?.userMetadata?['name']?.toString();
      if (metaName != null && metaName.trim().isNotEmpty) {
        return metaName.trim();
      }
    } catch (_) {}
    return 'A companion';
  }

  List<CompanionShare> _hydrateRows(
    List<Map<String, dynamic>> rows, {
    required bool useRecipientForCache,
  }) {
    final profileCache = FriendSearchRepository().inMemoryProfileCache;
    return rows.map((r) {
      var share = CompanionShare.fromRow(r);
      final senderProf = profileCache[share.senderId];
      if (senderProf != null &&
          (share.senderName == 'Companion' || share.senderName.isEmpty)) {
        final cachedName = senderProf['name']?.toString().trim() ?? '';
        if (cachedName.isNotEmpty) {
          share = share.copyWith(
            senderName: cachedName,
            senderAvatarUrl:
                senderProf['avatar_url']?.toString() ?? share.senderAvatarUrl,
            senderAvatarColor: senderProf['avatar_color']?.toString() ??
                share.senderAvatarColor,
          );
        }
      }
      final recipientProf = profileCache[share.recipientId];
      if (recipientProf != null &&
          (share.recipientName == 'Companion' ||
              share.recipientName.isEmpty)) {
        final cachedName = recipientProf['name']?.toString().trim() ?? '';
        if (cachedName.isNotEmpty) {
          share = share.copyWith(
            recipientName: cachedName,
            recipientAvatarUrl: recipientProf['avatar_url']?.toString() ??
                share.recipientAvatarUrl,
            recipientAvatarColor: recipientProf['avatar_color']?.toString() ??
                share.recipientAvatarColor,
            senderName: useRecipientForCache &&
                    (share.senderName == 'Companion' ||
                        share.senderName.isEmpty)
                ? cachedName
                : null,
            senderAvatarUrl: useRecipientForCache &&
                    (share.senderName == 'Companion' ||
                        share.senderName.isEmpty)
                ? recipientProf['avatar_url']?.toString()
                : null,
            senderAvatarColor: useRecipientForCache &&
                    (share.senderName == 'Companion' ||
                        share.senderName.isEmpty)
                ? recipientProf['avatar_color']?.toString()
                : null,
          );
        }
      }
      return share;
    }).toList();
  }

  static const String _itemSharedWithCompanionsSql = '''
    SELECT sender_id, recipient_id
    FROM companion_shares
    WHERE entity_type = ?
      AND status IN ('pending', 'accepted')
      AND (
        (sender_id = ? AND (entity_id = ? OR accepted_entity_id = ?))
        OR (recipient_id = ? AND (entity_id = ? OR accepted_entity_id = ?))
      )
  ''';

  static const String _companionSharedItemsSql = '''
    SELECT entity_id, accepted_entity_id
    FROM companion_shares
    WHERE entity_type = ?
      AND status IN ('pending', 'accepted')
      AND (
        (sender_id = ? AND recipient_id = ?)
        OR (sender_id = ? AND recipient_id = ?)
      )
  ''';

  Set<String> _extractCounterpartIds(List<Map<String, dynamic>> rows, String uid) {
    final ids = <String>{};
    for (final r in rows) {
      final senderId = r['sender_id']?.toString().trim() ?? '';
      final recipientId = r['recipient_id']?.toString().trim() ?? '';
      if (senderId == uid && recipientId.isNotEmpty) {
        ids.add(recipientId);
      } else if (recipientId == uid && senderId.isNotEmpty) {
        ids.add(senderId);
      }
    }
    return ids;
  }

  Set<String> _extractEntityIds(List<Map<String, dynamic>> rows) {
    final ids = <String>{};
    for (final r in rows) {
      final eid = r['entity_id']?.toString().trim() ?? '';
      final aid = r['accepted_entity_id']?.toString().trim() ?? '';
      if (eid.isNotEmpty) ids.add(eid);
      if (aid.isNotEmpty) ids.add(aid);
    }
    return ids;
  }

  /// Returns companion user IDs with whom [entityId] ([entityType]) already has an active share.
  Future<Set<String>> getSharedCompanionIdsForItem({
    required String entityType,
    required String entityId,
  }) async {
    if (!isDatabaseInitialized) return const <String>{};
    final uid = currentUserId;
    if (uid.isEmpty || entityId.trim().isEmpty) return const <String>{};
    try {
      final rows = await db.getAll(
        _itemSharedWithCompanionsSql,
        [entityType, uid, entityId, entityId, uid, entityId, entityId],
      );
      return _extractCounterpartIds(rows, uid);
    } catch (_) {
      return const <String>{};
    }
  }

  /// Watches companion user IDs with whom [entityId] ([entityType]) already has an active share.
  Stream<Set<String>> watchSharedCompanionIdsForItem({
    required String entityType,
    required String entityId,
  }) {
    if (!isDatabaseInitialized) return Stream.value(const <String>{});
    final uid = currentUserId;
    if (uid.isEmpty || entityId.trim().isEmpty) {
      return Stream.value(const <String>{});
    }
    return db
        .watch(
          _itemSharedWithCompanionsSql,
          parameters: [entityType, uid, entityId, entityId, uid, entityId, entityId],
        )
        .map((rows) => _extractCounterpartIds(rows, uid));
  }

  /// Returns entity IDs ([entityType]) already actively shared between current user and [companionUserId].
  Future<Set<String>> getSharedEntityIdsForCompanion({
    required String companionUserId,
    required String entityType,
  }) async {
    if (!isDatabaseInitialized) return const <String>{};
    final uid = currentUserId;
    if (uid.isEmpty || companionUserId.trim().isEmpty) {
      return const <String>{};
    }
    try {
      final rows = await db.getAll(
        _companionSharedItemsSql,
        [entityType, uid, companionUserId, companionUserId, uid],
      );
      return _extractEntityIds(rows);
    } catch (_) {
      return const <String>{};
    }
  }

  /// Watches entity IDs ([entityType]) already actively shared between current user and [companionUserId].
  Stream<Set<String>> watchSharedEntityIdsForCompanion({
    required String companionUserId,
    required String entityType,
  }) {
    if (!isDatabaseInitialized) return Stream.value(const <String>{});
    final uid = currentUserId;
    if (uid.isEmpty || companionUserId.trim().isEmpty) {
      return Stream.value(const <String>{});
    }
    return db
        .watch(
          _companionSharedItemsSql,
          parameters: [entityType, uid, companionUserId, companionUserId, uid],
        )
        .map(_extractEntityIds);
  }

  /// Checks both local SQLite and Supabase to see if [entityId] was already shared with [companionUserId].
  Future<bool> isItemAlreadySharedWithCompanion({
    required String entityType,
    required String entityId,
    required String companionUserId,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty || entityId.trim().isEmpty || companionUserId.trim().isEmpty) {
      return false;
    }

    final localSharedIds = await getSharedCompanionIdsForItem(
      entityType: entityType,
      entityId: entityId,
    );
    if (localSharedIds.contains(companionUserId)) {
      return true;
    }

    if (isRemoteAuthenticated && _supabaseClient != null) {
      try {
        final res = await _supabaseClient!
            .from('companion_shares')
            .select('id')
            .eq('entity_type', entityType)
            .inFilter('status', const ['pending', 'accepted'])
            .or(
              'and(sender_id.eq.$uid,recipient_id.eq.$companionUserId,entity_id.eq.$entityId),'
              'and(sender_id.eq.$uid,recipient_id.eq.$companionUserId,accepted_entity_id.eq.$entityId),'
              'and(sender_id.eq.$companionUserId,recipient_id.eq.$uid,entity_id.eq.$entityId),'
              'and(sender_id.eq.$companionUserId,recipient_id.eq.$uid,accepted_entity_id.eq.$entityId)',
            )
            .limit(1)
            .timeout(const Duration(seconds: 3));
        if ((res as List).isNotEmpty) {
          return true;
        }
      } catch (e) {
        debugPrint('[CompanionShareRepository] Duplicate check remote notice: $e');
      }
    }

    return false;
  }

  List<CompanionShare> _deduplicatePendingShares(List<CompanionShare> shares) {
    final seen = <String>{};
    final result = <CompanionShare>[];
    for (final s in shares) {
      final key = '${s.senderId}|${s.recipientId}|${s.entityType}|${s.entityId}';
      if (seen.add(key)) {
        result.add(s);
      }
    }
    return result;
  }

  /// Watches pending incoming shares sent to current user.
  Stream<List<CompanionShare>> watchPendingIncomingShares() {
    if (!isDatabaseInitialized) return Stream.value(const []);
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    const query = '''
      SELECT 
        s.*,
        COALESCE(p.name, 'Companion') AS sender_name,
        p.avatar_url AS sender_avatar_url,
        COALESCE(p.avatar_color, '#6366F1') AS sender_avatar_color
      FROM companion_shares s
      LEFT JOIN user_profiles p ON p.user_id = s.sender_id
      WHERE s.recipient_id = ? AND s.status = 'pending'
      ORDER BY s.created_at DESC
    ''';

    return db.watch(query, parameters: [uid]).map(
      (rows) => _deduplicatePendingShares(
        _hydrateRows(rows, useRecipientForCache: false),
      ),
    );
  }

  /// Watches all shares sent by current user.
  Stream<List<CompanionShare>> watchSentShares() {
    if (!isDatabaseInitialized) return Stream.value(const []);
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    const query = '''
      SELECT 
        s.*,
        COALESCE(p.name, 'Companion') AS sender_name,
        p.avatar_url AS sender_avatar_url,
        COALESCE(p.avatar_color, '#6366F1') AS sender_avatar_color,
        COALESCE(p.name, 'Companion') AS recipient_name,
        p.avatar_url AS recipient_avatar_url,
        COALESCE(p.avatar_color, '#6366F1') AS recipient_avatar_color
      FROM companion_shares s
      LEFT JOIN user_profiles p ON p.user_id = s.recipient_id
      WHERE s.sender_id = ?
      ORDER BY s.created_at DESC
    ''';

    return db.watch(query, parameters: [uid]).map(
      (rows) => _hydrateRows(rows, useRecipientForCache: true),
    );
  }

  /// Watches declined share requests sent by current user AND collaborative task
  /// deletion notices where a companion deleted a shared collaborative task.
  Stream<List<CompanionShare>> watchDeclinedSentShares() {
    if (!isDatabaseInitialized) return Stream.value(const []);
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const []);

    const query = '''
      SELECT
        s.*,
        COALESCE(sp.name, 'Companion') AS sender_name,
        sp.avatar_url AS sender_avatar_url,
        COALESCE(sp.avatar_color, '#6366F1') AS sender_avatar_color,
        COALESCE(rp.name, 'Companion') AS recipient_name,
        rp.avatar_url AS recipient_avatar_url,
        COALESCE(rp.avatar_color, '#6366F1') AS recipient_avatar_color
      FROM companion_shares s
      LEFT JOIN user_profiles sp ON sp.user_id = s.sender_id
      LEFT JOIN user_profiles rp ON rp.user_id = s.recipient_id
      WHERE (s.sender_id = ? AND s.status = 'declined')
         OR (
           (s.sender_id = ? OR s.recipient_id = ?)
           AND s.status = 'cancelled'
           AND s.share_mode = 'collaborate'
           AND s.entity_type = 'task'
         )
      ORDER BY s.updated_at DESC
    ''';

    return db.watch(query, parameters: [uid, uid, uid]).map(
      (rows) => _hydrateRows(rows, useRecipientForCache: false).where((s) {
        if (s.isDeclinedDismissed) return false;
        if (s.isDeclined) return s.senderId == uid;
        if (s.isCollaborativeTaskDeleted) {
          final cancelledBy = s.cancelledByUserId;
          if (cancelledBy != null && cancelledBy.isNotEmpty) {
            return cancelledBy != uid;
          }
          return s.senderId == uid;
        }
        return false;
      }).toList(),
    );
  }

  /// Watches undismissed collaborative task deletion notices for the current user.
  Stream<List<CompanionShare>> watchCollaborativeTaskDeletedNotices() {
    return watchDeclinedSentShares().map(
      (shares) => shares.where((s) => s.isCollaborativeTaskDeleted).toList(),
    );
  }

  /// Marks a declined sent-share notice as dismissed in `preview_data` so it stays hidden.
  Future<void> dismissDeclinedShareNotice(String shareId) async {
    final cleanId = shareId.trim();
    if (cleanId.isEmpty || !isDatabaseInitialized) return;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> updatedPreview = {};

    try {
      final existing = await db.getOptional(
        'SELECT preview_data FROM companion_shares WHERE id = ? LIMIT 1',
        [cleanId],
      );
      final rawPreview = existing?['preview_data'];
      if (rawPreview is String && rawPreview.trim().isNotEmpty) {
        final decoded = jsonDecode(rawPreview);
        if (decoded is Map) {
          updatedPreview = Map<String, dynamic>.from(decoded);
        }
      } else if (rawPreview is Map) {
        updatedPreview = Map<String, dynamic>.from(rawPreview);
      }
      updatedPreview['declined_notice_dismissed'] = true;
      updatedPreview['declined_notice_dismissed_at'] = nowUtc;

      await db.execute('''
        UPDATE companion_shares
        SET preview_data = ?, updated_at = ?
        WHERE id = ?
      ''', [jsonEncode(updatedPreview), nowUtc, cleanId]);
    } catch (e) {
      debugPrint(
          '[CompanionShareRepository] dismissDeclinedShareNotice local notice: $e');
    }

    if (isRemoteAuthenticated && _supabaseClient != null) {
      unawaited(() async {
        try {
          await _supabaseClient!
              .from('companion_shares')
              .update({
                'preview_data': updatedPreview,
                'updated_at': nowUtc,
              })
              .eq('id', cleanId);
        } catch (e) {
          debugPrint(
              '[CompanionShareRepository] dismissDeclinedShareNotice remote notice: $e');
        }
      }());
    }
  }

  /// Watches the set of local entity IDs actively linked via an accepted collaborative share.
  Stream<Set<String>> watchCollaborativeEntityIds(String entityType) {
    if (!isDatabaseInitialized) return Stream.value(const <String>{});
    final uid = currentUserId;
    if (uid.isEmpty) return Stream.value(const <String>{});

    const query = '''
      SELECT entity_id, accepted_entity_id
      FROM companion_shares
      WHERE entity_type = ?
        AND share_mode = 'collaborate'
        AND status = 'accepted'
        AND (sender_id = ? OR recipient_id = ?)
    ''';

    return db.watch(query, parameters: [entityType, uid, uid]).map((rows) {
      final ids = <String>{};
      for (final row in rows) {
        final eid = row['entity_id']?.toString();
        final aid = row['accepted_entity_id']?.toString();
        if (eid != null && eid.isNotEmpty) ids.add(eid);
        if (aid != null && aid.isNotEmpty) ids.add(aid);
      }
      return ids;
    });
  }

  /// Sends an uncompleted Task to a companion with offline-first snapshot & collaboration support.
  Future<CompanionShare> shareTask({
    required Task task,
    required String recipientId,
    String shareMode = 'copy',
  }) async {
    if (task.isCompleted) {
      throw StateError('Completed tasks cannot be shared or collaborated on.');
    }

    final senderName = await _resolveAuthoritativeSenderName();
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final cleanTags = TaskRepository.removeSenderTag(task.tags, senderName);

    final preview = <String, dynamic>{
      'title': task.title,
      'notes': task.notes,
      'status': task.status,
      'priority': task.priority ?? 0,
      'tags': cleanTags,
      'due_date': task.dueDate,
      'due_time': task.dueTime,
      'estimate_min': task.estimateMin,
      'recurrence_rule': task.recurrenceRule,
      'recurrence_mode': task.recurrenceMode,
      'sender_id': currentUserId,
      'sender_name': senderName,
      'task_updated_at': nowUtc,
    };

    return _createAndSyncShare(
      entityType: 'task',
      entityId: task.id,
      itemTitle: task.title,
      preview: preview,
      recipientId: recipientId,
      shareMode: shareMode,
      sourceTask: shareMode == 'collaborate'
          ? task.copyWith(tags: cleanTags, senderUsername: senderName)
          : null,
    );
  }

  /// Sends a Habit snapshot copy to a companion (share-only, no collaboration mode).
  Future<CompanionShare> shareHabit({
    required Habit habit,
    required String recipientId,
    String shareMode = 'copy',
  }) async {
    final senderName = await _resolveAuthoritativeSenderName();
    final preview = <String, dynamic>{
      'title': habit.name,
      'name': habit.name,
      'icon': habit.icon,
      'color': habit.color,
      'kind': habit.category.isNotEmpty ? habit.category : 'boolean',
      'target_value': habit.targetValue,
      'schedule_type': habit.scheduleType,
      'remind_time': habit.remindTime,
      'sender_id': currentUserId,
      'sender_name': senderName,
    };

    return _createAndSyncShare(
      entityType: 'habit',
      entityId: habit.id,
      itemTitle: habit.name,
      preview: preview,
      recipientId: recipientId,
      shareMode: 'copy',
    );
  }

  /// Sends a Note snapshot copy to a companion (share-only, no collaboration mode).
  Future<CompanionShare> shareNote({
    required Note note,
    required String recipientId,
    String shareMode = 'copy',
  }) async {
    final senderName = await _resolveAuthoritativeSenderName();
    final preview = <String, dynamic>{
      'title': note.title,
      'notes': note.bodyMd,
      'body_md': note.bodyMd,
      'category': note.category,
      'mood': note.mood,
      'energy': note.energy,
      'sender_id': currentUserId,
      'sender_name': senderName,
    };

    return _createAndSyncShare(
      entityType: 'note',
      entityId: note.id,
      itemTitle: note.title,
      preview: preview,
      recipientId: recipientId,
      shareMode: 'copy',
    );
  }

  Future<CompanionShare> _createAndSyncShare({
    required String entityType,
    required String entityId,
    required String itemTitle,
    required Map<String, dynamic> preview,
    required String recipientId,
    required String shareMode,
    Task? sourceTask,
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw StateError('User must be signed in to share items with companions.');
    }

    final alreadyShared = await isItemAlreadySharedWithCompanion(
      entityType: entityType,
      entityId: entityId,
      companionUserId: recipientId,
    );
    if (alreadyShared) {
      throw StateError(
        'This $entityType has already been shared with this companion.',
      );
    }

    final shareId = IdGenerator.generateDeterministicId(
      'share_${uid}_${recipientId}_${entityType}_$entityId',
    );
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final previewJson = jsonEncode(preview);

    await db.execute('''
      INSERT OR REPLACE INTO companion_shares (
        id, sender_id, recipient_id, entity_type, entity_id,
        share_mode, status, preview_data, accepted_entity_id, created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?, ?, ?, 'pending', ?, NULL, ?, ?
      )
    ''', [
      shareId,
      uid,
      recipientId,
      entityType,
      entityId,
      shareMode,
      previewJson,
      nowUtc,
      nowUtc,
    ]);

    final share = CompanionShare(
      id: shareId,
      senderId: uid,
      recipientId: recipientId,
      entityType: entityType,
      entityId: entityId,
      shareMode: shareMode,
      status: 'pending',
      previewData: preview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      senderName: preview['sender_name']?.toString() ?? 'Companion',
    );

    if (isRemoteAuthenticated) {
      unawaited(() async {
        // For collaborative tasks, ensure the sender's task row exists remotely BEFORE creating the share.
        if (entityType == 'task' && shareMode == 'collaborate' && sourceTask != null) {
          try {
            final cleanStatus = (sourceTask.status == 'done' || sourceTask.status == 'cancelled')
                ? sourceTask.status
                : 'todo';
            await _supabaseClient!.from('tasks').upsert({
              'id': sourceTask.id,
              'user_id': uid,
              'title': sourceTask.title,
              'notes': sourceTask.notes,
              'status': cleanStatus,
              'priority': (sourceTask.priority ?? 0).clamp(0, 3),
              'project_id': null,
              'tags': sourceTask.tags,
              'due_date': (sourceTask.dueDate != null && sourceTask.dueDate!.trim().isNotEmpty)
                  ? sourceTask.dueDate
                  : null,
              'due_time': (sourceTask.dueTime != null && sourceTask.dueTime!.trim().isNotEmpty)
                  ? sourceTask.dueTime
                  : null,
              'estimate_min': sourceTask.estimateMin,
              'recurrence_rule': (sourceTask.recurrenceRule != null && sourceTask.recurrenceRule!.trim().isNotEmpty)
                  ? sourceTask.recurrenceRule
                  : null,
              'recurrence_mode': (sourceTask.recurrenceMode == 'fixed' || sourceTask.recurrenceMode == 'after_completion')
                  ? sourceTask.recurrenceMode
                  : 'fixed',
              'updated_at': nowUtc,
            });
          } catch (e) {
            debugPrint('[CompanionShareRepository] Sender collaborative task upsert notice: $e');
          }
        }
        try {
          await _supabaseClient!.from('companion_shares').upsert({
            'id': shareId,
            'sender_id': uid,
            'recipient_id': recipientId,
            'entity_type': entityType,
            'entity_id': entityId,
            'share_mode': shareMode,
            'status': 'pending',
            'preview_data': previewJson,
            'accepted_entity_id': null,
            'created_at': nowUtc,
            'updated_at': nowUtc,
          });
        } catch (e) {
          debugPrint('[CompanionShareRepository] Immediate share upsert notice: $e');
        }
        await _logShareSentActivity(
          recipientId: recipientId,
          shareId: shareId,
          entityType: entityType,
          shareMode: shareMode,
          itemTitle: itemTitle,
        );
      }());
    }

    return share;
  }

  /// Accepts a shared item, performs idempotent local cloning, links accepted_entity_id,
  /// and synchronizes acceptance to Supabase.
  Future<String> acceptShare(CompanionShare share) async {
    final uid = currentUserId;
    if (uid.isEmpty) {
      throw StateError('User must be signed in to accept shared items.');
    }

    String? existingAcceptedId = share.acceptedEntityId?.trim();
    if (isDatabaseInitialized &&
        (existingAcceptedId == null || existingAcceptedId.isEmpty)) {
      try {
        final existingShare = await db.getOptional('''
          SELECT accepted_entity_id
          FROM companion_shares
          WHERE (
              id = ?
              OR (
                sender_id = ?
                AND recipient_id = ?
                AND entity_type = ?
                AND entity_id = ?
                AND status = 'accepted'
              )
            )
            AND accepted_entity_id IS NOT NULL
            AND accepted_entity_id != ''
          ORDER BY updated_at DESC
          LIMIT 1
        ''', [
          share.id,
          share.senderId,
          uid,
          share.entityType,
          share.entityId,
        ]);
        existingAcceptedId =
            existingShare?['accepted_entity_id']?.toString().trim();
      } catch (_) {}
    }

    final clonedId =
        (existingAcceptedId != null && existingAcceptedId.isNotEmpty)
            ? existingAcceptedId
            : IdGenerator.generateDeterministicId(
                'accepted_${share.entityType}_${share.senderId}_${uid}_${share.entityId}',
              );
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final updatedPreview = Map<String, dynamic>.from(share.previewData);
    final rawSenderName = (share.previewSenderName != null &&
            share.previewSenderName!.trim().isNotEmpty &&
            share.previewSenderName!.trim() != 'Companion')
        ? share.previewSenderName!.trim()
        : (share.senderName.trim() != 'Companion'
            ? share.senderName.trim()
            : '');
    final cleanSenderUsername =
        rawSenderName.replaceFirst(RegExp(r'^@+'), '').trim();

    // 1. Instant Local Cloning into recipient's private records (idempotent upsert)
    if (share.isTask) {
      final tagsString =
          TaskRepository.mergeSenderTag(share.tags.join(','), cleanSenderUsername);
      final taskStatus = (share.taskStatus == 'done' || share.taskStatus == 'cancelled')
          ? share.taskStatus!
          : 'todo';

      final newTask = Task(
        id: clonedId,
        userId: uid,
        title: share.title,
        notes: share.notes,
        status: taskStatus,
        priority: share.priority ?? 0,
        tags: tagsString,
        dueDate: share.dueDate,
        dueTime: share.dueTime,
        estimateMin: share.estimateMin,
        recurrenceRule: share.recurrenceRule,
        recurrenceMode: share.recurrenceMode,
        isCollaborative: share.isCollaborative,
        shareId: share.id,
        senderId: share.senderId,
        senderUsername:
            cleanSenderUsername.isNotEmpty ? cleanSenderUsername : null,
      );
      await TaskRepository().addTask(newTask);

      updatedPreview.addAll({
        'sender_id': share.senderId,
        if (cleanSenderUsername.isNotEmpty) 'sender_name': cleanSenderUsername,
        'status': taskStatus,
        'tags': tagsString,
        'task_updated_at': nowUtc,
      });
    } else if (share.isHabit) {
      final rawKind = share.habitKind ?? '';
      final category =
          rawKind.toLowerCase() == 'boolean' ? '' : rawKind;
      final newHabit = Habit(
        id: clonedId,
        name: share.title,
        category: category,
        icon: share.habitIcon ?? 'fitness',
        color: share.habitColor ?? '#10B981',
        scheduleType: share.scheduleType ?? 'daily',
        remindTime: share.remindTime,
        targetValue: share.targetValue ?? 20,
        shareId: share.id,
        senderId: share.senderId,
        senderUsername:
            cleanSenderUsername.isNotEmpty ? cleanSenderUsername : null,
      );
      await HabitRepository().addHabit(newHabit);

      updatedPreview['sender_id'] = share.senderId;
      if (cleanSenderUsername.isNotEmpty) {
        updatedPreview['sender_name'] = cleanSenderUsername;
      }
    } else if (share.isNote) {
      final newNote = Note(
        id: clonedId,
        userId: uid,
        title: share.title,
        bodyMd: share.noteBody ?? '',
        category: (share.noteCategory != null && share.noteCategory!.isNotEmpty)
            ? share.noteCategory!
            : 'General',
        mood: share.mood,
        energy: share.energy,
        shareId: share.id,
        senderId: share.senderId,
        senderUsername:
            cleanSenderUsername.isNotEmpty ? cleanSenderUsername : null,
      );
      await NoteRepository().addNote(newNote);

      updatedPreview['sender_id'] = share.senderId;
      if (cleanSenderUsername.isNotEmpty) {
        updatedPreview['sender_name'] = cleanSenderUsername;
      }
    } else if (share.isProject) {
      await db.execute('''
        INSERT OR REPLACE INTO projects (
          id, user_id, name, color, created_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?
        )
      ''', [
        clonedId,
        uid,
        share.title,
        share.previewData['color'] ?? '#6366F1',
        nowUtc,
        nowUtc,
      ]);
    }

    final updatedPreviewJson = jsonEncode(updatedPreview);

    // 2. Mark share as accepted locally & record linked entity ID
    await db.execute('''
      UPDATE companion_shares
      SET status = 'accepted', accepted_entity_id = ?, preview_data = ?, updated_at = ?
      WHERE id = ?
    ''', [clonedId, updatedPreviewJson, nowUtc, share.id]);

    // 3. Online RPC synchronization (awaited with bounded timeout) with fallback direct upsert
    if (isRemoteAuthenticated) {
      bool rpcOk = false;
      try {
        await _supabaseClient?.rpc(
          'accept_companion_share',
          params: {
            'p_share_id': share.id,
            'p_cloned_id': clonedId,
          },
        ).timeout(const Duration(seconds: 4));
        rpcOk = true;
      } catch (e) {
        debugPrint('[CompanionShareRepository] accept_companion_share RPC notice: $e');
      }

      if (!rpcOk) {
        try {
          if (share.isTask) {
            await _supabaseClient?.from('tasks').upsert({
              'id': clonedId,
              'user_id': uid,
              'title': share.title,
              'notes': share.notes,
              'status': updatedPreview['status'] ?? 'todo',
              'priority': (share.priority ?? 0).clamp(0, 3),
              'project_id': null,
              'tags': updatedPreview['tags'],
              'due_date': (share.dueDate != null && share.dueDate!.trim().isNotEmpty)
                  ? share.dueDate
                  : null,
              'due_time': (share.dueTime != null && share.dueTime!.trim().isNotEmpty)
                  ? share.dueTime
                  : null,
              'estimate_min': share.estimateMin,
              'recurrence_rule': (share.recurrenceRule != null && share.recurrenceRule!.trim().isNotEmpty)
                  ? share.recurrenceRule
                  : null,
              'recurrence_mode': (share.recurrenceMode == 'fixed' || share.recurrenceMode == 'after_completion')
                  ? share.recurrenceMode
                  : 'fixed',
              'updated_at': nowUtc,
            });
          }
          await _supabaseClient
              ?.from('companion_shares')
              .update({
                'status': 'accepted',
                'accepted_entity_id': clonedId,
                'preview_data': updatedPreviewJson,
                'updated_at': nowUtc,
              })
              .eq('id', share.id);
        } catch (e) {
          debugPrint('[CompanionShareRepository] Fallback status update notice: $e');
        }
      }
    }

    return clonedId;
  }

  /// Propagates local collaborative task mutations to Supabase via SECURITY DEFINER RPC.
  Future<void> syncCollaborativeTaskUpdate(Task task) async {
    if (isSigningOut || !isRemoteAuthenticated || _supabaseClient == null) {
      return;
    }

    final cleanStatus =
        (task.status == 'done' || task.status == 'cancelled') ? task.status : 'todo';
    final cleanRecMode = (task.recurrenceMode == 'fixed' ||
            task.recurrenceMode == 'after_completion')
        ? task.recurrenceMode!
        : 'fixed';

    try {
      await _supabaseClient!.rpc(
        'sync_collaborative_task_rpc',
        params: {
          'p_task_id': task.id,
          'p_title': task.title,
          'p_notes': task.notes,
          'p_status': cleanStatus,
          'p_priority': (task.priority ?? 0).clamp(0, 3),
          'p_tags': task.tags,
          'p_due_date': (task.dueDate != null && task.dueDate!.trim().isNotEmpty)
              ? task.dueDate
              : null,
          'p_due_time': (task.dueTime != null && task.dueTime!.trim().isNotEmpty)
              ? task.dueTime
              : null,
          'p_estimate_min': task.estimateMin,
          'p_recurrence_rule': (task.recurrenceRule != null &&
                  task.recurrenceRule!.trim().isNotEmpty)
              ? task.recurrenceRule
              : null,
          'p_recurrence_mode': cleanRecMode,
        },
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[CompanionShareRepository] sync_collaborative_task_rpc notice: $e');
      if (task.shareId != null && task.shareId!.isNotEmpty) {
        try {
          final nowUtc = DateTime.now().toUtc().toIso8601String();
          await _supabaseClient!.from('companion_shares').update({
            'preview_data': jsonEncode({
              'sender_id': task.senderId,
              'sender_name': task.senderUsername,
              'title': task.title,
              'notes': task.notes,
              'status': cleanStatus,
              'priority': (task.priority ?? 0).clamp(0, 3),
              'tags': task.tags,
              'due_date': task.dueDate,
              'due_time': task.dueTime,
              'estimate_min': task.estimateMin,
              'recurrence_rule': task.recurrenceRule,
              'recurrence_mode': cleanRecMode,
              'task_updated_at': nowUtc,
            }),
            'updated_at': nowUtc,
          }).eq('id', task.shareId!);
        } catch (fallbackErr) {
          debugPrint('[CompanionShareRepository] Fallback collaborative share update notice: $fallbackErr');
        }
      }
    }
  }

  /// Declines an incoming share request and records decline notice metadata.
  Future<void> declineShare(String shareId) async {
    final cleanId = shareId.trim();
    if (cleanId.isEmpty) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic>? existingShare;

    if (isDatabaseInitialized) {
      try {
        existingShare = await db.getOptional('''
          SELECT sender_id, recipient_id, entity_type, entity_id, share_mode, preview_data
          FROM companion_shares
          WHERE id = ?
          LIMIT 1
        ''', [cleanId]);
      } catch (_) {}

      await db.execute('''
        UPDATE companion_shares
        SET status = 'declined', updated_at = ?
        WHERE id = ?
      ''', [nowUtc, cleanId]);

      if (!isRemoteAuthenticated && existingShare != null) {
        final senderId = existingShare['sender_id']?.toString() ?? '';
        final recipientId = existingShare['recipient_id']?.toString() ?? '';
        final entityType = existingShare['entity_type']?.toString() ?? 'task';
        final entityId = existingShare['entity_id']?.toString() ?? '';
        final shareMode = existingShare['share_mode']?.toString() ?? 'copy';
        Map<String, dynamic> previewMap = const {};
        try {
          final rawPrev = existingShare['preview_data'];
          if (rawPrev is String && rawPrev.trim().isNotEmpty) {
            final decoded = jsonDecode(rawPrev);
            if (decoded is Map) {
              previewMap = Map<String, dynamic>.from(decoded);
            }
          }
        } catch (_) {}

        final senderName = previewMap['sender_name']?.toString();
        if (entityType == 'task' && entityId.isNotEmpty) {
          try {
            final senderTask = await db.getOptional(
              "SELECT id, tags FROM tasks WHERE id = ? AND (deleted_at IS NULL OR deleted_at = '')",
              [entityId],
            );
            if (senderTask != null) {
              final cleanedTags = TaskRepository.removeSenderTag(
                senderTask['tags']?.toString(),
                senderName,
              );
              if (cleanedTags != senderTask['tags']?.toString()) {
                await db.execute(
                  'UPDATE tasks SET tags = ?, updated_at = ? WHERE id = ?',
                  [cleanedTags, nowUtc, entityId],
                );
              }
            }
          } catch (e) {
            debugPrint(
                '[CompanionShareRepository] declineShare local tag cleanup notice: $e');
          }
        }

        if (senderId.isNotEmpty) {
          await _ensureDeclinedActivityLogLocal(
            shareId: cleanId,
            senderId: senderId,
            recipientId: recipientId,
            entityType: entityType,
            entityId: entityId,
            shareMode: shareMode,
            itemTitle: previewMap['title']?.toString() ??
                previewMap['name']?.toString() ??
                'Shared item',
            createdAtUtc: nowUtc,
          );
        }
      }
    }

    if (isRemoteAuthenticated) {
      unawaited(() async {
        bool rpcOk = false;
        try {
          await _supabaseClient?.rpc(
            'decline_companion_share',
            params: {'p_share_id': cleanId},
          ).timeout(const Duration(seconds: 4));
          rpcOk = true;
        } catch (e) {
          debugPrint(
              '[CompanionShareRepository] decline_companion_share RPC notice: $e');
        }
        if (!rpcOk) {
          try {
            await _supabaseClient
                ?.from('companion_shares')
                .update({'status': 'declined', 'updated_at': nowUtc})
                .eq('id', cleanId);
          } catch (e) {
            debugPrint(
                '[CompanionShareRepository] declineShare remote notice: $e');
          }
        }
      }());
    }
  }

  Future<void> _ensureDeclinedActivityLogLocal({
    required String shareId,
    required String senderId,
    required String recipientId,
    required String entityType,
    required String entityId,
    required String shareMode,
    required String itemTitle,
    required String createdAtUtc,
  }) async {
    if (!isDatabaseInitialized || senderId.isEmpty) return;
    try {
      final detId = IdGenerator.generateDeterministicId('share_declined_$shareId');
      final existing = await db.getOptional('''
        SELECT id FROM friend_activity_logs
        WHERE user_id = ?
          AND (
            id = ?
            OR (
              event_type = 'shared_item_declined'
              AND json_extract(metadata, '\$.share_id') = ?
            )
          )
        LIMIT 1
      ''', [senderId, detId, shareId]);
      if (existing != null) return;

      var recipientName = 'Companion';
      if (recipientId.isNotEmpty) {
        final profRow = await db.getOptional(
          'SELECT name FROM user_profiles WHERE user_id = ? LIMIT 1',
          [recipientId],
        );
        final dbName = profRow?['name']?.toString().trim() ?? '';
        if (dbName.isNotEmpty && dbName != 'Companion') {
          recipientName = dbName;
        } else {
          final cached =
              FriendSearchRepository().inMemoryProfileCache[recipientId];
          final cachedName = cached?['name']?.toString().trim() ?? '';
          if (cachedName.isNotEmpty) {
            recipientName = cachedName;
          }
        }
      }

      final cleanTitle =
          itemTitle.trim().isNotEmpty ? itemTitle.trim() : 'Shared $entityType';
      final metaJson = jsonEncode({
        'share_id': shareId,
        'entity_type': entityType,
        'entity_id': entityId,
        'share_mode': shareMode,
        'recipient_id': recipientId,
        'recipient_name': recipientName,
        'sender_id': recipientId,
        'item_title': cleanTitle,
      });

      await db.execute('''
        INSERT OR IGNORE INTO friend_activity_logs (
          id, user_id, event_type, title, metadata, created_at
        ) VALUES (?, ?, 'shared_item_declined', ?, ?, ?)
      ''', [
        detId,
        senderId,
        '$recipientName declined "$cleanTitle"',
        metaJson,
        createdAtUtc,
      ]);
    } catch (e) {
      debugPrint(
          '[CompanionShareRepository] _ensureDeclinedActivityLogLocal notice: $e');
    }
  }

  Future<void> _ensureCollaborativeTaskDeletedActivityLogLocal({
    required String shareId,
    required String survivingPartnerUserId,
    required String actorUserId,
    required String? actorNameOverride,
    required String senderId,
    required String recipientId,
    required String entityId,
    required String itemTitle,
    required String createdAtUtc,
  }) async {
    if (!isDatabaseInitialized || survivingPartnerUserId.isEmpty) return;
    final uid = currentUserId;
    if (isRemoteAuthenticated &&
        uid.isNotEmpty &&
        survivingPartnerUserId != uid) {
      return;
    }

    try {
      final detId = IdGenerator.generateDeterministicId('collab_deleted_$shareId');
      final existing = await db.getOptional('''
        SELECT id FROM friend_activity_logs
        WHERE user_id = ?
          AND (
            id = ?
            OR (
              event_type = 'collaborative_task_deleted'
              AND json_extract(metadata, '\$.share_id') = ?
            )
          )
        LIMIT 1
      ''', [survivingPartnerUserId, detId, shareId]);
      if (existing != null) return;

      var actorName = actorNameOverride?.trim() ?? '';
      if (actorName == 'Companion' || actorName == 'A companion') {
        actorName = '';
      }
      if (actorName.isEmpty && actorUserId.isNotEmpty) {
        final profRow = await db.getOptional(
          'SELECT name FROM user_profiles WHERE user_id = ? LIMIT 1',
          [actorUserId],
        );
        final dbName = profRow?['name']?.toString().trim() ?? '';
        if (dbName.isNotEmpty &&
            dbName != 'Companion' &&
            dbName != 'A companion') {
          actorName = dbName;
        } else {
          final cached =
              FriendSearchRepository().inMemoryProfileCache[actorUserId];
          final cachedName = cached?['name']?.toString().trim() ?? '';
          if (cachedName.isNotEmpty) {
            actorName = cachedName;
          }
        }
      }
      if (actorName.isEmpty) actorName = 'Companion';

      final cleanTitle =
          itemTitle.trim().isNotEmpty ? itemTitle.trim() : 'Shared Task';
      final metaJson = jsonEncode({
        'actor_user_id': actorUserId,
        'actor_username': actorName,
        'sender_user_id': senderId,
        'recipient_user_id': recipientId,
        'share_id': shareId,
        'entity_type': 'task',
        'entity_id': entityId,
        'share_mode': 'collaborate',
        'item_title': cleanTitle,
        'status': 'cancelled',
        'cancellation_reason': 'collaborative_task_deleted',
        'sender_id': actorUserId,
      });

      await db.execute('''
        INSERT OR IGNORE INTO friend_activity_logs (
          id, user_id, event_type, title, metadata, created_at
        ) VALUES (?, ?, 'collaborative_task_deleted', ?, ?, ?)
      ''', [
        detId,
        survivingPartnerUserId,
        '$actorName deleted collaborative task: $cleanTitle',
        metaJson,
        createdAtUtc,
      ]);
    } catch (e) {
      debugPrint(
          '[CompanionShareRepository] _ensureCollaborativeTaskDeletedActivityLogLocal notice: $e');
    }
  }

  /// Cancels an outgoing share request sent by current user.
  Future<void> cancelShare(String shareId) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    if (isDatabaseInitialized) {
      await db.execute('''
        UPDATE companion_shares
        SET status = 'cancelled', updated_at = ?
        WHERE id = ?
      ''', [nowUtc, shareId]);
    }

    if (isRemoteAuthenticated) {
      unawaited(() async {
        try {
          await _supabaseClient
              ?.from('companion_shares')
              .update({'status': 'cancelled', 'updated_at': nowUtc})
              .eq('id', shareId);
        } catch (e) {
          debugPrint('[CompanionShareRepository] cancelShare remote notice: $e');
        }
      }());
    }
  }

  /// Cancels active task shares linked to [taskId] when the task is soft-deleted locally.
  ///
  /// When deleting a collaborative task, preserves the companion's task in normal tasks
  /// (stripping sender/collaboration tags without deleting it) and notifies the companion.
  Future<void> cancelSharesForTask(String taskId) async {
    final cleanId = taskId.trim();
    if (cleanId.isEmpty) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final uid = currentUserId;
    final actorName = await _resolveAuthoritativeSenderName();
    final fallbackUpdates = <String, String>{};

    if (isDatabaseInitialized) {
      try {
        final rows = await db.getAll('''
          SELECT id, sender_id, recipient_id, entity_id, accepted_entity_id,
                 share_mode, status, preview_data
          FROM companion_shares
          WHERE entity_type = 'task'
            AND status IN ('pending', 'accepted')
            AND (entity_id = ? OR accepted_entity_id = ?)
        ''', [cleanId, cleanId]);

        for (final row in rows) {
          final id = row['id']?.toString() ?? '';
          final senderId = row['sender_id']?.toString() ?? '';
          final recipientId = row['recipient_id']?.toString() ?? '';
          final entityId = row['entity_id']?.toString() ?? '';
          final acceptedId = row['accepted_entity_id']?.toString() ?? '';
          final shareMode = row['share_mode']?.toString() ?? 'copy';
          final prevStatus = row['status']?.toString() ?? 'pending';
          if (id.isEmpty) continue;

          // Keep already-accepted copy shares untouched so independent copy attribution remains
          if (shareMode == 'copy' &&
              prevStatus == 'accepted' &&
              acceptedId.isNotEmpty) {
            continue;
          }

          final previewMap = <String, dynamic>{};
          try {
            final rawPrev = row['preview_data'];
            if (rawPrev is String && rawPrev.trim().isNotEmpty) {
              final decoded = jsonDecode(rawPrev);
              if (decoded is Map) {
                previewMap.addAll(Map<String, dynamic>.from(decoded));
              }
            }
          } catch (_) {}

          final actorId = uid.isNotEmpty
              ? uid
              : (entityId == cleanId ? senderId : recipientId);
          final survivingPartnerUserId = (actorId == senderId)
              ? recipientId
              : (actorId == recipientId
                  ? senderId
                  : (entityId == cleanId ? recipientId : senderId));
          final partnerTaskId = entityId == cleanId ? acceptedId : entityId;

          if (shareMode == 'collaborate') {
            previewMap['cancelled_by'] = actorId;
            previewMap['cancelled_by_name'] = actorName;
            previewMap['cancellation_reason'] = 'collaborative_task_deleted';
            previewMap['cancelled_at'] = nowUtc;
          } else {
            previewMap['cancelled_by'] = actorId;
            previewMap['cancelled_by_name'] = actorName;
            previewMap['cancellation_reason'] = 'task_deleted';
            previewMap['cancelled_at'] = nowUtc;
          }

          final updatedPreviewJson = jsonEncode(previewMap);
          fallbackUpdates[id] = updatedPreviewJson;

          await db.execute('''
            UPDATE companion_shares
            SET status = 'cancelled', preview_data = ?, updated_at = ?
            WHERE id = ?
          ''', [updatedPreviewJson, nowUtc, id]);

          if (partnerTaskId.isNotEmpty &&
              (shareMode == 'collaborate' || partnerTaskId == entityId)) {
            final partnerTask = await db.getOptional(
              "SELECT id, user_id, tags FROM tasks WHERE id = ? AND (deleted_at IS NULL OR deleted_at = '')",
              [partnerTaskId],
            );
            if (partnerTask != null) {
              final partnerOwner = partnerTask['user_id']?.toString() ?? '';
              final canEditLocal = !isRemoteAuthenticated ||
                  uid.isEmpty ||
                  partnerOwner.isEmpty ||
                  partnerOwner == uid;
              if (canEditLocal) {
                final cleanedTags = TaskRepository.removeSenderTag(
                  partnerTask['tags']?.toString(),
                  previewMap['sender_name']?.toString(),
                );
                if (cleanedTags != partnerTask['tags']?.toString()) {
                  await db.execute(
                    'UPDATE tasks SET tags = ?, updated_at = ? WHERE id = ?',
                    [cleanedTags, nowUtc, partnerTaskId],
                  );
                }
              }
            }
          }

          if (shareMode == 'collaborate' &&
              (prevStatus == 'accepted' || acceptedId.isNotEmpty) &&
              survivingPartnerUserId.isNotEmpty) {
            final localTitleRow = await db.getOptional(
              'SELECT title FROM tasks WHERE id = ? LIMIT 1',
              [cleanId],
            );
            final itemTitle = previewMap['title']?.toString().trim().isNotEmpty ==
                    true
                ? previewMap['title'].toString().trim()
                : (localTitleRow?['title']?.toString() ?? 'Shared Task');
            await _ensureCollaborativeTaskDeletedActivityLogLocal(
              shareId: id,
              survivingPartnerUserId: survivingPartnerUserId,
              actorUserId: actorId,
              actorNameOverride: actorName,
              senderId: senderId,
              recipientId: recipientId,
              entityId:
                  partnerTaskId.isNotEmpty ? partnerTaskId : entityId,
              itemTitle: itemTitle,
              createdAtUtc: nowUtc,
            );
          }
        }
      } catch (e) {
        debugPrint(
            '[CompanionShareRepository] cancelSharesForTask local notice: $e');
      }
    }

    if (isRemoteAuthenticated && _supabaseClient != null) {
      unawaited(() async {
        bool rpcOk = false;
        try {
          await _supabaseClient!.rpc(
            'cancel_collaborative_share_on_task_delete',
            params: {'p_task_id': cleanId},
          ).timeout(const Duration(seconds: 4));
          rpcOk = true;
        } catch (e) {
          debugPrint(
              '[CompanionShareRepository] cancel_collaborative_share_on_task_delete RPC notice: $e');
        }

        if (!rpcOk) {
          try {
            if (fallbackUpdates.isEmpty) {
              final remoteRows = await _supabaseClient!
                  .from('companion_shares')
                  .select(
                      'id, sender_id, recipient_id, entity_id, accepted_entity_id, share_mode, status, preview_data')
                  .eq('entity_type', 'task')
                  .or('entity_id.eq.$cleanId,accepted_entity_id.eq.$cleanId');
              for (final row
                  in List<Map<String, dynamic>>.from(remoteRows as List)) {
                final status = row['status']?.toString() ?? '';
                final shareMode = row['share_mode']?.toString() ?? 'copy';
                final acceptedId =
                    row['accepted_entity_id']?.toString() ?? '';
                final id = row['id']?.toString() ?? '';
                if (id.isEmpty ||
                    (status != 'pending' && status != 'accepted') ||
                    (shareMode == 'copy' &&
                        status == 'accepted' &&
                        acceptedId.isNotEmpty)) {
                  continue;
                }
                final prev = <String, dynamic>{};
                try {
                  final raw = row['preview_data'];
                  if (raw is String && raw.trim().isNotEmpty) {
                    final dec = jsonDecode(raw);
                    if (dec is Map) {
                      prev.addAll(Map<String, dynamic>.from(dec));
                    }
                  } else if (raw is Map) {
                    prev.addAll(Map<String, dynamic>.from(raw));
                  }
                } catch (_) {}
                prev['cancelled_by'] = uid;
                prev['cancelled_by_name'] = actorName;
                prev['cancellation_reason'] = shareMode == 'collaborate'
                    ? 'collaborative_task_deleted'
                    : 'task_deleted';
                prev['cancelled_at'] = nowUtc;
                fallbackUpdates[id] = jsonEncode(prev);
              }
            }

            for (final entry in fallbackUpdates.entries) {
              await _supabaseClient!
                  .from('companion_shares')
                  .update({
                    'status': 'cancelled',
                    'preview_data': entry.value,
                    'updated_at': nowUtc,
                  })
                  .eq('id', entry.key);
            }
          } catch (e) {
            debugPrint(
                '[CompanionShareRepository] cancelSharesForTask remote notice: $e');
          }
        }
      }());
    }
  }

  DateTime? _parseUtc(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  bool _jsonValuesEqual(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_jsonValuesEqual(a[key], b[key])) {
          return false;
        }
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (int i = 0; i < a.length; i++) {
        if (!_jsonValuesEqual(a[i], b[i])) return false;
      }
      return true;
    }
    return false;
  }

  bool _previewEquals(dynamic rawExisting, Map<String, dynamic> targetMap) {
    if (rawExisting == null) return targetMap.isEmpty;
    try {
      final decoded = rawExisting is String
          ? (rawExisting.trim().isEmpty ? <String, dynamic>{} : jsonDecode(rawExisting))
          : rawExisting;
      if (decoded is Map) {
        return _jsonValuesEqual(decoded, targetMap);
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Pulls incoming and outgoing companion shares directly from Supabase into local SQLite.
  Future<void> syncSharesFromRemote() async {
    if (isSigningOut) return;
    final client = _supabaseClient;
    final uid = currentUserId;
    if (!isRemoteAuthenticated ||
        client == null ||
        uid.isEmpty ||
        !isDatabaseInitialized) {
      return;
    }

    try {
      final res = await client
          .from('companion_shares')
          .select('*')
          .or('sender_id.eq.$uid,recipient_id.eq.$uid');

      if (isSigningOut) return;

      final rows = List<Map<String, dynamic>>.from(res as List);
      final counterpartIds = <String>{};
      final declinedForUserA = <Map<String, String>>[];
      final collabDeletedForMe = <Map<String, String>>[];

      for (final row in rows) {
        if (isSigningOut) return;
        final id = row['id']?.toString() ?? '';
        final senderId = row['sender_id']?.toString() ?? '';
        final recipientId = row['recipient_id']?.toString() ?? '';
        if (id.isEmpty || senderId.isEmpty || recipientId.isEmpty) continue;

        final entityType = row['entity_type']?.toString() ?? 'task';
        final entityId = row['entity_id']?.toString() ?? '';
        final shareMode = row['share_mode']?.toString() ?? 'copy';
        final status = row['status']?.toString() ?? 'pending';
        final rawPreview = row['preview_data'];
        Map<String, dynamic> previewMap = {};
        if (rawPreview is Map) {
          previewMap = Map<String, dynamic>.from(rawPreview);
        } else if (rawPreview is String && rawPreview.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(rawPreview);
            if (decoded is Map) {
              previewMap = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
        final acceptedEntityId = row['accepted_entity_id']?.toString();
        final createdAt = row['created_at']?.toString() ??
            DateTime.now().toUtc().toIso8601String();
        final updatedAt = row['updated_at']?.toString() ?? createdAt;

        final existing = await db.getOptional(
          'SELECT id, status, accepted_entity_id, preview_data, updated_at FROM companion_shares WHERE id = ?',
          [id],
        );

        // Preserve local notice dismissal if remote hasn't received it yet
        if ((status == 'declined' || status == 'cancelled') &&
            existing != null) {
          try {
            final prevStr = existing['preview_data']?.toString() ?? '';
            if (prevStr.isNotEmpty) {
              final existingPreview = jsonDecode(prevStr);
              if (existingPreview is Map &&
                  (existingPreview['declined_notice_dismissed'] == true ||
                      existingPreview['declined_notice_dismissed'] == 'true')) {
                previewMap['declined_notice_dismissed'] = true;
                if (existingPreview['declined_notice_dismissed_at'] != null) {
                  previewMap['declined_notice_dismissed_at'] =
                      existingPreview['declined_notice_dismissed_at'];
                }
              }
            }
          } catch (_) {}
        }

        final previewJson = jsonEncode(previewMap);
        final remoteUpdated = _parseUtc(updatedAt);
        final normalizedRemoteUpdatedAt =
            remoteUpdated?.toIso8601String() ?? updatedAt;
        var effectiveStatus = status;

        if (existing != null) {
          final localStatus = existing['status']?.toString() ?? '';
          final localUpdated = _parseUtc(existing['updated_at']?.toString());
          final isLocalStrictlyNewer = localUpdated != null &&
              remoteUpdated != null &&
              localUpdated.isAfter(
                remoteUpdated.add(const Duration(milliseconds: 500)),
              );
          final isLocalTerminalOverRemote =
              (localStatus == 'cancelled' || localStatus == 'declined') &&
                  (status == 'pending' || status == 'accepted') &&
                  localUpdated != null &&
                  (remoteUpdated == null || !remoteUpdated.isAfter(localUpdated));

          if (isLocalStrictlyNewer || isLocalTerminalOverRemote) {
            effectiveStatus = localStatus.isNotEmpty ? localStatus : status;
            if (localStatus != status && isRemoteAuthenticated) {
              final pushUpdatedAt =
                  existing['updated_at']?.toString() ?? normalizedRemoteUpdatedAt;
              unawaited(() async {
                try {
                  await client.from('companion_shares').update({
                    'status': localStatus,
                    'updated_at': pushUpdatedAt,
                  }).eq('id', id);
                } catch (_) {}
              }());
            }
          } else {
            final timestampChanged =
                (localUpdated == null || remoteUpdated == null)
                    ? existing['updated_at'] != updatedAt
                    : localUpdated
                            .difference(remoteUpdated)
                            .inMilliseconds
                            .abs() >
                        500;
            final acceptedChanged =
                (existing['accepted_entity_id']?.toString() ?? '') !=
                    (acceptedEntityId ?? '');
            final previewChanged =
                !_previewEquals(existing['preview_data'], previewMap);

            if (localStatus != status ||
                acceptedChanged ||
                previewChanged ||
                timestampChanged) {
              await db.execute('''
                UPDATE companion_shares
                SET status = ?, accepted_entity_id = ?, preview_data = ?, updated_at = ?
                WHERE id = ?
              ''', [
                status,
                acceptedEntityId,
                previewJson,
                normalizedRemoteUpdatedAt,
                id,
              ]);
            }
          }
        } else {
          final normalizedCreatedAt =
              _parseUtc(createdAt)?.toIso8601String() ?? createdAt;
          await db.execute('''
            INSERT INTO companion_shares (
              id, sender_id, recipient_id, entity_type, entity_id,
              share_mode, status, preview_data, accepted_entity_id, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            id,
            senderId,
            recipientId,
            entityType,
            entityId,
            shareMode,
            status,
            previewJson,
            acceptedEntityId,
            normalizedCreatedAt,
            normalizedRemoteUpdatedAt,
          ]);
        }

        // Propagate newer collaborative task snapshot from companion_shares.preview_data
        // to the current user's local task row so both User A and User B stay in sync.
        if (entityType == 'task' &&
            shareMode == 'collaborate' &&
            effectiveStatus == 'accepted') {
          final myTaskId = (senderId == uid) ? entityId : acceptedEntityId;
          if (myTaskId != null &&
              myTaskId.isNotEmpty &&
              previewMap.isNotEmpty) {
            final localTask = await db.getOptional(
              "SELECT id, updated_at, tags FROM tasks WHERE id = ? AND (deleted_at IS NULL OR deleted_at = '')",
              [myTaskId],
            );
            final previewUpdated = DateTime.tryParse(
              previewMap['task_updated_at']?.toString() ?? '',
            )?.toUtc();
            final senderName = previewMap['sender_name']?.toString();
            final baseTags =
                previewMap['tags']?.toString() ?? localTask?['tags']?.toString();
            final targetTags = (senderId == uid)
                ? TaskRepository.removeSenderTag(baseTags, senderName)
                : TaskRepository.mergeSenderTag(baseTags, senderName);

            if (localTask != null && previewUpdated != null) {
              final localUpdated = DateTime.tryParse(
                localTask['updated_at']?.toString() ?? '',
              )?.toUtc();
              if (localUpdated == null || previewUpdated.isAfter(localUpdated)) {
                await db.execute('''
                  UPDATE tasks SET
                    title = COALESCE(?, title),
                    notes = ?,
                    status = COALESCE(?, status),
                    priority = COALESCE(?, priority),
                    tags = ?,
                    due_date = ?,
                    due_time = ?,
                    estimate_min = ?,
                    recurrence_rule = ?,
                    recurrence_mode = COALESCE(?, recurrence_mode),
                    updated_at = ?
                  WHERE id = ?
                ''', [
                  previewMap['title']?.toString(),
                  previewMap.containsKey('notes')
                      ? previewMap['notes']?.toString()
                      : null,
                  previewMap['status']?.toString(),
                  previewMap['priority'] is num
                      ? (previewMap['priority'] as num).toInt()
                      : null,
                  targetTags,
                  previewMap.containsKey('due_date')
                      ? previewMap['due_date']?.toString()
                      : null,
                  previewMap.containsKey('due_time')
                      ? previewMap['due_time']?.toString()
                      : null,
                  previewMap['estimate_min'] is num
                      ? (previewMap['estimate_min'] as num).toInt()
                      : null,
                  previewMap.containsKey('recurrence_rule')
                      ? previewMap['recurrence_rule']?.toString()
                      : null,
                  previewMap['recurrence_mode']?.toString(),
                  previewUpdated.toIso8601String(),
                  myTaskId,
                ]);
              }
            }
          }
        }

        // Strip leftover sender attribution tags when a collaborative task share is
        // declined or cancelled (or from sender's own task on decline/cancel),
        // without stripping copy-share tags from an accepted copy on recipient's side.
        if (entityType == 'task' &&
            (effectiveStatus == 'declined' || effectiveStatus == 'cancelled') &&
            (shareMode == 'collaborate' || senderId == uid)) {
          final myTaskId = (senderId == uid) ? entityId : acceptedEntityId;
          if (myTaskId != null && myTaskId.isNotEmpty) {
            final localTask = await db.getOptional(
              "SELECT id, tags FROM tasks WHERE id = ? AND (deleted_at IS NULL OR deleted_at = '')",
              [myTaskId],
            );
            if (localTask != null) {
              final cleanedTags = TaskRepository.removeSenderTag(
                localTask['tags']?.toString(),
                previewMap['sender_name']?.toString(),
              );
              if (cleanedTags != localTask['tags']?.toString()) {
                await db.execute(
                  'UPDATE tasks SET tags = ?, updated_at = ? WHERE id = ?',
                  [
                    cleanedTags,
                    DateTime.now().toUtc().toIso8601String(),
                    myTaskId,
                  ],
                );
              }
            }
          }
        }

        if (entityType == 'task' &&
            shareMode == 'collaborate' &&
            effectiveStatus == 'cancelled' &&
            acceptedEntityId != null &&
            acceptedEntityId.isNotEmpty) {
          final cancelledBy =
              previewMap['cancelled_by']?.toString().trim() ?? '';
          final reason =
              previewMap['cancellation_reason']?.toString().trim() ?? '';
          final isPartnerDeleted = (cancelledBy.isNotEmpty && cancelledBy != uid) ||
              (cancelledBy.isEmpty &&
                  reason == 'collaborative_task_deleted' &&
                  senderId == uid);
          if (isPartnerDeleted) {
            final actorUid = cancelledBy.isNotEmpty
                ? cancelledBy
                : (senderId == uid ? recipientId : senderId);
            collabDeletedForMe.add({
              'id': id,
              'surviving_partner_uid': uid,
              'actor_user_id': actorUid,
              'actor_name':
                  previewMap['cancelled_by_name']?.toString() ?? '',
              'sender_id': senderId,
              'recipient_id': recipientId,
              'entity_id':
                  (senderId == uid) ? entityId : acceptedEntityId,
              'title': previewMap['title']?.toString() ??
                  previewMap['name']?.toString() ??
                  'Shared Task',
              'updated_at': updatedAt,
            });
          }
        }

        if (senderId == uid && effectiveStatus == 'declined') {
          declinedForUserA.add({
            'id': id,
            'sender_id': senderId,
            'recipient_id': recipientId,
            'entity_type': entityType,
            'entity_id': entityId,
            'share_mode': shareMode,
            'title': previewMap['title']?.toString() ??
                previewMap['name']?.toString() ??
                'Shared $entityType',
            'updated_at': updatedAt,
          });
        }

        if (senderId != uid) counterpartIds.add(senderId);
        if (recipientId != uid) counterpartIds.add(recipientId);
      }

      for (final otherUid in counterpartIds) {
        if (isSigningOut) return;
        await FriendSearchRepository().syncSingleProfileFromRemote(otherUid);
      }

      for (final declined in declinedForUserA) {
        if (isSigningOut) return;
        await _ensureDeclinedActivityLogLocal(
          shareId: declined['id'] ?? '',
          senderId: declined['sender_id'] ?? '',
          recipientId: declined['recipient_id'] ?? '',
          entityType: declined['entity_type'] ?? 'task',
          entityId: declined['entity_id'] ?? '',
          shareMode: declined['share_mode'] ?? 'copy',
          itemTitle: declined['title'] ?? 'Shared item',
          createdAtUtc: declined['updated_at'] ??
              DateTime.now().toUtc().toIso8601String(),
        );
      }

      for (final deletedNotice in collabDeletedForMe) {
        if (isSigningOut) return;
        await _ensureCollaborativeTaskDeletedActivityLogLocal(
          shareId: deletedNotice['id'] ?? '',
          survivingPartnerUserId:
              deletedNotice['surviving_partner_uid'] ?? uid,
          actorUserId: deletedNotice['actor_user_id'] ?? '',
          actorNameOverride: deletedNotice['actor_name'],
          senderId: deletedNotice['sender_id'] ?? '',
          recipientId: deletedNotice['recipient_id'] ?? '',
          entityId: deletedNotice['entity_id'] ?? '',
          itemTitle: deletedNotice['title'] ?? 'Shared Task',
          createdAtUtc: deletedNotice['updated_at'] ??
              DateTime.now().toUtc().toIso8601String(),
        );
      }

      await deduplicateSharedEntities();
    } catch (e) {
      debugPrint('[CompanionShareRepository] syncSharesFromRemote notice: $e');
    }
  }

  /// Cleans up local duplicate companion_shares and orphaned duplicate cloned items.
  Future<void> deduplicateSharedEntities() async {
    if (!isDatabaseInitialized) return;
    final uid = currentUserId;
    if (uid.isEmpty) return;

    try {
      final shareRows = await db.getAll('''
        SELECT id, sender_id, recipient_id, entity_type, entity_id,
               share_mode, status, accepted_entity_id, updated_at, created_at
        FROM companion_shares
        ORDER BY
          CASE
            WHEN status = 'accepted' THEN 0
            WHEN status = 'pending' THEN 1
            ELSE 2
          END,
          CASE WHEN share_mode = 'collaborate' THEN 0 ELSE 1 END,
          updated_at DESC,
          created_at DESC,
          id DESC
      ''');

      final seenKeys = <String>{};
      final keptAcceptedIds = <String>{};
      final dupShareIds = <String>[];
      final dupTaskIds = <String>{};
      final dupHabitIds = <String>{};
      final dupNoteIds = <String>{};
      final dupProjectIds = <String>{};

      for (final row in shareRows) {
        final shareId = row['id']?.toString() ?? '';
        final senderId = row['sender_id']?.toString() ?? '';
        final recipientId = row['recipient_id']?.toString() ?? '';
        final entityType = row['entity_type']?.toString() ?? '';
        final entityId = row['entity_id']?.toString() ?? '';
        final acceptedId = row['accepted_entity_id']?.toString() ?? '';
        if (shareId.isEmpty) continue;

        final key = '$senderId|$recipientId|$entityType|$entityId';
        if (seenKeys.add(key)) {
          if (acceptedId.isNotEmpty) keptAcceptedIds.add(acceptedId);
        } else {
          dupShareIds.add(shareId);
          if (acceptedId.isNotEmpty) {
            if (entityType == 'task') dupTaskIds.add(acceptedId);
            if (entityType == 'habit') dupHabitIds.add(acceptedId);
            if (entityType == 'note') dupNoteIds.add(acceptedId);
            if (entityType == 'project') dupProjectIds.add(acceptedId);
          }
        }
      }

      for (final shareId in dupShareIds) {
        await db.execute('DELETE FROM companion_shares WHERE id = ?', [shareId]);
      }

      Future<void> deleteDupRows(String table, Set<String> candidateIds) async {
        for (final id in candidateIds) {
          if (keptAcceptedIds.contains(id)) continue;
          await db.execute('DELETE FROM $table WHERE id = ?', [id]);
        }
      }

      await deleteDupRows('tasks', dupTaskIds);
      await deleteDupRows('habits', dupHabitIds);
      await deleteDupRows('notes', dupNoteIds);
      await deleteDupRows('projects', dupProjectIds);

      // Cancel accepted collaborative shares whose local source or cloned task was soft-deleted
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      const orphanedWhere = '''
        entity_type = 'task'
          AND share_mode = 'collaborate'
          AND status = 'accepted'
          AND (
            EXISTS (
              SELECT 1 FROM tasks t
              WHERE t.id = companion_shares.entity_id
                AND t.deleted_at IS NOT NULL AND t.deleted_at != ''
            )
            OR (
              accepted_entity_id IS NOT NULL AND accepted_entity_id != ''
              AND EXISTS (
                SELECT 1 FROM tasks t
                WHERE t.id = companion_shares.accepted_entity_id
                  AND t.deleted_at IS NOT NULL AND t.deleted_at != ''
              )
            )
          )
      ''';
      final orphanedAcceptedShares = await db.getAll('''
        SELECT id FROM companion_shares WHERE $orphanedWhere
      ''');
      if (orphanedAcceptedShares.isNotEmpty) {
        await db.execute('''
          UPDATE companion_shares
          SET status = 'cancelled', updated_at = ?
          WHERE $orphanedWhere
        ''', [nowUtc]);
        if (isRemoteAuthenticated && _supabaseClient != null) {
          for (final shareRow in orphanedAcceptedShares) {
            final rowId = shareRow['id']?.toString() ?? '';
            if (rowId.isEmpty) continue;
            try {
              await _supabaseClient!
                  .from('companion_shares')
                  .update({'status': 'cancelled', 'updated_at': nowUtc})
                  .eq('id', rowId);
            } catch (e) {
              debugPrint(
                '[CompanionShareRepository] Push cancelled share $rowId notice: $e',
              );
            }
          }
        }
      }

      // Remove duplicate local task clones sharing identical normalized title/due_date/status
      final localTasks = await db.getAll('''
        SELECT t.id, t.user_id, t.title, COALESCE(t.due_date, '') AS due_date, t.status,
               EXISTS (
                 SELECT 1 FROM companion_shares cs
                 WHERE cs.status IN ('pending', 'accepted')
                   AND (cs.entity_id = t.id OR cs.accepted_entity_id = t.id)
               ) AS is_linked_share
        FROM tasks t
        WHERE t.user_id = ? AND (t.deleted_at IS NULL OR t.deleted_at = '')
        ORDER BY is_linked_share DESC, t.updated_at DESC, t.created_at DESC, t.id DESC
      ''', [uid]);

      final seenTaskKeys = <String>{};
      for (final row in localTasks) {
        final id = row['id']?.toString() ?? '';
        final title = (row['title']?.toString() ?? '').trim().toLowerCase();
        final dueDate = row['due_date']?.toString() ?? '';
        final status = row['status']?.toString() ?? 'todo';
        final isLinked = ((row['is_linked_share'] as num?)?.toInt() ?? 0) == 1;
        if (id.isEmpty || title.isEmpty) continue;

        final key = '$uid|$title|$dueDate|$status';
        if (!seenTaskKeys.add(key) && !isLinked) {
          await db.execute(
            'UPDATE tasks SET deleted_at = ?, updated_at = ? WHERE id = ?',
            [nowUtc, nowUtc, id],
          );
        }
      }
    } catch (e) {
      debugPrint('[CompanionShareRepository] deduplicateSharedEntities notice: $e');
    }
  }

  Future<void> _logShareSentActivity({
    required String recipientId,
    required String shareId,
    required String entityType,
    required String shareMode,
    required String itemTitle,
  }) async {
    try {
      final uid = currentUserId;
      final client = _supabaseClient;
      if (uid.isEmpty || client == null) return;

      final actId = IdGenerator.generateDeterministicId(
        'share_act_${DateTime.now().microsecondsSinceEpoch}_$recipientId',
      );
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final senderName = _resolveSenderDisplayName();
      final meta = <String, dynamic>{
        'share_id': shareId,
        'entity_type': entityType,
        'share_mode': shareMode,
        'title': itemTitle,
        'sender_id': uid,
        'recipient_id': recipientId,
      };

      await client.from('friend_activity_logs').insert({
        'id': actId,
        'user_id': recipientId,
        'event_type': 'shared_item_sent',
        'title': '$senderName shared a $entityType with you: $itemTitle',
        'metadata': meta,
        'created_at': nowUtc,
      });
    } catch (e) {
      debugPrint('[CompanionShareRepository] _logShareSentActivity notice: $e');
    }
  }
}
