import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/project_big_task_card.dart';

/// PROJECTS TAB (Projects as Big Tasks with Subtasks & Progress Bars)
class ProjectsTab extends StatefulWidget {
  const ProjectsTab({
    super.key,
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
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
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
                  final subtasks = List<Task>.from(tasksByProject[project.name] ?? [])
                    ..sort(compareTasksByDueDate);
                  final color = _parseHex(project.color);

                  return ProjectBigTaskCard(
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
                  ProjectBigTaskCard(
                    project: Project(
                      id: 'inbox_general',
                      name: 'Inbox & General Tasks',
                      color: '#64748B',
                    ),
                    color: const Color(0xFF64748B),
                    subtasks: List<Task>.from(unassignedTasks)..sort(compareTasksByDueDate),
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
