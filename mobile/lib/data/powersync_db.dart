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
import 'package:axis/domain/domain_events.dart';

// Re-export modular components for clean architecture and 100% backwards compatibility
import 'package:axis/data/powersync/app_schema.dart';
import 'package:axis/data/powersync/supabase_connector.dart';

export 'package:axis/data/powersync/app_schema.dart';
export 'package:axis/data/powersync/supabase_connector.dart';

// Alias for existing callers
final Schema schema = appSchema;

PowerSyncDatabase? _dbInstance;

/// Safe accessor for the PowerSyncDatabase instance
PowerSyncDatabase get db {
  final instance = _dbInstance;
  if (instance == null) {
    throw StateError(
      'PowerSyncDatabase is not initialized. Ensure openDatabase() has completed before accessing db.',
    );
  }
  return instance;
}

set db(PowerSyncDatabase value) {
  _dbInstance = value;
  _dbInitialized = true;
}

bool _dbInitialized = false;
bool get isDatabaseInitialized => _dbInitialized && _dbInstance != null;
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
  } catch (_) {
    // Supabase not yet initialized or running in offline/test environment
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
  if (uid.isEmpty || uid == 'local_guest') return;

  try {
    // Claim all local orphan records that were created without a user_id OR created in offline guest mode
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
    try {
      await db.execute("UPDATE note_categories SET user_id = ? $orphanClause", [uid]);
    } catch (_) {}
    await db.execute("UPDATE prayers SET user_id = ? $orphanClause", [uid]);
    await db.execute("UPDATE user_profiles SET user_id = ? $orphanClause", [uid]);
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
        'note_categories',
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
          if (name == 'note_categories') {
            try {
              rawDb.execute('CREATE TABLE IF NOT EXISTS local_note_categories (id TEXT PRIMARY KEY, user_id TEXT, name TEXT, icon TEXT, color TEXT, sort_order INTEGER, created_at TEXT, updated_at TEXT)');
              rawDb.execute('INSERT OR IGNORE INTO local_note_categories SELECT id, user_id, name, icon, color, sort_order, created_at, updated_at FROM "$name"');
            } catch (_) {}
          }
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

  // Self-heal: automatically repair any habit whose category was corrupted to 'boolean' or 'numeric'
  try {
    await db.execute('''
      UPDATE habits 
      SET kind = COALESCE(
        (SELECT name FROM habit_categories ORDER BY sort_order ASC, name ASC LIMIT 1),
        'Daily plan'
      )
      WHERE kind IN ('boolean', 'numeric')
    ''');
  } catch (e) {
    debugPrint('[PowerSync] Self-healing habit category notice: $e');
  }

  // Connect to Supabase
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );

  final connector = createSupabaseConnector();

  // PowerSync runs 100% locally with SQLite for full offline-first functionality.
  // We only engage remote sync streaming when an active authenticated session exists.
  Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
    final session = data.session;
    final event = data.event;
    if (session != null) {
      setCachedUserId(session.user.id);
      if (!db.connected) {
        db.connect(connector: connector);
      }
      await purgeForeignUserData();
      await syncGlobalUserLevel();
    } else if (event == AuthChangeEvent.signedOut) {
      setCachedUserId('');
      if (db.connected) {
        try {
          await db.disconnect();
        } catch (e) {
          debugPrint('[PowerSync] db.disconnect on auth change error: $e');
        }
      }
    }
  });

  if (Supabase.instance.client.auth.currentSession != null && !db.connected) {
    db.connect(connector: connector);
  }

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

    // Drop legacy local duplicate table and migrate existing records to PowerSync note_categories
    try {
      await db.execute('''
        INSERT OR IGNORE INTO note_categories (id, user_id, name, icon, color, sort_order, created_at, updated_at)
        SELECT id, user_id, name, icon, color, sort_order, created_at, updated_at FROM local_note_categories
      ''');
      await db.execute('DROP TABLE IF EXISTS local_note_categories');
    } catch (_) {}

    // Index local SQLite tables (PowerSync tables have their indexes managed natively in appSchema)
    await db.execute('CREATE INDEX IF NOT EXISTS idx_local_auth_session_user_id ON local_auth_session(user_id)');

    // Centralized prayer_settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prayer_settings (
        id TEXT PRIMARY KEY,
        city TEXT,
        country TEXT,
        latitude REAL,
        longitude REAL,
        timezone TEXT,
        calculation_method TEXT,
        last_sync_date TEXT,
        adhan_notifications_enabled INTEGER DEFAULT 1,
        fajr_alarm_enabled INTEGER DEFAULT 1
      )
    ''');
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
    final previousLevel = globalUserLevel.value;
    globalUserLevel.value = lvl;
    if (lvl > previousLevel) {
      DomainEvents.emit(LevelUpEvent(lvl));
    }

    if (uid.isNotEmpty && uid != 'local_guest') {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final existing = await db.getOptional('SELECT id FROM user_profiles WHERE user_id = ? LIMIT 1', [uid]);
      if (existing != null) {
        final existingId = existing['id'] as String;
        await db.execute('''
          UPDATE user_profiles SET
            total_xp = ?,
            level = ?,
            updated_at = ?
          WHERE id = ?
        ''', [effectiveXp, lvl, nowUtc, existingId]);
      } else {
        final profileId = IdGenerator.generateDeterministicId('profile_$uid');
        Map<String, dynamic>? authMeta;
        try {
          authMeta = Supabase.instance.client.auth.currentUser?.userMetadata;
        } catch (_) {}
        final metaName = authMeta?['display_name'] as String?;
        final metaTitle = (authMeta?['title'] as String?) ?? (authMeta?['callsign'] as String?);
        final metaAvatar = authMeta?['avatar_url'] as String?;

        String nameToUse = (metaName != null && metaName.trim().isNotEmpty) ? metaName.trim() : '';
        if (nameToUse.isEmpty) {
          try {
            final sessionRow = await db.getOptional('SELECT display_name FROM local_auth_session WHERE id = ?', ['active_session']);
            final savedName = sessionRow?['display_name'] as String?;
            if (savedName != null && savedName.trim().isNotEmpty && savedName != 'Operative') {
              nameToUse = savedName.trim();
            }
          } catch (_) {}
        }
        if (nameToUse.isEmpty || nameToUse == 'Operative') {
          nameToUse = 'Commander';
        }
        final titleToUse = (metaTitle != null && metaTitle.trim().isNotEmpty) ? metaTitle.trim() : 'Specialist';

        final hashPart = uid.replaceAll('-', '').toUpperCase();
        final friendCode = 'AX-${hashPart.length >= 4 ? hashPart.substring(0, 4) : "7842"}';

        await db.execute('''
          INSERT INTO user_profiles (id, user_id, name, title, avatar_color, avatar_url, total_xp, level, friend_code, created_at, updated_at)
          VALUES (?, ?, ?, ?, '#6366F1', ?, ?, ?, ?, ?, ?)
        ''', [profileId, uid, nameToUse, titleToUse, metaAvatar, effectiveXp, lvl, friendCode, nowUtc, nowUtc]);
      }
    }
  } catch (e) {
    debugPrint('[PowerSync] Error in syncGlobalUserLevel: $e');
  }
}

Future<void> resetAllData() async {
  if (!_dbInitialized) return;
  try {
    // disconnectAndClear safely purges all synced PowerSync tables locally
    // without queuing destructive upload DELETE mutations to Supabase Postgres.
    await db.disconnectAndClear();
    try {
      await db.execute('DELETE FROM local_auth_session');
      await db.execute('DELETE FROM prayer_settings');
    } catch (e) {
      debugPrint('[PowerSync] Error clearing local tables in resetAllData: $e');
    }
    _cachedUserId = '';
    globalUserLevel.value = 1;
    CacheService().clear();
    await initCustomLocalTables();
    if (Supabase.instance.client.auth.currentSession != null && !db.connected) {
      db.connect(connector: createSupabaseConnector());
    }
  } catch (e) {
    debugPrint('[PowerSync] Error in resetAllData: $e');
  }
}
