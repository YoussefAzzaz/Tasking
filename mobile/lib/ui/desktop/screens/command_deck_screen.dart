import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/focus_repository.dart';
import '../../../data/habit_repository.dart';
import '../../../data/prayer_time_service.dart';
import '../../../data/project_repository.dart';
import '../../../data/task_repository.dart';
import '../../../data/user_profile_repository.dart';
import '../../../domain/id_generator.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_checkbox.dart';
import '../widgets/desktop_selection_chip.dart';
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

class _CommandDeckScreenState extends State<CommandDeckScreen> {
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  int _taskFilterIndex = 0; // 0: All, 1: Overdue, 2: High Priority, 3: Upcoming
  final _quickTaskInputController = TextEditingController();

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
    _quickTaskInputController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickAddTask() async {
    final title = _quickTaskInputController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final task = Task(
      id: IdGenerator.generateDeterministicId('task_${now.microsecondsSinceEpoch}'),
      title: title,
      status: 'pending',
      priority: 2,
      dueDate: todayStr,
    );

    await TaskRepository().addTask(task);
    _quickTaskInputController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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

          // 2-Column Main Deck Split (Left flex 6, Right flex 4)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildExecutionStreamCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildActiveProjectsMatrixCard(),
                  ],
                ),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildPrayerTelemetryCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildHabitLoopsCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildLevelXpCard(),
                  ],
                ),
              ),
            ],
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
            Text(
              '$timeStr  ·  $dateStr',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AxisColors.textMuted,
              ),
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
                    const Expanded(child: _FocusTodayMetric()),
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

  Widget _buildExecutionStreamCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: "TODAY'S EXECUTION STREAM",
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 0),
                const SizedBox(width: 4),
                _buildFilterChip('Overdue', 1),
                const SizedBox(width: 4),
                _buildFilterChip('High Priority', 2),
                const SizedBox(width: 4),
                _buildFilterChip('Upcoming', 3),
              ],
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<Task>>(
            stream: TaskRepository().watchTasks(),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? [];
              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);

              var filtered = tasks.where((t) {
                if (_taskFilterIndex == 1) {
                  return !t.isCompleted && t.dueDate != null && t.dueDate!.compareTo(todayStr) < 0;
                } else if (_taskFilterIndex == 2) {
                  return t.priority == 1 && !t.isCompleted;
                } else if (_taskFilterIndex == 3) {
                  return !t.isCompleted && (t.dueDate == null || t.dueDate!.compareTo(todayStr) >= 0);
                }
                return true;
              }).take(6).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Text(
                      'No tasks in this execution queue',
                      style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return Column(
                children: filtered.map((task) => _buildTaskRow(task)).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          // Inline quick add input
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AxisColors.borderSubtle, width: 1),
                  ),
                  child: TextField(
                    controller: _quickTaskInputController,
                    onSubmitted: (_) => _handleQuickAddTask(),
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: '+ Add a new task for today...',
                      hintStyle: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AccentButton(
                label: 'Add',
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                onPressed: _handleQuickAddTask,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    return DesktopSelectionChip(
      label: label,
      selected: _taskFilterIndex == index,
      onTap: () => setState(() => _taskFilterIndex = index),
    );
  }

  Widget _buildTaskRow(Task task) {
    final isDone = task.isCompleted;
    final railColor = isDone
        ? AxisColors.tertiary
        : (task.priority == 1 ? AxisColors.priorityHigh : AxisColors.secondary);

    return Container(
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
        ],
      ),
    );
  }

  Widget _buildActiveProjectsMatrixCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'ACTIVE PROJECTS MATRIX',
            trailing: GhostButton(
              label: 'EXPAND ↗',
              height: 28,
              onPressed: () => widget.onNavigateToTab(2), // Projects & Tasks
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Project>>(
            stream: ProjectRepository().watchProjects(),
            builder: (context, projSnap) {
              final projects = projSnap.data ?? [];
              if (projects.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      'No active projects. Create one in Projects & Tasks.',
                      style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return StreamBuilder<List<Task>>(
                stream: TaskRepository().watchTasks(),
                builder: (context, taskSnap) {
                  final allTasks = taskSnap.data ?? [];
                  final displayProjects = projects.take(3).toList();

                  return Row(
                    children: displayProjects.map((p) {
                      final projectTasks = allTasks
                          .where((t) => t.projectId == p.id || t.projectId == p.name)
                          .toList();
                      final total = projectTasks.length;
                      final completed = projectTasks.where((t) => t.isCompleted).length;
                      final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;
                      final pct = (progress * 100).toInt();

                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.only(right: 8.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AxisColors.borderSubtle, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$completed/$total tasks',
                                    style: GoogleFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim),
                                  ),
                                  Text(
                                    '$pct%',
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AxisColors.secondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ProgressGauge(
                                value: progress,
                                height: 3.5,
                                color: AxisColors.secondary,
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              );
            },
          ),
        ],
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
          StreamBuilder<List<Prayer>>(
            stream: PrayerTimeService().watchPrayers(),
            builder: (context, snapshot) {
              final prayers = snapshot.data ?? [];
              final doneCount = prayers.where((p) => p.isDone).length;
              final totalCount = prayers.isNotEmpty ? prayers.length : 5;
              final progress = (doneCount / totalCount).clamp(0.0, 1.0);

              return Column(
                children: [
                  ...prayers.map((prayer) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                  }),
                  const SizedBox(height: 12),
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
            trailing: GhostButton(
              label: '+ View',
              height: 26,
              onPressed: () => widget.onNavigateToTab(1), // Prayer & Habits
            ),
          ),
          const SizedBox(height: 6),
          StreamBuilder<List<Habit>>(
            stream: HabitRepository().watchHabits(),
            builder: (context, snapshot) {
              final habits = (snapshot.data ?? []).take(4).toList();
              if (habits.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      'No active habits enrolled',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 58,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: habits.length,
                itemBuilder: (context, i) {
                  final h = habits[i];
                  return Container(
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
                          color: AxisColors.warning,
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
                              Text(
                                '${h.streakDays}d streak',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  color: AxisColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
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
        final nextLevelTarget = level * 1000;
        final currentLevelBase = (level - 1) * 1000;
        final progress = nextLevelTarget > currentLevelBase
            ? ((xp - currentLevelBase) / (nextLevelTarget - currentLevelBase)).clamp(0.0, 1.0)
            : 0.5;

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

/// Shared metric-card layout for the Command Deck stats row.
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

/// Live "Focus Today" metric card backed by real focus_sessions data — no
/// hardcoded values. Shows 0m until a completed session exists for today.
class _FocusTodayMetric extends StatelessWidget {
  const _FocusTodayMetric();

  static String formatMinutes(int total) {
    final h = total ~/ 60;
    final m = total % 60;
    if (h <= 0) return '${m}m';
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: FocusRepository().watchFocusedMinutesToday(),
      builder: (context, snapshot) {
        final minutes = snapshot.data ?? 0;
        return _buildMetricCard(
          title: 'FOCUS TODAY',
          value: formatMinutes(minutes),
          caption: 'Deep work sprint',
          icon: Icons.bolt_rounded,
          accentColor: AxisColors.primary,
        );
      },
    );
  }
}
