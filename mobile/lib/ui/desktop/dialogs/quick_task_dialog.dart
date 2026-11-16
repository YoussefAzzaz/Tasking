import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../data/task_repository.dart';
import '../../tasks/create_task_sheet.dart';

/// Modal dialog providing task creation and editing on the desktop workspace.
abstract final class QuickTaskDialog {
  static Future<void> show(
    BuildContext context, {
    String? initialProject,
    DateTime? initialDate,
    String? initialTime,
    Task? taskToEdit,
    ValueChanged<Task>? onTaskUpdated,
    VoidCallback? onTaskCreated,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        final dialogWidth = (size.width - 48).clamp(320.0, 920.0);
        final dialogHeight = (size.height - 40).clamp(400.0, 740.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            constraints: const BoxConstraints(maxWidth: 960, maxHeight: 760),
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
              child: CreateTaskSheet(
                isDesktop: true,
                initialProject: initialProject,
                initialDate: initialDate,
                initialTime: initialTime,
                taskToEdit: taskToEdit,
                onTaskCreated: () {
                  onTaskCreated?.call();
                },
                onTaskUpdated: (updated) {
                  onTaskUpdated?.call(updated);
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

