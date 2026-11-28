import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

/// Canonical Adhan and Fajr alarm notification channel definitions.
///
/// Channel keys use a `_v2` suffix so existing Android installs register
/// updated channels backed by loudness-normalized `res/raw` Adhan audio files
/// instead of inheriting legacy OS-cached channel settings.
class AdhanNotificationChannels {
  const AdhanNotificationChannels._();

  static const String prayerDefault = 'prayer_adhan_channel_v2';
  static const String prayerAlafasy = 'prayer_adhan_channel_alafasy_v2';
  static const String prayerMadinah = 'prayer_adhan_channel_madinah_v2';

  static const String fajrDefault = 'fajr_alarm_channel_v2';
  static const String fajrAlafasy = 'fajr_alarm_channel_alafasy_v2';
  static const String fajrMadinah = 'fajr_alarm_channel_madinah_v2';

  /// Maps the active Adhan [soundId] and [isFajr] flag to the matching
  /// notification channel so all 5 daily prayers share identical audio routing.
  static String channelKeyFor({
    required String soundId,
    required bool isFajr,
  }) {
    switch (soundId.trim().toLowerCase()) {
      case 'alafasy':
        return isFajr ? fajrAlafasy : prayerAlafasy;
      case 'madinah':
        return isFajr ? fajrMadinah : prayerMadinah;
      default:
        return isFajr ? fajrDefault : prayerDefault;
    }
  }

  /// Resolves the prayer channel key used when checking or requesting OS
  /// notification/full-screen/DND permissions.
  static String permissionChannelKeyFor(String soundId) =>
      channelKeyFor(soundId: soundId, isFajr: false);

  static bool isPrayerAdhanChannel(String? key) =>
      key != null && key.startsWith('prayer_adhan_channel');

  static bool isFajrAlarmChannel(String? key) =>
      key != null && key.startsWith('fajr_alarm_channel');

  static bool isAnyAdhanChannel(String? key) =>
      isPrayerAdhanChannel(key) || isFajrAlarmChannel(key);

  /// Builds all Adhan and Fajr notification channels with uniform alarm priority
  /// and normalized `res/raw` sound sources.
  static List<NotificationChannel> buildChannels() {
    return [
      _buildAdhanChannel(
        channelKey: prayerDefault,
        channelName: 'Prayer Adhan & Times',
        channelDescription:
            'Daily Islamic prayer notifications and Adhan reminder',
        defaultColor: const Color(0xFF0EA5E9),
        soundSource: 'resource://raw/res_adhan',
      ),
      _buildAdhanChannel(
        channelKey: prayerAlafasy,
        channelName: 'Prayer Adhan (Sheikh Alafasy)',
        channelDescription:
            'Daily Islamic prayer notifications with Sheikh Mishary Rashid Alafasy Adhan',
        defaultColor: const Color(0xFF0EA5E9),
        soundSource: 'resource://raw/res_adhan_alafasy',
      ),
      _buildAdhanChannel(
        channelKey: prayerMadinah,
        channelName: 'Prayer Adhan (Al-Madinah)',
        channelDescription:
            'Daily Islamic prayer notifications with Al-Madinah Al-Munawwarah Adhan',
        defaultColor: const Color(0xFF0EA5E9),
        soundSource: 'resource://raw/res_adhan_madinah',
      ),
      _buildAdhanChannel(
        channelKey: fajrDefault,
        channelName: 'Fajr Wake-Up Alarm',
        channelDescription:
            'High-priority cognitive Fajr wake-up verification alarm',
        defaultColor: const Color(0xFFEF4444),
        soundSource: 'resource://raw/res_adhan',
      ),
      _buildAdhanChannel(
        channelKey: fajrAlafasy,
        channelName: 'Fajr Wake-Up Alarm (Sheikh Alafasy)',
        channelDescription:
            'High-priority cognitive Fajr wake-up verification alarm with Sheikh Alafasy',
        defaultColor: const Color(0xFFEF4444),
        soundSource: 'resource://raw/res_adhan_alafasy',
      ),
      _buildAdhanChannel(
        channelKey: fajrMadinah,
        channelName: 'Fajr Wake-Up Alarm (Al-Madinah)',
        channelDescription:
            'High-priority cognitive Fajr wake-up verification alarm with Al-Madinah Adhan',
        defaultColor: const Color(0xFFEF4444),
        soundSource: 'resource://raw/res_adhan_madinah',
      ),
    ];
  }

  static NotificationChannel _buildAdhanChannel({
    required String channelKey,
    required String channelName,
    required String channelDescription,
    required Color defaultColor,
    required String soundSource,
  }) {
    return NotificationChannel(
      channelKey: channelKey,
      channelName: channelName,
      channelDescription: channelDescription,
      defaultColor: defaultColor,
      importance: NotificationImportance.Max,
      channelShowBadge: true,
      playSound: true,
      soundSource: soundSource,
      defaultRingtoneType: DefaultRingtoneType.Alarm,
      enableVibration: false,
      onlyAlertOnce: true,
      criticalAlerts: true,
    );
  }
}
