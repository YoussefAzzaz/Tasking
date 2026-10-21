import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/location_service.dart';
import 'package:axis/data/qibla_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/domain/id_generator.dart';

/// Database representation of a prayer from the dedicated `prayers` table.
class Prayer {
  final String id;
  final String userId;
  final String prayerCode; // 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  final String name; // 'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'
  final String icon; // 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'
  final String time; // e.g. '05:14 AM'
  final int sortOrder; // 1..5
  final bool isDone;
  final String createdAt;
  final String updatedAt;

  const Prayer({
    required this.id,
    required this.userId,
    required this.prayerCode,
    required this.name,
    required this.icon,
    required this.time,
    required this.sortOrder,
    required this.isDone,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Prayer.fromRow(Map<String, dynamic> row) {
    final rawDone = row['is_done'];
    final done = rawDone == 1 || rawDone == true || rawDone == 'true' || rawDone == '1';
    return Prayer(
      id: row['id'] as String,
      userId: (row['user_id'] as String?) ?? '',
      prayerCode: (row['prayer_code'] as String?) ?? '',
      name: (row['name'] as String?) ?? '',
      icon: (row['icon'] as String?) ?? '',
      time: (row['time'] as String?) ?? '',
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 1,
      isDone: done,
      createdAt: (row['created_at'] as String?) ?? '',
      updatedAt: (row['updated_at'] as String?) ?? '',
    );
  }
}

/// Representation of a single daily Islamic prayer for calculations and alarms
class PrayerItem {
  final String id;
  final String name;
  final String icon;
  final int sortOrder;
  final DateTime time;
  final String formattedTime;

  const PrayerItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.sortOrder,
    required this.time,
    required this.formattedTime,
  });
}

/// Service that automatically resolves the user's location & timezone,
/// calculates high-precision Islamic prayer (Adan) times using adhan_dart,
/// and synchronizes the 5 daily prayers in the dedicated `prayers` table.
class PrayerTimeService with WidgetsBindingObserver {
  static final PrayerTimeService _instance = PrayerTimeService._();
  factory PrayerTimeService() => _instance;
  PrayerTimeService._();

  String _currentCity = 'Auto';
  String _currentCountry = '';
  String _currentTimezone = '';
  double _currentLat = 35.7065;
  double _currentLng = -0.6292;
  String _lastSyncedDate = '';
  Timer? _midnightTimer;
  Timer? _heartbeatTimer;
  bool _isInitialized = false;
  bool _isSyncing = false;

  String get currentCity => _currentCity;
  String get currentCountry => _currentCountry;
  String get currentTimezone => _currentTimezone;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  String get lastSyncedDate => _lastSyncedDate;

  /// Initializes the local prayer settings table and synchronizes prayers
  Future<void> init() async {
    try {
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

      await _loadSavedSettings();
      await syncPrayers();

      if (!_isInitialized) {
        WidgetsBinding.instance.addObserver(this);
        _scheduleMidnightRollover();
        _startHeartbeat();
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('Error initializing PrayerTimeService: $e');
    }
  }

  /// App lifecycle observer — refreshes adan times immediately when returning to the app
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_lastSyncedDate != todayStr) {
        syncPrayers();
      }
    }
  }

  /// Schedules automatic recalculation and daily rollover when midnight arrives
  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    final delay = tomorrow.difference(now);

    _midnightTimer = Timer(delay, () async {
      await syncPrayers();
      _scheduleMidnightRollover();
    });
  }

  /// Heartbeat check every 30 minutes in case device was sleeping across midnight
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_lastSyncedDate != todayStr) {
        syncPrayers();
      }
    });
  }

  /// Loads cached location & prayer settings from SQLite
  Future<void> _loadSavedSettings() async {
    try {
      final rows = await db.getAll('SELECT * FROM prayer_settings WHERE id = ?', ['current']);
      if (rows.isNotEmpty) {
        final row = rows.first;
        _currentCity = (row['city'] as String?) ?? _currentCity;
        _currentCountry = (row['country'] as String?) ?? _currentCountry;
        _currentTimezone = (row['timezone'] as String?) ?? _currentTimezone;
        _currentLat = (row['latitude'] as num?)?.toDouble() ?? _currentLat;
        _currentLng = (row['longitude'] as num?)?.toDouble() ?? _currentLng;
        _lastSyncedDate = (row['last_sync_date'] as String?) ?? '';
      }
    } catch (_) {}
  }

  /// Saves resolved location to SQLite
  Future<void> _saveSettings() async {
    try {
      await db.execute('''
        INSERT INTO prayer_settings (
          id, city, country, latitude, longitude, timezone, last_sync_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          city = excluded.city,
          country = excluded.country,
          latitude = excluded.latitude,
          longitude = excluded.longitude,
          timezone = excluded.timezone,
          last_sync_date = excluded.last_sync_date
      ''', [
        'current',
        _currentCity,
        _currentCountry,
        _currentLat,
        _currentLng,
        _currentTimezone,
        _lastSyncedDate,
      ]);
    } catch (_) {}
  }

  /// Resolves the user's geographical coordinates and timezone via LocationService.
  Future<Coordinates> resolveCoordinates({bool forceRefresh = false}) async {
    if (!forceRefresh && _currentCity != 'Auto' && _currentLat != 0) {
      return Coordinates(_currentLat, _currentLng);
    }

    try {
      final loc = await LocationService().getLocation(forceRefresh: forceRefresh);
      _currentLat = loc.latitude;
      _currentLng = loc.longitude;
      _currentCity = loc.city;
      _currentCountry = loc.country;
      _currentTimezone = DateTime.now().timeZoneName;
      await _saveSettings();
      return Coordinates(_currentLat, _currentLng);
    } catch (_) {
      return Coordinates(_currentLat, _currentLng);
    }
  }

  /// Calculates the exact Qibla bearing towards the Kaaba in Mecca
  double get qiblaBearing =>
      QiblaService().calculateQiblaBearing(_currentLat, _currentLng);

  /// Selects the optimal Islamic calculation method based on country / coordinates
  CalculationParameters _getCalculationMethod() {
    final country = _currentCountry.toLowerCase();
    if (country.contains('tunis') || country.contains('alger')) {
      return CalculationMethodParameters.tunisia();
    } else if (country.contains('egypt')) {
      return CalculationMethodParameters.egyptian();
    } else if (country.contains('morocco')) {
      return CalculationMethodParameters.morocco();
    } else if (country.contains('saudi') || country.contains('arabia')) {
      return CalculationMethodParameters.ummAlQura();
    } else if (country.contains('pakistan') || country.contains('india') || country.contains('bangladesh')) {
      return CalculationMethodParameters.karachi();
    } else if (country.contains('united states') || country.contains('canada')) {
      return CalculationMethodParameters.northAmerica();
    } else if (country.contains('singapore') || country.contains('malaysia')) {
      return CalculationMethodParameters.singapore();
    }

    // Default by offset
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    if (offsetHours == 1) {
      return CalculationMethodParameters.tunisia();
    } else if (offsetHours == 2) {
      return CalculationMethodParameters.egyptian();
    } else if (offsetHours == 3) {
      return CalculationMethodParameters.ummAlQura();
    } else if (offsetHours >= 5 && offsetHours <= 6) {
      return CalculationMethodParameters.karachi();
    }

    return CalculationMethodParameters.muslimWorldLeague();
  }

  /// Calculates the 5 daily prayer times for the provided date
  Future<List<PrayerItem>> calculatePrayersForDate(DateTime date) async {
    final coords = await resolveCoordinates();
    final params = _getCalculationMethod();

    final prayerTimes = PrayerTimes(
      coordinates: coords,
      date: date,
      calculationParameters: params,
      precision: false,
    );

    String formatAdan(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());

    return [
      PrayerItem(
        id: 'fajr',
        name: 'Fajr',
        icon: 'fajr',
        sortOrder: 1,
        time: prayerTimes.fajr.toLocal(),
        formattedTime: formatAdan(prayerTimes.fajr),
      ),
      PrayerItem(
        id: 'dhuhr',
        name: 'Dhuhr',
        icon: 'dhuhr',
        sortOrder: 2,
        time: prayerTimes.dhuhr.toLocal(),
        formattedTime: formatAdan(prayerTimes.dhuhr),
      ),
      PrayerItem(
        id: 'asr',
        name: 'Asr',
        icon: 'asr',
        sortOrder: 3,
        time: prayerTimes.asr.toLocal(),
        formattedTime: formatAdan(prayerTimes.asr),
      ),
      PrayerItem(
        id: 'maghrib',
        name: 'Maghrib',
        icon: 'maghrib',
        sortOrder: 4,
        time: prayerTimes.maghrib.toLocal(),
        formattedTime: formatAdan(prayerTimes.maghrib),
      ),
      PrayerItem(
        id: 'isha',
        name: 'Isha',
        icon: 'isha',
        sortOrder: 5,
        time: prayerTimes.isha.toLocal(),
        formattedTime: formatAdan(prayerTimes.isha),
      ),
    ];
  }

  /// Returns the next upcoming prayer relative to current local time
  Future<PrayerItem?> getNextPrayer([DateTime? currentTime]) async {
    final target = currentTime ?? DateTime.now();
    final prayers = await calculatePrayersForDate(target);
    for (final p in prayers) {
      if (p.time.isAfter(target)) {
        return p;
      }
    }
    // All prayers passed for today, next is tomorrow's Fajr
    final tomorrowPrayers = await calculatePrayersForDate(target.add(const Duration(days: 1)));
    return tomorrowPrayers.isNotEmpty ? tomorrowPrayers.first : null;
  }

  /// Canonical deterministic ID for each of the strictly 5 Islamic prayers.
  /// Guarantees that IDs are 100% stable, persistent, and never duplicate or recreate.
  static String prayerIdForCode(String code) =>
      IdGenerator.generateDeterministicId('canonical_prayer_${code.toLowerCase()}');

  /// Static fallback list of the 5 canonical daily Islamic prayers.
  static List<Prayer> defaultPrayers([String? userId]) {
    final uid = userId ?? currentUserId;
    return [
      Prayer(
        id: prayerIdForCode('fajr'),
        userId: uid,
        prayerCode: 'fajr',
        name: 'Fajr',
        icon: 'fajr',
        time: '05:30 AM',
        sortOrder: 1,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: prayerIdForCode('dhuhr'),
        userId: uid,
        prayerCode: 'dhuhr',
        name: 'Dhuhr',
        icon: 'dhuhr',
        time: '12:45 PM',
        sortOrder: 2,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: prayerIdForCode('asr'),
        userId: uid,
        prayerCode: 'asr',
        name: 'Asr',
        icon: 'asr',
        time: '04:15 PM',
        sortOrder: 3,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: prayerIdForCode('maghrib'),
        userId: uid,
        prayerCode: 'maghrib',
        name: 'Maghrib',
        icon: 'maghrib',
        time: '06:45 PM',
        sortOrder: 4,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      Prayer(
        id: prayerIdForCode('isha'),
        userId: uid,
        prayerCode: 'isha',
        name: 'Isha',
        icon: 'isha',
        time: '08:15 PM',
        sortOrder: 5,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
    ];
  }

  /// Streams the 5 daily prayers from the dedicated `prayers` table.
  /// Pure projection without side-effects to prevent recreation loops.
  Stream<List<Prayer>> watchPrayers() {
    final uid = currentUserId;
    final query = uid.isNotEmpty
        ? "SELECT id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at FROM prayers WHERE (user_id = ? OR user_id IS NULL OR user_id = '') ORDER BY sort_order ASC"
        : 'SELECT id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at FROM prayers ORDER BY sort_order ASC';
    final params = uid.isNotEmpty ? [uid] : <dynamic>[];

    return db.watch(query, parameters: params).map((rows) {
      if (rows.isEmpty) {
        return defaultPrayers(uid);
      }
      return rows.map((r) => Prayer.fromRow(r)).toList();
    });
  }

  /// Synchronizes the 5 dedicated daily prayers into the `prayers` table.
  /// Strictly maintains exactly 5 canonical rows (Fajr, Dhuhr, Asr, Maghrib, Isha).
  /// Never duplicates prayers, preserves completion state, and protects against race conditions.
  Future<void> syncPrayers({bool forceLocation = false}) async {
    if (!isDatabaseInitialized || _isSyncing) return;
    _isSyncing = true;

    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final isNewDay = _lastSyncedDate.isNotEmpty && _lastSyncedDate != todayStr;

      if (forceLocation) {
        await resolveCoordinates(forceRefresh: true);
      }

      // 1. Purge legacy prayers from habits table & prayer category from habit_categories
      await db.execute("DELETE FROM habits WHERE kind = 'Prayers' OR id LIKE 'habit_prayer_%'");
      await db.execute("DELETE FROM habit_categories WHERE id = 'cat_prayers' OR LOWER(name) = 'prayers'");

      final prayerItems = await calculatePrayersForDate(now);
      final uid = currentUserId;
      final utcNow = now.toUtc().toIso8601String();

      // Canonical 5 IDs
      final canonicalIds = [
        prayerIdForCode('fajr'),
        prayerIdForCode('dhuhr'),
        prayerIdForCode('asr'),
        prayerIdForCode('maghrib'),
        prayerIdForCode('isha'),
      ];

      // 2. Fetch existing records in dedicated prayers table
      final existingRows = await db.getAll(
        "SELECT id, prayer_code, is_done, time FROM prayers WHERE id IN (?, ?, ?, ?, ?)",
        canonicalIds,
      );
      final existingMap = {
        for (var r in existingRows)
          (r['prayer_code'] as String? ?? '').toLowerCase(): r
      };

      // 3. Upsert exactly the 5 prayers by canonical ID
      for (final item in prayerItems) {
        final code = item.id.toLowerCase();
        final prayerId = prayerIdForCode(code);
        final existing = existingMap[code];

        if (existing == null) {
          await db.execute('''
            INSERT INTO prayers (
              id, user_id, prayer_code, name, icon, time, sort_order, is_done, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              user_id = excluded.user_id,
              name = excluded.name,
              icon = excluded.icon,
              time = excluded.time,
              sort_order = excluded.sort_order,
              updated_at = excluded.updated_at
          ''', [
            prayerId,
            uid,
            code,
            item.name,
            item.icon,
            item.formattedTime,
            item.sortOrder,
            utcNow,
            utcNow,
          ]);
        } else {
          // If rollover to a new day, reset is_done to 0
          if (isNewDay) {
            await db.execute('''
              UPDATE prayers SET
                user_id = ?,
                name = ?,
                icon = ?,
                time = ?,
                sort_order = ?,
                is_done = 0,
                updated_at = ?
              WHERE id = ?
            ''', [
              uid,
              item.name,
              item.icon,
              item.formattedTime,
              item.sortOrder,
              utcNow,
              prayerId,
            ]);
          } else {
            // Update time and details, PRESERVE existing is_done state
            await db.execute('''
              UPDATE prayers SET
                user_id = ?,
                name = ?,
                icon = ?,
                time = ?,
                sort_order = ?,
                updated_at = ?
              WHERE id = ?
            ''', [
              uid,
              item.name,
              item.icon,
              item.formattedTime,
              item.sortOrder,
              utcNow,
              prayerId,
            ]);
          }
        }
      }

      // 4. Clean up any rogue or duplicate prayer rows outside the 5 canonical IDs
      await db.execute(
        "DELETE FROM prayers WHERE id NOT IN (?, ?, ?, ?, ?)",
        canonicalIds,
      );

      _lastSyncedDate = todayStr;
      await _saveSettings();

      // Schedule Adhan notifications and Fajr Wake-Up Alarm
      await AdhanAlarmService().scheduleAllPrayers(prayerItems);

      // Synchronize home screen widgets
      AppWidgetSyncService().syncHabitStreak();
    } catch (e) {
      debugPrint('Error syncing prayers: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Backward compatibility alias for syncPrayers
  Future<void> syncPrayerHabits({bool forceLocation = false}) =>
      syncPrayers(forceLocation: forceLocation);

  /// Resets today's prayer tasks back to undone (`is_done = 0`).
  /// CRITICAL GUARANTEES:
  ///   - Does NOT delete or create rows (strictly preserves the 5 rows).
  ///   - Keeps all previous EXP and streak progress intact.
  ///   - Resets only the completion state back to undone.
  Future<void> resetPrayers() async {
    if (!isDatabaseInitialized) return;
    final uid = currentUserId;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    try {
      final query = uid.isNotEmpty
          ? "UPDATE prayers SET is_done = 0, updated_at = ? WHERE (user_id = ? OR user_id IS NULL OR user_id = '')"
          : 'UPDATE prayers SET is_done = 0, updated_at = ?';
      final params = uid.isNotEmpty ? [nowUtc, uid] : [nowUtc];
      await db.execute(query, params);
      StatsRepository().invalidateStats();
      AppWidgetSyncService().syncHabitStreak();
    } catch (e) {
      debugPrint('[PrayerTimeService] Error resetting prayers: $e');
    }
  }

  /// Toggles completion of a single prayer and awards/reverts EXP without recreating any records.
  Future<void> togglePrayer(String prayerId, bool isDone) async {
    if (!isDatabaseInitialized) return;
    final uid = currentUserId;
    final now = DateTime.now();
    final nowUtc = now.toUtc().toIso8601String();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final logEventId = IdGenerator.generateDeterministicId('xpevent_${prayerId}_$today');
    final habitLogId = IdGenerator.generateDeterministicId('habitlog_prayer_${prayerId}_$today');

    try {
      // 1. Update prayer status in dedicated table
      await db.execute(
        'UPDATE prayers SET is_done = ?, updated_at = ? WHERE id = ?',
        [isDone ? 1 : 0, nowUtc, prayerId],
      );

      // 2. Award or remove XP in logs table & sync habit_logs for streak calculation
      if (isDone) {
        await db.execute('''
          INSERT OR REPLACE INTO logs (
            id, user_id, task_id, event_type, xp_earned, timestamp
          ) VALUES (?, ?, ?, 'prayer_completed', 25, ?)
        ''', [logEventId, uid, prayerId, nowUtc]);

        await db.execute('''
          INSERT OR REPLACE INTO habit_logs (
            id, user_id, habit_id, log_date, status, value, created_at, updated_at
          ) VALUES (?, ?, ?, ?, 'done', 1, ?, ?)
        ''', [habitLogId, uid, prayerId, today, nowUtc, nowUtc]);
      } else {
        await db.execute('DELETE FROM logs WHERE id = ?', [logEventId]);
        await db.execute('DELETE FROM habit_logs WHERE id = ?', [habitLogId]);
      }

      StatsRepository().invalidateStats();
      await syncGlobalUserLevel();
      AppWidgetSyncService().syncHabitStreak();
    } catch (e) {
      debugPrint('[PrayerTimeService] Error toggling prayer: $e');
    }
  }

  void dispose() {
    _midnightTimer?.cancel();
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
