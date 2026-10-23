import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/markdown_list_text_input_formatter.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';
import 'package:axis/ui/tasks/create_project_sheet.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';

/// Desktop Column 2: Master Task Matrix, Projects Deck & Markdown Task Spec Inspector.
class DesktopTasksColumn extends StatefulWidget {
  const DesktopTasksColumn({
    super.key,
    this.searchFilter = '',
    required this.onAddTask,
  });

  final String searchFilter;
  final VoidCallback onAddTask;

  @override
  State<DesktopTasksColumn> createState() => _DesktopTasksColumnState();
}

class _DesktopTasksColumnState extends State<DesktopTasksColumn> {
  final _taskRepo = TaskRepository();
  final _projRepo = ProjectRepository();

  Task? _selectedTask;
  bool _isEditingNotes = false;
  late final TextEditingController _notesController;
  late final FocusNode _notesFocusNode;
  String _prioritySort = 'PRIORITY'; // 'PRIORITY', 'DUE_DATE'

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController();
    _notesFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _selectTask(Task task) {
    setState(() {
      _selectedTask = task;
      _notesController.text = task.notes ?? '';
      _isEditingNotes = false;
    });
  }

  Future<void> _saveTaskNotes() async {
    if (_selectedTask == null) return;
    final updated = _selectedTask!.copyWith(notes: _notesController.text);
    await _taskRepo.updateTask(updated);
    setState(() {
      _selectedTask = updated;
      _isEditingNotes = false;
    });
  }

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.primary;
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Active Projects Deck
          _buildProjectsDeck(),

          const Divider(color: AxisColors.borderSubtle, height: 1),

          // 2. Today's Task Matrix
          Expanded(
            flex: 6,
            child: _buildTasksList(),
          ),

          const Divider(color: AxisColors.borderSubtle, height: 1),

          // 3. Task Spec Inspector (Markdown Viewer & Editor)
          Expanded(
            flex: 5,
            child: _buildTaskSpecInspector(),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsDeck() {
    return StreamBuilder<List<Project>>(
      stream: _projRepo.watchProjects(),
      builder: (context, projSnapshot) {
        final projects = projSnapshot.data ?? [];

        return StreamBuilder<List<Task>>(
          stream: _taskRepo.watchTasks(),
          builder: (context, taskSnapshot) {
            final tasks = taskSnapshot.data ?? [];

            // Compute project progress and sort completed to the end
            final projectData = projects.map((proj) {
              final projTasks = tasks.where((t) => t.projectId == proj.id).toList();
              final done = projTasks.where((t) => t.status == 'done').length;
              final total = projTasks.length;
              final progress = total > 0 ? done / total : 0.0;
              final isDone = total > 0 && done == total;
              return {
                'project': proj,
                'done': done,
                'total': total,
                'progress': progress,
                'isDone': isDone,
              };
            }).toList();

            // Sort: Incomplete projects first, 100% completed projects at the end
            projectData.sort((a, b) {
              final aDone = a['isDone'] as bool;
              final bDone = b['isDone'] as bool;
              if (aDone != bDone) return aDone ? 1 : -1;
              final pA = a['project'] as Project;
              final pB = b['project'] as Project;
              return pA.name.toLowerCase().compareTo(pB.name.toLowerCase());
            });

            return Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              color: const Color(0xFF090E1A),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.folder_special_rounded, size: 14, color: AxisColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Active Projects',
                            style: TextStyle(
                              color: AxisColors.textHigh,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${projectData.where((p) => !(p['isDone'] as bool)).length} of ${projectData.length} Active',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AxisColors.textDim,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Horizontal Projects Cards
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ...projectData.map((data) {
                          final proj = data['project'] as Project;
                          final done = data['done'] as int;
                          final total = data['total'] as int;
                          final progress = data['progress'] as double;
                          final percent = (progress * 100).toInt();
                          final accentColor = _parseHex(proj.color);

                          return Container(
                            width: 130,
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLow,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        proj.name.toUpperCase(),
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: accentColor,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$percent%',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: accentColor,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(1.5),
                                  child: LinearProgressIndicator(
                                    value: progress,
                                    minHeight: 3,
                                    backgroundColor: AxisColors.surfaceHighest,
                                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$done/$total tasks',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    color: AxisColors.textDim,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // + Add Project Round Button with Rainbow Color Picker Border
                        RainbowColorPickerButton(
                          selectedColor: '#6366F1',
                          size: 32,
                          borderWidth: 2.0,
                          onColorSelected: (newColor) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => CreateProjectSheet(onProjectCreated: () {}),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTasksList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header & Sort Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.checklist_rounded, size: 14, color: AxisColors.primarySoft),
                  SizedBox(width: 6),
                  Text(
                    'Today\'s Task Matrix',
                    style: TextStyle(
                      color: AxisColors.textHigh,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _prioritySort = _prioritySort == 'PRIORITY' ? 'DUE_DATE' : 'PRIORITY';
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Text(
                        _prioritySort == 'PRIORITY' ? 'SORT: PRIORITY' : 'SORT: DUE DATE',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: widget.onAddTask,
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.add_rounded, size: 14, color: AxisColors.primary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tasks Stream List
        Expanded(
          child: StreamBuilder<List<Task>>(
            stream: _taskRepo.watchTasks(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }

              var tasks = snapshot.data!;

              // Filter by search query
              if (widget.searchFilter.isNotEmpty) {
                final query = widget.searchFilter.toLowerCase();
                tasks = tasks.where((t) => t.title.toLowerCase().contains(query)).toList();
              }

              // Apply sorting
              if (_prioritySort == 'PRIORITY') {
                tasks.sort(compareTasksByPriority);
              } else {
                tasks.sort(compareTasksByDueDate);
              }

              if (tasks.isEmpty) {
                return const Center(
                  child: Text(
                    'No tasks scheduled for today',
                    style: TextStyle(color: AxisColors.textDim, fontSize: 11),
                  ),
                );
              }

              // Auto-select first task if none selected
              if (_selectedTask == null && tasks.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedTask == null) _selectTask(tasks.first);
                });
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final isDone = task.status == 'done';
                  final isSelected = _selectedTask?.id == task.id;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AxisColors.primary.withValues(alpha: 0.12)
                          : AxisColors.surfaceLow,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? AxisColors.primary.withValues(alpha: 0.5)
                            : AxisColors.borderSubtle,
                      ),
                    ),
                    child: InkWell(
                      onTap: () => _selectTask(task),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _taskRepo.toggleTaskStatus(task, !isDone),
                              child: Icon(
                                isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                size: 16,
                                color: isDone ? AxisColors.tertiary : AxisColors.textDim,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    task.title,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                                      decoration: isDone ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      // Clean Bolt Duration Timer
                                      if (task.estimateMin != null && task.estimateMin! > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.bolt_rounded,
                                              size: 11,
                                              color: AxisColors.secondary,
                                            ),
                                            const SizedBox(width: 1),
                                            Text(
                                              '${task.estimateMin}m',
                                              style: const TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: AxisColors.secondary,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                        ),
                                      if (task.dueDate != null && task.dueDate!.isNotEmpty)
                                        Text(
                                          task.dueDate!,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            color: AxisColors.textDim,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (task.priority != null && task.priority! <= 2)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (task.priority == 1 ? Colors.red : Colors.orange)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  task.priority == 1 ? 'HIGH' : 'MED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: task.priority == 1 ? Colors.red : Colors.orange,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskSpecInspector() {
    if (_selectedTask == null) {
      return const Center(
        child: Text(
          'Select a task to inspect specification',
          style: TextStyle(color: AxisColors.textDim, fontSize: 11),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF070B16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header with Edit / Live Preview Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.code_rounded, size: 14, color: AxisColors.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'Task Spec Inspector',
                    style: TextStyle(
                      color: AxisColors.textHigh,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_isEditingNotes)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AxisColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: const Size(50, 24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      onPressed: _saveTaskNotes,
                      child: const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      setState(() => _isEditingNotes = !_isEditingNotes);
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isEditingNotes
                            ? AxisColors.primary.withValues(alpha: 0.2)
                            : AxisColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isEditingNotes ? Icons.visibility_rounded : Icons.edit_rounded,
                            size: 11,
                            color: AxisColors.textMuted,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            _isEditingNotes ? 'Preview' : 'Edit Spec',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.textHigh,
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

          const SizedBox(height: 8),

          // Markdown Format Toolbar (if editing)
          if (_isEditingNotes) ...[
            NoteFormatToolbar(controller: _notesController, focusNode: _notesFocusNode),
            const SizedBox(height: 6),
          ],

          // Content Area (Editor vs Live Markdown Viewer)
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: _isEditingNotes
                  ? TextField(
                      controller: _notesController,
                      focusNode: _notesFocusNode,
                      maxLines: null,
                      expands: true,
                      inputFormatters: const [
                        MarkdownListTextInputFormatter(),
                      ],
                      style: const TextStyle(
                        color: AxisColors.textHigh,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Enter markdown task specification...',
                        hintStyle: TextStyle(color: AxisColors.textDim, fontSize: 11),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : (_selectedTask!.notes != null && _selectedTask!.notes!.isNotEmpty)
                      ? SingleChildScrollView(
                          child: AxisMarkdownViewer(
                            markdown: _selectedTask!.notes!,
                            onMarkdownChanged: (updatedNotes) async {
                              final updated = _selectedTask!.copyWith(notes: updatedNotes);
                              setState(() => _selectedTask = updated);
                              await TaskRepository().updateTask(updated);
                            },
                          ),
                        )
                      : const Center(
                          child: Text(
                            'No markdown specification attached. Click "Edit Spec" to add.',
                            style: TextStyle(color: AxisColors.textDim, fontSize: 10),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
