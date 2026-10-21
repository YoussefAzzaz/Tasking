import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/domain/id_generator.dart';

import 'package:axis/core/cache/cache_service.dart';

late PowerSyncDatabase db;
bool _dbInitialized = false;
bool get isDatabaseInitialized => _dbInitialized;
final ValueNotifier<int> globalUserLevel = ValueNotifier<int>(1);

const String kDefaultSupabaseUrl = 'https://hzyvdkgdkxbxooatrzwy.supabase.co';
const String kDefaultSupabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6eXZka2dka3hieG9vYXRyend5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0NDkyOTAsImV4cCI6MjEwODAyNTI5MH0.qZRq2nz-vdipPqdmtIZZXstlub7q4HTUZmgIxsSUWlA';
const String kDefaultPowerSyncUrl =
    'https://6ad7e4283b1803753bd362b7.powersync.journeyapps.com';

String _cachedUserId = '';
void setCachedUserId(String id) => _cachedUserId = id;

String get currentUserId {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      _cachedUserId = uid;
      return uid;
    }
  } catch (_) {}
  return _cachedUserId;
}

// We define the schema based on SPEC.md §4 Core Data Entities with user_id multi-user isolation
final schema = Schema([
  const Table('tasks', [
    Column.text('user_id'),
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
    Column.text('user_id'),
    Column.text('name'),
    Column.text('color'),
    Column.text('created_at'),
  ]),
  const Table('tags', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('color'),
    Column.text('created_at'),
  ]),
  const Table('logs', [
    Column.text('user_id'),
    Column.text('task_id'),
    Column.text('event_type'),
    Column.integer('xp_earned'),
    Column.text('timestamp'),
  ]),
  const Table('habits', [
    Column.text('user_id'),
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
    Column.text('user_id'),
    Column.text('habit_id'),
    Column.text('log_date'),
    Column.text('status'),
    Column.integer('value'),
    Column.text('note'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('notes', [
    Column.text('user_id'),
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
    Column.text('user_id'),
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
  ]),
  const Table('habit_categories', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('icon'),
    Column.text('color'),
    Column.integer('sort_order'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('prayers', [
    Column.text('user_id'),
    Column.text('prayer_code'),
    Column.text('name'),
    Column.text('icon'),
    Column.text('time'),
    Column.integer('sort_order'),
    Column.integer('is_done'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  const Table('user_profiles', [
    Column.text('user_id'),
    Column.text('name'),
    Column.text('title'),
    Column.text('avatar_color'),
    Column.integer('total_xp'),
    Column.integer('level'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
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

    return PowerSyncCredentials(
      endpoint: const String.fromEnvironment('POWERSYNC_URL', defaultValue: kDefaultPowerSyncUrl),
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
      final user = Supabase.instance.client.auth.currentUser;
      final uid = user?.id ?? currentUserId;
      for (var op in transaction.crud) {
        final table = Supabase.instance.client.from(op.table);
        if (op.op == UpdateType.put) {
          final data = Map<String, dynamic>.from(op.opData!);
          data['id'] = op.id;
          if (uid.isNotEmpty && (!data.containsKey('user_id') || data['user_id'] == null || (data['user_id'] as String).isEmpty)) {
            data['user_id'] = uid;
          }
          await table.upsert(data);
        } else if (op.op == UpdateType.patch) {
          final data = Map<String, dynamic>.from(op.opData!);
          if (uid.isNotEmpty && (!data.containsKey('user_id') || data['user_id'] == null || (data['user_id'] as String).isEmpty)) {
            data['user_id'] = uid;
          }
          await table.update(data).eq('id', op.id);
        } else if (op.op == UpdateType.delete) {
          if (uid.isNotEmpty) {
            await table.delete().eq('id', op.id).eq('user_id', uid);
          } else {
            await table.delete().eq('id', op.id);
          }
        }
      }
      await transaction.complete();
    } on PostgrestException catch (e) {
      debugPrint('[PowerSync SupabaseConnector] PostgrestException [${e.code}]: ${e.message}');
      final code = e.code ?? '';
      final isFatal = code.startsWith('22') ||
          code.startsWith('23') ||
          code.startsWith('42') ||
          code == 'PGRST116' ||
          code == 'PGRST204';
      if (isFatal) {
        debugPrint('[PowerSync SupabaseConnector] Discarding fatal transaction to unblock sync queue: ${e.message}');
        await transaction.complete();
      } else {
        rethrow;
      }
    } catch (e) {
      debugPrint('[PowerSync SupabaseConnector] upload error: $e');
      rethrow;
    }
  }
}

Future<void> clearUserDataOnSignOut() async {
  if (!_dbInitialized) return;
  try {
    try {
      await db.disconnectAndClear();
    } catch (_) {}
    await db.execute('DELETE FROM tasks');
    await db.execute('DELETE FROM projects');
    await db.execute('DELETE FROM tags');
    await db.execute('DELETE FROM logs');
    await db.execute('DELETE FROM habits');
    await db.execute('DELETE FROM habit_logs');
    await db.execute('DELETE FROM notes');
    await db.execute('DELETE FROM focus_sessions');
    await db.execute('DELETE FROM habit_categories');
    await db.execute('DELETE FROM local_habit_categories');
    await db.execute('DELETE FROM prayers');
    await db.execute('DELETE FROM user_profiles');
    await db.execute('DELETE FROM local_auth_session');
    _cachedUserId = '';
    globalUserLevel.value = 1;
    CacheService().clear();
  } catch (e) {
    debugPrint('[PowerSync] Error clearing user data on sign out: $e');
  }
}

Future<void> purgeForeignUserData() async {
  if (!_dbInitialized) return;
  final uid = currentUserId;
  if (uid.isEmpty) return;
  try {
    // 0. Remove legacy prayers from generic habits table
    await db.execute("DELETE FROM habits WHERE kind = 'Prayers' OR id LIKE 'habit_prayer_%'");

    // 1. Claim any local orphan records that were created without a user_id
    await db.execute("UPDATE tasks SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE projects SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE tags SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE habits SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE habit_logs SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE notes SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE focus_sessions SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE logs SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE habit_categories SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE local_habit_categories SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE prayers SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);
    await db.execute("UPDATE user_profiles SET user_id = ? WHERE user_id IS NULL OR user_id = ''", [uid]);

    // 2. Remove any records belonging to any other user
    await db.execute('DELETE FROM tasks WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM projects WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM tags WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM habits WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM habit_logs WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM notes WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM focus_sessions WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM logs WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM habit_categories WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM local_habit_categories WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM prayers WHERE user_id != ?', [uid]);
    await db.execute('DELETE FROM user_profiles WHERE user_id != ?', [uid]);
  } catch (e) {
    debugPrint('[PowerSync] Error in purgeForeignUserData: $e');
  }
}

void _cleanupConflictingLegacyTables(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return;

    final rawDb = sqlite.sqlite3.open(path);
    try {
      final tablesToInspect = [
        'habit_categories',
        'prayers',
        'user_profiles',
        'user_profile',
      ];
      for (final name in tablesToInspect) {
        final rows = rawDb.select(
          "SELECT type FROM sqlite_master WHERE name = ?",
          [name],
        );
        if (rows.isNotEmpty && rows.first['type'] == 'table') {
          debugPrint(
              '[PowerSync] Migrating legacy physical table "$name" to PowerSync view');
          rawDb.execute('DROP TABLE IF EXISTS "$name"');
        }
      }
    } finally {
      rawDb.close();
    }
  } catch (e) {
    debugPrint('[PowerSync] Pre-init legacy table check notice: $e');
  }
}

Future<void> openDatabase() async {
  if (_dbInitialized) return;
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'axis_powersync.db');

  _cleanupConflictingLegacyTables(path);

  db = PowerSyncDatabase(schema: schema, path: path);
  await db.initialize();

  // Connect to Supabase
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL', defaultValue: kDefaultSupabaseUrl),
    publishableKey: const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: kDefaultSupabaseAnonKey),
  );

  final connector = SupabaseConnector();

  // PowerSync runs 100% locally with SQLite for full offline-first functionality.
  // We only engage remote sync streaming when an active authenticated session exists.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    if (data.session != null) {
      setCachedUserId(data.session!.user.id);
      db.connect(connector: connector);
      await purgeForeignUserData();
      await syncGlobalUserLevel();
    } else {
      try {
        await db.disconnect();
      } catch (_) {}
    }
  });

  if (Supabase.instance.client.auth.currentSession != null) {
    db.connect(connector: connector);
  }

  // Automatically ensure foreign data is cleaned whenever sync connects or reconnects
  db.statusStream.listen((status) async {
    if (status.connected && currentUserId.isNotEmpty) {
      await purgeForeignUserData();
    }
  });

  _dbInitialized = true;

  await initCustomLocalTables();
  await purgeForeignUserData();
  await syncGlobalUserLevel();
}

Future<void> initCustomLocalTables() async {
  if (!_dbInitialized) return;
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_auth_session (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        email TEXT NOT NULL,
        display_name TEXT,
        cached_password TEXT,
        last_login_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_habit_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL DEFAULT 'fitness',
        color TEXT NOT NULL DEFAULT '#10B981',
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    // Purge legacy prayer habits, legacy prayer categories, legacy default categories, and legacy default projects
    await db.execute("DELETE FROM habits WHERE kind = 'Prayers' OR id LIKE 'habit_prayer_%'");
    await db.execute("DELETE FROM habit_categories WHERE id = 'cat_prayers' OR LOWER(name) = 'prayers'");
    await db.execute("DELETE FROM local_habit_categories WHERE id = 'cat_prayers' OR LOWER(name) = 'prayers'");
    await db.execute("DELETE FROM habit_categories WHERE id IN ('cat_workout', 'cat_reading', 'cat_mindful', 'cat_hydrate', 'cat_code', 'cat_rest')");
    await db.execute("DELETE FROM local_habit_categories WHERE id IN ('cat_workout', 'cat_reading', 'cat_mindful', 'cat_hydrate', 'cat_code', 'cat_rest')");
    await db.execute("DELETE FROM projects WHERE id IN ('work', 'personal', 'growth')");

    final uid = currentUserId;

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
        final tagId = IdGenerator.generateDeterministicId('tag_$t');
        await db.execute(
          'INSERT OR IGNORE INTO tags (id, user_id, name, color, created_at) VALUES (?, ?, ?, ?, ?)',
          [tagId, uid, t, '#6366F1', DateTime.now().toUtc().toIso8601String()],
        );
      }
    }

    // High-performance database indexes for user isolation, filtering and sorting
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_user_id ON tasks(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_projects_user_id ON projects(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tags_user_id ON tags(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_habits_user_id ON habits(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_logs_user_id ON habit_logs(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_user_id ON notes(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_focus_sessions_user_id ON focus_sessions(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_logs_user_id ON logs(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_habit_categories_user_id ON habit_categories(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prayers_user_id ON prayers(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_prayers_user_sort ON prayers(user_id, sort_order)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id)');

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
    final uid = currentUserId;
    final logQuery = uid.isNotEmpty
        ? 'SELECT COALESCE(SUM(xp_earned), 0) AS total FROM logs WHERE user_id = ?'
        : 'SELECT COALESCE(SUM(xp_earned), 0) AS total FROM logs';
    final focusQuery = uid.isNotEmpty
        ? 'SELECT COALESCE(SUM(xp_earned), 0) AS total FROM focus_sessions WHERE completed = 1 AND user_id = ?'
        : 'SELECT COALESCE(SUM(xp_earned), 0) AS total FROM focus_sessions WHERE completed = 1';
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    final logRow = await db.getOptional(logQuery, params);
    final focusRow = await db.getOptional(focusQuery, params);
    final logTotal = (logRow?['total'] as num?)?.toInt() ?? 0;
    final focusTotal = (focusRow?['total'] as num?)?.toInt() ?? 0;
    final totalXp = logTotal + focusTotal;

    int effectiveXp = totalXp;
    if (uid.isNotEmpty) {
      final existingProfile = await db.getOptional(
        'SELECT total_xp, level FROM user_profiles WHERE user_id = ?',
        [uid],
      );
      if (existingProfile != null) {
        final profileXp = (existingProfile['total_xp'] as num?)?.toInt() ?? 0;
        if (profileXp > effectiveXp) {
          effectiveXp = profileXp;
        }
      }
    }

    final lvl = GamificationEngine.calculateLevel(effectiveXp);
    globalUserLevel.value = lvl;

    if (uid.isNotEmpty) {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final profileId = IdGenerator.generateDeterministicId('profile_$uid');
      await db.execute('''
        INSERT INTO user_profiles (id, user_id, name, title, avatar_color, total_xp, level, created_at, updated_at)
        VALUES (?, ?, 'Commander', 'Specialist', '#6366F1', ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          total_xp = excluded.total_xp,
          level = excluded.level,
          updated_at = excluded.updated_at
      ''', [profileId, uid, effectiveXp, lvl, nowUtc, nowUtc]);
    }
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
    await db.execute('DELETE FROM prayers');
    await db.execute('DELETE FROM user_profiles');
    await db.execute('DELETE FROM user_profile');
    globalUserLevel.value = 1;
    CacheService().clear();
    await initCustomLocalTables();
  } catch (_) {}
}

