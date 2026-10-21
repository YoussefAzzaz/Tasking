import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/powersync_db.dart' show globalUserLevel;
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/today/widgets/xp_cockpit_card.dart';
import 'package:axis/ui/today/widgets/micro_slots_section.dart';
import 'package:axis/ui/today/widgets/priority_task_card.dart';

export 'package:axis/ui/today/widgets/priority_task_card.dart';
export 'package:axis/ui/today/widgets/time_slot_card.dart';
export 'package:axis/ui/today/widgets/xp_cockpit_card.dart';
export 'package:axis/ui/today/widgets/micro_slots_section.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _totalXp = 0;
  int _todayXp = 0;
  int _streakDays = 0;
  StreamSubscription<UserStats>? _statsSub;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _statsSub = StatsRepository().watchStats().listen((stats) {
      if (mounted) {
        setState(() {
          _totalXp = stats.totalXp;
          _todayXp = stats.todayXp;
          _streakDays = stats.streakDays;
        });
      }
    });
    globalUserLevel.addListener(_onGlobalLevelChanged);
  }

  @override
  void dispose() {
    _statsSub?.cancel();
    globalUserLevel.removeListener(_onGlobalLevelChanged);
    super.dispose();
  }

  void _onGlobalLevelChanged() {
    _loadStats(forceRefresh: true);
  }

  Future<void> _loadStats({bool forceRefresh = false}) async {
    try {
      final stats = await StatsRepository().getUserStats(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _totalXp = stats.totalXp;
          _todayXp = stats.todayXp;
          _streakDays = stats.streakDays;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleTaskStatus(Task task, bool isDone) async {
    // Optimistic UI update
    final deltaXp = (task.priority == 1 ? 75 : (task.priority == 2 ? 50 : 25)) * (isDone ? 1 : -1);
    setState(() {
      _totalXp = (_totalXp + deltaXp).clamp(0, 9999999);
      _todayXp = (_todayXp + deltaXp).clamp(0, 9999999);
    });

    await TaskRepository().toggleTaskStatus(task, isDone);
    _loadStats(forceRefresh: true);
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
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AxisColors.primarySoft,
                                  ),
                        ),
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.displaySmall,
                        ),
                      ],
                    ),
                    StreakBadge(
                      days: _streakDays,
                      isActive: _streakDays > 0,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── XP Cockpit Card ──────────────────────────────────────
                XpCockpitCard(
                  level: level,
                  rank: rank,
                  todayXp: _todayXp,
                  totalXp: _totalXp,
                  nextLevelXp: nextLevelXp,
                  progress: progress,
                ),

                const SizedBox(height: 20),

                // ── Offline / Sync status pill ───────────────────────────
                _buildSyncStatusPill(context),

                const SizedBox(height: 24),

                // ── 15M Auto-Scheduler section ───────────────────────────
                MicroSlotsSection(
                  slottedTasks: slottedTasks,
                  onToggleTask: _toggleTaskStatus,
                ),

                const SizedBox(height: 24),

                // ── Priority Matrix ───────────────────────────────────────
                _buildPriorityMatrixHeader(context, pendingTasks.length),

                const SizedBox(height: 10),

                if (pendingTasks.isEmpty)
                  _buildEmptyPriorityMatrix(context)
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
                        : (task.projectId != null
                            ? '#${task.projectId}'
                            : 'Task');
                    final estimate = '${task.estimateMin ?? 15}m';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PriorityTaskCard(
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

  Widget _buildSyncStatusPill(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService().isOnlineNotifier,
      builder: (context, isOnline, _) {
        final dotColor = isOnline ? AxisColors.tertiary : AxisColors.warning;
        final statusText = isOnline ? 'ONLINE' : 'OFFLINE MODE';
        final subText = isOnline ? '• CLOUD SYNCED' : '• LOCAL SQLITE';
        final syncLabel = isOnline ? 'PowerSync Active' : 'Offline Ready';
        final icon = isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;
        final iconColor = isOnline ? AxisColors.secondary : AxisColors.warning;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withValues(alpha: 0.6),
                      blurRadius: 6,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.textHigh,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                subText,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.textMuted,
                    ),
              ),
              const Spacer(),
              Icon(icon, color: iconColor, size: 15),
              const SizedBox(width: 4),
              Text(
                syncLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: iconColor,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriorityMatrixHeader(BuildContext context, int count) {
    return Row(
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
          '$count REMAINING',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AxisColors.textMuted,
              ),
        ),
      ],
    );
  }

  Widget _buildEmptyPriorityMatrix(BuildContext context) {
    return AxisCard(
      tier: GlassTier.one,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
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
                  color: AxisColors.primary.withValues(alpha: 0.3),
                ),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      color: AxisColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 16, color: Colors.white),
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
    );
  }
}
