import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/project_repository.dart';
import 'package:axis/data/tag_repository.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';
import 'package:axis/ui/tasks/widgets/project_selector_field.dart';
import 'package:axis/ui/tasks/widgets/tag_selector_field.dart';
import 'package:axis/ui/tasks/widgets/task_duration_picker_sheet.dart';
import 'package:axis/ui/tasks/widgets/task_priority_selector.dart';
import 'package:axis/ui/tasks/widgets/task_description_editor.dart';
import 'package:axis/ui/tasks/widgets/task_date_picker_row.dart';
import 'package:axis/ui/tasks/services/task_form_service.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';
import 'package:axis/domain/calendar_scheduler.dart';

export 'package:axis/ui/tasks/widgets/task_form_widgets.dart';
export 'package:axis/ui/tasks/widgets/project_selector_field.dart';
export 'package:axis/ui/tasks/widgets/tag_selector_field.dart';
export 'package:axis/ui/tasks/widgets/task_duration_picker_sheet.dart';
export 'package:axis/ui/tasks/widgets/task_priority_selector.dart';
export 'package:axis/ui/tasks/widgets/task_description_editor.dart';
export 'package:axis/ui/tasks/widgets/task_date_picker_row.dart';
export 'package:axis/ui/tasks/services/task_form_service.dart';

/// Modal bottom sheet for structured manual task creation and editing
class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({
    super.key,
    required this.onTaskCreated,
    this.initialProject,
    this.initialDate,
    this.initialTime,
    this.taskToEdit,
    this.onTaskUpdated,
    this.isDesktop = false,
  });

  final VoidCallback onTaskCreated;
  final String? initialProject;
  final DateTime? initialDate;
  final String? initialTime;
  final Task? taskToEdit;
  final ValueChanged<Task>? onTaskUpdated;
  final bool isDesktop;

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
  bool _previewDescMode = false;
  bool _isDescExpanded = false;

  int? _priority = 1; // Default to P1
  String? _selectedProject;
  final Set<String> _selectedTags = {};
  DateTime? _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  int _estimateMin = 15;
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
    final now = DateTime.now();
    _selectedDate = widget.initialDate ?? now;
    final isToday = _selectedDate!.year == now.year &&
        _selectedDate!.month == now.month &&
        _selectedDate!.day == now.day;

    if (widget.taskToEdit != null) {
      final t = widget.taskToEdit!;
      _titleController.text = t.title;
      _descController.text = t.notes ?? '';
      if ((t.notes ?? '').trim().isNotEmpty) {
        _isDescExpanded = true;
      }
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
      _selectedDate = t.dueDate != null
          ? DateTime.tryParse(t.dueDate!)
          : null;
      if (t.dueTime != null && t.dueTime!.isNotEmpty) {
        final parsed = CalendarScheduler.parseTimeToMinutes(t.dueTime);
        if (parsed != null) {
          _selectedTime = TimeOfDay(hour: parsed ~/ 60, minute: parsed % 60);
        }
      }
      _estimateMin = (t.estimateMin != null && t.estimateMin! > 0)
          ? t.estimateMin!
          : 15;
    } else if (widget.initialProject != null &&
        widget.initialProject!.trim().isNotEmpty) {
      _selectedProject = widget.initialProject!.trim();
      _projectController.text = widget.initialProject!.trim();
      if (widget.initialTime != null && widget.initialTime!.isNotEmpty) {
        final parsed = CalendarScheduler.parseTimeToMinutes(widget.initialTime);
        if (parsed != null) {
          _selectedTime = TimeOfDay(hour: parsed ~/ 60, minute: parsed % 60);
        }
      } else if (isToday) {
        final defMin = CalendarScheduler.defaultTodayTaskStartMinute(now);
        _selectedTime = TimeOfDay(hour: defMin ~/ 60, minute: defMin % 60);
      }
    } else {
      if (widget.initialTime != null && widget.initialTime!.isNotEmpty) {
        final parsed = CalendarScheduler.parseTimeToMinutes(widget.initialTime);
        if (parsed != null) {
          _selectedTime = TimeOfDay(hour: parsed ~/ 60, minute: parsed % 60);
        }
      } else if (isToday) {
        final defMin = CalendarScheduler.defaultTodayTaskStartMinute(now);
        _selectedTime = TimeOfDay(hour: defMin ~/ 60, minute: defMin % 60);
      }
    }
    _loadExistingData();

    _descFocusNode.addListener(() {
      if (_descFocusNode.hasFocus) {
        if (!_isDescExpanded) {
          setState(() {
            _isDescExpanded = true;
          });
        }
        if (_showProjectDropdown || _showTagDropdown) {
          setState(() {
            _showProjectDropdown = false;
            _showTagDropdown = false;
          });
        }
      }
    });

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

  Future<void> _pickDuration() async {
    await TaskDurationPickerSheet.show(
      context: context,
      initialEstimateMin: _estimateMin,
      onApplied: (val) =>
          setState(() => _estimateMin = (val > 0) ? val : 15),
      onCleared: () => setState(() => _estimateMin = 15),
    );
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _selectedTime ??
        TimeOfDay(
          hour: CalendarScheduler.defaultTodayTaskStartMinute(now) ~/ 60,
          minute: CalendarScheduler.defaultTodayTaskStartMinute(now) % 60,
        );
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
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
      setState(() => _errorText = context.isArabic ? 'يرجى إدخال اسم المهمة' : 'Please enter a task name');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      final dueTimeStr = (_selectedDate != null && _selectedTime != null)
          ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
          : null;

      final savedTask = await TaskFormService().saveTask(
        taskToEdit: widget.taskToEdit,
        title: title,
        notes: _descController.text.trim(),
        priority: _priority,
        rawProject: _projectController.text.trim().isNotEmpty
            ? _projectController.text.trim()
            : _selectedProject,
        selectedTags: _selectedTags,
        additionalTag: _tagInputController.text,
        selectedDate: _selectedDate,
        estimateMin: _estimateMin,
        existingProjects: _existingProjects,
        dueTime: dueTimeStr,
      );

      if (mounted) {
        Navigator.pop(context);
        if (widget.taskToEdit != null) {
          widget.onTaskUpdated?.call(savedTask);
        }
        widget.onTaskCreated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = context.isArabic ? 'فشل حفظ المهمة: $e' : 'Failed to save task: $e';
        });
      }
    }
  }

  Widget _buildTaskNameField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label: context.isArabic ? 'اسم المهمة *' : 'TASK NAME *'),
        AutoDirectionScope(
          controller: _titleController,
          child: TextField(
            controller: _titleController,
            focusNode: _titleFocusNode,
            autofocus: false,
            onChanged: (_) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AxisColors.textHigh,
                  fontWeight: FontWeight.w500,
                ),
            cursorColor: AxisColors.primary,
            decoration: InputDecoration(
              hintText: context.isArabic
                  ? 'مثال: تصميم واجهة المستخدم'
                  : 'e.g., Design user onboarding flow',
              hintStyle: const TextStyle(color: AxisColors.textDim),
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
                borderSide:
                    const BorderSide(color: AxisColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPriorityField(BuildContext context) {
    return TaskPrioritySelector(
      priority: _priority,
      onPriorityChanged: (p) => setState(() => _priority = p),
    );
  }

  Widget _buildDatePickerRow(BuildContext context) {
    return TaskDatePickerRow(
      selectedDate: _selectedDate,
      estimateMin: _estimateMin,
      onPickDate: _pickDate,
      onClearDate: () => setState(() {
        _selectedDate = null;
        _selectedTime = null;
      }),
      onPickDuration: _pickDuration,
      onClearDuration: () => setState(() => _estimateMin = 15),
      onSelectEstimateMin: (min) =>
          setState(() => _estimateMin = (min > 0) ? min : 15),
      onSelectQuickDate: (date) {
        setState(() {
          _selectedDate = date;
          final now = DateTime.now();
          if (date.year == now.year && date.month == now.month && date.day == now.day) {
            final defMin = CalendarScheduler.defaultTodayTaskStartMinute(now);
            _selectedTime = TimeOfDay(hour: defMin ~/ 60, minute: defMin % 60);
          }
        });
      },
      selectedTime: _selectedTime,
      onPickTime: _pickTime,
      onClearTime: () => setState(() => _selectedTime = null),
    );
  }

  Widget _buildProjectField(BuildContext context) {
    return ProjectSelectorField(
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
    );
  }

  Widget _buildTagField(BuildContext context) {
    return TagSelectorField(
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
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return TaskSubmitButton(
      isEdit: widget.taskToEdit != null,
      isSaving: _saving,
      onPressed: _saving ? null : _saveTask,
    );
  }

  Widget _buildSettingsPanel(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaskNameField(context),
          const SizedBox(height: 18),
          _buildPriorityField(context),
          const SizedBox(height: 18),
          _buildDatePickerRow(context),
          const SizedBox(height: 18),
          _buildProjectField(context),
          const SizedBox(height: 18),
          _buildTagField(context),
          const SizedBox(height: 28),
          _buildSubmitButton(context),
        ],
      ),
    );
  }

  Widget _buildDescriptionPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: TaskDescriptionEditor(
        controller: _descController,
        focusNode: _descFocusNode,
        isExpanded: true,
        previewMode: _previewDescMode,
        onToggleExpanded: () =>
            setState(() => _isDescExpanded = !_isDescExpanded),
        onTogglePreview: () =>
            setState(() => _previewDescMode = !_previewDescMode),
        onChanged: () => setState(() {}),
        isDesktop: true,
      ),
    );
  }

  Widget _buildDesktopTwoPanels(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTaskNameField(context),
                const SizedBox(height: 18),
                TaskDescriptionEditor(
                  controller: _descController,
                  focusNode: _descFocusNode,
                  isExpanded: _isDescExpanded,
                  previewMode: _previewDescMode,
                  onToggleExpanded: () =>
                      setState(() => _isDescExpanded = !_isDescExpanded),
                  onTogglePreview: () =>
                      setState(() => _previewDescMode = !_previewDescMode),
                  onChanged: () => setState(() {}),
                  isDesktop: false,
                ),
                const SizedBox(height: 18),
                _buildPriorityField(context),
                const SizedBox(height: 18),
                _buildDatePickerRow(context),
                const SizedBox(height: 18),
                _buildProjectField(context),
                const SizedBox(height: 18),
                _buildTagField(context),
                const SizedBox(height: 28),
                _buildSubmitButton(context),
              ],
            ),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Panel: Settings and options
            Expanded(
              flex: 1,
              child: _buildSettingsPanel(context),
            ),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AxisColors.borderSubtle,
            ),
            // Right Panel: Description tools and description box
            Expanded(
              flex: 1,
              child: _buildDescriptionPanel(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDesktop) {
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
          child: Container(
            color: const Color(0xF50D1524),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TaskSheetHeader(
                  isEdit: widget.taskToEdit != null,
                  isDesktop: true,
                  onClose: () => Navigator.pop(context),
                  onShare: (widget.taskToEdit != null &&
                          !widget.taskToEdit!.isCompleted)
                      ? () => ShareTaskSheet.show(context, widget.taskToEdit!)
                      : null,
                ),
                const Divider(color: AxisColors.borderSubtle, height: 1),
                Expanded(
                  child: _buildDesktopTwoPanels(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final insets = MediaQuery.of(context).viewInsets;

    return FocusScope(
      autofocus: false,
      child: ModalSheetScaffold(
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
                  // Handle and Header (tap to close automatically)
                  ModalSheetTopBar(
                    child: TaskSheetHeader(
                      isEdit: widget.taskToEdit != null,
                      isDesktop: false,
                      onClose: () => Navigator.pop(context),
                      onShare: (widget.taskToEdit != null &&
                              !widget.taskToEdit!.isCompleted)
                          ? () => ShareTaskSheet.show(context, widget.taskToEdit!)
                          : null,
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
                          _buildTaskNameField(context),
                          const SizedBox(height: 18),

                          // Description / Notes (with Markup & Markdown support)
                          TaskDescriptionEditor(
                            controller: _descController,
                            focusNode: _descFocusNode,
                            isExpanded: _isDescExpanded,
                            previewMode: _previewDescMode,
                            onToggleExpanded: () =>
                                setState(() => _isDescExpanded = !_isDescExpanded),
                            onTogglePreview: () =>
                                setState(() => _previewDescMode = !_previewDescMode),
                            onChanged: () => setState(() {}),
                            isDesktop: false,
                          ),
                          const SizedBox(height: 18),

                          _buildPriorityField(context),
                          const SizedBox(height: 18),
                          _buildDatePickerRow(context),
                          const SizedBox(height: 18),
                          _buildProjectField(context),
                          const SizedBox(height: 18),
                          _buildTagField(context),
                          const SizedBox(height: 28),
                          _buildSubmitButton(context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
