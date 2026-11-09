import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/models/task_filter_criteria.dart';
import 'package:axis/ui/tasks/widgets/task_filter_widgets.dart';
import 'package:axis/ui/tasks/widgets/filter_studio_rows.dart';
import 'package:axis/ui/tasks/widgets/filter_studio_tag_selector.dart';

export 'package:axis/domain/models/task_filter_criteria.dart';
export 'package:axis/ui/tasks/widgets/task_filter_widgets.dart';
export 'package:axis/ui/tasks/widgets/filter_studio_rows.dart';
export 'package:axis/ui/tasks/widgets/filter_studio_tag_selector.dart';

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

  List<Widget> _buildTagDropdownItems(BuildContext context) {
    final query =
        _tagInputController.text.trim().toLowerCase().replaceAll('@', '');
    final List<Widget> items = [];

    // All tags (clear filter) option
    if (_selectedTags.isNotEmpty) {
      items.add(
        FilterDropdownOption(
          icon: Icons.label_off_rounded,
          iconColor: AxisColors.textMuted,
          title: context.isArabic ? 'جميع الوسوم (مسح الفلتر)' : 'All Tags (Clear filter)',
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            context.isArabic ? 'اكتب للبحث أو إضافة وسم...' : 'Type to search or add tag...',
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
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
          title: context.isArabic ? 'إضافة وسم "@$rawTyped"' : 'Add tag "@$rawTyped"',
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
                              children: [
                                const Icon(Icons.tune_rounded,
                                    color: AxisColors.primary, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  context.isArabic ? 'استوديو الفلاتر' : 'FILTER STUDIO',
                                  style: const TextStyle(
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
                        FilterPriorityRow(
                          selectedPriority: _selectedPriority,
                          onSelectPriority: (p) =>
                              setState(() => _selectedPriority = p),
                        ),
                        const SizedBox(height: 16),

                        // 2. Due Date Filter Row
                        FilterDueDateRow(
                          selectedDueDateOption: _selectedDueDateOption,
                          pickedCustomDate: _pickedCustomDate,
                          onSelectOption: (opt) => setState(() {
                            _selectedDueDateOption = opt;
                            if (opt == null) _pickedCustomDate = null;
                          }),
                          onPickCustomDate: _pickDate,
                        ),
                        const SizedBox(height: 16),

                        // 3. Tag Filter
                        FilterStudioTagSelector(
                          selectedTags: _selectedTags,
                          controller: _tagInputController,
                          focusNode: _tagFocusNode,
                          showDropdown: _showTagDropdown,
                          dropdownItems: _buildTagDropdownItems(context),
                          onToggleDropdown: () {
                            setState(() {
                              _showTagDropdown = !_showTagDropdown;
                              if (_showTagDropdown) {
                                _tagFocusNode.requestFocus();
                              }
                            });
                          },
                          onTapField: () =>
                              setState(() => _showTagDropdown = true),
                          onSubmit: (_) => _addCurrentTag(),
                          onChanged: (_) =>
                              setState(() => _showTagDropdown = true),
                          onRemoveTag: (tag) =>
                              setState(() => _selectedTags.remove(tag)),
                          onAddTag: _addCurrentTag,
                        ),
                        const SizedBox(height: 16),

                        // Results preview count
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              context.isArabic
                                  ? '$matchCount ${matchCount == 1 ? 'مهمة مطابقة' : 'مهام مطابقة'}'
                                  : '$matchCount ${matchCount == 1 ? 'task matches' : 'tasks match'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textMuted,
                              ),
                            ),
                            if (hasActiveFilter)
                              Text(
                                context.isArabic ? 'تم ضبط الفلاتر' : 'Filters Configured',
                                style: const TextStyle(
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
                                label: Text(context.isArabic ? 'إعادة ضبط الفلاتر' : 'Reset Filters'),
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
                                label: Text(context.isArabic ? 'تطبيق الفلاتر' : 'Apply Filters'),
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
