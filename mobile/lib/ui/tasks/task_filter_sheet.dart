import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';

// ---------------------------------------------------------------------------
// TASK FILTER CRITERIA MODEL
// ---------------------------------------------------------------------------
class TaskFilterCriteria {
  final int? priority;
  final String? dueDateOption;
  final DateTime? customDate;
  final Set<String> tags;

  const TaskFilterCriteria({
    this.priority,
    this.dueDateOption,
    this.customDate,
    this.tags = const {},
  });

  bool get isActive =>
      priority != null ||
      dueDateOption != null ||
      customDate != null ||
      tags.isNotEmpty;

  int get activeCount {
    int count = 0;
    if (priority != null) count++;
    if (dueDateOption != null || customDate != null) count++;
    if (tags.isNotEmpty) count += tags.length;
    return count;
  }

  bool matches(Task t) {
    // 1. Priority filter
    if (priority != null && t.priority != priority) {
      return false;
    }

    // 2. Due Date filter
    if (dueDateOption != null) {
      if (t.dueDate == null) return false;
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      final tomorrowStr = DateFormat('yyyy-MM-dd')
          .format(now.add(const Duration(days: 1)));

      switch (dueDateOption) {
        case 'today':
          if (t.dueDate != todayStr) return false;
          break;
        case 'tomorrow':
          if (t.dueDate != tomorrowStr) return false;
          break;
        case 'overdue':
          if (t.dueDate!.compareTo(todayStr) >= 0) return false;
          break;
        case 'upcoming':
          if (t.dueDate!.compareTo(todayStr) <= 0) return false;
          break;
        case 'custom':
          if (customDate != null) {
            final customStr =
                DateFormat('yyyy-MM-dd').format(customDate!);
            if (t.dueDate != customStr) return false;
          }
          break;
      }
    }

    // 3. Tag filter: every selected tag must be in task's tags
    if (tags.isNotEmpty) {
      if (t.tags == null || t.tags!.isEmpty) return false;
      final taskTags = t.tags!
          .toLowerCase()
          .split(',')
          .map((e) => e.trim().replaceAll('@', ''))
          .where((e) => e.isNotEmpty)
          .toSet();
      for (final requiredTag in tags) {
        if (!taskTags.contains(requiredTag.toLowerCase().replaceAll('@', ''))) {
          return false;
        }
      }
    }

    return true;
  }
}

// ---------------------------------------------------------------------------
// FILTER DROPDOWN OPTION WIDGET
// ---------------------------------------------------------------------------
class FilterDropdownOption extends StatelessWidget {
  const FilterDropdownOption({
    super.key,
    this.icon,
    this.iconColor,
    required this.title,
    this.isSelected = false,
    this.isAction = false,
    required this.onTap,
  });

  final IconData? icon;
  final Color? iconColor;
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
            if (icon != null) ...[
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

// ---------------------------------------------------------------------------
// FILTER STUDIO CHIP WIDGET
// ---------------------------------------------------------------------------
class FilterStudioChip extends StatelessWidget {
  const FilterStudioChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AxisColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.22)
              : AxisColors.surfaceHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AxisColors.borderSubtle,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? activeColor : AxisColors.textDim),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AxisColors.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TASK FILTER SHEET (Modal with the Filter Card and Reset Filter inside)
// ---------------------------------------------------------------------------
class TaskFilterSheet extends StatefulWidget {
  const TaskFilterSheet({
    super.key,
    required this.filterCriteria,
    required this.repo,
  });

  final ValueNotifier<TaskFilterCriteria> filterCriteria;
  final TaskRepository repo;

  @override
  State<TaskFilterSheet> createState() => _TaskFilterSheetState();
}

class _TaskFilterSheetState extends State<TaskFilterSheet> {
  late int? _selectedPriority;
  late String? _selectedDueDateOption;
  late DateTime? _pickedCustomDate;
  late Set<String> _selectedTags;
  late final Stream<List<Task>> _tasksStream;

  final _tagInputController = TextEditingController();
  final _tagFocusNode = FocusNode();
  bool _showTagDropdown = false;
  final List<String> _existingTags = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    _selectedPriority = widget.filterCriteria.value.priority;
    _selectedDueDateOption = widget.filterCriteria.value.dueDateOption;
    _pickedCustomDate = widget.filterCriteria.value.customDate;
    _selectedTags = Set<String>.from(widget.filterCriteria.value.tags);
    _tasksStream = widget.repo.watchTasks();

    _tagFocusNode.addListener(() {
      if (_tagFocusNode.hasFocus) {
        setState(() {
          _showTagDropdown = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tagInputController.dispose();
    _tagFocusNode.dispose();
    super.dispose();
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

  List<Widget> _buildTagDropdownItems() {
    final query =
        _tagInputController.text.trim().toLowerCase().replaceAll('@', '');
    final List<Widget> items = [];

    // All tags (clear filter) option
    if (_selectedTags.isNotEmpty) {
      items.add(
        FilterDropdownOption(
          icon: Icons.label_off_rounded,
          iconColor: AxisColors.textMuted,
          title: 'All Tags (Clear filter)',
          isAction: true,
          onTap: () {
            setState(() {
              _selectedTags.clear();
              _tagInputController.clear();
              _showTagDropdown = false;
              _tagFocusNode.unfocus();
            });
          },
        ),
      );
    }

    final filtered = _existingTags.where((tag) {
      if (query.isEmpty) return true;
      return tag.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty && query.isEmpty && _selectedTags.isEmpty) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            'Type to search or add tag...',
            style: TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    for (final tag in filtered) {
      final isSelected = _selectedTags.contains(tag);
      items.add(
        FilterDropdownOption(
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

    // Quick add option if query is non-empty and not already in list
    final exactMatch = _existingTags.any((t) => t.toLowerCase() == query);
    if (query.isNotEmpty && !exactMatch) {
      final rawTyped = _tagInputController.text.trim().replaceAll('@', '');
      items.add(
        FilterDropdownOption(
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _pickedCustomDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: AxisTheme.dark.copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AxisColors.primary,
              surface: AxisColors.surfaceHigh,
              onSurface: AxisColors.textHigh,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _pickedCustomDate = picked;
        _selectedDueDateOption = 'custom';
      });
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedPriority = null;
      _selectedDueDateOption = null;
      _selectedTags.clear();
      _pickedCustomDate = null;
      _tagInputController.clear();
      _showTagDropdown = false;
    });
    widget.filterCriteria.value = const TaskFilterCriteria();
  }

  void _applyFilters() {
    widget.filterCriteria.value = TaskFilterCriteria(
      priority: _selectedPriority,
      dueDateOption: _selectedDueDateOption,
      customDate: _pickedCustomDate,
      tags: Set<String>.from(_selectedTags),
    );
  }

  bool _matchesCurrent(Task t) {
    final tempCriteria = TaskFilterCriteria(
      priority: _selectedPriority,
      dueDateOption: _selectedDueDateOption,
      customDate: _pickedCustomDate,
      tags: _selectedTags,
    );
    return tempCriteria.matches(t);
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = _selectedPriority != null ||
        _selectedDueDateOption != null ||
        _selectedTags.isNotEmpty ||
        _pickedCustomDate != null;

    return StreamBuilder<List<Task>>(
      stream: _tasksStream,
      builder: (context, snapshot) {
        final allTasks = snapshot.data ?? [];

        // Collect all distinct tags from existing tasks
        final tagSet = <String>{};
        for (final t in allTasks) {
          if (t.tags != null) {
            for (final tag in t.tags!.split(',')) {
              final clean = tag.trim().replaceAll('@', '');
              if (clean.isNotEmpty) tagSet.add(clean);
            }
          }
        }
        tagSet.addAll(_selectedTags);
        _existingTags
          ..clear()
          ..addAll(tagSet)
          ..sort();

        final matchCount = allTasks.where(_matchesCurrent).length;

        return FocusScope(
          autofocus: false,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => FocusScope.of(context).unfocus(),
            child: Container(
              padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          decoration: const BoxDecoration(
            color: AxisColors.surfaceLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: AxisColors.borderPrimary, width: 1.2),
              left: BorderSide(color: AxisColors.borderPrimary, width: 1.2),
              right: BorderSide(color: AxisColors.borderPrimary, width: 1.2),
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle pill
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AxisColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Filter Controls Card (The exact filter card with reset inside)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AxisColors.borderPrimary),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.tune_rounded,
                                    color: AxisColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'FILTER STUDIO',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.primarySoft,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded,
                                  size: 20, color: AxisColors.textDim),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Divider(color: AxisColors.borderSubtle, height: 20),

                        // 1. Priority Filter Row
                        const Text('PRIORITY',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textMuted,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilterStudioChip(
                              label: 'All',
                              isSelected: _selectedPriority == null,
                              onTap: () => setState(() => _selectedPriority = null),
                            ),
                            const SizedBox(width: 6),
                            FilterStudioChip(
                              label: 'P1 High',
                              color: AxisColors.priorityHigh,
                              isSelected: _selectedPriority == 1,
                              onTap: () => setState(() => _selectedPriority = 1),
                            ),
                            const SizedBox(width: 6),
                            FilterStudioChip(
                              label: 'P2 Medium',
                              color: AxisColors.priorityMed,
                              isSelected: _selectedPriority == 2,
                              onTap: () => setState(() => _selectedPriority = 2),
                            ),
                            const SizedBox(width: 6),
                            FilterStudioChip(
                              label: 'P3 Low',
                              color: AxisColors.priorityLow,
                              isSelected: _selectedPriority == 3,
                              onTap: () => setState(() => _selectedPriority = 3),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 2. Due Date Filter Row
                        const Text('DUE DATE',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textMuted,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterStudioChip(
                                label: 'All Dates',
                                isSelected: _selectedDueDateOption == null,
                                onTap: () => setState(() {
                                  _selectedDueDateOption = null;
                                  _pickedCustomDate = null;
                                }),
                              ),
                              const SizedBox(width: 6),
                              FilterStudioChip(
                                label: 'Today',
                                color: AxisColors.primary,
                                isSelected: _selectedDueDateOption == 'today',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'today'),
                              ),
                              const SizedBox(width: 6),
                              FilterStudioChip(
                                label: 'Tomorrow',
                                color: AxisColors.secondary,
                                isSelected: _selectedDueDateOption == 'tomorrow',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'tomorrow'),
                              ),
                              const SizedBox(width: 6),
                              FilterStudioChip(
                                label: 'Upcoming',
                                color: AxisColors.tertiary,
                                isSelected: _selectedDueDateOption == 'upcoming',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'upcoming'),
                              ),
                              const SizedBox(width: 6),
                              FilterStudioChip(
                                label: 'Overdue',
                                color: AxisColors.error,
                                isSelected: _selectedDueDateOption == 'overdue',
                                onTap: () => setState(
                                    () => _selectedDueDateOption = 'overdue'),
                              ),
                              const SizedBox(width: 6),
                              FilterStudioChip(
                                label: _pickedCustomDate != null
                                    ? DateFormat('d MMM').format(_pickedCustomDate!)
                                    : 'Pick Date...',
                                icon: Icons.calendar_today_rounded,
                                color: AxisColors.secondarySoft,
                                isSelected: _selectedDueDateOption == 'custom',
                                onTap: _pickDate,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Tag Filter (Searchable Dropdown + Chip Wrap matching Create Task Sheet)
                        const Text('TAG',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textMuted,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),

                        if (_selectedTags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _selectedTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
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
                                      onTap: () => setState(
                                          () => _selectedTags.remove(tag)),
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
                            autofocus: false,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AxisColors.textHigh,
                                ),
                            cursorColor: AxisColors.primary,
                            decoration: InputDecoration(
                              hintText: 'Select or write tag name...',
                              hintStyle: const TextStyle(
                                  color: AxisColors.textDim, fontSize: 13),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
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
                        const SizedBox(height: 16),

                        // Results preview count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$matchCount ${matchCount == 1 ? 'task matches' : 'tasks match'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textMuted,
                              ),
                            ),
                            if (hasActiveFilter)
                              const Text(
                                'Filters Configured',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AxisColors.primarySoft,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),

                        const Divider(color: AxisColors.borderSubtle, height: 24),

                        // Action Buttons inside the Filter Card: Reset Filters + Apply
                        Row(
                          children: [
                            // Reset Filter Button inside the card
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: hasActiveFilter ? _clearAllFilters : null,
                                icon: const Icon(Icons.restart_alt_rounded, size: 16),
                                label: const Text('Reset Filters'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AxisColors.secondary,
                                  disabledForegroundColor:
                                      AxisColors.textDim.withValues(alpha: 0.3),
                                  side: BorderSide(
                                    color: hasActiveFilter
                                        ? AxisColors.secondary.withValues(alpha: 0.5)
                                        : AxisColors.borderSubtle,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Apply Button
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  _applyFilters();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('Apply Filters'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AxisColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}
