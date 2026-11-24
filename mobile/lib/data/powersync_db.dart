import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/core/config/app_config.dart';
import 'package:axis/core/storage/axis_storage.dart';
import 'package:axis/domain/domain_events.dart';

// Re-export modular components for clean architecture and 100% backwards compatibility
import 'package:axis/data/powersync/app_schema.dart';
import 'package:axis/data/powersync/supabase_connector.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/auth_service.dart';

export 'package:axis/data/powersync/app_schema.dart';
export 'package:axis/data/powersync/supabase_connector.dart';

// Alias for existing callers
const Schema schema = appSchema;

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
}

bool _dbInitialized = false;
bool get isDatabaseInitialized => _dbInitialized && _dbInstance != null;
final ValueNotifier<int> globalUserLevel = ValueNotifier<int>(1);

bool _isConnectingPowerSync = false;
bool _isSigningOut = false;
DateTime? _lastCredentialsRecoveryAt;
bool _isSyncingUserLevel = false;

bool get isSigningOut => _isSigningOut;
void setSigningOut(bool value) => _isSigningOut = value;

bool get isPowerSyncConnectedOrConnecting =>
    _dbInstance != null &&
    (_isConnectingPowerSync ||
        _dbInstance!.connected ||
        _dbInstance!.currentStatus.connecting);

Future<void> connectPowerSyncSafely([SupabaseConnector? customConnector]) async {
  final instance = _dbInstance;
  if (_isSigningOut || instance == null || isPowerSyncConnectedOrConnecting) return;
  _isConnectingPowerSync = true;
  try {
    if (instance.currentStatus.anyError != null && !instance.connected) {
      try {
        await instance.disconnect();
      } catch (_) {}
    }
    await instance.connect(
      connector: customConnector ?? createSupabaseConnector(),
    );
  } catch (e) {
    debugPrint('[PowerSync] connectPowerSyncSafely notice: $e');
  } finally {
    _isConnectingPowerSync = false;
  }
}

String _cachedUserId = '';
void setCachedUserId(String id) => _cachedUserId = id;

String get currentUserId {
  if (_isSigningOut) return '';
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
  return SupabaseConnector(
    getDatabase: () => _dbInitialized ? db : null,
    getCurrentUserId: () => currentUserId,
    isSigningOut: () => _isSigningOut,
  );
}

/// Cleanly clears user data on sign out without creating delete mutations in the upload queue
Future<void> clearUserDataOnSignOut() async {
  if (!_dbInitialized) return;
  try {
    // Clear identity & caches FIRST so active db.watch listeners abort cleanly
    // instead of re-inserting or re-tagging records during teardown.
    _cachedUserId = '';
    globalUserLevel.value = 1;
    CacheService().clear();

    // disconnectAndClear purges all synced PowerSync tables locally without generating upload CRUD ops
    await db.disconnectAndClear();
    try {
      await db.execute('DELETE FROM local_auth_session');
    } catch (e) {
      debugPrint('[PowerSync] Error clearing local auth session: $e');
    }
  } catch (e) {
    debugPrint('[PowerSync] Error clearing user data on sign out: $e');
  }
}

/// Automatically claims any local offline guest records when transitioning to an authenticated account,
/// preventing any data loss for users who started in "Offline Mode".
Future<void> purgeForeignUserData() async {
  if (!_dbInitialized || _isSigningOut) return;
  final uid = currentUserId;
  if (uid.isEmpty || uid == 'local_guest') return;

  try {
    const orphanWhere =
        "user_id IS NULL OR user_id = '' OR user_id = 'local_guest'";
    bool needsClaim = false;
    try {
      final hasOrphans = await db.getOptional('''
        SELECT 1 AS found FROM (
          SELECT 1 FROM tasks WHERE $orphanWhere
          UNION ALL SELECT 1 FROM projects WHERE $orphanWhere
          UNION ALL SELECT 1 FROM tags WHERE $orphanWhere
          UNION ALL SELECT 1 FROM habits WHERE $orphanWhere
          UNION ALL SELECT 1 FROM habit_logs WHERE $orphanWhere
          UNION ALL SELECT 1 FROM notes WHERE $orphanWhere
          UNION ALL SELECT 1 FROM focus_sessions WHERE $orphanWhere
          UNION ALL SELECT 1 FROM logs WHERE $orphanWhere
          UNION ALL SELECT 1 FROM habit_categories WHERE $orphanWhere
          UNION ALL SELECT 1 FROM note_categories WHERE $orphanWhere
          UNION ALL SELECT 1 FROM prayers WHERE $orphanWhere
          UNION ALL SELECT 1 FROM daily_prayer_status WHERE $orphanWhere
          UNION ALL SELECT 1 FROM user_profiles WHERE $orphanWhere
        ) LIMIT 1
      ''');
      needsClaim = hasOrphans != null;
    } catch (_) {
      needsClaim = true;
    }
    if (!needsClaim) return;

    // Atomically claim all local orphan records in a transaction to prevent partial state corruption
    await db.writeTransaction((tx) async {
      const orphanClause =
          "WHERE user_id IS NULL OR user_id = '' OR user_id = 'local_guest'";

      await tx.execute("UPDATE tasks SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE projects SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE tags SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE habits SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE habit_logs SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE notes SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE focus_sessions SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE logs SET user_id = ? $orphanClause", [uid]);
      await tx.execute("UPDATE habit_categories SET user_id = ? $orphanClause", [uid]);
      try {
        await tx.execute("UPDATE note_categories SET user_id = ? $orphanClause", [uid]);
      } catch (_) {}
      await tx.execute("UPDATE prayers SET user_id = ? $orphanClause", [uid]);
      try {
        await tx.execute("UPDATE daily_prayer_status SET user_id = ? $orphanClause", [uid]);
      } catch (_) {}
      await tx.execute("UPDATE user_profiles SET user_id = ? $orphanClause", [uid]);
    });
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
  final path = await AxisStorage.getDatabasePath();

  _cleanupConflictingLegacyTables(path);

  // 0. Keep PowerSync logger at WARNING so routine sync heartbeats do not flood debug output
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((record) {
    if (record.loggerName.toLowerCase().contains('powersync')) {
      final lvl = record.level.name;
      final msg = record.message;
      if (record.level >= Level.WARNING) {
        debugPrint('[PowerSync Logger] [$lvl] $msg');
        if (record.error != null) debugPrint('[PowerSync Logger Error] ${record.error}');
        if (record.stackTrace != null) debugPrint('[PowerSync Logger Stack] ${record.stackTrace}');
      } else {
        debugPrint('[PowerSync Logger] [$lvl] $msg');
      }
    }
  });

  db = PowerSyncDatabase(schema: appSchema, path: path);
  await db.initialize();
  _dbInitialized = true;
  await initCustomLocalTables();

  // 1. Subscribe to statusStream to expose connection state transitions and sync errors without flooding
  bool? wasConnected;
  String? lastErrorKey;
  db.statusStream.listen((status) {
    if (_isSigningOut) return;

    if (status.anyError != null) {
      final errKey = '${status.downloadError}|${status.uploadError}';
      if (lastErrorKey != errKey) {
        lastErrorKey = errKey;
        debugPrint('[PowerSync Status Error] downloadError: ${status.downloadError}, uploadError: ${status.uploadError}');
      }
      final dlErr = status.downloadError?.toString() ?? '';
      if (dlErr.contains('CredentialsException') || dlErr.contains('Not logged in')) {
        final now = DateTime.now();
        if (_lastCredentialsRecoveryAt == null ||
            now.difference(_lastCredentialsRecoveryAt!) > const Duration(seconds: 10)) {
          _lastCredentialsRecoveryAt = now;
          debugPrint('[PowerSync] Detected CredentialsException in statusStream. Attempting automatic session recovery...');
          unawaited(ensurePowerSyncConnected(forceReconnect: true));
        }
      }
    } else {
      lastErrorKey = null;
    }

    if (wasConnected != status.connected) {
      wasConnected = status.connected;
      if (status.connected) {
        debugPrint('[PowerSync Status] Connected and sync stream active.');
      } else if (status.connecting) {
        debugPrint('[PowerSync Status] Connecting to sync service...');
      }
    }
  });

  // Ensure local habit pause state table exists
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_habit_state (
        habit_id TEXT PRIMARY KEY,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL
      )
    ''');
  } catch (e) {
    debugPrint('[PowerSync] local_habit_state init notice: $e');
  }

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
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('[PowerSync] Supabase.initialize notice: $e');
  }

  final connector = createSupabaseConnector();

  // PowerSync runs 100% locally with SQLite for full offline-first functionality.
  // We only engage remote sync streaming when an active authenticated session exists.
  try {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (_isSigningOut) return;
      final session = data.session;
      final event = data.event;
      if (session != null && !session.isExpired) {
        AuthService().sessionExpiredNotifier.value = false;
        final previousUid = _cachedUserId;
        final newUid = session.user.id;
        if (previousUid.isNotEmpty &&
            previousUid != 'local_guest' &&
            previousUid != newUid) {
          try {
            await db.disconnectAndClear();
          } catch (e) {
            debugPrint('[PowerSync] disconnectAndClear on user switch notice: $e');
          }
        }
        setCachedUserId(newUid);
        connectPowerSyncSafely(connector);
        await purgeForeignUserData();
        await syncGlobalUserLevel();
      } else if (session != null && session.isExpired) {
        setCachedUserId(session.user.id);
        if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
          try {
            final res = await Supabase.instance.client.auth.refreshSession();
            final refreshed = res.session;
            if (refreshed != null && !refreshed.isExpired) {
              setCachedUserId(refreshed.user.id);
              AuthService().sessionExpiredNotifier.value = false;
              connectPowerSyncSafely(connector);
              await purgeForeignUserData();
              await syncGlobalUserLevel();
              return;
            }
          } catch (e) {
            debugPrint('[PowerSync] Auth refresh on state change notice: $e');
          }
        }
        // Try silent re-authentication with cached credentials
        final recovered = await AuthService().trySilentReAuthWithSavedCredentials();
        if (recovered) {
          final refreshed = Supabase.instance.client.auth.currentSession;
          if (refreshed != null && !refreshed.isExpired) {
            setCachedUserId(refreshed.user.id);
            AuthService().sessionExpiredNotifier.value = false;
            connectPowerSyncSafely(connector);
            await purgeForeignUserData();
            await syncGlobalUserLevel();
            return;
          }
        }
        // If recovery failed, mark session as expired and redirect out
        unawaited(AuthService().handleSessionExpired(reason: 'Supabase token refresh failed'));
      } else if (event == AuthChangeEvent.signedOut) {
        AuthService().sessionExpiredNotifier.value = false;
        setCachedUserId('');
        if (db.connected || db.currentStatus.connecting) {
          try {
            await db.disconnect();
          } catch (e) {
            debugPrint('[PowerSync] db.disconnect on auth change error: $e');
          }
        }
      }
    });
  } catch (e) {
    debugPrint('[PowerSync] Supabase auth state change listener notice: $e');
  }

  Session? startupSession;
  try {
    startupSession = Supabase.instance.client.auth.currentSession;
  } catch (_) {
    startupSession = null;
  }
  if (startupSession != null) {
    setCachedUserId(startupSession.user.id);
    if (!startupSession.isExpired) {
      AuthService().sessionExpiredNotifier.value = false;
      unawaited(connectPowerSyncSafely(connector));
      if (!Platform.environment.containsKey('FLUTTER_TEST')) {
        unawaited(
          Future<void>.delayed(
            const Duration(milliseconds: 600),
            () => FriendRepository().syncAllFriendData(),
          ),
        );
      }
    } else {
      unawaited(() async {
        if (startupSession!.refreshToken != null && startupSession.refreshToken!.isNotEmpty) {
          try {
            final res = await Supabase.instance.client.auth.refreshSession();
            final refreshed = res.session;
            if (refreshed != null && !refreshed.isExpired) {
              setCachedUserId(refreshed.user.id);
              AuthService().sessionExpiredNotifier.value = false;
              connectPowerSyncSafely(connector);
              await purgeForeignUserData();
              await syncGlobalUserLevel();
              if (!Platform.environment.containsKey('FLUTTER_TEST')) {
                unawaited(FriendRepository().syncAllFriendData());
              }
              return;
            }
          } catch (e) {
            debugPrint('[PowerSync] Startup session refresh notice: $e');
          }
        }
        final recovered = await AuthService().trySilentReAuthWithSavedCredentials();
        if (recovered) {
          final refreshed = Supabase.instance.client.auth.currentSession;
          if (refreshed != null && !refreshed.isExpired) {
            setCachedUserId(refreshed.user.id);
            AuthService().sessionExpiredNotifier.value = false;
            connectPowerSyncSafely(connector);
            await purgeForeignUserData();
            await syncGlobalUserLevel();
            if (!Platform.environment.containsKey('FLUTTER_TEST')) {
              unawaited(FriendRepository().syncAllFriendData());
            }
            return;
          }
        }
        unawaited(AuthService().handleSessionExpired(reason: 'Sync error unrecoverable'));
      }());
    }
  }

  await HabitRepository.ensureStateLoaded();
  unawaited(purgeForeignUserData());
  unawaited(syncGlobalUserLevel());
}

Future<void> initCustomLocalTables() async {
  if (_dbInstance == null) return;
  try {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS local_auth_session (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        email TEXT NOT NULL,
        display_name TEXT,
        avatar_url TEXT,
        encrypted_password TEXT,
        password_hash TEXT,
        last_login_at TEXT NOT NULL
      )
    ''');
    try {
      await db.execute('ALTER TABLE local_auth_session ADD COLUMN avatar_url TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE local_auth_session ADD COLUMN encrypted_password TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE local_auth_session ADD COLUMN password_hash TEXT');
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
        fajr_alarm_enabled INTEGER DEFAULT 1,
        adhan_sound_id TEXT DEFAULT 'makkah',
        adhan_sound_title TEXT DEFAULT 'Makkah Al-Mukarramah',
        adhan_sound_path TEXT DEFAULT 'assets/audio/adhan_makkah.mp3',
        adhan_sound_type TEXT DEFAULT 'bundled',
        adhan_permissions_prompted INTEGER DEFAULT 0
      )
    ''');

    // Prayer adhan events tracking table to prevent duplicate triggers & unrequested replays
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prayer_adhan_events (
        id TEXT PRIMARY KEY,
        prayer_code TEXT,
        event_date TEXT,
        dismissed INTEGER DEFAULT 0,
        triggered_at TEXT
      )
    ''');

    // Safe incremental column migration for existing installs
    final soundCols = [
      'ALTER TABLE prayer_settings ADD COLUMN adhan_sound_id TEXT DEFAULT "makkah"',
      'ALTER TABLE prayer_settings ADD COLUMN adhan_sound_title TEXT DEFAULT "Makkah Al-Mukarramah"',
      'ALTER TABLE prayer_settings ADD COLUMN adhan_sound_path TEXT DEFAULT "assets/audio/adhan_makkah.mp3"',
      'ALTER TABLE prayer_settings ADD COLUMN adhan_sound_type TEXT DEFAULT "bundled"',
      'ALTER TABLE prayer_settings ADD COLUMN adhan_permissions_prompted INTEGER DEFAULT 0',
    ];
    for (final sql in soundCols) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  } catch (e) {
    debugPrint('[PowerSync] Error in initCustomLocalTables: $e');
  }
}

Future<void> syncGlobalUserLevel() async {
  if (!_dbInitialized || _isSyncingUserLevel || _isSigningOut) return;
  _isSyncingUserLevel = true;
  try {
    final uid = currentUserId;
    final logQuery = uid.isNotEmpty
        ? "SELECT COALESCE(SUM(xp_earned), 0) AS total FROM logs WHERE (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest') AND (deleted_at IS NULL OR deleted_at = '') AND (event_type IS NULL OR event_type != 'focus_completed')"
        : "SELECT COALESCE(SUM(xp_earned), 0) AS total FROM logs WHERE (deleted_at IS NULL OR deleted_at = '') AND (event_type IS NULL OR event_type != 'focus_completed')";
    final focusQuery = uid.isNotEmpty
        ? "SELECT COALESCE(SUM(xp_earned), 0) AS total FROM focus_sessions WHERE completed = 1 AND (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest')"
        : 'SELECT COALESCE(SUM(xp_earned), 0) AS total FROM focus_sessions WHERE completed = 1';
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    final logRow = await db.getOptional(logQuery, params);
    final focusRow = await db.getOptional(focusQuery, params);
    final logTotal = (logRow?['total'] as num?)?.toInt() ?? 0;
    final focusTotal = (focusRow?['total'] as num?)?.toInt() ?? 0;
    int totalXp = logTotal + focusTotal;

    // Self-healing: if historical logs were purged or deficit exists compared to user_profiles.total_xp,
    // heal the deficit by inserting a permanent historical progression anchor row into logs so lifetime XP is preserved!
    if (uid.isNotEmpty && uid != 'local_guest') {
      final existingProfile = await db.getOptional(
        'SELECT total_xp, level FROM user_profiles WHERE user_id = ?',
        [uid],
      );
      if (existingProfile != null) {
        final profileXp = (existingProfile['total_xp'] as num?)?.toInt() ?? 0;
        if (profileXp > totalXp) {
          final deficit = profileXp - totalXp;
          final anchorId = IdGenerator.generateDeterministicId('historical_xp_anchor_$uid');
          final anchorExists = await db.getOptional('SELECT id FROM logs WHERE id = ?', [anchorId]);
          final nowIso = DateTime.now().toUtc().toIso8601String();
          if (anchorExists == null) {
            await db.execute('''
              INSERT INTO logs (id, user_id, task_id, event_type, xp_earned, timestamp, created_at, updated_at)
              VALUES (?, ?, 'historical_base', 'historical_progression', ?, '2026-10-01T00:00:00.000Z', ?, ?)
            ''', [anchorId, uid, deficit, nowIso, nowIso]);
          } else {
            await db.execute('''
              UPDATE logs SET xp_earned = xp_earned + ?, updated_at = ? WHERE id = ?
            ''', [deficit, nowIso, anchorId]);
          }
          totalXp += deficit;
        }
      }
    }

    final lvl = GamificationEngine.calculateLevel(totalXp);
    final previousLevel = globalUserLevel.value;
    globalUserLevel.value = lvl;
    if (lvl > previousLevel) {
      DomainEvents.emit(LevelUpEvent(lvl));
    }

    if (uid.isNotEmpty && uid != 'local_guest') {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final profileId = IdGenerator.generateDeterministicId('profile_$uid');
      final existing = await db.getOptional(
        'SELECT id, total_xp, level FROM user_profiles WHERE user_id = ? OR id = ? LIMIT 1',
        [uid, profileId],
      );
      if (existing != null) {
        final existingId = existing['id'] as String;
        final existingXp = (existing['total_xp'] as num?)?.toInt() ?? 0;
        final existingLvl = (existing['level'] as num?)?.toInt() ?? 1;
        if (existingXp != totalXp || existingLvl != lvl) {
          await db.execute('''
            UPDATE user_profiles SET
              total_xp = ?,
              level = ?,
              updated_at = ?
            WHERE id = ?
          ''', [totalXp, lvl, nowUtc, existingId]);
        }
      } else if (totalXp > 0 || db.currentStatus.hasSynced == true) {
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

        try {
          await db.execute('''
            INSERT INTO user_profiles (id, user_id, name, title, avatar_color, avatar_url, total_xp, level, friend_code, created_at, updated_at)
            VALUES (?, ?, ?, ?, '#6366F1', ?, ?, ?, ?, ?, ?)
          ''', [profileId, uid, nameToUse, titleToUse, metaAvatar, totalXp, lvl, friendCode, nowUtc, nowUtc]);
        } catch (_) {
          await db.execute('''
            UPDATE user_profiles SET
              total_xp = ?,
              level = ?,
              updated_at = ?
            WHERE (id = ? OR user_id = ?)
              AND (COALESCE(total_xp, 0) != ? OR COALESCE(level, 1) != ?)
          ''', [totalXp, lvl, nowUtc, profileId, uid, totalXp, lvl]);
        }
      }
    }

    try {
      UserProfileRepository().updateNotifierLevelAndXp(totalXp, lvl);
    } catch (_) {}
  } catch (e) {
    debugPrint('[PowerSync] Error in syncGlobalUserLevel: $e');
  } finally {
    _isSyncingUserLevel = false;
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
    if (Supabase.instance.client.auth.currentSession != null) {
      await connectPowerSyncSafely();
    }
  } catch (e) {
    debugPrint('[PowerSync] Error in resetAllData: $e');
  }
}

/// Verifies whether PowerSync is currently connected and reconnects if credentials exist.
Future<void> ensurePowerSyncConnected({bool forceReconnect = false}) async {
  if (!_dbInitialized || _isSigningOut) return;
  try {
    final client = Supabase.instance.client;
    var session = client.auth.currentSession;
    if (session != null && session.isExpired) {
      if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
        try {
          final res = await client.auth.refreshSession();
          session = res.session;
        } catch (e) {
          debugPrint('[PowerSync] ensurePowerSyncConnected refresh notice: $e');
        }
      }
      if (session == null || session.isExpired) {
        final recovered = await AuthService().trySilentReAuthWithSavedCredentials();
        if (recovered) {
          session = client.auth.currentSession;
        }
      }
    }
    if (session != null && !session.isExpired) {
      AuthService().sessionExpiredNotifier.value = false;
      setCachedUserId(session.user.id);
      final hasSyncError = db.currentStatus.anyError != null;
      if (forceReconnect || hasSyncError) {
        if (db.connected || db.currentStatus.connecting) {
          try {
            await db.disconnect();
          } catch (_) {}
        }
        await connectPowerSyncSafely();
      } else {
        await connectPowerSyncSafely();
      }
      await purgeForeignUserData();
      await syncGlobalUserLevel();
    } else if (session != null && session.isExpired) {
      unawaited(AuthService().handleSessionExpired(reason: 'Expired session in ensurePowerSyncConnected'));
    }
  } catch (e) {
    debugPrint('[PowerSync] ensurePowerSyncConnected error: $e');
  }
}
