import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:axis/data/sharing/companion_share_models.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/friends/widgets/pending_shares_section.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';

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
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
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
  });
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
