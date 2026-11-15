import '../data/habit_repository.dart';
import '../data/prayers/prayer_model.dart';
import '../data/task_repository.dart';

/// Represents a daily habit time slot placed on the desktop calendar.
class CalendarHabitBlock {
  final Habit habit;
  final int startMinute;
  final int durationMin;

  const CalendarHabitBlock({
    required this.habit,
    required this.startMinute,
    this.durationMin = CalendarScheduler.defaultHabitDurationMin,
  });

  int get endMinute => startMinute + durationMin;

  String get startTimeFormatted => CalendarScheduler.formatMinutes(startMinute);
  String get endTimeFormatted => CalendarScheduler.formatMinutes(endMinute);
}

/// Represents an Islamic prayer time slot placed on the desktop calendar.
class CalendarPrayerBlock {
  final Prayer prayer;
  final int startMinute;
  final int durationMin;

  const CalendarPrayerBlock({
    required this.prayer,
    required this.startMinute,
    this.durationMin = CalendarScheduler.defaultPrayerDurationMin,
  });

  int get endMinute => startMinute + durationMin;

  String get startTimeFormatted => CalendarScheduler.formatMinutes(startMinute);
  String get endTimeFormatted => CalendarScheduler.formatMinutes(endMinute);
}

/// Represents grid line zoom resolution for the desktop calendar.
enum CalendarZoomLevel {
  hour(
    intervalMinutes: 60,
    hourHeight: 96.0,
    label: '1h',
  ),
  halfHour(
    intervalMinutes: 30,
    hourHeight: 192.0,
    label: '30m',
  ),
  quarterHour(
    intervalMinutes: 15,
    hourHeight: 384.0,
    label: '15m',
  );

  final int intervalMinutes;
  final double hourHeight;
  final String label;

  const CalendarZoomLevel({
    required this.intervalMinutes,
    required this.hourHeight,
    required this.label,
  });
}

/// Pure scheduling engine for the desktop Google-Calendar-style week view.
///
/// Handles:
/// - Including active daily habits and Islamic prayers (duration is ALWAYS 15m and fixed).
/// - Priority sorting (`P1 -> P2 -> P3`) from morning to night.
/// - Packing tasks while avoiding all intervals occupied by daily habits and prayers.
/// - Same-day drag reordering (preserves manual list order without priority
///   re-sorting).
/// - Cross-day moves and duration resizing (re-sorts affected days by
///   priority automatically).
abstract final class CalendarScheduler {
  static const int defaultDayStartMinutes = 8 * 60; // 08:00
  static const int defaultHabitStartMinutes = 7 * 60; // 07:00
  static const int defaultHabitDurationMin = 15; // Habits due time is ALWAYS 15 min and can't be changed
  static const int defaultPrayerDurationMin = 15; // Prayers due time is ALWAYS 15 min and can't be changed
  static const int defaultTaskDurationMin = 15;
  static const int minTaskDurationMin = 5;
  static const int maxTaskDurationMin = 480;

  /// Formats a [DateTime] as `yyyy-MM-dd`.
  static String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formats minutes since midnight (`0..1439`) as `HH:mm`.
  static String formatMinutes(int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    final h = (clamped ~/ 60).toString().padLeft(2, '0');
    final m = (clamped % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Parses `HH:mm` or `h:mm AM/PM` into minutes since midnight.
  static int? parseTimeToMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    final val = HabitRepository.parseTimeToMinutes(timeStr);
    if (val >= 24 * 60) return null;
    return val;
  }

  /// Maps priority (`1=P1`, `2=P2`, `3=P3`) to sort rank (`0..3`).
  static int priorityRank(int? priority) {
    return switch (priority) {
      1 => 0,
      2 => 1,
      3 => 2,
      _ => 3,
    };
  }

  /// Returns a valid duration in minutes, defaulting to [defaultTaskDurationMin].
  static int sanitizeDuration(int? estimateMin) {
    if (estimateMin == null || estimateMin <= 0) {
      return defaultTaskDurationMin;
    }
    return estimateMin.clamp(minTaskDurationMin, maxTaskDurationMin);
  }

  /// Snaps a dragged resize duration to 5-minute increments within allowed bounds.
  static int snapDurationTo5Min(int minutes) {
    final snapped = (minutes / 5).round() * 5;
    return snapped.clamp(minTaskDurationMin, maxTaskDurationMin);
  }

  /// Returns standard minutes from midnight for canonical prayer codes.
  static int defaultPrayerMinutesForCode(String code) {
    return switch (code.toLowerCase().trim()) {
      'fajr' => 5 * 60 + 30, // 05:30
      'dhuhr' => 12 * 60 + 45, // 12:45
      'asr' => 16 * 60 + 15, // 16:15
      'maghrib' => 18 * 60 + 45, // 18:45
      'isha' => 20 * 60 + 15, // 20:15
      _ => 12 * 60,
    };
  }

  /// Returns the 7 consecutive [DateTime] days of the week containing [anchorDate]
  /// starting from [startWeekday] (`DateTime.monday` .. `DateTime.sunday`).
  static List<DateTime> buildWeekDays(DateTime anchorDate, int startWeekday) {
    final normalizedAnchor = DateTime(
      anchorDate.year,
      anchorDate.month,
      anchorDate.day,
    );
    final normalizedStartWeekday =
        ((startWeekday - 1) % 7) + 1; // 1 (Mon) .. 7 (Sun)
    final offset =
        (normalizedAnchor.weekday - normalizedStartWeekday + 7) % 7;
    final weekStart = DateTime(
      normalizedAnchor.year,
      normalizedAnchor.month,
      normalizedAnchor.day - offset,
    );
    return List<DateTime>.generate(
      7,
      (i) => DateTime(weekStart.year, weekStart.month, weekStart.day + i),
      growable: false,
    );
  }

  /// Builds calendar blocks for active **daily** habits only.
  ///
  /// Weekly and other non-daily habits, disabled habits, and legacy prayer
  /// pseudo-rows are excluded. Habit duration is ALWAYS 15 min and fixed.
  static List<CalendarHabitBlock> buildDailyHabitBlocks(
    List<Habit> habits, {
    int habitDurationMin = defaultHabitDurationMin,
  }) {
    const duration = defaultHabitDurationMin; // Always 15 min!
    final blocks = <CalendarHabitBlock>[];
    for (final habit in habits) {
      if (!habit.isEnabled) continue;
      if (HabitStreakService.isPrayerIdentifier(habit.id)) continue;
      if (habit.scheduleType.toLowerCase().trim() != 'daily') continue;

      final parsedMin = parseTimeToMinutes(habit.remindTime);
      final startMin = (parsedMin ?? defaultHabitStartMinutes)
          .clamp(0, 24 * 60 - duration);
      blocks.add(
        CalendarHabitBlock(
          habit: habit,
          startMinute: startMin,
          durationMin: duration,
        ),
      );
    }

    blocks.sort((a, b) {
      final timeCmp = a.startMinute.compareTo(b.startMinute);
      if (timeCmp != 0) return timeCmp;
      final orderCmp = a.habit.sortOrder.compareTo(b.habit.sortOrder);
      if (orderCmp != 0) return orderCmp;
      return a.habit.name.toLowerCase().compareTo(b.habit.name.toLowerCase());
    });
    return blocks;
  }

  /// Builds calendar blocks for daily Islamic prayers.
  ///
  /// Prayer duration is ALWAYS 15 min and fixed.
  static List<CalendarPrayerBlock> buildDailyPrayerBlocks(
    List<Prayer> prayers, {
    int prayerDurationMin = defaultPrayerDurationMin,
  }) {
    const duration = defaultPrayerDurationMin; // Always 15 min!
    final blocks = <CalendarPrayerBlock>[];
    for (final prayer in prayers) {
      final parsedMin = parseTimeToMinutes(prayer.time);
      final startMin = (parsedMin ?? defaultPrayerMinutesForCode(prayer.prayerCode))
          .clamp(0, 24 * 60 - duration);
      blocks.add(
        CalendarPrayerBlock(
          prayer: prayer,
          startMinute: startMin,
          durationMin: duration,
        ),
      );
    }

    blocks.sort((a, b) {
      final timeCmp = a.startMinute.compareTo(b.startMinute);
      if (timeCmp != 0) return timeCmp;
      return a.prayer.sortOrder.compareTo(b.prayer.sortOrder);
    });
    return blocks;
  }

  /// Packs [orderedTasks] sequentially from [dayStartMin] on [dateStr], skipping
  /// any time interval that overlaps a [CalendarHabitBlock] or [CalendarPrayerBlock].
  ///
  /// Preserves the exact order of [orderedTasks]. Completed tasks are excluded.
  static List<Task> packTasksForDay({
    required String dateStr,
    required List<Task> orderedTasks,
    required List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
  }) {
    final blockedIntervals = <({int start, int end})>[
      for (final h in habitBlocks) (start: h.startMinute, end: h.endMinute),
      for (final p in prayerBlocks) (start: p.startMinute, end: p.endMinute),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final active = orderedTasks.where((t) => !t.isCompleted).toList();
    final packed = <Task>[];

    var cursor = dayStartMin.clamp(0, 24 * 60 - minTaskDurationMin);

    for (final task in active) {
      final duration = sanitizeDuration(task.estimateMin);
      var slotStart = cursor;

      var adjusted = true;
      while (adjusted) {
        adjusted = false;
        final slotEnd = slotStart + duration;
        for (final block in blockedIntervals) {
          if (slotStart < block.end && slotEnd > block.start) {
            if (block.end < 24 * 60 - minTaskDurationMin) {
              slotStart = block.end;
              adjusted = true;
            }
            break;
          }
        }
      }

      final clampedStart = slotStart.clamp(0, 24 * 60 - minTaskDurationMin);
      packed.add(
        task.copyWith(
          dueDate: dateStr,
          dueTime: formatMinutes(clampedStart),
          estimateMin: duration,
        ),
      );

      final nextCursor = clampedStart + duration;
      cursor = nextCursor.clamp(0, 24 * 60 - minTaskDurationMin);
    }

    return packed;
  }

  /// Sorts incomplete tasks on [dateStr] by priority (`P1 -> P2 -> P3`) from
  /// morning to night and packs them around daily habit and prayer blocks.
  static List<Task> sortAndPackDayByPriority({
    required String dateStr,
    required List<Task> dayTasks,
    required List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
  }) {
    final active = dayTasks.where((t) => !t.isCompleted).toList();
    final indexed = active.asMap().entries.toList();

    indexed.sort((a, b) {
      final prioCmp = priorityRank(a.value.priority)
          .compareTo(priorityRank(b.value.priority));
      if (prioCmp != 0) return prioCmp;

      final timeA = parseTimeToMinutes(a.value.dueTime);
      final timeB = parseTimeToMinutes(b.value.dueTime);
      if (timeA != null && timeB != null && timeA != timeB) {
        return timeA.compareTo(timeB);
      }
      if (timeA != null && timeB == null) return -1;
      if (timeA == null && timeB != null) return 1;

      return a.key.compareTo(b.key);
    });

    return packTasksForDay(
      dateStr: dateStr,
      orderedTasks: indexed.map((e) => e.value).toList(),
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      dayStartMin: dayStartMin,
    );
  }

  /// Reorders [movedTaskId] within the SAME day ([dateStr]) based on
  /// [targetDropMinute], WITHOUT priority re-sorting.
  ///
  /// Treats the move as reordering the day's task list (e.g., dragging a P3
  /// task to the top puts it first in the morning), while still keeping every
  /// task clear of [habitBlocks] and [prayerBlocks].
  static List<Task> reorderTaskWithinSameDay({
    required String dateStr,
    required List<Task> currentDayTasks,
    required String movedTaskId,
    required int targetDropMinute,
    required List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
  }) {
    final active = currentDayTasks.where((t) => !t.isCompleted).toList();
    final movedIndex = active.indexWhere((t) => t.id == movedTaskId);
    if (movedIndex < 0) {
      return packTasksForDay(
        dateStr: dateStr,
        orderedTasks: active,
        habitBlocks: habitBlocks,
        prayerBlocks: prayerBlocks,
        dayStartMin: dayStartMin,
      );
    }

    // Order current day tasks by their current scheduled dueTime (or input order).
    final orderedCurrent = _orderByScheduledTime(active);
    final originalMovedIdx =
        orderedCurrent.indexWhere((t) => t.id == movedTaskId);
    final movedTask = orderedCurrent[originalMovedIdx];
    final remaining = <Task>[];
    final wasBeforeMoved = <bool>[];
    for (var i = 0; i < orderedCurrent.length; i++) {
      if (i == originalMovedIdx) continue;
      remaining.add(orderedCurrent[i]);
      wasBeforeMoved.add(i < originalMovedIdx);
    }

    // Ensure remaining tasks have concrete time slots for accurate drop lookup.
    final packedRemaining = packTasksForDay(
      dateStr: dateStr,
      orderedTasks: remaining,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      dayStartMin: dayStartMin,
    );

    var insertIdx = packedRemaining.length;
    for (var i = 0; i < packedRemaining.length; i++) {
      final t = packedRemaining[i];
      final start = parseTimeToMinutes(t.dueTime) ?? dayStartMin;
      final duration = sanitizeDuration(t.estimateMin);
      final end = start + duration;
      final shouldInsertBefore = wasBeforeMoved[i]
          ? targetDropMinute < end
          : targetDropMinute <= start;
      if (shouldInsertBefore) {
        insertIdx = i;
        break;
      }
    }

    final reordered = [...remaining];
    reordered.insert(insertIdx.clamp(0, reordered.length), movedTask);

    return packTasksForDay(
      dateStr: dateStr,
      orderedTasks: reordered,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      dayStartMin: dayStartMin,
    );
  }

  /// Moves [movedTaskId] from its current day to [targetDateStr] and
  /// automatically re-sorts both source and target days by priority
  /// (`P1 -> P2 -> P3`).
  ///
  /// Returns the updated [Task] objects across affected days.
  static List<Task> moveTaskToDay({
    required List<Task> allTasks,
    required String movedTaskId,
    required String targetDateStr,
    required List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
  }) {
    final movedIdx = allTasks.indexWhere((t) => t.id == movedTaskId);
    if (movedIdx < 0) return const [];

    final movedTask = allTasks[movedIdx];
    final sourceDateStr = movedTask.dueDate;

    final updatedMoved = movedTask.copyWith(
      dueDate: targetDateStr,
      clearDueTime: true,
      estimateMin: sanitizeDuration(movedTask.estimateMin),
    );

    final targetDayTasks = <Task>[
      for (final t in allTasks)
        if (t.id != movedTaskId && t.dueDate == targetDateStr && !t.isCompleted)
          t,
      if (!updatedMoved.isCompleted) updatedMoved,
    ];

    final packedTarget = sortAndPackDayByPriority(
      dateStr: targetDateStr,
      dayTasks: targetDayTasks,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      dayStartMin: dayStartMin,
    );

    if (sourceDateStr != null &&
        sourceDateStr.isNotEmpty &&
        sourceDateStr != targetDateStr) {
      final sourceDayTasks = [
        for (final t in allTasks)
          if (t.id != movedTaskId &&
              t.dueDate == sourceDateStr &&
              !t.isCompleted)
            t,
      ];
      final packedSource = sortAndPackDayByPriority(
        dateStr: sourceDateStr,
        dayTasks: sourceDayTasks,
        habitBlocks: habitBlocks,
        prayerBlocks: prayerBlocks,
        dayStartMin: dayStartMin,
      );
      return [...packedTarget, ...packedSource];
    }

    return packedTarget;
  }

  /// Updates [resizedTaskId]'s duration to [newEstimateMin] and automatically
  /// re-sorts [dateStr] by priority (`P1 -> P2 -> P3`).
  static List<Task> resizeTaskDuration({
    required String dateStr,
    required List<Task> dayTasks,
    required String resizedTaskId,
    required int newEstimateMin,
    required List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
  }) {
    final clampedDuration = sanitizeDuration(newEstimateMin);
    final updatedDayTasks = [
      for (final t in dayTasks)
        if (!t.isCompleted)
          t.id == resizedTaskId
              ? t.copyWith(estimateMin: clampedDuration)
              : t,
    ];

    return sortAndPackDayByPriority(
      dateStr: dateStr,
      dayTasks: updatedDayTasks,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      dayStartMin: dayStartMin,
    );
  }

  /// Orders tasks by their current `dueTime` ascending (preserving relative
  /// list order for ties or unscheduled tasks).
  static List<Task> orderByCurrentSchedule(List<Task> tasks) {
    return _orderByScheduledTime(tasks);
  }

  static List<Task> _orderByScheduledTime(List<Task> tasks) {
    final indexed = tasks.asMap().entries.toList();
    indexed.sort((a, b) {
      final timeA = parseTimeToMinutes(a.value.dueTime);
      final timeB = parseTimeToMinutes(b.value.dueTime);
      if (timeA != null && timeB != null && timeA != timeB) {
        return timeA.compareTo(timeB);
      }
      if (timeA != null && timeB == null) return -1;
      if (timeA == null && timeB != null) return 1;
      return a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }
}
