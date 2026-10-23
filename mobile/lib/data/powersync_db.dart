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
import 'package:axis/core/config/app_config.dart';

// Re-export modular components for clean architecture and 100% backwards compatibility
import 'package:axis/data/powersync/app_schema.dart';
import 'package:axis/data/powersync/supabase_connector.dart';

export 'package:axis/data/powersync/app_schema.dart';
export 'package:axis/data/powersync/supabase_connector.dart';

// Alias for existing callers
final Schema schema = appSchema;

late PowerSyncDatabase db;
bool _dbInitialized = false;
bool get isDatabaseInitialized => _dbInitialized;
final ValueNotifier<int> globalUserLevel = ValueNotifier<int>(1);

String _cachedUserId = '';
void setCachedUserId(String id) => _cachedUserId = id;

String get currentUserId {
  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      _cachedUserId = uid;
      return uid;
    }
  } catch (e) {
    debugPrint('[PowerSync] currentUserId check fallback: $e');
  }
  return _cachedUserId;
}

/// Factory helper for SupabaseConnector bound to currentUserId
SupabaseConnector createSupabaseConnector() {
  return SupabaseConnector(getCurrentUserId: () => currentUserId);
}

/// Cleanly clears user data on sign out without creating delete mutations in the upload queue
Future<void> clearUserDataOnSignOut() async {
  if (!_dbInitialized) return;
  try {
    // disconnectAndClear purges all synced PowerSync tables locally without generating upload CRUD ops
    await db.disconnectAndClear();
    try {
      await db.execute('DELETE FROM local_auth_session');
    } catch (e) {
      debugPrint('[PowerSync] Error clearing local auth session: $e');
    }
    _cachedUserId = '';
    globalUserLevel.value = 1;
    CacheService().clear();
  } catch (e) {
    debugPrint('[PowerSync] Error clearing user data on sign out: $e');
  }
}

/// Automatically claims any local offline guest records when transitioning to an authenticated account,
/// preventing any data loss for users who started in "Offline Mode".
Future<void> purgeForeignUserData() async {
  if (!_dbInitialized) return;
  final uid = currentUserId;
  if (uid.isEmpty) return;

  try {
    // 0. Remove legacy prayers from generic habits table
    await db.execute("DELETE FROM habits WHERE kind = 'Prayers' OR id LIKE 'habit_prayer_%'");

    // 1. Claim any local orphan records that were created without a user_id OR created in offline guest mode
    const orphanClause = "WHERE user_id IS NULL OR user_id = '' OR user_id = 'local_guest'";
    await db.execute("UPDATE tasks SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE projects SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE tags SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE habits SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE habit_logs SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE notes SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE focus_sessions SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE logs SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE habit_categories SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE prayers SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE user_profiles SET user_id = ? $orphanClause", [uid]);

    // Note: In PowerSync, multi-user isolation is enforced through server-side Sync Rules
    // and client query filters (WHERE user_id = ?). We deliberately avoid physical "DELETE FROM ... WHERE user_id != ?"
    // because PowerSync treats local DELETEs as upload transactions, which would pollute the CRUD queue.
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
          debugPrint('[PowerSync] Migrating legacy physical table "$name" to PowerSync view');
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

  db = PowerSyncDatabase(schema: appSchema, path: path);
  await db.initialize();

  // Connect to Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  final connector = createSupabaseConnector();

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
      } catch (e) {
        debugPrint('[PowerSync] db.disconnect on auth change error: $e');
      }
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
        avatar_url TEXT,
        last_login_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('ALTER TABLE local_auth_session ADD COLUMN avatar_url TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE user_profiles ADD COLUMN avatar_url TEXT');
    } catch (_) {}
    try {
      await db.execute('UPDATE local_auth_session SET cached_password = NULL');
    } catch (_) {}

    // Drop legacy local duplicate table and migrate existing records to PowerSync habit_categories
    try {
      await db.execute('''
        INSERT OR IGNORE INTO habit_categories (id, user_id, name, icon, color, sort_order, created_at, updated_at)
        SELECT id, user_id, name, icon, color, sort_order, created_at, updated_at FROM local_habit_categories
      ''');
      await db.execute('DROP TABLE IF EXISTS local_habit_categories');
    } catch (_) {}

    // Purge legacy prayer habits from generic habits table
    await db.execute("DELETE FROM habits WHERE kind = 'Prayers' OR id LIKE 'habit_prayer_%'");
    await db.execute("DELETE FROM habit_categories WHERE id = 'cat_prayers' OR LOWER(name) = 'prayers'");

    // Purge legacy predefined categories from habits table so default categories don't ghost-reappear
    await db.execute("UPDATE habits SET kind = NULL WHERE LOWER(kind) IN ('workout', 'reading', 'mindful', 'hydrate', 'code', 'rest', 'cat_workout', 'cat_reading', 'cat_mindful', 'cat_hydrate', 'cat_code', 'cat_rest')");

    // Index local SQLite tables (PowerSync tables have their indexes managed natively in appSchema)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_local_auth_session_user_id ON local_auth_session(user_id)');
  } catch (e) {
    debugPrint('[PowerSync] Error in initCustomLocalTables: $e');
  }
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
      final existing = await db.getOptional('SELECT id FROM user_profiles WHERE id = ?', [profileId]);
      if (existing != null) {
        await db.execute('''
          UPDATE user_profiles SET
            total_xp = ?,
            level = ?,
            updated_at = ?
          WHERE id = ?
        ''', [effectiveXp, lvl, nowUtc, profileId]);
      } else {
        await db.execute('''
          INSERT INTO user_profiles (id, user_id, name, title, avatar_color, total_xp, level, created_at, updated_at)
          VALUES (?, ?, 'Commander', 'Specialist', '#6366F1', ?, ?, ?, ?)
        ''', [profileId, uid, effectiveXp, lvl, nowUtc, nowUtc]);
      }
    }
  } catch (e) {
    debugPrint('[PowerSync] Error in syncGlobalUserLevel: $e');
  }
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
  } catch (e) {
    debugPrint('[PowerSync] Error in resetAllData: $e');
  }
}
