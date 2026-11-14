import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('Repository Limit & Offset Pagination Unit Tests', () {
    late sqlite.Database db;

    setUp(() {
      db = sqlite.sqlite3.openInMemory();
      db.execute('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT,
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
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        );

        CREATE TABLE notes (
          id TEXT PRIMARY KEY,
          user_id TEXT,
          title TEXT,
          body_md TEXT,
          category TEXT,
          mood TEXT,
          energy TEXT,
          pinned INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT,
          deleted_at TEXT
        );
      ''');

      // Populate 50 tasks
      final insertTask = db.prepare('''
        INSERT INTO tasks (id, user_id, title, status, created_at, updated_at)
        VALUES (?, 'u1', ?, 'todo', ?, ?)
      ''');
      for (int i = 0; i < 50; i++) {
        final date = '2026-11-09T10:${i.toString().padLeft(2, '0')}:00Z';
        insertTask.execute(['task_$i', 'Task #$i', date, date]);
      }
      insertTask.dispose();

      // Populate 50 notes
      final insertNote = db.prepare('''
        INSERT INTO notes (id, user_id, title, body_md, category, pinned, created_at, updated_at)
        VALUES (?, 'u1', ?, 'Body text', ?, 0, ?, ?)
      ''');
      for (int i = 0; i < 50; i++) {
        final date = '2026-11-09T10:${i.toString().padLeft(2, '0')}:00Z';
        final cat = i % 2 == 0 ? 'note' : 'journal';
        insertNote.execute(['note_$i', 'Note #$i', cat, date, date]);
      }
      insertNote.dispose();
    });

    tearDown(() {
      db.dispose();
    });

    test('SQLite tasks table obeys LIMIT and OFFSET paging correctly', () {
      final pagedPage1 = db.select('''
        SELECT * FROM tasks WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '')
        ORDER BY created_at DESC LIMIT 10 OFFSET 0
      ''', ['u1']);

      expect(pagedPage1.length, equals(10));
      // First task should be task_49 (most recent)
      expect(pagedPage1.first['id'], equals('task_49'));
      expect(pagedPage1.last['id'], equals('task_40'));

      final pagedPage2 = db.select('''
        SELECT * FROM tasks WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '')
        ORDER BY created_at DESC LIMIT 10 OFFSET 10
      ''', ['u1']);

      expect(pagedPage2.length, equals(10));
      expect(pagedPage2.first['id'], equals('task_39'));
      expect(pagedPage2.last['id'], equals('task_30'));
    });

    test('SQLite notes table obeys category filter with LIMIT and OFFSET paging', () {
      final journalPage1 = db.select('''
        SELECT * FROM notes WHERE category = ? AND user_id = ? AND (deleted_at IS NULL OR deleted_at = '')
        ORDER BY pinned DESC, created_at DESC LIMIT 5 OFFSET 0
      ''', ['journal', 'u1']);

      expect(journalPage1.length, equals(5));
      for (final row in journalPage1) {
        expect(row['category'], equals('journal'));
      }

      final journalPage2 = db.select('''
        SELECT * FROM notes WHERE category = ? AND user_id = ? AND (deleted_at IS NULL OR deleted_at = '')
        ORDER BY pinned DESC, created_at DESC LIMIT 5 OFFSET 5
      ''', ['journal', 'u1']);

      expect(journalPage2.length, equals(5));
      // Page 2 items should not overlap with Page 1 items
      final p1Ids = journalPage1.map((r) => r['id']).toSet();
      for (final row in journalPage2) {
        expect(p1Ids.contains(row['id']), isFalse);
      }
    });
  });
}

