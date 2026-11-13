import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/data/habit_notification_service.dart';
import 'package:axis/data/notification_controller.dart';
import 'package:axis/data/task_repository.dart';

/// Handles platform-specific AwesomeNotifications lifecycle, progress bar notifications,
/// and scheduled completion alarms for focus sessions.
class FocusNotificationManager {
  static final FocusNotificationManager _instance =
      FocusNotificationManager._internal();
  factory FocusNotificationManager() => _instance;
  FocusNotificationManager._internal();

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _notificationsInitialized = false;
  bool get isInitialized => _notificationsInitialized;

  Future<void> initNotifications() async {
    if (!isSupportedPlatform || _notificationsInitialized) return;
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'focus_session_channel',
            channelName: 'Focus Session',
            channelDescription:
                'Active focus countdown with interactive pause/resume actions',
            defaultColor: const Color(0xFF00E5FF),
            importance: NotificationImportance.Low,
            channelShowBadge: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
          ),
          NotificationChannel(
            channelKey: 'focus_completed_channel',
            channelName: 'Focus Completed',
            channelDescription: 'Focus session completion alerts and rewards',
            defaultColor: const Color(0xFF10B981),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
          NotificationChannel(
            channelKey: 'prayer_adhan_channel',
            channelName: 'Prayer Adhan & Times',
            channelDescription:
                'Daily Islamic prayer notifications and Adhan reminder',
            defaultColor: const Color(0xFF38BDF8),
            importance: NotificationImportance.Max,
            channelShowBadge: true,
            playSound: true,
            soundSource: 'resource://raw/res_adhan',
            enableVibration: true,
            criticalAlerts: true,
          ),
          NotificationChannel(
            channelKey: 'fajr_alarm_channel',
            channelName: 'Fajr Wake-Up Alarm',
            channelDescription:
                'High-priority cognitive Fajr wake-up verification alarm',
            defaultColor: const Color(0xFFEF4444),
            importance: NotificationImportance.Max,
            channelShowBadge: true,
            playSound: true,
            soundSource: 'resource://raw/res_adhan',
            enableVibration: true,
            criticalAlerts: true,
          ),
          NotificationChannel(
            channelKey: HabitNotificationService.channelKey,
            channelName: 'Habit Reminders',
            channelDescription:
                'Notifications for upcoming habits (10m and 5m before scheduled time)',
            defaultColor: const Color(0xFF10B981),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
        ],
        debug: false,
      );

      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: NotificationController.onActionReceivedMethod,
        onNotificationCreatedMethod:
            NotificationController.onNotificationCreatedMethod,
        onNotificationDisplayedMethod:
            NotificationController.onNotificationDisplayedMethod,
        onDismissActionReceivedMethod:
            NotificationController.onDismissActionReceivedMethod,
      );

      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize awesome notifications: $e');
    }
  }

  Future<void> showPinnedNotification({
    required int remainingSeconds,
    required int totalSeconds,
    required bool isBreak,
    required bool isRunning,
    required bool isPaused,
    required Task? attachedTask,
    required String selectedSoundscape,
  }) async {
    if (!_notificationsInitialized) return;
    if (!isRunning && !isPaused) return;

    final mins = remainingSeconds ~/ 60;
    final secs = remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final taskTitle = isBreak
        ? 'Reboot Break'
        : (attachedTask?.title ?? 'Deep Focus Cycle');
    final progress = totalSeconds > 0
        ? ((totalSeconds - remainingSeconds) / totalSeconds * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    final String title = isBreak
        ? (isPaused ? 'Break Paused • $timeStr' : 'Reboot Break • $timeStr')
        : (isPaused ? 'Focus Paused • $timeStr' : 'Deep Focus • $timeStr');

    final String body = isBreak
        ? (isPaused
            ? 'Reboot break is paused'
            : 'Rest and recharge your cognitive buffer')
        : (isPaused
            ? '$taskTitle is paused'
            : '$taskTitle ($selectedSoundscape)');

    final Color color = isPaused
        ? const Color(0xFFF59E0B)
        : (isBreak ? const Color(0xFF10B981) : const Color(0xFF00E5FF));

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1001,
          channelKey: 'focus_session_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.ProgressBar,
          progress: progress.toDouble(),
          category: NotificationCategory.Progress,
          color: color,
          locked: true,
          autoDismissible: false,
        ),
        actionButtons: [
          if (isPaused)
            NotificationActionButton(
              key: 'ACTION_RESUME',
              label: 'Resume',
              actionType: ActionType.SilentBackgroundAction,
              autoDismissible: false,
            )
          else
            NotificationActionButton(
              key: 'ACTION_PAUSE',
              label: 'Pause',
              actionType: ActionType.SilentBackgroundAction,
              autoDismissible: false,
            ),
          NotificationActionButton(
            key: 'ACTION_STOP',
            label: 'Stop',
            actionType: ActionType.SilentBackgroundAction,
            autoDismissible: true,
          ),
        ],
      );
    } catch (e) {
      debugPrint('Failed to display awesome notification: $e');
    }
  }

  Future<void> showCompletedNotification({
    required int xp,
    required bool isBreak,
    required Task? attachedTask,
  }) async {
    if (!_notificationsInitialized) return;

    final taskTitle = attachedTask?.title ?? 'Focus Session';

    try {
      await AwesomeNotifications().cancel(1001);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1002,
          channelKey: 'focus_completed_channel',
          title: isBreak ? 'Reboot Break Complete' : 'Focus Session Complete',
          body: isBreak
              ? 'Break cycle finished. Energy restored. Ready for the next sprint!'
              : 'Optimal continuity achieved. You earned +$xp XP for $taskTitle.',
          category: NotificationCategory.Status,
          color: isBreak ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
          autoDismissible: true,
          locked: false,
        ),
      );
    } catch (e) {
      debugPrint('Failed to display completed focus notification: $e');
    }
  }

  Future<void> scheduleCompletionNotification({
    required DateTime endTime,
    required bool isBreak,
    required Task? attachedTask,
  }) async {
    if (!_notificationsInitialized) return;
    final taskTitle =
        isBreak ? 'Reboot Break' : (attachedTask?.title ?? 'Deep Focus Cycle');
    final title =
        isBreak ? 'Reboot Break Complete' : 'Focus Session Complete';
    final body = isBreak
        ? 'Break cycle finished. Energy restored. Return to launch focus!'
        : 'Optimal continuity achieved for $taskTitle. Return to claim your XP.';
    try {
      await AwesomeNotifications().cancel(1002);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1002,
          channelKey: 'focus_completed_channel',
          title: title,
          body: body,
          category: NotificationCategory.Alarm,
          color: isBreak ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
          wakeUpScreen: true,
          autoDismissible: true,
          locked: false,
        ),
        schedule: NotificationCalendar(
          year: endTime.year,
          month: endTime.month,
          day: endTime.day,
          hour: endTime.hour,
          minute: endTime.minute,
          second: endTime.second,
          millisecond: 0,
          repeats: false,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );
    } catch (e) {
      debugPrint(
          '[FocusSessionService] Error scheduling completion notification: $e');
    }
  }

  Future<void> cancelScheduledCompletion() async {
    try {
      await AwesomeNotifications().cancel(1002);
    } catch (_) {}
  }

  Future<void> cancelNotification() async {
    try {
      await AwesomeNotifications().cancel(1001);
      await AwesomeNotifications().cancel(1002);
    } catch (_) {}
  }
}

