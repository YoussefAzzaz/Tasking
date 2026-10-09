import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/task_card.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';

/// Tasks tab — Inbox, Upcoming, Projects, Filters segments
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _repo = TaskRepository();

  static const _segments = ['Inbox', 'Upcoming', 'Projects', 'Filters'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _segments.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Text('Tasks',
              style: Theme.of(context).textTheme.displaySmall),
        ),
        const SizedBox(height: 12),

        // Segment pill tabs
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AxisColors.surfaceHigh.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AxisColors.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AxisColors.primary.withOpacity(0.3), width: 1),
              ),
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AxisColors.primarySoft,
              ),
              unselectedLabelStyle:
                  Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AxisColors.textDim,
              ),
              tabs: _segments.map((s) => Tab(text: s)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Tab views
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _InboxTab(repo: _repo),
              _PlaceholderTab(label: 'Upcoming'),
              _PlaceholderTab(label: 'Projects'),
              _PlaceholderTab(label: 'Filters'),
            ],
          ),
        ),
      ],
    );
  }
}

class _InboxTab extends StatelessWidget {
  const _InboxTab({required this.repo});
  final TaskRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: repo.watchTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AxisColors.primary),
          );
        }

        final tasks = snapshot.data ?? [];
        if (tasks.isEmpty) {
          return _EmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final task = tasks[i];
            return TaskCard(
              task: task,
              onToggle: (checked) async {
                final updated = Task(
                  id: task.id,
                  title: task.title,
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
            );
          },
        );
      },
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_rounded,
              size: 40, color: AxisColors.textDim),
          const SizedBox(height: 12),
          Text(label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AxisColors.textDim,
              )),
          Text('Coming soon',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AxisColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AxisColors.primary.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                size: 32, color: AxisColors.primarySoft),
          ),
          const SizedBox(height: 16),
          Text('All clear',
              style: Theme.of(context).textTheme.displaySmall),
          const SizedBox(height: 4),
          Text('Tap + to add your first task',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
