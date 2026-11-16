import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/tasks/project_big_task_card.dart';
import 'package:axis/ui/common/category_filter_slider.dart';
import 'package:axis/ui/common/cyber_search_bar.dart';

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
  final void Function({String? initialProject}) onAddTask;

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  late final Stream<List<Project>> _projectsStream;
  late final Stream<List<Task>> _tasksStream;
  final Set<String> _locallyDeletedProjects = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedProjectId = 'all';

  @override
  void initState() {
    super.initState();
    _projectsStream = widget.projectRepo.watchProjects();
    _tasksStream = widget.taskRepo.watchTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildEmptySearchState({
    required String query,
    required VoidCallback onClear,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AxisColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 32, color: AxisColors.secondary),
            ),
            const SizedBox(height: 14),
            Text(
              context.isArabic
                  ? 'لم يتم العثور على مهام لـ "$query"'
                  : 'No tasks found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.isArabic
                  ? 'تحقق من الإملاء أو ابحث بكلمة مفتاحية مختلفة.'
                  : 'Try checking your spelling or search with a different keyword.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AxisColors.secondary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.close_rounded,
                  size: 14, color: AxisColors.secondary),
              label: Text(
                context.isArabic ? 'مسح البحث' : 'Clear Search',
                style: const TextStyle(
                  color: AxisColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                  color: '#0EA5E9',
                ));
              }
            }

            final allProjects = [...customProjects, ...discoveredProjects].where((p) {
              final idLower = p.id.toLowerCase();
              final nameLower = p.name.toLowerCase();
              return idLower != 'work' &&
                     idLower != 'personal' &&
                     idLower != 'growth' &&
                     !_locallyDeletedProjects.contains(idLower) &&
                     !_locallyDeletedProjects.contains(nameLower) &&
                     !_locallyDeletedProjects.contains(idLower.replaceFirst('discovered_', ''));
            }).toList();

            // Separate collaborative tasks from personal project buckets
            final collaborativeTasks =
                allTasks.where((t) => t.isCollaborative).toList();
            final personalTasks =
                allTasks.where((t) => !t.isCollaborative).toList();

            final Map<String, List<Task>> tasksByProject = {};
            final unassignedTasks = <Task>[];

            for (final t in personalTasks) {
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

            // Sort projects: active/in-progress projects first, done/100% completed projects at the end
            allProjects.sort((a, b) {
              final tasksA = tasksByProject[a.name] ?? [];
              final isDoneA = tasksA.isNotEmpty && tasksA.every((t) => t.status == 'done');

              final tasksB = tasksByProject[b.name] ?? [];
              final isDoneB = tasksB.isNotEmpty && tasksB.every((t) => t.status == 'done');

              if (isDoneA != isDoneB) {
                return isDoneA ? 1 : -1;
              }
              return a.createdAt.compareTo(b.createdAt);
            });

            // Build horizontal category filter slider items
            final sliderItems = <CategorySliderItem>[
              CategorySliderItem(
                id: 'all',
                label: context.isArabic ? 'جميع المشاريع' : 'All Projects',
                iconData: Icons.hub_rounded,
                color: AxisColors.secondary,
                count: allTasks.length,
              ),
              if (collaborativeTasks.isNotEmpty)
                CategorySliderItem(
                  id: 'collaborative',
                  label: context.isArabic
                      ? 'المهام التعاونية'
                      : 'Collaborative Tasks',
                  iconData: Icons.handshake_rounded,
                  color: AxisColors.secondary,
                  count: collaborativeTasks.length,
                ),
              ...allProjects.map((project) {
                final subtasks = tasksByProject[project.name] ?? [];
                return CategorySliderItem(
                  id: project.id,
                  label: project.name,
                  iconData: Icons.folder_rounded,
                  color: _parseHex(project.color),
                  count: subtasks.length,
                );
              }),
              if (unassignedTasks.isNotEmpty)
                CategorySliderItem(
                  id: 'inbox_general',
                  label: context.isArabic ? 'الوارد والعام' : 'Inbox & General',
                  iconData: Icons.inbox_rounded,
                  color: const Color(0xFF64748B),
                  count: unassignedTasks.length,
                ),
            ];

            final isSearching = _searchQuery.isNotEmpty;

            final showCollaborativeCard = (_selectedProjectId == 'all' ||
                    _selectedProjectId == 'collaborative') &&
                collaborativeTasks.isNotEmpty;

            final displayedCollaborativeTasks = showCollaborativeCard
                ? (!isSearching
                    ? collaborativeTasks
                    : collaborativeTasks
                        .where((t) =>
                            t.title.toLowerCase().contains(_searchQuery) ||
                            (t.notes?.toLowerCase().contains(_searchQuery) ??
                                false) ||
                            (t.senderUsername
                                    ?.toLowerCase()
                                    .contains(_searchQuery) ??
                                false))
                        .toList())
                : <Task>[];

            // Filter projects based on slider selection and search query
            final displayedProjects = allProjects.where((project) {
              if (_selectedProjectId != 'all') {
                final matches = project.id.toLowerCase() == _selectedProjectId.toLowerCase() ||
                    project.name.toLowerCase() == _selectedProjectId.toLowerCase();
                if (!matches) return false;
              }

              if (isSearching) {
                final subtasks = tasksByProject[project.name] ?? [];
                final hasMatchingSubtask = subtasks.any((t) =>
                    t.title.toLowerCase().contains(_searchQuery) ||
                    (t.notes?.toLowerCase().contains(_searchQuery) ?? false));
                final matchesProjectName = project.name.toLowerCase().contains(_searchQuery);
                return hasMatchingSubtask || matchesProjectName;
              }

              return true;
            }).toList();

            final showUnassignedProject = (_selectedProjectId == 'all' ||
                    _selectedProjectId.toLowerCase() == 'inbox_general') &&
                unassignedTasks.isNotEmpty;

            final displayedUnassignedTasks = showUnassignedProject
                ? (!isSearching
                    ? unassignedTasks
                    : unassignedTasks
                        .where((t) =>
                            t.title.toLowerCase().contains(_searchQuery) ||
                            (t.notes?.toLowerCase().contains(_searchQuery) ?? false))
                        .toList())
                : <Task>[];

            // Count total matching tasks across displayed projects
            int totalMatchingTasks = displayedCollaborativeTasks.length +
                displayedUnassignedTasks.length;
            for (final proj in displayedProjects) {
              final raw = tasksByProject[proj.name] ?? [];
              final filtered = (!isSearching || proj.name.toLowerCase().contains(_searchQuery))
                  ? raw
                  : raw
                      .where((t) =>
                          t.title.toLowerCase().contains(_searchQuery) ||
                          (t.notes?.toLowerCase().contains(_searchQuery) ?? false))
                      .toList();
              totalMatchingTasks += filtered.length;
            }

            return ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Header banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
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
                            children: [
                              const Icon(Icons.hub_rounded,
                                  color: AxisColors.secondary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  context.isArabic ? 'أهداف المشاريع' : 'PROJECT OBJECTIVES',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
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
                          label: Text(
                            context.isArabic ? 'إضافة مشروع' : 'Add Project',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Search bar for tasks and projects
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CyberSearchBar(
                    controller: _searchController,
                    hintText: context.isArabic ? 'بحث في المهام أو المشاريع...' : 'Search tasks or projects...',
                    accentColor: AxisColors.secondary,
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.trim().toLowerCase();
                      });
                    },
                    onClear: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Horizontal category filter slider
                if (sliderItems.length > 1) ...[
                  CategoryFilterSlider(
                    items: sliderItems,
                    selectedId: _selectedProjectId,
                    onSelected: (id) {
                      setState(() {
                        if (_selectedProjectId == id && id != 'all') {
                          _selectedProjectId = 'all';
                        } else {
                          _selectedProjectId = id;
                        }
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  const SizedBox(height: 14),
                ],

                // Empty search results state
                if (isSearching && totalMatchingTasks == 0)
                  _buildEmptySearchState(
                    query: _searchController.text.trim(),
                    onClear: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  )
                // No projects created state
                else if (!isSearching &&
                    allProjects.isEmpty &&
                    unassignedTasks.isEmpty &&
                    collaborativeTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.folder_open_rounded, size: 36, color: AxisColors.textDim),
                          const SizedBox(height: 12),
                          Text(
                            context.isArabic ? 'لم يتم إنشاء مشاريع بعد' : 'No Projects Created Yet',
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.isArabic
                                ? 'انقر على "إضافة مشروع" أعلاه لإنشاء مشروعك المخصص الأول.'
                                : 'Tap "Add Project" above to create your first custom project.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AxisColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                // Render filtered project cards
                else ...[
                  if (displayedCollaborativeTasks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ProjectBigTaskCard(
                        project: Project(
                          id: 'collaborative_tasks',
                          name: context.isArabic
                              ? 'المهام التعاونية'
                              : 'Collaborative Tasks',
                          color: '#0EA5E9',
                        ),
                        color: AxisColors.secondary,
                        subtasks: List<Task>.from(displayedCollaborativeTasks)
                          ..sort(compareTasksByDueDate),
                        forceExpand: isSearching,
                        taskRepo: widget.taskRepo,
                        projectRepo: widget.projectRepo,
                        onAddSubtask: () => widget.onAddTask(),
                      ),
                    ),
                  ],
                  ...displayedProjects.map((project) {
                    final rawSubtasks = tasksByProject[project.name] ?? [];
                    final subtasks = (!isSearching || project.name.toLowerCase().contains(_searchQuery))
                        ? List<Task>.from(rawSubtasks)
                        : rawSubtasks
                            .where((t) =>
                                t.title.toLowerCase().contains(_searchQuery) ||
                                (t.notes?.toLowerCase().contains(_searchQuery) ?? false))
                            .toList();
                    subtasks.sort(compareTasksByDueDate);
                    final color = _parseHex(project.color);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ProjectBigTaskCard(
                        project: project,
                        color: color,
                        subtasks: subtasks,
                        forceExpand: isSearching,
                        taskRepo: widget.taskRepo,
                        projectRepo: widget.projectRepo,
                        onAddSubtask: () =>
                            widget.onAddTask(initialProject: project.name),
                        onDelete: () {
                          setState(() {
                            if (_selectedProjectId == project.id ||
                                _selectedProjectId.toLowerCase() == project.name.toLowerCase()) {
                              _selectedProjectId = 'all';
                            }
                            _locallyDeletedProjects.add(project.id.toLowerCase());
                            _locallyDeletedProjects.add(project.name.toLowerCase());
                            final raw = project.id.toLowerCase().replaceFirst('discovered_', '');
                            _locallyDeletedProjects.add(raw);
                          });
                        },
                      ),
                    );
                  }),

                  // Unassigned / General Tasks section if any
                  if (displayedUnassignedTasks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ProjectBigTaskCard(
                        project: Project(
                          id: 'inbox_general',
                          name: context.isArabic ? 'الوارد والمهام العامة' : 'Inbox & General Tasks',
                          color: '#64748B',
                        ),
                        color: const Color(0xFF64748B),
                        subtasks: List<Task>.from(displayedUnassignedTasks)..sort(compareTasksByDueDate),
                        forceExpand: isSearching,
                        taskRepo: widget.taskRepo,
                        projectRepo: widget.projectRepo,
                        onAddSubtask: () => widget.onAddTask(),
                      ),
                    ),
                  ],
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
