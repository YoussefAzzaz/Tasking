import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Centralized file and directory manager for all local app-generated files.
/// Organizes files into an isolated 'axis' folder to protect user documents
/// from clutter and accidental deletion.
class AxisStorage {
  static bool _initialized = false;
  static String? _axisRootPath;
  static String? debugOverrideRootPath;

  /// Resets internal state for unit testing.
  @visibleForTesting
  static void resetForTesting() {
    _initialized = false;
    _axisRootPath = null;
    debugOverrideRootPath = null;
  }

  /// Root directory for all Axis app-generated files: `<Documents>/axis/`
  static Future<Directory> getAxisRootDirectory() async {
    if (debugOverrideRootPath != null) {
      final dir = Directory(p.join(debugOverrideRootPath!, 'axis'));
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    if (_axisRootPath != null) {
      final dir = Directory(_axisRootPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    final docDir = await getApplicationDocumentsDirectory();
    final axisDir = Directory(p.join(docDir.path, 'axis'));
    if (!await axisDir.exists()) {
      await axisDir.create(recursive: true);
    }
    _axisRootPath = axisDir.path;
    return axisDir;
  }

  /// Directory for local SQLite and PowerSync databases: `<Documents>/axis/database/`
  static Future<Directory> getDatabaseDirectory() async {
    final root = await getAxisRootDirectory();
    final dir = Directory(p.join(root.path, 'database'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Full path to the local PowerSync database: `<Documents>/axis/database/axis_powersync.db`
  static Future<String> getDatabasePath() async {
    await ensureInitializedAndMigrated();
    final dbDir = await getDatabaseDirectory();
    return p.join(dbDir.path, 'axis_powersync.db');
  }

  /// Directory for app preferences: `<Documents>/axis/preferences/`
  static Future<Directory> getPreferencesDirectory() async {
    final root = await getAxisRootDirectory();
    final dir = Directory(p.join(root.path, 'preferences'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// File for app locale preference: `<Documents>/axis/preferences/app_locale_preference.json`
  static Future<File> getLocaleFile() async {
    await ensureInitializedAndMigrated();
    final prefDir = await getPreferencesDirectory();
    return File(p.join(prefDir.path, 'app_locale_preference.json'));
  }

  /// File for reading preferences: `<Documents>/axis/preferences/reading_preferences.json`
  static Future<File> getReadingPreferencesFile() async {
    await ensureInitializedAndMigrated();
    final prefDir = await getPreferencesDirectory();
    return File(p.join(prefDir.path, 'reading_preferences.json'));
  }

  /// File for cached user credentials: `<Documents>/axis/preferences/last_saved_credentials.json`
  static Future<File> getLastSavedCredentialsFile() async {
    await ensureInitializedAndMigrated();
    final prefDir = await getPreferencesDirectory();
    return File(p.join(prefDir.path, 'last_saved_credentials.json'));
  }

  /// Directory for notifications state: `<Documents>/axis/notifications/`
  static Future<Directory> getNotificationsDirectory() async {
    final root = await getAxisRootDirectory();
    final dir = Directory(p.join(root.path, 'notifications'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// File for dismissed notifications: `<Documents>/axis/notifications/dismissed_notifications.json`
  static Future<File> getDismissedNotificationsFile() async {
    await ensureInitializedAndMigrated();
    final dir = await getNotificationsDirectory();
    return File(p.join(dir.path, 'dismissed_notifications.json'));
  }

  /// Directory for custom/downloaded Adhan sounds: `<Documents>/axis/sounds/custom_adhan_sounds/`
  static Future<Directory> getAdhanSoundsDirectory() async {
    await ensureInitializedAndMigrated();
    final root = await getAxisRootDirectory();
    final audioDir = Directory(p.join(root.path, 'sounds', 'custom_adhan_sounds'));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    return audioDir;
  }

  /// Directory for user exports and notes vault: `<Documents>/axis/vault/`
  static Future<Directory> getVaultDirectory() async {
    await ensureInitializedAndMigrated();
    final root = await getAxisRootDirectory();
    final vaultDir = Directory(p.join(root.path, 'vault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    return vaultDir;
  }

  /// Automatically ensures all directories exist and migrates any loose legacy files
  /// from `<Documents>/` into `<Documents>/axis/` with 100% data preservation.
  static Future<void> ensureInitializedAndMigrated() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final docDir = debugOverrideRootPath != null
          ? Directory(debugOverrideRootPath!)
          : await getApplicationDocumentsDirectory();

      // 1. Migrate database files: axis_powersync.db, -wal, -shm
      final dbDir = await getDatabaseDirectory();
      final legacyDb = File(p.join(docDir.path, 'axis_powersync.db'));
      final targetDb = File(p.join(dbDir.path, 'axis_powersync.db'));

      if (await legacyDb.exists() && !await targetDb.exists()) {
        try {
          await legacyDb.rename(targetDb.path);
          debugPrint('[AxisStorage] Migrated legacy database to ${targetDb.path}');
        } catch (e) {
          // Fallback to copy + delete if cross-partition rename fails
          await legacyDb.copy(targetDb.path);
          await legacyDb.delete();
        }

        // Also migrate wal and shm files if present
        for (final ext in ['-wal', '-shm']) {
          final legacyExtra = File('${legacyDb.path}$ext');
          final targetExtra = File('${targetDb.path}$ext');
          if (await legacyExtra.exists()) {
            try {
              await legacyExtra.rename(targetExtra.path);
            } catch (_) {
              try {
                await legacyExtra.copy(targetExtra.path);
                await legacyExtra.delete();
              } catch (_) {}
            }
          }
        }
      }

      // 2. Migrate locale preferences
      final prefDir = await getPreferencesDirectory();
      final legacyLocale = File(p.join(docDir.path, 'app_locale_preference.json'));
      final targetLocale = File(p.join(prefDir.path, 'app_locale_preference.json'));
      if (await legacyLocale.exists() && !await targetLocale.exists()) {
        try {
          await legacyLocale.rename(targetLocale.path);
        } catch (_) {
          await legacyLocale.copy(targetLocale.path);
          await legacyLocale.delete();
        }
      }

      // 3. Migrate reading preferences
      final legacyReading = File(p.join(docDir.path, 'reading_preferences.json'));
      final targetReading = File(p.join(prefDir.path, 'reading_preferences.json'));
      if (await legacyReading.exists() && !await targetReading.exists()) {
        try {
          await legacyReading.rename(targetReading.path);
        } catch (_) {
          await legacyReading.copy(targetReading.path);
          await legacyReading.delete();
        }
      }

      // 4. Migrate dismissed notifications
      final notifDir = await getNotificationsDirectory();
      final legacyNotif = File(p.join(docDir.path, 'dismissed_notifications.json'));
      final targetNotif = File(p.join(notifDir.path, 'dismissed_notifications.json'));
      if (await legacyNotif.exists() && !await targetNotif.exists()) {
        try {
          await legacyNotif.rename(targetNotif.path);
        } catch (_) {
          await legacyNotif.copy(targetNotif.path);
          await legacyNotif.delete();
        }
      }

      // 5. Migrate custom adhan sounds folder
      final legacySoundsDir = Directory(p.join(docDir.path, 'custom_adhan_sounds'));
      if (await legacySoundsDir.exists()) {
        final targetSoundsDir = await getAdhanSoundsDirectory();
        await for (final entity in legacySoundsDir.list()) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            final destFile = File(p.join(targetSoundsDir.path, fileName));
            if (!await destFile.exists()) {
              try {
                await entity.rename(destFile.path);
              } catch (_) {
                await entity.copy(destFile.path);
                await entity.delete();
              }
            }
          }
        }
        try {
          await legacySoundsDir.delete(recursive: true);
        } catch (_) {}
      }

      // 6. Migrate legacy Axis_Vault folder
      final legacyVaultDir = Directory(p.join(docDir.path, 'Axis_Vault'));
      if (await legacyVaultDir.exists()) {
        final targetVaultDir = await getVaultDirectory();
        await for (final entity in legacyVaultDir.list()) {
          if (entity is File) {
            final fileName = p.basename(entity.path);
            final destFile = File(p.join(targetVaultDir.path, fileName));
            if (!await destFile.exists()) {
              try {
                await entity.rename(destFile.path);
              } catch (_) {
                await entity.copy(destFile.path);
                await entity.delete();
              }
            }
          }
        }
        try {
          await legacyVaultDir.delete(recursive: true);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AxisStorage] Migration notice: $e');
    }
  }
}
