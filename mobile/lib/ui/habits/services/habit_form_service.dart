import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/domain/id_generator.dart';

/// Application service handling habit persistence, auto-registering habit categories,
/// and habit deletion operations.
class HabitFormService {
  final HabitRepository _habitRepo;
  final HabitCategoryRepository _categoryRepo;

  HabitFormService({
    HabitRepository? habitRepo,
    HabitCategoryRepository? categoryRepo,
  })  : _habitRepo = habitRepo ?? HabitRepository(),
        _categoryRepo = categoryRepo ?? HabitCategoryRepository();

  Future<Habit> saveHabit({
    Habit? habitToEdit,
    required String rawName,
    required String categoryInput,
    required String selectedIcon,
    required String selectedColor,
    required String scheduleType,
    required TimeOfDay? reminderTime,
    required int targetXp,
    required List<HabitCategory> existingCategories,
  }) async {
    final name = rawName.trim();
    if (name.isEmpty) {
      throw ArgumentError('Please enter a habit name');
    }

    final categoryName = categoryInput.trim();
    if (categoryName.isNotEmpty) {
      final exists = existingCategories.any(
        (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      );
      if (!exists) {
        await _categoryRepo.addCategory(
          name: categoryName,
          icon: selectedIcon,
          color: selectedColor,
        );
      }
    }

    final timeStr = reminderTime != null
        ? '${reminderTime.hourOfPeriod == 0 ? 12 : reminderTime.hourOfPeriod}:${reminderTime.minute.toString().padLeft(2, '0')} ${reminderTime.period == DayPeriod.am ? 'AM' : 'PM'}'
        : null;

    final category =
        categoryName.isNotEmpty ? categoryName : 'General Routines';

    if (habitToEdit != null) {
      final updatedHabit = Habit(
        id: habitToEdit.id,
        name: name,
        category: category,
        icon: selectedIcon,
        color: selectedColor,
        scheduleType: scheduleType,
        remindTime: timeStr,
        targetValue: targetXp,
        isDoneToday: habitToEdit.isDoneToday,
        streakDays: habitToEdit.streakDays,
      );
      await _habitRepo.updateHabit(updatedHabit);
      return updatedHabit;
    }

    final habit = Habit(
      id: IdGenerator.generateDeterministicId(
          'habit_${DateTime.now().microsecondsSinceEpoch}_$name'),
      name: name,
      category: category,
      icon: selectedIcon,
      color: selectedColor,
      scheduleType: scheduleType,
      remindTime: timeStr,
      targetValue: targetXp,
    );

    await _habitRepo.addHabit(habit);
    return habit;
  }

  Future<void> deleteHabit(String id) async {
    await _habitRepo.deleteHabit(id);
  }

  static void showConfirmDeleteDialog({
    required BuildContext context,
    required Habit habit,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          'Delete "${habit.name}"?',
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onConfirm();
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

