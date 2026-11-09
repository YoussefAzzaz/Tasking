import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/powersync_db.dart' show isDatabaseInitialized, currentUserId;
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_notification_service.dart';

/// Centralized notification action coordinator handling foreground & headless isolate events.
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

  static void _handleAction(String key, {Map<String, String?>? payload, String? channelKey}) {
    if (key == 'ACTION_PAUSE') {
      FocusSessionService().pauseTimer();
    } else if (key == 'ACTION_RESUME') {
      FocusSessionService().startTimer();
    } else if (key == 'ACTION_STOP') {
      FocusSessionService().resetTimer();
    } else if (key == 'DISMISS_FAJR_ALARM' || channelKey == 'fajr_alarm_channel') {
      AdhanAlarmService().handleFajrAlarmAction();
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
          AdhanAlarmService().stopAlarmSound();
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
    if (receivedNotification.channelKey == 'habit_reminder_channel') {
      final notifUserId = receivedNotification.payload?['user_id'];
      final activeUid = currentUserId;
      // If notification belongs to a different user, dismiss and cancel schedule immediately
      if (notifUserId != null &&
          notifUserId.isNotEmpty &&
          activeUid.isNotEmpty &&
          activeUid != notifUserId) {
        if (receivedNotification.id != null) {
          await AwesomeNotifications().dismiss(receivedNotification.id!);
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
          await AwesomeNotifications().cancelSchedule(receivedNotification.id!);
          return;
        }
      }

      // Daisy-chain checkpoint refill: if this queued occurrence was flagged as a checkpoint
      // (every 10th item or queue tail), trigger background refill to replenish the sliding window.
      final isCheckpoint =
          receivedNotification.payload?['is_checkpoint'] == 'true';
      if (isCheckpoint) {
        unawaited(HabitNotificationService().refillQueue());
      }
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {}
}
