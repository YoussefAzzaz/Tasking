import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/project_repository.dart';
import '../../../../data/task_repository.dart';
import '../../core/desktop_layout.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/progress_gauge.dart';
import '../../widgets/telemetry_chip.dart';

/// Horizontally scrollable row displaying all project workspaces and their progress.
class ProjectsKanbanRow extends StatelessWidget {
  const ProjectsKanbanRow({
    super.key,
    required this.selectedProjectId,
    required this.onSelectProject,
    required this.onDeleteProject,
    required this.taskRepo,
    this.scrollController,
  });

  final String? selectedProjectId;
  final ValueChanged<String?> onSelectProject;
  final ValueChanged<Project> onDeleteProject;
  final TaskRepository taskRepo;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Project>>(
      stream: ProjectRepository().watchProjects(),
      builder: (context, projSnap) {
        final projects = projSnap.data ?? [];
        if (projects.isEmpty) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<List<Task>>(
          stream: taskRepo.watchTasks(),
          builder: (context, taskSnap) {
            final allTasks = taskSnap.data ?? [];
            final isArabic = AppLocalizations.of(context).isArabic;

            return SizedBox(
              height: 120,
              child: DesktopHorizontalScroll(
                controller: scrollController,
                child: ListView.builder(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: projects.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = selectedProjectId == null;
                      return GestureDetector(
                        onTap: () => onSelectProject(null),
                        child: Container(
                          width: 160,
                          margin: const EdgeInsetsDirectional.only(end: 12),
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
                                isArabic ? 'جميع المشاريع' : 'All Projects',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              Text(
                                isArabic ? '${projects.length} مساحات عمل' : '${projects.length} workspaces',
                                style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final p = projects[index - 1];
                    final isSelected = selectedProjectId == p.id;
                    final projectTasks = allTasks
                        .where((t) => t.projectId == p.id || t.projectId == p.name)
                        .toList();
                    final total = projectTasks.length;
                    final completed = projectTasks.where((t) => t.isCompleted).length;
                    final progress = total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

                    return GestureDetector(
                      onTap: () => onSelectProject(isSelected ? null : p.id),
                      child: Container(
                        width: 220,
                        margin: const EdgeInsetsDirectional.only(end: 12),
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
                                        onTap: () => onDeleteProject(p),
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
                                      isArabic ? '$completed/$total مهام' : '$completed/$total tasks',
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
}

