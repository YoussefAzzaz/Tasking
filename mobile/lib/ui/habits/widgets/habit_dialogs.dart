import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';
import 'package:axis/ui/common/axis_snackbar.dart';

/// Shows a confirmation dialog to delete a specific habit.
void showConfirmDeleteHabitDialog(
  BuildContext context, {
  required Habit habit,
  required void Function(Habit habit) onDeleteHabit,
}) {
  final isArabic = context.isArabic;
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AxisColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AxisColors.borderPrimary),
      ),
      title: Text(
        isArabic ? 'حذف "${habit.name}"؟' : 'Delete "${habit.name}"?',
        style: const TextStyle(color: AxisColors.textHigh),
      ),
      content: Text(
        isArabic
            ? 'سيؤدي هذا إلى حذف هذه العادة وجميع سجلات تتابعها نهائياً.'
            : 'This will permanently delete this habit and all its streak logs.',
        style: const TextStyle(color: AxisColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: const TextStyle(color: AxisColors.textDim),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
          onPressed: () {
            Navigator.pop(dialogCtx);
            onDeleteHabit(habit);
            AxisSnackBar.showDeleted(
              context,
              itemTitle: habit.name,
              itemType: isArabic ? 'عادة' : 'Habit',
            );
          },
          child: Text(
            isArabic ? 'حذف' : 'Delete',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

/// Shows a confirmation dialog to delete a habit category.
void showConfirmDeleteCategoryDialog(
  BuildContext context, {
  required HabitCategory category,
  required VoidCallback? onDeleteCategory,
}) {
  final isArabic = context.isArabic;
  final catName = context.l10n.localizedHabitCategory(category.name);
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      backgroundColor: AxisColors.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AxisColors.borderPrimary),
      ),
      title: Text(
        isArabic ? 'حذف "$catName"؟' : 'Delete "${category.name}"?',
        style: const TextStyle(color: AxisColors.textHigh),
      ),
      content: Text(
        isArabic
            ? 'هل أنت متأكد من حذف تصنيف "$catName"؟ ستبقى العادات الموجودة في هذا التصنيف محفوظة ضمن الروتين العام.'
            : 'Are you sure you want to delete the "${category.name}" category? Habits in this category will remain safe in General Routines.',
        style: const TextStyle(color: AxisColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: Text(
            isArabic ? 'إلغاء' : 'Cancel',
            style: const TextStyle(color: AxisColors.textDim),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
          onPressed: () {
            Navigator.pop(dialogCtx);
            onDeleteCategory?.call();
          },
          child: Text(
            isArabic ? 'حذف' : 'Delete',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}
