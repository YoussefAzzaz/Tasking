import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/habits/widgets/fajr_alarm_dialog.dart';

/// Centralized service managing prayer Adhan notifications,
/// scheduling, and the persistent cognitive Fajr Wake-Up Alarm.
class AdhanAlarmService {
  static final AdhanAlarmService _instance = AdhanAlarmService._();
  factory AdhanAlarmService() => _instance;
  AdhanAlarmService._();

  bool _adhanNotificationsEnabled = true;
  bool _fajrAlarmEnabled = true;
  AudioPlayer? _alarmPlayer;
  Timer? _vibrationTimer;
  bool _isAlarmRinging = false;
  bool _isModalShowing = false;

  bool get adhanNotificationsEnabled => _adhanNotificationsEnabled;
  bool get fajrAlarmEnabled => _fajrAlarmEnabled;
  bool get isAlarmRinging => _isAlarmRinging;

  /// Initializes alarm preferences from SQLite
  Future<void> init() async {
    try {
      // Ensure prayer_settings table exists
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

      // Ensure preference columns exist for older existing tables
      try {
        await db.execute('''
          ALTER TABLE prayer_settings ADD COLUMN adhan_notifications_enabled INTEGER DEFAULT 1
        ''');
      } catch (_) {}

      try {
        await db.execute('''
          ALTER TABLE prayer_settings ADD COLUMN fajr_alarm_enabled INTEGER DEFAULT 1
        ''');
      } catch (_) {}

      final rows = await db.getAll('SELECT * FROM prayer_settings WHERE id = ?', ['current']);
      if (rows.isNotEmpty) {
        final row = rows.first;
        final adhanVal = row['adhan_notifications_enabled'] as num?;
        final fajrVal = row['fajr_alarm_enabled'] as num?;
        if (adhanVal != null) _adhanNotificationsEnabled = adhanVal.toInt() == 1;
        if (fajrVal != null) _fajrAlarmEnabled = fajrVal.toInt() == 1;
      }
    } catch (e) {
      debugPrint('Error initializing AdhanAlarmService: $e');
    }
  }

  /// Toggles daily Adhan notifications
  Future<void> setAdhanNotificationsEnabled(bool enabled) async {
    _adhanNotificationsEnabled = enabled;
    try {
      await db.execute('''
        UPDATE prayer_settings SET adhan_notifications_enabled = ? WHERE id = 'current'
      ''', [enabled ? 1 : 0]);

      if (!enabled) {
        // Cancel all scheduled adhan notifications
        for (int i = 1; i <= 5; i++) {
          await AwesomeNotifications().cancel(1000 + i);
        }
      } else {
        // Reschedule
        final prayers = await PrayerTimeService().calculatePrayersForDate(DateTime.now());
        await scheduleAllPrayers(prayers);
      }
    } catch (_) {}
  }

  /// Toggles the persistent Fajr Wake-Up Alarm (+1 min after Fajr)
  Future<void> setFajrAlarmEnabled(bool enabled) async {
    _fajrAlarmEnabled = enabled;
    try {
      await db.execute('''
        UPDATE prayer_settings SET fajr_alarm_enabled = ? WHERE id = 'current'
      ''', [enabled ? 1 : 0]);

      if (!enabled) {
        await AwesomeNotifications().cancel(9991);
      } else {
        final prayers = await PrayerTimeService().calculatePrayersForDate(DateTime.now());
        await scheduleAllPrayers(prayers);
      }
    } catch (_) {}
  }

  /// Schedules daily Adhan notifications and the +1 min Fajr Wake-Up Alarm
  Future<void> scheduleAllPrayers(List<PrayerItem> prayers) async {
    final now = DateTime.now();

    // 1. Schedule Adhan notifications for today's prayers
    if (_adhanNotificationsEnabled) {
      for (final prayer in prayers) {
        if (prayer.time.isAfter(now)) {
          await _scheduleSingleAdhan(prayer);
        }
      }
    }

    // 2. Schedule persistent Fajr Wake-Up Alarm (+1 minute after Fajr)
    if (_fajrAlarmEnabled) {
      final fajr = prayers.firstWhere(
        (p) => p.sortOrder == 1,
        orElse: () => prayers.first,
      );
      final fajrAlarmTime = fajr.time.add(const Duration(minutes: 1));
      if (fajrAlarmTime.isAfter(now)) {
        await _scheduleFajrWakeUpAlarm(fajrAlarmTime, fajr.formattedTime);
      }
    }
  }

  /// Schedules notification for a single prayer time
  Future<void> _scheduleSingleAdhan(PrayerItem prayer) async {
    final notifId = 1000 + prayer.sortOrder;

    try {
      await AwesomeNotifications().cancel(notifId);

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notifId,
          channelKey: 'prayer_adhan_channel',
          title: 'Adhan: ${prayer.name}',
          body: 'It is now time for ${prayer.name} (${prayer.formattedTime}).',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          payload: {
            'type': 'adhan',
            'prayer_id': prayer.id,
            'prayer_name': prayer.name,
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'MARK_DONE',
            label: 'Mark as Completed',
            actionType: ActionType.Default,
          ),
          NotificationActionButton(
            key: 'OPEN_QIBLA',
            label: 'Qibla Direction',
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
    } catch (e) {
      debugPrint('Error scheduling Adhan notification for ${prayer.name}: $e');
    }
  }

  /// Schedules the persistent Fajr Wake-Up Alarm exactly 1 min after Fajr Adhan
  Future<void> _scheduleFajrWakeUpAlarm(DateTime alarmTime, String adhanTimeStr) async {
    const notifId = 9991;

    try {
      await AwesomeNotifications().cancel(notifId);

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notifId,
          channelKey: 'fajr_alarm_channel',
          title: 'Fajr Wake-Up Alarm',
          body: 'Prayer is better than sleep. Complete the wake-up verification to stop the alarm.',
          notificationLayout: NotificationLayout.BigText,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          fullScreenIntent: true,
          autoDismissible: false,
          locked: true,
          payload: {
            'type': 'fajr_alarm',
            'adhan_time': adhanTimeStr,
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'DISMISS_FAJR_ALARM',
            label: 'Wake Up & Stop Alarm',
            actionType: ActionType.Default,
          ),
        ],
        schedule: NotificationCalendar(
          year: alarmTime.year,
          month: alarmTime.month,
          day: alarmTime.day,
          hour: alarmTime.hour,
          minute: alarmTime.minute,
          second: 0,
          millisecond: 0,
          repeats: false,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );
    } catch (e) {
      debugPrint('Error scheduling Fajr alarm: $e');
    }
  }

  /// Generates a synthesized high-frequency alarm beeping WAV buffer
  Future<File> _getOrGenerateAlarmWav() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/fajr_alarm_beep.wav');
    if (await file.exists() && (await file.length()) > 500) {
      return file;
    }

    const sampleRate = 22050;
    const durationSeconds = 2;
    const totalSamples = sampleRate * durationSeconds;
    final samples = Int16List(totalSamples);

    // Beeping pattern: 250ms tone at 880Hz, 100ms pause, 250ms tone at 1200Hz, 400ms pause
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final cycle = t % 1.0;
      double tone = 0.0;

      if (cycle < 0.25) {
        tone = sin(2 * pi * 880 * t);
      } else if (cycle >= 0.35 && cycle < 0.60) {
        tone = sin(2 * pi * 1200 * t);
      }

      final val = (tone * 0.75 * 32767).toInt();
      samples[i] = val.clamp(-32768, 32767);
    }

    final byteData = ByteData(44 + totalSamples * 2);
    void writeString(int offset, String str) {
      for (int i = 0; i < str.length; i++) {
        byteData.setUint8(offset + i, str.codeUnitAt(i));
      }
    }

    writeString(0, 'RIFF');
    byteData.setUint32(4, 36 + totalSamples * 2, Endian.little);
    writeString(8, 'WAVE');
    writeString(12, 'fmt ');
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, 1, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, sampleRate * 2, Endian.little);
    byteData.setUint16(32, 2, Endian.little);
    byteData.setUint16(34, 16, Endian.little);
    writeString(36, 'data');
    byteData.setUint32(40, totalSamples * 2, Endian.little);

    for (int i = 0; i < totalSamples; i++) {
      byteData.setInt16(44 + i * 2, samples[i], Endian.little);
    }

    await file.writeAsBytes(byteData.buffer.asUint8List());
    return file;
  }

  /// Starts continuous alarm sound and vibration
  Future<void> startAlarmSound() async {
    if (_isAlarmRinging) return;
    _isAlarmRinging = true;

    try {
      final wavFile = await _getOrGenerateAlarmWav();
      _alarmPlayer ??= AudioPlayer();
      await _alarmPlayer!.setReleaseMode(ReleaseMode.loop);
      await _alarmPlayer!.play(DeviceFileSource(wavFile.path));
    } catch (_) {}

    _vibrationTimer?.cancel();
    _vibrationTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      HapticFeedback.heavyImpact();
    });
  }

  /// Stops the alarm sound and vibration
  Future<void> stopAlarmSound() async {
    _isAlarmRinging = false;
    _vibrationTimer?.cancel();
    _vibrationTimer = null;

    try {
      await _alarmPlayer?.stop();
    } catch (_) {}

    await AwesomeNotifications().cancel(9991);
  }

  /// Triggers the non-dismissible Fajr Wake-Up Modal with cognitive challenge
  void triggerFajrWakeUpModal({BuildContext? context}) {
    if (_isModalShowing) return;
    _isModalShowing = true;

    startAlarmSound();

    final targetContext = context ?? rootNavigatorKey.currentContext;
    if (targetContext != null) {
      showDialog(
        context: targetContext,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: FajrAlarmDialog(
            onAlarmDismissed: () async {
              await stopAlarmSound();
              _isModalShowing = false;
              // Mark Fajr habit as done
              await HabitRepository().toggleHabit('habit_prayer_fajr', true);
            },
          ),
        ),
      ).then((_) {
        _isModalShowing = false;
        stopAlarmSound();
      });
    }
  }

  /// Handles incoming alarm notification tap or action
  void handleFajrAlarmAction() {
    triggerFajrWakeUpModal();
  }
}
