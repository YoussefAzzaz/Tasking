import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/sharing/companion_share_models.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/models/habit.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/friends/friend_models.dart';

void main() {
  group('Companion Sharing Data Model & Logic Tests', () {
    test('CompanionShare correctly deserializes from row and parses preview data', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final row = {
        'id': 'share_test_123',
        'sender_id': 'user_sender_456',
        'recipient_id': 'user_recipient_789',
        'entity_type': 'task',
        'entity_id': 'task_orig_001',
        'share_mode': 'copy',
        'status': 'pending',
        'preview_data': jsonEncode({
          'title': 'Read Clean Code Chapter 4',
          'notes': 'Focus on formatting and small functions',
          'priority': 2,
          'tags': 'study,engineering',
          'due_date': '2026-11-15',
          'due_time': '14:30',
          'estimate_min': 45,
        }),
        'created_at': nowStr,
        'updated_at': nowStr,
        'sender_name': 'Ammar',
        'sender_avatar_color': '#10B981',
      };

      final share = CompanionShare.fromRow(row);

      expect(share.id, equals('share_test_123'));
      expect(share.senderId, equals('user_sender_456'));
      expect(share.recipientId, equals('user_recipient_789'));
      expect(share.isTask, isTrue);
      expect(share.isCopy, isTrue);
      expect(share.isPending, isTrue);
      expect(share.title, equals('Read Clean Code Chapter 4'));
      expect(share.notes, equals('Focus on formatting and small functions'));
      expect(share.priority, equals(2));
      expect(share.tags, equals(['study', 'engineering']));
      expect(share.dueDate, equals('2026-11-15'));
      expect(share.dueTime, equals('14:30'));
      expect(share.estimateMin, equals(45));
      expect(share.senderName, equals('Ammar'));
      expect(share.senderAvatarColor, equals('#10B981'));
    });

    test('CompanionShare handles habit and note entities gracefully', () {
      final habitRow = {
        'id': 'share_habit_1',
        'sender_id': 'u1',
        'recipient_id': 'u2',
        'entity_type': 'habit',
        'entity_id': 'h1',
        'share_mode': 'copy',
        'status': 'pending',
        'accepted_entity_id': 'shared_habit_share_habit_1',
        'preview_data': jsonEncode({
          'name': 'Morning Adhkar',
          'icon': 'mosque',
          'color': '#38BDF8',
          'kind': 'build',
          'schedule_type': 'daily',
          'remind_time': '06:00',
          'category': 'spiritual',
          'target_value': 1,
        }),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final habitShare = CompanionShare.fromRow(habitRow);
      expect(habitShare.isHabit, isTrue);
      expect(habitShare.title, equals('Morning Adhkar'));
      expect(habitShare.acceptedEntityId, equals('shared_habit_share_habit_1'));
      expect(habitShare.habitIcon, equals('mosque'));
      expect(habitShare.habitColor, equals('#38BDF8'));
      expect(habitShare.habitKind, equals('build'));
      expect(habitShare.scheduleType, equals('daily'));
      expect(habitShare.remindTime, equals('06:00'));
      expect(habitShare.targetValue, equals(1));

      final noteRow = {
        'id': 'share_note_1',
        'sender_id': 'u1',
        'recipient_id': 'u2',
        'entity_type': 'note',
        'entity_id': 'n1',
        'share_mode': 'copy',
        'status': 'pending',
        'preview_data': jsonEncode({
          'title': 'Project Ideas',
          'body_md': '# Architecture ideas\n- Offline-first replication',
          'category': 'idea',
          'mood': 'focused',
          'energy': 4,
        }),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final noteShare = CompanionShare.fromRow(noteRow);
      expect(noteShare.isNote, isTrue);
      expect(noteShare.title, equals('Project Ideas'));
      expect(noteShare.notes, contains('Offline-first'));
      expect(noteShare.noteBody, contains('Offline-first'));
      expect(noteShare.noteCategory, equals('idea'));
      expect(noteShare.mood, equals('focused'));
      expect(noteShare.energy, equals('4'));
    });

    test('Task can be prepared for snapshot cloning into a new recipient instance', () {
      final originalTask = Task(
        id: 'orig_999',
        userId: 'sender_user_id',
        title: 'Submit Expense Report',
        notes: 'Include transport receipts',
        priority: 1,
        tags: 'finance,admin',
        dueDate: '2026-11-20',
        dueTime: '17:00',
        estimateMin: 30,
      );

      final clonedTask = Task(
        id: 'new_cloned_uuid',
        userId: 'recipient_user_id',
        title: originalTask.title,
        notes: originalTask.notes,
        status: 'todo',
        priority: originalTask.priority,
        tags: originalTask.tags,
        dueDate: originalTask.dueDate,
        dueTime: originalTask.dueTime,
        estimateMin: originalTask.estimateMin,
      );

      expect(clonedTask.id, isNot(equals(originalTask.id)));
      expect(clonedTask.userId, equals('recipient_user_id'));
      expect(clonedTask.title, equals(originalTask.title));
      expect(clonedTask.status, equals('todo'));
      expect(clonedTask.priority, equals(1));
    });

    test('TaskRepository.mergeSenderTag appends normalized username once without duplicates', () {
      expect(
        TaskRepository.mergeSenderTag(null, 'alice'),
        equals('alice'),
      );
      expect(
        TaskRepository.mergeSenderTag('work,urgent', '@alice'),
        equals('work,urgent,alice'),
      );
      expect(
        TaskRepository.mergeSenderTag('work,@Alice,urgent', 'alice'),
        equals('work,@Alice,urgent'),
      );
      expect(
        TaskRepository.mergeSenderTag('work', ''),
        equals('work'),
      );
    });

    test('Task.fromRow hydrates collaborative fields and newer preview updates', () {
      final task = Task.fromRow({
        'id': 'task-1',
        'user_id': 'user-a',
        'title': 'Old Title',
        'notes': 'Old Notes',
        'status': 'todo',
        'priority': 1,
        'tags': 'work',
        'updated_at': '2026-11-14T10:00:00Z',
        'share_id': 'share-1',
        'share_mode': 'collaborate',
        'share_status': 'accepted',
        'share_sender_id': 'user-a',
        'sender_username': 'alice',
        'recipient_username': 'bob',
        'share_preview_data': {
          'title': 'Updated By Bob',
          'notes': 'Updated Notes',
          'status': 'done',
          'priority': 2,
          'sender_name': 'alice',
          'tags': 'work,alice',
          'task_updated_at': '2026-11-14T12:00:00Z',
        },
      });

      expect(task.isCollaborative, isTrue);
      expect(task.shareId, equals('share-1'));
      expect(task.senderId, equals('user-a'));
      expect(task.senderUsername, equals('alice'));
      expect(task.recipientUsername, equals('bob'));
      expect(task.title, equals('Updated By Bob'));
      expect(task.notes, equals('Updated Notes'));
      expect(task.status, equals('done'));
      expect(task.priority, equals(2));
      expect(task.tags, equals('work,alice'));
    });

    test('CompanionShare.fromRow resolves senderName and task metadata from preview_data', () {
      final share = CompanionShare.fromRow({
        'id': 'share-2',
        'sender_id': 'user-a',
        'recipient_id': 'user-b',
        'entity_type': 'task',
        'entity_id': 'task-2',
        'share_mode': 'collaborate',
        'status': 'accepted',
        'created_at': '2026-11-14T09:00:00Z',
        'preview_data': {
          'title': 'Prepare presentation',
          'status': 'done',
          'sender_name': 'alice',
        },
      });

      expect(share.senderName, equals('alice'));
      expect(share.previewSenderName, equals('alice'));
      expect(share.taskStatus, equals('done'));
      expect(share.isCollaborative, isTrue);
    });

    test('TaskRepository.deduplicateTasks collapses duplicate ids, shareIds, and normalized tasks preferring richer metadata', () {
      final plainDuplicate = Task(
        id: 't_plain',
        userId: 'user-b',
        title: '  Fix the share function  ',
        dueDate: '2026-11-16',
        status: 'todo',
      );
      final richerCollaborative = Task(
        id: 't_collab',
        userId: 'user-b',
        title: 'Fix the share function',
        dueDate: '2026-11-16',
        status: 'todo',
        isCollaborative: true,
        shareId: 'share_abc',
        senderId: 'user-a',
        senderUsername: 'alice',
      );
      final sameShareIdCopy = Task(
        id: 't_other_id',
        userId: 'user-b',
        title: 'Renamed copy sharing same shareId',
        dueDate: '2026-11-17',
        status: 'todo',
        shareId: 'share_abc',
      );
      final sameIdCopy = Task(
        id: 't_collab',
        userId: 'user-b',
        title: 'Duplicate ID entry',
        dueDate: '2026-11-18',
        status: 'todo',
      );
      final distinctDueDateTask = Task(
        id: 't_distinct_date',
        userId: 'user-b',
        title: 'Fix the share function',
        dueDate: '2026-11-20',
        status: 'todo',
      );
      final distinctStatusTask = Task(
        id: 't_distinct_status',
        userId: 'user-b',
        title: 'Fix the share function',
        dueDate: '2026-11-16',
        status: 'done',
      );

      final deduped = TaskRepository.deduplicateTasks([
        plainDuplicate,
        richerCollaborative,
        sameShareIdCopy,
        sameIdCopy,
        distinctDueDateTask,
        distinctStatusTask,
      ]);

      expect(deduped.length, equals(3));
      expect(deduped[0].id, equals('t_collab'));
      expect(deduped[0].isCollaborative, isTrue);
      expect(deduped[0].senderUsername, equals('alice'));
      expect(deduped[1].id, equals('t_distinct_date'));
      expect(deduped[2].id, equals('t_distinct_status'));
    });

    test('TaskRepository.removeSenderTag strips matching @username case-insensitively and preserves other tags', () {
      expect(
        TaskRepository.removeSenderTag('deep_work, @Alice, focus', 'alice'),
        equals('deep_work,focus'),
      );
      expect(
        TaskRepository.removeSenderTag('Alice,@alice,urgent', '@ALICE'),
        equals('urgent'),
      );
      expect(
        TaskRepository.removeSenderTag('@alice', 'alice'),
        isNull,
      );
      expect(
        TaskRepository.removeSenderTag(null, 'alice'),
        isNull,
      );
    });

    test('Habit.fromRow and Note.fromRow hydrate senderUsername and share metadata', () {
      final habitFromJoin = Habit.fromRow({
        'id': 'h_joined',
        'name': 'Morning Adhkar',
        'schedule_type': 'daily',
        'share_id': 'share_h1',
        'share_sender_id': 'user_a',
        'sender_username': '@Ammar',
      });
      expect(habitFromJoin.shareId, equals('share_h1'));
      expect(habitFromJoin.senderId, equals('user_a'));
      expect(habitFromJoin.senderUsername, equals('Ammar'));

      final habitFromPreviewFallback = Habit.fromRow({
        'id': 'h_preview',
        'name': 'Read 10 Pages',
        'share_id': 'share_h2',
        'sender_username': 'Companion',
        'share_preview_data': jsonEncode({
          'sender_id': 'user_b',
          'sender_name': 'Fatima',
        }),
      });
      expect(habitFromPreviewFallback.senderId, equals('user_b'));
      expect(habitFromPreviewFallback.senderUsername, equals('Fatima'));

      final noteFromJoin = Note.fromRow({
        'id': 'n_joined',
        'title': 'Architecture Spec',
        'body_md': 'Draft body',
        'category': 'Work',
        'share_id': 'share_n1',
        'share_sender_id': 'user_c',
        'sender_username': 'Bilal',
      });
      expect(noteFromJoin.shareId, equals('share_n1'));
      expect(noteFromJoin.senderId, equals('user_c'));
      expect(noteFromJoin.senderUsername, equals('Bilal'));
    });

    test('CompanionShare.fromRow resolves recipientName and isDeclinedDismissed plus FriendActivityLog declined getter', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final declinedActive = CompanionShare.fromRow({
        'id': 'share_decl_1',
        'sender_id': 'user_a',
        'recipient_id': 'user_b',
        'entity_type': 'habit',
        'entity_id': 'h_1',
        'share_mode': 'copy',
        'status': 'declined',
        'preview_data': jsonEncode({'title': 'Evening Walk'}),
        'created_at': nowStr,
        'updated_at': nowStr,
        'sender_name': 'UserA',
        'recipient_name': 'UserB',
      });
      expect(declinedActive.recipientName, equals('UserB'));
      expect(declinedActive.isDeclinedDismissed, isFalse);

      final declinedDismissed = CompanionShare.fromRow({
        'id': 'share_decl_2',
        'sender_id': 'user_a',
        'recipient_id': 'user_b',
        'entity_type': 'note',
        'entity_id': 'n_1',
        'share_mode': 'copy',
        'status': 'declined',
        'preview_data': jsonEncode({
          'title': 'Sprint Notes',
          'declined_notice_dismissed': true,
        }),
        'created_at': nowStr,
        'updated_at': nowStr,
        'recipient_name': 'UserB',
      });
      expect(declinedDismissed.isDeclinedDismissed, isTrue);

      final declinedLog = FriendActivityLog.fromRow({
        'id': 'log_decl_1',
        'user_id': 'user_a',
        'user_name': 'UserB',
        'event_type': 'shared_item_declined',
        'title': 'UserB declined "Sprint Notes"',
        'created_at': nowStr,
      });
      expect(declinedLog.isSharedItemDeclined, isTrue);
      expect(declinedLog.isSharedItem, isTrue);
    });

    test('CompanionShare and FriendActivityLog parse collaborative_task_deleted metadata cleanly', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      final deletedCollabShare = CompanionShare.fromRow({
        'id': 'share_collab_del_1',
        'sender_id': 'user_a',
        'recipient_id': 'user_b',
        'entity_type': 'task',
        'entity_id': 't_a1',
        'accepted_entity_id': 't_b1',
        'share_mode': 'collaborate',
        'status': 'cancelled',
        'preview_data': jsonEncode({
          'title': 'Prepare Release',
          'cancelled_by': 'user_b',
          'cancelled_by_name': 'Fatima',
          'cancellation_reason': 'collaborative_task_deleted',
        }),
        'created_at': nowStr,
        'updated_at': nowStr,
        'sender_name': 'Ahmed',
        'recipient_name': 'Fatima',
      });

      expect(deletedCollabShare.isCollaborativeTaskDeleted, isTrue);
      expect(deletedCollabShare.cancelledByUserId, equals('user_b'));
      expect(deletedCollabShare.cancelledByName, equals('Fatima'));

      final copyCancelledShare = CompanionShare.fromRow({
        'id': 'share_copy_cancel_1',
        'sender_id': 'user_a',
        'recipient_id': 'user_b',
        'entity_type': 'task',
        'entity_id': 't_a2',
        'share_mode': 'copy',
        'status': 'cancelled',
        'preview_data': jsonEncode({'title': 'Independent Copy'}),
        'created_at': nowStr,
        'updated_at': nowStr,
      });
      expect(copyCancelledShare.isCollaborativeTaskDeleted, isFalse);

      final deletedLog = FriendActivityLog.fromRow({
        'id': 'log_collab_del_1',
        'user_id': 'user_a',
        'user_name': 'Fatima',
        'event_type': 'collaborative_task_deleted',
        'title': 'Fatima deleted collaborative task: Prepare Release',
        'created_at': nowStr,
      });
      expect(deletedLog.isCollaborativeTaskDeleted, isTrue);
      expect(deletedLog.isSharedItem, isTrue);
    });
  });
}

