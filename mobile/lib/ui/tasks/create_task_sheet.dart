import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';

/// Modal bottom sheet for structured manual task creation
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
      if (t.dueDate != null) {
        _selectedDate = DateTime.tryParse(t.dueDate!);
      } else {
        _selectedDate = null;
      }
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
    } else if (widget.initialProject != null && widget.initialProject!.trim().isNotEmpty) {
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
    _projectFocusNode.dispose();
    _tagFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    try {
      final projects = await ProjectRepository().getProjects();
      final taskRows = await db.getAll('SELECT tags FROM tasks WHERE tags IS NOT NULL');
      final tagSet = <String>{'urgent', 'deepwork', 'meeting', 'review', 'errand', 'backend', 'frontend'};
      for (final row in taskRows) {
        final tagsStr = row['tags'] as String?;
        if (tagsStr != null && tagsStr.isNotEmpty) {
          for (final t in tagsStr.split(',')) {
            final trimmed = t.trim().replaceAll('@', '');
            if (trimmed.isNotEmpty) tagSet.add(trimmed);
          }
        }
      }
      if (mounted) {
        setState(() {
          _existingProjects = projects;
          _existingTags = tagSet.toList()..sort();
        });
      }
    } catch (_) {}
  }

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.primary;
    }
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

    final project = (rawProject == null || rawProject.isEmpty || rawProject == 'Inbox')
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

  List<Widget> _buildProjectDropdownItems() {
    final query = _projectController.text.trim().toLowerCase();
    final List<Widget> items = [];

    // Inbox / Default (No Project)
    final isInboxSelected = _selectedProject == null ||
        _selectedProject!.isEmpty ||
        _selectedProject!.toLowerCase() == 'inbox';
    items.add(
      _DropdownOption(
        icon: Icons.inbox_rounded,
        iconColor: AxisColors.textDim,
        title: 'Inbox (No Project)',
        isSelected: isInboxSelected,
        onTap: () {
          setState(() {
            _selectedProject = null;
            _projectController.clear();
            _showProjectDropdown = false;
            _projectFocusNode.unfocus();
          });
        },
      ),
    );

    // Filtered projects
    final filtered = _existingProjects.where((p) {
      if (query.isEmpty) return true;
      return p.name.toLowerCase().contains(query);
    }).toList();

    for (final proj in filtered) {
      final isSelected = _selectedProject != null &&
          _selectedProject!.toLowerCase() == proj.name.toLowerCase();
      final color = _parseHex(proj.color);
      items.add(
        _DropdownOption(
          colorDot: color,
          title: proj.name,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedProject = proj.name;
              _projectController.text = proj.name;
              _showProjectDropdown = false;
              _projectFocusNode.unfocus();
            });
          },
        ),
      );
    }

    // Quick-create new project if typed name doesn't match an existing project
    final exactMatch = _existingProjects.any(
      (p) => p.name.toLowerCase() == query,
    );
    if (query.isNotEmpty && !exactMatch && query != 'inbox') {
      final rawTyped = _projectController.text.trim();
      items.add(
        _DropdownOption(
          icon: Icons.add_rounded,
          iconColor: AxisColors.secondary,
          title: 'Create project "$rawTyped"',
          isAction: true,
          onTap: () {
            setState(() {
              _selectedProject = rawTyped;
              _projectController.text = rawTyped;
              _showProjectDropdown = false;
              _projectFocusNode.unfocus();
            });
          },
        ),
      );
    }

    return items;
  }

  List<Widget> _buildTagDropdownItems() {
    final query =
        _tagInputController.text.trim().toLowerCase().replaceAll('@', '');
    final List<Widget> items = [];

    final filtered = _existingTags.where((tag) {
      if (query.isEmpty) return true;
      return tag.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty && query.isEmpty) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            'Type to create a new tag...',
            style: TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    for (final tag in filtered) {
      final isSelected = _selectedTags.contains(tag);
      items.add(
        _DropdownOption(
          icon: Icons.label_outline_rounded,
          iconColor: AxisColors.primary,
          title: '@$tag',
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedTags.remove(tag);
              } else {
                _selectedTags.add(tag);
              }
              _tagInputController.clear();
              _showTagDropdown = false;
              _tagFocusNode.unfocus();
            });
          },
        ),
      );
    }

    // If typed tag doesn't match an existing tag, offer quick-add
    final exactMatch = _existingTags.any(
      (t) => t.toLowerCase() == query,
    );
    if (query.isNotEmpty && !exactMatch) {
      final rawTyped = _tagInputController.text.trim().replaceAll('@', '');
      items.add(
        _DropdownOption(
          icon: Icons.add_rounded,
          iconColor: AxisColors.primary,
          title: 'Add tag "@$rawTyped"',
          isAction: true,
          onTap: () {
            _addCurrentTag();
            setState(() {
              _showTagDropdown = false;
              _tagFocusNode.unfocus();
            });
          },
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;

    return GestureDetector(
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                              color: AxisColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.add_task_rounded,
                                color: AxisColors.primary, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.taskToEdit != null ? 'EDIT TASK' : 'NEW TASK',
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
                    _FieldLabel(label: 'TASK NAME *'),
                    TextField(
                      controller: _titleController,
                      autofocus: false,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AxisColors.textHigh,
                            fontWeight: FontWeight.w500,
                          ),
                      cursorColor: AxisColors.primary,
                      decoration: InputDecoration(
                        hintText: 'e.g., Design user onboarding flow',
                        hintStyle: TextStyle(color: AxisColors.textDim),
                        errorText: _errorText,
                        filled: true,
                        fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AxisColors.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AxisColors.borderSubtle),
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
                    _FieldLabel(label: 'DESCRIPTION & NOTES'),
                    TextField(
                      controller: _descController,
                      maxLines: 3,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AxisColors.textHigh,
                          ),
                      cursorColor: AxisColors.primary,
                      decoration: InputDecoration(
                        hintText: 'Add context, sub-items, or relevant links...',
                        hintStyle: TextStyle(color: AxisColors.textDim),
                        filled: true,
                        fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AxisColors.borderSubtle),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AxisColors.borderSubtle),
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

                    // Priority Selector: 1, 2, 3, None
                    _FieldLabel(label: 'PRIORITY'),
                    Row(
                      children: [
                        _PriorityButton(
                          priorityNumber: 1,
                          label: 'P1 High',
                          color: AxisColors.priorityHigh,
                          isSelected: _priority == 1,
                          onTap: () => setState(() => _priority = 1),
                        ),
                        const SizedBox(width: 8),
                        _PriorityButton(
                          priorityNumber: 2,
                          label: 'P2 Med',
                          color: AxisColors.priorityMed,
                          isSelected: _priority == 2,
                          onTap: () => setState(() => _priority = 2),
                        ),
                        const SizedBox(width: 8),
                        _PriorityButton(
                          priorityNumber: 3,
                          label: 'P3 Low',
                          color: AxisColors.priorityLow,
                          isSelected: _priority == 3,
                          onTap: () => setState(() => _priority = 3),
                        ),
                        const SizedBox(width: 8),
                        _PriorityButton(
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
                    _FieldLabel(label: 'DUE DATE & TIME'),
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
                                color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedDate != null
                                      ? AxisColors.secondary
                                      : AxisColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_month_rounded,
                                      size: 18,
                                      color: _selectedDate != null
                                          ? AxisColors.secondary
                                          : AxisColors.textMuted),
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
                                      onTap: () =>
                                          setState(() => _selectedDate = null),
                                      child: const Icon(Icons.clear_rounded,
                                          size: 16, color: AxisColors.textDim),
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
                                color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _selectedTime != null
                                      ? AxisColors.primary
                                      : AxisColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 18,
                                      color: _selectedTime != null
                                          ? AxisColors.primary
                                          : AxisColors.textMuted),
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
                                      onTap: () =>
                                          setState(() => _selectedTime = null),
                                      child: const Icon(Icons.clear_rounded,
                                          size: 16, color: AxisColors.textDim),
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
                        _QuickDateChip(
                          label: 'Today',
                          isSelected: _selectedDate != null &&
                              _selectedDate!.day == DateTime.now().day &&
                              _selectedDate!.month == DateTime.now().month,
                          onTap: () =>
                              setState(() => _selectedDate = DateTime.now()),
                        ),
                        const SizedBox(width: 6),
                        _QuickDateChip(
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
                        _QuickDateChip(
                          label: 'In 3 Days',
                          isSelected: false,
                          onTap: () => setState(() => _selectedDate =
                              DateTime.now().add(const Duration(days: 3))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Project Dropdown Selector
                    _FieldLabel(label: 'PROJECT'),
                    Container(
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showProjectDropdown
                              ? AxisColors.secondary
                              : AxisColors.borderSubtle,
                          width: _showProjectDropdown ? 1.5 : 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _projectController,
                        focusNode: _projectFocusNode,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AxisColors.textHigh,
                            ),
                        cursorColor: AxisColors.secondary,
                        decoration: InputDecoration(
                          hintText: 'Select or write project name...',
                          hintStyle: const TextStyle(color: AxisColors.textDim, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          prefixIcon: const Icon(Icons.folder_open_rounded,
                              size: 18, color: AxisColors.secondary),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_projectController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.close_rounded,
                                      size: 16, color: AxisColors.textDim),
                                  onPressed: () {
                                    _projectController.clear();
                                    setState(() {
                                      _selectedProject = null;
                                    });
                                  },
                                ),
                              IconButton(
                                icon: Icon(
                                  _showProjectDropdown
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: AxisColors.textDim,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showProjectDropdown = !_showProjectDropdown;
                                    if (_showProjectDropdown) {
                                      _showTagDropdown = false;
                                      _projectFocusNode.requestFocus();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _showProjectDropdown = true;
                            _showTagDropdown = false;
                          });
                        },
                        onChanged: (text) {
                          setState(() {
                            _showProjectDropdown = true;
                            _selectedProject = text.isNotEmpty ? text : null;
                          });
                        },
                      ),
                    ),
                    if (_showProjectDropdown) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AxisColors.secondary.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            children: _buildProjectDropdownItems(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Tag Dropdown Selector
                    _FieldLabel(label: 'TAGS'),
                    if (_selectedTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedTags.map((tag) {
                          return Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AxisColors.primary.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '@$tag',
                                  style: const TextStyle(
                                    color: AxisColors.primarySoft,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setState(() => _selectedTags.remove(tag)),
                                  child: const Icon(Icons.close_rounded,
                                      size: 14, color: AxisColors.textDim),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Container(
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _showTagDropdown
                              ? AxisColors.primary
                              : AxisColors.borderSubtle,
                          width: _showTagDropdown ? 1.5 : 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _tagInputController,
                        focusNode: _tagFocusNode,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AxisColors.textHigh,
                            ),
                        cursorColor: AxisColors.primary,
                        decoration: InputDecoration(
                          hintText: 'Select or write tag name...',
                          hintStyle:
                              const TextStyle(color: AxisColors.textDim, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          prefixIcon: const Icon(Icons.label_outline_rounded,
                              size: 18, color: AxisColors.primary),
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_tagInputController.text.isNotEmpty)
                                IconButton(
                                  icon: const Icon(Icons.add_rounded,
                                      size: 20, color: AxisColors.primary),
                                  tooltip: 'Add tag',
                                  onPressed: _addCurrentTag,
                                ),
                              IconButton(
                                icon: Icon(
                                  _showTagDropdown
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: AxisColors.textDim,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showTagDropdown = !_showTagDropdown;
                                    if (_showTagDropdown) {
                                      _showProjectDropdown = false;
                                      _tagFocusNode.requestFocus();
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _showTagDropdown = true;
                            _showProjectDropdown = false;
                          });
                        },
                        onSubmitted: (_) => _addCurrentTag(),
                        onChanged: (_) {
                          setState(() {
                            _showTagDropdown = true;
                          });
                        },
                      ),
                    ),
                    if (_showTagDropdown) ...[
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AxisColors.primary.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            children: _buildTagDropdownItems(),
                          ),
                        ),
                      ),
                    ],
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
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      widget.taskToEdit != null ? 'SAVE CHANGES' : 'CREATE TASK',
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
  );
}
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AxisColors.textMuted,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _PriorityButton extends StatelessWidget {
  const _PriorityButton({
    required this.priorityNumber,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final int priorityNumber;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.22) : AxisColors.surfaceHigh.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : AxisColors.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : AxisColors.textDim,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickDateChip extends StatelessWidget {
  const _QuickDateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.secondary.withValues(alpha: 0.2)
              : AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AxisColors.secondarySoft : AxisColors.textDim,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _DropdownOption extends StatelessWidget {
  const _DropdownOption({
    this.icon,
    this.iconColor,
    this.colorDot,
    required this.title,
    this.isSelected = false,
    this.isAction = false,
    required this.onTap,
  });

  final IconData? icon;
  final Color? iconColor;
  final Color? colorDot;
  final String title;
  final bool isSelected;
  final bool isAction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AxisColors.surfaceHigh.withValues(alpha: 0.6)
              : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: AxisColors.borderSubtle, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            if (colorDot != null) ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colorDot,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorDot!.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
            ] else if (icon != null) ...[
              Icon(icon, size: 16, color: iconColor ?? AxisColors.textMuted),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isAction
                      ? (iconColor ?? AxisColors.secondary)
                      : (isSelected ? AxisColors.textHigh : AxisColors.textMuted),
                  fontSize: 13,
                  fontWeight:
                      isSelected || isAction ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: AxisColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
