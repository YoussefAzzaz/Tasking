import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/project_repository.dart';
import '../../../../data/task_repository.dart';
import '../../dialogs/quick_task_dialog.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/telemetry_chip.dart';

/// Top header for the Projects & Tasks screen showing workspace title, counters, and action buttons.
class ProjectsTasksHeader extends StatelessWidget {
  const ProjectsTasksHeader({
    super.key,
    required this.selectedProjectId,
    required this.onNewProject,
    required this.onDeleteProject,
    required this.taskRepo,
  });

  final String? selectedProjectId;
  final VoidCallback onNewProject;
  final ValueChanged<Project> onDeleteProject;
  final TaskRepository taskRepo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Project>>(
      stream: ProjectRepository().watchProjects(),
      builder: (context, projSnap) {
        final projects = projSnap.data ?? [];
        final selProj = projects.cast<Project?>().firstWhere(
          (p) => p != null && p.id == selectedProjectId,
          orElse: () => null,
        );

        return StreamBuilder<List<Task>>(
          stream: taskRepo.watchTasks(),
          builder: (context, snapshot) {
            final tasks = snapshot.data ?? [];
            final isArabic = AppLocalizations.of(context).isArabic;
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
                              selProj != null
                                  ? (isArabic ? 'المشروع: ${selProj.name}' : 'Project: ${selProj.name}')
                                  : (isArabic ? 'المشاريع والمهام' : 'Projects & Tasks'),
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
                          TelemetryChip(
                            label: isArabic ? 'دورة العمل نشطة' : 'Sprint Active',
                            color: AxisColors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selProj != null
                            ? (isArabic
                                ? 'قائمة التنفيذ المصفاة لمساحة العمل "${selProj.name}"'
                                : 'Filtered execution queue for workspace "${selProj.name}"')
                            : (isArabic
                                ? 'إدارة المهام والمشاريع وقوائم التنفيذ'
                                : 'Manage deliverables, sprints, and task execution queues'),
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
                      label: isArabic ? 'النشطة: $activeCount' : 'ACTIVE: $activeCount',
                      color: AxisColors.secondary,
                    ),
                    const SizedBox(width: 8),
                    TelemetryChip(
                      label: isArabic ? 'المكتملة: $completedCount' : 'COMPLETED: $completedCount',
                      color: AxisColors.tertiary,
                    ),
                    const SizedBox(width: 14),
                    if (selProj != null) ...[
                      GhostButton(
                        label: isArabic ? 'حذف المشروع' : 'Delete Project',
                        icon: Icons.delete_outline_rounded,
                        color: AxisColors.priorityHigh,
                        borderColor: AxisColors.priorityHigh.withValues(alpha: 0.35),
                        hoverBackgroundColor: AxisColors.priorityHigh.withValues(alpha: 0.12),
                        onPressed: () => onDeleteProject(selProj),
                      ),
                      const SizedBox(width: 8),
                    ],
                    GhostButton(
                      label: isArabic ? '+ مشروع جديد' : '+ New Project',
                      icon: Icons.create_new_folder_outlined,
                      onPressed: onNewProject,
                    ),
                    const SizedBox(width: 8),
                    AccentButton(
                      label: isArabic ? 'مهمة جديدة' : 'New Task',
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
}

