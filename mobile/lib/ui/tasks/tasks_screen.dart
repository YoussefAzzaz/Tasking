import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/ui/tasks/create_task_sheet.dart';
import 'package:axis/ui/tasks/create_project_sheet.dart';
import 'package:axis/ui/common/axis_sliding_segmented_bar.dart';
import 'package:axis/ui/tasks/inbox_tab.dart';
import 'package:axis/ui/tasks/upcoming_tab.dart';
import 'package:axis/ui/tasks/projects_tab.dart';
import 'package:axis/ui/tasks/task_filter_sheet.dart';

export 'package:axis/ui/tasks/task_filter_sheet.dart' show TaskFilterCriteria, TaskFilterSheet;
export 'package:axis/ui/tasks/inbox_tab.dart' show InboxTab;
export 'package:axis/ui/tasks/upcoming_tab.dart' show UpcomingTab;
export 'package:axis/ui/tasks/projects_tab.dart' show ProjectsTab;
export 'package:axis/ui/tasks/project_big_task_card.dart' show ProjectBigTaskCard;
export 'package:axis/ui/tasks/tasks_empty_state.dart' show TasksEmptyState;

/// Obsidian Kinetic Tasks Screen — Coordinator shell with sliding segmented bar & IndexedStack
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
      InboxTab(repo: _taskRepo, filterCriteria: _filterCriteria),
      UpcomingTab(repo: _taskRepo, filterCriteria: _filterCriteria),
      ProjectsTab(
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
        initialProject: initialProject,
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
      builder: (_) => TaskFilterSheet(
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
