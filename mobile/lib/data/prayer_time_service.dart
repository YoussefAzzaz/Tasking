import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart' hide Prayer;
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/location_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';

import 'prayers/prayer_model.dart';
import 'prayers/prayer_calculator.dart';
import 'prayers/prayer_repository.dart';
import 'prayers/prayer_completion_handler.dart';
import 'daily_prayer_status_repository.dart';

// Re-export modular components for clean architecture and 100% backwards compatibility
export 'prayers/prayer_model.dart';
export 'prayers/prayer_calculator.dart';
export 'prayers/prayer_repository.dart';
export 'prayers/prayer_completion_handler.dart';

/// Service facade that coordinates location resolution, astronomical Adhan calculations,
/// SQLite persistence in the dedicated `prayers` table, and daily alarms.
class PrayerTimeService with WidgetsBindingObserver {
  static final PrayerTimeService _instance = PrayerTimeService._();
  factory PrayerTimeService() => _instance;
  PrayerTimeService._();

  final PrayerCalculator _calculator = const PrayerCalculator();
  final PrayerRepository _repository = PrayerRepository();
  final PrayerCompletionHandler _completionHandler = PrayerCompletionHandler();

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

  /// Great Circle bearing to Kaaba in Mecca
  double get qiblaBearing => _calculator.calculateQiblaBearing(_currentLat, _currentLng);

  /// Canonical deterministic ID for each of the strictly 5 Islamic prayers.
  static String prayerIdForCode(String code, [String? userId]) =>
      PrayerRepository.prayerIdForCode(code, userId);

  /// Static fallback list of the 5 canonical daily Islamic prayers.
  static List<Prayer> defaultPrayers([String? userId]) =>
      PrayerRepository.defaultPrayers(userId);

  /// Initializes the local prayer settings and synchronizes today's prayers
  Future<void> init() async {
    try {
      await _loadSavedSettings();
      await syncPrayers();

      if (!_isInitialized) {
        WidgetsBinding.instance.addObserver(this);
        _scheduleMidnightRollover();
        _startHeartbeat();
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('[PrayerTimeService] Error initializing: $e');
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

  /// Schedules automatic recalculation and daily rollover when midnight (00:00) arrives
  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    final delay = tomorrow.difference(now);

    _midnightTimer = Timer(delay, () async {
      final uid = currentUserId;
      if (uid.isNotEmpty) {
        await _repository.resetPrayers(uid);
      }
      await syncPrayers();
      await DailyPrayerStatusRepository().syncMyDailyPrayerStatus();
      _scheduleMidnightRollover();
    });
  }

  /// Heartbeat check every 15 minutes in case device was sleeping across midnight (00:00)
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 15), (_) async {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_lastSyncedDate != todayStr) {
        final uid = currentUserId;
        if (uid.isNotEmpty) {
          await _repository.resetPrayers(uid);
        }
        await syncPrayers();
        await DailyPrayerStatusRepository().syncMyDailyPrayerStatus();
      }
    });
  }

  /// Loads cached location & prayer settings from SQLite
  Future<void> _loadSavedSettings() async {
    try {
      if (!isDatabaseInitialized) return;
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
    } catch (e) {
      debugPrint('[PrayerTimeService] _loadSavedSettings notice: $e');
    }
  }

  /// Saves resolved location to SQLite
  Future<void> _saveSettings() async {
    try {
      if (!isDatabaseInitialized) return;
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
    } catch (e) {
      debugPrint('[PrayerTimeService] _saveSettings notice: $e');
    }
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
    } catch (e) {
      debugPrint('[PrayerTimeService] resolveCoordinates notice: $e');
      return Coordinates(_currentLat, _currentLng);
    }
  }

  /// Calculates the 5 daily prayer times for the provided date using domain calculator
  Future<List<PrayerItem>> calculatePrayersForDate(DateTime date) async {
    final coords = await resolveCoordinates();
    return _calculator.calculatePrayers(
      coordinates: coords,
      date: date,
      country: _currentCountry,
    );
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

  /// Streams the 5 daily prayers from the dedicated `prayers` table.
  Stream<List<Prayer>> watchPrayers([String? userId]) =>
      _repository.watchPrayers(userId ?? currentUserId);

  /// Synchronizes the 5 dedicated daily prayers into the `prayers` table.
  /// Strictly maintains exactly 5 canonical rows (Fajr, Dhuhr, Asr, Maghrib, Isha).
  /// Never resets is_done completion state, avoiding cross-device unchecking race conditions.
  Future<void> syncPrayers({bool forceLocation = false}) async {
    if (!isDatabaseInitialized || _isSyncing) return;
    _isSyncing = true;

    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final uid = currentUserId;

      if (_lastSyncedDate.isNotEmpty && _lastSyncedDate != todayStr && uid.isNotEmpty) {
        await _repository.resetStalePrayersFromPreviousDays(uid, todayStr);
      }

      if (forceLocation) {
        await resolveCoordinates(forceRefresh: true);
      }

      final prayerItems = await calculatePrayersForDate(now);

      await _repository.upsertPrayers(uid, prayerItems);

      _lastSyncedDate = todayStr;
      await _saveSettings();

      // Schedule Adhan notifications and Fajr Wake-Up Alarm
      await AdhanAlarmService().scheduleAllPrayers(prayerItems);

      // Synchronize home screen widgets
      AppWidgetSyncService().syncHabitStreak();

      // Ensure daily prayer status for today is synced
      unawaited(DailyPrayerStatusRepository().syncMyDailyPrayerStatus());
    } catch (e) {
      debugPrint('[PrayerTimeService] Error syncing prayers: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Backward compatibility alias for syncPrayers
  Future<void> syncPrayerHabits({bool forceLocation = false}) =>
      syncPrayers(forceLocation: forceLocation);

  /// Resets today's prayer tasks back to undone (`is_done = 0`).
  Future<void> resetPrayers([String? userId]) async {
    final uid = userId ?? currentUserId;
    await _repository.resetPrayers(uid);
    await DailyPrayerStatusRepository().resetDailyPrayerStatusForToday(uid);
    AppWidgetSyncService().syncHabitStreak();
  }

  /// Toggles completion of a single prayer and awards/reverts EXP without recreating any records.
  Future<void> togglePrayer(String prayerId, bool isDone, [String? userId]) =>
      _completionHandler.togglePrayer(
        prayerId: prayerId,
        isDone: isDone,
        userId: userId ?? currentUserId,
      );

  void dispose() {
    _midnightTimer?.cancel();
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
