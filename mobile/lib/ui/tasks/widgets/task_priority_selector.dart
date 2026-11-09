import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';

/// Segmented priority selector buttons for task creation (P1, P2, P3, None)
class TaskPrioritySelector extends StatelessWidget {
  const TaskPrioritySelector({
    super.key,
    required this.priority,
    required this.onPriorityChanged,
  });

  final int? priority;
  final ValueChanged<int> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label: context.isArabic ? 'الأولوية' : 'PRIORITY'),
        Row(
          children: [
            PriorityButton(
              priorityNumber: 1,
              label: context.isArabic ? 'P1 حرجة' : 'P1 High',
              color: AxisColors.priorityHigh,
              isSelected: priority == 1,
              onTap: () => onPriorityChanged(1),
            ),
            const SizedBox(width: 8),
            PriorityButton(
              priorityNumber: 2,
              label: context.isArabic ? 'P2 متوسطة' : 'P2 Med',
              color: AxisColors.priorityMed,
              isSelected: priority == 2,
              onTap: () => onPriorityChanged(2),
            ),
            const SizedBox(width: 8),
            PriorityButton(
              priorityNumber: 3,
              label: context.isArabic ? 'P3 منخفضة' : 'P3 Low',
              color: AxisColors.priorityLow,
              isSelected: priority == 3,
              onTap: () => onPriorityChanged(3),
            ),
            const SizedBox(width: 8),
            PriorityButton(
              priorityNumber: 0,
              label: context.isArabic ? 'بدون' : 'None',
              color: AxisColors.textMuted,
              isSelected: priority == 0 || priority == null,
              onTap: () => onPriorityChanged(0),
            ),
          ],
        ),
      ],
    );
  }
}

