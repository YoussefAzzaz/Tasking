import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/focus_repository.dart';
import '../../../data/habit_category_repository.dart';
import '../../../data/habit_repository.dart';
import '../../../data/note_repository.dart';
import '../../../data/prayer_time_service.dart';
import '../../../data/task_repository.dart';
import '../../../data/user_profile_repository.dart';
import '../../../domain/gamification_engine.dart';
import '../../common/axis_markdown_viewer.dart';
import '../../notes/create_note_sheet.dart';
import '../../notes/widgets/daily_journal_card.dart';
import '../../today/widgets/time_slot_card.dart';
import '../core/desktop_layout.dart';
import '../core/task_checklist_mixin.dart';
import '../dialogs/quick_habit_dialog.dart';
import '../dialogs/quick_task_dialog.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_checkbox.dart';
import '../widgets/ghost_button.dart';
import '../widgets/priority_badge.dart';
import '../widgets/progress_gauge.dart';
import '../widgets/section_header.dart';
import '../widgets/task_status_rail.dart';
import '../widgets/telemetry_chip.dart';

/// Command Deck Dashboard (Tab 0) - Primary desktop mission control view.
class CommandDeckScreen extends StatefulWidget {
  const CommandDeckScreen({
    super.key,
    required this.onNavigateToTab,
    required this.onOpenNewTaskDialog,
  });

  final ValueChanged<int> onNavigateToTab;
  final VoidCallback onOpenNewTaskDialog;

  @override
  State<CommandDeckScreen> createState() => _CommandDeckScreenState();
}

class _CommandDeckScreenState extends State<CommandDeckScreen> with TaskChecklistMixin {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _currentTime = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  // Checklist helpers provided by TaskChecklistMixin

  void _showTaskPreviewDialog(Task initialTask) {
    Task currentTask = initialTask;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setPreviewState) {
            final isDone = currentTask.isCompleted;
            final checklist = parseTaskChecklist(currentTask.notes);
            final displayNotes = stripChecklistFromNotes(currentTask.notes);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Container(
                width: 580,
                constraints: const BoxConstraints(maxHeight: 740),
                decoration: BoxDecoration(
                  color: AxisColors.canvasBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AxisColors.borderGlass2, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AxisColors.secondary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.preview_rounded,
                                  color: AxisColors.secondary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "TASK PREVIEW // TODAY'S STREAM",
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AxisColors.secondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GhostButton(
                                label: 'Edit',
                                icon: Icons.edit_outlined,
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                onPressed: () {
                                  Navigator.of(dialogCtx).pop();
                                  QuickTaskDialog.show(
                                    context,
                                    taskToEdit: currentTask,
                                    onTaskUpdated: (_) {
                                      if (mounted) setState(() {});
                                    },
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: AxisColors.textDim),
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AxisColors.borderSubtle, height: 1),

                    // Scrollable content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title & Completion
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DesktopCheckbox(
                                  value: isDone,
                                  onChanged: (val) async {
                                    final updated = currentTask.copyWith(status: val ? 'done' : 'todo');
                                    setPreviewState(() {
                                      currentTask = updated;
                                    });
                                    await TaskRepository().toggleTaskStatus(currentTask, val);
                                  },
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentTask.title,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                          color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          if (currentTask.priority != null)
                                            PriorityBadge(priority: currentTask.priority),
                                          if (currentTask.dueDate != null)
                                            TelemetryChip(
                                              label: 'Due ${currentTask.dueDate}${currentTask.dueTime != null ? " ${currentTask.dueTime}" : ""}',
                                              color: AxisColors.secondary,
                                              icon: Icons.calendar_today_rounded,
                                            ),
                                          if (currentTask.estimateMin != null)
                                            TelemetryChip(
                                              label: '${currentTask.estimateMin}m Estimate',
                                              color: AxisColors.primary,
                                              icon: Icons.timer_outlined,
                                            ),
                                          TelemetryChip(
                                            label: isDone ? 'COMPLETED' : 'IN PROGRESS',
                                            color: isDone ? AxisColors.tertiary : AxisColors.warning,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Notes section (strip checkboxes so not duplicated!)
                            if (displayNotes.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceLowest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AxisColors.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'NOTES & CONTEXT',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: AxisColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    AxisMarkdownViewer(
                                      markdown: displayNotes,
                                      selectable: true,
                                      baseStyle: GoogleFonts.getFont('Geist', fontSize: 13, height: 1.4, color: AxisColors.textHigh),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Interactive Checklist Subtasks
                            if (checklist.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceLowest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AxisColors.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'CHECKLIST SUBTASKS (${checklist.where((c) => c.isDone).length}/${checklist.length})',
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: AxisColors.textMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...checklist.map((item) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: Row(
                                          children: [
                                            DesktopCheckbox(
                                              value: item.isDone,
                                              size: 18,
                                              color: AxisColors.secondary,
                                              onChanged: (val) async {
                                                final updated = await toggleTaskChecklist(currentTask, item.lineIndex);
                                                if (dialogCtx.mounted) {
                                                  setPreviewState(() {
                                                    currentTask = updated;
                                                  });
                                                }
                                              },
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                item.text,
                                                style: GoogleFonts.getFont(
                                                  'Geist',
                                                  fontSize: 13,
                                                  decoration: item.isDone ? TextDecoration.lineThrough : null,
                                                  color: item.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const Divider(color: AxisColors.borderSubtle, height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GhostButton(
                            label: 'Close',
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                          ),
                          const SizedBox(width: 10),
                          AccentButton(
                            label: isDone ? 'Mark Incomplete' : 'Complete Task',
                            icon: isDone ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                            onPressed: () async {
                              await TaskRepository().toggleTaskStatus(currentTask, !isDone);
                              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            },
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2.2 Welcome Header
          _buildWelcomeHeader(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 2.3 Top Stats Row (4 cards)
          _buildStatsRow(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 2-Column Main Deck Split (Left flex 6, Right flex 4) - constrained to page height without outer scroller
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildExecutionStreamCard(),
                      ),
                      const SizedBox(height: DesktopLayout.sectionSpacing),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _buildMacroSlotsCard()),
                            const SizedBox(width: DesktopLayout.sectionSpacing),
                            Expanded(child: SingleChildScrollView(child: _buildDailyJournalCard())),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DesktopLayout.sectionSpacing),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildPrayerTelemetryCard(),
                      ),
                      const SizedBox(height: DesktopLayout.sectionSpacing),
                      Expanded(
                        child: _buildHabitLoopsCard(),
                      ),
                      const SizedBox(height: DesktopLayout.sectionSpacing),
                      _buildLevelXpCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);
    final dateStr = DateFormat('EEE, MMM d').format(_currentTime);

    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final name = profile.name.trim().isEmpty ? 'Commander' : profile.name;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AxisColors.tertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'SYSTEM ACTIVE • LOCAL NODE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AxisColors.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Welcome Back, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AxisColors.textHigh,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$timeStr  ·  $dateStr',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AxisColors.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                const TelemetryChip(
                  label: 'All Systems Online',
                  dotColor: AxisColors.tertiary,
                  color: AxisColors.tertiary,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, taskSnapshot) {
        final tasks = taskSnapshot.data ?? [];
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final todayTasks = tasks.where((t) => t.dueDate == todayStr).toList();
        final completedTasks = todayTasks.where((t) => t.isCompleted).length;
        final totalTasks = todayTasks.isNotEmpty ? todayTasks.length : tasks.length;
        final completedCount = todayTasks.isNotEmpty ? completedTasks : tasks.where((t) => t.isCompleted).length;

        return StreamBuilder<List<Habit>>(
          stream: HabitRepository().watchHabits(),
          builder: (context, habitSnapshot) {
            final habits = habitSnapshot.data ?? [];
            final maxStreak = habits.fold<int>(0, (prev, h) => h.streakDays > prev ? h.streakDays : prev);

            return StreamBuilder<List<Prayer>>(
              stream: PrayerTimeService().watchPrayers(),
              builder: (context, prayerSnapshot) {
                final prayers = prayerSnapshot.data ?? [];
                final nextPrayer = prayers.where((p) => !p.isDone).firstOrNull;

                return Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        title: 'DAILY TASKS',
                        value: '$completedCount / $totalTasks',
                        caption: 'Tasks target',
                        icon: Icons.check_circle_outline_rounded,
                        accentColor: AxisColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'HABIT STREAK',
                        value: '$maxStreak Days',
                        caption: 'Best adherence',
                        icon: Icons.local_fire_department_rounded,
                        accentColor: AxisColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StreamBuilder<int>(
                        stream: FocusRepository().watchTodayFocusMinutes(),
                        builder: (context, focusSnap) {
                          final totalMin = focusSnap.data ?? 0;
                          final hours = totalMin ~/ 60;
                          final mins = totalMin % 60;
                          final formatted = hours > 0 && mins > 0
                              ? '${hours}h ${mins}m'
                              : (hours > 0 ? '${hours}h' : '${mins}m');

                          return _buildMetricCard(
                            title: 'FOCUS TODAY',
                            value: formatted,
                            caption: totalMin > 0 ? 'Deep work sprints' : 'No focus sprints yet',
                            icon: Icons.bolt_rounded,
                            accentColor: AxisColors.primary,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        title: 'NEXT PRAYER',
                        value: nextPrayer != null ? '${nextPrayer.name} ${nextPrayer.time}' : 'All Done',
                        caption: nextPrayer != null ? 'Obligation scheduled' : 'All obligations met',
                        icon: Icons.schedule_rounded,
                        accentColor: AxisColors.tertiary,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String caption,
    required IconData icon,
    required Color accentColor,
  }) {
    return DesktopCard(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AxisColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: 16, color: accentColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AxisColors.textHigh,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutionStreamCard() {
    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        final todayTasks = tasks.where((t) {
          if (t.dueDate == null || t.dueDate!.trim().isEmpty) return false;
          return t.dueDate == todayStr || t.dueDate!.startsWith(todayStr);
        }).toList()
          ..sort((a, b) {
            if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
            final pA = a.priority ?? 3;
            final pB = b.priority ?? 3;
            if (pA != pB) return pA.compareTo(pB);
            return (a.dueTime ?? '').compareTo(b.dueTime ?? '');
          });

        final pendingCount = todayTasks.where((t) => !t.isCompleted).length;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: "TODAY'S EXECUTION STREAM",
                trailing: TelemetryChip(
                  label: '$pendingCount REMAINING',
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 8),
              if (todayTasks.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      'No tasks scheduled for today',
                      style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: todayTasks.length,
                    itemBuilder: (context, index) => _buildTaskRow(todayTasks[index]),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMacroSlotsCard() {
    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        final slottedTasks = tasks.where((t) {
          final isToday = t.dueDate != null &&
              (t.dueDate == todayStr || t.dueDate!.startsWith(todayStr));
          if (!isToday) return false;
          final estimate = t.estimateMin;
          return estimate != null && estimate <= 15;
        }).toList();

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: '15 MIN MACRO SLOTS',
                trailing: TelemetryChip(
                  label: '${slottedTasks.length} SLOTS',
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 6),
              // AI insight banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      color: AxisColors.secondary,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        slottedTasks.isNotEmpty
                            ? '${slottedTasks.length} macro-task${slottedTasks.length > 1 ? 's' : ''} (≤15m) slotted.'
                            : 'Auto-scheduler active (≤15m).',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textHigh),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Auto-Scheduler recalculated idle gaps!'),
                            backgroundColor: AxisColors.secondary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Text(
                        'RESCHEDULE',
                        style: GoogleFonts.getFont(
                          'Geist',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: slottedTasks.isEmpty
                    ? SingleChildScrollView(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.hourglass_empty_rounded, color: AxisColors.secondary, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'No 15-Minute Slots Scheduled',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.spaceGrotesk(
                                        color: AxisColors.textHigh,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Today\'s tasks with estimates of 15 minutes or less appear here.',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.getFont('Geist', color: AxisColors.textDim, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: slottedTasks.length,
                        itemBuilder: (context, i) {
                          final t = slottedTasks[i];
                          final isDone = t.isCompleted;
                          final timeStr = t.dueTime != null && t.dueTime!.isNotEmpty
                              ? t.dueTime!
                              : '${t.estimateMin ?? 15}M Macro';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: TimeSlotCard(
                              time: timeStr,
                              title: t.title,
                              xp: t.priority == 1 ? 30 : 20,
                              isDone: isDone,
                              onToggle: (v) {
                                TaskRepository().toggleTaskStatus(t, v);
                              },
                              onTap: () => _showTaskPreviewDialog(t),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openJournalDialog({Note? noteToEdit}) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 740),
            decoration: BoxDecoration(
              color: AxisColors.canvasBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderGlass2, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CreateNoteSheet(
                initialCategory: 'journal',
                noteToEdit: noteToEdit,
                onNoteCreated: () {
                  if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                  setState(() {});
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDailyJournalCard() {
    final now = DateTime.now();
    return StreamBuilder<List<Note>>(
      stream: NoteRepository().watchNotes(),
      builder: (context, noteSnapshot) {
        final notes = noteSnapshot.data ?? [];
        final todayJournal = notes.cast<Note?>().firstWhere(
          (n) =>
              n != null &&
              n.category == 'journal' &&
              n.createdAt.year == now.year &&
              n.createdAt.month == now.month &&
              n.createdAt.day == now.day,
          orElse: () => null,
        );

        return DailyJournalCard(
          todayJournal: todayJournal,
          onOpenTodayJournal: (note) => _openJournalDialog(noteToEdit: note),
          onStartNewJournal: () => _openJournalDialog(),
        );
      },
    );
  }

  Widget _buildTaskRow(Task task) {
    final isDone = task.isCompleted;
    final railColor = isDone
        ? AxisColors.tertiary
        : switch (task.priority) {
            1 => AxisColors.priorityHigh,
            2 => AxisColors.priorityMed,
            3 => AxisColors.priorityLow,
            _ => AxisColors.secondary,
          };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        hoverColor: AxisColors.surfaceHigh.withValues(alpha: 0.35),
        onTap: () => _showTaskPreviewDialog(task),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3.0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AxisColors.borderSubtle, width: 1),
          ),
          child: Row(
            children: [
              TaskStatusRail(color: railColor, height: 20),
              const SizedBox(width: 10),
              DesktopCheckbox(
                value: isDone,
                onChanged: (val) {
                  TaskRepository().toggleTaskStatus(task, val);
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.getFont(
                    'Geist',
                    fontSize: 13,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                    color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                  ),
                ),
              ),
              if (task.priority != null && !isDone) ...[
                const SizedBox(width: 8),
                PriorityBadge(priority: task.priority, compact: true),
              ],
              if (task.dueTime != null) ...[
                const SizedBox(width: 8),
                Text(
                  task.dueTime!,
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                ),
              ],
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AxisColors.textDim,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerTelemetryCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'PRAYER TELEMETRY',
          ),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<List<Prayer>>(
              stream: PrayerTimeService().watchPrayers(),
              builder: (context, snapshot) {
                final prayers = snapshot.data ?? [];
                final doneCount = prayers.where((p) => p.isDone).length;
                final totalCount = prayers.isNotEmpty ? prayers.length : 5;
                final progress = (doneCount / totalCount).clamp(0.0, 1.0);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: prayers.length,
                        itemBuilder: (context, index) {
                          final prayer = prayers[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                DesktopCheckbox(
                                  value: prayer.isDone,
                                  color: AxisColors.tertiary,
                                  onChanged: (val) {
                                    PrayerTimeService().togglePrayer(prayer.id, val);
                                  },
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    prayer.name,
                                    style: GoogleFonts.getFont(
                                      'Geist',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: prayer.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                    ),
                                  ),
                                ),
                                Text(
                                  prayer.time,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11,
                                    color: AxisColors.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TelemetryChip(
                                  label: prayer.isDone ? 'Done' : 'Upcoming',
                                  color: prayer.isDone ? AxisColors.tertiary : AxisColors.textDim,
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    ProgressGauge(
                      value: progress,
                      label: 'OBLIGATIONS: $doneCount/$totalCount (${(progress * 100).toInt()}%)',
                      color: AxisColors.tertiary,
                      height: 5.0,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitLoopsCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'STREAKS & HABIT LOOPS',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GhostButton(
                  label: 'New',
                  icon: Icons.add_rounded,
                  height: 26,
                  onPressed: () => QuickHabitDialog.show(
                    context,
                    onHabitCreated: () {
                      if (mounted) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 6),
                GhostButton(
                  label: 'View ↗',
                  height: 26,
                  onPressed: () => widget.onNavigateToTab(1), // Prayer & Habits
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: StreamBuilder<List<HabitCategory>>(
              stream: HabitCategoryRepository().watchCategories(),
              builder: (context, catSnap) {
                final categories = catSnap.data ?? [];

                return StreamBuilder<List<Habit>>(
                  stream: HabitRepository().watchHabits(),
                  builder: (context, snapshot) {
                    final habits = (snapshot.data ?? []).take(4).toList();
                    if (habits.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(
                          child: Text(
                            'No active habits enrolled. Click + New to add one.',
                            style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                          ),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisExtent: 64,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: habits.length,
                    itemBuilder: (context, i) {
                      final h = habits[i];
                      final catColor = HabitCategoryRepository().resolveHabitCategoryColor(h, categories);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => QuickHabitDialog.show(
                            context,
                            habitToEdit: h,
                            onHabitCreated: () {
                              if (mounted) setState(() {});
                            },
                          ),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AxisColors.borderSubtle, width: 1),
                            ),
                            child: Row(
                              children: [
                                DesktopCheckbox(
                                  value: h.isDoneToday,
                                  color: catColor,
                                  onChanged: (val) {
                                    HabitRepository().toggleHabit(h.id, val);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        h.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.getFont(
                                          'Geist',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: h.isDoneToday ? AxisColors.textDim : AxisColors.textHigh,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: catColor,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '${h.streakDays}d streak · ${h.category.isNotEmpty ? h.category : "General"}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.spaceGrotesk(
                                                fontSize: 10,
                                                color: AxisColors.textDim,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildLevelXpCard() {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final level = profile.level > 0 ? profile.level : 1;
        final xp = profile.totalXp;
        final currentLevelBase = GamificationEngine.xpToReachLevel(level);
        final nextLevelTarget = GamificationEngine.xpToReachLevel(level + 1);
        final progress = nextLevelTarget > currentLevelBase
            ? ((xp - currentLevelBase) / (nextLevelTarget - currentLevelBase)).clamp(0.0, 1.0)
            : 0.0;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'LEVEL $level OPERATOR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AxisColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$xp / $nextLevelTarget XP',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressGauge(
                value: progress,
                gradient: const LinearGradient(
                  colors: [AxisColors.secondary, AxisColors.primary],
                ),
                height: 6.0,
              ),
            ],
          ),
        );
      },
    );
  }
}
