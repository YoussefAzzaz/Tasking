import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/location_service.dart';
import 'package:axis/data/qibla_service.dart';

/// Representation of a single daily Islamic prayer
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
/// and synchronizes the 5 daily prayer habits in the database with automatic daily rollover.
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

  String get currentCity => _currentCity;
  String get currentCountry => _currentCountry;
  String get currentTimezone => _currentTimezone;
  double get currentLat => _currentLat;
  double get currentLng => _currentLng;
  String get lastSyncedDate => _lastSyncedDate;

  /// Initializes the local prayer settings table and synchronizes prayer habits
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
          last_sync_date TEXT
        )
      ''');

      await _loadSavedSettings();
      await syncPrayerHabits();

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
        syncPrayerHabits();
      }
    }
  }

  /// Schedules automatic recalculation when midnight arrives
  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    final delay = tomorrow.difference(now);

    _midnightTimer = Timer(delay, () async {
      await syncPrayerHabits();
      _scheduleMidnightRollover();
    });
  }

  /// Heartbeat check every 30 minutes in case device was sleeping across midnight
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (_lastSyncedDate != todayStr) {
        syncPrayerHabits();
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
        INSERT OR REPLACE INTO prayer_settings (
          id, city, country, latitude, longitude, timezone, last_sync_date
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
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
  /// Integrates hardware GPS (geolocator), IP geolocation, and regional timezone inference.
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
        id: 'habit_prayer_fajr',
        name: 'Fajr Prayer',
        icon: 'fajr',
        sortOrder: 1,
        time: prayerTimes.fajr.toLocal(),
        formattedTime: formatAdan(prayerTimes.fajr),
      ),
      PrayerItem(
        id: 'habit_prayer_dhuhr',
        name: 'Dhuhr Prayer',
        icon: 'dhuhr',
        sortOrder: 2,
        time: prayerTimes.dhuhr.toLocal(),
        formattedTime: formatAdan(prayerTimes.dhuhr),
      ),
      PrayerItem(
        id: 'habit_prayer_asr',
        name: 'Asr Prayer',
        icon: 'asr',
        sortOrder: 3,
        time: prayerTimes.asr.toLocal(),
        formattedTime: formatAdan(prayerTimes.asr),
      ),
      PrayerItem(
        id: 'habit_prayer_maghrib',
        name: 'Maghrib Prayer',
        icon: 'maghrib',
        sortOrder: 4,
        time: prayerTimes.maghrib.toLocal(),
        formattedTime: formatAdan(prayerTimes.maghrib),
      ),
      PrayerItem(
        id: 'habit_prayer_isha',
        name: 'Isha Prayer',
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

  /// Synchronizes the 5 prayer habits with the local SQLite database.
  /// Automatically creates the habits if they do not exist yet,
  /// and updates their adan times (remind_time) dynamically every day.
  Future<void> syncPrayerHabits({bool forceLocation = false}) async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      if (forceLocation) {
        await resolveCoordinates(forceRefresh: true);
      }

      // Ensure the 'Prayers' category exists
      await db.execute('''
        INSERT OR IGNORE INTO habit_categories (id, name, icon, color)
        VALUES ('cat_prayers', 'Prayers', 'mosque', '#10B981')
      ''');

      final prayers = await calculatePrayersForDate(now);
      final existingHabits = await db.getAll(
        "SELECT id, remind_time FROM habits WHERE kind = 'Prayers' OR id LIKE 'habit_prayer_%'",
      );
      final existingMap = {for (var h in existingHabits) h['id'] as String: h};

      final utcNow = now.toUtc().toIso8601String();

      for (final prayer in prayers) {
        if (!existingMap.containsKey(prayer.id)) {
          // Create the prayer habit
          await db.execute('''
            INSERT INTO habits (
              id, name, kind, icon, color, schedule_type, remind_time, target_value, sort_order, created_at, updated_at
            ) VALUES (?, ?, 'Prayers', ?, '#10B981', 'daily', ?, 25, ?, ?, ?)
          ''', [
            prayer.id,
            prayer.name,
            prayer.icon,
            prayer.formattedTime,
            prayer.sortOrder,
            utcNow,
            utcNow,
          ]);
        } else {
          // Update the daily adan time if it changed for today
          final currentRemind = existingMap[prayer.id]?['remind_time'] as String?;
          if (currentRemind != prayer.formattedTime || _lastSyncedDate != todayStr) {
            await db.execute('''
              UPDATE habits SET
                remind_time = ?,
                sort_order = ?,
                updated_at = ?
              WHERE id = ?
            ''', [
              prayer.formattedTime,
              prayer.sortOrder,
              utcNow,
              prayer.id,
            ]);
          }
        }
      }

      _lastSyncedDate = todayStr;
      await _saveSettings();

      // Synchronize home screen widgets with updated prayer habits
      AppWidgetSyncService().syncHabitStreak();
    } catch (e) {
      debugPrint('Error syncing prayer habits: $e');
    }
  }

  void dispose() {
    _midnightTimer?.cancel();
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
