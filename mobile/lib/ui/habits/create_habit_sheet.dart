import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';

class HabitCategory {
  final String id;
  final String name;
  final String icon;
  final String color;

  const HabitCategory({
    required this.id,
    required this.name,
    this.icon = 'fitness',
    this.color = '#10B981',
  });
}

class CreateHabitSheet extends StatefulWidget {
  const CreateHabitSheet({
    super.key,
    required this.onHabitCreated,
    this.habitToEdit,
  });
  final VoidCallback onHabitCreated;
  final Habit? habitToEdit;

  @override
  State<CreateHabitSheet> createState() => _CreateHabitSheetState();
}

class _CreateHabitSheetState extends State<CreateHabitSheet> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController(text: 'Workout');
  final _categoryFocusNode = FocusNode();

  bool _showCategoryDropdown = false;
  String _selectedIcon = 'fitness';
  String _scheduleType = 'daily';
  TimeOfDay? _reminderTime = const TimeOfDay(hour: 7, minute: 0);
  int _targetXp = 20;
  String _selectedColor = '#10B981';
  bool _saving = false;
  String? _errorText;

  List<HabitCategory> _categories = [
    const HabitCategory(id: 'cat_workout', name: 'Workout', icon: 'fitness', color: '#10B981'),
    const HabitCategory(id: 'cat_reading', name: 'Reading', icon: 'book', color: '#38BDF8'),
    const HabitCategory(id: 'cat_mindful', name: 'Mindful', icon: 'meditation', color: '#A855F7'),
    const HabitCategory(id: 'cat_hydrate', name: 'Hydrate', icon: 'water', color: '#06B6D4'),
    const HabitCategory(id: 'cat_code', name: 'Code', icon: 'code', color: '#6366F1'),
    const HabitCategory(id: 'cat_rest', name: 'Rest', icon: 'sleep', color: '#F59E0B'),
  ];

  static const _colors = [
    {'hex': '#10B981', 'color': AxisColors.success, 'label': 'Emerald'},
    {'hex': '#38BDF8', 'color': AxisColors.secondary, 'label': 'Cyan'},
    {'hex': '#6366F1', 'color': AxisColors.primary, 'label': 'Indigo'},
    {'hex': '#F59E0B', 'color': AxisColors.warning, 'label': 'Amber'},
    {'hex': '#EC4899', 'color': Color(0xFFEC4899), 'label': 'Rose'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.habitToEdit != null) {
      final h = widget.habitToEdit!;
      _nameController.text = h.name;
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
          if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hour != 12) {
            hour += 12;
          } else if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hour == 12) {
            hour = 0;
          }
          _reminderTime = TimeOfDay(hour: hour, minute: minute);
        } catch (_) {}
      }
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
    _categoryController.dispose();
    _categoryFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await db.getAll('SELECT * FROM habit_categories ORDER BY name ASC');
      if (rows.isNotEmpty) {
        final list = rows.map((r) => HabitCategory(
          id: r['id'] as String,
          name: r['name'] as String,
          icon: (r['icon'] as String?) ?? 'fitness',
          color: (r['color'] as String?) ?? '#10B981',
        )).toList();
        if (mounted) {
          setState(() => _categories = list);
        }
      }
    } catch (_) {}
  }

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.success;
    }
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
        try {
          await db.execute(
            'INSERT OR IGNORE INTO habit_categories (id, name, icon, color) VALUES (?, ?, ?, ?)',
            ['cat_${DateTime.now().microsecondsSinceEpoch}', categoryName, _selectedIcon, _selectedColor],
          );
        } catch (_) {}
      }
    }

    final timeStr = _reminderTime != null
        ? '${_reminderTime!.hourOfPeriod == 0 ? 12 : _reminderTime!.hourOfPeriod}:${_reminderTime!.minute.toString().padLeft(2, '0')} ${_reminderTime!.period == DayPeriod.am ? 'AM' : 'PM'}'
        : null;

    if (widget.habitToEdit != null) {
      final updatedHabit = Habit(
        id: widget.habitToEdit!.id,
        name: name,
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

  List<Widget> _buildCategoryDropdownItems() {
    final query = _categoryController.text.trim().toLowerCase();
    final items = <Widget>[];

    final filtered = _categories.where((c) {
      if (query.isEmpty) return true;
      return c.name.toLowerCase().contains(query);
    }).toList();

    for (final cat in filtered) {
      final isSel = _categoryController.text.trim().toLowerCase() ==
          cat.name.toLowerCase();
      final color = _parseHex(cat.color);

      items.add(
        InkWell(
          onTap: () {
            setState(() {
              _categoryController.text = cat.name;
              _selectedIcon = cat.icon;
              _selectedColor = cat.color;
              _showCategoryDropdown = false;
              _categoryFocusNode.unfocus();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSel
                  ? AxisColors.surfaceHigh.withValues(alpha: 0.6)
                  : Colors.transparent,
              border: const Border(
                bottom: BorderSide(color: AxisColors.borderSubtle, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      color: isSel ? AxisColors.textHigh : AxisColors.textMuted,
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSel)
                  const Icon(Icons.check_rounded,
                      size: 16, color: AxisColors.success),
              ],
            ),
          ),
        ),
      );
    }

    final exactMatch = _categories.any((c) => c.name.toLowerCase() == query);
    if (query.isNotEmpty && !exactMatch) {
      final typed = _categoryController.text.trim();
      items.add(
        InkWell(
          onTap: () {
            setState(() {
              _categoryController.text = typed;
              _showCategoryDropdown = false;
              _categoryFocusNode.unfocus();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.add_rounded, size: 16, color: AxisColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create category "$typed"',
                    style: const TextStyle(
                      color: AxisColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        setState(() => _showCategoryDropdown = false);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: insets.bottom),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF50A1422),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AxisColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: AxisColors.success,
                                  size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              widget.habitToEdit != null ? 'EDIT HABIT ROUTINE' : 'NEW HABIT ROUTINE',
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

              // Form Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      _SectionTitle(label: 'HABIT NAME *'),
                      TextField(
                        controller: _nameController,
                        autofocus: false,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                                color: AxisColors.success, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Category Dropdown Selector (Same method as Project in Task Form)
                      _SectionTitle(label: 'CATEGORY'),
                      Container(
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showCategoryDropdown
                                ? AxisColors.success
                                : AxisColors.borderSubtle,
                            width: _showCategoryDropdown ? 1.5 : 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _categoryController,
                          focusNode: _categoryFocusNode,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AxisColors.textHigh,
                              ),
                          cursorColor: AxisColors.success,
                          decoration: InputDecoration(
                            hintText: 'Select or write category name...',
                            hintStyle: const TextStyle(
                                color: AxisColors.textDim, fontSize: 13),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            prefixIcon: const Icon(Icons.category_rounded,
                                size: 18, color: AxisColors.success),
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_categoryController.text.isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded,
                                        size: 16, color: AxisColors.textDim),
                                    onPressed: () {
                                      _categoryController.clear();
                                      setState(() {});
                                    },
                                  ),
                                IconButton(
                                  icon: Icon(
                                    _showCategoryDropdown
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.keyboard_arrow_down_rounded,
                                    color: AxisColors.textDim,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _showCategoryDropdown =
                                          !_showCategoryDropdown;
                                      if (_showCategoryDropdown) {
                                        _categoryFocusNode.requestFocus();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            setState(() => _showCategoryDropdown = true);
                          },
                          onChanged: (text) {
                            setState(() => _showCategoryDropdown = true);
                          },
                        ),
                      ),
                      if (_showCategoryDropdown) ...[
                        const SizedBox(height: 6),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLow,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AxisColors.success.withValues(alpha: 0.35),
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
                              children: _buildCategoryDropdownItems(),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Frequency & Reminder
                      Row(
                        children: [
                          // Frequency
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionTitle(label: 'FREQUENCY'),
                                DropdownButtonFormField<String>(
                                  initialValue: _scheduleType,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AxisColors.surfaceHigh
                                        .withValues(alpha: 0.5),
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
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 12),
                                  ),
                                  dropdownColor: AxisColors.surfaceHigh,
                                  style: const TextStyle(
                                      color: AxisColors.textHigh, fontSize: 13),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'daily', child: Text('Daily')),
                                    DropdownMenuItem(
                                        value: 'weekdays',
                                        child: Text('Weekdays')),
                                    DropdownMenuItem(
                                        value: 'weekly',
                                        child: Text('3x / Week')),
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
                                _SectionTitle(label: 'TIME'),
                                InkWell(
                                  onTap: _pickTime,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: AxisColors.surfaceHigh
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: AxisColors.borderSubtle),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.alarm_rounded,
                                            size: 18, color: AxisColors.success),
                                        const SizedBox(width: 8),
                                        Text(
                                          _reminderTime != null
                                              ? '${_reminderTime!.hourOfPeriod == 0 ? 12 : _reminderTime!.hourOfPeriod}:${_reminderTime!.minute.toString().padLeft(2, '0')} ${_reminderTime!.period == DayPeriod.am ? 'AM' : 'PM'}'
                                              : 'Set Time',
                                          style: TextStyle(
                                            color: _reminderTime != null
                                                ? AxisColors.textHigh
                                                : AxisColors.textDim,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
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
                      _SectionTitle(label: 'COLOR ACCENT'),
                      Row(
                        children: _colors.map((c) {
                          final isSel = _selectedColor == c['hex'];
                          final col = c['color'] as Color;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () => setState(
                                  () => _selectedColor = c['hex'] as String),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: col,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: col.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: isSel
                                    ? const Icon(Icons.check_rounded,
                                        size: 18, color: Colors.white)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // XP Reward
                      _SectionTitle(label: 'XP REWARD'),
                      Row(
                        children: [10, 20, 30, 50].map((xp) {
                          final isSel = _targetXp == xp;
                          return Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => setState(() => _targetXp = xp),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? AxisColors.success
                                            .withValues(alpha: 0.22)
                                        : AxisColors.surfaceHigh
                                            .withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSel
                                          ? AxisColors.success
                                          : AxisColors.borderSubtle,
                                      width: isSel ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+$xp XP',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isSel
                                            ? AxisColors.success
                                            : AxisColors.textDim,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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
                                color: AxisColors.success.withValues(alpha: 0.4),
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
                                      const Icon(Icons.add_task_rounded,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.habitToEdit != null ? 'UPDATE HABIT' : 'ACTIVATE HABIT',
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label});
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
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
