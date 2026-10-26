import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import 'telemetry_chip.dart';

/// Renders a task priority pill (P1 High, P2 Medium, P3 Low) matching design telemetry.
class PriorityBadge extends StatelessWidget {
  const PriorityBadge({
    super.key,
    required this.priority,
    this.compact = false,
  });

  /// 1 = High, 2 = Medium, 3 = Low
  final int? priority;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (priority == null || priority == 0) {
      return const SizedBox.shrink();
    }

    final (label, color) = switch (priority) {
      1 => (compact ? 'P1' : 'High Priority', AxisColors.priorityHigh),
      2 => (compact ? 'P2' : 'Medium Priority', AxisColors.priorityMed),
      3 => (compact ? 'P3' : 'Low Priority', AxisColors.priorityLow),
      _ => ('P$priority', AxisColors.textDim),
    };

    return TelemetryChip(
      label: label,
      dotColor: color,
      color: color,
      isMonospace: true,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6.0 : 8.0,
        vertical: 2.0,
      ),
    );
  }
}
