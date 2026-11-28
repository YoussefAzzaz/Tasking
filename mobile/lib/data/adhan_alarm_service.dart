import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/notifications/notification_ids.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/prayers/adhan_notification_channels.dart';
import 'package:axis/data/prayers/adhan_sound_service.dart';
import 'package:axis/ui/habits/widgets/fajr_alarm_dialog.dart';
import 'package:axis/ui/prayers/adhan_full_screen_alarm.dart';

/// Arabic prayer name lookup for full-screen alarm display.
const _prayerNameArabic = <String, String>{
  'Fajr': 'الفجر',
  'Dhuhr': 'الظهر',
  'Asr': 'العصر',
  'Maghrib': 'المغرب',
  'Isha': 'العشاء',
};

/// Centralized service managing prayer Adhan notifications,
/// scheduling, full-screen alarm overlays, and the persistent
/// cognitive Fajr Wake-Up Alarm.
///
/// Uses the OS alarm audio channel so the Adhan plays at full
/// alarm volume even when the device is in silent/DND mode,
/// and fires full-screen intents to wake the screen and show
/// the adhan overlay even when the app is closed or locked.
class AdhanAlarmService {
  static final AdhanAlarmService _instance = AdhanAlarmService._();
  factory AdhanAlarmService() => _instance;
  AdhanAlarmService._();

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  static const MethodChannel _platformChannel = MethodChannel('com.axis.axis/settings');

  bool _adhanNotificationsEnabled = true;
  bool _fajrAlarmEnabled = true;
  bool _adhanPermissionsPrompted = false;
  AudioPlayer? _alarmPlayer;
  Timer? _vibrationTimer;
  bool _isAlarmRinging = false;
  bool _isModalShowing = false;

  /// Guards against duplicate full-screen adhan overlays.
  bool isFullScreenAlarmShowing = false;
  bool _platformHandlerRegistered = false;
  static final Set<String> _inMemoryDismissedAdhans = <String>{};
  Map<String, String>? _activeAdhanInfo;
  Map<String, String>? get activeAdhanInfo => _activeAdhanInfo;

  bool get adhanNotificationsEnabled => _adhanNotificationsEnabled;
  bool get fajrAlarmEnabled => _fajrAlarmEnabled;
  bool get isAlarmRinging => _isAlarmRinging;
  bool get hasPromptedPermissions => _adhanPermissionsPrompted;

  bool _settingsLoaded = false;

  /// Canonical sort order (1..5) for a prayer code, id, or display name.
  static int? sortOrderForPrayerCode(String raw) {
    final lower = raw.trim().toLowerCase();
    if (lower.isEmpty) return null;
    if (lower.contains('fajr')) return 1;
    if (lower.contains('dhuhr')) return 2;
    if (lower.contains('asr')) return 3;
    if (lower.contains('maghrib')) return 4;
    if (lower.contains('isha')) return 5;
    return null;
  }

  /// Canonical prayer code ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha') from an id or name.
  static String? canonicalPrayerCode(String raw) {
    switch (sortOrderForPrayerCode(raw)) {
      case 1:
        return 'fajr';
      case 2:
        return 'dhuhr';
      case 3:
        return 'asr';
      case 4:
        return 'maghrib';
      case 5:
        return 'isha';
      default:
        return null;
    }
  }

  Future<void> _loadAlarmSettingsFromDb() async {
    if (_settingsLoaded || !isDatabaseInitialized) return;
    try {
      final rows = await db.getAll('SELECT * FROM prayer_settings WHERE id = ?', ['current']);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final adhanVal = row['adhan_notifications_enabled'] as num?;
        final fajrVal = row['fajr_alarm_enabled'] as num?;
        final promptedVal = row['adhan_permissions_prompted'] as num?;
        if (adhanVal != null) _adhanNotificationsEnabled = adhanVal.toInt() == 1;
        if (fajrVal != null) _fajrAlarmEnabled = fajrVal.toInt() == 1;
        if (promptedVal != null) _adhanPermissionsPrompted = promptedVal.toInt() == 1;
      }
      _settingsLoaded = true;
    } catch (e) {
      debugPrint('[AdhanAlarmService] _loadAlarmSettingsFromDb notice: $e');
    }
  }

  /// Checks whether the given prayer has already been marked completed today in SQLite.
  Future<bool> isPrayerCompletedToday(String prayerCodeOrId) async {
    final code = canonicalPrayerCode(prayerCodeOrId);
    if (code == null || !isDatabaseInitialized) return false;
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final uid = currentUserId;

      final logQuery = uid.isNotEmpty
          ? '''
            SELECT id FROM habit_logs
            WHERE log_date = ?
              AND status = 'done'
              AND (LOWER(habit_id) = ? OR LOWER(habit_id) LIKE ?)
              AND (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest')
            LIMIT 1
          '''
          : '''
            SELECT id FROM habit_logs
            WHERE log_date = ?
              AND status = 'done'
              AND (LOWER(habit_id) = ? OR LOWER(habit_id) LIKE ?)
            LIMIT 1
          ''';
      final logParams = uid.isNotEmpty
          ? [todayStr, 'prayer_$code', '%_$code', uid]
          : [todayStr, 'prayer_$code', '%_$code'];
      final lRow = await db.getOptional(logQuery, logParams);
      if (lRow != null) return true;

      final prayerQuery = uid.isNotEmpty
          ? '''
            SELECT is_done, updated_at FROM prayers
            WHERE (LOWER(prayer_code) = ? OR LOWER(id) = ? OR LOWER(id) LIKE ?)
              AND is_done = 1
              AND (user_id = ? OR user_id IS NULL OR user_id = '' OR user_id = 'local_guest')
            LIMIT 1
          '''
          : '''
            SELECT is_done, updated_at FROM prayers
            WHERE (LOWER(prayer_code) = ? OR LOWER(id) = ? OR LOWER(id) LIKE ?)
              AND is_done = 1
            LIMIT 1
          ''';
      final prayerParams = uid.isNotEmpty
          ? [code, 'prayer_$code', '%_$code', uid]
          : [code, 'prayer_$code', '%_$code'];
      final pRow = await db.getOptional(prayerQuery, prayerParams);
      if (pRow == null) return false;

      final updatedAt = pRow['updated_at']?.toString() ?? '';
      if (updatedAt.isEmpty) return false;
      try {
        final dt = DateTime.parse(updatedAt).toLocal();
        return dt.year == now.year && dt.month == now.month && dt.day == now.day;
      } catch (_) {
        return updatedAt.startsWith(todayStr);
      }
    } catch (e) {
      debugPrint('[AdhanAlarmService] isPrayerCompletedToday error: $e');
      return false;
    }
  }

  /// Checks whether today's adhan for this prayer has already been dismissed by the user.
  Future<bool> isAdhanDismissedToday(String prayerCodeOrId) async {
    final code = canonicalPrayerCode(prayerCodeOrId);
    if (code == null) return false;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = '${todayStr}_$code';
    if (_inMemoryDismissedAdhans.contains(key)) return true;
    if (!isDatabaseInitialized) return false;
    try {
      final rows = await db.getAll(
        'SELECT id FROM prayer_adhan_events WHERE id = ? AND dismissed = 1 LIMIT 1',
        [key],
      );
      if (rows.isNotEmpty) {
        _inMemoryDismissedAdhans.add(key);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Backward-compatible alias for checking if today's adhan was dismissed.
  Future<bool> isAdhanHandledOrDismissedToday(String prayerCodeOrId) async {
    return isAdhanDismissedToday(prayerCodeOrId);
  }

  /// Marks today's adhan for this prayer as triggered to log telemetry.
  Future<void> markAdhanTriggeredToday(String prayerCodeOrId) async {
    final code = canonicalPrayerCode(prayerCodeOrId);
    if (code == null) return;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = '${todayStr}_$code';
    if (!isDatabaseInitialized) return;
    try {
      await db.execute('''
        INSERT INTO prayer_adhan_events (id, prayer_code, event_date, dismissed, triggered_at)
        VALUES (?, ?, ?, 0, ?)
        ON CONFLICT(id) DO UPDATE SET triggered_at = excluded.triggered_at
      ''', [key, code, todayStr, DateTime.now().toIso8601String()]);
    } catch (_) {}
  }

  /// Marks today's adhan for this prayer as dismissed, stopping sound and cancelling related alarms.
  Future<void> markAdhanDismissedToday(String prayerCodeOrId) async {
    final code = canonicalPrayerCode(prayerCodeOrId);
    if (code == null) return;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final key = '${todayStr}_$code';
    _inMemoryDismissedAdhans.add(key);
    _activeAdhanInfo = null;
    if (isDatabaseInitialized) {
      try {
        await db.execute('''
          INSERT INTO prayer_adhan_events (id, prayer_code, event_date, dismissed, triggered_at)
          VALUES (?, ?, ?, 1, ?)
          ON CONFLICT(id) DO UPDATE SET dismissed = 1
        ''', [key, code, todayStr, DateTime.now().toIso8601String()]);
      } catch (_) {}
    }
    // If Fajr adhan is dismissed, cancel the scheduled +1m Fajr wake-up verification alarm immediately
    if (code == 'fajr' && isSupportedPlatform) {
      try {
        await AwesomeNotifications().cancelSchedule(NotificationIds.fajrLegacyWakeup);
        await AwesomeNotifications().cancel(NotificationIds.fajrLegacyWakeup);
        await AwesomeNotifications().dismiss(NotificationIds.fajrLegacyWakeup);
      } catch (_) {}
    }
  }

  /// Explicitly dismisses the active adhan for a prayer and stops all sound & vibration.
  Future<void> dismissAdhan({String? prayerName, String? prayerId}) async {
    final lookup = (prayerId != null && prayerId.isNotEmpty)
        ? prayerId
        : (prayerName ?? 'fajr');
    await markAdhanDismissedToday(lookup);
    await stopAlarmSound();
  }

  /// Cancels today's scheduled/active notification when a prayer is marked done,
  /// or re-evaluates scheduling when unchecked back to undone.
  Future<void> onPrayerCompletedToday(
    String prayerCodeOrId, {
    required bool isDone,
  }) async {
    if (!isSupportedPlatform) return;
    final sortOrder = sortOrderForPrayerCode(prayerCodeOrId);
    if (sortOrder == null) return;

    final notifId = NotificationIds.adhanForOrder(sortOrder);
    final nativeReqCode = NotificationIds.adhanNativeAlarmForOrder(sortOrder);

    try {
      await _loadAlarmSettingsFromDb();
      if (isDone) {
        await AwesomeNotifications().cancel(notifId);
        await AwesomeNotifications().cancelSchedule(notifId);
        await AwesomeNotifications().dismiss(notifId);
        await cancelNativeAlarm(nativeReqCode);
        if (sortOrder == 1) {
          await AwesomeNotifications().cancel(NotificationIds.fajrLegacyWakeup);
          await AwesomeNotifications().cancelSchedule(NotificationIds.fajrLegacyWakeup);
          await AwesomeNotifications().dismiss(NotificationIds.fajrLegacyWakeup);
        }
        if (_isAlarmRinging || sortOrder == 1) {
          await stopAlarmSound();
        }
        // Roll forward to tomorrow's prayer time for this slot so tomorrow stays scheduled.
        if (_adhanNotificationsEnabled || (_fajrAlarmEnabled && sortOrder == 1)) {
          final todayPrayers =
              await PrayerTimeService().calculatePrayersForDate(DateTime.now());
          await scheduleAllPrayers(todayPrayers);
        }
      } else {
        final prayers =
            await PrayerTimeService().calculatePrayersForDate(DateTime.now());
        await scheduleAllPrayers(prayers);
      }
    } catch (e) {
      debugPrint('[AdhanAlarmService] onPrayerCompletedToday error: $e');
    }
  }

  /// Registers native->Dart callback handler and initializes alarm preferences.
  Future<void> init() async {
    _registerPlatformHandler();
    // Root-cause fix: whenever the user selects a new Adhan sound, immediately
    // reschedule all 5 daily prayers so Fajr..Isha never stay bound to stale
    // notification channels with mismatched audio/loudness.
    AdhanSoundService().onSoundSelectionChanged = () {
      unawaited(_rescheduleAllPrayersForSoundChange());
    };
    try {
      await AdhanSoundService().init();
      await _loadAlarmSettingsFromDb();
      await _syncKeepAliveServiceState();
      await checkPendingNativeAdhanLaunch();
    } catch (e) {
      debugPrint('Error initializing AdhanAlarmService: $e');
    }
  }

  Future<void> _rescheduleAllPrayersForSoundChange() async {
    if (!isSupportedPlatform) return;
    try {
      final prayers =
          await PrayerTimeService().calculatePrayersForDate(DateTime.now());
      await scheduleAllPrayers(prayers);
    } catch (e) {
      debugPrint('[AdhanAlarmService] reschedule on sound change notice: $e');
    }
  }

  void _registerPlatformHandler() {
    if (_platformHandlerRegistered || !isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _platformHandlerRegistered = true;
    _platformChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAdhanTrigger') {
        final args = (call.arguments as Map?)?.cast<dynamic, dynamic>();
        if (args != null) {
          final prayerName = (args['prayerName'] as String?) ?? 'Prayer';
          final prayerId = args['prayerId'] as String?;
          final prayerTime = args['prayerTime'] as String?;
          final lookup = (prayerId != null && prayerId.isNotEmpty) ? prayerId : prayerName;
          if (await isAdhanHandledOrDismissedToday(lookup) || await isPrayerCompletedToday(lookup)) {
            debugPrint('[AdhanAlarmService] Bypassing onAdhanTrigger: already handled/dismissed today ($lookup).');
            await stopAlarmSound();
            return;
          }
          triggerAdhanFullScreen(
            prayerName: prayerName,
            prayerId: (prayerId != null && prayerId.isNotEmpty) ? prayerId : null,
            prayerTime: (prayerTime != null && prayerTime.isNotEmpty) ? prayerTime : null,
          );
        }
      }
    });
  }

  /// Checks whether current time has passed the scheduled prayer time
  /// by more than [graceMinutes] (default 30 minutes).
  static bool isAfterAdhanTime({
    String? prayerTime,
    String? prayerName,
    int graceMinutes = 30,
  }) {
    // If the alarm is currently ringing, it is definitely active.
    if (_instance._isAlarmRinging) return false;

    final now = DateTime.now();
    int? prayerMin;

    if (prayerTime != null && prayerTime.trim().isNotEmpty) {
      prayerMin = HabitRepository.parseTimeToMinutes(prayerTime);
      if (prayerMin > 24 * 60) prayerMin = null;
    }

    if (prayerMin == null && prayerName != null && prayerName.trim().isNotEmpty) {
      final defaults = PrayerTimeService.defaultPrayers();
      final match = defaults.where((p) =>
          p.name.toLowerCase() == prayerName.toLowerCase() ||
          p.id.toLowerCase() == prayerName.toLowerCase());
      if (match.isNotEmpty) {
        prayerMin = HabitRepository.parseTimeToMinutes(match.first.time);
        if (prayerMin > 24 * 60) prayerMin = null;
      }
    }

    if (prayerMin == null) return false;

    final nowMin = now.hour * 60 + now.minute;
    return nowMin > (prayerMin + graceMinutes);
  }

  /// Checks if Android launched/woke MainActivity directly for an Adhan alarm.
  Future<void> checkPendingNativeAdhanLaunch() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final payload = await _platformChannel.invokeMapMethod<String, String>('consumePendingAdhanLaunch');
      if (payload != null) {
        final prayerName = payload['prayerName'] ?? 'Prayer';
        final prayerId = payload['prayerId'];
        final prayerTime = payload['prayerTime'];
        final lookup = (prayerId != null && prayerId.isNotEmpty) ? prayerId : prayerName;
        if (await isAdhanHandledOrDismissedToday(lookup) || await isPrayerCompletedToday(lookup)) {
          debugPrint('[AdhanAlarmService] Bypassing pending native adhan launch: already handled/dismissed today ($lookup).');
          await stopAlarmSound();
          return;
        }
        if (isAfterAdhanTime(prayerTime: prayerTime, prayerName: prayerName)) {
          debugPrint('[AdhanAlarmService] Bypassing pending native adhan launch: current time is after adhan time ($prayerTime).');
          await stopAlarmSound();
          return;
        }
        triggerAdhanFullScreen(
          prayerName: prayerName,
          prayerId: (prayerId != null && prayerId.isNotEmpty) ? prayerId : null,
          prayerTime: (prayerTime != null && prayerTime.isNotEmpty) ? prayerTime : null,
        );
      }
    } catch (_) {}
  }

  /// Ensures the Android foreground keep-alive guardian service matches active alarm toggles.
  Future<void> _syncKeepAliveServiceState() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    if (_adhanNotificationsEnabled || _fajrAlarmEnabled) {
      await startKeepAliveService();
    } else {
      await stopKeepAliveService();
    }
  }

  Future<void> startKeepAliveService() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod<bool>('startKeepAliveService');
    } catch (e) {
      debugPrint('[AdhanAlarmService] startKeepAliveService error: $e');
    }
  }

  Future<void> stopKeepAliveService() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod<bool>('stopKeepAliveService');
    } catch (e) {
      debugPrint('[AdhanAlarmService] stopKeepAliveService error: $e');
    }
  }

  Future<bool> isKeepAliveRunning() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return (await _platformChannel.invokeMethod<bool>('isKeepAliveRunning')) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> bringToForegroundForAdhan({
    required String prayerName,
    String? prayerId,
    String? prayerTime,
  }) async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod<bool>('bringToForegroundForAdhan', {
        'prayerId': prayerId ?? '',
        'prayerName': prayerName,
        'prayerNameAr': _prayerNameArabic[prayerName] ?? prayerName,
        'prayerTime': prayerTime ?? '',
      });
    } catch (e) {
      debugPrint('[AdhanAlarmService] bringToForegroundForAdhan error: $e');
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return (await _platformChannel.invokeMethod<bool>('isBatteryOptimizationIgnored')) ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod<bool>('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('[AdhanAlarmService] requestIgnoreBatteryOptimizations error: $e');
    }
  }

  Future<bool> isOverlayPermissionGranted() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return (await _platformChannel.invokeMethod<bool>('isOverlayPermissionGranted')) ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> openOverlaySettings() async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod<bool>('openOverlaySettings');
    } catch (e) {
      debugPrint('[AdhanAlarmService] openOverlaySettings error: $e');
    }
  }

  /// Schedules an exact native AlarmClock wakeup to bring Axis to the foreground for Adhan.
  Future<void> scheduleNativeAlarmForTime({
    required int requestCode,
    required DateTime triggerTime,
    required String prayerName,
    String? prayerId,
    String? prayerTime,
  }) async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod<bool>('scheduleNativeAdhanAlarm', {
        'requestCode': requestCode,
        'triggerAtMillis': triggerTime.millisecondsSinceEpoch,
        'prayerId': prayerId ?? '',
        'prayerName': prayerName,
        'prayerNameAr': _prayerNameArabic[prayerName] ?? prayerName,
        'prayerTime': prayerTime ?? '',
      });
    } catch (e) {
      debugPrint('[AdhanAlarmService] scheduleNativeAlarmForTime error: $e');
    }
  }

  /// Cancels a previously scheduled native AlarmClock wakeup.
  Future<void> cancelNativeAlarm(int requestCode) async {
    if (!isSupportedPlatform || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _platformChannel.invokeMethod<bool>('cancelNativeAdhanAlarm', {
        'requestCode': requestCode,
      });
    } catch (_) {}
  }

  /// Sets whether the first-time Adhan permissions onboarding has been prompted
  Future<void> setPermissionsPrompted(bool prompted) async {
    _adhanPermissionsPrompted = prompted;
    if (!isDatabaseInitialized) return;
    try {
      await db.execute('''
        INSERT INTO prayer_settings (id, adhan_permissions_prompted) VALUES ('current', ?)
        ON CONFLICT(id) DO UPDATE SET adhan_permissions_prompted = excluded.adhan_permissions_prompted
      ''', [prompted ? 1 : 0]);
    } catch (e) {
      debugPrint('[AdhanAlarmService] setPermissionsPrompted error: $e');
    }
  }

  /// Opens the system Do Not Disturb access page directly
  Future<void> openDndSettings() async {
    if (!isSupportedPlatform) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final opened = await _platformChannel.invokeMethod<bool>('openDndSettings');
        if (opened == true) return;
      } catch (e) {
        debugPrint('[AdhanAlarmService] Native openDndSettings error: $e');
      }
    }
    try {
      await AwesomeNotifications().showGlobalDndOverridePage();
    } catch (e) {
      debugPrint('[AdhanAlarmService] showGlobalDndOverridePage fallback: $e');
    }
  }

  /// Opens the system Exact Alarm settings page
  Future<void> openExactAlarmSettings() async {
    if (!isSupportedPlatform) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final opened = await _platformChannel.invokeMethod<bool>('openExactAlarmSettings');
        if (opened == true) return;
      } catch (e) {
        debugPrint('[AdhanAlarmService] Native openExactAlarmSettings error: $e');
      }
    }
    try {
      await AwesomeNotifications().showAlarmPage();
    } catch (e) {
      debugPrint('[AdhanAlarmService] showAlarmPage fallback: $e');
    }
  }

  /// Opens the App Notification settings page
  Future<void> openNotificationSettings() async {
    if (!isSupportedPlatform) return;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final opened = await _platformChannel.invokeMethod<bool>('openAppNotificationSettings');
        if (opened == true) return;
      } catch (e) {
        debugPrint('[AdhanAlarmService] Native openAppNotificationSettings error: $e');
      }
    }
    final permChannelKey = AdhanNotificationChannels.permissionChannelKeyFor(
      AdhanSoundService().currentSound.id,
    );
    try {
      await AwesomeNotifications().showNotificationConfigPage(channelKey: permChannelKey);
    } catch (e) {
      debugPrint('[AdhanAlarmService] showNotificationConfigPage fallback: $e');
    }
  }

  /// Queries real-time status of each critical Adhan alarm permission
  Future<Map<String, bool>> checkDetailedPermissions() async {
    if (!isSupportedPlatform) {
      return {
        'notifications': true,
        'exact_alarms': true,
        'full_screen': true,
        'critical_alerts': true,
        'override_dnd': true,
        'battery_unrestricted': true,
        'display_over_apps': true,
      };
    }

    try {
      final permChannelKey = AdhanNotificationChannels.permissionChannelKeyFor(
        AdhanSoundService().currentSound.id,
      );
      bool notifAllowed = await AwesomeNotifications().isNotificationAllowed();
      final allowedList = await AwesomeNotifications().checkPermissionList(
        channelKey: permChannelKey,
        permissions: const [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.PreciseAlarms,
          NotificationPermission.FullScreenIntent,
          NotificationPermission.CriticalAlert,
          NotificationPermission.OverrideDnD,
        ],
      );

      bool exactAlarmGranted = allowedList.contains(NotificationPermission.PreciseAlarms);
      bool dndGranted = allowedList.contains(NotificationPermission.OverrideDnD);
      bool batteryUnrestricted = true;
      bool overlayGranted = true;

      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          final nativeNotif = await _platformChannel.invokeMethod<bool>('isNotificationGranted');
          if (nativeNotif != null) notifAllowed = nativeNotif;
        } catch (_) {}
        try {
          final nativeExact = await _platformChannel.invokeMethod<bool>('isExactAlarmGranted');
          if (nativeExact != null) exactAlarmGranted = nativeExact;
        } catch (_) {}
        try {
          final nativeDnd = await _platformChannel.invokeMethod<bool>('isDndOverrideGranted');
          if (nativeDnd != null) dndGranted = nativeDnd;
        } catch (_) {}
        batteryUnrestricted = await isBatteryOptimizationIgnored();
        overlayGranted = await isOverlayPermissionGranted();
      }

      return {
        'notifications': notifAllowed,
        'exact_alarms': exactAlarmGranted,
        'full_screen': allowedList.contains(NotificationPermission.FullScreenIntent),
        'critical_alerts': allowedList.contains(NotificationPermission.CriticalAlert),
        'override_dnd': dndGranted,
        'battery_unrestricted': batteryUnrestricted,
        'display_over_apps': overlayGranted,
      };
    } catch (e) {
      debugPrint('[AdhanAlarmService] checkDetailedPermissions error: $e');
      return {
        'notifications': false,
        'exact_alarms': false,
        'full_screen': false,
        'critical_alerts': false,
        'override_dnd': false,
        'battery_unrestricted': false,
        'display_over_apps': false,
      };
    }
  }

  /// Checks if all necessary permissions are granted for full-screen, unmuted adhan alarms
  Future<bool> areAllPermissionsGranted() async {
    final status = await checkDetailedPermissions();
    return (status['notifications'] ?? false) &&
        (status['exact_alarms'] ?? false) &&
        (status['full_screen'] ?? false) &&
        (status['override_dnd'] ?? false);
  }

  /// Checks and requests necessary permissions for full-screen adhan alarms:
  /// - Post Notifications (Android 13+)
  /// - Exact Alarms (Android 12/14+)
  /// - Full Screen Intents (Android 14+)
  /// - Critical Alerts / Override DND
  Future<bool> checkAndRequestPermissions({bool openSettingsIfNeeded = false}) async {
    if (!isSupportedPlatform) return true;

    try {
      final permChannelKey = AdhanNotificationChannels.permissionChannelKeyFor(
        AdhanSoundService().currentSound.id,
      );
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey: permChannelKey,
          permissions: const [
            NotificationPermission.Alert,
            NotificationPermission.Sound,
            NotificationPermission.Badge,
            NotificationPermission.Vibration,
            NotificationPermission.Light,
            NotificationPermission.FullScreenIntent,
            NotificationPermission.PreciseAlarms,
            NotificationPermission.CriticalAlert,
            NotificationPermission.OverrideDnD,
          ],
        );
      }

      // Check current status
      final status = await checkDetailedPermissions();

      // If full screen intent or precise alarms can be requested via awn
      final missingAwn = <NotificationPermission>[];
      if (status['full_screen'] != true) {
        missingAwn.add(NotificationPermission.FullScreenIntent);
      }
      if (status['critical_alerts'] != true) {
        missingAwn.add(NotificationPermission.CriticalAlert);
      }
      if (status['exact_alarms'] != true) {
        missingAwn.add(NotificationPermission.PreciseAlarms);
      }
      if (missingAwn.isNotEmpty) {
        await AwesomeNotifications().requestPermissionToSendNotifications(
          channelKey: permChannelKey,
          permissions: missingAwn,
        );
      }

      if (openSettingsIfNeeded) {
        final recheck = await checkDetailedPermissions();
        if (recheck['notifications'] != true) {
          await openNotificationSettings();
          return false;
        }
        if (recheck['exact_alarms'] != true) {
          await openExactAlarmSettings();
          return false;
        }
        if (recheck['override_dnd'] != true) {
          await openDndSettings();
          return false;
        }
      }

      final finalStatus = await checkDetailedPermissions();
      return (finalStatus['notifications'] ?? false) &&
          (finalStatus['exact_alarms'] ?? false) &&
          (finalStatus['override_dnd'] ?? false);
    } catch (e) {
      debugPrint('[AdhanAlarmService] checkAndRequestPermissions error: $e');
      return false;
    }
  }

  /// Toggles daily Adhan notifications
  Future<void> setAdhanNotificationsEnabled(bool enabled) async {
    _adhanNotificationsEnabled = enabled;
    try {
      await db.execute('''
        INSERT INTO prayer_settings (id, adhan_notifications_enabled) VALUES ('current', ?)
        ON CONFLICT(id) DO UPDATE SET adhan_notifications_enabled = excluded.adhan_notifications_enabled
      ''', [enabled ? 1 : 0]);

      if (!isSupportedPlatform) return;

      if (!enabled) {
        // Cancel all scheduled adhan notifications & native wakeup alarms
        for (int i = 1; i <= 5; i++) {
          await AwesomeNotifications().cancel(NotificationIds.adhanForOrder(i));
          await cancelNativeAlarm(NotificationIds.adhanNativeAlarmForOrder(i));
        }
        await _syncKeepAliveServiceState();
      } else {
        await checkAndRequestPermissions();
        await _syncKeepAliveServiceState();
        // Reschedule
        final prayers = await PrayerTimeService().calculatePrayersForDate(DateTime.now());
        await scheduleAllPrayers(prayers);
      }
    } catch (e) {
      debugPrint('[AdhanAlarmService] setAdhanNotificationsEnabled error: $e');
    }
  }

  /// Toggles the persistent Fajr Wake-Up Alarm (+1 min after Fajr)
  Future<void> setFajrAlarmEnabled(bool enabled) async {
    _fajrAlarmEnabled = enabled;
    try {
      await db.execute('''
        INSERT INTO prayer_settings (id, fajr_alarm_enabled) VALUES ('current', ?)
        ON CONFLICT(id) DO UPDATE SET fajr_alarm_enabled = excluded.fajr_alarm_enabled
      ''', [enabled ? 1 : 0]);

      if (!isSupportedPlatform) return;

      if (!enabled) {
        await AwesomeNotifications().cancel(NotificationIds.fajrLegacyWakeup);
        await _syncKeepAliveServiceState();
      } else {
        await checkAndRequestPermissions();
        await _syncKeepAliveServiceState();
        final prayers = await PrayerTimeService().calculatePrayersForDate(DateTime.now());
        await scheduleAllPrayers(prayers);
      }
    } catch (e) {
      debugPrint('[AdhanAlarmService] setFajrAlarmEnabled error: $e');
    }
  }

  /// Schedules daily Adhan notifications and the +1 min Fajr Wake-Up Alarm.
  /// Skips today's occurrence if that prayer is already marked done today,
  /// and rolls past/completed slots forward to tomorrow's prayer times.
  Future<void> scheduleAllPrayers(List<PrayerItem> prayers) async {
    if (!isSupportedPlatform) return;
    await _loadAlarmSettingsFromDb();
    final now = DateTime.now();
    await _syncKeepAliveServiceState();

    List<PrayerItem> tomorrowPrayers = const [];
    try {
      tomorrowPrayers = await PrayerTimeService()
          .calculatePrayersForDate(now.add(const Duration(days: 1)));
    } catch (_) {}
    final tomorrowByOrder = {
      for (final tp in tomorrowPrayers) tp.sortOrder: tp,
    };

    // 1. Schedule Adhan notifications (today if undone & upcoming, else tomorrow)
    if (_adhanNotificationsEnabled) {
      for (final prayer in prayers) {
        final doneToday = await isPrayerCompletedToday(prayer.name);
        if (doneToday) {
          final notifId = NotificationIds.adhanForOrder(prayer.sortOrder);
          await AwesomeNotifications().cancel(notifId);
          await AwesomeNotifications().cancelSchedule(notifId);
          await AwesomeNotifications().dismiss(notifId);
          await cancelNativeAlarm(NotificationIds.adhanNativeAlarmForOrder(prayer.sortOrder));

          final tomorrowPrayer = tomorrowByOrder[prayer.sortOrder];
          if (tomorrowPrayer != null) {
            await _scheduleSingleAdhan(tomorrowPrayer);
          }
        } else if (prayer.time.isAfter(now)) {
          await _scheduleSingleAdhan(prayer);
        } else {
          final tomorrowPrayer = tomorrowByOrder[prayer.sortOrder];
          if (tomorrowPrayer != null) {
            await _scheduleSingleAdhan(tomorrowPrayer);
          }
        }
      }
    }

    // 2. Clear any legacy Fajr duplicate +1 min alarms (Fajr adhan itself serves as the un-dismissible waking alarm)
    if (isSupportedPlatform) {
      try {
        await AwesomeNotifications().cancel(NotificationIds.fajrLegacyWakeup);
        await AwesomeNotifications().cancelSchedule(NotificationIds.fajrLegacyWakeup);
        await AwesomeNotifications().dismiss(NotificationIds.fajrLegacyWakeup);
      } catch (_) {}
    }
  }

  /// Schedules a full-screen intent notification for a single prayer time.
  /// The notification uses the alarm audio channel with the selected adhan
  /// sound, `fullScreenIntent: true`, `wakeUpScreen: true`, and
  /// `category: Alarm` so it overrides DND and wakes the device.
  Future<void> _scheduleSingleAdhan(PrayerItem prayer) async {
    final notifId = NotificationIds.adhanForOrder(prayer.sortOrder);

    try {
      await AwesomeNotifications().cancel(notifId);

      final isFajr = prayer.sortOrder == 1;
      final activeSound = AdhanSoundService().currentSound;
      final targetChannel = AdhanNotificationChannels.channelKeyFor(
        soundId: activeSound.id,
        isFajr: isFajr,
      );

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notifId,
          channelKey: targetChannel,
          title: isFajr ? 'Fajr Wake-Up Adhan' : 'Adhan: ${prayer.name}',
          body: isFajr
              ? 'Prayer is better than sleep. Complete the wake-up verification to stop the alarm.'
              : 'It is now time for ${prayer.name} (${prayer.formattedTime}).',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          fullScreenIntent: true,
          autoDismissible: false,
          locked: true,
          payload: {
            'type': isFajr ? 'fajr_alarm' : 'adhan',
            'prayer_id': prayer.id,
            'prayer_name': prayer.name,
            'prayer_name_ar': _prayerNameArabic[prayer.name] ?? prayer.name,
            'prayer_time': prayer.formattedTime,
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: isFajr ? 'WAKE_UP_CHALLENGE' : 'DISMISS_ADHAN',
            label: isFajr ? 'Wake Up Challenge' : 'Dismiss',
            actionType: ActionType.Default,
          ),
          NotificationActionButton(
            key: 'MARK_DONE',
            label: 'Mark as Prayed',
            actionType: ActionType.Default,
          ),
        ],
        schedule: NotificationCalendar(
          year: prayer.time.year,
          month: prayer.time.month,
          day: prayer.time.day,
          hour: prayer.time.hour,
          minute: prayer.time.minute,
          second: 0,
          millisecond: 0,
          repeats: false,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      // Pair with Android native AlarmClock wakeup so background/Doze opens AdhanFullScreenAlarm directly
      await scheduleNativeAlarmForTime(
        requestCode: NotificationIds.adhanNativeAlarmForOrder(prayer.sortOrder),
        triggerTime: prayer.time,
        prayerName: prayer.name,
        prayerId: prayer.id,
        prayerTime: prayer.formattedTime,
      );
    } catch (e) {
      debugPrint('Error scheduling Adhan notification for ${prayer.name}: $e');
    }
  }

  /// Starts Adhan alarm audio playback using the alarm audio stream
  /// so it plays at the alarm volume level, bypassing silent/DND mode.
  Future<void> startAlarmSound() async {
    if (_isAlarmRinging) return;
    _isAlarmRinging = true;

    try {
      _alarmPlayer ??= AudioPlayer();
      // Configure audio context to use the alarm audio stream with transient exclusive focus
      await _alarmPlayer!.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.music,
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
          stayAwake: true,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      ));
      await _alarmPlayer!.setReleaseMode(ReleaseMode.loop);
      // Enforce full alarm-stream player volume alongside loudness-normalized assets
      // so all 5 daily prayer alarms ring at maximum consistent clarity.
      await _alarmPlayer!.setVolume(1.0);
      final source = AdhanSoundService().getActiveAudioSource();
      await _alarmPlayer!.play(source);
      // Guard against race condition if stopAlarmSound was called while play was initializing
      if (!_isAlarmRinging) {
        await _alarmPlayer?.stop();
        return;
      }
      // Dismiss raw OS notification-sound alerts so the looping full-screen alarm doesn't echo
      if (isSupportedPlatform) {
        for (int i = 1; i <= 5; i++) {
          unawaited(AwesomeNotifications().dismiss(NotificationIds.adhanForOrder(i)));
        }
      }
    } catch (e) {
      debugPrint('[AdhanAlarmService] startAlarmSound error: $e');
    }

    _vibrationTimer?.cancel();
    _vibrationTimer = null;
  }

  /// Stops the alarm sound and vibration, and dismisses active notifications
  Future<void> stopAlarmSound() async {
    _isAlarmRinging = false;
    _isModalShowing = false;
    isFullScreenAlarmShowing = false;
    _activeAdhanInfo = null;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    if (_alarmPlayer != null) {
      try {
        await _alarmPlayer?.stop();
      } catch (e) {
        debugPrint('[AdhanAlarmService] stopAlarmSound error: $e');
      }
    }

    try {
      AdhanSoundService().stopPreview();
    } catch (_) {}

    if (!isSupportedPlatform) return;

    try {
      await AwesomeNotifications().cancelSchedule(NotificationIds.fajrLegacyWakeup);
      await AwesomeNotifications().cancel(NotificationIds.fajrLegacyWakeup);
      await AwesomeNotifications().dismiss(NotificationIds.fajrLegacyWakeup);
      for (int i = 1; i <= 5; i++) {
        await AwesomeNotifications().cancel(NotificationIds.adhanForOrder(i));
        await AwesomeNotifications().dismiss(NotificationIds.adhanForOrder(i));
      }
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _platformChannel.invokeMethod<bool>('cancelNativeWakeupNotification');
        await _platformChannel.invokeMethod<bool>('clearAdhanWakeFlags');
      }
    } catch (_) {}
  }

  static final Map<String, DateTime> _recentTriggers = {};

  /// Triggers the full-screen Adhan alarm overlay for any of the 5 prayers.
  /// Shows the prayer name, time, plays the adhan sound, and provides
  /// Dismiss and Mark-as-Prayed buttons.
  ///
  /// If the app was launched cold from a terminated state, this retries
  /// until [rootNavigatorKey] mounts.
  void triggerAdhanFullScreen({
    required String prayerName,
    String? prayerId,
    String? prayerTime,
    BuildContext? context,
  }) {
    final code = canonicalPrayerCode(prayerId ?? prayerName) ?? prayerName.toLowerCase();
    final now = DateTime.now();
    final lastTime = _recentTriggers[code];
    if (lastTime != null && now.difference(lastTime).inSeconds < 12) {
      debugPrint('[AdhanAlarmService] Deduping duplicate adhan trigger for $code within 12s');
      return;
    }
    _recentTriggers[code] = now;
    if (isFullScreenAlarmShowing) return;

    unawaited(_triggerAdhanIfPending(
      prayerName: prayerName,
      prayerId: prayerId,
      prayerTime: prayerTime,
      context: context,
    ));
  }

  Future<void> _triggerAdhanIfPending({
    required String prayerName,
    String? prayerId,
    String? prayerTime,
    BuildContext? context,
  }) async {
    if (isFullScreenAlarmShowing) return;

    final lookup = (prayerId != null && prayerId.isNotEmpty) ? prayerId : prayerName;
    if (await isAdhanHandledOrDismissedToday(lookup) || await isPrayerCompletedToday(lookup)) {
      debugPrint('[AdhanAlarmService] Bypassing adhan: already handled or completed today ($lookup).');
      await stopAlarmSound();
      return;
    }

    // If the scheduled prayer time has already passed and the alarm is not currently ringing, do NOT launch the adhan screen.
    if (!_isAlarmRinging && isAfterAdhanTime(prayerTime: prayerTime, prayerName: prayerName)) {
      debugPrint('[AdhanAlarmService] Bypassing adhan screen because current time is after adhan time ($prayerTime).');
      await stopAlarmSound();
      return;
    }
    if (isFullScreenAlarmShowing) return;

    final nameAr = _prayerNameArabic[prayerName] ?? prayerName;
    final time = prayerTime ?? '';

    _activeAdhanInfo = {
      'prayerName': prayerName,
      'prayerNameAr': nameAr,
      'prayerTime': time,
      'prayerId': prayerId ?? '',
    };

    final targetContext = context ?? rootNavigatorKey.currentContext;
    if (targetContext == null) {
      // App cold-booting: wait for root navigator to mount
      int attempts = 0;
      Timer.periodic(const Duration(milliseconds: 150), (timer) {
        attempts++;
        if (isFullScreenAlarmShowing) {
          timer.cancel();
          return;
        }
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          timer.cancel();
          triggerAdhanFullScreen(
            prayerName: prayerName,
            prayerId: prayerId,
            prayerTime: prayerTime,
            context: ctx,
          );
        } else if (attempts >= 40) {
          timer.cancel();
          debugPrint('[AdhanAlarmService] Navigator key unavailable after 6s');
        }
      });
      return;
    }
    if (!targetContext.mounted) return;

    // Record as triggered today so telemetry is recorded
    await markAdhanTriggeredToday(lookup);
    if (!targetContext.mounted) return;

    AdhanFullScreenAlarm.show(
      targetContext,
      prayerName: prayerName,
      prayerNameAr: nameAr,
      prayerTime: time,
      prayerId: prayerId,
    );
  }

  /// Triggers the Fajr Wake-Up Modal with cognitive challenge
  void triggerFajrWakeUpModal({BuildContext? context}) {
    unawaited(_triggerFajrWakeUpModalIfPending(context: context));
  }

  Future<void> _triggerFajrWakeUpModalIfPending({BuildContext? context}) async {
    if (_isModalShowing) return;
    if (await isAdhanHandledOrDismissedToday('fajr') || await isPrayerCompletedToday('fajr')) {
      debugPrint('[AdhanAlarmService] Bypassing fajr wake-up modal: already handled or completed today.');
      await stopAlarmSound();
      return;
    }
    if (_isModalShowing) return;

    final targetContext = context ?? rootNavigatorKey.currentContext;
    if (targetContext == null) {
      int attempts = 0;
      Timer.periodic(const Duration(milliseconds: 150), (timer) {
        attempts++;
        if (_isModalShowing) {
          timer.cancel();
          return;
        }
        final ctx = rootNavigatorKey.currentContext;
        if (ctx != null) {
          timer.cancel();
          triggerFajrWakeUpModal(context: ctx);
        } else if (attempts >= 30) {
          timer.cancel();
        }
      });
      return;
    }
    if (!targetContext.mounted) return;

    _isModalShowing = true;
    startAlarmSound();

    showDialog(
      context: targetContext,
      barrierDismissible: true,
      builder: (_) => PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            stopAlarmSound();
            markAdhanDismissedToday('fajr');
          }
        },
        child: FajrAlarmDialog(
          onAlarmDismissed: () async {
            await stopAlarmSound();
            await markAdhanDismissedToday('fajr');
            _isModalShowing = false;
            // Mark Fajr prayer as completed in the dedicated prayers table
            await PrayerTimeService().togglePrayer('fajr', true);
          },
        ),
      ),
    ).then((_) {
      _isModalShowing = false;
      stopAlarmSound();
    });
  }

  /// Handles incoming adhan notification tap or action from any prayer
  void handleAdhanAction({
    required String prayerName,
    String? prayerId,
    String? prayerTime,
  }) {
    triggerAdhanFullScreen(
      prayerName: prayerName,
      prayerId: prayerId,
      prayerTime: prayerTime,
    );
  }

  /// Handles incoming alarm notification tap or action (Fajr only)
  void handleFajrAlarmAction() {
    triggerFajrWakeUpModal();
  }
}
