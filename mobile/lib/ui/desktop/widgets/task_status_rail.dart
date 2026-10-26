import 'package:flutter/material.dart';

/// 3px vertical accent rail indicating status (in-progress, overdue, active).
class TaskStatusRail extends StatelessWidget {
  const TaskStatusRail({
    super.key,
    required this.color,
    this.width = 3.0,
    this.borderRadius = const BorderRadius.all(Radius.circular(2.0)),
    this.height,
  });

  final Color color;
  final double width;
  final BorderRadius borderRadius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 0.5,
          ),
        ],
      ),
    );
  }
}
