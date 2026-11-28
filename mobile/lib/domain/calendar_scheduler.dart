import '../data/habit_repository.dart';
import '../data/prayers/prayer_model.dart';
import '../data/task_repository.dart';
import 'recurrence_engine.dart';

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

/// Pure scheduling engine for the calendar and task scheduler.
///
/// Handles:
/// - Rendering active daily habits and Islamic prayers (duration is ALWAYS 15m and fixed).
/// - Priority sorting (`P1 -> P2 -> P3`) from morning to night.
/// - Task collision detection and placement strictly against other tasks (habits and prayers
///   never push, block, or reschedule tasks).
/// - Expanding weekly and recurring tasks onto matching future dates.
/// - Same-day drag reordering, cross-day moves, and duration resizing.
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

  /// Snaps minutes since midnight to [stepMinutes] (default 15m), clamped to valid day bounds.
  static int snapTimeToGrid(int minutes, [int stepMinutes = 15]) {
    final snapped = (minutes / stepMinutes).round() * stepMinutes;
    return snapped.clamp(0, 24 * 60 - minTaskDurationMin);
  }

  /// Returns the default start minute for a new task created today.
  ///
  /// Placed after the current time (+30 minutes), snapped to the next 15-minute mark.
  static int defaultTodayTaskStartMinute([DateTime? referenceTime]) {
    final now = referenceTime ?? DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    var target = nowMinutes + 30;
    final remainder = target % 15;
    if (remainder != 0) {
      target += (15 - remainder);
    }
    if (target < defaultDayStartMinutes) {
      target = defaultDayStartMinutes;
    }
    return target.clamp(0, 23 * 60 + 45);
  }

  /// Formats the default time string (`HH:mm`) for a new task created today.
  static String defaultTodayTaskTimeString([DateTime? referenceTime]) {
    return formatMinutes(defaultTodayTaskStartMinute(referenceTime));
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

  /// Returns all tasks occurring on [dateStr], combining concrete tasks due on [dateStr]
  /// with projected future occurrences of active fixed-schedule recurring tasks
  /// (such as weekly classes/sessions).
  static List<Task> expandTasksForDate(
    List<Task> allTasks,
    String dateStr, {
    bool includeCompleted = true,
  }) {
    final concreteOnDate = <Task>[];
    final concreteSeriesKeys = <String>{};

    for (final t in allTasks) {
      if (t.dueDate == dateStr) {
        final rrule = t.recurrenceRule?.trim() ?? '';
        if (rrule.isNotEmpty) {
          concreteSeriesKeys.add(_recurringSeriesSignature(t));
        }
        if (includeCompleted || !t.isCompleted) {
          concreteOnDate.add(t);
        }
      }
    }

    final projected = <Task>[];
    final seenProjectedSeries = <String>{};

    for (final t in allTasks) {
      if (t.isCompleted) continue;
      final rrule = t.recurrenceRule?.trim() ?? '';
      if (rrule.isEmpty) continue;
      if ((t.recurrenceMode ?? 'fixed') == 'after_completion') continue;
      final anchor = t.dueDate?.trim() ?? '';
      if (anchor.isEmpty || dateStr.compareTo(anchor) <= 0) continue;

      final sig = _recurringSeriesSignature(t);
      if (concreteSeriesKeys.contains(sig) || seenProjectedSeries.contains(sig)) {
        continue;
      }

      if (RecurrenceEngine.occursOnDate(
        rrule: rrule,
        anchorDateStr: anchor,
        targetDateStr: dateStr,
      )) {
        seenProjectedSeries.add(sig);
        projected.add(
          t.copyWith(
            id: 'proj_${t.id}_$dateStr',
            dueDate: dateStr,
            sourceTaskId: t.sourceTaskId ?? t.id,
          ),
        );
      }
    }

    return [...concreteOnDate, ...projected];
  }

  static String _recurringSeriesSignature(Task t) {
    final title = t.title.trim().toLowerCase();
    final rrule = (t.recurrenceRule ?? '').trim().toUpperCase();
    final time = (t.dueTime ?? '').trim();
    return '$title|$rrule|$time';
  }

  /// Packs [orderedTasks] sequentially from [dayStartMin] on [dateStr].
  ///
  /// Preserves the exact order of [orderedTasks]. Habits and prayers never push
  /// or reschedule tasks.
  static List<Task> packTasksForDay({
    required String dateStr,
    required List<Task> orderedTasks,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    DateTime? referenceTime,
    bool includeCompleted = true,
  }) {
    final active = includeCompleted
        ? orderedTasks
        : orderedTasks.where((t) => !t.isCompleted).toList();
    final packed = <Task>[];

    final now = referenceTime ?? DateTime.now();
    final isToday = dateStr == formatDate(now);
    final defaultStart = isToday ? defaultTodayTaskStartMinute(now) : dayStartMin;

    var cursor = defaultStart.clamp(0, 24 * 60 - minTaskDurationMin);

    for (final task in active) {
      final duration = sanitizeDuration(task.estimateMin);
      final explicitTime = parseTimeToMinutes(task.dueTime);

      var slotStart = explicitTime ?? cursor;
      if (slotStart < cursor) {
        slotStart = cursor;
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
      if (nextCursor > cursor) {
        cursor = nextCursor.clamp(0, 24 * 60 - minTaskDurationMin);
      }
    }

    return packed;
  }

  /// Sorts incomplete tasks on [dateStr] by priority (`P1 -> P2 -> P3`) from
  /// morning to night and packs them sequentially without shifting for habits or prayers.
  static List<Task> sortAndPackDayByPriority({
    required String dateStr,
    required List<Task> dayTasks,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    DateTime? referenceTime,
    bool includeCompleted = false,
  }) {
    final active = includeCompleted
        ? dayTasks
        : dayTasks.where((t) => !t.isCompleted).toList();
    final now = referenceTime ?? DateTime.now();
    final isToday = dateStr == formatDate(now);
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

    final effectiveStart = isToday ? defaultTodayTaskStartMinute(now) : dayStartMin;

    return packTasksForDay(
      dateStr: dateStr,
      orderedTasks: indexed.map((e) => e.value).toList(),
      dayStartMin: effectiveStart,
      referenceTime: referenceTime,
    );
  }

  /// Reorders [movedTaskId] within the SAME day ([dateStr]) based on
  /// [targetDropMinute] using priority-aware forward collision resolution
  /// strictly against other tasks (never habits or prayers).
  static List<Task> reorderTaskWithinSameDay({
    required String dateStr,
    required List<Task> currentDayTasks,
    required String movedTaskId,
    required int targetDropMinute,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    DateTime? referenceTime,
    bool includeCompleted = true,
  }) {
    final active = includeCompleted
        ? currentDayTasks
        : currentDayTasks.where((t) => !t.isCompleted).toList();
    final movedIndex = active.indexWhere((t) => t.id == movedTaskId);
    if (movedIndex < 0) {
      return packTasksForDay(
        dateStr: dateStr,
        orderedTasks: active,
        dayStartMin: dayStartMin,
        referenceTime: referenceTime,
        includeCompleted: includeCompleted,
      );
    }

    final movedTask = active[movedIndex];
    final remaining = active.where((t) => t.id != movedTaskId).toList();
    final targetMin = snapTimeToGrid(targetDropMinute, 5);

    return resolveCollisionPlacement(
      dateStr: dateStr,
      existingDayTasks: remaining,
      incomingTask: movedTask,
      targetStartMinute: targetMin,
      dayStartMin: dayStartMin,
      minGapMinutes: 1,
    );
  }

  /// Resolves task placement on [dateStr] starting from [targetStartMinute]
  /// strictly against other tasks (never habits or prayers):
  /// 1. Searches strictly forward: never moves any task into empty space before [targetStartMinute].
  /// 2. If slot is occupied by a conflicting task:
  ///    - If incoming task has strictly higher priority (P1 vs P2):
  ///      Incoming task takes the slot; conflicting task moves to the next empty space.
  ///    - If priority is the same or incoming has lower priority:
  ///      The existing task stays in its place, and the incoming task moves to the next empty space.
  static List<Task> resolveCollisionPlacement({
    required String dateStr,
    required List<Task> existingDayTasks,
    required Task incomingTask,
    required int targetStartMinute,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    int minGapMinutes = 0,
  }) {
    final tasksMap = <String, Task>{
      for (final t in existingDayTasks)
        if (!t.isCompleted &&
            t.id != incomingTask.id &&
            t.dueTime != null &&
            t.dueTime!.trim().isNotEmpty)
          t.id: t,
    };

    void placeTask(Task task, int requestedMin) {
      final duration = sanitizeDuration(task.estimateMin);
      var cur = requestedMin.clamp(0, 24 * 60 - minTaskDurationMin);

      while (cur < 24 * 60 - minTaskDurationMin) {
        final slotEnd = cur + duration;

        Task? conflicting;
        int? confEnd;

        for (final other in tasksMap.values) {
          if (other.id == task.id) continue;
          final oStart = parseTimeToMinutes(other.dueTime);
          if (oStart == null) continue;
          final oDuration = sanitizeDuration(other.estimateMin);
          final oEnd = oStart + oDuration;

          if (cur < oEnd && slotEnd > oStart) {
            conflicting = other;
            confEnd = oEnd;
            break;
          }
        }

        if (conflicting == null) {
          tasksMap[task.id] = task.copyWith(
            dueDate: dateStr,
            dueTime: formatMinutes(cur.clamp(0, 24 * 60 - minTaskDurationMin)),
            estimateMin: duration,
          );
          return;
        }

        final taskRank = priorityRank(task.priority);
        final confRank = priorityRank(conflicting.priority);
        // Never displace a projected future recurring occurrence (keep fixed weekly slot intact)
        final canDisplaceConflicting =
            taskRank < confRank && conflicting.sourceTaskId == null;

        if (canDisplaceConflicting) {
          tasksMap[task.id] = task.copyWith(
            dueDate: dateStr,
            dueTime: formatMinutes(cur.clamp(0, 24 * 60 - minTaskDurationMin)),
            estimateMin: duration,
          );
          tasksMap.remove(conflicting.id);
          final nextMin = cur + duration + minGapMinutes;
          placeTask(conflicting, nextMin);
          return;
        } else {
          final nextMin = confEnd! + minGapMinutes;
          cur = nextMin;
        }
      }

      tasksMap[task.id] = task.copyWith(
        dueDate: dateStr,
        dueTime: formatMinutes(cur.clamp(0, 24 * 60 - minTaskDurationMin)),
        estimateMin: duration,
      );
    }

    placeTask(incomingTask, targetStartMinute);

    final allTasks = tasksMap.values.toList();
    allTasks.sort((a, b) {
      final timeA = parseTimeToMinutes(a.dueTime) ?? dayStartMin;
      final timeB = parseTimeToMinutes(b.dueTime) ?? dayStartMin;
      if (timeA != timeB) return timeA.compareTo(timeB);
      final rA = priorityRank(a.priority);
      final rB = priorityRank(b.priority);
      if (rA != rB) return rA.compareTo(rB);
      return a.id.compareTo(b.id);
    });
    return allTasks;
  }

  /// Moves [movedTaskId] from its current day to [targetDateStr] and
  /// automatically re-sorts both source and target days by priority (`P1 -> P2 -> P3`).
  static List<Task> moveTaskToDay({
    required List<Task> allTasks,
    required String movedTaskId,
    required String targetDateStr,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    int? targetDropMinute,
    DateTime? referenceTime,
    bool includeCompleted = true,
  }) {
    final movedIdx = allTasks.indexWhere((t) => t.id == movedTaskId);
    if (movedIdx < 0) return const [];

    final movedTask = allTasks[movedIdx];
    final sourceDateStr = movedTask.dueDate;

    final updatedMoved = movedTask.copyWith(
      dueDate: targetDateStr,
      dueTime: targetDropMinute != null ? formatMinutes(targetDropMinute) : null,
      clearDueTime: targetDropMinute == null,
      estimateMin: sanitizeDuration(movedTask.estimateMin),
    );

    final targetDayTasks = <Task>[
      for (final t in allTasks)
        if (t.id != movedTaskId && t.dueDate == targetDateStr && (includeCompleted || !t.isCompleted))
          t.copyWith(clearDueTime: targetDropMinute == null),
      if (includeCompleted || !updatedMoved.isCompleted) updatedMoved,
    ];

    final packedTarget = sortAndPackDayByPriority(
      dateStr: targetDateStr,
      dayTasks: targetDayTasks,
      dayStartMin: dayStartMin,
      referenceTime: referenceTime,
      includeCompleted: includeCompleted,
    );

    if (sourceDateStr != null &&
        sourceDateStr.isNotEmpty &&
        sourceDateStr != targetDateStr) {
      final sourceDayTasks = [
        for (final t in allTasks)
          if (t.id != movedTaskId &&
              t.dueDate == sourceDateStr &&
              (includeCompleted || !t.isCompleted))
            t,
      ];
      final packedSource = sortAndPackDayByPriority(
        dateStr: sourceDateStr,
        dayTasks: sourceDayTasks,
        dayStartMin: dayStartMin,
        referenceTime: referenceTime,
        includeCompleted: includeCompleted,
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
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    bool includeCompleted = true,
  }) {
    final clampedDuration = sanitizeDuration(newEstimateMin);
    final updatedDayTasks = [
      for (final t in dayTasks)
        if (includeCompleted || !t.isCompleted)
          t.id == resizedTaskId
              ? t.copyWith(estimateMin: clampedDuration)
              : t,
    ];

    return sortAndPackDayByPriority(
      dateStr: dateStr,
      dayTasks: updatedDayTasks,
      dayStartMin: dayStartMin,
      includeCompleted: includeCompleted,
    );
  }

  /// Orders tasks by their current `dueTime` ascending (preserving relative
  /// list order for ties or unscheduled tasks).
  static List<Task> orderByCurrentSchedule(List<Task> tasks) {
    return _orderByScheduledTime(tasks);
  }

  /// Auto-schedules [newTask] on [dateStr] respecting priority and existing tasks,
  /// without rescheduling for habits or prayers.
  static List<Task> scheduleNewTaskForDay({
    required String dateStr,
    required List<Task> existingDayTasks,
    required Task newTask,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    DateTime? referenceTime,
    bool includeCompleted = true,
  }) {
    final activeExisting = existingDayTasks
        .where((t) => (includeCompleted || !t.isCompleted) && t.id != newTask.id)
        .toList();

    final tasksMap = <String, Task>{};
    var normCursor = dayStartMin;
    for (final t in activeExisting) {
      if (t.dueTime != null && t.dueTime!.trim().isNotEmpty) {
        tasksMap[t.id] = t;
      } else {
        final normalized = t.copyWith(dueTime: formatMinutes(normCursor));
        tasksMap[t.id] = normalized;
        normCursor += sanitizeDuration(t.estimateMin);
      }
    }

    final now = referenceTime ?? DateTime.now();
    final isToday = dateStr == formatDate(now);
    final explicitMin = parseTimeToMinutes(newTask.dueTime);
    final candidateStart = explicitMin != null
        ? snapTimeToGrid(explicitMin, 5)
        : (isToday ? defaultTodayTaskStartMinute(now) : dayStartMin);

    return resolveCollisionPlacement(
      dateStr: dateStr,
      existingDayTasks: tasksMap.values.toList(),
      incomingTask: newTask,
      targetStartMinute: candidateStart,
      dayStartMin: dayStartMin,
    );
  }

  /// Checks whether a task scheduled on [dateStr] starting at [startMinute] with [durationMin]
  /// collides with any other active task (including weekly/recurring tasks) on that date.
  /// Strictly checks only tasks (never habits or prayers).
  static Task? findConflictingTask({
    required String dateStr,
    required int startMinute,
    required int durationMin,
    required List<Task> existingTasks,
    String? excludeTaskId,
  }) {
    final endMinute = startMinute + durationMin;
    final dayTasks = expandTasksForDate(
      existingTasks,
      dateStr,
      includeCompleted: false,
    );
    for (final other in dayTasks) {
      if (other.isCompleted) continue;
      if (excludeTaskId != null &&
          (other.id == excludeTaskId || other.sourceTaskId == excludeTaskId)) {
        continue;
      }
      final oStart = parseTimeToMinutes(other.dueTime);
      if (oStart == null) continue;
      final oDur = sanitizeDuration(other.estimateMin);
      final oEnd = oStart + oDur;
      if (startMinute < oEnd && endMinute > oStart) {
        return other;
      }
    }
    return null;
  }

  /// Finds the next available contiguous start minute on [dateStr] starting from [searchFromMinute]
  /// for a task of [durationMin] that does not collide with any existing task on that day.
  /// Habits and prayers are never treated as collisions.
  static int findNextAvailableMinute({
    required String dateStr,
    required int searchFromMinute,
    required int durationMin,
    required List<Task> existingTasks,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayEndMinute = 24 * 60,
    String? excludeTaskId,
  }) {
    final dayTasks = expandTasksForDate(
      existingTasks,
      dateStr,
      includeCompleted: false,
    );
    final blocked = <({int start, int end})>[
      for (final t in dayTasks)
        if (!t.isCompleted &&
            (excludeTaskId == null ||
                (t.id != excludeTaskId && t.sourceTaskId != excludeTaskId)) &&
            t.dueTime != null)
          if (parseTimeToMinutes(t.dueTime) != null)
            (
              start: parseTimeToMinutes(t.dueTime)!,
              end: parseTimeToMinutes(t.dueTime)! + sanitizeDuration(t.estimateMin),
            ),
    ]..sort((a, b) => a.start.compareTo(b.start));

    var cur = searchFromMinute.clamp(0, dayEndMinute - durationMin);
    var moved = true;
    while (moved && cur + durationMin <= dayEndMinute) {
      moved = false;
      final curEnd = cur + durationMin;
      for (final b in blocked) {
        if (cur < b.end && curEnd > b.start) {
          cur = b.end;
          moved = true;
          break;
        }
      }
    }
    return cur.clamp(0, dayEndMinute - durationMin);
  }

  /// Displaces conflicting tasks forward into the next empty spot while [incomingTask] takes [targetStartMinute].
  /// Habits and prayers never displace or reschedule tasks.
  static List<Task> displaceConflictingTask({
    required String dateStr,
    required List<Task> existingDayTasks,
    required Task incomingTask,
    required int targetStartMinute,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
  }) {
    final forcedHighPriorityTask = incomingTask.copyWith(priority: 1);
    final result = resolveCollisionPlacement(
      dateStr: dateStr,
      existingDayTasks: existingDayTasks,
      incomingTask: forcedHighPriorityTask,
      targetStartMinute: targetStartMinute,
    );
    return result
        .map((t) => t.id == incomingTask.id ? t.copyWith(priority: incomingTask.priority) : t)
        .toList();
  }

  /// Packs any unscheduled tasks into open slots on [dateStr] while keeping
  /// all tasks with existing `dueTime` at their exact slots without reordering.
  /// Habits and prayers never block or shift task slots.
  static List<Task> packTasksPreservingExplicitTimes({
    required String dateStr,
    required List<Task> dayTasks,
    List<CalendarHabitBlock> habitBlocks = const [],
    List<CalendarPrayerBlock> prayerBlocks = const [],
    int dayStartMin = defaultDayStartMinutes,
    DateTime? referenceTime,
    bool includeCompleted = true,
  }) {
    final active = includeCompleted
        ? dayTasks
        : dayTasks.where((t) => !t.isCompleted).toList();
    if (active.isEmpty) return const [];

    final now = referenceTime ?? DateTime.now();
    final isToday = dateStr == formatDate(now);
    final baseline = isToday ? defaultTodayTaskStartMinute(now) : dayStartMin;

    final result = <Task>[];
    final scheduled = active.where((t) => t.dueTime != null && t.dueTime!.trim().isNotEmpty).toList();
    final unscheduled = active.where((t) => t.dueTime == null || t.dueTime!.trim().isEmpty).toList();

    unscheduled.sort((a, b) {
      final rA = priorityRank(a.priority);
      final rB = priorityRank(b.priority);
      if (rA != rB) return rA.compareTo(rB);
      return a.id.compareTo(b.id);
    });

    result.addAll(scheduled);

    var cursor = baseline;
    for (final task in unscheduled) {
      final duration = sanitizeDuration(task.estimateMin);
      var placed = false;
      while (!placed && cursor < 24 * 60 - minTaskDurationMin) {
        var hitTask = false;
        for (final s in result) {
          final sStart = parseTimeToMinutes(s.dueTime) ?? dayStartMin;
          final sEnd = sStart + sanitizeDuration(s.estimateMin);
          if (cursor < sEnd && (cursor + duration) > sStart) {
            cursor = sEnd;
            hitTask = true;
            break;
          }
        }
        if (hitTask) continue;

        placed = true;
      }

      result.add(task.copyWith(
        dueDate: dateStr,
        dueTime: formatMinutes(cursor.clamp(0, 24 * 60 - minTaskDurationMin)),
        estimateMin: duration,
      ));
      cursor += duration;
    }

    result.sort((a, b) {
      final timeA = parseTimeToMinutes(a.dueTime) ?? dayStartMin;
      final timeB = parseTimeToMinutes(b.dueTime) ?? dayStartMin;
      if (timeA != timeB) return timeA.compareTo(timeB);
      final rA = priorityRank(a.priority);
      final rB = priorityRank(b.priority);
      if (rA != rB) return rA.compareTo(rB);
      return a.id.compareTo(b.id);
    });

    return result;
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
