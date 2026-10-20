import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:axis/domain/gamification_engine.dart';

import 'package:axis/core/cache/cache_service.dart';

late PowerSyncDatabase db;
bool _dbInitialized = false;
bool get isDatabaseInitialized => _dbInitialized;
final ValueNotifier<int> globalUserLevel = ValueNotifier<int>(1);

// We define the schema based on SPEC.md §4 Core Data Entities
final schema = Schema([
  const Table('tasks', [
    Column.text('title'),
    Column.text('notes'),
    Column.text('status'), // 'todo', 'done', 'skipped'
    Column.integer('priority'),
    Column.text('project_id'),
    Column.text('tags'), // JSON string or comma separated
    Column.text('due_date'), // YYYY-MM-DD
    Column.text('due_time'), // HH:mm
    Column.integer('estimate_min'),
    Column.text('recurrence_rule'),
    Column.text('recurrence_mode'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('projects', [
    Column.text('name'),
    Column.text('color'),
    Column.text('created_at'),
  ]),
  const Table('tags', [
    Column.text('name'),
    Column.text('color'),
    Column.text('created_at'),
  ]),
  const Table('logs', [
    Column.text('task_id'),
    Column.text('event_type'),
    Column.integer('xp_earned'),
    Column.text('timestamp'),
  ]),
  const Table('habits', [
    Column.text('name'),
    Column.text('icon'),
    Column.text('color'),
    Column.text('kind'),
    Column.integer('target_value'),
    Column.text('unit'),
    Column.text('schedule_type'),
    Column.text('remind_time'),
    Column.integer('sort_order'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('habit_logs', [
    Column.text('habit_id'),
    Column.text('log_date'),
    Column.text('status'),
    Column.integer('value'),
    Column.text('note'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('notes', [
    Column.text('title'),
    Column.text('body_md'),
    Column.integer('pinned'),
    Column.text('category'),
    Column.text('mood'),
    Column.text('energy'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('focus_sessions', [
    Column.text('task_id'),
    Column.text('kind'),
    Column.integer('planned_min'),
    Column.integer('actual_min'),
    Column.text('started_at'),
    Column.text('ended_at'),
    Column.integer('completed'),
    Column.integer('xp_earned'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ])
]);

class SupabaseConnector extends PowerSyncBackendConnector {
  SupabaseConnector() : super();

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return null;
    }
    final token = session.accessToken;
    
    // In production, your backend would generate a secure PowerSync token.
    // For local dev, we use the JWT directly if PowerSync is configured to trust Supabase JWTs.
    return PowerSyncCredentials(
      endpoint: const String.fromEnvironment('POWERSYNC_URL', defaultValue: 'http://localhost:8080'),
      token: token,
      userId: session.user.id,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) {
      return;
    }

    try {
      for (var op in transaction.crud) {
        final table = Supabase.instance.client.from(op.table);
        if (op.op == UpdateType.put) {
          await table.upsert(op.opData!);
        } else if (op.op == UpdateType.patch) {
          await table.update(op.opData!).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          await table.delete().eq('id', op.id);
        }
      }
      await transaction.complete();
    } catch (e) {
      // In real life, handle specific errors
      rethrow;
    }
  }
}

Future<void> openDatabase() async {
  if (_dbInitialized) return;
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'axis_powersync.db');

  db = PowerSyncDatabase(schema: schema, path: path);
  await db.initialize();

  // Connect to Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://localhost:54321'),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'dummy_key'),
  );

  final connector = SupabaseConnector();
  
  // PowerSync runs 100% locally with SQLite for full offline-first functionality.
  // We only engage remote sync streaming when an active authenticated session exists.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.session != null) {
      db.connect(connector: connector);
    } else {
      db.disconnect();
    }
  });

  if (Supabase.instance.client.auth.currentSession != null) {
    db.connect(connector: connector);
  }

  _dbInitialized = true;

  await initCustomLocalTables();
  await syncGlobalUserLevel();
}

Future<void> initCustomLocalTables() async {
  if (!_dbInitialized) return;
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile (
        id TEXT PRIMARY KEY,
        name TEXT,
        title TEXT,
        avatar_color TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS habit_categories (
        id TEXT PRIMARY KEY,
        name TEXT UNIQUE,
        icon TEXT,
        color TEXT
      )
    ''');

    // Seed default habit categories if table is empty
    final catCount = await db.get('SELECT COUNT(*) as cnt FROM habit_categories');
    if ((catCount['cnt'] as num?)?.toInt() == 0) {
      final defaults = [
        ['cat_workout', 'Workout', 'fitness', '#10B981'],
        ['cat_reading', 'Reading', 'book', '#38BDF8'],
        ['cat_mindful', 'Mindful', 'meditation', '#A855F7'],
        ['cat_hydrate', 'Hydrate', 'water', '#06B6D4'],
        ['cat_code', 'Code', 'code', '#6366F1'],
        ['cat_rest', 'Rest', 'sleep', '#F59E0B'],
      ];
      for (final def in defaults) {
        await db.execute(
          'INSERT OR IGNORE INTO habit_categories (id, name, icon, color) VALUES (?, ?, ?, ?)',
          def,
        );
      }
    }

    // Seed default tags if table is empty
    final tagCount = await db.get('SELECT COUNT(*) as cnt FROM tags');
    if ((tagCount['cnt'] as num?)?.toInt() == 0) {
      final defaultTags = [
        'urgent',
        'deepwork',
        'meeting',
        'review',
        'errand',
        'backend',
        'frontend'
      ];
      for (final t in defaultTags) {
        await db.execute(
          'INSERT OR IGNORE INTO tags (id, name, color, created_at) VALUES (?, ?, ?, ?)',
          ['tag_$t', t, '#6366F1', DateTime.now().toUtc().toIso8601String()],
        );
      }
    }

    // High-performance database indexes for filtering and sorting
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_due_date ON tasks(due_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_status_due ON tasks(status, due_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_project ON tasks(project_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_logs_habit_date ON habit_logs(habit_id, log_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_logs_date_status ON habit_logs(log_date, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_habits_sort_order ON habits(sort_order)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_habits_kind ON habits(kind)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON logs(timestamp)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_task_event ON logs(task_id, event_type)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_focus_sessions_completed ON focus_sessions(completed, started_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_pinned_created ON notes(pinned, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_category ON notes(category)');
  } catch (_) {}
}

Future<void> syncGlobalUserLevel() async {
  if (!_dbInitialized) return;
  try {
    final logRow = await db.getOptional('SELECT COALESCE(SUM(xp_earned), 0) AS total FROM logs');
    final focusRow = await db.getOptional(
      'SELECT COALESCE(SUM(xp_earned), 0) AS total FROM focus_sessions WHERE completed = 1',
    );
    final logTotal = (logRow?['total'] as num?)?.toInt() ?? 0;
    final focusTotal = (focusRow?['total'] as num?)?.toInt() ?? 0;
    final lvl = GamificationEngine.calculateLevel(logTotal + focusTotal);
    globalUserLevel.value = lvl;
  } catch (_) {}
}

Future<void> resetAllData() async {
  if (!_dbInitialized) return;
  try {
    await db.execute('DELETE FROM tasks');
    await db.execute('DELETE FROM projects');
    await db.execute('DELETE FROM tags');
    await db.execute('DELETE FROM logs');
    await db.execute('DELETE FROM habits');
    await db.execute('DELETE FROM habit_logs');
    await db.execute('DELETE FROM notes');
    await db.execute('DELETE FROM focus_sessions');
    await db.execute('DELETE FROM habit_categories');
    await db.execute('DELETE FROM user_profile');
    globalUserLevel.value = 1;
    CacheService().clear();
    await initCustomLocalTables();
  } catch (_) {}
}

