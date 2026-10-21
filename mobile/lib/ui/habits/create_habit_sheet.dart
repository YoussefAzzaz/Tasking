import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';

export 'package:axis/ui/habits/widgets/habit_form_widgets.dart';

class CreateHabitSheet extends StatefulWidget {
  const CreateHabitSheet({
    super.key,
    required this.onHabitCreated,
    this.habitToEdit,
    this.initialCategory,
    this.existingCategories,
  });

  final VoidCallback onHabitCreated;
  final Habit? habitToEdit;
  final String? initialCategory;
  final List<HabitCategory>? existingCategories;

  @override
  State<CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends State<CreateHabitSheet> {
  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _categoryController = TextEditingController();
  final _categoryFocusNode = FocusNode();

  bool _showCategoryDropdown = false;
  String _selectedIcon = 'fitness';
  String _scheduleType = 'daily';
  TimeOfDay? _reminderTime = const TimeOfDay(hour: 7, minute: 0);
  int _targetXp = 20;
  String _selectedColor = '#10B981';
  bool _saving = false;
  String? _errorText;

  List<HabitCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
    if (widget.existingCategories != null && widget.existingCategories!.isNotEmpty) {
      _categories = List<HabitCategory>.from(widget.existingCategories!);
    }
    if (widget.habitToEdit != null) {
      final h = widget.habitToEdit!;
      _nameController.text = h.name;
      _categoryController.text = h.category;
      _selectedIcon = h.icon;
      _selectedColor = h.color;
      _scheduleType = h.scheduleType;
      _targetXp = h.targetValue;
      if (h.remindTime != null && h.remindTime!.isNotEmpty) {
        try {
          final parts = h.remindTime!.split(' ');
          final timeParts = parts[0].split(':');
          int hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          if (parts.length > 1 &&
              parts[1].toUpperCase() == 'PM' &&
              hour != 12) {
            hour += 12;
          } else if (parts.length > 1 &&
              parts[1].toUpperCase() == 'AM' &&
              hour == 12) {
            hour = 0;
          }
          _reminderTime = TimeOfDay(hour: hour, minute: minute);
        } catch (_) {}
      }
    } else if (widget.initialCategory != null &&
        widget.initialCategory!.trim().isNotEmpty) {
      _categoryController.text = widget.initialCategory!.trim();
    }
    _loadCategories();
    _categoryFocusNode.addListener(() {
      if (_categoryFocusNode.hasFocus) {
        setState(() => _showCategoryDropdown = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final list = await HabitCategoryRepository().getCategories(forceRefresh: true);
      if (mounted) {
        setState(() {
          final merged = <HabitCategory>[...list];
          final names = merged.map((c) => c.name.toLowerCase()).toSet();
          if (widget.existingCategories != null) {
            for (final ec in widget.existingCategories!) {
              if (!names.contains(ec.name.toLowerCase())) {
                names.add(ec.name.toLowerCase());
                merged.add(ec);
              }
            }
          }
          _categories = merged;
          if (widget.habitToEdit == null &&
              _categoryController.text.trim().isNotEmpty) {
            final cat = _categoryController.text.trim().toLowerCase();
            final match = _categories.firstWhere(
              (c) => c.name.toLowerCase() == cat,
              orElse: () => const HabitCategory(id: '', name: ''),
            );
            if (match.name.isNotEmpty) {
              _selectedIcon = match.icon;
              _selectedColor = match.color;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
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
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Please enter a habit name');
      return;
    }

    setState(() {
      _saving = true;
      _errorText = null;
    });

    final categoryName = _categoryController.text.trim();
    if (categoryName.isNotEmpty) {
      final exists = _categories.any(
        (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      );
      if (!exists) {
        await HabitCategoryRepository().addCategory(
          name: categoryName,
          icon: _selectedIcon,
          color: _selectedColor,
        );
      }
    }

    final timeStr = _reminderTime != null
        ? '${_reminderTime!.hourOfPeriod == 0 ? 12 : _reminderTime!.hourOfPeriod}:${_reminderTime!.minute.toString().padLeft(2, '0')} ${_reminderTime!.period == DayPeriod.am ? 'AM' : 'PM'}'
        : null;

    final category = categoryName.isNotEmpty ? categoryName : 'General Routines';

    if (widget.habitToEdit != null) {
      final updatedHabit = Habit(
        id: widget.habitToEdit!.id,
        name: name,
        category: category,
        icon: _selectedIcon,
        color: _selectedColor,
        scheduleType: _scheduleType,
        remindTime: timeStr,
        targetValue: _targetXp,
        isDoneToday: widget.habitToEdit!.isDoneToday,
        streakDays: widget.habitToEdit!.streakDays,
      );
      await HabitRepository().updateHabit(updatedHabit);
      if (mounted) {
        Navigator.pop(context);
        widget.onHabitCreated();
      }
      return;
    }

    final habit = Habit(
      id: IdGenerator.generateDeterministicId(
          'habit_${DateTime.now().microsecondsSinceEpoch}_$name'),
      name: name,
      category: category,
      icon: _selectedIcon,
      color: _selectedColor,
      scheduleType: _scheduleType,
      remindTime: timeStr,
      targetValue: _targetXp,
    );

    await HabitRepository().addHabit(habit);

    if (mounted) {
      Navigator.pop(context);
      widget.onHabitCreated();
    }
  }

  void _confirmDelete() {
    if (widget.habitToEdit == null) return;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          'Delete "${widget.habitToEdit!.name}"?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: const Text(
          'Are you sure you want to delete this habit? All progress and logs will be removed.',
          style: TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _saving = true);
              await HabitRepository().deleteHabit(widget.habitToEdit!.id);
              if (mounted) {
                Navigator.pop(context);
                widget.onHabitCreated();
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight =
        (screenHeight - insets.bottom).clamp(260.0, screenHeight);

    return FocusScope(
      autofocus: false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() => _showCategoryDropdown = false);
        },
        child: Padding(
          padding: EdgeInsets.only(bottom: insets.bottom),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: availableHeight * 0.90,
            ),
            decoration: BoxDecoration(
              color: const Color(0xF50A1422),
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
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
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AxisColors.success
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    color: AxisColors.success,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      widget.habitToEdit != null
                                          ? 'EDIT HABIT ROUTINE'
                                          : 'NEW HABIT ROUTINE',
                                      maxLines: 1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AxisColors.textHigh,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

                // Form Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        const FieldLabel(label: 'HABIT NAME *'),
                        TextField(
                          controller: _nameController,
                          focusNode: _nameFocusNode,
                          autofocus: false,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: AxisColors.textHigh,
                                  ),
                          cursorColor: AxisColors.success,
                          decoration: InputDecoration(
                            hintText: 'e.g. Read 20 Pages, Morning Run',
                            hintStyle: TextStyle(color: AxisColors.textDim),
                            errorText: _errorText,
                            filled: true,
                            fillColor:
                                AxisColors.surfaceHigh.withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AxisColors.borderSubtle),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AxisColors.borderSubtle),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AxisColors.success, width: 1.5),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Category Dropdown Selector
                        const FieldLabel(label: 'CATEGORY'),
                        CategorySelectorField(
                          controller: _categoryController,
                          focusNode: _categoryFocusNode,
                          categories: _categories,
                          isOpen: _showCategoryDropdown,
                          onOpenChanged: (open) =>
                              setState(() => _showCategoryDropdown = open),
                          onSelectCategory: (name, icon, color) {
                            setState(() {
                              _categoryController.text = name;
                              _selectedIcon = icon;
                              _selectedColor = color;
                            });
                          },
                          onClear: () {
                            _categoryController.clear();
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 18),

                        // Frequency & Reminder
                        Row(
                          children: [
                            // Frequency
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FieldLabel(label: 'FREQUENCY'),
                                  DropdownButtonFormField<String>(
                                    initialValue: _scheduleType,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: AxisColors.surfaceHigh
                                          .withValues(alpha: 0.5),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: AxisColors.borderSubtle),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: AxisColors.borderSubtle),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 12),
                                    ),
                                    dropdownColor: AxisColors.surfaceHigh,
                                    style: const TextStyle(
                                        color: AxisColors.textHigh,
                                        fontSize: 13),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'daily',
                                        child: Text(
                                          'Daily (00:00)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'weekly',
                                        child: Text(
                                          'Weekly (Fri)',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'every_3_days',
                                        child: Text(
                                          'Every 3 Days',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DropdownMenuItem(
                                        value: 'weekdays',
                                        child: Text(
                                          'Weekdays',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _scheduleType = v ?? 'daily'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // Time of Day
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const FieldLabel(label: 'TIME'),
                                  InkWell(
                                    onTap: _pickTime,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: AxisColors.surfaceHigh
                                            .withValues(alpha: 0.5),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                        border: Border.all(
                                            color: AxisColors.borderSubtle),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.alarm_rounded,
                                              size: 18,
                                              color: AxisColors.success),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _reminderTime != null
                                                  ? '${_reminderTime!.hourOfPeriod == 0 ? 12 : _reminderTime!.hourOfPeriod}:${_reminderTime!.minute.toString().padLeft(2, '0')} ${_reminderTime!.period == DayPeriod.am ? 'AM' : 'PM'}'
                                                  : 'Set Time',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: _reminderTime != null
                                                    ? AxisColors.textHigh
                                                    : AxisColors.textDim,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
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
                          ],
                        ),
                      const SizedBox(height: 18),

                      // Color Accent
                      const FieldLabel(label: 'COLOR ACCENT'),
                      ColorAccentSelector(
                        selectedColor: _selectedColor,
                        onSelectColor: (col) =>
                            setState(() => _selectedColor = col),
                      ),
                      const SizedBox(height: 18),

                      // XP Reward
                      const FieldLabel(label: 'XP REWARD'),
                      XpRewardSelector(
                        targetXp: _targetXp,
                        onSelectXp: (xp) => setState(() => _targetXp = xp),
                      ),
                      const SizedBox(height: 28),

                      // Submit
                      InkWell(
                        onTap: _saving ? null : _save,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AxisColors.success,
                                Color(0xFF059669),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AxisColors.success.withValues(alpha: 0.4),
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
                                      const Icon(Icons.add_task_rounded,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.habitToEdit != null
                                            ? 'UPDATE HABIT'
                                            : 'ACTIVATE HABIT',
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
                      if (widget.habitToEdit != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _confirmDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AxisColors.error,
                            side: const BorderSide(
                              color: AxisColors.error,
                              width: 1.2,
                            ),
                            minimumSize: const Size(double.infinity, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: const Text(
                            'DELETE HABIT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
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
