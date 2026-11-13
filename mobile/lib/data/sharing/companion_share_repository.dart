import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/task_repository.dart';
import 'companion_share_models.dart';

export 'companion_share_models.dart';

/// Centralized repository for sharing tasks, habits, notes, and projects between companions.
class CompanionShareRepository {
  static final CompanionShareRepository _instance = CompanionShareRepository._internal();
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
    final client = _supabaseClient;
    if (client == null) return false;
    final session = client.auth.currentSession;
    return session != null && !session.isExpired;
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

    return db.watch(query, parameters: [uid]).map((rows) {
      return rows.map((r) => CompanionShare.fromRow(r)).toList();
    });
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
        COALESCE(p.avatar_color, '#6366F1') AS sender_avatar_color
      FROM companion_shares s
      LEFT JOIN user_profiles p ON p.user_id = s.recipient_id
      WHERE s.sender_id = ?
      ORDER BY s.created_at DESC
    ''';

    return db.watch(query, parameters: [uid]).map((rows) {
      return rows.map((r) => CompanionShare.fromRow(r)).toList();
    });
  }

  /// Sends a Task to a companion with full offline-first snapshot cloning support.
  Future<CompanionShare> shareTask({
    required Task task,
    required String recipientId,
    String shareMode = 'copy',
  }) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw StateError('User must be signed in to share tasks with companions.');

    final preview = <String, dynamic>{
      'title': task.title,
      'notes': task.notes,
      'priority': task.priority,
      'tags': task.tags,
      'due_date': task.dueDate,
      'due_time': task.dueTime,
      'estimate_min': task.estimateMin,
      'recurrence_rule': task.recurrenceRule,
      'recurrence_mode': task.recurrenceMode,
    };

    final shareId = IdGenerator.generateDeterministicId(
      'share_${DateTime.now().millisecondsSinceEpoch}_${task.id}',
    );
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    await db.execute('''
      INSERT INTO companion_shares (
        id, sender_id, recipient_id, entity_type, entity_id,
        share_mode, status, preview_data, created_at, updated_at
      ) VALUES (
        ?, ?, ?, 'task', ?, ?, 'pending', ?, ?, ?
      )
    ''', [
      shareId,
      uid,
      recipientId,
      task.id,
      shareMode,
      jsonEncode(preview),
      nowUtc,
      nowUtc,
    ]);

    final share = CompanionShare(
      id: shareId,
      senderId: uid,
      recipientId: recipientId,
      entityType: 'task',
      entityId: task.id,
      shareMode: shareMode,
      status: 'pending',
      previewData: preview,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // If online, also log friend activity
    if (isRemoteAuthenticated) {
      unawaited(_logShareSentActivity(recipientId, 'task', task.title));
    }

    return share;
  }

  /// Accepts a shared item, performs instant local cloning, and marks the share as accepted.
  Future<String> acceptShare(CompanionShare share) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw StateError('User must be signed in to accept shared items.');

    String clonedId = IdGenerator.generateDeterministicId(
      'cloned_${DateTime.now().millisecondsSinceEpoch}_${share.id}',
    );
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    // 1. Instant Local Cloning into recipient's private records
    if (share.isTask) {
      final tagsString = share.tags.isNotEmpty ? share.tags.join(',') : null;
      final newTask = Task(
        id: clonedId,
        userId: uid,
        title: share.title,
        notes: share.notes,
        status: 'todo',
        priority: share.priority,
        tags: tagsString,
        dueDate: share.dueDate,
        dueTime: share.dueTime,
        estimateMin: share.estimateMin,
        recurrenceRule: share.recurrenceRule,
      );
      await TaskRepository().addTask(newTask);
    } else if (share.isHabit) {
      await db.execute('''
        INSERT INTO habits (
          id, user_id, name, icon, color, kind, target_value, unit,
          schedule_type, remind_time, sort_order, is_enabled, created_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?
        )
      ''', [
        clonedId,
        uid,
        share.title,
        share.previewData['icon'] ?? 'check_circle',
        share.previewData['color'] ?? '#10B981',
        share.previewData['kind'] ?? 'Daily plan',
        share.previewData['target_value'] ?? 1,
        share.previewData['unit'] ?? 'times',
        share.previewData['schedule_type'] ?? 'daily',
        share.previewData['remind_time'],
        99,
        nowUtc,
        nowUtc,
      ]);
    } else if (share.isNote) {
      await db.execute('''
        INSERT INTO notes (
          id, user_id, title, body_md, pinned, category, created_at, updated_at
        ) VALUES (
          ?, ?, ?, ?, 0, ?, ?, ?
        )
      ''', [
        clonedId,
        uid,
        share.title,
        share.notes ?? '',
        share.previewData['category'],
        nowUtc,
        nowUtc,
      ]);
    } else if (share.isProject) {
      await db.execute('''
        INSERT INTO projects (
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

    // 2. Mark share as accepted locally in SQLite
    await db.execute('''
      UPDATE companion_shares
      SET status = 'accepted', updated_at = ?
      WHERE id = ?
    ''', [nowUtc, share.id]);

    // 3. Online RPC synchronization (non-blocking)
    if (isRemoteAuthenticated) {
      unawaited(() async {
        try {
          await _supabaseClient?.rpc(
            'accept_companion_share',
            params: {'p_share_id': share.id},
          );
        } catch (e) {
          debugPrint('[CompanionShareRepository] accept_companion_share RPC notice: $e');
        }
      }());
    }

    return clonedId;
  }

  /// Declines an incoming share request.
  Future<void> declineShare(String shareId) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await db.execute('''
      UPDATE companion_shares
      SET status = 'declined', updated_at = ?
      WHERE id = ?
    ''', [nowUtc, shareId]);
  }

  /// Cancels an outgoing share request sent by current user.
  Future<void> cancelShare(String shareId) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await db.execute('''
      UPDATE companion_shares
      SET status = 'cancelled', updated_at = ?
      WHERE id = ?
    ''', [nowUtc, shareId]);
  }

  Future<void> _logShareSentActivity(String recipientId, String entityType, String title) async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return;

      final actId = IdGenerator.generateDeterministicId(
        'share_act_${DateTime.now().millisecondsSinceEpoch}_$recipientId',
      );
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      await db.execute('''
        INSERT INTO friend_activity_logs (
          id, user_id, event_type, title, metadata, created_at
        ) VALUES (
          ?, ?, 'shared_item_sent', ?, ?, ?
        )
      ''', [
        actId,
        uid,
        'Shared a $entityType: $title',
        jsonEncode({'recipient_id': recipientId, 'entity_type': entityType, 'title': title}),
        nowUtc,
      ]);
    } catch (_) {}
  }
}

