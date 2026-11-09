import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/friends/friend_models.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/domain/streak_engine.dart';

void main() {
  group('Comprehensive System Stress & Capacity Tests', () {
    // -------------------------------------------------------------
    // TEST 1: 1,000 Companions (Friends & Accountability Partners)
    // -------------------------------------------------------------
    test('Stress Test: 1,000 Companions Allocation, Sorting & Memory', () {
      final initialMemory = ProcessInfo.currentRss;
      final sw = Stopwatch()..start();

      final companions = List<FriendUser>.generate(1000, (i) {
        return FriendUser(
          id: 'prof_$i',
          friendshipId: 'fs_$i',
          userId: 'user_$i',
          name: 'Companion Officer $i',
          title: i % 2 == 0 ? 'Tactical Strategist' : 'Senior Specialist',
          avatarColor: '#10B981',
          totalXp: (i * 37) % 50000,
          level: 1 + (i % 60),
          friendCode: 'AXIS-${1000 + i}',
        );
      });

      final allocTime = sw.elapsedMilliseconds;
      sw.reset();

      // Sort by totalXp descending (Standings tab logic)
      companions.sort((a, b) => b.totalXp.compareTo(a.totalXp));
      final sortTime = sw.elapsedMilliseconds;

      final memoryDeltaMb = (ProcessInfo.currentRss - initialMemory) / (1024 * 1024);

      print('=== 1,000 COMPANIONS STRESS TEST ===');
      print('Allocated: ${companions.length} companions in ${allocTime}ms');
      print('Sorted 1,000 companions in ${sortTime}ms');
      print('Estimated RSS Delta: ${memoryDeltaMb.toStringAsFixed(2)} MB');
      print('Status: Fully Supported. No crash.');

      expect(companions.length, equals(1000));
      expect(companions.first.totalXp >= companions.last.totalXp, isTrue);
      expect(allocTime, lessThan(100)); // Should take < 100ms
      expect(sortTime, lessThan(50));   // Should take < 50ms
    });

    // -------------------------------------------------------------
    // TEST 2: 200 Projects
    // -------------------------------------------------------------
    test('Stress Test: 200 Projects Allocation & Sorting', () {
      final initialMemory = ProcessInfo.currentRss;
      final sw = Stopwatch()..start();

      final projects = List<Project>.generate(200, (i) {
        return Project(
          id: 'proj_$i',
          name: 'Project Mission Alpha #$i',
          color: '#6366F1',
          createdAt: DateTime.now().subtract(Duration(days: i)),
        );
      });

      final allocTime = sw.elapsedMilliseconds;
      sw.reset();

      // Sort chronologically
      projects.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final sortTime = sw.elapsedMilliseconds;

      final memoryDeltaMb = (ProcessInfo.currentRss - initialMemory) / (1024 * 1024);

      print('=== 200 PROJECTS STRESS TEST ===');
      print('Allocated: ${projects.length} projects in ${allocTime}ms');
      print('Sorted in ${sortTime}ms');
      print('Estimated RSS Delta: ${memoryDeltaMb.toStringAsFixed(2)} MB');
      print('Status: Fully Supported. No crash.');

      expect(projects.length, equals(200));
      expect(allocTime, lessThan(50));
    });

    // -------------------------------------------------------------
    // TEST 3: 200 Habit Categories
    // -------------------------------------------------------------
    test('Stress Test: 200 Habit Categories Allocation & Mapping', () {
      final sw = Stopwatch()..start();

      final categories = List<HabitCategory>.generate(200, (i) {
        return HabitCategory(
          id: 'cat_habit_$i',
          name: 'Habit Domain Sector $i',
          icon: 'fitness',
          color: '#3B82F6',
        );
      });

      final allocTime = sw.elapsedMilliseconds;
      sw.reset();

      final categoryMap = {for (final c in categories) c.id: c};
      final mapTime = sw.elapsedMilliseconds;

      print('=== 200 HABIT CATEGORIES STRESS TEST ===');
      print('Allocated: ${categories.length} categories in ${allocTime}ms');
      print('Indexed into Map in ${mapTime}ms');
      print('Status: Fully Supported. No crash.');

      expect(categories.length, equals(200));
      expect(categoryMap.length, equals(200));
      expect(allocTime, lessThan(50));
    });

    // -------------------------------------------------------------
    // TEST 4: 200 Note Categories
    // -------------------------------------------------------------
    test('Stress Test: 200 Note Categories Allocation & Tree Lookup', () {
      final sw = Stopwatch()..start();

      final noteCategories = List<NoteCategory>.generate(200, (i) {
        return NoteCategory(
          id: 'cat_note_$i',
          name: 'Knowledge Vault $i',
          icon: 'folder',
          color: '#EC4899',
        );
      });

      final allocTime = sw.elapsedMilliseconds;
      print('=== 200 NOTE CATEGORIES STRESS TEST ===');
      print('Allocated: ${noteCategories.length} note categories in ${allocTime}ms');
      print('Status: Fully Supported. No crash.');

      expect(noteCategories.length, equals(200));
      expect(allocTime, lessThan(50));
    });

    // -------------------------------------------------------------
    // TEST 5: 300 Habits & Streak Calculations
    // -------------------------------------------------------------
    test('Stress Test: 300 Habits & Streak Calculations', () {
      final sw = Stopwatch()..start();

      final habits = List<Habit>.generate(300, (i) {
        return Habit(
          id: 'habit_$i',
          name: 'Discipline Practice #$i',
          category: 'Health & Focus',
          scheduleType: i % 3 == 0 ? 'weekly' : 'daily',
          remindTime: '${(i % 12 + 1).toString().padLeft(2, '0')}:00 ${i % 2 == 0 ? 'AM' : 'PM'}',
          sortOrder: i,
          isDoneToday: i % 2 == 0,
        );
      });

      final allocTime = sw.elapsedMilliseconds;
      sw.reset();

      // Sort habits by time (as done in UI)
      habits.sort(HabitRepository.compareByTime);
      final sortTime = sw.elapsedMilliseconds;
      sw.reset();

      // Run 300 streak calculations with 60 days of logs each
      final nowStr = '2026-11-09';
      int calculatedStreaks = 0;
      for (final habit in habits) {
        final mockLogs = List.generate(60, (d) {
          final dateStr = '2026-10-${(d % 30 + 1).toString().padLeft(2, '0')}';
          return StreakLog(dateStr, d % 2 == 0 ? 'completed' : 'skipped');
        });
        final streak = StreakEngine.calculateStreak(habit.scheduleType, mockLogs, nowStr);
        if (streak >= 0) calculatedStreaks++;
      }
      final streakTime = sw.elapsedMilliseconds;

      print('=== 300 HABITS STRESS TEST ===');
      print('Allocated: ${habits.length} habits in ${allocTime}ms');
      print('Sorted by time in ${sortTime}ms');
      print('Calculated 300 habit streaks (60 days logs each) in ${streakTime}ms');
      print('Status: Fully Supported. No crash.');

      expect(habits.length, equals(300));
      expect(calculatedStreaks, equals(300));
      expect(streakTime, lessThan(250)); // Fast calculation
    });

    // -------------------------------------------------------------
    // TEST 6: SQLite & Memory Scale for Journals (up to 300,000)
    // -------------------------------------------------------------
    test('Stress Test: SQLite Engine & Memory for Journals (up to 300,000)', () {
      final db = sqlite.sqlite3.openInMemory();
      db.execute('''
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
        CREATE INDEX idx_notes_user_cat ON notes (user_id, category, pinned, created_at);
      ''');

      print('=== JOURNALS SCALING & STRESS TEST (Target: 300,000) ===');

      // Test scaling checkpoints: 1,000, 10,000, 50,000, 100,000, 300,000
      final checkpoints = [1000, 10000, 50000, 100000, 300000];
      int currentCount = 0;

      final insertStmt = db.prepare('''
        INSERT INTO notes (id, user_id, title, body_md, category, mood, energy, pinned, created_at, updated_at)
        VALUES (?, 'u1', ?, ?, 'journal', 'HIGH ENERGY', 'Optimal', 0, '2026-11-09T10:00:00Z', '2026-11-09T10:00:00Z')
      ''');

      for (final target in checkpoints) {
        final toAdd = target - currentCount;
        final sw = Stopwatch()..start();

        db.execute('BEGIN TRANSACTION');
        for (int i = currentCount; i < target; i++) {
          insertStmt.execute([
            'journal_$i',
            'Journal Entry #$i: Daily Tactical Debrief',
            'Today completed 14 tactical objectives. Energy remained at peak levels through deep focus sessions. Key takeaway: maintain strict morning buffer.',
          ]);
        }
        db.execute('COMMIT');
        final insertTime = sw.elapsedMilliseconds;
        currentCount = target;

        // Measure Paged Query (LIMIT 50)
        sw.reset();
        final pagedRows = db.select(
          'SELECT * FROM notes WHERE category = ? AND user_id = ? ORDER BY pinned DESC, created_at DESC LIMIT 50',
          ['journal', 'u1'],
        );
        final pagedQueryTime = sw.elapsedMilliseconds;

        // Measure Unpaged Query (Full table scan without LIMIT as currently done in NoteRepository)
        sw.reset();
        final unpagedRows = db.select(
          'SELECT * FROM notes WHERE category = ? AND user_id = ? ORDER BY pinned DESC, created_at DESC',
          ['journal', 'u1'],
        );
        final unpagedQueryTime = sw.elapsedMilliseconds;

        // Measure In-Memory Dart Object Mapping
        sw.reset();
        int mappedCount = 0;
        for (final row in unpagedRows) {
          final note = Note.fromRow(row);
          if (note.id.isNotEmpty) mappedCount++;
        }
        final mappingTime = sw.elapsedMilliseconds;

        final currentRssMb = ProcessInfo.currentRss / (1024 * 1024);

        print('--- Checkpoint: $target Journals ---');
        print('  Insertion time (${toAdd} rows): ${insertTime}ms');
        print('  Paged query (LIMIT 50): ${pagedQueryTime}ms (fetched ${pagedRows.length} rows)');
        print('  Unpaged query (SELECT *): ${unpagedQueryTime}ms (fetched ${unpagedRows.length} rows)');
        print('  In-memory Dart deserialization: ${mappingTime}ms');
        print('  Process RSS Memory: ${currentRssMb.toStringAsFixed(1)} MB');

        expect(unpagedRows.length, equals(target));
        expect(pagedRows.length, equals(50));
      }

      insertStmt.dispose();
      db.dispose();
    });

    // -------------------------------------------------------------
    // TEST 7: SQLite & Memory Scale for Tasks (up to 1,000,000)
    // -------------------------------------------------------------
    test('Stress Test: SQLite Engine & Memory for Tasks (up to 1,000,000)', () {
      final db = sqlite.sqlite3.openInMemory();
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
        CREATE INDEX idx_tasks_user_status ON tasks (user_id, status, created_at);
        CREATE INDEX idx_tasks_due_date ON tasks (user_id, due_date, status);
      ''');

      print('=== TASKS SCALING & STRESS TEST (Target: 1,000,000) ===');

      final checkpoints = [1000, 10000, 50000, 100000, 250000, 500000, 1000000];
      int currentCount = 0;

      final insertStmt = db.prepare('''
        INSERT INTO tasks (
          id, user_id, title, notes, status, priority, project_id, tags, due_date, due_time, estimate_min, created_at, updated_at
        ) VALUES (
          ?, 'u1', ?, 'Sample execution details and checklist items', 'todo', ?, 'proj_1', 'work,core', '2026-11-15', '14:00', 30, '2026-11-09T10:00:00Z', '2026-11-09T10:00:00Z'
        )
      ''');

      for (final target in checkpoints) {
        final toAdd = target - currentCount;
        final sw = Stopwatch()..start();

        db.execute('BEGIN TRANSACTION');
        for (int i = currentCount; i < target; i++) {
          insertStmt.execute([
            'task_$i',
            'Execute Operational Objective #$i',
            (i % 3) + 1,
          ]);
        }
        db.execute('COMMIT');
        final insertTime = sw.elapsedMilliseconds;
        currentCount = target;

        // Measure Paged Query (LIMIT 50)
        sw.reset();
        final pagedRows = db.select(
          "SELECT * FROM tasks WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '') ORDER BY created_at DESC LIMIT 50",
          ['u1'],
        );
        final pagedQueryTime = sw.elapsedMilliseconds;

        // Measure Unpaged Query up to 250k (above 250k unpaged in a single query takes high RAM)
        int unpagedQueryTime = -1;
        int rowCount = 0;
        int mappingTime = -1;

        if (target <= 250000) {
          sw.reset();
          final unpagedRows = db.select(
            "SELECT * FROM tasks WHERE user_id = ? AND (deleted_at IS NULL OR deleted_at = '') ORDER BY created_at DESC",
            ['u1'],
          );
          unpagedQueryTime = sw.elapsedMilliseconds;
          rowCount = unpagedRows.length;

          // Benchmark Dart Task.fromRow mapping
          sw.reset();
          int mapped = 0;
          for (final row in unpagedRows) {
            final t = Task.fromRow(row);
            if (t.id.isNotEmpty) mapped++;
          }
          mappingTime = sw.elapsedMilliseconds;
        } else {
          // Count only to verify SQLite holds the rows without loading all into memory
          sw.reset();
          final countRow = db.select('SELECT COUNT(*) as cnt FROM tasks WHERE user_id = ?', ['u1']);
          rowCount = countRow.first['cnt'] as int;
          unpagedQueryTime = sw.elapsedMilliseconds;
        }

        final currentRssMb = ProcessInfo.currentRss / (1024 * 1024);

        print('--- Checkpoint: $target Tasks ---');
        print('  Insertion time (${toAdd} rows): ${insertTime}ms');
        print('  Paged query (LIMIT 50): ${pagedQueryTime}ms (fetched ${pagedRows.length} rows)');
        if (target <= 250000) {
          print('  Unpaged query (SELECT *): ${unpagedQueryTime}ms (fetched $rowCount rows)');
          print('  In-memory Dart deserialization: ${mappingTime}ms');
        } else {
          print('  Database verified count: $rowCount rows (COUNT query: ${unpagedQueryTime}ms)');
          print('  [OOM Warning]: Loading $target tasks into unpaged List<Task> requires ~${(target * 0.0012).toStringAsFixed(0)}MB RAM!');
        }
        print('  Process RSS Memory: ${currentRssMb.toStringAsFixed(1)} MB');

        expect(rowCount, equals(target));
        expect(pagedRows.length, equals(50));
      }

      insertStmt.dispose();
      db.dispose();
    });

    // -------------------------------------------------------------
    // TEST 8: SQLite & Memory Scale for Notes (up to 1,000,000)
    // -------------------------------------------------------------
    test('Stress Test: SQLite Engine & Memory for Notes (up to 1,000,000)', () {
      final db = sqlite.sqlite3.openInMemory();
      db.execute('''
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
        CREATE INDEX idx_notes_user_cat ON notes (user_id, category, pinned, created_at);
      ''');

      print('=== NOTES SCALING & STRESS TEST (Target: 1,000,000) ===');

      final checkpoints = [1000, 10000, 50000, 100000, 250000, 500000, 1000000];
      int currentCount = 0;

      final insertStmt = db.prepare('''
        INSERT INTO notes (id, user_id, title, body_md, category, pinned, created_at, updated_at)
        VALUES (?, 'u1', ?, ?, 'note', 0, '2026-11-09T10:00:00Z', '2026-11-09T10:00:00Z')
      ''');

      for (final target in checkpoints) {
        final toAdd = target - currentCount;
        final sw = Stopwatch()..start();

        db.execute('BEGIN TRANSACTION');
        for (int i = currentCount; i < target; i++) {
          insertStmt.execute([
            'note_$i',
            'Knowledge Base Document #$i',
            '# Architecture Overview\nDetailed documentation on modules and reactive stream management.\n- Item A\n- Item B\n',
          ]);
        }
        db.execute('COMMIT');
        final insertTime = sw.elapsedMilliseconds;
        currentCount = target;

        // Measure Paged Query (LIMIT 50)
        sw.reset();
        final pagedRows = db.select(
          'SELECT * FROM notes WHERE category = ? AND user_id = ? ORDER BY pinned DESC, created_at DESC LIMIT 50',
          ['note', 'u1'],
        );
        final pagedQueryTime = sw.elapsedMilliseconds;

        // Measure count or unpaged query
        int queryTime = 0;
        int rowCount = 0;
        if (target <= 100000) {
          sw.reset();
          final unpagedRows = db.select(
            'SELECT * FROM notes WHERE category = ? AND user_id = ? ORDER BY pinned DESC, created_at DESC',
            ['note', 'u1'],
          );
          queryTime = sw.elapsedMilliseconds;
          rowCount = unpagedRows.length;
        } else {
          sw.reset();
          final countRow = db.select('SELECT COUNT(*) as cnt FROM notes WHERE category = ? AND user_id = ?', ['note', 'u1']);
          queryTime = sw.elapsedMilliseconds;
          rowCount = countRow.first['cnt'] as int;
        }

        final currentRssMb = ProcessInfo.currentRss / (1024 * 1024);

        print('--- Checkpoint: $target Notes ---');
        print('  Insertion time (${toAdd} rows): ${insertTime}ms');
        print('  Paged query (LIMIT 50): ${pagedQueryTime}ms (fetched ${pagedRows.length} rows)');
        print('  Verified count / Query time: ${queryTime}ms (total: $rowCount notes)');
        print('  Process RSS Memory: ${currentRssMb.toStringAsFixed(1)} MB');

        expect(rowCount, equals(target));
        expect(pagedRows.length, equals(50));
      }

      insertStmt.dispose();
      db.dispose();
    });
  });
}
