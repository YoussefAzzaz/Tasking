import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/focus_session_service.dart';
import '../../../data/project_repository.dart';
import '../../../data/task_repository.dart';
import '../../../domain/id_generator.dart';
import '../../common/axis_markdown_viewer.dart';
import '../../common/cyber_color_picker.dart';
import '../core/desktop_layout.dart';
import '../core/task_checklist_mixin.dart';
import '../dialogs/quick_task_dialog.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_checkbox.dart';
import '../widgets/desktop_horizontal_scroll.dart';
import '../widgets/ghost_button.dart';
import '../widgets/priority_badge.dart';
import '../widgets/progress_gauge.dart';
import '../widgets/section_header.dart';
import '../widgets/task_status_rail.dart';
import '../widgets/telemetry_chip.dart';

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

class _ProjectsTasksScreenState extends State<ProjectsTasksScreen> with TaskChecklistMixin {
  Task? _selectedTask;
  int _taskFilterIndex = 0; // 0: All, 1: Today, 2: In Progress, 3: Completed
  String? _selectedProjectId;
  final ScrollController _tasksScrollController = ScrollController();
  final ScrollController _projectsScrollController = ScrollController();

  @override
  void dispose() {
    _tasksScrollController.dispose();
    _projectsScrollController.dispose();
    super.dispose();
  }

  void _editTask(Task task) {
    QuickTaskDialog.show(
      context,
      taskToEdit: task,
      onTaskUpdated: (updated) {
        setState(() => _selectedTask = updated);
      },
    );
  }

  // Checklist helpers provided by TaskChecklistMixin

  Future<void> _promptAddSubtask(Task task) async {
    final controller = TextEditingController();
    final subtask = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.canvasBase,
        title: Text('Add Subtask Checkpoint', style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: GoogleFonts.getFont('Geist', color: AxisColors.textHigh),
          decoration: const InputDecoration(hintText: 'e.g. Write integration test suite'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Add', style: TextStyle(color: AxisColors.secondary)),
          ),
        ],
      ),
    );
    if (subtask != null && subtask.isNotEmpty) {
      final current = task.notes ?? '';
      final updatedNotes = current.isEmpty ? '- [ ] $subtask' : '$current\n- [ ] $subtask';
      final updated = task.copyWith(notes: updatedNotes);
      await TaskRepository().updateTask(updated);
      setState(() => _selectedTask = updated);
    }
  }

  void _showNewProjectDialog() {
    final nameController = TextEditingController();
    String selectedColor = '#6366F1';
    final colors = ['#6366F1', '#38BDF8', '#10B981', '#F59E0B', '#EF4444', '#EC4899', '#8B5CF6'];

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
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
                const SizedBox(height: 14),
                Text(
                  'PROJECT COLOR',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AxisColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ...colors.map((hex) {
                      final isSel = selectedColor.toLowerCase() == hex.toLowerCase();
                      final c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSel ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }),
                    if (!colors.any((c) => c.toLowerCase() == selectedColor.toLowerCase()))
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: Color(int.parse(selectedColor.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    RainbowColorPickerButton(
                      selectedColor: selectedColor,
                      size: 26,
                      onColorSelected: (newHex) {
                        setDialogState(() => selectedColor = newHex);
                      },
                    ),
                  ],
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
                            color: selectedColor,
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
      ),
    );
  }

  Future<void> _confirmDeleteProject(Project p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.canvasBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AxisColors.borderGlass2),
        ),
        title: Text(
          'Delete Project',
          style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete "${p.name}"? Tasks associated with this project will be unlinked but not deleted.',
          style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.getFont('Geist', color: AxisColors.textDim)),
          ),
          AccentButton(
            label: 'Delete Project',
            color: AxisColors.priorityHigh,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProjectRepository().deleteProject(p.id, projectName: p.name);
      if (_selectedProjectId == p.id) {
        setState(() {
          _selectedProjectId = null;
          _selectedTask = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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

          // 4.5 & 4.6 Split: Task List (left) + Task Inspector (right) - constrained to page size
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return StreamBuilder<List<Project>>(
      stream: ProjectRepository().watchProjects(),
      builder: (context, projSnap) {
        final projects = projSnap.data ?? [];
        final selProj = projects.cast<Project?>().firstWhere(
          (p) => p != null && p.id == _selectedProjectId,
          orElse: () => null,
        );

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
                              selProj != null ? 'Project: ${selProj.name}' : 'Projects & Tasks',
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
                        selProj != null
                            ? 'Filtered execution queue for workspace "${selProj.name}"'
                            : 'Manage deliverables, sprints, and task execution queues',
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
                    if (selProj != null) ...[
                      GhostButton(
                        label: 'Delete Project',
                        icon: Icons.delete_outline_rounded,
                        color: AxisColors.priorityHigh,
                        borderColor: AxisColors.priorityHigh.withValues(alpha: 0.35),
                        hoverBackgroundColor: AxisColors.priorityHigh.withValues(alpha: 0.12),
                        onPressed: () => _confirmDeleteProject(selProj),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GhostButton(
                      label: '+ New Project',
                      icon: Icons.create_new_folder_outlined,
                      onPressed: _showNewProjectDialog,
                    ),
                    const SizedBox(width: 8),
                    AccentButton(
                      label: 'New Task',
                      icon: Icons.add_rounded,
                      onPressed: () => QuickTaskDialog.show(context),
                    ),
                  ],
                ),
              ],
            );
          },
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
              child: DesktopHorizontalScroll(
                controller: _projectsScrollController,
                child: ListView.builder(
                  controller: _projectsScrollController,
                  scrollDirection: Axis.horizontal,
                itemCount: projects.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // "All Projects" chip
                    final isSelected = _selectedProjectId == null;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedProjectId = null),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? AxisColors.primary.withValues(alpha: 0.15) : AxisColors.surfaceLow,
                          borderRadius: DesktopLayout.borderRadiusCard,
                          border: Border.all(
                            color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
                            width: 1,
                          ),
                        ),
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

                  return GestureDetector(
                    onTap: () => setState(() => _selectedProjectId = isSelected ? null : p.id),
                    child: Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AxisColors.primary.withValues(alpha: 0.15) : AxisColors.surfaceLow,
                        borderRadius: DesktopLayout.borderRadiusCard,
                        border: Border.all(
                          color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
                          width: 1,
                        ),
                      ),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TelemetryChip(
                                    label: '${(progress * 100).toInt()}%',
                                    color: AxisColors.secondary,
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  ),
                                  const SizedBox(width: 4),
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () => _confirmDeleteProject(p),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 14,
                                          color: AxisColors.textDim,
                                        ),
                                      ),
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
                    ),
                  );
                },
              ),
            ),
          );
          },
        );
      },
    );
  }

  Widget _buildTaskListPane() {
    return StreamBuilder<List<Project>>(
      stream: ProjectRepository().watchProjects(),
      builder: (context, projSnap) {
        final projects = projSnap.data ?? [];
        final selProj = projects.cast<Project?>().firstWhere(
          (p) => p != null && p.id == _selectedProjectId,
          orElse: () => null,
        );

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'TASK QUEUE',
                trailing: selProj != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TelemetryChip(
                            label: selProj.name.toUpperCase(),
                            color: AxisColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          GhostButton(
                            label: 'All Projects',
                            icon: Icons.filter_alt_off_outlined,
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: () => setState(() => _selectedProjectId = null),
                          ),
                        ],
                      )
                    : null,
              ),
              DesktopHorizontalScrollView(
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
              const SizedBox(height: 12),
              // Task items list
              Expanded(
                child: StreamBuilder<List<Task>>(
                stream: TaskRepository().watchTasks(),
                builder: (context, snapshot) {
                  final tasks = snapshot.data ?? [];
                  final now = DateTime.now();
                  final todayStr = DateFormat('yyyy-MM-dd').format(now);

                  var filtered = tasks.where((t) {
                    if (_selectedProjectId != null) {
                      final tProj = t.projectId?.trim() ?? '';
                      final matches = tProj == _selectedProjectId ||
                          (selProj != null && (
                            tProj.toLowerCase() == selProj.id.toLowerCase() ||
                            tProj.toLowerCase() == selProj.name.toLowerCase()
                          ));
                      if (!matches) return false;
                    }
                    if (_taskFilterIndex == 1) {
                      return t.dueDate == todayStr;
                    } else if (_taskFilterIndex == 2) {
                      return !t.isCompleted;
                    } else if (_taskFilterIndex == 3) {
                      return t.isCompleted;
                    }
                    return true;
                  }).toList()
                    ..sort((a, b) {
                      // 1. Automatically move checked/completed tasks down
                      if (a.isCompleted != b.isCompleted) {
                        return a.isCompleted ? 1 : -1;
                      }
                      // 2. Sort by date (earliest due date first, tasks without date placed at the end)
                      final aDate = a.dueDate;
                      final bDate = b.dueDate;
                      if (aDate != null && bDate != null) {
                        final dateComp = aDate.compareTo(bDate);
                        if (dateComp != 0) return dateComp;
                        final aTime = a.dueTime ?? '';
                        final bTime = b.dueTime ?? '';
                        final timeComp = aTime.compareTo(bTime);
                        if (timeComp != 0) return timeComp;
                      } else if (aDate != null && bDate == null) {
                        return -1;
                      } else if (aDate == null && bDate != null) {
                        return 1;
                      }
                      // 3. Sort by name alphabetically
                      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
                    });

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No tasks found for selected filter',
                        style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      ),
                    );
                  }

                  // Auto-select first task if none selected or no longer in filtered
                  if ((_selectedTask == null || !filtered.any((t) => t.id == _selectedTask!.id)) && filtered.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && (_selectedTask == null || !filtered.any((t) => t.id == _selectedTask!.id))) {
                        setState(() => _selectedTask = filtered.first);
                      }
                    });
                  }

                  return Scrollbar(
                    controller: _tasksScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _tasksScrollController,
                      padding: const EdgeInsets.only(right: 12.0),
                      itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final task = filtered[index];
                          final isSelected = _selectedTask?.id == task.id;
                          final isDone = task.isCompleted;
                          final railColor = isDone
                              ? AxisColors.tertiary
                              : switch (task.priority) {
                                  1 => AxisColors.priorityHigh,
                                  2 => AxisColors.priorityMed,
                                  3 => AxisColors.priorityLow,
                                  _ => AxisColors.secondary,
                                };

                          return GestureDetector(
                            onTap: () => setState(() => _selectedTask = task),
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3.0),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AxisColors.primary.withValues(alpha: 0.16)
                                    : AxisColors.surfaceLowest,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
                                  width: 1,
                                ),
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
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(String label, int index) {
    final isSelected = _taskFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _taskFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AxisColors.primary.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? AxisColors.primary : AxisColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.getFont(
            'Geist',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AxisColors.textHigh : AxisColors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskInspectorPane() {
    final task = _selectedTask;
    if (task == null) {
      return DesktopCard(
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
                  const SizedBox(width: 8),
                  GhostButton(
                    label: 'Edit',
                    icon: Icons.edit_outlined,
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    onPressed: () => _editTask(task),
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                Builder(
                  builder: (context) {
                    final displayNotes = stripChecklistFromNotes(task.notes);
                    if (displayNotes.isNotEmpty) {
                      return AxisMarkdownViewer(
                        markdown: displayNotes,
                        selectable: true,
                        baseStyle: GoogleFonts.getFont('Geist', fontSize: 13, height: 1.4, color: AxisColors.textHigh),
                      );
                    }
                    return Text(
                      'No additional notes provided for this deliverable.',
                      style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                    );
                  },
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'DELIVERABLE CHECKLIST',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.textMuted,
                      ),
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _promptAddSubtask(task),
                        child: Text(
                          '+ Add Subtask',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.secondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final checklist = parseTaskChecklist(task.notes);
                    if (checklist.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Text(
                          'No checklist items yet. Click + Add Subtask to add checkpoints.',
                          style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      );
                    }
                    return Column(
                      children: checklist.map((item) {
                        return InkWell(
                          onTap: () => toggleTaskChecklist(task, item.lineIndex),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  item.isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  size: 16,
                                  color: item.isDone ? AxisColors.tertiary : AxisColors.textDim,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.text,
                                    style: GoogleFonts.getFont(
                                      'Geist',
                                      fontSize: 12,
                                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                                      color: item.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                      await TaskRepository().deleteTask(task.id);
                      setState(() {
                        _selectedTask = null;
                      });
                    },
                  ),
                ],
              ),
              AccentButton(
                label: '▶ Start Focus Session',
                onPressed: () {
                  FocusSessionService().setAttachedTask(task);
                  FocusSessionService().startTimer();
                  widget.onNavigateToTab(4); // Navigate to Focus Timers
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
