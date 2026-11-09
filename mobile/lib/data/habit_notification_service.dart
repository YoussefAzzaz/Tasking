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

/// Represents a single chronological occurrence slot in the rolling notification queue.
class HabitOccurrence {
  final int id;
  final Habit habit;
  final DateTime triggerTime;
  final int minutesBefore;
  final int dateKey;
  final bool isFollowUp;
  final bool isCheckpoint;

  const HabitOccurrence({
    required this.id,
    required this.habit,
    required this.triggerTime,
    required this.minutesBefore,
    required this.dateKey,
    required this.isFollowUp,
    this.isCheckpoint = false,
  });

  HabitOccurrence copyWith({
    int? id,
    Habit? habit,
    DateTime? triggerTime,
    int? minutesBefore,
    int? dateKey,
    bool? isFollowUp,
    bool? isCheckpoint,
  }) {
    return HabitOccurrence(
      id: id ?? this.id,
      habit: habit ?? this.habit,
      triggerTime: triggerTime ?? this.triggerTime,
      minutesBefore: minutesBefore ?? this.minutesBefore,
      dateKey: dateKey ?? this.dateKey,
      isFollowUp: isFollowUp ?? this.isFollowUp,
      isCheckpoint: isCheckpoint ?? this.isCheckpoint,
    );
  }

  /// Fingerprint hashing config and trigger time to skip redundant platform calls.
  String get fingerprint =>
      '${habit.id}_${habit.name}_${habit.remindTime}_${habit.scheduleType}_${habit.isEnabled}_${habit.color}_${triggerTime.millisecondsSinceEpoch}_$isCheckpoint';
}

/// Service managing scheduled pre-habit notifications (10m and 5m before habit time),
/// implementing a Sliding Window "Next-N" Queue combined with a Daisy-Chain Checkpoint pattern.
class HabitNotificationService {
  static final HabitNotificationService _instance =
      HabitNotificationService._internal();
  factory HabitNotificationService() => _instance;
  HabitNotificationService._internal();

  /// Maximum size of the rolling upcoming notification queue registered with the platform
  static const int maxQueueSize = 40;
  static const String channelKey = 'habit_reminder_channel';

  bool _initialized = false;
  StreamSubscription<List<Habit>>? _habitsSub;
  final Map<int, String> _scheduledFingerprints = {};
  final Map<int, String> _slotHabitIds = {};
  bool _isSyncing = false;
  bool _needsResync = false;

  @visibleForTesting
  Map<int, String> get scheduledFingerprints =>
      Map.unmodifiable(_scheduledFingerprints);

  @visibleForTesting
  Map<int, String> get slotHabitIds => Map.unmodifiable(_slotHabitIds);

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

  /// Formats a DateTime into a YYYYMMDD integer date key (e.g. 20261109).
  static int toDateKey(DateTime dt) {
    return dt.year * 10000 + dt.month * 100 + dt.day;
  }

  /// Generates collision-safe 32-bit positive integer IDs based on habitId, dateKey (YYYYMMDD),
  /// and isFollowUp flag (false for 10m reminder, true for 5m reminder).
  static int generateOccurrenceId({
    required String habitId,
    required int dateKey,
    required bool isFollowUp,
  }) {
    int hash = 0;
    for (int i = 0; i < habitId.length; i++) {
      hash = (31 * hash + habitId.codeUnitAt(i)) & 0x7FFFFFFF;
    }
    final base = isFollowUp ? 200000000 : 100000000;
    final dateComponent = (dateKey % 10000) * 65536;
    final habitComponent = hash % 65536;
    return base + dateComponent + habitComponent;
  }

  /// Legacy ID generator kept for backwards-compatibility with existing tests and callers.
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

      // Listen to habit changes from PowerSync or local DB.
      // watchHabits() immediately emits the initial list of habits from SQLite,
      // avoiding duplicate scheduling passes on startup.
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

  /// Determines if a habit is scheduled to run on a given date
  static bool isHabitScheduledForDate(
    Habit habit,
    DateTime date,
    DateTime createdDate,
  ) {
    final scheduleType = habit.scheduleType.toLowerCase().trim();
    if (scheduleType == 'weekdays') {
      return date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
    } else if (scheduleType == 'weekly') {
      return date.weekday == DateTime.friday;
    } else if (scheduleType == 'every_3_days' || scheduleType == '3days') {
      final daysDiff = date.difference(createdDate).inDays;
      return daysDiff >= 0 && (daysDiff % 3 == 0);
    }
    return true; // daily (default)
  }

  /// Builds a chronological list of upcoming reminder occurrences across all habits,
  /// up to [limit] (default: [maxQueueSize] = 40).
  /// Every 10th item (and the last item) is flagged as a checkpoint for daisy-chain refills.
  Future<List<HabitOccurrence>> buildUpcomingOccurrences(
    List<Habit> habits, {
    int limit = maxQueueSize,
    DateTime? fromTime,
    Future<bool> Function(String habitId)? isCompletedToday,
  }) async {
    final now = fromTime ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final candidates = <HabitOccurrence>[];
    final completedCache = <String, bool>{};

    final activeHabits = habits.where((h) {
      if (!h.isEnabled) return false;
      final rt = h.remindTime;
      return rt != null && rt.trim().isNotEmpty;
    }).toList();

    if (activeHabits.isEmpty || limit <= 0) {
      return const [];
    }

    final habitTimes = <String, HabitReminderTime>{};
    final habitCreatedDates = <String, DateTime>{};

    for (final habit in activeHabits) {
      final times = calculateReminderTimes(habit.remindTime);
      if (times != null) {
        habitTimes[habit.id] = times;
      }
      try {
        final dt = DateTime.parse(habit.createdAt ?? '').toLocal();
        habitCreatedDates[habit.id] = DateTime(dt.year, dt.month, dt.day);
      } catch (_) {
        habitCreatedDates[habit.id] = today;
      }
    }

    for (int d = 0; d < 90; d++) {
      final targetDate = today.add(Duration(days: d));
      final isToday = (d == 0);

      for (final habit in activeHabits) {
        final times = habitTimes[habit.id];
        if (times == null) continue;

        if (!isHabitScheduledForDate(
          habit,
          targetDate,
          habitCreatedDates[habit.id] ?? today,
        )) {
          continue;
        }

        if (isToday) {
          bool isDone = completedCache[habit.id] ?? false;
          if (!completedCache.containsKey(habit.id)) {
            isDone = isCompletedToday != null
                ? await isCompletedToday(habit.id)
                : await isHabitCompletedToday(habit.id);
            completedCache[habit.id] = isDone;
          }
          if (isDone) continue;
        }

        final habitTargetDateTime = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        ).add(Duration(minutes: times.habitMinutes));

        final dt10 = habitTargetDateTime.subtract(const Duration(minutes: 10));
        final dt5 = habitTargetDateTime.subtract(const Duration(minutes: 5));
        final dateKey = toDateKey(targetDate);

        if (dt10.isAfter(now)) {
          candidates.add(HabitOccurrence(
            id: generateOccurrenceId(
              habitId: habit.id,
              dateKey: dateKey,
              isFollowUp: false,
            ),
            habit: habit,
            triggerTime: dt10,
            minutesBefore: 10,
            dateKey: dateKey,
            isFollowUp: false,
          ));
        }

        if (dt5.isAfter(now)) {
          candidates.add(HabitOccurrence(
            id: generateOccurrenceId(
              habitId: habit.id,
              dateKey: dateKey,
              isFollowUp: true,
            ),
            habit: habit,
            triggerTime: dt5,
            minutesBefore: 5,
            dateKey: dateKey,
            isFollowUp: true,
          ));
        }
      }

      if (candidates.length >= limit) {
        break;
      }
    }

    candidates.sort((a, b) {
      final comp = a.triggerTime.compareTo(b.triggerTime);
      if (comp != 0) return comp;
      return a.id.compareTo(b.id);
    });

    final selected = candidates.take(limit).toList();

    for (int i = 0; i < selected.length; i++) {
      final isCheckpoint = ((i + 1) % 10 == 0) || (i == selected.length - 1);
      if (isCheckpoint) {
        selected[i] = selected[i].copyWith(isCheckpoint: true);
      }
    }

    return selected;
  }

  /// Syncs scheduled reminders with the rolling "Next-N" queue.
  /// Skips unchanged slots using the [_scheduledFingerprints] cache and cancels dropped slots.
  Future<void> syncHabitReminders(List<Habit> habits) async {
    try {
      final upcomingOccurrences = await buildUpcomingOccurrences(
        habits,
        limit: maxQueueSize,
      );

      final newIds = upcomingOccurrences.map((o) => o.id).toSet();

      // Cancel obsolete slots that dropped out of the rolling window
      final obsoleteIds = _scheduledFingerprints.keys
          .where((id) => !newIds.contains(id))
          .toList();

      for (final oldId in obsoleteIds) {
        await AwesomeNotifications().cancel(oldId);
        _scheduledFingerprints.remove(oldId);
        _slotHabitIds.remove(oldId);
      }

      // Schedule or retain slots
      for (final slot in upcomingOccurrences) {
        final fp = slot.fingerprint;
        if (_scheduledFingerprints[slot.id] == fp) {
          // Unchanged slot in rolling window, skip redundant PlatformChannel call
          continue;
        }

        await _scheduleOccurrence(slot);
        _scheduledFingerprints[slot.id] = fp;
        _slotHabitIds[slot.id] = slot.habit.id;
      }
    } catch (e) {
      debugPrint('[HabitNotificationService] syncHabitReminders error: $e');
    }
  }

  /// Refills the sliding window queue by fetching all active habits from SQLite.
  /// Protected against concurrent re-entrant calls.
  Future<void> refillQueue({bool force = false}) async {
    if (!isDatabaseInitialized) return;
    if (_isSyncing) {
      _needsResync = true;
      return;
    }
    _isSyncing = true;
    try {
      if (force) {
        _scheduledFingerprints.clear();
        _slotHabitIds.clear();
      }
      final uid = currentUserId;
      final query = uid.isNotEmpty
          ? "SELECT * FROM habits WHERE user_id = ? AND (is_enabled != 0 OR is_enabled IS NULL) AND remind_time IS NOT NULL AND remind_time != ''"
          : "SELECT * FROM habits WHERE (user_id IS NULL OR user_id = '') AND (is_enabled != 0 OR is_enabled IS NULL) AND remind_time IS NOT NULL AND remind_time != ''";
      final params = uid.isNotEmpty ? [uid] : <dynamic>[];
      final rows = await db.getAll(query, params);
      final habits = rows.map((r) => Habit.fromRow(r)).toList();
      await syncHabitReminders(habits);
    } catch (e) {
      debugPrint('[HabitNotificationService] refillQueue error: $e');
    } finally {
      _isSyncing = false;
      if (_needsResync) {
        _needsResync = false;
        unawaited(refillQueue());
      }
    }
  }

  /// Reschedules all habits directly from SQLite.
  Future<void> rescheduleAllHabits() async {
    await refillQueue(force: true);
  }

  /// Schedules habit reminders by integrating into the rolling queue.
  Future<void> scheduleHabitReminders(Habit habit, {bool force = false}) async {
    if (!habit.isEnabled || habit.remindTime == null || habit.remindTime!.trim().isEmpty) {
      await cancelHabitReminders(habit.id);
      return;
    }

    if (force) {
      final idsToClear = _slotHabitIds.entries
          .where((e) => e.value == habit.id)
          .map((e) => e.key)
          .toList();
      for (final id in idsToClear) {
        _scheduledFingerprints.remove(id);
      }
    }

    if (isDatabaseInitialized) {
      await refillQueue();
    } else {
      await syncHabitReminders([habit]);
    }
  }

  /// Internal helper to schedule a single-shot exact occurrence.
  Future<void> _scheduleOccurrence(HabitOccurrence slot) async {
    final habit = slot.habit;
    final habitColor = parseHex(habit.color);

    final title = slot.minutesBefore == 10
        ? 'Reminder: ${habit.name} in 10 minutes'
        : 'Starting soon: ${habit.name} in 5 minutes';

    final body = slot.minutesBefore == 10
        ? '"${habit.name}" is scheduled for ${habit.remindTime}. Get ready to start and earn +${habit.targetValue} XP!'
        : 'Almost time for "${habit.name}" (${habit.remindTime}). Start preparing now!';

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: slot.id,
        channelKey: channelKey,
        title: title,
        body: body,
        color: habitColor,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        wakeUpScreen: true,
        payload: {
          'type': 'habit_reminder',
          'habit_id': habit.id,
          'habit_name': habit.name,
          'user_id': currentUserId,
          'minutes_before': '${slot.minutesBefore}',
          'remind_time': habit.remindTime ?? '',
          'date_key': '${slot.dateKey}',
          'is_follow_up': slot.isFollowUp ? 'true' : 'false',
          'is_checkpoint': slot.isCheckpoint ? 'true' : 'false',
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
        year: slot.triggerTime.year,
        month: slot.triggerTime.month,
        day: slot.triggerTime.day,
        hour: slot.triggerTime.hour,
        minute: slot.triggerTime.minute,
        second: 0,
        millisecond: 0,
        repeats: false,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  /// Cancels all scheduled habit reminders and dismisses any active habit notifications
  /// across all accounts (used on sign-out and account switching).
  Future<void> cancelAllHabitReminders() async {
    try {
      _scheduledFingerprints.clear();
      _slotHabitIds.clear();
      await AwesomeNotifications().cancelSchedulesByChannelKey(channelKey);
      await AwesomeNotifications().cancelNotificationsByChannelKey(channelKey);
    } catch (e) {
      debugPrint('[HabitNotificationService] cancelAllHabitReminders error: $e');
    }
  }

  /// Cancels all scheduled reminder notifications for a specific habit ID.
  Future<void> cancelHabitReminders(String habitId) async {
    try {
      final idsToRemove = _slotHabitIds.entries
          .where((e) => e.value == habitId)
          .map((e) => e.key)
          .toList();

      for (final id in idsToRemove) {
        _scheduledFingerprints.remove(id);
        _slotHabitIds.remove(id);
        await AwesomeNotifications().cancel(id);
      }

      // Legacy IDs
      await AwesomeNotifications()
          .cancel(generateNotificationId(habitId, 10, 0));
      await AwesomeNotifications()
          .cancel(generateNotificationId(habitId, 5, 0));
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

  /// Cancels pending alarms and dismisses delivered reminder notifications from the system status tray
  /// when a habit is completed today, and rolls the queue over to tomorrow.
  Future<void> onHabitCompletedToday(String habitId) async {
    try {
      final now = DateTime.now();
      final dateKey = toDateKey(now);
      final todayWeekday = now.weekday;

      final occId10 = generateOccurrenceId(
        habitId: habitId,
        dateKey: dateKey,
        isFollowUp: false,
      );
      final occId5 = generateOccurrenceId(
        habitId: habitId,
        dateKey: dateKey,
        isFollowUp: true,
      );

      final legacyId10 = generateNotificationId(habitId, 10, todayWeekday);
      final legacyId5 = generateNotificationId(habitId, 5, todayWeekday);
      final legacyId10Daily = generateNotificationId(habitId, 10, 0);
      final legacyId5Daily = generateNotificationId(habitId, 5, 0);

      final idsToCancel = [
        occId10,
        occId5,
        legacyId10,
        legacyId5,
        legacyId10Daily,
        legacyId5Daily,
      ];

      for (final id in idsToCancel) {
        _scheduledFingerprints.remove(id);
        _slotHabitIds.remove(id);
        await AwesomeNotifications().cancelSchedule(id);
        await AwesomeNotifications().dismiss(id);
      }

      // Daisy-chain roll over to tomorrow: trigger queue refill to dynamically push upcoming slots
      unawaited(refillQueue());
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
