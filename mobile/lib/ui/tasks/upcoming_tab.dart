import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_card.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';
import 'package:axis/ui/tasks/tasks_empty_state.dart';

/// UPCOMING TAB (Chronologically grouped with cached stream & filter criteria)
class UpcomingTab extends StatefulWidget {
  const UpcomingTab({
    super.key,
    required this.repo,
    required this.filterCriteria,
  });

  final TaskRepository repo;
  final ValueNotifier<TaskFilterCriteria> filterCriteria;

  @override
  State<UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<UpcomingTab> {
  late final Stream<List<Task>> _tasksStream;

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
            if (tasks.isEmpty) return const TasksEmptyState();

            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final tomorrowStr = DateFormat('yyyy-MM-dd')
                .format(DateTime.now().add(const Duration(days: 1)));

            final overdue = <Task>[];
            final today = <Task>[];
            final tomorrow = <Task>[];
            final upcoming = <Task>[];
            final noDate = <Task>[];

            for (final t in tasks) {
              if (t.status == 'done') continue;
              if (!criteria.matches(t)) continue;

              if (t.dueDate == null) {
                noDate.add(t);
              } else if (t.dueDate!.compareTo(todayStr) < 0) {
                overdue.add(t);
              } else if (t.dueDate == todayStr) {
                today.add(t);
              } else if (t.dueDate == tomorrowStr) {
                tomorrow.add(t);
              } else {
                upcoming.add(t);
              }
            }

            if (overdue.isEmpty &&
                today.isEmpty &&
                tomorrow.isEmpty &&
                upcoming.isEmpty &&
                noDate.isEmpty) {
              return TasksEmptyState(
                isFiltered: criteria.isActive,
                onReset: () =>
                    widget.filterCriteria.value = const TaskFilterCriteria(),
              );
            }

            // Sort each bucket chronologically
            overdue.sort(compareTasksByDueDate);
            today.sort(compareTasksByDueDate);
            tomorrow.sort(compareTasksByDueDate);
            upcoming.sort(compareTasksByDueDate);
            noDate.sort(compareTasksByDueDate);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (overdue.isNotEmpty)
                  UpcomingSection(
                    title: 'OVERDUE',
                    color: AxisColors.error,
                    tasks: overdue,
                    repo: widget.repo,
                  ),
                if (today.isNotEmpty)
                  UpcomingSection(
                    title: 'TODAY',
                    color: AxisColors.primary,
                    tasks: today,
                    repo: widget.repo,
                  ),
                if (tomorrow.isNotEmpty)
                  UpcomingSection(
                    title: 'TOMORROW',
                    color: AxisColors.secondary,
                    tasks: tomorrow,
                    repo: widget.repo,
                  ),
                if (upcoming.isNotEmpty)
                  UpcomingSection(
                    title: 'LATER THIS MONTH',
                    color: AxisColors.tertiary,
                    tasks: upcoming,
                    repo: widget.repo,
                  ),
                if (noDate.isNotEmpty)
                  UpcomingSection(
                    title: 'NO DUE DATE',
                    color: AxisColors.textDim,
                    tasks: noDate,
                    repo: widget.repo,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class UpcomingSection extends StatelessWidget {
  const UpcomingSection({
    super.key,
    required this.title,
    required this.color,
    required this.tasks,
    required this.repo,
  });

  final String title;
  final Color color;
  final List<Task> tasks;
  final TaskRepository repo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                style: const TextStyle(fontSize: 11, color: AxisColors.textDim),
              ),
            ],
          ),
        ),
        ...tasks.map((task) => Padding(
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
            )),
      ],
    );
  }
}
