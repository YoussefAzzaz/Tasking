import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/focus_session_service.dart';
import '../../../data/project_repository.dart';
import '../../../data/task_repository.dart';
import '../../../domain/id_generator.dart';
import '../core/desktop_layout.dart';
import '../dialogs/quick_task_dialog.dart';
import '../widgets/accent_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_checkbox.dart';
import '../widgets/desktop_pressable.dart';
import '../widgets/desktop_selection_chip.dart';
import '../widgets/ghost_button.dart';
import '../widgets/priority_badge.dart';
import '../widgets/progress_gauge.dart';
import '../widgets/section_header.dart';
import '../widgets/task_status_rail.dart';
import '../widgets/telemetry_chip.dart';
import '../widgets/undo_snackbar.dart';

/// Projects & Tasks Matrix Screen (Tab 2).
class ProjectsTasksScreen extends StatefulWidget {
  const ProjectsTasksScreen({
    super.key,
    required this.onNavigateToTab,
  });

  final ValueChanged<int> onNavigateToTab;

  @override
  State<ProjectsTasksScreen> createState() => _ProjectsTasksScreenState();
}

class _ProjectsTasksScreenState extends State<ProjectsTasksScreen> {
  Task? _selectedTask;
  int _taskFilterIndex = 0; // 0: All, 1: Today, 2: In Progress, 3: Completed
  String? _selectedProjectId;
  final _quickTaskController = TextEditingController();

  @override
  void dispose() {
    _quickTaskController.dispose();
    super.dispose();
  }

  void _showNewProjectDialog() {
    final nameController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AxisColors.borderGlass2, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create New Project',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                autofocus: true,
                style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
                decoration: InputDecoration(
                  hintText: 'e.g. Axis Command Center v2',
                  hintStyle: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                  filled: true,
                  fillColor: AxisColors.surfaceLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AxisColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AccentButton(
                    label: 'Create Project',
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isNotEmpty) {
                        final proj = Project(
                          id: IdGenerator.generateDeterministicId('proj_${DateTime.now().microsecondsSinceEpoch}'),
                          name: name,
                          color: '#6366F1',
                        );
                        await ProjectRepository().addProject(proj);
                      }
                      if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleQuickAddTask() async {
    final title = _quickTaskController.text.trim();
    if (title.isEmpty) return;

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final task = Task(
      id: IdGenerator.generateDeterministicId('task_${now.microsecondsSinceEpoch}'),
      title: title,
      status: 'pending',
      priority: 2,
      dueDate: todayStr,
      projectId: _selectedProjectId,
    );

    await TaskRepository().addTask(task);
    _quickTaskController.clear();
    setState(() => _selectedTask = task);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 4.2 Page Header
          _buildHeader(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 4.4 Project Kanban Cards (horizontal scroll)
          _buildProjectsRow(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 4.5 & 4.6 Split: Task List (left) + Task Inspector (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildTaskListPane(),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                flex: 6,
                child: _buildTaskInspectorPane(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<List<Task>>(
      stream: TaskRepository().watchTasks(),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        final activeCount = tasks.where((t) => !t.isCompleted).length;
        final completedCount = tasks.where((t) => t.isCompleted).length;

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
                      Flexible(
                        child: Text(
                          'Projects & Tasks',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: AxisColors.textHigh,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const TelemetryChip(
                        label: 'Sprint Active',
                        color: AxisColors.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage deliverables, sprints, and task execution queues',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TelemetryChip(
                  label: 'ACTIVE: $activeCount',
                  color: AxisColors.secondary,
                ),
                const SizedBox(width: 8),
                TelemetryChip(
                  label: 'COMPLETED: $completedCount',
                  color: AxisColors.tertiary,
                ),
                const SizedBox(width: 14),
                GhostButton(
                  label: '+ New Project',
                  icon: Icons.create_new_folder_outlined,
                  onPressed: _showNewProjectDialog,
                ),
                const SizedBox(width: 8),
                AccentButton(
                  label: '+ New Task',
                  icon: Icons.add_rounded,
                  onPressed: () => QuickTaskDialog.show(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildProjectsRow() {
    return StreamBuilder<List<Project>>(
      stream: ProjectRepository().watchProjects(),
      builder: (context, projSnap) {
        final projects = projSnap.data ?? [];
        if (projects.isEmpty) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<Task>>(
          stream: TaskRepository().watchTasks(),
          builder: (context, taskSnap) {
            final allTasks = taskSnap.data ?? [];

            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: projects.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "All Projects" chip
                    final isSelected = _selectedProjectId == null;
                    return _ProjectCard(
                      width: 160,
                      isSelected: isSelected,
                      semanticLabel: 'All Projects, ${projects.length} workspaces',
                      onTap: () => setState(() => _selectedProjectId = null),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.apps_rounded, size: 20, color: AxisColors.secondary),
                          const SizedBox(height: 8),
                          Text(
                            'All Projects',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                          ),
                          Text(
                            '${projects.length} workspaces',
                            style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                          ),
                        ],
                      ),
                    );
                  }

                  final p = projects[index - 1];
                  final isSelected = _selectedProjectId == p.id;
                  final projectTasks = allTasks
                      .where((t) => t.projectId == p.id || t.projectId == p.name)
                      .toList();
                  final total = projectTasks.length;
                  final completed = projectTasks.where((t) => t.isCompleted).length;
                  final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

                  return _ProjectCard(
                    width: 220,
                    isSelected: isSelected,
                    semanticLabel: '${p.name}, $completed of $total tasks, ${(progress * 100).toInt()}% complete',
                    onTap: () => setState(() => _selectedProjectId = isSelected ? null : p.id),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ),
                            TelemetryChip(
                              label: '${(progress * 100).toInt()}%',
                              color: AxisColors.secondary,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$completed/$total tasks',
                                  style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
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
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskListPane() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'TASK QUEUE',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterButton('All', 0),
                const SizedBox(width: 4),
                _buildFilterButton('Today', 1),
                const SizedBox(width: 4),
                _buildFilterButton('Active', 2),
                const SizedBox(width: 4),
                _buildFilterButton('Done', 3),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                    controller: _quickTaskController,
                    onSubmitted: (_) => _handleQuickAddTask(),
                    style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh),
                    decoration: InputDecoration(
                      hintText: '+ Add task to this queue...',
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
                padding: const EdgeInsets.symmetric(horizontal: 14),
                onPressed: _handleQuickAddTask,
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Task items list
          StreamBuilder<List<Task>>(
            stream: TaskRepository().watchTasks(),
            builder: (context, snapshot) {
              final tasks = snapshot.data ?? [];
              final now = DateTime.now();
              final todayStr = DateFormat('yyyy-MM-dd').format(now);

              var filtered = tasks.where((t) {
                if (_selectedProjectId != null && t.projectId != _selectedProjectId) {
                  return false;
                }
                if (_taskFilterIndex == 1) {
                  return t.dueDate == todayStr;
                } else if (_taskFilterIndex == 2) {
                  return !t.isCompleted;
                } else if (_taskFilterIndex == 3) {
                  return t.isCompleted;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36.0),
                  child: Center(
                    child: Text(
                      'No tasks found for selected filter',
                      style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                    ),
                  ),
                );
              }

              // Auto-select first task if none selected
              if (_selectedTask == null && filtered.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedTask == null) {
                    setState(() => _selectedTask = filtered.first);
                  }
                });
              }

              return Column(
                children: filtered.map((task) {
                  final isSelected = _selectedTask?.id == task.id;
                  final isDone = task.isCompleted;
                  final railColor = isDone
                      ? AxisColors.tertiary
                      : (task.priority == 1 ? AxisColors.priorityHigh : AxisColors.secondary);

                  return DesktopPressable(
                    role: DesktopPressableRole.listItem,
                    selected: isSelected,
                    label: task.title,
                    onActivate: () => setState(() => _selectedTask = task),
                    builder: (context, visuals) {
                      final hovered = visuals.hovered || visuals.pressed;
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 3.0),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AxisColors.primary.withValues(alpha: 0.16)
                              : hovered
                                  ? AxisColors.surfaceLow
                                  : AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected
                                ? AxisColors.primary
                                : (hovered ? AxisColors.borderGlass2 : AxisColors.borderSubtle),
                            width: 1,
                          ),
                          boxShadow: desktopFocusRing(visuals.focused),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
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
                                  if (task.dueDate != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Due ${task.dueDate} ${task.dueTime ?? ""}',
                                      style: GoogleFonts.spaceGrotesk(fontSize: 10, color: AxisColors.textDim),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (task.priority != null && !isDone) ...[
                              const SizedBox(width: 8),
                              PriorityBadge(priority: task.priority, compact: true),
                            ],
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, int index) {
    return DesktopSelectionChip(
      label: label,
      selected: _taskFilterIndex == index,
      onTap: () => setState(() => _taskFilterIndex = index),
    );
  }

  Widget _buildTaskInspectorPane() {
    final task = _selectedTask;
    if (task == null) {
      return DesktopCard(
        height: 380,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_outlined, size: 36, color: AxisColors.textDim),
              const SizedBox(height: 10),
              Text(
                'Select a task to inspect details and checklist',
                style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
              ),
            ],
          ),
        ),
      );
    }

    final isDone = task.isCompleted;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TASK INSPECTOR',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AxisColors.secondary,
                ),
              ),
              Row(
                children: [
                  if (task.priority != null) PriorityBadge(priority: task.priority),
                  const SizedBox(width: 8),
                  TelemetryChip(
                    label: isDone ? 'COMPLETED' : 'IN PROGRESS',
                    color: isDone ? AxisColors.tertiary : AxisColors.secondary,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            task.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AxisColors.textHigh,
            ),
          ),
          const SizedBox(height: 14),
          // Description / notes
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOTES & CONTEXT',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AxisColors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.notes != null && task.notes!.isNotEmpty
                      ? task.notes!
                      : 'No additional notes provided for this deliverable.',
                  style: GoogleFonts.getFont('Geist', fontSize: 13, height: 1.4, color: AxisColors.textHigh),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Checklist
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DELIVERABLE CHECKLIST',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AxisColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                _buildChecklistItem('Verify architecture requirements', true),
                _buildChecklistItem('Draft implementation plan and schema', true),
                _buildChecklistItem('Review telemetry and performance bounds', false),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Actions
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GhostButton(
                    label: isDone ? 'Mark as Incomplete' : 'Mark Completed',
                    icon: isDone ? Icons.undo_rounded : Icons.check_circle_outline_rounded,
                    onPressed: () {
                      TaskRepository().toggleTaskStatus(task, !isDone);
                      setState(() {
                        _selectedTask = task.copyWith(status: isDone ? 'todo' : 'done');
                      });
                    },
                  ),
                  GhostButton(
                    label: 'Delete',
                    icon: Icons.delete_outline_rounded,
                    onPressed: () async {
                      final confirmed = await ConfirmDialog.show(
                        context,
                        title: 'Delete task?',
                        message:
                            '"${task.title}" will be permanently removed. You can undo for a few seconds after deleting.',
                      );
                      if (!confirmed) return;

                      final snapshot = task; // captured for undo
                      await TaskRepository().deleteTask(snapshot.id);
                      setState(() {
                        _selectedTask = null;
                      });
                      if (!mounted) return;
                      showUndoSnackBar(
                        context,
                        message: 'Task deleted',
                        onUndo: () => TaskRepository().addTask(snapshot),
                      );
                    },
                  ),
                ],
              ),
              AccentButton(
                label: '▶ Start Focus Session',
                onPressed: () {
                  FocusSessionService().setAttachedTask(task);
                  FocusSessionService().startTimer();
                  widget.onNavigateToTab(3); // Navigate to Focus Timers
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 16,
            color: done ? AxisColors.tertiary : AxisColors.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.getFont(
                'Geist',
                fontSize: 12,
                decoration: done ? TextDecoration.lineThrough : null,
                color: done ? AxisColors.textDim : AxisColors.textHigh,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable workspace card in the projects rail — keyboard-operable and
/// screen-reader announced.
class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.width,
    required this.isSelected,
    required this.onTap,
    required this.child,
    this.semanticLabel,
  });

  final double width;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return DesktopPressable(
      role: DesktopPressableRole.listItem,
      selected: isSelected,
      label: semanticLabel,
      onActivate: onTap,
      builder: (context, visuals) {
        final hovered = visuals.hovered || visuals.pressed;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: width,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AxisColors.primary.withValues(alpha: 0.15)
                : hovered
                    ? AxisColors.surfaceLow.withValues(alpha: 0.75)
                    : AxisColors.surfaceLow,
            borderRadius: DesktopLayout.borderRadiusCard,
            border: Border.all(
              color: isSelected
                  ? AxisColors.primary
                  : (hovered ? AxisColors.borderGlass2 : AxisColors.borderSubtle),
              width: 1,
            ),
            boxShadow: desktopFocusRing(visuals.focused),
          ),
          child: child,
        );
      },
    );
  }
}
