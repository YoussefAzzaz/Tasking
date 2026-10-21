import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/domain/streak_engine.dart';

/// Immutable model representing user gamification and productivity statistics.
class UserStats {
  final int totalXp;
  final int todayXp;
  final int level;
  final int streakDays;

  const UserStats({
    this.totalXp = 0,
    this.todayXp = 0,
    this.level = 1,
    this.streakDays = 0,
  });

  UserStats copyWith({
    int? totalXp,
    int? todayXp,
    int? level,
    int? streakDays,
  }) {
    return UserStats(
      totalXp: totalXp ?? this.totalXp,
      todayXp: todayXp ?? this.todayXp,
      level: level ?? this.level,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}

/// Centralized repository handling stats and XP aggregation with:
/// 1. Optimized SQLite aggregate queries (SUM, CASE WHEN) instead of full table scans.
/// 2. In-memory caching with Stale-While-Revalidate for sub-millisecond response.
/// 3. Non-blocking async execution with timeout safety.
class StatsRepository {
  static final StatsRepository _instance = StatsRepository._internal();
  factory StatsRepository() => _instance;
  StatsRepository._internal();

  static const String _cacheKey = 'user_stats_summary';

  /// Watches user statistics in real time, recalculating fresh UserStats
  /// whenever logs change in SQLite (task done/undone, habit completed, focus session).
  Stream<UserStats> watchStats() {
    final uid = currentUserId;
    final query = uid.isNotEmpty
        ? "SELECT id, xp_earned, timestamp FROM logs WHERE user_id = ? OR user_id IS NULL OR user_id = ''"
        : "SELECT id, xp_earned, timestamp FROM logs";
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db.watch(query, parameters: params).asyncMap((_) async {
      CacheService().invalidate(_cacheKey);
      return await _calculateStatsFromDatabase();
    });
  }

  /// Retrieves user statistics immediately from cache if available,
  /// otherwise calculates them using optimized SQL aggregates.
  Future<UserStats> getUserStats({bool forceRefresh = false}) async {
    if (forceRefresh) {
      CacheService().invalidate(_cacheKey);
    }

    return CacheService().getOrFetch<UserStats>(
      _cacheKey,
      _calculateStatsFromDatabase,
      ttl: const Duration(minutes: 2),
      staleWhileRevalidate: true,
      timeout: const Duration(seconds: 3),
      fallback: const UserStats(),
    );
  }

  /// Calculates user statistics using native SQLite aggregate functions.
  Future<UserStats> _calculateStatsFromDatabase() async {
    if (!isDatabaseInitialized) {
      return const UserStats();
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayPattern = '$todayStr%';

    int totalXp = 0;
    int todayXp = 0;

    final uid = currentUserId;

    try {
      // 1. Optimized aggregate query for general logs
      final logQuery = uid.isNotEmpty
          ? '''
          SELECT 
            COALESCE(SUM(xp_earned), 0) AS total_xp,
            COALESCE(SUM(CASE WHEN timestamp LIKE ? THEN xp_earned ELSE 0 END), 0) AS today_xp
          FROM logs
          WHERE user_id = ?
          '''
          : '''
          SELECT 
            COALESCE(SUM(xp_earned), 0) AS total_xp,
            COALESCE(SUM(CASE WHEN timestamp LIKE ? THEN xp_earned ELSE 0 END), 0) AS today_xp
          FROM logs
          ''';
      final logParams = uid.isNotEmpty ? [todayPattern, uid] : [todayPattern];
      final logRow = await db.getOptional(logQuery, logParams);

      if (logRow != null) {
        totalXp += (logRow['total_xp'] as num?)?.toInt() ?? 0;
        todayXp += (logRow['today_xp'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[StatsRepository] Error querying log XP: $e');
    }

    try {
      // 2. Optimized aggregate query for completed focus sessions
      final focusQuery = uid.isNotEmpty
          ? '''
          SELECT 
            COALESCE(SUM(xp_earned), 0) AS total_xp,
            COALESCE(SUM(CASE WHEN started_at LIKE ? THEN xp_earned ELSE 0 END), 0) AS today_xp
          FROM focus_sessions 
          WHERE completed = 1 AND user_id = ?
          '''
          : '''
          SELECT 
            COALESCE(SUM(xp_earned), 0) AS total_xp,
            COALESCE(SUM(CASE WHEN started_at LIKE ? THEN xp_earned ELSE 0 END), 0) AS today_xp
          FROM focus_sessions 
          WHERE completed = 1
          ''';
      final focusParams = uid.isNotEmpty ? [todayPattern, uid] : [todayPattern];
      final focusRow = await db.getOptional(focusQuery, focusParams);

      if (focusRow != null) {
        totalXp += (focusRow['total_xp'] as num?)?.toInt() ?? 0;
        todayXp += (focusRow['today_xp'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('[StatsRepository] Error querying focus session XP: $e');
    }

    // 3. Compute streak days from habit logs
    int streakDays = 0;
    try {
      final habitLogQuery = uid.isNotEmpty
          ? 'SELECT log_date, status FROM habit_logs WHERE user_id = ? ORDER BY log_date DESC LIMIT 365'
          : 'SELECT log_date, status FROM habit_logs ORDER BY log_date DESC LIMIT 365';
      final habitLogParams = uid.isNotEmpty ? [uid] : <dynamic>[];
      final habitLogRows = await db.getAll(habitLogQuery, habitLogParams);

      final streakLogs = habitLogRows
          .map((r) => StreakLog(r['log_date'] as String, r['status'] as String))
          .toList();
      streakDays = StreakEngine.calculateStreak('daily', streakLogs, todayStr);
    } catch (e) {
      debugPrint('[StatsRepository] Error calculating habit streak days: $e');
    }

    final level = GamificationEngine.calculateLevel(totalXp);
    globalUserLevel.value = level;

    return UserStats(
      totalXp: totalXp,
      todayXp: todayXp,
      level: level,
      streakDays: streakDays,
    );
  }

  /// Invalidates cached stats so subsequent reads recalculate fresh totals.
  void invalidateStats() {
    CacheService().invalidate(_cacheKey);
  }

  /// Directly updates cached stats (optimistic update)
  void updateOptimistic(UserStats stats) {
    CacheService().set<UserStats>(_cacheKey, stats, ttl: const Duration(minutes: 2));
    globalUserLevel.value = stats.level;
  }
}
