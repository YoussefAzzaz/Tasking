import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/powersync_db.dart' show isDatabaseInitialized, currentUserId;
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
      AdhanAlarmService().stopAlarmSound();
    } else if (channelKey == 'fajr_alarm_channel') {
      AdhanAlarmService().handleFajrAlarmAction();
    } else if (key == 'DISMISS_ADHAN') {
      AdhanFullScreenAlarm.dismissCurrent();
    } else if (key == 'MARK_DONE') {
      final prayerId = payload?['prayer_id'];
      if (prayerId != null) {
        PrayerTimeService().togglePrayer(prayerId, true);
      }
      final habitId = payload?['habit_id'];
      if (habitId != null) {
        HabitRepository().toggleHabit(habitId, true);
        HabitNotificationService().onHabitCompletedToday(habitId);
      }
      AdhanFullScreenAlarm.dismissCurrent();
    } else if (key == 'SHOW_ADHAN' || channelKey == 'prayer_adhan_channel') {
      // Adhan notification displayed/tapped: verify prayer isn't already marked done today before ringing
      final prayerName = payload?['prayer_name'] ?? 'Fajr';
      final prayerId = payload?['prayer_id'];
      final prayerTime = payload?['prayer_time'] ?? '';
      unawaited(() async {
        final lookup =
            (prayerId != null && prayerId.isNotEmpty) ? prayerId : prayerName;
        if (await AdhanAlarmService().isPrayerCompletedToday(lookup)) {
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
        if (key == 'DISMISS_FAJR_ALARM' || channelKey == 'fajr_alarm_channel') {
          await AdhanAlarmService().stopAlarmSound();
        } else if (key == 'DISMISS_ADHAN') {
          await AdhanAlarmService().stopAlarmSound();
        } else if (key == 'MARK_DONE' && payload != null) {
          if (isDatabaseInitialized) {
            final prayerId = payload['prayer_id'];
            if (prayerId != null) {
              await PrayerTimeService().togglePrayer(prayerId, true);
            }
            final habitId = payload['habit_id'];
            if (habitId != null) {
              await HabitRepository().toggleHabit(habitId, true);
              await HabitNotificationService().onHabitCompletedToday(habitId);
            }
          }
          await AdhanAlarmService().stopAlarmSound();
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
    if (receivedNotification.channelKey == 'fajr_alarm_channel') {
      final isDone = await AdhanAlarmService().isPrayerCompletedToday('fajr');
      if (isDone) {
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
    // skip if already marked done today; otherwise open AdhanFullScreenAlarm.
    if (receivedNotification.channelKey == 'prayer_adhan_channel') {
      final payload = receivedNotification.payload;
      final prayerName = payload?['prayer_name'];
      final prayerId = payload?['prayer_id'];
      final prayerTime = payload?['prayer_time'];
      final lookup = (prayerId != null && prayerId.isNotEmpty)
          ? prayerId
          : (prayerName ?? '');
      if (lookup.isNotEmpty &&
          await AdhanAlarmService().isPrayerCompletedToday(lookup)) {
        if (receivedNotification.id != null) {
          await AwesomeNotifications().dismiss(receivedNotification.id!);
          await AwesomeNotifications().cancel(receivedNotification.id!);
          await AwesomeNotifications().cancelSchedule(receivedNotification.id!);
        }
        await AdhanAlarmService().stopAlarmSound();
        return;
      }
      if (prayerName != null) {
        final sendPort = IsolateNameServer.lookupPortByName('notification_action_port');
        if (sendPort != null) {
          sendPort.send({
            'key': 'SHOW_ADHAN',
            'channelKey': 'prayer_adhan_channel',
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
    // Handle swipe dismiss of notification
    final channelKey = receivedAction.channelKey;
    if (channelKey == 'prayer_adhan_channel' || channelKey == 'fajr_alarm_channel') {
      await AdhanAlarmService().stopAlarmSound();
    }
  }
}
