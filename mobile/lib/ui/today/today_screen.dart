import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/data/app_widget_sync_service.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _totalXp = 0;
  int _todayXp = 0;
  int _streakDays = 0;
  StreamSubscription? _logsSub;
  StreamSubscription? _habitLogsSub;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _logsSub = db.watch('SELECT id FROM logs').listen((_) => _loadStats());
    _habitLogsSub = db.watch('SELECT id FROM habit_logs').listen((_) => _loadStats());
  }

  @override
  void dispose() {
    _logsSub?.cancel();
    _habitLogsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);

      final logRows = await db.getAll('SELECT xp_earned, timestamp FROM logs');
      final focusRows = await db.getAll(
          'SELECT xp_earned, started_at FROM focus_sessions WHERE completed = 1');

      int total = 0;
      int today = 0;

      for (final row in logRows) {
        final xp = (row['xp_earned'] as num?)?.toInt() ?? 0;
        total += xp;
        final ts = row['timestamp'] as String?;
        if (ts != null && ts.startsWith(todayStr)) {
          today += xp;
        }
      }

      for (final row in focusRows) {
        final xp = (row['xp_earned'] as num?)?.toInt() ?? 0;
        total += xp;
        final sa = row['started_at'] as String?;
        if (sa != null && sa.startsWith(todayStr)) {
          today += xp;
        }
      }

      final habitLogRows =
          await db.getAll('SELECT log_date, status FROM habit_logs');
      final streakLogs = habitLogRows
          .map((r) => StreakLog(r['log_date'] as String, r['status'] as String))
          .toList();
      final streak = StreakEngine.calculateStreak('daily', streakLogs, todayStr);
      await syncGlobalUserLevel();
      AppWidgetSyncService().syncAll();

      if (mounted) {
        setState(() {
          _totalXp = total;
          _todayXp = today;
          _streakDays = streak;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleTaskStatus(Task task, bool isDone) async {
    final updated = Task(
      id: task.id,
      title: task.title,
      notes: task.notes,
      status: isDone ? 'done' : 'todo',
      priority: task.priority,
      projectId: task.projectId,
      tags: task.tags,
      dueDate: task.dueDate,
      dueTime: task.dueTime,
      estimateMin: task.estimateMin,
      recurrenceRule: task.recurrenceRule,
      recurrenceMode: task.recurrenceMode,
    );
    await TaskRepository().updateTask(updated);

    if (isDone) {
      final xp = task.priority == 1 ? 75 : (task.priority == 2 ? 50 : 25);
      try {
        await db.execute('''
          INSERT INTO logs (id, task_id, event_type, xp_earned, timestamp)
          VALUES (?, ?, ?, ?, ?)
        ''', [
          'log_${DateTime.now().microsecondsSinceEpoch}',
          task.id,
          'task_completed',
          xp,
          DateTime.now().toUtc().toIso8601String(),
        ]);
      } catch (_) {}
    } else {
      try {
        await db.execute('DELETE FROM logs WHERE task_id = ? AND event_type = ?', [task.id, 'task_completed']);
      } catch (_) {}
    }
    await syncGlobalUserLevel();
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dayLabel = DateFormat('EEEE').format(now).toUpperCase();
    final dateLabel = DateFormat('d MMM yyyy').format(now);

    final level = GamificationEngine.calculateLevel(_totalXp);
    final currentLevelBaseXp = GamificationEngine.xpToReachLevel(level);
    final nextLevelXp = GamificationEngine.xpToReachLevel(level + 1);
    final span = nextLevelXp - currentLevelBaseXp;
    final progress =
        span > 0 ? ((_totalXp - currentLevelBaseXp) / span).clamp(0.0, 1.0) : 0.0;
    final rank = level >= 10
        ? 'CYBER KINETIC'
        : (level >= 5 ? 'CYBER OPERATIVE' : 'CYBER INITIATE');

    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];
        final now = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(now);

        // Filter strictly for today's active tasks, sorted by priority (P1 -> P2 -> P3)
        final pendingTasks = allTasks.where((t) {
          if (t.status == 'done') return false;
          if (t.dueDate == null || t.dueDate!.trim().isEmpty) return false;
          return t.dueDate == todayStr || t.dueDate!.startsWith(todayStr);
        }).toList()
          ..sort(compareTasksByPriority);

        final slottedTasks = allTasks.where((t) {
          final isToday = t.dueDate != null &&
              (t.dueDate == todayStr || t.dueDate!.startsWith(todayStr));
          if (!isToday) return false;
          if (t.dueTime != null && t.dueTime!.isNotEmpty) return true;
          if (t.estimateMin != null && t.estimateMin! <= 30) return true;
          return false;
        }).toList();

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),

                // ── Date header ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dayLabel,
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AxisColors.primarySoft,
                              ),
                        ),
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ],
                    ),
                    // Dynamic Streak badge
                    StreakBadge(
                      days: _streakDays,
                      isActive: _streakDays > 0,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── XP Cockpit Card ──────────────────────────────────────
                SizedBox(
                  height: 120,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -20,
                        right: -20,
                        child: Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AxisColors.primary.withValues(alpha: 0.06),
                            boxShadow: [
                              BoxShadow(
                                color: AxisColors.primary.withValues(alpha: 0.15),
                                blurRadius: 60,
                                spreadRadius: 20,
                              )
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -20,
                        left: -20,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AxisColors.secondary.withValues(alpha: 0.04),
                            boxShadow: [
                              BoxShadow(
                                color: AxisColors.secondary.withValues(alpha: 0.12),
                                blurRadius: 50,
                                spreadRadius: 15,
                              )
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: AxisCard(
                          tier: GlassTier.two,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AxisColors.surfaceLow,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: AxisColors.borderSubtle),
                                    ),
                                    child: const Icon(Icons.terminal_rounded,
                                        color: AxisColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              'Lv $level',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .displaySmall,
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AxisColors.secondary
                                                    .withValues(alpha: 0.18),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                rank,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: AxisColors
                                                          .secondarySoft,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text(
                                              '+$_todayXp XP',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelMedium
                                                  ?.copyWith(
                                                    color: AxisColors.tertiary,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'earned today',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: AxisColors.secondary,
                                            ),
                                      ),
                                      Text(
                                        'to Lv ${level + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: AxisColors.textMuted,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.bolt_rounded,
                                              color: AxisColors.primary,
                                              size: 12),
                                          const SizedBox(width: 3),
                                          Text(
                                            '$_totalXp / $nextLevelXp XP',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: AxisColors.textMuted,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  XpBar(progress: progress, height: 7),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ── Offline / Sync status pill ───────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AxisColors.tertiary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AxisColors.tertiary.withValues(alpha: 0.6),
                              blurRadius: 6,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'OFFLINE READY',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• 0MS LATENCY',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AxisColors.textMuted,
                                ),
                      ),
                      const Spacer(),
                      const Icon(Icons.cloud_done_rounded,
                          color: AxisColors.secondary, size: 15),
                      const SizedBox(width: 4),
                      Text(
                        'Instant Sync',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AxisColors.secondary,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── 15M Auto-Scheduler section ───────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            color: AxisColors.secondary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '15M MICRO SLOTS',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Auto-Scheduler recalculated idle gaps!'),
                            backgroundColor: AxisColors.secondary,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: AxisColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color:
                                  AxisColors.secondary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_fix_high_rounded,
                                color: AxisColors.secondary, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'RESCHEDULE',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AxisColors.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Scheduler card
                AxisCard(
                  tier: GlassTier.two,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // AI insight banner
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AxisColors.secondary
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.psychology_rounded,
                                  color: AxisColors.secondary, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                slottedTasks.isNotEmpty
                                    ? 'Auto-Scheduler slotted ${slottedTasks.length} micro-task${slottedTasks.length > 1 ? 's' : ''} into idle gaps.'
                                    : 'Auto-Scheduler ready. Tasks with estimated times will be slotted dynamically.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AxisColors.textHigh,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AxisColors.tertiary
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                slottedTasks.isNotEmpty ? 'OPTIMIZED' : 'READY',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AxisColors.tertiary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (slottedTasks.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceHigh.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hourglass_empty_rounded,
                                  color: AxisColors.secondary, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No Micro-Slots Scheduled',
                                      style: TextStyle(
                                        color: AxisColors.textHigh,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Tasks with scheduled times or short estimates appear here.',
                                      style: TextStyle(
                                        color: AxisColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...slottedTasks.map((t) {
                          final isDone = t.status == 'done';
                          final timeStr = t.dueTime != null
                              ? t.dueTime!
                              : '${t.estimateMin ?? 15}M Micro';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _TimeSlot(
                              time: timeStr,
                              title: t.title,
                              xp: t.priority == 1 ? 30 : 20,
                              isDone: isDone,
                              onToggle: (v) => _toggleTaskStatus(t, v),
                            ),
                          );
                        }),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Priority Matrix ───────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.view_timeline_rounded,
                            color: AxisColors.primarySoft, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'PRIORITY MATRIX',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    Text(
                      '${pendingTasks.length} REMAINING',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AxisColors.textMuted,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                if (pendingTasks.isEmpty)
                  AxisCard(
                    tier: GlassTier.one,
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AxisColors.primary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Icon(Icons.done_all_rounded,
                                color: AxisColors.primary, size: 22),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Tasks For Today',
                            style: TextStyle(
                              color: AxisColors.textHigh,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Your priority matrix for today is clean. Add a task to get started.',
                            style: TextStyle(
                              color: AxisColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => CreateTaskSheet(
                                  onTaskCreated: () => _loadStats(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AxisColors.primary,
                                    Color(0xFF6366F1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: AxisColors.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 16, color: Colors.white),
                                  SizedBox(width: 6),
                                  Text(
                                    'Create Task',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...pendingTasks.map((task) {
                    final isDone = task.status == 'done';
                    final badge = task.priority == 1
                        ? 'P1 CRITICAL'
                        : (task.priority == 2 ? 'P2 MEDIUM' : 'P3 LOW');
                    final xp = task.priority == 1
                        ? 75
                        : (task.priority == 2 ? 50 : 25);
                    final tag = task.tags != null && task.tags!.isNotEmpty
                        ? '@${task.tags!.split(',').first.trim().replaceAll('@', '')}'
                        : (task.projectId != null ? '#${task.projectId}' : 'Task');
                    final estimate = '${task.estimateMin ?? 15}m';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PriorityTaskCard(
                        priority: task.priority ?? 3,
                        badge: badge,
                        estimate: estimate,
                        tag: tag,
                        title: task.title,
                        subtitle: task.notes ??
                            (task.dueDate != null
                                ? 'Due: ${task.dueDate}'
                                : 'No notes added'),
                        xp: xp,
                        isDone: isDone,
                        onToggle: (v) => _toggleTaskStatus(task, v),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => TaskDetailSheet(
                              task: task,
                              onTaskUpdated: (_) => _loadStats(),
                            ),
                          );
                        },
                      ),
                    );
                  }),

                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Time slot row with left-accent rail
class _TimeSlot extends StatelessWidget {
  const _TimeSlot({
    required this.time,
    required this.title,
    required this.xp,
    required this.isDone,
    required this.onToggle,
  });

  final String time;
  final String title;
  final int xp;
  final bool isDone;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    const railColor = AxisColors.secondary;

    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: isDone
                    ? AxisColors.tertiary.withValues(alpha: 0.5)
                    : railColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    AxisCheckbox(
                      checked: isDone,
                      onChanged: onToggle,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                time,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AxisColors.secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AxisColors.secondary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'FITTED 15M',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AxisColors.secondary,
                                        fontSize: 9,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: isDone
                                      ? AxisColors.textDim
                                      : AxisColors.textHigh,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: AxisColors.textDim,
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+$xp XP',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AxisColors.secondary,
                            fontWeight: FontWeight.bold,
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
}

/// Priority Matrix task card
class _PriorityTaskCard extends StatelessWidget {
  const _PriorityTaskCard({
    required this.priority,
    required this.badge,
    required this.estimate,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.xp,
    required this.isDone,
    required this.onToggle,
    this.onTap,
  });

  final int priority;
  final String badge, estimate, tag, title, subtitle;
  final int xp;
  final bool isDone;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        priority == 1 ? AxisColors.error : (priority == 2 ? AxisColors.warning : AxisColors.primary);
    final badgeBg = priority == 1
        ? const Color(0x2993000A)
        : (priority == 2
            ? AxisColors.warning.withValues(alpha: 0.15)
            : AxisColors.primary.withValues(alpha: 0.14));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AxisCard(
        tier: GlassTier.one,
        padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AxisCheckbox(
              checked: isDone,
              onChanged: onToggle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(9999),
                        boxShadow: priority == 1
                            ? [
                                BoxShadow(
                                  color: AxisColors.error
                                      .withValues(alpha: 0.15),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        estimate,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AxisColors.secondary,
                            ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        tag,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AxisColors.primarySoft,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: AxisColors.textDim,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AxisColors.textMuted,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AxisColors.primarySoft.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+$xp XP',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.primarySoft,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
