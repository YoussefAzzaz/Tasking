import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:axis/data/sharing/companion_share_models.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/domain/models/habit.dart';
import 'package:axis/domain/models/task_filter_criteria.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/tasks/inbox_tab.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';
import 'package:axis/ui/desktop/screens/projects_tasks/projects_task_item.dart';
import 'package:axis/ui/desktop/screens/projects_tasks/projects_task_list_pane.dart';
import 'package:axis/ui/desktop/screens/projects_tasks/projects_task_inspector_pane.dart';
import 'package:axis/ui/desktop/screens/command_deck/desktop_task_preview_dialog.dart';
import 'package:axis/ui/friends/widgets/pending_shares_section.dart';
import 'package:axis/data/friends/friend_models.dart';

void main() {
  group('Companion Task Sharing End-to-End Simulation Tests', () {
    late sqlite.Database db;

    setUp(() {
      db = sqlite.sqlite3.openInMemory();

      // Setup simulated local SQLite tables matching PowerSync AppSchema
      db.execute('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT NOT NULL,
          notes TEXT,
          status TEXT DEFAULT 'todo',
          priority INTEGER,
          project_id TEXT,
          tags TEXT,
          due_date TEXT,
          due_time TEXT,
          estimate_min INTEGER,
          recurrence_rule TEXT,
          recurrence_mode TEXT,
          completed_at TEXT,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        );

        CREATE TABLE companion_shares (
          id TEXT PRIMARY KEY,
          sender_id TEXT NOT NULL,
          recipient_id TEXT NOT NULL,
          entity_type TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          share_mode TEXT NOT NULL DEFAULT 'copy',
          status TEXT NOT NULL DEFAULT 'pending',
          preview_data TEXT NOT NULL,
          accepted_entity_id TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );

        CREATE TABLE habits (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          name TEXT NOT NULL,
          category TEXT,
          icon TEXT,
          color TEXT,
          kind TEXT,
          schedule_type TEXT,
          remind_time TEXT,
          target_value INTEGER,
          is_enabled INTEGER DEFAULT 1,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        );

        CREATE TABLE notes (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT,
          body_md TEXT,
          category TEXT DEFAULT 'note',
          mood TEXT,
          energy INTEGER,
          pinned INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        );

        CREATE TABLE user_profiles (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL UNIQUE,
          name TEXT,
          title TEXT,
          avatar_color TEXT,
          avatar_url TEXT,
          total_xp INTEGER DEFAULT 0,
          level INTEGER DEFAULT 1,
          friend_code TEXT,
          created_at TEXT,
          updated_at TEXT
        );

        CREATE TABLE friendships (
          id TEXT PRIMARY KEY,
          requester_id TEXT NOT NULL,
          addressee_id TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'accepted',
          created_at TEXT,
          updated_at TEXT
        );
      ''');

      // Populate companion profiles
      db.execute('''
        INSERT INTO user_profiles (id, user_id, name, title, avatar_color, level, total_xp)
        VALUES 
          ('p1', 'user_alpha', 'Ahmed', 'Strategist', '#10B981', 14, 2800),
          ('p2', 'user_beta', 'Fatima', 'Architect', '#38BDF8', 12, 2200);

        INSERT INTO friendships (id, requester_id, addressee_id, status)
        VALUES ('f1', 'user_alpha', 'user_beta', 'accepted');
      ''');
    });

    tearDown(() {
      db.dispose();
    });

    test('Full lifecycle: User A shares task -> User B receives pending share -> User B accepts and clones task', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. User A creates a task
      final taskA = Task(
        id: 'task_alpha_101',
        userId: 'user_alpha',
        title: 'Complete Mobile Security Audit',
        notes: 'Check biometrics and token expiration',
        priority: 1,
        tags: 'security,audit',
        dueDate: '2026-11-20',
        dueTime: '15:00',
        estimateMin: 90,
      );

      db.execute('''
        INSERT INTO tasks (
          id, user_id, title, notes, status, priority, tags, due_date, due_time, estimate_min, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        taskA.id,
        taskA.userId,
        taskA.title,
        taskA.notes,
        taskA.status,
        taskA.priority,
        taskA.tags,
        taskA.dueDate,
        taskA.dueTime,
        taskA.estimateMin,
        nowStr,
        nowStr,
      ]);

      // Verify User A has 1 task, User B has 0 tasks
      var countA = db.select('SELECT COUNT(*) as c FROM tasks WHERE user_id = ?', ['user_alpha']).first['c'];
      var countB = db.select('SELECT COUNT(*) as c FROM tasks WHERE user_id = ?', ['user_beta']).first['c'];
      expect(countA, equals(1));
      expect(countB, equals(0));

      // 2. User A shares the task with User B (Snapshot Copy)
      final previewData = {
        'title': taskA.title,
        'notes': taskA.notes,
        'priority': taskA.priority,
        'tags': taskA.tags,
        'due_date': taskA.dueDate,
        'due_time': taskA.dueTime,
        'estimate_min': taskA.estimateMin,
      };

      const shareId = 'share_alpha_to_beta_001';
      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status, preview_data, created_at, updated_at
        ) VALUES (?, ?, ?, 'task', ?, 'copy', 'pending', ?, ?, ?)
      ''', [
        shareId,
        'user_alpha',
        'user_beta',
        taskA.id,
        jsonEncode(previewData),
        nowStr,
        nowStr,
      ]);

      // 3. User B queries pending incoming shares
      final pendingRows = db.select('''
        SELECT 
          s.*,
          p.name AS sender_name,
          p.avatar_color AS sender_avatar_color,
          p.avatar_url AS sender_avatar_url
        FROM companion_shares s
        LEFT JOIN user_profiles p ON p.user_id = s.sender_id
        WHERE s.recipient_id = ? AND s.status = 'pending'
      ''', ['user_beta']);

      expect(pendingRows.length, equals(1));
      final pendingShare = CompanionShare.fromRow(pendingRows.first);

      expect(pendingShare.id, equals(shareId));
      expect(pendingShare.senderName, equals('Ahmed'));
      expect(pendingShare.senderAvatarColor, equals('#10B981'));
      expect(pendingShare.title, equals('Complete Mobile Security Audit'));
      expect(pendingShare.priority, equals(1));
      expect(pendingShare.tags, equals(['security', 'audit']));
      expect(pendingShare.isCopy, isTrue);
      expect(pendingShare.isPending, isTrue);

      // 4. User B accepts the share -> executes Local Cloning
      const clonedTaskId = 'task_beta_cloned_202';
      final clonedTask = Task(
        id: clonedTaskId,
        userId: 'user_beta',
        title: pendingShare.title,
        notes: pendingShare.notes,
        status: 'todo',
        priority: pendingShare.priority,
        tags: pendingShare.tags.join(','),
        dueDate: pendingShare.dueDate,
        dueTime: pendingShare.dueTime,
        estimateMin: pendingShare.estimateMin,
      );

      // Insert cloned task into User B's tasks
      db.execute('''
        INSERT INTO tasks (
          id, user_id, title, notes, status, priority, tags, due_date, due_time, estimate_min, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        clonedTask.id,
        clonedTask.userId,
        clonedTask.title,
        clonedTask.notes,
        clonedTask.status,
        clonedTask.priority,
        clonedTask.tags,
        clonedTask.dueDate,
        clonedTask.dueTime,
        clonedTask.estimateMin,
        nowStr,
        nowStr,
      ]);

      // Mark share as accepted
      db.execute('''
        UPDATE companion_shares
        SET status = 'accepted', updated_at = ?
        WHERE id = ?
      ''', [nowStr, shareId]);

      // 5. Verify final state
      // Both users now have 1 task each, isolated and independent!
      countA = db.select('SELECT COUNT(*) as c FROM tasks WHERE user_id = ?', ['user_alpha']).first['c'];
      countB = db.select('SELECT COUNT(*) as c FROM tasks WHERE user_id = ?', ['user_beta']).first['c'];
      expect(countA, equals(1));
      expect(countB, equals(1));

      final betaTaskRow = db.select('SELECT * FROM tasks WHERE id = ?', [clonedTaskId]).first;
      expect(betaTaskRow['user_id'], equals('user_beta'));
      expect(betaTaskRow['title'], equals('Complete Mobile Security Audit'));
      expect(betaTaskRow['priority'], equals(1));
      expect(betaTaskRow['status'], equals('todo'));

      // Check share record is now 'accepted'
      final updatedShareRow = db.select('SELECT status FROM companion_shares WHERE id = ?', [shareId]).first;
      expect(updatedShareRow['status'], equals('accepted'));

      // Pending inbox for User B is now empty
      final remainingPending = db.select('''
        SELECT COUNT(*) as c FROM companion_shares WHERE recipient_id = ? AND status = 'pending'
      ''', ['user_beta']).first['c'];
      expect(remainingPending, equals(0));
    });

    test('User B declines incoming share request', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      const shareId = 'share_decline_test';

      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status, preview_data, created_at, updated_at
        ) VALUES (?, 'user_alpha', 'user_beta', 'task', 'task_1', 'copy', 'pending', '{"title":"Unwanted Task"}', ?, ?)
      ''', [shareId, nowStr, nowStr]);

      // User B declines
      db.execute('''
        UPDATE companion_shares SET status = 'declined', updated_at = ? WHERE id = ?
      ''', [nowStr, shareId]);

      final row = db.select('SELECT status FROM companion_shares WHERE id = ?', [shareId]).first;
      expect(row['status'], equals('declined'));

      // No task was added to User B
      final countB = db.select('SELECT COUNT(*) as c FROM tasks WHERE user_id = ?', ['user_beta']).first['c'];
      expect(countB, equals(0));
    });

    test('User A cancels outgoing share request before acceptance', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();
      const shareId = 'share_cancel_test';

      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status, preview_data, created_at, updated_at
        ) VALUES (?, 'user_alpha', 'user_beta', 'task', 'task_2', 'copy', 'pending', '{"title":"Draft Task"}', ?, ?)
      ''', [shareId, nowStr, nowStr]);

      // User A cancels
      db.execute('''
        UPDATE companion_shares SET status = 'cancelled', updated_at = ? WHERE id = ?
      ''', [nowStr, shareId]);

      final row = db.select('SELECT status FROM companion_shares WHERE id = ?', [shareId]).first;
      expect(row['status'], equals('cancelled'));
    });

    test('Full lifecycle: User A shares habit and note -> User B accepts -> clones into habits/notes with accepted_entity_id', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // 1. User A creates a habit and a note
      final habitA = Habit(
        id: 'habit_alpha_1',
        name: 'Fajr Quran Reading',
        category: 'spiritual',
        icon: 'menu_book',
        color: '#10B981',
        scheduleType: 'daily',
        remindTime: '05:30',
        targetValue: 30,
      );
      final noteA = Note(
        id: 'note_alpha_1',
        userId: 'user_alpha',
        title: 'Sprint Retrospective Notes',
        bodyMd: '## Wins\n- Offline-first PowerSync replication is smooth.',
        category: 'journal',
        mood: 'CALM FOCUS',
        energy: '4',
      );

      db.execute('''
        INSERT INTO habits (id, user_id, name, category, icon, color, kind, schedule_type, remind_time, target_value, is_enabled, created_at, updated_at)
        VALUES (?, 'user_alpha', ?, ?, ?, ?, 'build', ?, ?, ?, 1, ?, ?)
      ''', [
        habitA.id,
        habitA.name,
        habitA.category,
        habitA.icon,
        habitA.color,
        habitA.scheduleType,
        habitA.remindTime,
        habitA.targetValue,
        nowStr,
        nowStr,
      ]);

      db.execute('''
        INSERT INTO notes (id, user_id, title, body_md, category, mood, energy, pinned, created_at, updated_at)
        VALUES (?, 'user_alpha', ?, ?, ?, ?, ?, 0, ?, ?)
      ''', [
        noteA.id,
        noteA.title,
        noteA.bodyMd,
        noteA.category,
        noteA.mood,
        noteA.energy,
        nowStr,
        nowStr,
      ]);

      // 2. User A shares habit (collaborate) and note (copy) to User B
      const habitShareId = 'share_habit_e2e';
      const noteShareId = 'share_note_e2e';

      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status, preview_data, created_at, updated_at
        ) VALUES (?, 'user_alpha', 'user_beta', 'habit', ?, 'collaborate', 'pending', ?, ?, ?)
      ''', [
        habitShareId,
        habitA.id,
        jsonEncode({
          'name': habitA.name,
          'title': habitA.name,
          'category': habitA.category,
          'icon': habitA.icon,
          'color': habitA.color,
          'kind': 'build',
          'schedule_type': habitA.scheduleType,
          'remind_time': habitA.remindTime,
          'target_value': habitA.targetValue,
        }),
        nowStr,
        nowStr,
      ]);

      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status, preview_data, created_at, updated_at
        ) VALUES (?, 'user_alpha', 'user_beta', 'note', ?, 'copy', 'pending', ?, ?, ?)
      ''', [
        noteShareId,
        noteA.id,
        jsonEncode({
          'title': noteA.title,
          'body_md': noteA.bodyMd,
          'category': noteA.category,
          'mood': noteA.mood,
          'energy': noteA.energy,
        }),
        nowStr,
        nowStr,
      ]);

      // 3. User B queries pending shares and accepts both
      final pendingRows = db.select('''
        SELECT cs.*, up.name AS sender_name, up.avatar_color AS sender_avatar_color
        FROM companion_shares cs
        LEFT JOIN user_profiles up ON up.user_id = cs.sender_id
        WHERE cs.recipient_id = 'user_beta' AND cs.status = 'pending'
      ''');
      expect(pendingRows.length, equals(2));

      for (final row in pendingRows) {
        final share = CompanionShare.fromRow(row);
        if (share.isHabit) {
          final clonedHabitId = 'shared_habit_${share.id}';
          db.execute('''
            INSERT INTO habits (id, user_id, name, category, icon, color, kind, schedule_type, remind_time, target_value, is_enabled, created_at, updated_at)
            VALUES (?, 'user_beta', ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)
          ''', [
            clonedHabitId,
            share.title,
            share.previewData['category'] ?? 'general',
            share.habitIcon ?? 'check_circle',
            share.habitColor ?? '#10B981',
            share.habitKind ?? 'build',
            share.scheduleType ?? 'daily',
            share.remindTime,
            share.targetValue ?? 20,
            nowStr,
            nowStr,
          ]);
          db.execute('''
            UPDATE companion_shares SET status = 'accepted', accepted_entity_id = ?, updated_at = ? WHERE id = ?
          ''', [clonedHabitId, nowStr, share.id]);
        } else if (share.isNote) {
          final clonedNoteId = 'shared_note_${share.id}';
          db.execute('''
            INSERT INTO notes (id, user_id, title, body_md, category, mood, energy, pinned, created_at, updated_at)
            VALUES (?, 'user_beta', ?, ?, ?, ?, ?, 0, ?, ?)
          ''', [
            clonedNoteId,
            share.title,
            share.noteBody ?? '',
            share.noteCategory ?? 'note',
            share.mood,
            share.energy,
            nowStr,
            nowStr,
          ]);
          db.execute('''
            UPDATE companion_shares SET status = 'accepted', accepted_entity_id = ?, updated_at = ? WHERE id = ?
          ''', [clonedNoteId, nowStr, share.id]);
        }
      }

      // 4. Verify cloned rows & accepted_entity_id linkage
      final betaHabit = db.select("SELECT * FROM habits WHERE user_id = 'user_beta'").first;
      expect(betaHabit['id'], equals('shared_habit_$habitShareId'));
      expect(betaHabit['name'], equals('Fajr Quran Reading'));
      expect(betaHabit['remind_time'], equals('05:30'));
      expect(betaHabit['target_value'], equals(30));

      final betaNote = db.select("SELECT * FROM notes WHERE user_id = 'user_beta'").first;
      expect(betaNote['id'], equals('shared_note_$noteShareId'));
      expect(betaNote['title'], equals('Sprint Retrospective Notes'));
      expect(betaNote['body_md'], contains('PowerSync replication'));
      expect(betaNote['category'], equals('journal'));
      expect(betaNote['mood'], equals('CALM FOCUS'));

      final updatedHabitShare = db.select('SELECT status, accepted_entity_id FROM companion_shares WHERE id = ?', [habitShareId]).first;
      expect(updatedHabitShare['status'], equals('accepted'));
      expect(updatedHabitShare['accepted_entity_id'], equals('shared_habit_$habitShareId'));

      final updatedNoteShare = db.select('SELECT status, accepted_entity_id FROM companion_shares WHERE id = ?', [noteShareId]).first;
      expect(updatedNoteShare['status'], equals('accepted'));
      expect(updatedNoteShare['accepted_entity_id'], equals('shared_note_$noteShareId'));
    });

    test('Copy shares of tasks, habits, and notes leave sender isolated without @tag or collab while tagging recipient copy only', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // User A creates task, habit, note
      db.execute('''
        INSERT INTO tasks (id, user_id, title, notes, status, priority, tags, created_at, updated_at)
        VALUES ('task_a_copy', 'user_alpha', 'Design Review', 'Check spacing', 'todo', 1, 'ui', ?, ?)
      ''', [nowStr, nowStr]);
      db.execute('''
        INSERT INTO habits (id, user_id, name, kind, schedule_type, target_value, created_at, updated_at)
        VALUES ('habit_a_copy', 'user_alpha', 'Deep Stretch', 'health', 'daily', 20, ?, ?)
      ''', [nowStr, nowStr]);
      db.execute('''
        INSERT INTO notes (id, user_id, title, body_md, category, created_at, updated_at)
        VALUES ('note_a_copy', 'user_alpha', 'Release Checklist', 'Run all unit tests', 'Work', ?, ?)
      ''', [nowStr, nowStr]);

      // Accepted copies in User B's rows
      db.execute('''
        INSERT INTO tasks (id, user_id, title, notes, status, priority, tags, created_at, updated_at)
        VALUES ('task_b_copy', 'user_beta', 'Design Review', 'Check spacing', 'todo', 1, 'ui,Ahmed', ?, ?)
      ''', [nowStr, nowStr]);
      db.execute('''
        INSERT INTO habits (id, user_id, name, kind, schedule_type, target_value, created_at, updated_at)
        VALUES ('habit_b_copy', 'user_beta', 'Deep Stretch', 'health', 'daily', 20, ?, ?)
      ''', [nowStr, nowStr]);
      db.execute('''
        INSERT INTO notes (id, user_id, title, body_md, category, created_at, updated_at)
        VALUES ('note_b_copy', 'user_beta', 'Release Checklist', 'Run all unit tests', 'Work', ?, ?)
      ''', [nowStr, nowStr]);

      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status,
          preview_data, accepted_entity_id, created_at, updated_at
        ) VALUES
          ('s_copy_task', 'user_alpha', 'user_beta', 'task', 'task_a_copy', 'copy', 'accepted', ?, 'task_b_copy', ?, ?),
          ('s_copy_habit', 'user_alpha', 'user_beta', 'habit', 'habit_a_copy', 'copy', 'accepted', ?, 'habit_b_copy', ?, ?),
          ('s_copy_note', 'user_alpha', 'user_beta', 'note', 'note_a_copy', 'copy', 'accepted', ?, 'note_b_copy', ?, ?)
      ''', [
        jsonEncode({'title': 'Design Review', 'sender_id': 'user_alpha', 'sender_name': 'Ahmed'}),
        nowStr,
        nowStr,
        jsonEncode({'title': 'Deep Stretch', 'sender_id': 'user_alpha', 'sender_name': 'Ahmed'}),
        nowStr,
        nowStr,
        jsonEncode({'title': 'Release Checklist', 'sender_id': 'user_alpha', 'sender_name': 'Ahmed'}),
        nowStr,
        nowStr,
      ]);

      const taskJoinSql = '''
        SELECT
          t.*,
          cs.id AS share_id,
          cs.share_mode AS share_mode,
          cs.status AS share_status,
          cs.sender_id AS share_sender_id,
          cs.preview_data AS share_preview_data,
          sp.name AS sender_username
        FROM tasks t
        LEFT JOIN companion_shares cs
          ON cs.id = (
            SELECT cs2.id FROM companion_shares cs2
            WHERE cs2.entity_type = 'task'
              AND (
                (cs2.share_mode = 'collaborate' AND cs2.status IN ('accepted', 'pending')
                  AND (cs2.entity_id = t.id OR cs2.accepted_entity_id = t.id))
                OR
                (cs2.share_mode = 'copy' AND cs2.status = 'accepted'
                  AND cs2.accepted_entity_id = t.id AND cs2.sender_id != COALESCE(t.user_id, ''))
              )
            LIMIT 1
          )
        LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
        WHERE t.user_id = ?
      ''';

      const habitJoinSql = '''
        SELECT
          h.*,
          cs.id AS share_id,
          cs.sender_id AS share_sender_id,
          cs.preview_data AS share_preview_data,
          sp.name AS sender_username
        FROM habits h
        LEFT JOIN companion_shares cs
          ON cs.id = (
            SELECT cs2.id FROM companion_shares cs2
            WHERE cs2.entity_type = 'habit'
              AND cs2.status = 'accepted'
              AND cs2.accepted_entity_id = h.id
              AND cs2.sender_id != COALESCE(h.user_id, '')
            LIMIT 1
          )
        LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
        WHERE h.user_id = ?
      ''';

      const noteJoinSql = '''
        SELECT
          n.*,
          cs.id AS share_id,
          cs.sender_id AS share_sender_id,
          cs.preview_data AS share_preview_data,
          sp.name AS sender_username
        FROM notes n
        LEFT JOIN companion_shares cs
          ON cs.id = (
            SELECT cs2.id FROM companion_shares cs2
            WHERE cs2.entity_type = 'note'
              AND cs2.status = 'accepted'
              AND cs2.accepted_entity_id = n.id
              AND cs2.sender_id != COALESCE(n.user_id, '')
            LIMIT 1
          )
        LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
        WHERE n.user_id = ?
      ''';

      final userATasks = db.select(taskJoinSql, ['user_alpha']).map(Task.fromRow).toList();
      final userBTasks = db.select(taskJoinSql, ['user_beta']).map(Task.fromRow).toList();
      expect(userATasks.single.isCollaborative, isFalse);
      expect(userATasks.single.senderUsername, isNull);
      expect(userATasks.single.tags, equals('ui'));
      expect(userBTasks.single.isCollaborative, isFalse);
      expect(userBTasks.single.senderUsername, equals('Ahmed'));

      final userAHabits = db.select(habitJoinSql, ['user_alpha']).map((r) => Habit.fromRow(r)).toList();
      final userBHabits = db.select(habitJoinSql, ['user_beta']).map((r) => Habit.fromRow(r)).toList();
      expect(userAHabits.single.senderUsername, isNull);
      expect(userBHabits.single.senderUsername, equals('Ahmed'));

      final userANotes = db.select(noteJoinSql, ['user_alpha']).map(Note.fromRow).toList();
      final userBNotes = db.select(noteJoinSql, ['user_beta']).map(Note.fromRow).toList();
      expect(userANotes.single.senderUsername, isNull);
      expect(userBNotes.single.senderUsername, equals('Ahmed'));
    });

    test('Collaborative task is un-classified when declined or removed by recipient while sender task stays active', () {
      final nowStr = DateTime.now().toUtc().toIso8601String();

      // Case 1: Collaborative invite declined by recipient
      db.execute('''
        INSERT INTO tasks (id, user_id, title, status, tags, created_at, updated_at)
        VALUES ('t_collab_decl', 'user_alpha', 'Plan Summit', 'todo', 'ops', ?, ?)
      ''', [nowStr, nowStr]);
      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status, preview_data, created_at, updated_at
        ) VALUES ('s_collab_decl', 'user_alpha', 'user_beta', 'task', 't_collab_decl', 'collaborate', 'pending', ?, ?, ?)
      ''', [jsonEncode({'title': 'Plan Summit', 'sender_name': 'Ahmed'}), nowStr, nowStr]);

      const singleTaskSql = '''
        SELECT
          t.*,
          cs.id AS share_id,
          cs.share_mode AS share_mode,
          cs.status AS share_status,
          cs.sender_id AS share_sender_id,
          cs.preview_data AS share_preview_data,
          sp.name AS sender_username
        FROM tasks t
        LEFT JOIN companion_shares cs
          ON cs.id = (
            SELECT cs2.id FROM companion_shares cs2
            WHERE cs2.entity_type = 'task'
              AND cs2.share_mode = 'collaborate'
              AND cs2.status IN ('accepted', 'pending')
              AND (cs2.entity_id = t.id OR cs2.accepted_entity_id = t.id)
              AND NOT EXISTS (
                SELECT 1 FROM tasks t_del
                WHERE (t_del.id = cs2.entity_id OR t_del.id = cs2.accepted_entity_id)
                  AND t_del.deleted_at IS NOT NULL AND t_del.deleted_at != ''
              )
            LIMIT 1
          )
        LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
        WHERE t.id = ? AND (t.deleted_at IS NULL OR t.deleted_at = '')
      ''';

      // Initially collaborative while pending
      var taskA = Task.fromRow(db.select(singleTaskSql, ['t_collab_decl']).single);
      expect(taskA.isCollaborative, isTrue);

      // User B declines
      db.execute("UPDATE companion_shares SET status = 'declined', updated_at = ? WHERE id = 's_collab_decl'", [nowStr]);
      taskA = Task.fromRow(db.select(singleTaskSql, ['t_collab_decl']).single);
      expect(taskA.isCollaborative, isFalse);
      expect(taskA.senderUsername, isNull);
      expect(TaskRepository.removeSenderTag(taskA.tags, 'Ahmed'), equals('ops'));

      // Case 2: Accepted collaborative task is soft-deleted/removed by User B
      db.execute('''
        INSERT INTO tasks (id, user_id, title, status, tags, created_at, updated_at)
        VALUES
          ('t_collab_rm_a', 'user_alpha', 'Ship V2', 'todo', 'release', ?, ?),
          ('t_collab_rm_b', 'user_beta', 'Ship V2', 'todo', 'release,Ahmed', ?, ?)
      ''', [nowStr, nowStr, nowStr, nowStr]);
      db.execute('''
        INSERT INTO companion_shares (
          id, sender_id, recipient_id, entity_type, entity_id, share_mode, status,
          preview_data, accepted_entity_id, created_at, updated_at
        ) VALUES ('s_collab_rm', 'user_alpha', 'user_beta', 'task', 't_collab_rm_a', 'collaborate', 'accepted', ?, 't_collab_rm_b', ?, ?)
      ''', [jsonEncode({'title': 'Ship V2', 'sender_name': 'Ahmed'}), nowStr, nowStr]);

      var activeCollabA = Task.fromRow(db.select(singleTaskSql, ['t_collab_rm_a']).single);
      expect(activeCollabA.isCollaborative, isTrue);

      // User B soft-deletes their copy and share is cancelled with actor metadata
      db.execute("UPDATE tasks SET deleted_at = ? WHERE id = 't_collab_rm_b'", [nowStr]);
      db.execute('''
        UPDATE companion_shares
        SET status = 'cancelled', preview_data = ?, updated_at = ?
        WHERE id = 's_collab_rm'
      ''', [
        jsonEncode({
          'title': 'Ship V2',
          'sender_name': 'Ahmed',
          'cancelled_by': 'user_beta',
          'cancelled_by_name': 'Fatima',
          'cancellation_reason': 'collaborative_task_deleted',
        }),
        nowStr,
      ]);

      final survivingA = db.select(singleTaskSql, ['t_collab_rm_a']).map(Task.fromRow).toList();
      expect(survivingA.length, equals(1));
      expect(survivingA.single.isCollaborative, isFalse);
      expect(survivingA.single.senderUsername, isNull);

      final cancelledShareRow = db.select(
        '''
        SELECT cs.*, sp.name AS sender_name, rp.name AS recipient_name
        FROM companion_shares cs
        LEFT JOIN user_profiles sp ON sp.user_id = cs.sender_id
        LEFT JOIN user_profiles rp ON rp.user_id = cs.recipient_id
        WHERE cs.id = 's_collab_rm'
        ''',
      ).single;
      final parsedCancelledShare = CompanionShare.fromRow(cancelledShareRow);
      expect(parsedCancelledShare.isCollaborativeTaskDeleted, isTrue);
      expect(parsedCancelledShare.cancelledByUserId, equals('user_beta'));
      expect(parsedCancelledShare.cancelledByName, equals('Fatima'));
    });
  });

  group('Companion Task Sharing UI Widget Tests', () {
    testWidgets('PendingSharesSection card renders sender info, task title, badges, and action buttons', (tester) async {
      final testShare = CompanionShare(
        id: 'ui_share_1',
        senderId: 'u_alpha',
        recipientId: 'u_beta',
        entityType: 'task',
        entityId: 't1',
        shareMode: 'copy',
        status: 'pending',
        previewData: const {
          'title': 'Design Database Schema for Companions',
          'notes': 'Include RLS policies and index strategy',
          'priority': 1,
        },
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        senderName: 'Tariq',
        senderAvatarColor: '#10B981',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PendingSharesSectionCardTestWrapper(share: testShare),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Sender
      expect(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Tariq sent you a task copy'),
        ),
        findsOneWidget,
      );
      expect(find.text('COPY'), findsOneWidget);

      // Task Title
      expect(find.text('Design Database Schema for Companions'), findsOneWidget);
      expect(find.text('Include RLS policies and index strategy'), findsOneWidget);

      // Action buttons
      expect(find.text('Accept Task'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('ShareTaskSheet renders task preview and mode selection switches', (tester) async {
      final testTask = Task(
        id: 't_preview',
        title: 'Review System Design Document',
        notes: 'Check section 2 for database constraints',
        priority: 2,
        dueDate: '2026-11-25',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareTaskSheet(task: testTask),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Sheet title
      expect(find.text('SHARE TASK WITH COMPANION'), findsOneWidget);

      // Task Preview
      expect(find.text('Review System Design Document'), findsOneWidget);
      expect(find.text('Check section 2 for database constraints'), findsOneWidget);
      expect(find.text('2026-11-25'), findsOneWidget);

      // Modes
      expect(find.text('Send as Copy'), findsOneWidget);
      expect(find.text('Collaborative'), findsOneWidget);

      // Send button
      expect(find.text('Send Task to Companion'), findsOneWidget);
    });

    testWidgets('ShareTaskSheet renders habit and note previews with entity-specific headers', (tester) async {
      final testHabit = Habit(
        id: 'h_preview',
        name: 'Morning Tahajjud',
        category: 'spiritual',
        scheduleType: 'daily',
        remindTime: '04:30',
        targetValue: 30,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareTaskSheet(habit: testHabit),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SHARE HABIT WITH COMPANION'), findsOneWidget);
      expect(find.text('HABIT'), findsOneWidget);
      expect(find.text('Morning Tahajjud'), findsOneWidget);
      expect(find.text('04:30'), findsOneWidget);
      expect(find.text('Send Habit to Companion'), findsOneWidget);
      // Habits are share-only (no collaboration mode selector)
      expect(find.text('Collaborative'), findsNothing);
      expect(find.text('Send as Copy'), findsNothing);

      final testNote = Note(
        id: 'n_preview',
        title: 'Weekly Reflection',
        bodyMd: 'Keep focus blocks uninterrupted in the morning.',
        category: 'journal',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ShareTaskSheet(note: testNote),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SHARE NOTE WITH COMPANION'), findsOneWidget);
      expect(find.text('NOTE'), findsOneWidget);
      expect(find.text('Weekly Reflection'), findsOneWidget);
      expect(find.text('Keep focus blocks uninterrupted in the morning.'), findsOneWidget);
      expect(find.text('Send Note to Companion'), findsOneWidget);
      // Notes are share-only (no collaboration mode selector)
      expect(find.text('Collaborative'), findsNothing);
      expect(find.text('Send as Copy'), findsNothing);
    });

    testWidgets('ShareWithCompanionSheet lets user choose Task/Habit/Note, enforces share-only for habits/notes, and filters out completed tasks', (tester) async {
      String? capturedType;
      dynamic capturedItem;
      String? capturedMode;

      final sampleTasks = [
        Task(id: 't_1', title: 'Draft Architecture Spec', priority: 2, status: 'todo'),
        Task(id: 't_done', title: 'Completed Legacy Task', priority: 1, status: 'done'),
      ];
      final sampleHabits = [
        Habit(id: 'h_1', name: 'Read 10 Pages', scheduleType: 'daily', remindTime: '21:00'),
      ];
      final sampleNotes = [
        Note(id: 'n_1', title: 'Key Learnings', bodyMd: 'Use triggers cleanly', category: 'note'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: ctx,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => ShareWithCompanionSheet(
                        companionUserId: 'user_sara',
                        companionName: 'Sara',
                        initialTasks: sampleTasks,
                        initialHabits: sampleHabits,
                        initialNotes: sampleNotes,
                        onShareOverride: (type, item, mode) async {
                          capturedType = type;
                          capturedItem = item;
                          capturedMode = mode;
                        },
                      ),
                    );
                  },
                  child: const Text('Open Share Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Share Sheet'));
      await tester.pumpAndSettle();

      // Step 1: Ask what to share (no mode selector on Step 1)
      expect(find.text('What would you like to share?'), findsOneWidget);
      expect(find.byKey(const ValueKey('share_type_task')), findsOneWidget);
      expect(find.byKey(const ValueKey('share_type_habit')), findsOneWidget);
      expect(find.byKey(const ValueKey('share_type_note')), findsOneWidget);
      expect(find.text('Collaborative'), findsNothing);

      // Choose Habit -> Step 2 item picker has NO Collaborative option
      await tester.tap(find.byKey(const ValueKey('share_type_habit')));
      await tester.pumpAndSettle();

      expect(find.text('Choose which habit to share'), findsOneWidget);
      expect(find.byKey(const ValueKey('pick_habit_h_1')), findsOneWidget);
      expect(find.text('Collaborative'), findsNothing);

      // Go back and test Note flow (also share-only -> mode 'copy')
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share_type_note')));
      await tester.pumpAndSettle();
      expect(find.text('Choose which note to share'), findsOneWidget);
      expect(find.text('Collaborative'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('pick_note_n_1')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Share with Sara'));
      await tester.pumpAndSettle();

      expect(capturedType, equals('note'));
      expect((capturedItem as Note).id, equals('n_1'));
      expect(capturedMode, equals('copy'));

      // Re-open and test Task flow: completed tasks are hidden, collaborative is available
      await tester.tap(find.text('Open Share Sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share_type_task')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('pick_task_t_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick_task_t_done')), findsNothing);
      expect(find.text('Completed Legacy Task'), findsNothing);
      expect(find.text('Collaborative'), findsOneWidget);

      await tester.tap(find.text('Collaborative'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick_task_t_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share with Sara'));
      await tester.pumpAndSettle();

      expect(capturedType, equals('task'));
      expect((capturedItem as Task).id, equals('t_1'));
      expect(capturedMode, equals('collaborate'));
    });

    testWidgets('Desktop ProjectsTaskItem and DesktopTaskPreviewDialog expose Share Task actions for active tasks and hide them for completed tasks', (tester) async {
      final desktopTask = Task(
        id: 'desk_t_1',
        title: 'Finalize Desktop Telemetry',
        notes: 'Verify desktop sync and sharing',
        priority: 1,
        dueDate: '2026-11-28',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ProjectsTaskItem(
              task: desktopTask,
              isSelected: false,
              onTap: () {},
              taskRepo: TaskRepository(),
              todayStr: '2026-11-14',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final itemShareBtn = find.byKey(const ValueKey('projects_task_item_share_desk_t_1'));
      expect(itemShareBtn, findsOneWidget);
      await tester.tap(itemShareBtn);
      await tester.pumpAndSettle();

      expect(find.text('SHARE TASK WITH COMPANION'), findsOneWidget);
      expect(find.text('Finalize Desktop Telemetry'), findsWidgets);

      // Dismiss ShareTaskSheet and verify DesktopTaskPreviewDialog share actions
      Navigator.of(tester.element(find.text('SHARE TASK WITH COMPANION'))).pop();
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: DesktopTaskPreviewDialog(
              initialTask: desktopTask,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('desktop_task_preview_share_button')), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Share Task'), findsOneWidget);

      // Completed task hides share actions on both ProjectsTaskItem and DesktopTaskPreviewDialog
      final completedDesktopTask = desktopTask.copyWith(status: 'done');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ProjectsTaskItem(
              task: completedDesktopTask,
              isSelected: false,
              onTap: () {},
              taskRepo: TaskRepository(),
              todayStr: '2026-11-14',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('projects_task_item_share_desk_t_1')), findsNothing);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: DesktopTaskPreviewDialog(
              initialTask: completedDesktopTask,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop_task_preview_share_button')), findsNothing);
      expect(find.text('Share Task'), findsNothing);
    });

    testWidgets('Mobile InboxTab separates collaborative tasks and shows @sender badge once', (tester) async {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final collabTask = Task(
        id: 'collab-1',
        userId: 'user-b',
        title: 'Joint Sprint Plan',
        status: 'todo',
        priority: 1,
        dueDate: todayStr,
        tags: 'work,alice',
        isCollaborative: true,
        shareId: 'share-1',
        senderId: 'user-a',
        senderUsername: 'alice',
        recipientUsername: 'bob',
      );
      final personalTask = Task(
        id: 'personal-1',
        userId: 'user-b',
        title: 'Solo Errand',
        status: 'todo',
        priority: 2,
        dueDate: todayStr,
      );
      final fakeRepo = _FakeTaskRepository([collabTask, personalTask]);
      final criteria = ValueNotifier<TaskFilterCriteria>(const TaskFilterCriteria());
      addTearDown(criteria.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: InboxTab(
              repo: fakeRepo,
              filterCriteria: criteria,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COLLABORATIVE TASKS'), findsOneWidget);
      expect(find.text('Joint Sprint Plan'), findsOneWidget);
      expect(find.text('Solo Errand'), findsOneWidget);
      expect(find.text('COLLAB'), findsOneWidget);
      // @alice rendered once as sender badge (and deduplicated from generic tags)
      expect(find.text('@alice'), findsOneWidget);
      expect(find.text('@work'), findsOneWidget);
    });

    testWidgets('Desktop ProjectsTaskListPane and InspectorPane separate collaborative tasks and show @sender', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final listScrollController = ScrollController();
      addTearDown(listScrollController.dispose);

      final collabTask = Task(
        id: 'collab-desk-1',
        userId: 'user-b',
        title: 'Shared Desktop Spec',
        status: 'todo',
        priority: 1,
        tags: 'spec,alice',
        isCollaborative: true,
        shareId: 'share-desk-1',
        senderId: 'user-a',
        senderUsername: 'alice',
        recipientUsername: 'bob',
      );
      final personalTask = Task(
        id: 'personal-desk-1',
        userId: 'user-b',
        title: 'Personal Desktop Cleanup',
        status: 'todo',
        priority: 3,
      );
      final fakeRepo = _FakeTaskRepository([collabTask, personalTask]);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 520,
                  height: 800,
                  child: ProjectsTaskListPane(
                    selectedProjectId: null,
                    selectedTaskId: collabTask.id,
                    onSelectTask: (_) {},
                    onResetProjectFilter: () {},
                    taskRepo: fakeRepo,
                    scrollController: listScrollController,
                  ),
                ),
                SizedBox(
                  width: 440,
                  height: 800,
                  child: ProjectsTaskInspectorPane(
                    selectedTaskId: collabTask.id,
                    selectedTask: collabTask,
                    taskRepo: fakeRepo,
                    onTaskUpdated: (_) {},
                    onTaskDeleted: () {},
                    onNavigateToTab: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Collaborative'), findsOneWidget);
      expect(find.text('COLLABORATIVE TASKS'), findsOneWidget);
      expect(find.text('Shared Desktop Spec'), findsWidgets);
      expect(find.text('Personal Desktop Cleanup'), findsOneWidget);
      expect(find.text('COLLAB'), findsOneWidget);
      expect(find.text('COLLABORATIVE'), findsOneWidget);
      // Shown once on ProjectsTaskItem and once on ProjectsTaskInspectorPane
      expect(find.text('@alice'), findsNWidgets(2));

      // Tap Collaborative filter button to hide personal task
      await tester.tap(find.text('Collaborative'));
      await tester.pumpAndSettle();
      expect(find.text('Shared Desktop Spec'), findsWidgets);
      expect(find.text('Personal Desktop Cleanup'), findsNothing);
    });

    testWidgets('ShareTaskSheet disables already-shared companion and renders ALREADY SHARED badge', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final task = Task(id: 't_1', title: 'Write Architecture RFC');
      const friends = [
        FriendUser(
          id: 'f1',
          userId: 'comp_shared',
          name: 'Alice',
          friendshipId: 'fr1',
        ),
        FriendUser(
          id: 'f2',
          userId: 'comp_free',
          name: 'Bob',
          friendshipId: 'fr2',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ShareTaskSheet(
              task: task,
              initialFriends: friends,
              initialAlreadySharedCompanionIds: const {'comp_shared'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('already_shared_companion_comp_shared')),
        findsOneWidget,
      );
      expect(find.text('ALREADY SHARED'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('already_shared_companion_comp_free')),
        findsNothing,
      );

      final sendBtnFinder = find.ancestor(
        of: find.text('Send Task to Companion'),
        matching: find.byType(ElevatedButton),
      );

      // Tapping already-shared companion should not enable Send button
      await tester.tap(find.text('Alice'));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(sendBtnFinder).onPressed, isNull);

      // Tapping available companion enables Send button
      await tester.tap(find.text('Bob'));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(sendBtnFinder).onPressed, isNotNull);
    });

    testWidgets('ShareWithCompanionSheet hides already-shared tasks, habits, and notes and deduplicates normalized titles/names', (tester) async {
      tester.view.physicalSize = const Size(900, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: ShareWithCompanionSheet(
              companionUserId: 'comp_1',
              companionName: 'Alice',
              initialAlreadySharedEntityIds: const {
                't_shared',
                'h_shared',
                'n_shared',
              },
              initialTasks: [
                Task(id: 't_shared', title: 'Already Shared Task'),
                Task(id: 't_avail_1', title: 'Available Task'),
                Task(id: 't_avail_dup', title: '  available task  '),
              ],
              initialHabits: [
                Habit(id: 'h_shared', name: 'Already Shared Habit'),
                Habit(id: 'h_avail_1', name: 'Morning Run'),
                Habit(id: 'h_avail_dup', name: 'morning run'),
              ],
              initialNotes: [
                Note(
                  id: 'n_shared',
                  title: 'Shared Note',
                  bodyMd: 'Body 1',
                  category: 'note',
                ),
                Note(
                  id: 'n_avail_1',
                  title: 'Fresh Note',
                  bodyMd: 'Body 2',
                  category: 'note',
                ),
                Note(
                  id: 'n_avail_dup',
                  title: 'fresh note',
                  bodyMd: 'Body 3',
                  category: 'note',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Task picker checks
      await tester.tap(find.byKey(const ValueKey('share_type_task')));
      await tester.pumpAndSettle();
      expect(find.text('Already Shared Task'), findsNothing);
      expect(find.byKey(const ValueKey('pick_task_t_avail_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick_task_t_avail_dup')), findsNothing);

      // Habit picker checks
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share_type_habit')));
      await tester.pumpAndSettle();
      expect(find.text('Already Shared Habit'), findsNothing);
      expect(find.byKey(const ValueKey('pick_habit_h_avail_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick_habit_h_avail_dup')), findsNothing);

      // Note picker checks
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share_type_note')));
      await tester.pumpAndSettle();
      expect(find.text('Shared Note'), findsNothing);
      expect(find.byKey(const ValueKey('pick_note_n_avail_1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pick_note_n_avail_dup')), findsNothing);
    });

    testWidgets('PendingSharesSection renders Declined Share Requests banner and dismisses notice on tap', (tester) async {
      final now = DateTime.now();
      final declinedTaskShare = CompanionShare(
        id: 'decl_notice_1',
        senderId: 'user_alpha',
        recipientId: 'user_beta',
        entityType: 'task',
        entityId: 't_1',
        shareMode: 'collaborate',
        status: 'declined',
        previewData: const {'title': 'Quarterly Audit'},
        createdAt: now,
        updatedAt: now,
        senderName: 'Ahmed',
        recipientName: 'Fatima',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PendingSharesSection(
                initialPendingShares: const [],
                initialDeclinedShares: [declinedTaskShare],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DECLINED SHARE REQUESTS'), findsOneWidget);
      expect(
        find.text('Fatima declined your shared task "Quarterly Audit"'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('dismiss_declined_share_decl_notice_1')));
      await tester.pumpAndSettle();

      expect(find.text('DECLINED SHARE REQUESTS'), findsNothing);
    });

    testWidgets('PendingSharesSection opens pre-accept SharedItemPreviewDialog with description and Accept/Decline actions for task, habit, and note', (tester) async {
      final now = DateTime.now();
      final taskShare = CompanionShare(
        id: 'prev_t1',
        senderId: 'user_alpha',
        recipientId: 'user_beta',
        entityType: 'task',
        entityId: 't_1',
        shareMode: 'collaborate',
        status: 'pending',
        previewData: const {
          'title': 'Launch Backend',
          'notes': 'Verify all RLS triggers and push migrations first.',
          'priority': 1,
          'due_date': '2026-11-20',
          'estimate_min': 30,
        },
        createdAt: now,
        updatedAt: now,
        senderName: 'Ahmed',
      );
      final habitShare = CompanionShare(
        id: 'prev_h1',
        senderId: 'user_alpha',
        recipientId: 'user_beta',
        entityType: 'habit',
        entityId: 'h_1',
        shareMode: 'copy',
        status: 'pending',
        previewData: const {
          'title': 'Morning Mobility',
          'schedule_type': 'daily',
          'remind_time': '07:00',
          'target_value': 25,
          'notes': '10-minute neck and back stretch after waking up.',
        },
        createdAt: now,
        updatedAt: now,
        senderName: 'Ahmed',
      );
      final noteShare = CompanionShare(
        id: 'prev_n1',
        senderId: 'user_alpha',
        recipientId: 'user_beta',
        entityType: 'note',
        entityId: 'n_1',
        shareMode: 'copy',
        status: 'pending',
        previewData: const {
          'title': 'System Design Notes',
          'body_md': 'PowerSync sync rules isolate per-user rows by owner_id.',
          'category': 'Architecture',
          'mood': 'CALM FOCUS',
        },
        createdAt: now,
        updatedAt: now,
        senderName: 'Ahmed',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PendingSharesSection(
                initialPendingShares: [taskShare, habitShare, noteShare],
                initialDeclinedShares: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Task preview popup
      await tester.tap(find.byKey(const ValueKey('preview_share_prev_t1')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedItemPreviewDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shared_item_preview_description')),
          matching: find.text('Verify all RLS triggers and push migrations first.'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('preview_dialog_accept_prev_t1')), findsOneWidget);
      expect(find.byKey(const ValueKey('preview_dialog_decline_prev_t1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('preview_dialog_decline_prev_t1')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedItemPreviewDialog), findsNothing);

      // Habit preview popup
      await tester.ensureVisible(find.byKey(const ValueKey('preview_share_prev_h1')));
      await tester.tap(find.byKey(const ValueKey('preview_share_prev_h1')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedItemPreviewDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shared_item_preview_description')),
          matching: find.text('10-minute neck and back stretch after waking up.'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('preview_dialog_accept_prev_h1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('preview_dialog_decline_prev_h1')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedItemPreviewDialog), findsNothing);

      // Note preview popup
      await tester.ensureVisible(find.byKey(const ValueKey('preview_share_prev_n1')));
      await tester.tap(find.byKey(const ValueKey('preview_share_prev_n1')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedItemPreviewDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('shared_item_preview_description')),
          matching: find.text('PowerSync sync rules isolate per-user rows by owner_id.'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('preview_dialog_accept_prev_n1')), findsOneWidget);
      expect(find.byKey(const ValueKey('preview_dialog_decline_prev_n1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('preview_dialog_decline_prev_n1')));
      await tester.pumpAndSettle();
      expect(find.byType(SharedItemPreviewDialog), findsNothing);
    });

    testWidgets('CollaborativeTaskDeletedNoticeBanner shows notice to User A and dismisses cleanly while InboxTab places surviving task in normal tasks', (tester) async {
      final now = DateTime.now();
      final notice = CompanionShare(
        id: 'collab_del_notice_1',
        senderId: 'user_alpha',
        recipientId: 'user_beta',
        entityType: 'task',
        entityId: 't_surviving_1',
        acceptedEntityId: 't_deleted_b_1',
        shareMode: 'collaborate',
        status: 'cancelled',
        previewData: const {
          'title': 'Ship V2',
          'cancelled_by': 'user_beta',
          'cancelled_by_name': 'Fatima',
          'cancellation_reason': 'collaborative_task_deleted',
        },
        createdAt: now,
        updatedAt: now,
        senderName: 'Ahmed',
        recipientName: 'Fatima',
      );

      final fakeRepo = _FakeTaskRepository([
        Task(
          id: 't_surviving_1',
          userId: 'user_alpha',
          title: 'Ship V2',
          status: 'todo',
          isCollaborative: false,
          dueDate: now.toIso8601String().split('T').first,
        ),
      ]);
      final filterCriteria = ValueNotifier(const TaskFilterCriteria());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: CollaborativeTaskDeletedNoticeBanner(
                    initialNotices: [notice],
                  ),
                ),
                Expanded(
                  child: InboxTab(
                    repo: fakeRepo,
                    filterCriteria: filterCriteria,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('COLLABORATIVE TASK NOTICES'), findsOneWidget);
      expect(
        find.text(
          'Fatima deleted collaborative task "Ship V2" — moved to your normal tasks',
        ),
        findsOneWidget,
      );
      expect(find.text('COLLABORATIVE TASKS'), findsNothing);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('Ship V2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('dismiss_declined_share_collab_del_notice_1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('COLLABORATIVE TASK NOTICES'), findsNothing);
      expect(find.text('Ship V2'), findsOneWidget);
    });
  });
}

class _FakeTaskRepository extends TaskRepository {
  final List<Task> tasks;
  _FakeTaskRepository(this.tasks);

  @override
  Stream<List<Task>> watchTasks({int? limit, int? offset}) {
    return Stream.value(tasks);
  }
}

/// Helper wrapper to test the UI card in isolation
class PendingSharesSectionCardTestWrapper extends StatelessWidget {
  final CompanionShare share;
  const PendingSharesSectionCardTestWrapper({super.key, required this.share});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                child: Center(
                  child: Text(
                    share.senderName[0],
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 12, color: AxisColors.textHigh),
                    children: [
                      TextSpan(
                        text: share.senderName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: ' sent you a task copy',
                        style: TextStyle(color: AxisColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'COPY',
                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            share.title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
          ),
          if (share.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              share.notes!,
              style: const TextStyle(fontSize: 11, color: AxisColors.textDim),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(backgroundColor: AxisColors.primary, foregroundColor: Colors.black),
                  child: const Text('Accept Task'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
                child: const Text('Decline'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
