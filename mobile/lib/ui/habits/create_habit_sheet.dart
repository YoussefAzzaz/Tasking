import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';
import 'package:axis/ui/habits/widgets/habit_form_widgets.dart';
import 'package:axis/ui/habits/widgets/habit_schedule_reminder_picker.dart';
import 'package:axis/ui/habits/services/habit_form_service.dart';

export 'package:axis/ui/habits/widgets/habit_form_widgets.dart';
export 'package:axis/ui/habits/widgets/habit_schedule_reminder_picker.dart';
export 'package:axis/ui/habits/services/habit_form_service.dart';

class CreateHabitSheet extends StatefulWidget {
  const CreateHabitSheet({
    super.key,
    required this.onHabitCreated,
    this.habitToEdit,
    this.initialCategory,
    this.existingCategories,
    this.isDialog = false,
  });

  final VoidCallback onHabitCreated;
  final Habit? habitToEdit;
  final String? initialCategory;
  final List<HabitCategory>? existingCategories;
  final bool isDialog;

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
    setState(() {
      _saving = true;
      _errorText = null;
    });

    try {
      await HabitFormService().saveHabit(
        habitToEdit: widget.habitToEdit,
        rawName: _nameController.text,
        categoryInput: _categoryController.text,
        selectedIcon: _selectedIcon,
        selectedColor: _selectedColor,
        scheduleType: _scheduleType,
        reminderTime: _reminderTime,
        targetXp: _targetXp,
        existingCategories: _categories,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onHabitCreated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = e.toString().replaceFirst('Exception: ', '').replaceFirst('ArgumentError: ', '');
        });
      }
    }
  }

  void _confirmDelete() {
    if (widget.habitToEdit == null) return;
    HabitFormService.showConfirmDeleteDialog(
      context: context,
      habit: widget.habitToEdit!,
      onConfirm: () async {
        setState(() => _saving = true);
        await HabitFormService().deleteHabit(widget.habitToEdit!.id);
        if (mounted) {
          Navigator.pop(context);
          widget.onHabitCreated();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final screenHeight = MediaQuery.of(context).size.height;
    final availableHeight =
        (screenHeight - insets.bottom).clamp(260.0, screenHeight);

    final sheetContent = Container(
      constraints: BoxConstraints(
        maxHeight: widget.isDialog ? 720 : availableHeight * 0.90,
      ),
      decoration: BoxDecoration(
        color: const Color(0xF50A1422),
        borderRadius: widget.isDialog
            ? BorderRadius.circular(12)
            : const BorderRadius.vertical(top: Radius.circular(24)),
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
        mainAxisSize: widget.isDialog ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (!widget.isDialog)
            ModalSheetTopBar(
              child: Padding(
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
                    HabitSheetHeader(
                      isEdit: widget.habitToEdit != null,
                      onClose: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
              child: HabitSheetHeader(
                isEdit: widget.habitToEdit != null,
                onClose: () => Navigator.pop(context),
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
                        FieldLabel(label: context.isArabic ? 'اسم العادة *' : 'HABIT NAME *'),
                        AutoDirectionScope(
                          controller: _nameController,
                          child: TextField(
                            controller: _nameController,
                            focusNode: _nameFocusNode,
                            autofocus: false,
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: AxisColors.textHigh,
                                    ),
                            cursorColor: AxisColors.success,
                            decoration: InputDecoration(
                              hintText: context.isArabic
                                  ? 'مثال: قراءة 20 صفحة، الجري صباحاً'
                                  : 'e.g. Read 20 Pages, Morning Run',
                              hintStyle: const TextStyle(color: AxisColors.textDim),
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
                        ),
                        const SizedBox(height: 18),

                        // Category Dropdown Selector
                        FieldLabel(label: context.isArabic ? 'التصنيف' : 'CATEGORY'),
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
                        HabitScheduleReminderPicker(
                          scheduleType: _scheduleType,
                          reminderTime: _reminderTime,
                          onPickTime: _pickTime,
                          onClearTime: () =>
                              setState(() => _reminderTime = null),
                          onScheduleTypeChanged: (newType) {
                            setState(() {
                              _scheduleType = newType;
                              if (_scheduleType != 'daily' &&
                                  widget.habitToEdit == null) {
                                _reminderTime = null;
                              }
                            });
                          },
                          isEdit: widget.habitToEdit != null,
                        ),
                        const SizedBox(height: 18),

                      // Color Accent
                      FieldLabel(label: context.isArabic ? 'لون التمييز' : 'COLOR ACCENT'),
                      ColorAccentSelector(
                        selectedColor: _selectedColor,
                        onSelectColor: (col) =>
                            setState(() => _selectedColor = col),
                      ),
                      const SizedBox(height: 18),

                      // XP Reward
                      FieldLabel(label: context.isArabic ? 'مكافأة نقاط الخبرة' : 'XP REWARD'),
                      XpRewardSelector(
                        targetXp: _targetXp,
                        onSelectXp: (xp) => setState(() => _targetXp = xp),
                      ),
                      const SizedBox(height: 28),

                      // Action Buttons
                      HabitActionButtons(
                        isEdit: widget.habitToEdit != null,
                        isSaving: _saving,
                        onSave: _saving ? null : _save,
                        onDelete: _saving ? null : _confirmDelete,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

    if (widget.isDialog) {
      return FocusScope(
        autofocus: false,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() => _showCategoryDropdown = false);
          },
          child: sheetContent,
        ),
      );
    }

    return FocusScope(
      autofocus: false,
      child: ModalSheetScaffold(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            FocusScope.of(context).unfocus();
            setState(() => _showCategoryDropdown = false);
          },
          child: Padding(
            padding: EdgeInsets.only(bottom: insets.bottom),
            child: sheetContent,
          ),
        ),
      ),
    );
  }
}
