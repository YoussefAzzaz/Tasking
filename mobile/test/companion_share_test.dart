import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/sharing/companion_share_models.dart';
import 'package:axis/data/task_repository.dart';

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
        'preview_data': jsonEncode({
          'name': 'Morning Adhkar',
          'icon': 'mosque',
          'color': '#38BDF8',
          'target_value': 1,
        }),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final habitShare = CompanionShare.fromRow(habitRow);
      expect(habitShare.isHabit, isTrue);
      expect(habitShare.title, equals('Morning Adhkar'));

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
        }),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final noteShare = CompanionShare.fromRow(noteRow);
      expect(noteShare.isNote, isTrue);
      expect(noteShare.title, equals('Project Ideas'));
      expect(noteShare.notes, contains('Offline-first'));
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
  });
}

