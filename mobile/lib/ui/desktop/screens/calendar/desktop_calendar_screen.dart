import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme.dart';
import '../../../../data/habit_repository.dart';
import '../../../../data/powersync_db.dart' show isDatabaseInitialized, db;
import '../../../../data/prayer_time_service.dart';
import '../../../../data/task_repository.dart';
import '../../../../domain/calendar_scheduler.dart';
import '../../dialogs/quick_task_dialog.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/ghost_button.dart';
import '../command_deck/desktop_task_preview_dialog.dart';

/// Google Calendar-style desktop week view combining priority-sorted tasks,
/// fixed 15-minute daily habits, and fixed 15-minute daily prayers with dynamic zoom.
class DesktopCalendarScreen extends StatefulWidget {
  const DesktopCalendarScreen({
    super.key,
    this.taskRepo,
    this.habitRepo,
    this.prayerRepo,
    this.initialTasks,
    this.initialHabits,
    this.initialPrayers,
    this.initialCompletedLogs,
    this.initialSelectedDate,
    this.initialStartWeekday = DateTime.sunday,
    this.initialZoomLevel = CalendarZoomLevel.halfHour,
  });

  final TaskRepository? taskRepo;
  final HabitRepository? habitRepo;
  final PrayerRepository? prayerRepo;
  final List<Task>? initialTasks;
  final List<Habit>? initialHabits;
  final List<Prayer>? initialPrayers;
  final Map<String, Set<String>>? initialCompletedLogs;
  final DateTime? initialSelectedDate;
  final int initialStartWeekday;
  final CalendarZoomLevel initialZoomLevel;

  @override
  State<DesktopCalendarScreen> createState() => _DesktopCalendarScreenState();
}

class _DesktopCalendarScreenState extends State<DesktopCalendarScreen> {
  static const double _timeGutterWidth = 62.0;

  late DateTime _selectedDate;
  late int _startWeekday;
  late CalendarZoomLevel _zoomLevel;
  late List<Task> _tasks;
  late List<Habit> _habits;
  late List<Prayer> _prayers;
  late final ScrollController _verticalScrollController;

  double get _hourHeight => _zoomLevel.hourHeight;

  /// Days whose task order was explicitly adjusted via same-day drag.
  /// Those days preserve manual task ordering rather than auto-sorting by P1..P3
  /// until a cross-day move, resize, or explicit creation updates them.
  final Set<String> _manuallyOrderedDays = {};
  bool _showCompletedTasks = true;

  final List<GlobalKey> _dayColumnKeys = List.generate(7, (_) => GlobalKey());

  StreamSubscription<List<Task>>? _taskSub;
  StreamSubscription<List<Habit>>? _habitSub;
  StreamSubscription<List<Prayer>>? _prayerSub;
  StreamSubscription<List<Map<String, dynamic>>>? _habitLogsSub;

  Map<String, Set<String>> _completedLogsByDate = {};

  String? _resizingTaskId;
  int _resizingBaseDurationMin = CalendarScheduler.defaultTaskDurationMin;
  double _resizingStartGlobalDy = 0.0;
  int? _resizingPreviewDurationMin;

  @override
  void initState() {
    super.initState();
    final baseDate = widget.initialSelectedDate ?? DateTime.now();
    _selectedDate = DateTime(baseDate.year, baseDate.month, baseDate.day);
    _startWeekday = ((widget.initialStartWeekday - 1) % 7) + 1;
    _zoomLevel = widget.initialZoomLevel;
    _tasks = List<Task>.from(widget.initialTasks ?? const []);
    _habits = List<Habit>.from(widget.initialHabits ?? const []);
    _prayers = List<Prayer>.from(widget.initialPrayers ?? const []);
    if (widget.initialCompletedLogs != null) {
      _completedLogsByDate = Map.from(widget.initialCompletedLogs!);
    }
    _verticalScrollController = ScrollController(
      initialScrollOffset: 6.5 * _hourHeight, // Start visible around 06:30
    );

    _bindStreams();
  }

  void _bindStreams() {
    final canReadTasks = widget.initialTasks == null &&
        (widget.taskRepo != null || isDatabaseInitialized);
    if (canReadTasks) {
      try {
        final repo = widget.taskRepo ?? TaskRepository();
        _taskSub = repo.watchTasks().listen(
          (tasks) {
            if (!mounted) return;
            setState(() => _tasks = tasks);
          },
          onError: (_) {},
        );
      } catch (_) {}
    }

    final canReadHabits = widget.initialHabits == null &&
        (widget.habitRepo != null || isDatabaseInitialized);
    if (canReadHabits) {
      try {
        final repo = widget.habitRepo ?? HabitRepository();
        _habitSub = repo.watchHabits().listen(
          (habits) {
            if (!mounted) return;
            setState(() => _habits = habits);
          },
          onError: (_) {},
        );
      } catch (_) {}
    }

    final canReadPrayers = widget.initialPrayers == null &&
        (widget.prayerRepo != null || isDatabaseInitialized);
    if (canReadPrayers) {
      try {
        final repo = widget.prayerRepo ?? PrayerRepository();
        _prayerSub = repo.watchPrayers().listen(
          (prayers) {
            if (!mounted) return;
            setState(() => _prayers = prayers);
          },
          onError: (_) {},
        );
      } catch (_) {}
    }

    if (isDatabaseInitialized) {
      try {
        _habitLogsSub = db.watch(
          "SELECT habit_id, log_date FROM habit_logs WHERE status = 'done'",
        ).listen((rows) {
          if (!mounted) return;
          final map = <String, Set<String>>{};
          for (final r in rows) {
            final hId = (r['habit_id'] as String? ?? '').toLowerCase().trim();
            final lDate = (r['log_date'] as String? ?? '').trim();
            if (hId.isNotEmpty && lDate.isNotEmpty) {
              map.putIfAbsent(lDate, () => <String>{}).add(hId);
              if (hId.startsWith('prayer_')) {
                map[lDate]!.add(hId.replaceFirst('prayer_', ''));
              }
            }
          }
          setState(() => _completedLogsByDate = map);
        }, onError: (_) {});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _taskSub?.cancel();
    _habitSub?.cancel();
    _prayerSub?.cancel();
    _habitLogsSub?.cancel();
    _verticalScrollController.dispose();
    super.dispose();
  }

  List<CalendarHabitBlock> get _dailyHabitBlocks =>
      CalendarScheduler.buildDailyHabitBlocks(_habits);

  List<Prayer> get _effectivePrayers =>
      _prayers.isNotEmpty ? _prayers : PrayerRepository.defaultPrayers();

  List<CalendarPrayerBlock> get _dailyPrayerBlocks =>
      CalendarScheduler.buildDailyPrayerBlocks(_effectivePrayers);

  List<Task> _computeLayoutForDay(
    String dateStr,
    List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks,
  ) {
    final dayTasks = CalendarScheduler.expandTasksForDate(
      _tasks,
      dateStr,
      includeCompleted: _showCompletedTasks,
    );
    if (dayTasks.isEmpty) return const [];

    final allHaveDueTime = dayTasks.every((t) =>
        t.dueTime != null && t.dueTime!.trim().isNotEmpty);

    if (allHaveDueTime) {
      final sorted = [...dayTasks]..sort((a, b) {
          final timeA = CalendarScheduler.parseTimeToMinutes(a.dueTime) ??
              CalendarScheduler.defaultDayStartMinutes;
          final timeB = CalendarScheduler.parseTimeToMinutes(b.dueTime) ??
              CalendarScheduler.defaultDayStartMinutes;
          if (timeA != timeB) return timeA.compareTo(timeB);
          final prioA = CalendarScheduler.priorityRank(a.priority);
          final prioB = CalendarScheduler.priorityRank(b.priority);
          if (prioA != prioB) return prioA.compareTo(prioB);
          return a.id.compareTo(b.id);
        });
      return sorted;
    }

    if (_manuallyOrderedDays.contains(dateStr)) {
      final ordered = CalendarScheduler.orderByCurrentSchedule(dayTasks);
      return CalendarScheduler.packTasksPreservingExplicitTimes(
        dateStr: dateStr,
        dayTasks: ordered,
        habitBlocks: habitBlocks,
        prayerBlocks: prayerBlocks,
        includeCompleted: _showCompletedTasks,
      );
    }

    return CalendarScheduler.packTasksPreservingExplicitTimes(
      dateStr: dateStr,
      dayTasks: dayTasks,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      includeCompleted: _showCompletedTasks,
    );
  }

  Future<void> _persistUpdatedTasks(List<Task> updatedTasks) async {
    if (updatedTasks.isEmpty) return;
    if (widget.taskRepo == null && !isDatabaseInitialized) return;
    final repo = widget.taskRepo ?? TaskRepository();
    for (final updated in updatedTasks) {
      try {
        await repo.updateTask(updated);
      } catch (_) {}
    }
  }

  void _applyUpdatedTasksLocally(List<Task> updatedTasks) {
    if (updatedTasks.isEmpty) return;
    final byId = {for (final t in updatedTasks) t.id: t};
    setState(() {
      _tasks = [
        for (final t in _tasks) byId[t.id] ?? t,
      ];
    });
  }

  Future<void> _handleSameDayReorder(Task movedTask, int targetDropMinute) async {
    final dateStr = movedTask.dueDate;
    if (dateStr == null || dateStr.isEmpty) return;

    final habitBlocks = _dailyHabitBlocks;
    final prayerBlocks = _dailyPrayerBlocks;
    final currentLayout = _computeLayoutForDay(dateStr, habitBlocks, prayerBlocks);
    final reordered = CalendarScheduler.reorderTaskWithinSameDay(
      dateStr: dateStr,
      currentDayTasks: currentLayout,
      movedTaskId: movedTask.id,
      targetDropMinute: targetDropMinute,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      includeCompleted: _showCompletedTasks,
    );

    _manuallyOrderedDays.add(dateStr);
    _applyUpdatedTasksLocally(reordered);
    await _persistUpdatedTasks(reordered);
  }

  Future<void> _handleCrossDayMove(Task movedTask, String targetDateStr, [int? targetDropMinute]) async {
    final sourceDateStr = movedTask.dueDate;
    final habitBlocks = _dailyHabitBlocks;
    final prayerBlocks = _dailyPrayerBlocks;

    if (sourceDateStr != null && sourceDateStr.isNotEmpty) {
      _manuallyOrderedDays.remove(sourceDateStr);
    }
    _manuallyOrderedDays.remove(targetDateStr);

    final updated = CalendarScheduler.moveTaskToDay(
      allTasks: _tasks,
      movedTaskId: movedTask.id,
      targetDateStr: targetDateStr,
      targetDropMinute: targetDropMinute,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      includeCompleted: _showCompletedTasks,
    );

    _applyUpdatedTasksLocally(updated);
    await _persistUpdatedTasks(updated);
  }

  Future<void> _handleResizeCommit(
    Task task,
    String dateStr,
    int newDurationMin,
  ) async {
    final habitBlocks = _dailyHabitBlocks;
    final prayerBlocks = _dailyPrayerBlocks;
    _manuallyOrderedDays.remove(dateStr);

    final rawDayTasks = _tasks
        .where((t) => t.dueDate == dateStr && (_showCompletedTasks || !t.isCompleted))
        .toList();
    final repacked = CalendarScheduler.resizeTaskDuration(
      dateStr: dateStr,
      dayTasks: rawDayTasks,
      resizedTaskId: task.id,
      newEstimateMin: newDurationMin,
      habitBlocks: habitBlocks,
      prayerBlocks: prayerBlocks,
      includeCompleted: _showCompletedTasks,
    );

    _applyUpdatedTasksLocally(repacked);
    await _persistUpdatedTasks(repacked);
  }

  void _setSelectedDate(int year, int month, int day) {
    final maxDays = DateTime(year, month + 1, 0).day;
    final clampedDay = day.clamp(1, maxDays);
    setState(() {
      _selectedDate = DateTime(year, month, clampedDay);
    });
  }

  void _shiftWeek(int deltaDays) {
    setState(() {
      _selectedDate = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day + deltaDays,
      );
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _setZoomLevel(CalendarZoomLevel newLevel) {
    if (_zoomLevel == newLevel) return;
    final oldHeight = _zoomLevel.hourHeight * 24;
    final newHeight = newLevel.hourHeight * 24;
    final currentOffset = _verticalScrollController.hasClients
        ? _verticalScrollController.offset
        : 6.5 * _zoomLevel.hourHeight;
    final ratio = oldHeight > 0 ? (currentOffset / oldHeight) : 0.25;

    setState(() {
      _zoomLevel = newLevel;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_verticalScrollController.hasClients) {
        final targetOffset = (ratio * newHeight).clamp(
          0.0,
          _verticalScrollController.position.maxScrollExtent,
        );
        _verticalScrollController.jumpTo(targetOffset);
      }
    });
  }

  void _zoomStep(int delta) {
    const levels = CalendarZoomLevel.values;
    final currentIndex = levels.indexOf(_zoomLevel);
    final targetIndex = (currentIndex + delta).clamp(0, levels.length - 1);
    if (targetIndex != currentIndex) {
      _setZoomLevel(levels[targetIndex]);
    }
  }

  Future<void> _openCreateTaskDialog({DateTime? date, String? time}) async {
    final targetDate = date ?? _selectedDate;
    final targetDateStr = CalendarScheduler.formatDate(targetDate);
    final now = DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;
    final initialTime = time ??
        (isToday ? CalendarScheduler.defaultTodayTaskTimeString(now) : null);

    await QuickTaskDialog.show(
      context,
      initialDate: targetDate,
      initialTime: initialTime,
      onTaskCreated: () {
        if (!mounted) return;
        setState(() {
          _manuallyOrderedDays.remove(targetDateStr);
        });
      },
    );
  }

  void _openTaskPreview(Task task) {
    DesktopTaskPreviewDialog.show(
      context,
      initialTask: task,
      onTaskUpdated: (updated) {
        if (!mounted) return;
        final affectedDate = updated.dueDate;
        if (affectedDate != null && affectedDate.isNotEmpty) {
          _manuallyOrderedDays.remove(affectedDate);
        }
        _applyUpdatedTasksLocally([updated]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekDays =
        CalendarScheduler.buildWeekDays(_selectedDate, _startWeekday);
    final habitBlocks = _dailyHabitBlocks;
    final prayerBlocks = _dailyPrayerBlocks;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, weekDays),
          const SizedBox(height: 12),
          Expanded(
            child: DesktopCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildWeekDayHeaders(context, weekDays),
                  const Divider(height: 1, color: AxisColors.borderSubtle),
                  Expanded(
                    child: _buildScrollableTimeGrid(
                      context,
                      weekDays,
                      habitBlocks,
                      prayerBlocks,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<DateTime> weekDays) {
    final isAr = context.isArabic;
    final l10n = context.l10n;
    final firstDay = weekDays.first;
    final lastDay = weekDays.last;
    final rangeLabel =
        '${_monthShortName(firstDay.month, isAr)} ${firstDay.day} – '
        '${_monthShortName(lastDay.month, isAr)} ${lastDay.day}, ${lastDay.year}';

    final currentYear = DateTime.now().year;
    final minYear = math.min(currentYear - 5, _selectedDate.year - 1);
    final maxYear = math.max(currentYear + 5, _selectedDate.year + 1);
    final years = [for (var y = minYear; y <= maxYear; y++) y];
    final daysInMonth =
        DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
    final days = [for (var d = 1; d <= daysInMonth; d++) d];

    return DesktopCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AxisColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.calendar_view_week_rounded,
                  color: AxisColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.calendar,
                    style: AxisFonts.spaceGrotesk(
                      color: AxisColors.textHigh,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    rangeLabel,
                    style: AxisFonts.jetBrainsMono(
                      color: AxisColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('calendar_prev_week_button'),
                tooltip: isAr ? 'الأسبوع السابق' : 'Previous week',
                onPressed: () => _shiftWeek(-7),
                icon: const Icon(
                  Icons.chevron_left_rounded,
                  color: AxisColors.textHigh,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
              GhostButton(
                key: const ValueKey('calendar_today_button'),
                label: isAr ? 'اليوم' : 'Today',
                height: 32,
                onPressed: _goToToday,
              ),
              IconButton(
                key: const ValueKey('calendar_next_week_button'),
                tooltip: isAr ? 'الأسبوع التالي' : 'Next week',
                onPressed: () => _shiftWeek(7),
                icon: const Icon(
                  Icons.chevron_right_rounded,
                  color: AxisColors.textHigh,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
              ),
              _buildDropdownChip<int>(
                key: const ValueKey('calendar_start_day_selector'),
                label: isAr ? 'بداية الأسبوع' : 'Start',
                value: _startWeekday,
                items: [
                  for (final w in [
                    DateTime.sunday,
                    DateTime.monday,
                    DateTime.tuesday,
                    DateTime.wednesday,
                    DateTime.thursday,
                    DateTime.friday,
                    DateTime.saturday,
                  ])
                    DropdownMenuItem<int>(
                      value: w,
                      child: Text(_weekdayShortName(w, isAr)),
                    ),
                ],
                onChanged: (w) {
                  if (w != null) setState(() => _startWeekday = w);
                },
              ),
              _buildDropdownChip<int>(
                key: const ValueKey('calendar_day_selector'),
                label: isAr ? 'اليوم' : 'Day',
                value: _selectedDate.day.clamp(1, daysInMonth),
                items: [
                  for (final d in days)
                    DropdownMenuItem<int>(
                      value: d,
                      child: Text('$d'),
                    ),
                ],
                onChanged: (d) {
                  if (d != null) {
                    _setSelectedDate(_selectedDate.year, _selectedDate.month, d);
                  }
                },
              ),
              _buildDropdownChip<int>(
                key: const ValueKey('calendar_month_selector'),
                label: isAr ? 'الشهر' : 'Month',
                value: _selectedDate.month,
                items: [
                  for (var m = 1; m <= 12; m++)
                    DropdownMenuItem<int>(
                      value: m,
                      child: Text(_monthShortName(m, isAr)),
                    ),
                ],
                onChanged: (m) {
                  if (m != null) {
                    _setSelectedDate(_selectedDate.year, m, _selectedDate.day);
                  }
                },
              ),
              _buildDropdownChip<int>(
                key: const ValueKey('calendar_year_selector'),
                label: isAr ? 'السنة' : 'Year',
                value: _selectedDate.year,
                items: [
                  for (final y in years)
                    DropdownMenuItem<int>(
                      value: y,
                      child: Text('$y'),
                    ),
                ],
                onChanged: (y) {
                  if (y != null) {
                    _setSelectedDate(y, _selectedDate.month, _selectedDate.day);
                  }
                },
              ),
              // Dynamic Zoom Controls: 1h -> 30m -> 15m
              _buildZoomControls(isAr),
              // Show / Hide Completed Tasks toggle
              _buildCompletedToggle(isAr),
              AccentButton(
                key: const ValueKey('calendar_new_task_button'),
                label: l10n.newTask,
                icon: Icons.add_rounded,
                height: 32,
                onPressed: _openCreateTaskDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedToggle(bool isAr) {
    return Tooltip(
      message: isAr
          ? (_showCompletedTasks ? 'إخفاء المهام المكتملة' : 'إظهار المهام المكتملة')
          : (_showCompletedTasks ? 'Hide Completed Tasks' : 'Show Completed Tasks'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('calendar_toggle_completed_button'),
          onTap: () {
            setState(() {
              _showCompletedTasks = !_showCompletedTasks;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: _showCompletedTasks
                  ? AxisColors.tertiary.withValues(alpha: 0.15)
                  : AxisColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _showCompletedTasks
                    ? AxisColors.tertiary.withValues(alpha: 0.5)
                    : AxisColors.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showCompletedTasks
                      ? Icons.check_circle_rounded
                      : Icons.check_circle_outline_rounded,
                  size: 15,
                  color: _showCompletedTasks
                      ? AxisColors.tertiary
                      : AxisColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'المكتملة' : 'Completed',
                  style: AxisFonts.spaceGrotesk(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _showCompletedTasks
                        ? AxisColors.tertiary
                        : AxisColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomControls(bool isAr) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: AxisColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: const ValueKey('calendar_zoom_out_button'),
            tooltip: isAr ? 'تصغير الخطوط' : 'Zoom out lines',
            icon: const Icon(Icons.remove_rounded, size: 16),
            color: _zoomLevel == CalendarZoomLevel.hour
                ? AxisColors.textDim.withValues(alpha: 0.35)
                : AxisColors.textHigh,
            onPressed: _zoomLevel == CalendarZoomLevel.hour
                ? null
                : () => _zoomStep(-1),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<CalendarZoomLevel>(
                key: const ValueKey('calendar_zoom_selector'),
                value: _zoomLevel,
                items: [
                  DropdownMenuItem(
                    value: CalendarZoomLevel.hour,
                    child: Text(
                      isAr ? '1 ساعة' : '1 Hour',
                      style: AxisFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: CalendarZoomLevel.halfHour,
                    child: Text(
                      isAr ? '30 دقيقة' : '30 Min',
                      style: AxisFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: CalendarZoomLevel.quarterHour,
                    child: Text(
                      isAr ? '15 دقيقة' : '15 Min',
                      style: AxisFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                onChanged: (lvl) {
                  if (lvl != null) _setZoomLevel(lvl);
                },
                isDense: true,
                dropdownColor: AxisColors.surfaceHigh,
                iconEnabledColor: AxisColors.textMuted,
                style: AxisFonts.jetBrainsMono(
                  color: AxisColors.textHigh,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            key: const ValueKey('calendar_zoom_in_button'),
            tooltip: isAr ? 'تكبير الخطوط' : 'Zoom in lines',
            icon: const Icon(Icons.add_rounded, size: 16),
            color: _zoomLevel == CalendarZoomLevel.quarterHour
                ? AxisColors.textDim.withValues(alpha: 0.35)
                : AxisColors.textHigh,
            onPressed: _zoomLevel == CalendarZoomLevel.quarterHour
                ? null
                : () => _zoomStep(1),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownChip<T>({
    required Key key,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AxisColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: AxisColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              key: key,
              value: value,
              items: items,
              onChanged: onChanged,
              isDense: true,
              dropdownColor: AxisColors.surfaceHigh,
              iconEnabledColor: AxisColors.textMuted,
              style: AxisFonts.jetBrainsMono(
                color: AxisColors.textHigh,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekDayHeaders(BuildContext context, List<DateTime> weekDays) {
    final isAr = context.isArabic;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Container(
      height: 54,
      color: AxisColors.surfaceHigh.withValues(alpha: 0.45),
      child: Row(
        children: [
          SizedBox(
            width: _timeGutterWidth,
            child: Center(
              child: Text(
                isAr ? 'الوقت' : 'TIME',
                style: AxisFonts.jetBrainsMono(
                  color: AxisColors.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                for (final day in weekDays)
                  Expanded(
                    child: _buildSingleDayHeader(
                      day: day,
                      isToday: day.year == today.year &&
                          day.month == today.month &&
                          day.day == today.day,
                      isSelected: day.year == _selectedDate.year &&
                          day.month == _selectedDate.month &&
                          day.day == _selectedDate.day,
                      isAr: isAr,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleDayHeader({
    required DateTime day,
    required bool isToday,
    required bool isSelected,
    required bool isAr,
  }) {
    final dateStr = CalendarScheduler.formatDate(day);
    return InkWell(
      key: ValueKey('calendar_day_header_$dateStr'),
      onTap: () => _setSelectedDate(day.year, day.month, day.day),
      child: Container(
        decoration: BoxDecoration(
          border: const Border(
            left: BorderSide(color: AxisColors.borderSubtle, width: 1),
          ),
          color: isSelected
              ? AxisColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _weekdayShortName(day.weekday, isAr).toUpperCase(),
              style: AxisFonts.jetBrainsMono(
                color: isToday ? AxisColors.primary : AxisColors.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isToday ? AxisColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${day.day}',
                style: AxisFonts.spaceGrotesk(
                  color: isToday ? Colors.white : AxisColors.textHigh,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableTimeGrid(
    BuildContext context,
    List<DateTime> weekDays,
    List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks,
  ) {
    final totalHeight = 24 * _hourHeight;

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent &&
            HardwareKeyboard.instance.isControlPressed) {
          if (pointerSignal.scrollDelta.dy < 0) {
            _zoomStep(1); // Zoom in
          } else if (pointerSignal.scrollDelta.dy > 0) {
            _zoomStep(-1); // Zoom out
          }
        }
      },
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        child: SizedBox(
          height: totalHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeGutter(totalHeight),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < weekDays.length; i++)
                      Expanded(
                        child: _buildDayColumn(
                          dayIndex: i,
                          day: weekDays[i],
                          habitBlocks: habitBlocks,
                          prayerBlocks: prayerBlocks,
                          totalHeight: totalHeight,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeGutter(double totalHeight) {
    final step = _zoomLevel.intervalMinutes;
    final totalSlots = (24 * 60) ~/ step;

    return SizedBox(
      width: _timeGutterWidth,
      height: totalHeight,
      child: Stack(
        children: [
          for (var i = 0; i < totalSlots; i++)
            Positioned(
              top: (i * step / 60.0) * _hourHeight + 3,
              left: 0,
              right: 8,
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  CalendarScheduler.formatMinutes(i * step),
                  style: AxisFonts.jetBrainsMono(
                    color: (i * step) % 60 == 0
                        ? AxisColors.textDim
                        : AxisColors.textDim.withValues(alpha: 0.65),
                    fontSize: (i * step) % 60 == 0 ? 10 : 8.5,
                    fontWeight: (i * step) % 60 == 0
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayColumn({
    required int dayIndex,
    required DateTime day,
    required List<CalendarHabitBlock> habitBlocks,
    required List<CalendarPrayerBlock> prayerBlocks,
    required double totalHeight,
  }) {
    final dateStr = CalendarScheduler.formatDate(day);
    final dayTasks = _computeLayoutForDay(dateStr, habitBlocks, prayerBlocks);
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final step = _zoomLevel.intervalMinutes;
    final totalSlots = (24 * 60) ~/ step;

    return DragTarget<Task>(
      key: ValueKey('calendar_day_column_$dateStr'),
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final colCtx = _dayColumnKeys[dayIndex].currentContext;
        final box = colCtx?.findRenderObject() as RenderBox?;
        var dropMinute = CalendarScheduler.defaultDayStartMinutes;
        if (box != null) {
          final localPos = box.globalToLocal(details.offset);
          dropMinute = ((localPos.dy / _hourHeight) * 60)
              .round()
              .clamp(0, 23 * 60 + 55);
        }
        final task = details.data;
        if (task.dueDate == dateStr) {
          _handleSameDayReorder(task, dropMinute);
        } else {
          _handleCrossDayMove(task, dateStr);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHoveredDrop = candidateData.isNotEmpty;
        return Container(
          key: _dayColumnKeys[dayIndex],
          height: totalHeight,
          decoration: BoxDecoration(
            border: const Border(
              left: BorderSide(color: AxisColors.borderSubtle, width: 1),
            ),
            color: isHoveredDrop
                ? AxisColors.primary.withValues(alpha: 0.06)
                : (isToday
                    ? AxisColors.primary.withValues(alpha: 0.02)
                    : Colors.transparent),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Double-tap empty calendar slot to create task at clicked time
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTapDown: (tapDetails) {
                    final clickedMin = ((tapDetails.localPosition.dy / _hourHeight) * 60)
                        .round()
                        .clamp(0, 23 * 60 + 45);
                    final snapped = (clickedMin ~/ 15) * 15;
                    final timeStr = CalendarScheduler.formatMinutes(snapped);
                    _openCreateTaskDialog(date: day, time: timeStr);
                  },
                  child: const SizedBox.expand(),
                ),
              ),
              // Dynamic grid lines based on zoom level (1h -> 30m -> 15m)
              for (var i = 0; i < totalSlots; i++)
                Positioned(
                  top: (i * step / 60.0) * _hourHeight,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    color: (i * step) % 60 == 0
                        ? AxisColors.borderSubtle.withValues(alpha: 0.5)
                        : ((i * step) % 30 == 0
                            ? AxisColors.borderSubtle.withValues(alpha: 0.28)
                            : AxisColors.borderSubtle.withValues(alpha: 0.16)),
                  ),
                ),
              // Islamic Daily Prayers (fixed 15 min, cannot be changed)
              for (final prayer in prayerBlocks)
                _buildPrayerBlockWidget(dateStr, prayer),
              // Protected Daily Habit Blocks (fixed 15 min, cannot be changed, weekly excluded)
              for (final block in habitBlocks)
                _buildHabitBlockWidget(dateStr, block),
              // Priority-sorted or manually-ordered Task Blocks
              for (final task in dayTasks)
                _buildTaskBlockWidget(dateStr, task),
            ],
          ),
        );
      },
    );
  }

  bool _isPrayerDone(String dateStr, CalendarPrayerBlock block) {
    final code = block.prayer.prayerCode.toLowerCase().trim();
    final pId = block.prayer.id.toLowerCase().trim();
    final dateLogs = _completedLogsByDate[dateStr];
    if (dateLogs != null) {
      if (dateLogs.contains(code) ||
          dateLogs.contains('prayer_$code') ||
          dateLogs.contains(pId)) {
        return true;
      }
    }
    final todayStr = CalendarScheduler.formatDate(DateTime.now());
    if (dateStr == todayStr && block.prayer.isDone) {
      return true;
    }
    return false;
  }

  bool _isHabitDone(String dateStr, CalendarHabitBlock block) {
    final hId = block.habit.id.toLowerCase().trim();
    final dateLogs = _completedLogsByDate[dateStr];
    if (dateLogs != null && (dateLogs.contains(hId) || dateLogs.contains('habit_$hId'))) {
      return true;
    }
    return false;
  }

  Future<void> _togglePrayerForDate(String dateStr, CalendarPrayerBlock block) async {
    final currentlyDone = _isPrayerDone(dateStr, block);
    final nextDone = !currentlyDone;
    setState(() {
      final code = block.prayer.prayerCode.toLowerCase().trim();
      final set = _completedLogsByDate.putIfAbsent(dateStr, () => <String>{});
      if (nextDone) {
        set.add(code);
        set.add('prayer_$code');
      } else {
        set.remove(code);
        set.remove('prayer_$code');
      }
    });
    try {
      await PrayerCompletionHandler().togglePrayer(
        prayerId: block.prayer.prayerCode,
        isDone: nextDone,
        date: dateStr,
      );
    } catch (_) {}
  }

  Future<void> _toggleHabitForDate(String dateStr, CalendarHabitBlock block) async {
    final currentlyDone = _isHabitDone(dateStr, block);
    final nextDone = !currentlyDone;
    setState(() {
      final hId = block.habit.id.toLowerCase().trim();
      final set = _completedLogsByDate.putIfAbsent(dateStr, () => <String>{});
      if (nextDone) {
        set.add(hId);
      } else {
        set.remove(hId);
      }
    });
    try {
      await HabitRepository().toggleHabit(
        block.habit.id,
        nextDone,
        dateStr,
      );
    } catch (_) {}
  }

  Widget _buildPrayerBlockWidget(String dateStr, CalendarPrayerBlock block) {
    final top = (block.startMinute / 60.0) * _hourHeight;
    final height = math.max((block.durationMin / 60.0) * _hourHeight, 22.0);
    final prayerColor = _prayerColor(block.prayer.prayerCode);
    final isDone = _isPrayerDone(dateStr, block);

    return Positioned(
      top: top,
      left: 3,
      right: 3,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _togglePrayerForDate(dateStr, block),
        child: Container(
          key: ValueKey('calendar_prayer_${dateStr}_${block.prayer.prayerCode}'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDone
                ? prayerColor.withValues(alpha: 0.08)
                : prayerColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDone
                  ? prayerColor.withValues(alpha: 0.35)
                  : prayerColor.withValues(alpha: 0.65),
              width: 1,
            ),
          ),
          child: ClipRect(
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle_rounded : _prayerIcon(block.prayer.prayerCode),
                  size: 12,
                  color: isDone ? AxisColors.textDim : prayerColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    height >= 34
                        ? '${block.prayer.name} (${block.startTimeFormatted})'
                        : block.prayer.name,
                    style: TextStyle(
                      color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: prayerColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '15m',
                    style: TextStyle(
                      color: prayerColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHabitBlockWidget(String dateStr, CalendarHabitBlock block) {
    final top = (block.startMinute / 60.0) * _hourHeight;
    final height = math.max((block.durationMin / 60.0) * _hourHeight, 22.0);
    const habitColor = Color(0xFF3B82F6); // Dedicated Blue color for habits
    final isDone = _isHabitDone(dateStr, block);

    return Positioned(
      top: top,
      left: 3,
      right: 3,
      height: height,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _toggleHabitForDate(dateStr, block),
        child: Container(
          key: ValueKey('calendar_habit_${dateStr}_${block.habit.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDone
                ? habitColor.withValues(alpha: 0.08)
                : habitColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDone
                  ? habitColor.withValues(alpha: 0.35)
                  : habitColor.withValues(alpha: 0.55),
              width: 1,
            ),
          ),
          child: ClipRect(
            child: Row(
              children: [
                Icon(
                  isDone ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                  size: 11,
                  color: isDone ? AxisColors.textDim : habitColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    height >= 34
                        ? '${block.habit.name} (${block.startTimeFormatted})'
                        : block.habit.name,
                    style: TextStyle(
                      color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: habitColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '15m',
                    style: TextStyle(
                      color: isDone ? AxisColors.textDim : habitColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskBlockWidget(String dateStr, Task task) {
    final startMin = CalendarScheduler.parseTimeToMinutes(task.dueTime) ??
        CalendarScheduler.defaultDayStartMinutes;
    final isResizing =
        _resizingTaskId == task.id && _resizingPreviewDurationMin != null;
    final duration = isResizing
        ? _resizingPreviewDurationMin!
        : CalendarScheduler.sanitizeDuration(task.estimateMin);
    final top = (startMin / 60.0) * _hourHeight;
    final height = math.max((duration / 60.0) * _hourHeight, 22.0);
    final isDone = task.isCompleted;
    final pColor = isDone ? AxisColors.tertiary : _priorityColor(task.priority);
    final pLabel = _priorityLabel(task.priority);
    final showCompact = height < 44;

    final blockCard = Container(
      decoration: BoxDecoration(
        color: isDone
            ? AxisColors.tertiary.withValues(alpha: 0.10)
            : pColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDone
              ? AxisColors.tertiary.withValues(alpha: 0.40)
              : pColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: isDone ? AxisColors.tertiary : pColor),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: showCompact ? 2 : 4,
                ),
                child: showCompact
                    ? Row(
                        children: [
                          if (isDone) ...[
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AxisColors.tertiary,
                              size: 11,
                            ),
                            const SizedBox(width: 3),
                          ],
                          if (task.isRecurring) ...[
                            Icon(
                              Icons.repeat_rounded,
                              color: isDone ? AxisColors.tertiary : pColor,
                              size: 10,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            pLabel,
                            style: AxisFonts.jetBrainsMono(
                              color: isDone ? AxisColors.tertiary : pColor,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                color: isDone ? AxisColors.textMuted : AxisColors.textHigh,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                decorationColor: AxisColors.textDim,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${duration}m',
                            style: AxisFonts.jetBrainsMono(
                              color: AxisColors.textMuted,
                              fontSize: 9.5,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              if (isDone) ...[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AxisColors.tertiary,
                                  size: 12,
                                ),
                                const SizedBox(width: 3),
                              ],
                              if (task.isRecurring) ...[
                                Icon(
                                  Icons.repeat_rounded,
                                  color: isDone ? AxisColors.tertiary : pColor,
                                  size: 11,
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                pLabel,
                                style: AxisFonts.jetBrainsMono(
                                  color: isDone ? AxisColors.tertiary : pColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${CalendarScheduler.formatMinutes(startMin)} · ${duration}m',
                                  style: AxisFonts.jetBrainsMono(
                                    color: AxisColors.textMuted,
                                    fontSize: 9.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Flexible(
                            child: Text(
                              task.title,
                              style: TextStyle(
                                color: isDone ? AxisColors.textMuted : AxisColors.textHigh,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                                decorationColor: AxisColors.textDim,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );

    if (task.isProjectedOccurrence) {
      return Positioned(
        key: ValueKey('calendar_task_${task.id}'),
        top: top,
        left: 3,
        right: 3,
        height: height,
        child: GestureDetector(
          onTap: () => _openTaskPreview(task),
          child: blockCard,
        ),
      );
    }

    return Positioned(
      key: ValueKey('calendar_task_${task.id}'),
      top: top,
      left: 3,
      right: 3,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Draggable<Task>(
              data: task,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: Material(
                color: Colors.transparent,
                child: Container(
                  width: 150,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: pColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.45),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDone) ...[
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AxisColors.tertiary,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        pLabel,
                        style: AxisFonts.jetBrainsMono(
                          color: pColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            color: isDone ? AxisColors.textMuted : AxisColors.textHigh,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            decorationColor: AxisColors.textDim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              childWhenDragging: Opacity(opacity: 0.35, child: blockCard),
              child: GestureDetector(
                onTap: () => _openTaskPreview(task),
                child: blockCard,
              ),
            ),
          ),
          // Bottom resize handle sits outside/above Draggable so vertical resize
          // drags update task duration cleanly without starting a move drag.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 8,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeUpDown,
              child: GestureDetector(
                key: ValueKey('calendar_task_resize_${task.id}'),
                behavior: HitTestBehavior.opaque,
                dragStartBehavior: DragStartBehavior.down,
                onVerticalDragStart: (details) {
                  setState(() {
                    _resizingTaskId = task.id;
                    _resizingBaseDurationMin =
                        CalendarScheduler.sanitizeDuration(task.estimateMin);
                    _resizingStartGlobalDy = details.globalPosition.dy;
                    _resizingPreviewDurationMin = _resizingBaseDurationMin;
                  });
                },
                onVerticalDragUpdate: (details) {
                  final totalDeltaDy =
                      details.globalPosition.dy - _resizingStartGlobalDy;
                  final deltaMin =
                      ((totalDeltaDy / _hourHeight) * 60).round();
                  final nextDuration = CalendarScheduler.snapDurationTo5Min(
                    _resizingBaseDurationMin + deltaMin,
                  );
                  if (nextDuration != _resizingPreviewDurationMin) {
                    setState(() => _resizingPreviewDurationMin = nextDuration);
                  }
                },
                onVerticalDragEnd: (_) {
                  final committed = _resizingPreviewDurationMin ??
                      _resizingBaseDurationMin;
                  setState(() {
                    _resizingTaskId = null;
                    _resizingPreviewDurationMin = null;
                    _resizingStartGlobalDy = 0.0;
                  });
                  _handleResizeCommit(task, dateStr, committed);
                },
                onVerticalDragCancel: () {
                  setState(() {
                    _resizingTaskId = null;
                    _resizingPreviewDurationMin = null;
                    _resizingStartGlobalDy = 0.0;
                  });
                },
                child: Center(
                  child: Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: pColor.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _prayerColor(String code) {
    return switch (code.toLowerCase().trim()) {
      'fajr' => const Color(0xFF06B6D4), // Dawn Cyan
      'dhuhr' => const Color(0xFFF59E0B), // Solar Amber
      'asr' => const Color(0xFFF97316), // Sunset Orange
      'maghrib' => const Color(0xFFEF4444), // Crimson Dusk
      'isha' => const Color(0xFF8B5CF6), // Night Violet
      _ => const Color(0xFF06B6D4),
    };
  }

  static IconData _prayerIcon(String code) {
    return switch (code.toLowerCase().trim()) {
      'fajr' => Icons.wb_twilight_rounded,
      'dhuhr' => Icons.wb_sunny_rounded,
      'asr' => Icons.wb_cloudy_rounded,
      'maghrib' => Icons.nights_stay_rounded,
      'isha' => Icons.bedtime_rounded,
      _ => Icons.mosque_rounded,
    };
  }

  static Color _priorityColor(int? priority) {
    return switch (priority) {
      1 => AxisColors.priorityHigh,
      2 => AxisColors.priorityMed,
      3 => AxisColors.priorityLow,
      _ => AxisColors.primary,
    };
  }

  static String _priorityLabel(int? priority) {
    return switch (priority) {
      1 => 'P1',
      2 => 'P2',
      3 => 'P3',
      _ => 'P-',
    };
  }

  static String _weekdayShortName(int weekday, bool isArabic) {
    if (isArabic) {
      return const [
        'إثنين',
        'ثلاثاء',
        'أربعاء',
        'خميس',
        'جمعة',
        'سبت',
        'أحد',
      ][(weekday - 1).clamp(0, 6)];
    }
    return const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][(weekday - 1).clamp(0, 6)];
  }

  static String _monthShortName(int month, bool isArabic) {
    if (isArabic) {
      return const [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ][(month - 1).clamp(0, 11)];
    }
    return const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][(month - 1).clamp(0, 11)];
  }
}
