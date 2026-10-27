import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../data/habit_repository.dart';
import '../../habits/create_habit_sheet.dart';

/// Modal dialog providing rich habit creation and editing on the desktop workspace.
abstract final class QuickHabitDialog {
  static Future<void> show(
    BuildContext context, {
    String? initialCategory,
    Habit? habitToEdit,
    VoidCallback? onHabitCreated,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Container(
            width: 580,
            constraints: const BoxConstraints(maxHeight: 740),
            decoration: BoxDecoration(
              color: AxisColors.canvasBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AxisColors.borderGlass2,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CreateHabitSheet(
                isDialog: true,
                initialCategory: initialCategory,
                habitToEdit: habitToEdit,
                onHabitCreated: () {
                  onHabitCreated?.call();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
