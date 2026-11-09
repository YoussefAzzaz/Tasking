import 'package:flutter/material.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/project_repository.dart';
import '../../../data/task_repository.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import 'projects_tasks/new_project_dialog.dart';
import 'projects_tasks/projects_kanban_row.dart';
import 'projects_tasks/projects_task_inspector_pane.dart';
import 'projects_tasks/projects_task_list_pane.dart';
import 'projects_tasks/projects_tasks_header.dart';

export 'projects_tasks/new_project_dialog.dart';
export 'projects_tasks/projects_kanban_row.dart';
export 'projects_tasks/projects_task_inspector_pane.dart';
export 'projects_tasks/projects_task_item.dart';
export 'projects_tasks/projects_task_list_pane.dart';
export 'projects_tasks/projects_tasks_header.dart';

/// Projects & Tasks Matrix Screen (Tab 2).
class ProjectsTasksScreen extends StatefulWidget {
  const ProjectsTasksScreen({
    super.key,
    required this.onNavigateToTab,
    this.taskRepo,
  });

  final ValueChanged<int> onNavigateToTab;
  final TaskRepository? taskRepo;

  @override
  State<ProjectsTasksScreen> createState() => _ProjectsTasksScreenState();
}

class _ProjectsTasksScreenState extends State<ProjectsTasksScreen> {
  TaskRepository get _taskRepo => widget.taskRepo ?? TaskRepository();
  Task? _selectedTask;
  String? _selectedTaskId;
  String? _selectedProjectId;
  final ScrollController _tasksScrollController = ScrollController();
  final ScrollController _projectsScrollController = ScrollController();

  @override
  void dispose() {
    _tasksScrollController.dispose();
    _projectsScrollController.dispose();
    super.dispose();
  }

  void _showNewProjectDialog() {
    NewProjectDialog.show(context);
  }

  Future<void> _confirmDeleteProject(Project p) async {
    final isArabic = AppLocalizations.of(context).isArabic;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.canvasBase,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AxisColors.borderGlass2),
        ),
        title: Text(
          isArabic ? 'حذف المشروع' : 'Delete Project',
          style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isArabic
              ? 'هل أنت متأكد من حذف "${p.name}"؟ سيتم إلغاء ربط المهام المرتبطة بهذا المشروع دون حذفها.'
              : 'Are you sure you want to delete "${p.name}"? Tasks associated with this project will be unlinked but not deleted.',
          style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              isArabic ? 'إلغاء' : 'Cancel',
              style: GoogleFonts.getFont('Geist', color: AxisColors.textDim),
            ),
          ),
          AccentButton(
            label: isArabic ? 'حذف المشروع' : 'Delete Project',
            color: AxisColors.priorityHigh,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final pName = p.name;
      await ProjectRepository().deleteProject(p.id, projectName: p.name);
      if (_selectedProjectId == p.id) {
        setState(() {
          _selectedProjectId = null;
          _selectedTask = null;
          _selectedTaskId = null;
        });
      }
      if (mounted) {
        AxisSnackBar.showDeleted(context, itemTitle: pName, itemType: 'Project');
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
          ProjectsTasksHeader(
            selectedProjectId: _selectedProjectId,
            onNewProject: _showNewProjectDialog,
            onDeleteProject: _confirmDeleteProject,
            taskRepo: _taskRepo,
          ),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 4.4 Project Kanban Cards (horizontal scroll)
          ProjectsKanbanRow(
            selectedProjectId: _selectedProjectId,
            onSelectProject: (projId) => setState(() => _selectedProjectId = projId),
            onDeleteProject: _confirmDeleteProject,
            taskRepo: _taskRepo,
            scrollController: _projectsScrollController,
          ),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // 4.5 & 4.6 Split: Task List (left) + Task Inspector (right)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ProjectsTaskListPane(
                    selectedProjectId: _selectedProjectId,
                    selectedTaskId: _selectedTaskId ?? _selectedTask?.id,
                    onSelectTask: (task) {
                      setState(() {
                        _selectedTask = task;
                        _selectedTaskId = task.id;
                      });
                    },
                    onResetProjectFilter: () => setState(() => _selectedProjectId = null),
                    taskRepo: _taskRepo,
                    scrollController: _tasksScrollController,
                  ),
                ),
                const SizedBox(width: DesktopLayout.sectionSpacing),
                Expanded(
                  flex: 6,
                  child: ProjectsTaskInspectorPane(
                    selectedTaskId: _selectedTaskId,
                    selectedTask: _selectedTask,
                    taskRepo: _taskRepo,
                    onTaskUpdated: (updated) {
                      setState(() {
                        _selectedTask = updated;
                        _selectedTaskId = updated.id;
                      });
                    },
                    onTaskDeleted: () {
                      setState(() {
                        _selectedTask = null;
                        _selectedTaskId = null;
                      });
                    },
                    onNavigateToTab: widget.onNavigateToTab,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
