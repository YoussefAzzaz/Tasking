import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';
import 'package:axis/ui/tasks/widgets/project_selector_field.dart';
import 'package:axis/ui/tasks/widgets/tag_selector_field.dart';

export 'package:axis/ui/tasks/widgets/task_form_widgets.dart';
export 'package:axis/ui/tasks/widgets/project_selector_field.dart';
export 'package:axis/ui/tasks/widgets/tag_selector_field.dart';

/// Modal bottom sheet for structured manual task creation and editing
class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({
    super.key,
    required this.onTaskCreated,
    this.initialProject,
    this.taskToEdit,
    this.onTaskUpdated,
  });

  final VoidCallback onTaskCreated;
  final String? initialProject;
  final Task? taskToEdit;
  final ValueChanged<Task>? onTaskUpdated;

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _projectController = TextEditingController();
  final _tagInputController = TextEditingController();

  final _titleFocusNode = FocusNode();
  final _descFocusNode = FocusNode();
  final _projectFocusNode = FocusNode();
  final _tagFocusNode = FocusNode();

  bool _showProjectDropdown = false;
  bool _showTagDropdown = false;

  int? _priority = 1; // Default to P1
  String? _selectedProject;
  final Set<String> _selectedTags = {};
  DateTime? _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  bool _saving = false;
  String? _errorText;

  List<Project> _existingProjects = [];
  List<String> _existingTags = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _descController.text = t.notes ?? '';
      _priority = t.priority ?? 1;
      _selectedProject = t.projectId;
      if (t.projectId != null) {
        _projectController.text = t.projectId!;
      }
      if (t.tags != null && t.tags!.isNotEmpty) {
        for (final tag in t.tags!.split(',')) {
          final clean = tag.trim().replaceAll('@', '');
          if (clean.isNotEmpty) _selectedTags.add(clean);
        }
      }
      _selectedDate =
          t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;
      if (t.dueTime != null) {
        final parts = t.dueTime!.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]);
          final m = int.tryParse(parts[1]);
          if (h != null && m != null) {
            _selectedTime = TimeOfDay(hour: h, minute: m);
          }
        }
      }
    } else if (widget.initialProject != null &&
        widget.initialProject!.trim().isNotEmpty) {
      _selectedProject = widget.initialProject!.trim();
      _projectController.text = widget.initialProject!.trim();
    }
    _loadExistingData();

    _projectFocusNode.addListener(() {
      if (_projectFocusNode.hasFocus) {
        setState(() {
          _showProjectDropdown = true;
          _showTagDropdown = false;
        });
      }
    });

    _tagFocusNode.addListener(() {
      if (_tagFocusNode.hasFocus) {
        setState(() {
          _showTagDropdown = true;
          _showProjectDropdown = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _projectController.dispose();
    _tagInputController.dispose();
    _titleFocusNode.dispose();
    _descFocusNode.dispose();
    _projectFocusNode.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    try {
      final projects = await ProjectRepository().getProjects();
      final tags = await TagRepository().getTags();
      if (mounted) {
        setState(() {
          _existingProjects = projects;
          _existingTags = tags;
        });
      }
    } catch (_) {}
  }

  void _addCurrentTag() {
    final raw = _tagInputController.text.trim().replaceAll('@', '');
    if (raw.isNotEmpty) {
      setState(() {
        _selectedTags.add(raw);
        if (!_existingTags.contains(raw)) {
          _existingTags.add(raw);
          _existingTags.sort();
        }
        _tagInputController.clear();
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: AxisTheme.dark.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AxisColors.primary,
              onPrimary: AxisColors.textHigh,
              surface: AxisColors.surfaceHigh,
              onSurface: AxisColors.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: AxisTheme.dark.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AxisColors.primary,
              onPrimary: AxisColors.textHigh,
              surface: AxisColors.surfaceHigh,
              onSurface: AxisColors.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorText = 'Please enter a task name');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final notes = _descController.text.trim();
    final dueDateStr = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : null;
    final dueTimeStr = _selectedTime != null
        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
        : null;

    final allTags = Set<String>.from(_selectedTags);
    if (_tagInputController.text.trim().isNotEmpty) {
      allTags.add(_tagInputController.text.trim().replaceAll('@', ''));
    }

    final rawProject = _projectController.text.trim().isNotEmpty
        ? _projectController.text.trim().replaceAll('#', '')
        : _selectedProject;

    final project =
        (rawProject == null || rawProject.isEmpty || rawProject == 'Inbox')
            ? null
            : rawProject;

    // If project was typed by user and doesn't exist yet, save it as a new Project!
    if (project != null) {
      final exists = _existingProjects.any(
        (p) => p.name.toLowerCase() == project.toLowerCase(),
      );
      if (!exists) {
        final newProject = Project(
          id: IdGenerator.generateDeterministicId('proj_$project'),
          name: project,
          color: '#6366F1',
        );
        try {
          await ProjectRepository().addProject(newProject);
        } catch (_) {}
      }
    }

    // Persist any user-defined tags so they can be viewed and managed
    for (final tag in allTags) {
      final clean = tag.trim().replaceAll('@', '');
      if (clean.isNotEmpty) {
        await TagRepository().addTag(clean);
      }
    }

    if (widget.taskToEdit != null) {
      final updated = Task(
        id: widget.taskToEdit!.id,
        title: title,
        notes: notes.isEmpty ? null : notes,
        status: widget.taskToEdit!.status,
        priority: _priority == 0 ? null : _priority,
        projectId: project,
        tags: allTags.isEmpty ? null : allTags.join(','),
        dueDate: dueDateStr,
        dueTime: dueTimeStr,
        estimateMin: widget.taskToEdit!.estimateMin,
        recurrenceRule: widget.taskToEdit!.recurrenceRule,
        recurrenceMode: widget.taskToEdit!.recurrenceMode,
      );
      await TaskRepository().updateTask(updated);
      if (mounted) {
        Navigator.pop(context);
        widget.onTaskUpdated?.call(updated);
        widget.onTaskCreated();
      }
      return;
    }

    final task = Task(
      id: IdGenerator.generateDeterministicId(
          'task_${DateTime.now().microsecondsSinceEpoch}_$title'),
      title: title,
      notes: notes.isEmpty ? null : notes,
      priority: _priority == 0 ? null : _priority,
      projectId: project,
      tags: allTags.isEmpty ? null : allTags.join(','),
      dueDate: dueDateStr,
      dueTime: dueTimeStr,
    );

    await TaskRepository().addTask(task);

    if (mounted) {
      Navigator.pop(context);
      widget.onTaskCreated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return FocusScope(
      autofocus: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _showProjectDropdown = false;
            _showTagDropdown = false;
          });
        },
        child: Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF50D1524),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle and Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AxisColors.borderGlass2,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color:
                                    AxisColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add_task_rounded,
                                  color: AxisColors.primary, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.taskToEdit != null
                                  ? 'EDIT TASK'
                                  : 'NEW TASK',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AxisColors.textHigh,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: AxisColors.textMuted, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(color: AxisColors.borderSubtle, height: 1),

              // Scrollable Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Name
                      const FieldLabel(label: 'TASK NAME *'),
                      TextField(
                        controller: _titleController,
                        focusNode: _titleFocusNode,
                        autofocus: false,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: AxisColors.textHigh,
                                  fontWeight: FontWeight.w500,
                                ),
                        cursorColor: AxisColors.primary,
                        decoration: InputDecoration(
                          hintText: 'e.g., Design user onboarding flow',
                          hintStyle: TextStyle(color: AxisColors.textDim),
                          errorText: _errorText,
                          filled: true,
                          fillColor:
                              AxisColors.surfaceHigh.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AxisColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AxisColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AxisColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Description / Notes
                      const FieldLabel(label: 'DESCRIPTION & NOTES'),
                      TextField(
                        controller: _descController,
                        focusNode: _descFocusNode,
                        autofocus: false,
                        maxLines: 3,
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AxisColors.textHigh,
                                ),
                        cursorColor: AxisColors.primary,
                        decoration: InputDecoration(
                          hintText:
                              'Add context, sub-items, or relevant links...',
                          hintStyle: TextStyle(color: AxisColors.textDim),
                          filled: true,
                          fillColor:
                              AxisColors.surfaceHigh.withValues(alpha: 0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AxisColors.borderSubtle),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AxisColors.borderSubtle),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AxisColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Priority Selector
                      const FieldLabel(label: 'PRIORITY'),
                      Row(
                        children: [
                          PriorityButton(
                            priorityNumber: 1,
                            label: 'P1 High',
                            color: AxisColors.priorityHigh,
                            isSelected: _priority == 1,
                            onTap: () => setState(() => _priority = 1),
                          ),
                          const SizedBox(width: 8),
                          PriorityButton(
                            priorityNumber: 2,
                            label: 'P2 Med',
                            color: AxisColors.priorityMed,
                            isSelected: _priority == 2,
                            onTap: () => setState(() => _priority = 2),
                          ),
                          const SizedBox(width: 8),
                          PriorityButton(
                            priorityNumber: 3,
                            label: 'P3 Low',
                            color: AxisColors.priorityLow,
                            isSelected: _priority == 3,
                            onTap: () => setState(() => _priority = 3),
                          ),
                          const SizedBox(width: 8),
                          PriorityButton(
                            priorityNumber: 0,
                            label: 'None',
                            color: AxisColors.textMuted,
                            isSelected: _priority == 0 || _priority == null,
                            onTap: () => setState(() => _priority = 0),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Date & Time Picker
                      const FieldLabel(label: 'DUE DATE & TIME'),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceHigh
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedDate != null
                                        ? AxisColors.secondary
                                        : AxisColors.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 18,
                                      color: _selectedDate != null
                                        ? AxisColors.secondary
                                        : AxisColors.textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _selectedDate != null
                                            ? DateFormat('EEE, d MMM yyyy')
                                                .format(_selectedDate!)
                                            : 'Pick Due Date',
                                        style: TextStyle(
                                          color: _selectedDate != null
                                              ? AxisColors.textHigh
                                              : AxisColors.textDim,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (_selectedDate != null)
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedDate = null),
                                        child: const Icon(Icons.clear_rounded,
                                            size: 16,
                                            color: AxisColors.textDim),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: _pickTime,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceHigh
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _selectedTime != null
                                        ? AxisColors.primary
                                        : AxisColors.borderSubtle,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 18,
                                      color: _selectedTime != null
                                        ? AxisColors.primary
                                        : AxisColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        _selectedTime != null
                                            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                                            : 'Time',
                                        style: TextStyle(
                                          color: _selectedTime != null
                                              ? AxisColors.textHigh
                                              : AxisColors.textDim,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (_selectedTime != null)
                                      GestureDetector(
                                        onTap: () => setState(
                                            () => _selectedTime = null),
                                        child: const Icon(Icons.clear_rounded,
                                            size: 16,
                                            color: AxisColors.textDim),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Quick Date Chips
                      Row(
                        children: [
                          QuickDateChip(
                            label: 'Today',
                            isSelected: _selectedDate != null &&
                                _selectedDate!.day == DateTime.now().day &&
                                _selectedDate!.month == DateTime.now().month,
                            onTap: () =>
                                setState(() => _selectedDate = DateTime.now()),
                          ),
                          const SizedBox(width: 6),
                          QuickDateChip(
                            label: 'Tomorrow',
                            isSelected: _selectedDate != null &&
                                _selectedDate!.day ==
                                    DateTime.now()
                                        .add(const Duration(days: 1))
                                        .day,
                            onTap: () => setState(() => _selectedDate =
                                DateTime.now().add(const Duration(days: 1))),
                          ),
                          const SizedBox(width: 6),
                          QuickDateChip(
                            label: 'In 3 Days',
                            isSelected: false,
                            onTap: () => setState(() => _selectedDate =
                                DateTime.now().add(const Duration(days: 3))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Project Dropdown Selector
                      ProjectSelectorField(
                        controller: _projectController,
                        focusNode: _projectFocusNode,
                        selectedProject: _selectedProject,
                        existingProjects: _existingProjects,
                        isOpen: _showProjectDropdown,
                        onOpenChanged: (open) {
                          setState(() {
                            _showProjectDropdown = open;
                            if (open) {
                              _showTagDropdown = false;
                              _projectFocusNode.requestFocus();
                            }
                          });
                        },
                        onSelectProject: (proj) {
                          setState(() {
                            _selectedProject = proj;
                            _projectController.text = proj ?? '';
                          });
                        },
                        onClear: () {
                          _projectController.clear();
                          setState(() => _selectedProject = null);
                        },
                      ),
                      const SizedBox(height: 18),

                      // Tag Dropdown Selector
                      TagSelectorField(
                        controller: _tagInputController,
                        focusNode: _tagFocusNode,
                        selectedTags: _selectedTags,
                        existingTags: _existingTags,
                        isOpen: _showTagDropdown,
                        onOpenChanged: (open) {
                          setState(() {
                            _showTagDropdown = open;
                            if (open) {
                              _showProjectDropdown = false;
                              _tagFocusNode.requestFocus();
                            }
                          });
                        },
                        onToggleTag: (tag) {
                          setState(() {
                            if (_selectedTags.contains(tag)) {
                              _selectedTags.remove(tag);
                            } else {
                              _selectedTags.add(tag);
                            }
                          });
                        },
                        onAddCurrentTag: _addCurrentTag,
                      ),
                      const SizedBox(height: 28),

                      // Submit Action Button
                      InkWell(
                        onTap: _saving ? null : _saveTask,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AxisColors.primary,
                                Color(0xFF6366F1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AxisColors.primary.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.taskToEdit != null
                                            ? 'SAVE CHANGES'
                                            : 'CREATE TASK',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelLarge
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.2,
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
