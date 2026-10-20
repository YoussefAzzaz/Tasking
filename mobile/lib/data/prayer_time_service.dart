import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/app_widget_sync_service.dart';

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

  /// Resolves the user's geographical coordinates and timezone.
  /// 1. Tries fast IP Geolocation (zero permissions, seamless)
  /// 2. Falls back to device timezone offset mapping
  Future<Coordinates> resolveCoordinates({bool forceRefresh = false}) async {
    if (!forceRefresh && _currentCity != 'Auto' && _currentLat != 0) {
      return Coordinates(_currentLat, _currentLng);
    }

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse('http://ip-api.com/json'));
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final jsonStr = await response.transform(utf8.decoder).join();
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;

        if (data['status'] == 'success') {
          _currentLat = (data['lat'] as num).toDouble();
          _currentLng = (data['lon'] as num).toDouble();
          _currentCity = (data['city'] as String?) ?? 'Local';
          _currentCountry = (data['country'] as String?) ?? '';
          _currentTimezone = (data['timezone'] as String?) ?? '';
          await _saveSettings();
          return Coordinates(_currentLat, _currentLng);
        }
      }
    } catch (_) {
      // Offline or network timeout, fallback to timezone offset inference
    }

    // Fallback: Map the device's local timezone offset to major Islamic regional coordinates
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    switch (offsetHours) {
      case 1: // West Africa / Central Europe / Algeria / Tunisia
        _currentLat = 35.7065;
        _currentLng = -0.6292;
        _currentCity = 'North Africa (GMT+1)';
        _currentCountry = 'Algeria';
        break;
      case 2: // Egypt / Levant / Eastern Europe
        _currentLat = 30.0444;
        _currentLng = 31.2357;
        _currentCity = 'Cairo Region (GMT+2)';
        _currentCountry = 'Egypt';
        break;
      case 3: // Saudi Arabia / Gulf / East Africa
        _currentLat = 21.4225;
        _currentLng = 39.8262;
        _currentCity = 'Makkah Region (GMT+3)';
        _currentCountry = 'Saudi Arabia';
        break;
      case 4: // UAE / Oman
        _currentLat = 25.2048;
        _currentLng = 55.2708;
        _currentCity = 'Dubai Region (GMT+4)';
        _currentCountry = 'United Arab Emirates';
        break;
      case 5: // Pakistan / Central Asia
        _currentLat = 24.8607;
        _currentLng = 67.0011;
        _currentCity = 'Karachi Region (GMT+5)';
        _currentCountry = 'Pakistan';
        break;
      case 6: // Bangladesh
        _currentLat = 23.8103;
        _currentLng = 90.4125;
        _currentCity = 'Dhaka Region (GMT+6)';
        _currentCountry = 'Bangladesh';
        break;
      case 7: // Western Indonesia
        _currentLat = -6.2088;
        _currentLng = 106.8456;
        _currentCity = 'Jakarta Region (GMT+7)';
        _currentCountry = 'Indonesia';
        break;
      case 8: // Malaysia / Singapore
        _currentLat = 3.1390;
        _currentLng = 101.6869;
        _currentCity = 'Kuala Lumpur (GMT+8)';
        _currentCountry = 'Malaysia';
        break;
      case 0: // UK / Morocco / Portugal
        _currentLat = 33.5731;
        _currentLng = -7.5898;
        _currentCity = 'Casablanca (GMT)';
        _currentCountry = 'Morocco';
        break;
      case -5: // North America Eastern
        _currentLat = 40.7128;
        _currentLng = -74.0060;
        _currentCity = 'New York (EST)';
        _currentCountry = 'United States';
        break;
      case -6: // North America Central
        _currentLat = 41.8781;
        _currentLng = -87.6298;
        _currentCity = 'Chicago (CST)';
        _currentCountry = 'United States';
        break;
      case -8: // North America Pacific
        _currentLat = 34.0522;
        _currentLng = -118.2437;
        _currentCity = 'Los Angeles (PST)';
        _currentCountry = 'United States';
        break;
      default:
        _currentLat = 21.4225;
        _currentLng = 39.8262;
        _currentCity = 'Makkah Region';
        _currentCountry = 'Saudi Arabia';
        break;
    }

    _currentTimezone = DateTime.now().timeZoneName;
    await _saveSettings();
    return Coordinates(_currentLat, _currentLng);
  }

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
