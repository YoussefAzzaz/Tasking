import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

class TasksEmptyState extends StatelessWidget {
  const TasksEmptyState({
    super.key,
    this.isFiltered = false,
    this.onReset,
  });

  final bool isFiltered;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isFiltered ? Icons.filter_list_off_rounded : Icons.inbox_rounded,
            size: 48,
            color: AxisColors.textDim,
          ),
          const SizedBox(height: 12),
          Text(
            isFiltered ? 'No tasks match active filters' : 'No tasks found',
            style: const TextStyle(
              color: AxisColors.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isFiltered
                ? 'Try adjusting or resetting your filter studio selections'
                : 'Tap "+ New Task" to create your first objective',
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
          if (isFiltered && onReset != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded, size: 16),
              label: const Text('Reset Filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AxisColors.primary,
                side: const BorderSide(color: AxisColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
