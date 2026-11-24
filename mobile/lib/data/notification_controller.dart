import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/powersync_db.dart' show isDatabaseInitialized, currentUserId, openDatabase;
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/ui/prayers/adhan_full_screen_alarm.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_notification_service.dart';

/// Centralized notification action coordinator handling foreground & headless isolate events.
///
/// Routes Adhan prayer notifications to the full-screen alarm overlay,
/// Fajr wake-up notifications to the cognitive challenge dialog,
/// and focus/habit notifications to their respective handlers.
class NotificationController {
  static ReceivePort? _receivePort;

  static void initializeIsolateReceivePort() {
    if (_receivePort != null) return;

    _receivePort = ReceivePort('notification_action_port');
    _receivePort!.listen((data) {
      if (data is Map) {
        final key = data['key'] as String? ?? '';
        final payload = (data['payload'] as Map?)?.cast<String, String?>();
        final channelKey = data['channelKey'] as String?;
        _handleAction(key, payload: payload, channelKey: channelKey);
      } else if (data is String) {
        _handleAction(data);
      }
    });

    IsolateNameServer.removePortNameMapping('notification_action_port');
    IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      'notification_action_port',
    );
  }

  /// Checks if the app was opened cold by a notification tap or full-screen intent.
  static Future<void> checkInitialNotificationAction() async {
    try {
      final initialAction = await AwesomeNotifications().getInitialNotificationAction(
        removeFromActionEvents: true,
      );
      if (initialAction != null) {
        final key = initialAction.buttonKeyPressed;
        final channelKey = initialAction.channelKey;
        final payload = initialAction.payload;

        // If cold opened from an adhan or fajr notification, check if already handled/dismissed today
        final prayerId = payload?['prayer_id'];
        final prayerName = payload?['prayer_name'] ?? '';
        final lookup = (prayerId != null && prayerId.isNotEmpty) ? prayerId : prayerName;
        if (lookup.isNotEmpty &&
            (await AdhanAlarmService().isAdhanHandledOrDismissedToday(lookup) ||
             await AdhanAlarmService().isPrayerCompletedToday(lookup))) {
          debugPrint('[NotificationController] Bypassing cold action: $lookup already handled/dismissed today.');
          await AdhanAlarmService().stopAlarmSound();
          return;
        }

        if (channelKey != null && channelKey.startsWith('fajr_alarm_channel')) {
          if (await AdhanAlarmService().isAdhanHandledOrDismissedToday('fajr') ||
              await AdhanAlarmService().isPrayerCompletedToday('fajr')) {
            debugPrint('[NotificationController] Bypassing cold Fajr alarm: already handled/dismissed today.');
            await AdhanAlarmService().stopAlarmSound();
            return;
          }
        }

        _handleAction(key, payload: payload, channelKey: channelKey);
      }
    } catch (e) {
      debugPrint('[NotificationController] checkInitialNotificationAction notice: $e');
    }
  }

  static void _handleAction(String key, {Map<String, String?>? payload, String? channelKey}) {
    if (key == 'ACTION_PAUSE') {
      FocusSessionService().pauseTimer();
    } else if (key == 'ACTION_RESUME') {
      FocusSessionService().startTimer();
    } else if (key == 'ACTION_STOP') {
      FocusSessionService().resetTimer();
    } else if (key == 'DISMISS_FAJR_ALARM') {
      AdhanAlarmService().dismissAdhan(prayerName: 'Fajr', prayerId: 'fajr');
    } else if (channelKey != null && channelKey.startsWith('fajr_alarm_channel')) {
      unawaited(() async {
        if (await AdhanAlarmService().isAdhanHandledOrDismissedToday('fajr') ||
            await AdhanAlarmService().isPrayerCompletedToday('fajr')) {
          await AdhanAlarmService().stopAlarmSound();
          return;
        }
        AdhanAlarmService().handleFajrAlarmAction();
      }());
    } else if (key == 'DISMISS_ADHAN') {
      final prayerId = payload?['prayer_id'];
      final prayerName = payload?['prayer_name'];
      AdhanAlarmService().dismissAdhan(prayerName: prayerName, prayerId: prayerId);
      AdhanFullScreenAlarm.dismissCurrent();
    } else if (key == 'MARK_DONE') {
      final prayerId = payload?['prayer_id'];
      final prayerName = payload?['prayer_name'];
      AdhanAlarmService().dismissAdhan(prayerName: prayerName, prayerId: prayerId);
      if (prayerId != null) {
        PrayerTimeService().togglePrayer(prayerId, true);
      }
      final habitId = payload?['habit_id'];
      if (habitId != null) {
        HabitRepository().toggleHabit(habitId, true);
        HabitNotificationService().onHabitCompletedToday(habitId);
      }
      AdhanFullScreenAlarm.dismissCurrent();
    } else if (key == 'SHOW_ADHAN' ||
        (channelKey != null && channelKey.startsWith('prayer_adhan_channel'))) {
      // Adhan notification displayed/tapped: verify prayer isn't already handled/marked done today before ringing
      final prayerName = payload?['prayer_name'] ?? 'Fajr';
      final prayerId = payload?['prayer_id'];
      final prayerTime = payload?['prayer_time'] ?? '';
      unawaited(() async {
        final lookup =
            (prayerId != null && prayerId.isNotEmpty) ? prayerId : prayerName;
        if (await AdhanAlarmService().isPrayerCompletedToday(lookup) ||
            await AdhanAlarmService().isAdhanHandledOrDismissedToday(lookup)) {
          await AdhanAlarmService().stopAlarmSound();
          return;
        }
        if (AdhanAlarmService.isAfterAdhanTime(
          prayerTime: prayerTime,
          prayerName: prayerName,
        )) {
          await AdhanAlarmService().stopAlarmSound();
          return;
        }
        await AdhanAlarmService().bringToForegroundForAdhan(
          prayerName: prayerName,
          prayerId: prayerId,
          prayerTime: prayerTime,
        );
        AdhanAlarmService().handleAdhanAction(
          prayerName: prayerName,
          prayerId: prayerId,
          prayerTime: prayerTime,
        );
      }());
    } else if (key == 'OPEN_HABITS' || channelKey == 'habit_reminder_channel') {
      try {
        router.go('/habits');
      } catch (_) {}
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    try {
      await AwesomeNotifications().decrementGlobalBadgeCounter();
    } catch (_) {}

    // Dismiss notification from system tray on action click
    if (receivedAction.id != null) {
      try {
        await AwesomeNotifications().dismiss(receivedAction.id!);
      } catch (_) {}
    }

    final key = receivedAction.buttonKeyPressed;
    final channelKey = receivedAction.channelKey;
    final payload = receivedAction.payload;

    final actionData = {
      'key': key,
      'channelKey': channelKey,
      'payload': payload,
    };

    final sendPort =
        IsolateNameServer.lookupPortByName('notification_action_port');
    if (sendPort != null) {
      sendPort.send(actionData);
    } else {
      // Running in headless background isolate without main thread port
      try {
        if (key == 'DISMISS_FAJR_ALARM' || (channelKey != null && channelKey.startsWith('fajr_alarm_channel'))) {
          await AdhanAlarmService().dismissAdhan(prayerName: 'Fajr', prayerId: 'fajr');
        } else if (key == 'DISMISS_ADHAN') {
          await AdhanAlarmService().dismissAdhan(
            prayerName: payload?['prayer_name'],
            prayerId: payload?['prayer_id'],
          );
        } else if (key == 'MARK_DONE' && payload != null) {
          if (!isDatabaseInitialized) {
            await openDatabase();
          }
          final prayerId = payload['prayer_id'];
          if (prayerId != null) {
            await PrayerTimeService().togglePrayer(prayerId, true);
          }
          final habitId = payload['habit_id'];
          if (habitId != null) {
            await HabitRepository().toggleHabit(habitId, true);
            await HabitNotificationService().onHabitCompletedToday(habitId);
          }
          await AdhanAlarmService().dismissAdhan(
            prayerName: payload['prayer_name'],
            prayerId: payload['prayer_id'],
          );
        }
      } catch (_) {}
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    if (receivedNotification.channelKey != null &&
        receivedNotification.channelKey!.startsWith('fajr_alarm_channel')) {
      final isDone = await AdhanAlarmService().isPrayerCompletedToday('fajr');
      final isHandled = await AdhanAlarmService().isAdhanHandledOrDismissedToday('fajr');
      if (isDone || isHandled) {
        if (receivedNotification.id != null) {
          await AwesomeNotifications().dismiss(receivedNotification.id!);
          await AwesomeNotifications().cancel(receivedNotification.id!);
          await AwesomeNotifications().cancelSchedule(receivedNotification.id!);
        }
        await AdhanAlarmService().stopAlarmSound();
      }
      return;
    }

    // When an Adhan notification is displayed (foreground or background),
    // skip if already marked done or dismissed today; otherwise open AdhanFullScreenAlarm.
    if (receivedNotification.channelKey != null &&
        receivedNotification.channelKey!.startsWith('prayer_adhan_channel')) {
      final payload = receivedNotification.payload;
      final prayerName = payload?['prayer_name'];
      final prayerId = payload?['prayer_id'];
      final prayerTime = payload?['prayer_time'];
      final lookup = (prayerId != null && prayerId.isNotEmpty)
          ? prayerId
          : (prayerName ?? '');
      if (lookup.isNotEmpty &&
          (await AdhanAlarmService().isPrayerCompletedToday(lookup) ||
           await AdhanAlarmService().isAdhanHandledOrDismissedToday(lookup))) {
        if (receivedNotification.id != null) {
          await AwesomeNotifications().dismiss(receivedNotification.id!);
          await AwesomeNotifications().cancel(receivedNotification.id!);
          await AwesomeNotifications().cancelSchedule(receivedNotification.id!);
        }
        await AdhanAlarmService().stopAlarmSound();
        return;
      }
      if (AdhanAlarmService.isAfterAdhanTime(
        prayerTime: prayerTime,
        prayerName: prayerName,
      )) {
        await AdhanAlarmService().stopAlarmSound();
        return;
      }
      if (prayerName != null) {
        final sendPort = IsolateNameServer.lookupPortByName('notification_action_port');
        if (sendPort != null) {
          sendPort.send({
            'key': 'SHOW_ADHAN',
            'channelKey': receivedNotification.channelKey ?? 'prayer_adhan_channel',
            'payload': payload,
          });
        } else {
          AdhanAlarmService().handleAdhanAction(
            prayerName: prayerName,
            prayerId: prayerId,
            prayerTime: prayerTime,
          );
        }
      }
      return;
    }

    if (receivedNotification.channelKey == 'habit_reminder_channel') {
      final notifUserId = receivedNotification.payload?['user_id'];
      final activeUid = currentUserId;
      if (notifUserId != null &&
          notifUserId.isNotEmpty &&
          activeUid.isNotEmpty &&
          activeUid != notifUserId) {
        if (receivedNotification.id != null) {
          await AwesomeNotifications().dismiss(receivedNotification.id!);
          await AwesomeNotifications().cancel(receivedNotification.id!);
          await AwesomeNotifications().cancelSchedule(receivedNotification.id!);
        }
        return;
      }

      final habitId = receivedNotification.payload?['habit_id'];
      if (habitId != null) {
        final isDone =
            await HabitNotificationService().isHabitCompletedToday(habitId);
        if (isDone && receivedNotification.id != null) {
          await AwesomeNotifications().dismiss(receivedNotification.id!);
          await AwesomeNotifications().cancel(receivedNotification.id!);
          await AwesomeNotifications().cancelSchedule(receivedNotification.id!);
          return;
        }
      }

      final isCheckpoint =
          receivedNotification.payload?['is_checkpoint'] == 'true';
      if (isCheckpoint) {
        unawaited(HabitNotificationService().refillQueue());
      }
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    // Decrement badge count when user swipes away a notification
    try {
      await AwesomeNotifications().decrementGlobalBadgeCounter();
    } catch (_) {}

    // Handle swipe dismiss of notification
    final channelKey = receivedAction.channelKey;
    if ((channelKey != null && channelKey.startsWith('prayer_adhan_channel')) ||
        (channelKey != null && channelKey.startsWith('fajr_alarm_channel'))) {
      final payload = receivedAction.payload;
      final prayerId = payload?['prayer_id'];
      final prayerName = payload?['prayer_name'];
      await AdhanAlarmService().dismissAdhan(prayerName: prayerName, prayerId: prayerId);
    }
  }
}
