import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:intl/intl.dart';

/// Pre-calculated habit reminder times (10 minutes and 5 minutes before scheduled time)
class HabitReminderTime {
  final int habitMinutes;
  final int tenMinBefore;
  final int fiveMinBefore;
  final int hour10;
  final int minute10;
  final int hour5;
  final int minute5;

  const HabitReminderTime({
    required this.habitMinutes,
    required this.tenMinBefore,
    required this.fiveMinBefore,
    required this.hour10,
    required this.minute10,
    required this.hour5,
    required this.minute5,
  });
}

/// Service managing scheduled pre-habit notifications (10m and 5m before habit time),
/// handling action buttons, cancellation, and tray dismissal upon completion.
class HabitNotificationService {
  static final HabitNotificationService _instance =
      HabitNotificationService._internal();
  factory HabitNotificationService() => _instance;
  HabitNotificationService._internal();

  bool _initialized = false;
  StreamSubscription<List<Habit>>? _habitsSub;

  static const String channelKey = 'habit_reminder_channel';

  /// Calculates the 10-minute and 5-minute pre-habit reminder times.
  /// Returns null if the remindTime string is null, empty, or unparseable.
  static HabitReminderTime? calculateReminderTimes(String? remindTimeStr) {
    if (remindTimeStr == null || remindTimeStr.trim().isEmpty) return null;
    final totalMinutes = HabitRepository.parseTimeToMinutes(remindTimeStr);
    if (totalMinutes >= 24 * 60) return null;

    final target10 = (totalMinutes - 10 + 1440) % 1440;
    final target5 = (totalMinutes - 5 + 1440) % 1440;

    return HabitReminderTime(
      habitMinutes: totalMinutes,
      tenMinBefore: target10,
      fiveMinBefore: target5,
      hour10: target10 ~/ 60,
      minute10: target10 % 60,
      hour5: target5 ~/ 60,
      minute5: target5 % 60,
    );
  }

  /// Generates deterministic unique 32-bit positive integer IDs for Awesome Notifications
  /// for a given habit ID, reminder offset (10 or 5), and optional weekday (0 for daily, 1-7 for Mon-Sun).
  static int generateNotificationId(String habitId, int minutesBefore, [int weekday = 0]) {
    int hash = 0;
    for (int i = 0; i < habitId.length; i++) {
      hash = (31 * hash + habitId.codeUnitAt(i)) & 0x1FFFFFFF;
    }
    final base = minutesBefore == 10 ? 100000000 : 200000000;
    return base + (weekday * 1000000) + (hash % 1000000);
  }

  /// Parses hex color strings safely
  static Color parseHex(String? hex, [Color fallback = const Color(0xFF10B981)]) {
    if (hex == null || hex.isEmpty) return fallback;
    try {
      final clean = hex.replaceAll('#', '').trim();
      if (clean.length == 6) {
        return Color(int.parse('FF$clean', radix: 16));
      } else if (clean.length == 8) {
        return Color(int.parse(clean, radix: 16));
      }
    } catch (_) {}
    return fallback;
  }

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  /// Initializes the service and schedules reminders for all existing habits.
  Future<void> init() async {
    if (!isSupportedPlatform) return;
    if (_initialized) return;
    _initialized = true;

    try {
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      await rescheduleAllHabits();

      // Listen to habit changes from PowerSync or local DB
      _habitsSub?.cancel();
      _habitsSub = HabitRepository().watchHabits().listen(
        (habits) async {
          await syncHabitReminders(habits);
        },
        onError: (e) {
          debugPrint('[HabitNotificationService] Stream error: $e');
        },
      );
    } catch (e) {
      debugPrint('[HabitNotificationService] Error initializing: $e');
    }
  }

  /// Reschedules all habits directly from SQLite
  Future<void> rescheduleAllHabits() async {
    if (!isDatabaseInitialized) return;
    try {
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? "SELECT * FROM habits WHERE (user_id = ? OR user_id IS NULL OR user_id = '') AND (is_enabled != 0 OR is_enabled IS NULL) AND remind_time IS NOT NULL AND remind_time != ''"
          : "SELECT * FROM habits WHERE (is_enabled != 0 OR is_enabled IS NULL) AND remind_time IS NOT NULL AND remind_time != ''";
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rows = await db.getAll(query, params);

      final habits = rows.map((r) => Habit.fromRow(r)).toList();
      for (final habit in habits) {
        if (habit.isEnabled) {
          await scheduleHabitReminders(habit);
        } else {
          await cancelHabitReminders(habit.id);
        }
      }
    } catch (e) {
      debugPrint('[HabitNotificationService] rescheduleAllHabits error: $e');
    }
  }

  /// Syncs scheduled reminders with the current list of habits
  Future<void> syncHabitReminders(List<Habit> habits) async {
    try {
      for (final habit in habits) {
        if (habit.isEnabled && habit.remindTime != null && habit.remindTime!.trim().isNotEmpty) {
          await scheduleHabitReminders(habit);
        } else {
          await cancelHabitReminders(habit.id);
        }
      }
    } catch (e) {
      debugPrint('[HabitNotificationService] syncHabitReminders error: $e');
    }
  }

  /// Schedules both 10-minute and 5-minute pre-habit reminders for a habit.
  Future<void> scheduleHabitReminders(Habit habit) async {
    if (!habit.isEnabled || habit.remindTime == null || habit.remindTime!.trim().isEmpty) {
      await cancelHabitReminders(habit.id);
      return;
    }

    final times = calculateReminderTimes(habit.remindTime);
    if (times == null) return;

    // Clear existing notifications for this habit first
    await cancelHabitReminders(habit.id);

    final habitColor = parseHex(habit.color);
    final scheduleType = habit.scheduleType.toLowerCase().trim();

    try {
      if (scheduleType == 'weekdays') {
        // Monday (1) through Friday (5)
        for (int weekday = DateTime.monday; weekday <= DateTime.friday; weekday++) {
          await _createReminder(
            id: generateNotificationId(habit.id, 10, weekday),
            habit: habit,
            minutesBefore: 10,
            hour: times.hour10,
            minute: times.minute10,
            color: habitColor,
            weekday: weekday,
            repeats: true,
          );

          await _createReminder(
            id: generateNotificationId(habit.id, 5, weekday),
            habit: habit,
            minutesBefore: 5,
            hour: times.hour5,
            minute: times.minute5,
            color: habitColor,
            weekday: weekday,
            repeats: true,
          );
        }
      } else if (scheduleType == 'weekly') {
        // Friday (5)
        await _createReminder(
          id: generateNotificationId(habit.id, 10, DateTime.friday),
          habit: habit,
          minutesBefore: 10,
          hour: times.hour10,
          minute: times.minute10,
          color: habitColor,
          weekday: DateTime.friday,
          repeats: true,
        );

        await _createReminder(
          id: generateNotificationId(habit.id, 5, DateTime.friday),
          habit: habit,
          minutesBefore: 5,
          hour: times.hour5,
          minute: times.minute5,
          color: habitColor,
          weekday: DateTime.friday,
          repeats: true,
        );
      } else if (scheduleType == 'every_3_days' || scheduleType == '3days') {
        // Schedule next 30 days of 3-day cycle occurrences
        final now = DateTime.now();
        DateTime createdDate;
        try {
          final dt = DateTime.parse(habit.createdAt ?? '').toLocal();
          createdDate = DateTime(dt.year, dt.month, dt.day);
        } catch (_) {
          createdDate = DateTime(now.year, now.month, now.day);
        }

        for (int d = 0; d < 30; d++) {
          final targetDate =
              DateTime(now.year, now.month, now.day).add(Duration(days: d));
          final daysDiff = targetDate.difference(createdDate).inDays;
          if (daysDiff >= 0 && daysDiff % 3 == 0) {
            // Check if reminder times are in future
            final dt10 = DateTime(targetDate.year, targetDate.month,
                targetDate.day, times.hour10, times.minute10);
            if (dt10.isAfter(now)) {
              await _createDateSpecificReminder(
                id: generateNotificationId(habit.id, 10, (d % 7) + 1),
                habit: habit,
                minutesBefore: 10,
                scheduledDate: dt10,
                color: habitColor,
              );
            }
            final dt5 = DateTime(targetDate.year, targetDate.month,
                targetDate.day, times.hour5, times.minute5);
            if (dt5.isAfter(now)) {
              await _createDateSpecificReminder(
                id: generateNotificationId(habit.id, 5, (d % 7) + 1),
                habit: habit,
                minutesBefore: 5,
                scheduledDate: dt5,
                color: habitColor,
              );
            }
          }
        }
      } else {
        // Daily (default) — repeats daily at hour & minute
        await _createReminder(
          id: generateNotificationId(habit.id, 10, 0),
          habit: habit,
          minutesBefore: 10,
          hour: times.hour10,
          minute: times.minute10,
          color: habitColor,
          weekday: null,
          repeats: true,
        );

        await _createReminder(
          id: generateNotificationId(habit.id, 5, 0),
          habit: habit,
          minutesBefore: 5,
          hour: times.hour5,
          minute: times.minute5,
          color: habitColor,
          weekday: null,
          repeats: true,
        );
      }
    } catch (e) {
      debugPrint(
          '[HabitNotificationService] Error scheduling habit reminders for ${habit.name}: $e');
    }
  }

  /// Helper to create repeating or weekday reminder
  Future<void> _createReminder({
    required int id,
    required Habit habit,
    required int minutesBefore,
    required int hour,
    required int minute,
    required Color color,
    int? weekday,
    required bool repeats,
  }) async {
    final title = minutesBefore == 10
        ? 'Reminder: ${habit.name} in 10 minutes'
        : 'Starting soon: ${habit.name} in 5 minutes';

    final body = minutesBefore == 10
        ? '"${habit.name}" is scheduled for ${habit.remindTime}. Get ready to start and earn +${habit.targetValue} XP!'
        : 'Almost time for "${habit.name}" (${habit.remindTime}). Start preparing now!';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        color: color,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        payload: {
          'type': 'habit_reminder',
          'habit_id': habit.id,
          'habit_name': habit.name,
          'minutes_before': '$minutesBefore',
          'remind_time': habit.remindTime ?? '',
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'MARK_DONE',
          label: 'Mark as Completed',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'OPEN_HABITS',
          label: 'Open Axis',
          actionType: ActionType.Default,
        ),
      ],
      schedule: NotificationCalendar(
        weekday: weekday,
        hour: hour,
        minute: minute,
        second: 0,
        millisecond: 0,
        repeats: repeats,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  /// Helper to create specific date reminder (e.g. for every 3 days)
  Future<void> _createDateSpecificReminder({
    required int id,
    required Habit habit,
    required int minutesBefore,
    required DateTime scheduledDate,
    required Color color,
  }) async {
    final title = minutesBefore == 10
        ? 'Reminder: ${habit.name} in 10 minutes'
        : 'Starting soon: ${habit.name} in 5 minutes';

    final body = minutesBefore == 10
        ? '"${habit.name}" is scheduled for ${habit.remindTime}. Get ready to start and earn +${habit.targetValue} XP!'
        : 'Almost time for "${habit.name}" (${habit.remindTime}). Start preparing now!';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: channelKey,
        title: title,
        body: body,
        color: color,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        payload: {
          'type': 'habit_reminder',
          'habit_id': habit.id,
          'habit_name': habit.name,
          'minutes_before': '$minutesBefore',
          'remind_time': habit.remindTime ?? '',
        },
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'MARK_DONE',
          label: 'Mark as Completed',
          actionType: ActionType.Default,
        ),
        NotificationActionButton(
          key: 'OPEN_HABITS',
          label: 'Open Axis',
          actionType: ActionType.Default,
        ),
      ],
      schedule: NotificationCalendar(
        year: scheduledDate.year,
        month: scheduledDate.month,
        day: scheduledDate.day,
        hour: scheduledDate.hour,
        minute: scheduledDate.minute,
        second: 0,
        millisecond: 0,
        repeats: false,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  /// Cancels all scheduled reminder notifications for a specific habit ID.
  Future<void> cancelHabitReminders(String habitId) async {
    try {
      // Daily (weekday 0)
      await AwesomeNotifications()
          .cancel(generateNotificationId(habitId, 10, 0));
      await AwesomeNotifications()
          .cancel(generateNotificationId(habitId, 5, 0));

      // Weekdays / multi-day
      for (int w = 1; w <= 7; w++) {
        await AwesomeNotifications()
            .cancel(generateNotificationId(habitId, 10, w));
        await AwesomeNotifications()
            .cancel(generateNotificationId(habitId, 5, w));
      }
    } catch (e) {
      debugPrint(
          '[HabitNotificationService] Error cancelling reminders for $habitId: $e');
    }
  }

  /// Dismisses delivered reminder notifications from the system status tray
  /// when a habit is completed today.
  Future<void> onHabitCompletedToday(String habitId) async {
    try {
      // Dismiss daily
      await AwesomeNotifications()
          .dismiss(generateNotificationId(habitId, 10, 0));
      await AwesomeNotifications()
          .dismiss(generateNotificationId(habitId, 5, 0));

      final todayWeekday = DateTime.now().weekday;
      await AwesomeNotifications()
          .dismiss(generateNotificationId(habitId, 10, todayWeekday));
      await AwesomeNotifications()
          .dismiss(generateNotificationId(habitId, 5, todayWeekday));
    } catch (e) {
      debugPrint(
          '[HabitNotificationService] Error dismissing completed habit notifications: $e');
    }
  }

  /// Checks if a habit has already been completed today in SQLite
  Future<bool> isHabitCompletedToday(String habitId) async {
    if (!isDatabaseInitialized) return false;
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? 'SELECT id FROM habit_logs WHERE habit_id = ? AND log_date = ? AND status = ? AND (user_id = ? OR user_id IS NULL OR user_id = \'\') LIMIT 1'
          : 'SELECT id FROM habit_logs WHERE habit_id = ? AND log_date = ? AND status = ? LIMIT 1';
      final params = uid.isNotEmpty
          ? [habitId, todayStr, 'done', uid]
          : [habitId, todayStr, 'done'];
      final res = await db.getOptional(query, params);
      return res != null;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _habitsSub?.cancel();
  }
}
