import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/project_repository.dart';
import '../../../../data/task_repository.dart';
import '../../../friends/widgets/pending_shares_section.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';
import 'projects_task_item.dart';

/// Left panel for the Projects & Tasks screen showing the task queue grouped chronologically.
class ProjectsTaskListPane extends StatefulWidget {
  const ProjectsTaskListPane({
    super.key,
    required this.selectedProjectId,
    required this.selectedTaskId,
    required this.onSelectTask,
    required this.onResetProjectFilter,
    required this.taskRepo,
    this.scrollController,
  });

  final String? selectedProjectId;
  final String? selectedTaskId;
  final ValueChanged<Task> onSelectTask;
  final VoidCallback onResetProjectFilter;
  final TaskRepository taskRepo;
  final ScrollController? scrollController;

  @override
  State<ProjectsTaskListPane> createState() => _ProjectsTaskListPaneState();
}

class _ProjectsTaskListPaneState extends State<ProjectsTaskListPane> {
  int _taskFilterIndex = 0; // 0: All, 1: Today, 2: Active, 3: Done, 4: Collaborative

  int _compareTasks(Task a, Task b) {
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
  }

  Widget _buildFilterButton(String label, int index) {
    final isSelected = _taskFilterIndex == index;
    final isArabic = AppLocalizations.of(context).isArabic;
    final displayLabel = isArabic
        ? switch (index) {
            0 => 'الكل',
            1 => 'اليوم',
            2 => 'النشطة',
            3 => 'المكتملة',
            4 => 'تعاونية',
            _ => label.tr(context),
          }
        : label;
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
          displayLabel,
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

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
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
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Project>>(
      stream: ProjectRepository().watchProjects(),
      builder: (context, projSnap) {
        final projects = projSnap.data ?? [];
        final selProj = projects.cast<Project?>().firstWhere(
          (p) => p != null && p.id == widget.selectedProjectId,
          orElse: () => null,
        );
        final isArabic = AppLocalizations.of(context).isArabic;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isArabic ? 'قائمة المهام' : 'TASK QUEUE',
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
                            label: isArabic ? 'جميع المشاريع' : 'All Projects',
                            icon: Icons.filter_alt_off_outlined,
                            height: 26,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            onPressed: widget.onResetProjectFilter,
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
                    const SizedBox(width: 4),
                    _buildFilterButton('Collaborative', 4),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const CollaborativeTaskDeletedNoticeBanner(
                margin: EdgeInsets.only(bottom: 10),
              ),
              // Task items list
              Expanded(
                child: StreamBuilder<List<Task>>(
                  stream: widget.taskRepo.watchTasks(),
                  builder: (context, snapshot) {
                    final tasks = snapshot.data ?? [];
                    final now = DateTime.now();
                    final todayStr = DateFormat('yyyy-MM-dd').format(now);
                    final tomorrowStr = DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

                    final filtered = tasks.where((t) {
                      if (widget.selectedProjectId != null) {
                        final tProj = t.projectId?.trim() ?? '';
                        final matches = tProj == widget.selectedProjectId ||
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
                      } else if (_taskFilterIndex == 4) {
                        return t.isCollaborative;
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          isArabic ? 'لا توجد مهام مطابقة للتصفية المختارة' : 'No tasks found for selected filter',
                          style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                        ),
                      );
                    }

                    // Separate active collaborative tasks cleanly from personal due-date buckets
                    final collaborativeTasks = <Task>[];
                    final overdueTasks = <Task>[];
                    final todayTasks = <Task>[];
                    final tomorrowTasks = <Task>[];
                    final upcomingTasks = <Task>[];
                    final noDateTasks = <Task>[];
                    final finishedTasks = <Task>[];

                    for (final task in filtered) {
                      if (task.isCollaborative &&
                          (!task.isCompleted || _taskFilterIndex == 4)) {
                        collaborativeTasks.add(task);
                        continue;
                      }
                      if (task.isCompleted) {
                        finishedTasks.add(task);
                        continue;
                      }

                      final d = task.dueDate;
                      if (d == null || d.trim().isEmpty) {
                        noDateTasks.add(task);
                      } else if (d.compareTo(todayStr) < 0) {
                        overdueTasks.add(task);
                      } else if (d == todayStr) {
                        todayTasks.add(task);
                      } else if (d == tomorrowStr) {
                        tomorrowTasks.add(task);
                      } else {
                        upcomingTasks.add(task);
                      }
                    }

                    final sections = <_DesktopTaskSection>[
                      if (collaborativeTasks.isNotEmpty)
                        _DesktopTaskSection(
                          title: isArabic
                              ? 'المهام التعاونية'
                              : 'COLLABORATIVE TASKS',
                          color: AxisColors.secondary,
                          tasks: collaborativeTasks..sort(_compareTasks),
                        ),
                      if (overdueTasks.isNotEmpty)
                        _DesktopTaskSection(
                          title: isArabic ? 'متأخرة' : 'OVERDUE',
                          color: AxisColors.error,
                          tasks: overdueTasks..sort(_compareTasks),
                        ),
                      if (todayTasks.isNotEmpty)
                        _DesktopTaskSection(
                          title: isArabic ? 'اليوم' : 'TODAY',
                          color: AxisColors.primary,
                          tasks: todayTasks..sort(_compareTasks),
                        ),
                      if (tomorrowTasks.isNotEmpty)
                        _DesktopTaskSection(
                          title: isArabic ? 'غداً' : 'TOMORROW',
                          color: AxisColors.secondary,
                          tasks: tomorrowTasks..sort(_compareTasks),
                        ),
                      if (upcomingTasks.isNotEmpty)
                        _DesktopTaskSection(
                          title: isArabic ? 'قادمة' : 'UPCOMING',
                          color: AxisColors.tertiary,
                          tasks: upcomingTasks..sort(_compareTasks),
                        ),
                      if (noDateTasks.isNotEmpty)
                        _DesktopTaskSection(
                          title: isArabic ? 'بدون تاريخ استحقاق' : 'NO DUE DATE',
                          color: AxisColors.textDim,
                          tasks: noDateTasks..sort(_compareTasks),
                        ),
                      if (finishedTasks.isNotEmpty)
                        _DesktopTaskSection(
                          title: isArabic ? 'منتهية' : 'FINISHED',
                          color: AxisColors.tertiary,
                          tasks: finishedTasks..sort(_compareTasks),
                        ),
                    ];

                    // Auto-select first task if none selected or no longer in filtered
                    final allSortedTasks = [
                      for (final s in sections) ...s.tasks,
                    ];
                    final activeSelectedId = widget.selectedTaskId;
                    if ((activeSelectedId == null || !allSortedTasks.any((t) => t.id == activeSelectedId)) && allSortedTasks.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final currentId = widget.selectedTaskId;
                        if (mounted && (currentId == null || !allSortedTasks.any((t) => t.id == currentId))) {
                          widget.onSelectTask(allSortedTasks.first);
                        }
                      });
                    }

                    return Scrollbar(
                      controller: widget.scrollController,
                      thumbVisibility: true,
                      child: ListView(
                        controller: widget.scrollController,
                        padding: const EdgeInsetsDirectional.only(end: 12.0),
                        children: [
                          for (final section in sections) ...[
                            _buildSectionHeader(
                              section.title,
                              section.color,
                              section.tasks.length,
                            ),
                            for (final task in section.tasks)
                              ProjectsTaskItem(
                                task: task,
                                isSelected: widget.selectedTaskId == task.id,
                                todayStr: todayStr,
                                taskRepo: widget.taskRepo,
                                onTap: () => widget.onSelectTask(task),
                              ),
                          ],
                        ],
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
}

class _DesktopTaskSection {
  const _DesktopTaskSection({
    required this.title,
    required this.color,
    required this.tasks,
  });

  final String title;
  final Color color;
  final List<Task> tasks;
}

