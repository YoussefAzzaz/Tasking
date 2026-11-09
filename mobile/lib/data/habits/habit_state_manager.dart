import 'package:flutter/foundation.dart';
import 'package:axis/data/powersync_db.dart';

/// Manages local habit states such as paused/resumed status in memory
/// and local SQLite table `local_habit_state`.
class HabitStateManager {
  static final Set<String> _pausedHabitIds = {};
  static bool _stateLoaded = false;

  /// Returns true if this habit has been explicitly paused locally.
  static bool isHabitPaused(String habitId) {
    return _pausedHabitIds.contains(habitId);
  }

  /// Ensures locally tracked paused habit states are loaded into memory from local storage/db
  static Future<void> ensureStateLoaded() async {
    if (_stateLoaded || !isDatabaseInitialized) return;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_habit_state (
          habit_id TEXT PRIMARY KEY,
          is_enabled INTEGER NOT NULL DEFAULT 1,
          updated_at TEXT NOT NULL
        )
      ''');
      final rows = await db.getAll('SELECT habit_id, is_enabled FROM local_habit_state');
      for (final r in rows) {
        final hId = r['habit_id'] as String? ?? '';
        final enabled = (r['is_enabled'] as num?)?.toInt() ?? 1;
        if (hId.isNotEmpty) {
          if (enabled == 0) {
            _pausedHabitIds.add(hId);
          } else {
            _pausedHabitIds.remove(hId);
          }
        }
      }
      _stateLoaded = true;
    } catch (e) {
      debugPrint('[HabitStateManager] ensureStateLoaded notice: $e');
    }
  }

  /// Updates in-memory paused state
  static void setHabitPausedInMemory(String habitId, bool isPaused) {
    if (isPaused) {
      _pausedHabitIds.add(habitId);
    } else {
      _pausedHabitIds.remove(habitId);
    }
  }

  /// Persists paused state to local SQLite table
  static Future<void> persistHabitState(String habitId, bool isEnabled, String nowUtc) async {
    if (!isDatabaseInitialized) return;
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS local_habit_state (
          habit_id TEXT PRIMARY KEY,
          is_enabled INTEGER NOT NULL DEFAULT 1,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO local_habit_state (habit_id, is_enabled, updated_at)
        VALUES (?, ?, ?)
        ON CONFLICT(habit_id) DO UPDATE SET
          is_enabled = excluded.is_enabled,
          updated_at = excluded.updated_at
      ''', [habitId, isEnabled ? 1 : 0, nowUtc]);
    } catch (e) {
      debugPrint('[HabitStateManager] Error persisting local_habit_state: $e');
    }
  }
}

