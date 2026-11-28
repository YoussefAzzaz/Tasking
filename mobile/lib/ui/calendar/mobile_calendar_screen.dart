import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayers/prayer_model.dart';
import 'package:axis/data/prayers/prayer_repository.dart';
import 'package:axis/data/prayers/prayer_completion_handler.dart';
import 'package:axis/data/powersync_db.dart' show isDatabaseInitialized, db;
import 'package:axis/domain/calendar_scheduler.dart';
import 'package:axis/domain/recurrence_engine.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';

enum MobileCalendarViewMode {
  day,
  schedule,
}

/// Cyber-minimalist mobile calendar featuring an interactive week strip,
/// a 24-hour Day Time Grid with live time indicator, an Agenda stream,
/// and support for completed tasks, habits, and Islamic prayers.
class MobileCalendarScreen extends StatefulWidget {
  const MobileCalendarScreen({
    super.key,
    this.initialTasks,
    this.initialHabits,
    this.initialPrayers,
    this.initialSelectedDate,
    this.initialCompletedLogs,
    this.taskRepo,
    this.habitRepo,
    this.prayerRepo,
  });

  final List<Task>? initialTasks;
  final List<Habit>? initialHabits;
  final List<Prayer>? initialPrayers;
  final DateTime? initialSelectedDate;
  final Map<String, Set<String>>? initialCompletedLogs;
  final TaskRepository? taskRepo;
  final HabitRepository? habitRepo;
  final PrayerRepository? prayerRepo;

  @override
  State<MobileCalendarScreen> createState() => _MobileCalendarScreenState();
}

class _MobileCalendarScreenState extends State<MobileCalendarScreen> {
  late DateTime _selectedDate;
  late List<Task> _tasks;
  late List<Habit> _habits;
  late List<Prayer> _prayers;
  late final ScrollController _gridScrollController;

  MobileCalendarViewMode _viewMode = MobileCalendarViewMode.day;
  bool _showCompletedTasks = true;
  static const double _hourHeight = 64.0;

  StreamSubscription<List<Task>>? _taskSub;
  StreamSubscription<List<Habit>>? _habitSub;
  StreamSubscription<List<Prayer>>? _prayerSub;
  StreamSubscription<List<Map<String, dynamic>>>? _habitLogsSub;

  Map<String, Set<String>> _completedLogsByDate = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialSelectedDate ?? DateTime.now();
    _tasks = List<Task>.from(widget.initialTasks ?? const []);
    _habits = List<Habit>.from(widget.initialHabits ?? const []);
    _prayers = List<Prayer>.from(widget.initialPrayers ?? const []);
    if (widget.initialCompletedLogs != null) {
      _completedLogsByDate = Map.from(widget.initialCompletedLogs!);
    }

    // Auto-scroll to morning (around 07:00) or current hour
    final currentHour = DateTime.now().hour;
    final initialHour = math.max(6, currentHour - 1);
    _gridScrollController = ScrollController(
      initialScrollOffset: initialHour * _hourHeight,
    );

    _initStreams();
  }

  void _initStreams() {
    if (widget.initialTasks == null) {
      final repo = widget.taskRepo ?? TaskRepository();
      try {
        _taskSub = repo.watchTasks().listen((tasks) {
          if (!mounted) return;
          setState(() => _tasks = tasks);
        });
      } catch (_) {}
    }

    if (widget.initialHabits == null) {
      final repo = widget.habitRepo ?? HabitRepository();
      try {
        _habitSub = repo.watchHabits().listen((habits) {
          if (!mounted) return;
          setState(() => _habits = habits);
        });
      } catch (_) {}
    }

    if (widget.initialPrayers == null) {
      final repo = widget.prayerRepo ?? PrayerRepository();
      try {
        _prayerSub = repo.watchPrayers().listen((prayers) {
          if (!mounted) return;
          setState(() => _prayers = prayers);
        });
      } catch (_) {}
    }

    if (widget.initialCompletedLogs == null && isDatabaseInitialized) {
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
    _gridScrollController.dispose();
    super.dispose();
  }

  List<CalendarHabitBlock> get _dailyHabitBlocks =>
      CalendarScheduler.buildDailyHabitBlocks(_habits);

  List<Prayer> get _effectivePrayers =>
      _prayers.isNotEmpty ? _prayers : PrayerRepository.defaultPrayers();

  List<CalendarPrayerBlock> get _dailyPrayerBlocks =>
      CalendarScheduler.buildDailyPrayerBlocks(_effectivePrayers);

  List<Task> _tasksForDay(String dateStr) {
    final raw = CalendarScheduler.expandTasksForDate(
      _tasks,
      dateStr,
      includeCompleted: _showCompletedTasks,
    );
    if (raw.isEmpty) return const [];

    return CalendarScheduler.packTasksPreservingExplicitTimes(
      dateStr: dateStr,
      dayTasks: raw,
      includeCompleted: _showCompletedTasks,
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
    final now = DateTime.now();
    final todayStr = CalendarScheduler.formatDate(now);
    if (dateStr == todayStr) {
      return block.prayer.isDone;
    }
    return false;
  }

  bool _isHabitDone(String dateStr, CalendarHabitBlock block) {
    final hId = block.habit.id.toLowerCase().trim();
    final dateLogs = _completedLogsByDate[dateStr];
    if (dateLogs != null &&
        (dateLogs.contains(hId) || dateLogs.contains('habit_$hId'))) {
      return true;
    }
    return false;
  }

  Future<void> _togglePrayerForDate(
      String dateStr, CalendarPrayerBlock block) async {
    final currentlyDone = _isPrayerDone(dateStr, block);
    final nextDone = !currentlyDone;
    final code = block.prayer.prayerCode.toLowerCase().trim();

    setState(() {
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

  Future<void> _toggleHabitForDate(
      String dateStr, CalendarHabitBlock block) async {
    final currentlyDone = _isHabitDone(dateStr, block);
    final nextDone = !currentlyDone;
    final hId = block.habit.id;

    setState(() {
      final set = _completedLogsByDate.putIfAbsent(dateStr, () => <String>{});
      if (nextDone) {
        set.add(hId);
      } else {
        set.remove(hId);
      }
    });

    try {
      final repo = widget.habitRepo ?? HabitRepository();
      await repo.toggleHabit(block.habit.id, nextDone, dateStr);
    } catch (_) {}
  }

  void _openCreateTask({DateTime? date, String? time}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTaskSheet(
        initialDate: date ?? _selectedDate,
        initialTime: time,
        onTaskCreated: () {
          setState(() {});
        },
      ),
    );
  }

  void _openTaskDetail(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TaskDetailSheet(
        task: task,
        onTaskUpdated: (updated) {
          setState(() {
            final idx = _tasks.indexWhere(
              (t) => t.id == updated.id || t.id == task.sourceTaskId,
            );
            if (idx >= 0) {
              _tasks[idx] = updated;
            }
          });
        },
      ),
    );
  }

  void _shiftDay(int deltaDays) {
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
      _selectedDate = now;
    });
    if (_gridScrollController.hasClients) {
      final target = math.max(0.0, (now.hour - 1) * _hourHeight);
      _gridScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.isArabic;
    final l10n = context.l10n;
    final dateStr = CalendarScheduler.formatDate(_selectedDate);
    final dayTasks = _tasksForDay(dateStr);
    final habitBlocks = _dailyHabitBlocks;
    final prayerBlocks = _dailyPrayerBlocks;

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top App Navigation & Controls Header
            _buildTopBar(context, isAr, l10n),

            // 2. Interactive Horizontal Week Strip
            _buildWeekStrip(context, isAr),

            const Divider(height: 1, color: AxisColors.borderSubtle),

            // 3. View Switcher Bar (Day Time Grid vs Schedule Timeline)
            _buildViewModeBar(context, isAr),

            // 4. Main Body: Day Time Grid or Schedule Agenda
            Expanded(
              child: _viewMode == MobileCalendarViewMode.day
                  ? _buildDayTimeGrid(context, dateStr, dayTasks, habitBlocks, prayerBlocks)
                  : _buildScheduleAgendaView(context, dateStr, dayTasks, habitBlocks, prayerBlocks, isAr),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('mobile_calendar_fab'),
        onPressed: () => _openCreateTask(date: _selectedDate),
        backgroundColor: AxisColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 26),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isAr, AppLocalizations l10n) {
    final monthName = _monthFullName(_selectedDate.month, isAr);
    final yearStr = '${_selectedDate.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AxisColors.surfaceLowest,
        border: Border(
          bottom: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Back Button if route can pop
          if (Navigator.of(context).canPop())
            IconButton(
              icon: Icon(
                isAr ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_rounded,
                size: 18,
                color: AxisColors.textHigh,
              ),
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).pop(),
            ),

          // Month & Year title
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AxisColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AxisColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$monthName $yearStr',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AxisColors.textHigh,
                        ),
                      ),
                      Text(
                        l10n.calendar,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: AxisColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Jump to Today
          TextButton(
            key: const ValueKey('mobile_calendar_today_button'),
            onPressed: _goToToday,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: AxisColors.surfaceHigh.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              isAr ? 'اليوم' : 'TODAY',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AxisColors.secondarySoft,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Completed Filter Toggle Button
          Tooltip(
            message: isAr
                ? (_showCompletedTasks ? 'إخفاء المكتملة' : 'إظهار المكتملة')
                : (_showCompletedTasks ? 'Hide Completed' : 'Show Completed'),
            child: InkWell(
              key: const ValueKey('mobile_calendar_completed_toggle'),
              onTap: () {
                setState(() => _showCompletedTasks = !_showCompletedTasks);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _showCompletedTasks
                      ? AxisColors.tertiary.withValues(alpha: 0.16)
                      : AxisColors.surfaceHigh.withValues(alpha: 0.25),
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
                      size: 14,
                      color: _showCompletedTasks
                          ? AxisColors.tertiary
                          : AxisColors.textDim,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isAr ? 'المكتملة' : 'Done',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: _showCompletedTasks
                            ? AxisColors.tertiary
                            : AxisColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip(BuildContext context, bool isAr) {
    // Current week days centered on _selectedDate starting on Sunday
    final weekDays = CalendarScheduler.buildWeekDays(_selectedDate, DateTime.sunday);
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: AxisColors.surfaceLowest,
      child: Row(
        children: [
          // Prev Week Chevron
          IconButton(
            key: const ValueKey('mobile_calendar_prev_week'),
            icon: Icon(
              isAr ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              size: 20,
              color: AxisColors.textMuted,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => _shiftDay(-7),
          ),

          // 7 Day items
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final day in weekDays)
                  _buildDayStripItem(context, day, now, isAr),
              ],
            ),
          ),

          // Next Week Chevron
          IconButton(
            key: const ValueKey('mobile_calendar_next_week'),
            icon: Icon(
              isAr ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
              size: 20,
              color: AxisColors.textMuted,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => _shiftDay(7),
          ),
        ],
      ),
    );
  }

  Widget _buildDayStripItem(
    BuildContext context,
    DateTime day,
    DateTime now,
    bool isAr,
  ) {
    final isSelected = day.year == _selectedDate.year &&
        day.month == _selectedDate.month &&
        day.day == _selectedDate.day;
    final isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
    final dateStr = CalendarScheduler.formatDate(day);
    final tasksForThisDay = CalendarScheduler.expandTasksForDate(
      _tasks,
      dateStr,
      includeCompleted: _showCompletedTasks,
    ).length;

    return GestureDetector(
      key: ValueKey('mobile_calendar_day_$dateStr'),
      onTap: () {
        setState(() => _selectedDate = day);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.primary.withValues(alpha: 0.22)
              : (isToday
                  ? AxisColors.secondary.withValues(alpha: 0.12)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AxisColors.primary
                : (isToday ? AxisColors.secondary.withValues(alpha: 0.45) : Colors.transparent),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _weekdayVeryShortName(day.weekday, isAr),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AxisColors.primarySoft
                    : (isToday ? AxisColors.secondarySoft : AxisColors.textDim),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${day.day}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isToday ? AxisColors.secondaryBright : AxisColors.textHigh),
              ),
            ),
            const SizedBox(height: 3),
            // Dot indicator for task activity
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tasksForThisDay > 0
                    ? (isSelected ? AxisColors.secondary : AxisColors.warning)
                    : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeBar(BuildContext context, bool isAr) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AxisColors.canvasBase,
      child: Row(
        children: [
          // View Switcher: Day Grid vs Schedule Timeline
          Container(
            height: 30,
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildViewModeChip(
                  key: 'mobile_calendar_view_day',
                  label: isAr ? 'مخطط' : 'Day',
                  icon: Icons.view_day_rounded,
                  isActive: _viewMode == MobileCalendarViewMode.day,
                  onTap: () => setState(() => _viewMode = MobileCalendarViewMode.day),
                ),
                _buildViewModeChip(
                  key: 'mobile_calendar_view_schedule',
                  label: isAr ? 'الجدول' : 'Schedule',
                  icon: Icons.list_alt_rounded,
                  isActive: _viewMode == MobileCalendarViewMode.schedule,
                  onTap: () => setState(() => _viewMode = MobileCalendarViewMode.schedule),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Selected date formatted
          Expanded(
            child: Text(
              '${_weekdayFullName(_selectedDate.weekday, isAr)}, ${_selectedDate.day} ${_monthShortName(_selectedDate.month, isAr)}',
              textAlign: isAr ? TextAlign.left : TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AxisColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeChip({
    required String key,
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: ValueKey(key),
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AxisColors.primary.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AxisColors.primarySoft : AxisColors.textDim,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : AxisColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Day View: Vertical 24h Hourly Time Grid
  // ---------------------------------------------------------------------------
  Widget _buildDayTimeGrid(
    BuildContext context,
    String dateStr,
    List<Task> dayTasks,
    List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks,
  ) {
    const totalHours = 24;
    const totalHeight = totalHours * _hourHeight;
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final currentMinute = now.hour * 60 + now.minute;
    final currentLineTop = (currentMinute / 60.0) * _hourHeight;

    return SingleChildScrollView(
      controller: _gridScrollController,
      physics: const ClampingScrollPhysics(),
      child: SizedBox(
        height: totalHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Time Gutter
            SizedBox(
              width: 52,
              child: Stack(
                children: [
                  for (var hour = 0; hour < totalHours; hour++)
                    Positioned(
                      top: hour * _hourHeight - 7,
                      left: 6,
                      right: 6,
                      child: Text(
                        '${hour.toString().padLeft(2, '0')}:00',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: AxisColors.textDim,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                ],
              ),
            ),

            // Vertical divider
            Container(width: 1, color: AxisColors.borderSubtle),

            // Right Scheduling Canvas
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTapDown: (tap) {
                  final clickedMin =
                      ((tap.localPosition.dy / _hourHeight) * 60).round().clamp(0, 23 * 60 + 45);
                  final snapped = (clickedMin ~/ 15) * 15;
                  final timeStr = CalendarScheduler.formatMinutes(snapped);
                  _openCreateTask(date: _selectedDate, time: timeStr);
                },
                child: Stack(
                  children: [
                    // Hour grid lines
                    for (var hour = 0; hour < totalHours; hour++)
                      Positioned(
                        top: hour * _hourHeight,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: AxisColors.borderSubtle.withValues(alpha: 0.35),
                        ),
                      ),
                    // Half-hour dashed/subtle lines
                    for (var hour = 0; hour < totalHours; hour++)
                      Positioned(
                        top: (hour + 0.5) * _hourHeight,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: AxisColors.borderSubtle.withValues(alpha: 0.15),
                        ),
                      ),

                    // Prayers Blocks
                    for (final prayer in prayerBlocks)
                      _buildMobilePrayerBlock(dateStr, prayer),

                    // Habits Blocks
                    for (final habit in habitBlocks)
                      _buildMobileHabitBlock(dateStr, habit),

                    // Task Blocks
                    for (final task in dayTasks)
                      _buildMobileTaskBlock(dateStr, task),

                    // Live Red/Cyan Laser Time Indicator Line (Today only)
                    if (isToday)
                      Positioned(
                        top: currentLineTop - 1,
                        left: 0,
                        right: 0,
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AxisColors.danger,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AxisColors.danger,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 2,
                                decoration: BoxDecoration(
                                  color: AxisColors.danger,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AxisColors.danger.withValues(alpha: 0.5),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
  }

  static Color _prayerColor(String raw) {
    final code = raw.trim().toLowerCase();
    if (code.contains('fajr')) return const Color(0xFF06B6D4); // Dawn Cyan
    if (code.contains('dhuhr')) return const Color(0xFFF59E0B); // Solar Amber
    if (code.contains('asr')) return const Color(0xFFF97316); // Sunset Orange
    if (code.contains('maghrib')) return const Color(0xFFEF4444); // Crimson Dusk
    if (code.contains('isha')) return const Color(0xFF8B5CF6); // Night Violet
    return const Color(0xFF06B6D4);
  }

  Widget _buildMobilePrayerBlock(String dateStr, CalendarPrayerBlock block) {
    final top = (block.startMinute / 60.0) * _hourHeight;
    final height = math.max((block.durationMin / 60.0) * _hourHeight, 20.0);
    final isDone = _isPrayerDone(dateStr, block);
    final color = _prayerColor(block.prayer.prayerCode);

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        key: ValueKey('mobile_prayer_${dateStr}_${block.prayer.prayerCode}'),
        onTap: () => _togglePrayerForDate(dateStr, block),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDone ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDone ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Text(
                block.prayer.name,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isDone ? AxisColors.textDim : Colors.white,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              const Spacer(),
              Text(
                block.startTimeFormatted,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  color: AxisColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHabitBlock(String dateStr, CalendarHabitBlock block) {
    final top = (block.startMinute / 60.0) * _hourHeight;
    final height = math.max((block.durationMin / 60.0) * _hourHeight, 20.0);
    final isDone = _isHabitDone(dateStr, block);
    const color = Color(0xFF3B82F6); // Dedicated Blue color for habits

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        key: ValueKey('mobile_habit_${dateStr}_${block.habit.id}'),
        onTap: () => _toggleHabitForDate(dateStr, block),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: isDone ? color.withValues(alpha: 0.08) : color.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDone ? color.withValues(alpha: 0.3) : color.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 13,
                color: color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  block.habit.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isDone ? AxisColors.textDim : Colors.white,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                block.startTimeFormatted,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  color: AxisColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileTaskBlock(String dateStr, Task task) {
    final startMin = CalendarScheduler.parseTimeToMinutes(task.dueTime) ??
        CalendarScheduler.defaultDayStartMinutes;
    final duration = CalendarScheduler.sanitizeDuration(task.estimateMin);
    final top = (startMin / 60.0) * _hourHeight;
    final height = math.max((duration / 60.0) * _hourHeight, 24.0);
    final isDone = task.isCompleted;
    final pColor = isDone ? AxisColors.tertiary : _priorityColor(task.priority);
    final pLabel = _priorityLabel(task.priority);

    return Positioned(
      key: ValueKey('mobile_task_${task.id}'),
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        onTap: () => _openTaskDetail(task),
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: isDone
                ? AxisColors.tertiary.withValues(alpha: 0.09)
                : pColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDone
                  ? AxisColors.tertiary.withValues(alpha: 0.35)
                  : pColor.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Left priority indicator strip
              Container(
                width: 3.5,
                decoration: BoxDecoration(
                  color: isDone ? AxisColors.tertiary : pColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
                ),
              ),
              const SizedBox(width: 6),
              if (isDone) ...[
                const Icon(
                  Icons.check_circle_rounded,
                  color: AxisColors.tertiary,
                  size: 13,
                ),
                const SizedBox(width: 4),
              ],
              if (task.isRecurring) ...[
                Icon(
                  Icons.repeat_rounded,
                  color: isDone ? AxisColors.tertiary : pColor,
                  size: 12,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                pLabel,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  color: isDone ? AxisColors.tertiary : pColor,
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDone ? AxisColors.textMuted : AxisColors.textHigh,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    decorationColor: AxisColors.textDim,
                  ),
                  maxLines: height < 40 ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${CalendarScheduler.formatMinutes(startMin)} · ${duration}m',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  color: AxisColors.textDim,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Agenda / Schedule View (Chronological Timeline Feed)
  // ---------------------------------------------------------------------------
  Widget _buildScheduleAgendaView(
    BuildContext context,
    String dateStr,
    List<Task> dayTasks,
    List<CalendarHabitBlock> habitBlocks,
    List<CalendarPrayerBlock> prayerBlocks,
    bool isAr,
  ) {
    // Collect all chronological items for the day
    final items = <_AgendaItem>[
      for (final p in prayerBlocks)
        _AgendaItem(
          startMinute: p.startMinute,
          title: p.prayer.name,
          subtitle: isAr ? 'صلاة إسلامية يومية' : 'Daily Islamic Prayer',
          icon: Icons.mosque_rounded,
          color: _prayerColor(p.prayer.prayerCode),
          isCompleted: _isPrayerDone(dateStr, p),
          onTap: () => _togglePrayerForDate(dateStr, p),
        ),
      for (final h in habitBlocks)
        _AgendaItem(
          startMinute: h.startMinute,
          title: h.habit.name,
          subtitle: isAr ? 'عادة يومية محمية' : 'Daily Habit Routine',
          icon: Icons.loop_rounded,
          color: const Color(0xFF3B82F6), // Blue for habits
          isCompleted: _isHabitDone(dateStr, h),
          onTap: () => _toggleHabitForDate(dateStr, h),
        ),
      for (final t in dayTasks)
        _AgendaItem(
          startMinute: CalendarScheduler.parseTimeToMinutes(t.dueTime) ?? 8 * 60,
          title: t.title,
          subtitle: t.isRecurring
              ? '${_priorityLabel(t.priority)} · ${t.estimateMin ?? 15}m · ${RecurrenceEngine.formatHumanReadable(t.recurrenceRule, isArabic: isAr)}'
              : '${_priorityLabel(t.priority)} · ${t.estimateMin ?? 15}m',
          icon: t.isRecurring ? Icons.repeat_rounded : Icons.task_alt_rounded,
          color: t.isCompleted ? AxisColors.tertiary : _priorityColor(t.priority),
          isCompleted: t.isCompleted,
          onTap: () => _openTaskDetail(t),
        ),
    ]..sort((a, b) => a.startMinute.compareTo(b.startMinute));

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                shape: BoxShape.circle,
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 36,
                color: AxisColors.textDim,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isAr ? 'لا توجد مهام أو مواعيد لهذا اليوم' : 'No tasks scheduled for this day',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AxisColors.textHigh,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isAr
                  ? 'انقر على زر الإضافة أدناه لجدولة مهمة جديدة'
                  : 'Tap the + button below to schedule a new task',
              style: GoogleFonts.getFont(
                'Geist',
                fontSize: 12,
                color: AxisColors.textDim,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final timeFormatted = CalendarScheduler.formatMinutes(item.startMinute);

        return InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.isCompleted
                    ? AxisColors.tertiary.withValues(alpha: 0.3)
                    : AxisColors.borderSubtle,
                width: 1.1,
              ),
            ),
            child: Row(
              children: [
                // Time chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timeFormatted,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Icon / Checkmark
                Icon(
                  item.isCompleted
                      ? Icons.check_circle_rounded
                      : (item.icon == Icons.task_alt_rounded
                          ? Icons.radio_button_unchecked_rounded
                          : item.icon),
                  size: 18,
                  color: item.color,
                ),
                const SizedBox(width: 10),

                // Title & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: item.isCompleted ? AxisColors.textMuted : AxisColors.textHigh,
                          decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                          decorationColor: AxisColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        style: GoogleFonts.getFont(
                          'Geist',
                          fontSize: 11,
                          color: AxisColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Helper Color & Label Methods
  // ---------------------------------------------------------------------------
  Color _priorityColor(int? priority) {
    switch (priority) {
      case 1:
        return AxisColors.priorityHigh; // Crimson
      case 2:
        return AxisColors.priorityMed; // Amber
      case 3:
      default:
        return AxisColors.priorityLow; // Cyan
    }
  }

  String _priorityLabel(int? priority) {
    switch (priority) {
      case 1:
        return 'P1';
      case 2:
        return 'P2';
      case 3:
      default:
        return 'P3';
    }
  }

  static String _weekdayVeryShortName(int weekday, bool isArabic) {
    if (isArabic) {
      return const ['إثن', 'ثلا', 'أرب', 'خمي', 'جمع', 'سبت', 'أحد'][(weekday - 1).clamp(0, 6)];
    }
    return const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][(weekday - 1).clamp(0, 6)];
  }

  static String _weekdayFullName(int weekday, bool isArabic) {
    if (isArabic) {
      return const [
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ][(weekday - 1).clamp(0, 6)];
    }
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][(weekday - 1).clamp(0, 6)];
  }

  static String _monthShortName(int month, bool isArabic) {
    if (isArabic) {
      return const [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ][(month - 1).clamp(0, 11)];
    }
    return const [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ][(month - 1).clamp(0, 11)];
  }

  static String _monthFullName(int month, bool isArabic) {
    if (isArabic) {
      return const [
        'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
        'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
      ][(month - 1).clamp(0, 11)];
    }
    return const [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ][(month - 1).clamp(0, 11)];
  }
}

class _AgendaItem {
  final int startMinute;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isCompleted;
  final VoidCallback onTap;

  const _AgendaItem({
    required this.startMinute,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isCompleted,
    required this.onTap,
  });
}
