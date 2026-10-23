import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_card.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';
import 'package:axis/ui/tasks/tasks_empty_state.dart';

enum OutdatedFilterMode { all, outdated, finished }

/// OUTDATED & FINISHED TAB
/// Displays past-due (outdated) tasks and completed (finished) tasks
/// with real-time PowerSync reactive updates, Filter Studio criteria support,
/// and interactive filter pills.
class OutdatedTab extends StatefulWidget {
  const OutdatedTab({
    super.key,
    required this.repo,
    required this.filterCriteria,
  });

  final TaskRepository repo;
  final ValueNotifier<TaskFilterCriteria> filterCriteria;

  @override
  State<OutdatedTab> createState() => _OutdatedTabState();
}

class _OutdatedTabState extends State<OutdatedTab> {
  late final Stream<List<Task>> _tasksStream;
  OutdatedFilterMode _activeFilter = OutdatedFilterMode.all;

  @override
  void initState() {
    super.initState();
    _tasksStream = widget.repo.watchTasks();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TaskFilterCriteria>(
      valueListenable: widget.filterCriteria,
      builder: (context, criteria, _) {
        return StreamBuilder<List<Task>>(
          stream: _tasksStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AxisColors.primary),
              );
            }

            final tasks = snapshot.data ?? [];
            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

            final outdated = <Task>[];
            final finished = <Task>[];

            for (final t in tasks) {
              if (!criteria.matches(t)) continue;

              if (t.status == 'done') {
                finished.add(t);
              } else if (t.dueDate != null &&
                  t.dueDate!.trim().isNotEmpty &&
                  t.dueDate!.compareTo(todayStr) < 0) {
                outdated.add(t);
              }
            }

            // Sort outdated chronologically: oldest overdue first
            outdated.sort(compareTasksByDueDate);

            // Sort finished: most recently scheduled/due first
            finished.sort((a, b) {
              final aDue = a.dueDate;
              final bDue = b.dueDate;
              if (aDue != null && bDue != null) {
                final cmp = bDue.compareTo(aDue);
                if (cmp != 0) return cmp;
              }
              if (aDue != null && bDue == null) return -1;
              if (aDue == null && bDue != null) return 1;
              return a.title.toLowerCase().compareTo(b.title.toLowerCase());
            });

            final totalCount = outdated.length + finished.length;

            if (totalCount == 0) {
              if (criteria.isActive) {
                return TasksEmptyState(
                  isFiltered: true,
                  onReset: () =>
                      widget.filterCriteria.value = const TaskFilterCriteria(),
                );
              }
              return _buildEmptyState(
                icon: Icons.task_alt_rounded,
                accentColor: AxisColors.primary,
                title: 'No Outdated or Finished Tasks',
                subtitle:
                    'All active tasks are on schedule, and no completed tasks have been recorded yet.',
              );
            }

            final showOutdated = _activeFilter == OutdatedFilterMode.all ||
                _activeFilter == OutdatedFilterMode.outdated;
            final showFinished = _activeFilter == OutdatedFilterMode.all ||
                _activeFilter == OutdatedFilterMode.finished;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Top filter pill selectors (All | Outdated | Finished)
                _buildFilterPills(
                  allCount: totalCount,
                  outdatedCount: outdated.length,
                  finishedCount: finished.length,
                ),
                const SizedBox(height: 12),

                // Outdated / Overdue section
                if (showOutdated && outdated.isNotEmpty)
                  _OutdatedSection(
                    title: 'OUTDATED',
                    subtitle: 'Past due date • grouped by date • tap checkbox to mark complete',
                    color: AxisColors.error,
                    tasks: outdated,
                    repo: widget.repo,
                    groupByDate: true,
                  ),

                if (showOutdated &&
                    outdated.isEmpty &&
                    _activeFilter == OutdatedFilterMode.outdated)
                  _buildEmptyState(
                    icon: Icons.done_all_rounded,
                    accentColor: AxisColors.tertiary,
                    title: 'No Outdated Tasks',
                    subtitle:
                        'Great job! All your active tasks are up to date and within their deadlines.',
                  ),

                // Finished / Completed section
                if (showFinished && finished.isNotEmpty) ...[
                  if (showOutdated && outdated.isNotEmpty)
                    const SizedBox(height: 10),
                  _OutdatedSection(
                    title: 'FINISHED',
                    subtitle: 'Completed tasks • tap checkbox to restore to todo',
                    color: AxisColors.tertiary,
                    tasks: finished,
                    repo: widget.repo,
                  ),
                ],

                if (showFinished &&
                    finished.isEmpty &&
                    _activeFilter == OutdatedFilterMode.finished)
                  _buildEmptyState(
                    icon: Icons.fact_check_outlined,
                    accentColor: AxisColors.secondary,
                    title: 'No Finished Tasks',
                    subtitle:
                        'Completed tasks will appear here as a record of your achievements.',
                  ),

                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterPills({
    required int allCount,
    required int outdatedCount,
    required int finishedCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        children: [
          _buildPillItem(
            label: 'All',
            count: allCount,
            isSelected: _activeFilter == OutdatedFilterMode.all,
            activeColor: AxisColors.primary,
            onTap: () => setState(() => _activeFilter = OutdatedFilterMode.all),
          ),
          const SizedBox(width: 4),
          _buildPillItem(
            label: 'Outdated',
            count: outdatedCount,
            isSelected: _activeFilter == OutdatedFilterMode.outdated,
            activeColor: AxisColors.error,
            dotColor: AxisColors.error,
            onTap: () =>
                setState(() => _activeFilter = OutdatedFilterMode.outdated),
          ),
          const SizedBox(width: 4),
          _buildPillItem(
            label: 'Finished',
            count: finishedCount,
            isSelected: _activeFilter == OutdatedFilterMode.finished,
            activeColor: AxisColors.tertiary,
            dotColor: AxisColors.tertiary,
            onTap: () =>
                setState(() => _activeFilter = OutdatedFilterMode.finished),
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required String label,
    required int count,
    required bool isSelected,
    required Color activeColor,
    Color? dotColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.5)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AxisColors.textDim,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.3)
                      : AxisColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AxisColors.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, size: 28, color: accentColor),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutdatedSection extends StatelessWidget {
  const _OutdatedSection({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.tasks,
    required this.repo,
    this.groupByDate = false,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<Task> tasks;
  final TaskRepository repo;
  final bool groupByDate;

  Map<String, List<Task>> _groupTasksByDate(List<Task> tasks) {
    final Map<String, List<Task>> map = {};
    for (final t in tasks) {
      final key = (t.dueDate != null && t.dueDate!.trim().isNotEmpty)
          ? t.dueDate!.trim()
          : 'no_date';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  String _formatDateHeader(String dateStr) {
    if (dateStr == 'no_date') return 'NO DUE DATE';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr.toUpperCase();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(target).inDays;

    final dateFormatted = DateFormat('EEE, MMM d').format(dt);

    if (diffDays == 1) {
      return 'YESTERDAY • $dateFormatted';
    } else if (diffDays > 1) {
      return '$diffDays DAYS OVERDUE • $dateFormatted';
    } else if (diffDays == 0) {
      return 'TODAY • $dateFormatted';
    } else {
      return dateFormatted.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${tasks.length})',
                    style:
                        const TextStyle(fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AxisColors.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (groupByDate) ...[
          for (final entry in _groupTasksByDate(tasks).entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 13, color: color),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateHeader(entry.key),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.length}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...entry.value.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskCard(
                  task: task,
                  onToggle: (checked) async {
                    final updated = Task(
                      id: task.id,
                      title: task.title,
                      notes: task.notes,
                      status: checked ? 'done' : 'todo',
                      priority: task.priority,
                      projectId: task.projectId,
                      tags: task.tags,
                      dueDate: task.dueDate,
                      dueTime: task.dueTime,
                      estimateMin: task.estimateMin,
                      recurrenceRule: task.recurrenceRule,
                      recurrenceMode: task.recurrenceMode,
                    );
                    await repo.updateTask(updated);
                  },
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TaskDetailSheet(task: task),
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskCard(
                task: task,
                onToggle: (checked) async {
                  final updated = Task(
                    id: task.id,
                    title: task.title,
                    notes: task.notes,
                    status: checked ? 'done' : 'todo',
                    priority: task.priority,
                    projectId: task.projectId,
                    tags: task.tags,
                    dueDate: task.dueDate,
                    dueTime: task.dueTime,
                    estimateMin: task.estimateMin,
                    recurrenceRule: task.recurrenceRule,
                    recurrenceMode: task.recurrenceMode,
                  );
                  await repo.updateTask(updated);
                },
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => TaskDetailSheet(task: task),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
