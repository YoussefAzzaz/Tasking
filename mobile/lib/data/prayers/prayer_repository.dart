import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:powersync/powersync.dart';
import 'package:axis/data/powersync_db.dart';
import 'prayer_model.dart';
import 'prayer_calculator.dart';

/// Data repository for Islamic prayers persisted in the dedicated `prayers` SQLite table.
class PrayerRepository {
  final PowerSyncDatabase Function() _getDb;
  final bool Function() _isInitialized;

  PrayerRepository({
    PowerSyncDatabase Function()? getDb,
    bool Function()? isInitialized,
  })  : _getDb = getDb ?? (() => db),
        _isInitialized = isInitialized ?? (() => isDatabaseInitialized);

  PowerSyncDatabase get _db => _getDb();
  bool get _ready => _isInitialized();

  /// Canonical deterministic ID for each of the strictly 5 Islamic prayers.
  /// Formatted as 'prayer_${userId}_${code}' to match Supabase seed trigger exactly.
  static String prayerIdForCode(String code, [String? userId]) {
    final uid = (userId != null && userId.isNotEmpty) ? userId : currentUserId;
    final clean = code.toLowerCase().trim();
    if (uid.isNotEmpty) {
      return 'prayer_${uid}_$clean';
    }
    return 'prayer_$clean';
  }

  /// Default canonical 5 prayers fallback list
  static List<Prayer> defaultPrayers([String? userId]) {
    return PrayerCalculator.defaultPrayers(userId);
  }

  /// Automatically claims any orphan or guest records for active user
  Future<void> claimGuestPrayers(String userId) async {
    if (!_ready || userId.isEmpty) return;
    try {
      await _db.execute(
        "UPDATE prayers SET user_id = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')",
        [userId],
      );
      await _db.execute(
        "UPDATE habit_logs SET user_id = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')",
        [userId],
      );
    } catch (e) {
      debugPrint('[PrayerRepository] claimGuestPrayers notice: $e');
    }
  }

  /// Streams the 5 daily prayers from the dedicated `prayers` table with indexed lookups.
  Stream<List<Prayer>> watchPrayers([String? userId]) {
    final uid = userId ?? currentUserId;
    if (!_ready) {
      return Stream.value(defaultPrayers(uid));
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Clean indexed query using LEFT JOIN on canonical IDs without full-table wildcard scans
    final String query;
    final List<dynamic> params;

    if (uid.isNotEmpty) {
      query = '''
        SELECT 
          p.id, p.user_id, p.prayer_code, p.name, p.icon, p.time, p.sort_order, p.is_done, p.created_at, p.updated_at,
          hl.status AS today_log_status
        FROM prayers p
        LEFT JOIN habit_logs hl 
          ON (hl.habit_id = p.id OR hl.habit_id = 'prayer_' || p.prayer_code)
         AND hl.log_date = ? 
         AND hl.status = 'done'
        WHERE p.user_id = ?
        ORDER BY p.sort_order ASC
      ''';
      params = [today, uid];
    } else {
      query = '''
        SELECT 
          p.id, p.user_id, p.prayer_code, p.name, p.icon, p.time, p.sort_order, p.is_done, p.created_at, p.updated_at,
          hl.status AS today_log_status
        FROM prayers p
        LEFT JOIN habit_logs hl 
          ON (hl.habit_id = p.id OR hl.habit_id = 'prayer_' || p.prayer_code)
         AND hl.log_date = ? 
         AND hl.status = 'done'
        WHERE (p.user_id IS NULL OR p.user_id = '' OR p.user_id = 'local_guest')
        ORDER BY p.sort_order ASC
      ''';
      params = [today];
    }

    return _db.watch(query, parameters: params).map((rows) {
      final defaults = defaultPrayers(uid);
      final defaultMap = {for (var p in defaults) p.prayerCode.toLowerCase(): p};

      final rowMap = <String, Prayer>{};
      for (final r in rows) {
        final code = (r['prayer_code'] as String? ?? '').toLowerCase();
        if (defaultMap.containsKey(code)) {
          final prayer = Prayer.fromRow(r);
          if (!rowMap.containsKey(code) || (!rowMap[code]!.isDone && prayer.isDone)) {
            rowMap[code] = prayer;
          }
        }
      }

      const canonicalCodes = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
      return canonicalCodes.map((code) => rowMap[code] ?? defaultMap[code]!).toList();
    });
  }

  /// Synchronizes calculated prayer times into SQLite preserving existing completion states
  Future<void> upsertPrayers(String userId, List<PrayerItem> prayerItems) async {
    if (!_ready) return;
    final now = DateTime.now();
    final utcNow = now.toUtc().toIso8601String();

    await claimGuestPrayers(userId);

    // Canonical IDs for active user
    final canonicalIds = [
      prayerIdForCode('fajr', userId),
      prayerIdForCode('dhuhr', userId),
      prayerIdForCode('asr', userId),
      prayerIdForCode('maghrib', userId),
      prayerIdForCode('isha', userId),
    ];

    final existingRows = await _db.getAll(
      userId.isNotEmpty
          ? "SELECT id, prayer_code, name, icon, time, sort_order, is_done, updated_at FROM prayers WHERE user_id = ?"
          : "SELECT id, prayer_code, name, icon, time, sort_order, is_done, updated_at FROM prayers WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')",
      userId.isNotEmpty ? [userId] : <dynamic>[],
    );

    final existingById = {for (var r in existingRows) (r['id'] as String? ?? ''): r};
    final existingByCode = {
      for (var r in existingRows) (r['prayer_code'] as String? ?? '').toLowerCase(): r
    };

    // Upsert exactly the 5 prayers by canonical ID.
    // Preserves completion state ONLY if completed during today's calendar day.
    // If updated_at is from yesterday or earlier, completion resets back to 0 at 00:00.
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    for (final item in prayerItems) {
      final code = item.id.toLowerCase();
      final prayerId = prayerIdForCode(code, userId);
      final existing = existingById[prayerId] ?? existingByCode[code];

      final updatedAt = existing != null ? (existing['updated_at'] as String? ?? '') : '';
      bool isFromToday = false;
      if (updatedAt.isNotEmpty) {
        try {
          final dt = DateTime.parse(updatedAt).toLocal();
          isFromToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
        } catch (_) {
          isFromToday = updatedAt.startsWith(todayStr);
        }
      }

      final bool preserveDone = existing != null &&
          isFromToday &&
          ((existing['is_done'] as num?)?.toInt() == 1 || existing['is_done'] == true);

      if (existing == null) {
        final dbCheck = await _db.getOptional('SELECT id FROM prayers WHERE id = ?', [prayerId]);
        if (dbCheck == null) {
          await _db.execute('''
            INSERT INTO prayers (
              id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            prayerId,
            userId,
            code,
            item.name,
            item.icon,
            item.formattedTime,
            item.sortOrder,
            preserveDone ? 1 : 0,
            utcNow,
            utcNow,
          ]);
        } else {
          await _db.execute('''
            UPDATE prayers SET
              user_id = ?,
              name = ?,
              icon = ?,
              time = ?,
              sort_order = ?
            WHERE id = ?
          ''', [
            userId,
            item.name,
            item.icon,
            item.formattedTime,
            item.sortOrder,
            prayerId,
          ]);
        }
      } else {
        final targetId = existing['id'] as String;
        final existingTime = existing['time'] as String?;
        final existingName = existing['name'] as String?;
        final existingIcon = existing['icon'] as String?;
        final existingSort = (existing['sort_order'] as num?)?.toInt();

        final currentIsDone = (existing['is_done'] as num?)?.toInt() == 1 || existing['is_done'] == true;
        final targetIsDone = preserveDone;
        final needsDoneReset = currentIsDone != targetIsDone;

        final needsUpdate = existingTime != item.formattedTime ||
            existingName != item.name ||
            existingIcon != item.icon ||
            existingSort != item.sortOrder ||
            targetId != prayerId ||
            needsDoneReset;

        if (needsUpdate) {
          if (targetId != prayerId) {
            // PowerSync SQLite constraint: primary key `id` is immutable and cannot be updated via UPDATE SET id = ?.
            // Insert or update canonical prayerId, then cleanly remove the legacy targetId row.
            final canonicalExists = await _db.getOptional('SELECT id FROM prayers WHERE id = ?', [prayerId]);
            if (canonicalExists == null) {
              await _db.execute('''
                INSERT INTO prayers (
                  id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''', [
                prayerId,
                userId,
                code,
                item.name,
                item.icon,
                item.formattedTime,
                item.sortOrder,
                targetIsDone ? 1 : 0,
                utcNow,
                utcNow,
              ]);
            } else {
              await _db.execute('''
                UPDATE prayers SET
                  user_id = ?,
                  name = ?,
                  icon = ?,
                  time = ?,
                  sort_order = ?,
                  is_done = ?,
                  updated_at = ?
                WHERE id = ?
              ''', [
                userId,
                item.name,
                item.icon,
                item.formattedTime,
                item.sortOrder,
                targetIsDone ? 1 : 0,
                utcNow,
                prayerId,
              ]);
            }

            try {
              await _db.execute('DELETE FROM prayers WHERE id = ?', [targetId]);
            } catch (_) {}
          } else {
            await _db.execute('''
              UPDATE prayers SET
                user_id = ?,
                name = ?,
                icon = ?,
                time = ?,
                sort_order = ?,
                is_done = ?,
                updated_at = ?
              WHERE id = ?
            ''', [
              userId,
              item.name,
              item.icon,
              item.formattedTime,
              item.sortOrder,
              targetIsDone ? 1 : 0,
              utcNow,
              prayerId,
            ]);
          }
        }
      }
    }

    // Clean up rogue rows outside the 5 canonical IDs
    if (userId.isNotEmpty) {
      await _db.execute(
        "DELETE FROM prayers WHERE user_id = ? AND id NOT IN (?, ?, ?, ?, ?)",
        [userId, ...canonicalIds],
      );
    }
  }

  /// Non-destructively resets is_done = 0 for prayers whose updated_at is from a previous calendar day.
  /// Does NOT delete habit_logs or logs from today.
  Future<void> resetStalePrayersFromPreviousDays(String userId, String todayStr) async {
    if (!_ready) return;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final query = userId.isNotEmpty
        ? "UPDATE prayers SET is_done = 0, updated_at = ? WHERE user_id = ? AND is_done != 0 AND (updated_at IS NULL OR updated_at < ?)"
        : "UPDATE prayers SET is_done = 0, updated_at = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest') AND is_done != 0 AND (updated_at IS NULL OR updated_at < ?)";
    final params = userId.isNotEmpty ? [nowUtc, userId, todayStr] : [nowUtc, todayStr];
    await _db.execute(query, params);
  }

  /// Resets today's prayer tasks back to undone (`is_done = 0`).
  /// CRITICAL GUARANTEES:
  ///   - Does NOT delete or create rows (strictly preserves the 5 rows).
  ///   - Keeps all previous EXP and streak progress intact.
  ///   - Resets only the completion state back to undone.
  Future<void> resetPrayers(String userId) async {
    if (!_ready) return;
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    final query = userId.isNotEmpty
        ? "UPDATE prayers SET is_done = 0, updated_at = ? WHERE user_id = ?"
        : "UPDATE prayers SET is_done = 0, updated_at = ? WHERE (user_id IS NULL OR user_id = '' OR user_id = 'local_guest')";
    final params = userId.isNotEmpty ? [nowUtc, userId] : [nowUtc];
    await _db.execute(query, params);
  }
}
