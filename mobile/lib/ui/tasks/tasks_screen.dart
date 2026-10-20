import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/ui/tasks/task_card.dart';
import 'package:axis/ui/tasks/task_detail_sheet.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/create_project_sheet.dart';
import 'package:axis/ui/common/axis_sliding_segmented_bar.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _taskRepo = TaskRepository();
  final _projectRepo = ProjectRepository();
  int _currentTabIndex = 0;

  static const _segments = ['Inbox', 'Upcoming', 'Projects'];
  late final List<Widget> _tabs;
  final _filterCriteria = ValueNotifier<TaskFilterCriteria>(const TaskFilterCriteria());

  @override
  void initState() {
    super.initState();
    // Instantiate all tab panels once so switching between them does not recreate them
    _tabs = [
      _InboxTab(repo: _taskRepo, filterCriteria: _filterCriteria),
      _UpcomingTab(repo: _taskRepo, filterCriteria: _filterCriteria),
      _ProjectsTab(
        taskRepo: _taskRepo,
        projectRepo: _projectRepo,
        onAddProject: _openCreateProject,
        onAddTask: _openCreateTask,
      ),
    ];
  }

  @override
  void dispose() {
    _filterCriteria.dispose();
    super.dispose();
  }

  void _openCreateTask({String? initialProject}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTaskSheet(
        onTaskCreated: () => setState(() {}),
      ),
    );
  }

  void _openCreateProject() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateProjectSheet(
        onProjectCreated: () => setState(() {}),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskFilterSheet(
        filterCriteria: _filterCriteria,
        repo: _taskRepo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Screen title row with Filter Studio trigger & "+ New Task" button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tasks', style: Theme.of(context).textTheme.displaySmall),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter Button with active indicator and badge
                  ValueListenableBuilder<TaskFilterCriteria>(
                    valueListenable: _filterCriteria,
                    builder: (context, criteria, _) {
                      final isActive = criteria.isActive;
                      return InkWell(
                        onTap: _openFilterSheet,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AxisColors.primary.withValues(alpha: 0.18)
                                : AxisColors.surfaceLow,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isActive
                                  ? AxisColors.primary
                                  : AxisColors.borderPrimary,
                              width: isActive ? 1.4 : 1,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: AxisColors.primary
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 0,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: isActive
                                    ? AxisColors.primary
                                    : AxisColors.textDim,
                                size: 18,
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AxisColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${criteria.activeCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // New Task Button
                  InkWell(
                    onTap: () => _openCreateTask(),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AxisColors.primary, Color(0xFF6366F1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AxisColors.primary.withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'New Task',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Smooth sliding segmented bar: single indicator pill
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AxisSlidingSegmentedBar(
            segments: _segments,
            selectedIndex: _currentTabIndex,
            activeColor: AxisColors.primary,
            onSegmentSelected: (index) {
              if (_currentTabIndex != index) {
                setState(() => _currentTabIndex = index);
              }
            },
          ),
        ),
        const SizedBox(height: 10),

        // Tab Views powered by IndexedStack: preserves all tab state with zero re-creation
        Expanded(
          child: IndexedStack(
            index: _currentTabIndex,
            children: _tabs,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// INBOX TAB (With reactive filter criteria & cached stream)
// ---------------------------------------------------------------------------
class _InboxTab extends StatefulWidget {
  const _InboxTab({
    required this.repo,
    required this.filterCriteria,
  });

  final TaskRepository repo;
  final ValueNotifier<TaskFilterCriteria> filterCriteria;

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
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
            final filteredTasks = allTasks.where(criteria.matches).toList();

            if (filteredTasks.isEmpty) {
              return _EmptyState(
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
                    await widget.repo.updateTask(updated);
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

// ---------------------------------------------------------------------------
// UPCOMING TAB (Chronologically grouped with cached stream & filter criteria)
// ---------------------------------------------------------------------------
class _UpcomingTab extends StatefulWidget {
  const _UpcomingTab({
    required this.repo,
    required this.filterCriteria,
  });

  final TaskRepository repo;
  final ValueNotifier<TaskFilterCriteria> filterCriteria;

  @override
  State<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<_UpcomingTab> {
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
            if (tasks.isEmpty) return const _EmptyState();

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
              return _EmptyState(
                isFiltered: criteria.isActive,
                onReset: () =>
                    widget.filterCriteria.value = const TaskFilterCriteria(),
              );
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (overdue.isNotEmpty)
                  _UpcomingSection(
                    title: 'OVERDUE',
                    color: AxisColors.error,
                    tasks: overdue,
                    repo: widget.repo,
                  ),
                if (today.isNotEmpty)
                  _UpcomingSection(
                    title: 'TODAY',
                    color: AxisColors.primary,
                    tasks: today,
                    repo: widget.repo,
                  ),
                if (tomorrow.isNotEmpty)
                  _UpcomingSection(
                    title: 'TOMORROW',
                    color: AxisColors.secondary,
                    tasks: tomorrow,
                    repo: widget.repo,
                  ),
                if (upcoming.isNotEmpty)
                  _UpcomingSection(
                    title: 'LATER THIS MONTH',
                    color: AxisColors.tertiary,
                    tasks: upcoming,
                    repo: widget.repo,
                  ),
                if (noDate.isNotEmpty)
                  _UpcomingSection(
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

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({
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

// ---------------------------------------------------------------------------
// PROJECTS TAB (Projects as Big Tasks with Subtasks & Progress Bars)
// ---------------------------------------------------------------------------
class _ProjectsTab extends StatefulWidget {
  const _ProjectsTab({
    required this.taskRepo,
    required this.projectRepo,
    required this.onAddProject,
    required this.onAddTask,
  });

  final TaskRepository taskRepo;
  final ProjectRepository projectRepo;
  final VoidCallback onAddProject;
  final VoidCallback onAddTask;

  @override
  State<_ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<_ProjectsTab> {
  late final Stream<List<Project>> _projectsStream;
  late final Stream<List<Task>> _tasksStream;
  static final Set<String> _locallyDeletedProjects = {};

  @override
  void initState() {
    super.initState();
    _projectsStream = widget.projectRepo.watchProjects();
    _tasksStream = widget.taskRepo.watchTasks();
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Project>>(
      stream: _projectsStream,
      builder: (context, projSnapshot) {
        return StreamBuilder<List<Task>>(
          stream: _tasksStream,
          builder: (context, taskSnapshot) {
            if (projSnapshot.connectionState == ConnectionState.waiting &&
                taskSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AxisColors.primary),
              );
            }

            final customProjects = projSnapshot.data ?? [];
            final allTasks = taskSnapshot.data ?? [];

            // Discovered projects from tasks' projectId if not in DB
            final projectNames = <String>{};
            for (final p in customProjects) {
              projectNames.add(p.name.toLowerCase());
            }

            final discoveredProjects = <Project>[];
            for (final t in allTasks) {
              if (t.projectId != null &&
                  t.projectId!.trim().isNotEmpty &&
                  !projectNames.contains(t.projectId!.trim().toLowerCase())) {
                projectNames.add(t.projectId!.trim().toLowerCase());
                discoveredProjects.add(Project(
                  id: 'discovered_${t.projectId}',
                  name: t.projectId!.trim(),
                  color: '#06B6D4',
                ));
              }
            }

            final allProjects = [...customProjects, ...discoveredProjects].where((p) {
              final idLower = p.id.toLowerCase();
              final nameLower = p.name.toLowerCase();
              return !_locallyDeletedProjects.contains(idLower) &&
                     !_locallyDeletedProjects.contains(nameLower) &&
                     !_locallyDeletedProjects.contains(idLower.replaceFirst('discovered_', ''));
            }).toList();

            // Defaults if empty and no project has been deleted
            if (customProjects.isEmpty && discoveredProjects.isEmpty) {
              final defaults = [
                Project(id: 'work', name: 'Work', color: '#6366F1'),
                Project(id: 'personal', name: 'Personal', color: '#10B981'),
                Project(id: 'growth', name: 'Growth', color: '#F59E0B'),
              ].where((p) =>
                  !_locallyDeletedProjects.contains(p.id.toLowerCase()) &&
                  !_locallyDeletedProjects.contains(p.name.toLowerCase())).toList();
              allProjects.addAll(defaults);
            }

            // Separate tasks by project
            final Map<String, List<Task>> tasksByProject = {};
            final unassignedTasks = <Task>[];

            for (final t in allTasks) {
              if (t.projectId == null || t.projectId!.isEmpty) {
                unassignedTasks.add(t);
                continue;
              }

              final matchedProj = allProjects.firstWhere(
                (p) =>
                    p.id == t.projectId ||
                    p.name.toLowerCase() == t.projectId!.toLowerCase(),
                orElse: () => Project(id: '', name: ''),
              );

              if (matchedProj.name.isNotEmpty) {
                tasksByProject
                    .putIfAbsent(matchedProj.name, () => [])
                    .add(t);
              } else {
                unassignedTasks.add(t);
              }
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Header banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLow.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: const [
                            Icon(Icons.hub_rounded,
                                color: AxisColors.secondary, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'PROJECT OBJECTIVES',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AxisColors.secondary,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: widget.onAddProject,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          backgroundColor:
                              AxisColors.secondary.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.add_rounded,
                            size: 14, color: AxisColors.secondary),
                        label: const Text('Add Project',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.secondary)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // List of Projects as Big Tasks
                ...allProjects.map((project) {
                  final subtasks = tasksByProject[project.name] ?? [];
                  final color = _parseHex(project.color);

                  return _ProjectBigTaskCard(
                    project: project,
                    color: color,
                    subtasks: subtasks,
                    taskRepo: widget.taskRepo,
                    projectRepo: widget.projectRepo,
                    onAddSubtask: widget.onAddTask,
                    onDelete: () {
                      setState(() {
                        _locallyDeletedProjects.add(project.id.toLowerCase());
                        _locallyDeletedProjects.add(project.name.toLowerCase());
                        final raw = project.id.toLowerCase().replaceFirst('discovered_', '');
                        _locallyDeletedProjects.add(raw);
                      });
                    },
                  );
                }),

                // Unassigned / General Tasks section if any
                if (unassignedTasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _ProjectBigTaskCard(
                    project: Project(
                      id: 'inbox_general',
                      name: 'Inbox & General Tasks',
                      color: '#64748B',
                    ),
                    color: const Color(0xFF64748B),
                    subtasks: unassignedTasks,
                    taskRepo: widget.taskRepo,
                    projectRepo: widget.projectRepo,
                    onAddSubtask: widget.onAddTask,
                  ),
                ],
                const SizedBox(height: 32),
              ],
            );
          },
        );
      },
    );
  }
}

class _ProjectBigTaskCard extends StatefulWidget {
  const _ProjectBigTaskCard({
    required this.project,
    required this.color,
    required this.subtasks,
    required this.taskRepo,
    required this.projectRepo,
    required this.onAddSubtask,
    this.onDelete,
  });

  final Project project;
  final Color color;
  final List<Task> subtasks;
  final TaskRepository taskRepo;
  final ProjectRepository projectRepo;
  final VoidCallback onAddSubtask;
  final VoidCallback? onDelete;

  @override
  State<_ProjectBigTaskCard> createState() => _ProjectBigTaskCardState();
}

class _ProjectBigTaskCardState extends State<_ProjectBigTaskCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final total = widget.subtasks.length;
    final done = widget.subtasks.where((t) => t.status == 'done').length;
    final progress = total > 0 ? (done / total) : 0.0;
    final percent = (progress * 100).toInt();
    final isComplete = total > 0 && done == total;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete
              ? AxisColors.success.withValues(alpha: 0.6)
              : widget.color.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Main Header (Treating Project as a Big Task)
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: widget.color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.folder_open_rounded,
                                  color: widget.color, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.project.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AxisColors.textHigh,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$done of $total subtasks finished',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AxisColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isComplete)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AxisColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: AxisColors.success.withValues(alpha: 0.5)),
                              ),
                              child: const Text('DONE',
                                  style: TextStyle(
                                      color: AxisColors.success,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            )
                          else
                            Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: widget.color,
                              ),
                            ),
                          const SizedBox(width: 6),
                          if (widget.project.id != 'inbox_general')
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AxisColors.textDim),
                              tooltip: 'Delete project',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                  minWidth: 26, minHeight: 26),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AxisColors.surfaceLow,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(
                                          color: AxisColors.borderPrimary),
                                    ),
                                    title: const Text('Delete Project?',
                                        style: TextStyle(
                                            color: AxisColors.textHigh)),
                                    content: Text(
                                      'Are you sure you want to delete "${widget.project.name}"? Tasks in this project will be kept but unassigned.',
                                      style: const TextStyle(
                                          color: AxisColors.textMuted),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel',
                                            style: TextStyle(
                                                color: AxisColors.textDim)),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: AxisColors.error),
                                        onPressed: () async {
                                          Navigator.pop(ctx);
                                          final projId = widget.project.id;
                                          final projName = widget.project.name;
                                          final rawId = projId.replaceFirst('discovered_', '');

                                          // First explicitly unassign all subtasks in memory
                                          if (widget.subtasks.isNotEmpty) {
                                            for (final t in widget.subtasks) {
                                              try {
                                                await db.execute('UPDATE tasks SET project_id = NULL WHERE id = ?', [t.id]);
                                              } catch (_) {}
                                            }
                                          }

                                          try {
                                            await db.execute('''
                                              UPDATE tasks 
                                              SET project_id = NULL 
                                              WHERE project_id = ? 
                                                 OR project_id = ? 
                                                 OR LOWER(COALESCE(project_id, '')) = LOWER(?) 
                                                 OR LOWER(COALESCE(project_id, '')) = LOWER(?)
                                            ''', [projId, rawId, projId, projName]);

                                            await db.execute('''
                                              DELETE FROM projects 
                                              WHERE id = ? 
                                                 OR id = ?
                                                 OR LOWER(name) = LOWER(?)
                                            ''', [projId, rawId, projName]);
                                          } catch (e) {
                                            debugPrint('Error deleting project: $e');
                                          }

                                          widget.onDelete?.call();

                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Project "${widget.project.name}" deleted'),
                                                backgroundColor: AxisColors.surfaceLow,
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text('Delete',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: AxisColors.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar for Project Finished Tasks
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                            height: 8,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isComplete
                                    ? [AxisColors.success, const Color(0xFF059669)]
                                    : [
                                        widget.color,
                                        widget.color.withValues(alpha: 0.8)
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(
                                  color: (isComplete
                                          ? AxisColors.success
                                          : widget.color)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subtasks breakdown
          if (_expanded) ...[
            const Divider(color: AxisColors.borderSubtle, height: 1),
            if (widget.subtasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Center(
                  child: Text(
                    'No subtasks created for this project yet.',
                    style: TextStyle(color: AxisColors.textDim, fontSize: 12),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: widget.subtasks.length,
                separatorBuilder: (_, _) =>
                    const Divider(color: AxisColors.borderGlass2, height: 1),
                itemBuilder: (context, i) {
                  final task = widget.subtasks[i];
                  final isDone = task.status == 'done';

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      value: isDone,
                      activeColor: widget.color,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      onChanged: (checked) async {
                        final updated = Task(
                          id: task.id,
                          title: task.title,
                          notes: task.notes,
                          status: (checked ?? false) ? 'done' : 'todo',
                          priority: task.priority,
                          projectId: task.projectId,
                          tags: task.tags,
                          dueDate: task.dueDate,
                          dueTime: task.dueTime,
                          estimateMin: task.estimateMin,
                          recurrenceRule: task.recurrenceRule,
                          recurrenceMode: task.recurrenceMode,
                        );
                        await widget.taskRepo.updateTask(updated);
                      },
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isDone ? AxisColors.textDim : AxisColors.textHigh,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: task.dueDate != null
                        ? Text(
                            'Due: ${task.dueDate}',
                            style: const TextStyle(
                                fontSize: 11, color: AxisColors.textMuted),
                          )
                        : null,
                    trailing: task.priority != null
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPriorityColor(task.priority!)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'P${task.priority}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getPriorityColor(task.priority!),
                              ),
                            ),
                          )
                        : null,
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => TaskDetailSheet(task: task),
                    ),
                  );
                },
              ),
            // Bottom Add Subtask button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: InkWell(
                onTap: widget.onAddSubtask,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 14, color: widget.color),
                      const SizedBox(width: 6),
                      Text(
                        'Add Subtask to ${widget.project.name}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getPriorityColor(int p) {
    switch (p) {
      case 1:
        return AxisColors.priorityHigh;
      case 2:
        return AxisColors.priorityMed;
      case 3:
        return AxisColors.priorityLow;
      default:
        return AxisColors.textDim;
    }
  }
}

// ---------------------------------------------------------------------------
// TASK FILTER CRITERIA MODEL
// ---------------------------------------------------------------------------
class TaskFilterCriteria {
  final int? priority;
  final String? dueDateOption;
  final DateTime? customDate;
  final Set<String> tags;

  const TaskFilterCriteria({
    this.priority,
    this.dueDateOption,
    this.customDate,
    this.tags = const {},
  });

  bool get isActive =>
      priority != null ||
      dueDateOption != null ||
      customDate != null ||
      tags.isNotEmpty;

  int get activeCount {
    int count = 0;
    if (priority != null) count++;
    if (dueDateOption != null || customDate != null) count++;
    if (tags.isNotEmpty) count += tags.length;
    return count;
  }

  bool matches(Task t) {
    // 1. Priority filter
    if (priority != null && t.priority != priority) {
      return false;
    }

    // 2. Due Date filter
    if (dueDateOption != null) {
      if (t.dueDate == null) return false;
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final tomorrowStr = DateFormat('yyyy-MM-dd')
          .format(now.add(const Duration(days: 1)));

      switch (dueDateOption) {
        case 'today':
          if (t.dueDate != todayStr) return false;
          break;
        case 'tomorrow':
          if (t.dueDate != tomorrowStr) return false;
          break;
        case 'overdue':
          if (t.dueDate!.compareTo(todayStr) >= 0) return false;
          break;
        case 'upcoming':
          if (t.dueDate!.compareTo(todayStr) <= 0) return false;
          break;
        case 'custom':
          if (customDate != null) {
            final customStr =
                DateFormat('yyyy-MM-dd').format(customDate!);
            if (t.dueDate != customStr) return false;
          }
          break;
      }
    }

    // 3. Tag filter: every selected tag must be in task's tags
    if (tags.isNotEmpty) {
      if (t.tags == null || t.tags!.isEmpty) return false;
      final taskTags = t.tags!
          .toLowerCase()
          .split(',')
          .map((e) => e.trim().replaceAll('@', ''))
          .where((e) => e.isNotEmpty)
          .toSet();
      for (final requiredTag in tags) {
        if (!taskTags.contains(requiredTag.toLowerCase().replaceAll('@', ''))) {
          return false;
        }
      }
    }

    return true;
  }
}

// ---------------------------------------------------------------------------
// FILTER DROPDOWN OPTION WIDGET
// ---------------------------------------------------------------------------
class _FilterDropdownOption extends StatelessWidget {
  const _FilterDropdownOption({
    this.icon,
    this.iconColor,
    required this.title,
    this.isSelected = false,
    this.isAction = false,
    required this.onTap,
  });

  final IconData? icon;
  final Color? iconColor;
  final String title;
  final bool isSelected;
  final bool isAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.surfaceHigh.withValues(alpha: 0.6)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: AxisColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? AxisColors.textMuted),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isAction
                      ? (iconColor ?? AxisColors.secondary)
                      : (isSelected ? AxisColors.textHigh : AxisColors.textMuted),
                  fontSize: 13,
                  fontWeight:
                      isSelected || isAction ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: AxisColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TASK FILTER SHEET (Modal with the Filter Card and Reset Filter inside)
// ---------------------------------------------------------------------------
class _TaskFilterSheet extends StatefulWidget {
  const _TaskFilterSheet({
    required this.filterCriteria,
    required this.repo,
  });

  final ValueNotifier<TaskFilterCriteria> filterCriteria;
  final TaskRepository repo;

  @override
  State<_TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<_TaskFilterSheet> {
  late int? _selectedPriority;
  late String? _selectedDueDateOption;
  late DateTime? _pickedCustomDate;
  late Set<String> _selectedTags;
  late final Stream<List<Task>> _tasksStream;

  final _tagInputController = TextEditingController();
  final _tagFocusNode = FocusNode();
  bool _showTagDropdown = false;
  final List<String> _existingTags = [];

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.filterCriteria.value.priority;
    _selectedDueDateOption = widget.filterCriteria.value.dueDateOption;
    _pickedCustomDate = widget.filterCriteria.value.customDate;
    _selectedTags = Set<String>.from(widget.filterCriteria.value.tags);
    _tasksStream = widget.repo.watchTasks();

    _tagFocusNode.addListener(() {
      if (_tagFocusNode.hasFocus) {
        setState(() {
          _showTagDropdown = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  void _addCurrentTag() {
    final raw = _tagInputController.text.trim().replaceAll('@', '');
    if (raw.isNotEmpty) {
      setState(() {
        _selectedTags.add(raw);
        if (!_existingTags.contains(raw)) {
          _existingTags.add(raw);
          _existingTags.sort();
        }
        _tagInputController.clear();
      });
    }
  }

  List<Widget> _buildTagDropdownItems() {
    final query =
        _tagInputController.text.trim().toLowerCase().replaceAll('@', '');
    final List<Widget> items = [];

    // All tags (clear filter) option
    if (_selectedTags.isNotEmpty) {
      items.add(
        _FilterDropdownOption(
          icon: Icons.label_off_rounded,
          iconColor: AxisColors.textMuted,
          title: 'All Tags (Clear filter)',
          isAction: true,
          onTap: () {
            setState(() {
              _selectedTags.clear();
              _tagInputController.clear();
              _showTagDropdown = false;
              _tagFocusNode.unfocus();
            });
          },
        ),
      );
    }

    final filtered = _existingTags.where((tag) {
      if (query.isEmpty) return true;
      return tag.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty && query.isEmpty && _selectedTags.isEmpty) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            'Type to search or add tag...',
            style: TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    for (final tag in filtered) {
      final isSelected = _selectedTags.contains(tag);
      items.add(
        _FilterDropdownOption(
          icon: Icons.label_outline_rounded,
          iconColor: AxisColors.primary,
          title: '@$tag',
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedTags.remove(tag);
              } else {
                _selectedTags.add(tag);
              }
              _tagInputController.clear();
              _showTagDropdown = false;
              _tagFocusNode.unfocus();
            });
          },
        ),
      );
    }

    // Quick add option if query is non-empty and not already in list
    final exactMatch = _existingTags.any((t) => t.toLowerCase() == query);
    if (query.isNotEmpty && !exactMatch) {
      final rawTyped = _tagInputController.text.trim().replaceAll('@', '');
      items.add(
        _FilterDropdownOption(
          icon: Icons.add_rounded,
          iconColor: AxisColors.primary,
          title: 'Add tag "@$rawTyped"',
          isAction: true,
          onTap: () {
            _addCurrentTag();
            setState(() {
              _showTagDropdown = false;
              _tagFocusNode.unfocus();
            });
          },
        ),
      );
    }

    return items;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedCustomDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: AxisTheme.dark.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AxisColors.primary,
              surface: AxisColors.surfaceHigh,
              onSurface: AxisColors.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _pickedCustomDate = picked;
        _selectedDueDateOption = 'custom';
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedPriority = null;
      _selectedDueDateOption = null;
      _selectedTags.clear();
      _pickedCustomDate = null;
      _tagInputController.clear();
      _showTagDropdown = false;
    });
    widget.filterCriteria.value = const TaskFilterCriteria();
  }

  void _applyFilters() {
    widget.filterCriteria.value = TaskFilterCriteria(
      priority: _selectedPriority,
      dueDateOption: _selectedDueDateOption,
      customDate: _pickedCustomDate,
      tags: Set<String>.from(_selectedTags),
    );
  }

  bool _matchesCurrent(Task t) {
    final tempCriteria = TaskFilterCriteria(
      priority: _selectedPriority,
      dueDateOption: _selectedDueDateOption,
      customDate: _pickedCustomDate,
      tags: _selectedTags,
    );
    return tempCriteria.matches(t);
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _selectedPriority != null ||
        _selectedDueDateOption != null ||
        _selectedTags.isNotEmpty ||
        _pickedCustomDate != null;

    return StreamBuilder<List<Task>>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];

        // Collect all distinct tags from existing tasks
        final tagSet = <String>{'urgent', 'deepwork', 'meeting', 'review', 'errand', 'backend', 'frontend'};
        for (final t in allTasks) {
          if (t.tags != null) {
            for (final tag in t.tags!.split(',')) {
              final clean = tag.trim().replaceAll('@', '');
              if (clean.isNotEmpty) tagSet.add(clean);
            }
          }
        }
        tagSet.addAll(_selectedTags);
        _existingTags
          ..clear()
          ..addAll(tagSet)
          ..sort();

        final matchCount = allTasks.where(_matchesCurrent).length;

        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: AxisColors.surfaceLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AxisColors.borderPrimary, width: 1.2),
              left: BorderSide(color: AxisColors.borderPrimary, width: 1.2),
              right: BorderSide(color: AxisColors.borderPrimary, width: 1.2),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle pill
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AxisColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Filter Controls Card (The exact filter card with reset inside)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AxisColors.borderPrimary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.tune_rounded,
                                    color: AxisColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'FILTER STUDIO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.primarySoft,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 20, color: AxisColors.textDim),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Divider(color: AxisColors.borderSubtle, height: 20),

                        // 1. Priority Filter Row
                        const Text('PRIORITY',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textMuted,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _FilterStudioChip(
                              label: 'All',
                              isSelected: _selectedPriority == null,
                              onTap: () => setState(() => _selectedPriority = null),
                            ),
                            const SizedBox(width: 6),
                            _FilterStudioChip(
                              label: 'P1 High',
                              color: AxisColors.priorityHigh,
                              isSelected: _selectedPriority == 1,
                              onTap: () => setState(() => _selectedPriority = 1),
                            ),
                            const SizedBox(width: 6),
                            _FilterStudioChip(
                              label: 'P2 Medium',
                              color: AxisColors.priorityMed,
                              isSelected: _selectedPriority == 2,
                              onTap: () => setState(() => _selectedPriority = 2),
                            ),
                            const SizedBox(width: 6),
                            _FilterStudioChip(
                              label: 'P3 Low',
                              color: AxisColors.priorityLow,
                              isSelected: _selectedPriority == 3,
                              onTap: () => setState(() => _selectedPriority = 3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2. Due Date Filter Row
                        const Text('DUE DATE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textMuted,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _FilterStudioChip(
                                label: 'All Dates',
                                isSelected: _selectedDueDateOption == null,
                                onTap: () => setState(() {
                                  _selectedDueDateOption = null;
                                  _pickedCustomDate = null;
                                }),
                              ),
                              const SizedBox(width: 6),
                              _FilterStudioChip(
                                label: 'Today',
                                color: AxisColors.primary,
                                isSelected: _selectedDueDateOption == 'today',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'today'),
                              ),
                              const SizedBox(width: 6),
                              _FilterStudioChip(
                                label: 'Tomorrow',
                                color: AxisColors.secondary,
                                isSelected: _selectedDueDateOption == 'tomorrow',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'tomorrow'),
                              ),
                              const SizedBox(width: 6),
                              _FilterStudioChip(
                                label: 'Upcoming',
                                color: AxisColors.tertiary,
                                isSelected: _selectedDueDateOption == 'upcoming',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'upcoming'),
                              ),
                              const SizedBox(width: 6),
                              _FilterStudioChip(
                                label: 'Overdue',
                                color: AxisColors.error,
                                isSelected: _selectedDueDateOption == 'overdue',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'overdue'),
                              ),
                              const SizedBox(width: 6),
                              _FilterStudioChip(
                                label: _pickedCustomDate != null
                                    ? DateFormat('d MMM').format(_pickedCustomDate!)
                                    : 'Pick Date...',
                                icon: Icons.calendar_today_rounded,
                                color: AxisColors.secondarySoft,
                                isSelected: _selectedDueDateOption == 'custom',
                                onTap: _pickDate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Tag Filter (Searchable Dropdown + Chip Wrap matching Create Task Sheet)
                        const Text('TAG',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textMuted,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),

                        if (_selectedTags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _selectedTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AxisColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: AxisColors.primary.withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '@$tag',
                                      style: const TextStyle(
                                        color: AxisColors.primarySoft,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    InkWell(
                                      onTap: () => setState(
                                          () => _selectedTags.remove(tag)),
                                      child: const Icon(Icons.close_rounded,
                                          size: 14, color: AxisColors.textDim),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],

                        Container(
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showTagDropdown
                                  ? AxisColors.primary
                                  : AxisColors.borderSubtle,
                              width: _showTagDropdown ? 1.5 : 1.0,
                            ),
                          ),
                          child: TextField(
                            controller: _tagInputController,
                            focusNode: _tagFocusNode,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AxisColors.textHigh,
                                ),
                            cursorColor: AxisColors.primary,
                            decoration: InputDecoration(
                              hintText: 'Select or write tag name...',
                              hintStyle: const TextStyle(
                                  color: AxisColors.textDim, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              prefixIcon: const Icon(Icons.label_outline_rounded,
                                  size: 18, color: AxisColors.primary),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_tagInputController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.add_rounded,
                                          size: 20, color: AxisColors.primary),
                                      tooltip: 'Add tag',
                                      onPressed: _addCurrentTag,
                                    ),
                                  IconButton(
                                    icon: Icon(
                                      _showTagDropdown
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      color: AxisColors.textDim,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showTagDropdown = !_showTagDropdown;
                                        if (_showTagDropdown) {
                                          _tagFocusNode.requestFocus();
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                _showTagDropdown = true;
                              });
                            },
                            onSubmitted: (_) => _addCurrentTag(),
                            onChanged: (_) {
                              setState(() {
                                _showTagDropdown = true;
                              });
                            },
                          ),
                        ),
                        if (_showTagDropdown) ...[
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AxisColors.primary.withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ListView(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                children: _buildTagDropdownItems(),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Results preview count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$matchCount ${matchCount == 1 ? 'task matches' : 'tasks match'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textMuted,
                              ),
                            ),
                            if (hasActiveFilter)
                              const Text(
                                'Filters Configured',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AxisColors.primarySoft,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),

                        const Divider(color: AxisColors.borderSubtle, height: 24),

                        // Action Buttons inside the Filter Card: Reset Filters + Apply
                        Row(
                          children: [
                            // Reset Filter Button inside the card
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: hasActiveFilter ? _clearAllFilters : null,
                                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                                label: const Text('Reset Filters'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AxisColors.secondary,
                                  disabledForegroundColor:
                                      AxisColors.textDim.withValues(alpha: 0.3),
                                  side: BorderSide(
                                    color: hasActiveFilter
                                        ? AxisColors.secondary.withValues(alpha: 0.5)
                                        : AxisColors.borderSubtle,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Apply Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _applyFilters();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Apply Filters'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AxisColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
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
  }
}

// ---------------------------------------------------------------------------
// FILTER STUDIO CHIP WIDGET
// ---------------------------------------------------------------------------
class _FilterStudioChip extends StatelessWidget {
  const _FilterStudioChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AxisColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.22)
              : AxisColors.surfaceHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AxisColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? activeColor : AxisColors.textDim),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AxisColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EMPTY STATE WIDGET
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    this.isFiltered = false,
    this.onReset,
  });

  final bool isFiltered;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off_rounded : Icons.inbox_rounded,
            size: 48,
            color: AxisColors.textDim,
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered ? 'No tasks match active filters' : 'No tasks found',
            style: const TextStyle(
              color: AxisColors.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFiltered
                ? 'Try adjusting or resetting your filter studio selections'
                : 'Tap "+ New Task" to create your first objective',
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
          if (isFiltered && onReset != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AxisColors.primary,
                side: const BorderSide(color: AxisColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
