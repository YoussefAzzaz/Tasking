import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_card.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';
import 'package:axis/ui/tasks/tasks_empty_state.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/core/bloc/blocs.dart';

/// INBOX TAB (With reactive filter criteria, due date sorting, and cached stream)
class InboxTab extends StatefulWidget {
  const InboxTab({
    super.key,
    required this.repo,
    required this.filterCriteria,
  });

  final TaskRepository repo;
  final ValueNotifier<TaskFilterCriteria> filterCriteria;

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
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

            final allTasks = snapshot.data ?? [];
            final now = DateTime.now();
            final todayStr = DateFormat('yyyy-MM-dd').format(now);

            // Inbox tab displays only today's tasks (both completed and not completed)
            final todayTasks = allTasks.where((t) {
              if (t.dueDate == null || t.dueDate!.trim().isEmpty) return false;
              return t.dueDate == todayStr || t.dueDate!.startsWith(todayStr);
            }).toList();

            final filteredTasks = todayTasks.where(criteria.matches).toList()
              ..sort(compareTasksByDueDate);

            if (filteredTasks.isEmpty) {
              return TasksEmptyState(
                isFiltered: criteria.isActive,
                onReset: () =>
                    widget.filterCriteria.value = const TaskFilterCriteria(),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredTasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final task = filteredTasks[i];
                return TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  onToggle: (checked) async {
                    try {
                      context.read<TasksBloc>().add(
                        ToggleTaskStatusRequested(task: task, isDone: checked),
                      );
                    } catch (_) {
                      final updated = task.copyWith(status: checked ? 'done' : 'todo');
                      await widget.repo.updateTask(updated);
                    }
                  },
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TaskDetailSheet(task: task),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
