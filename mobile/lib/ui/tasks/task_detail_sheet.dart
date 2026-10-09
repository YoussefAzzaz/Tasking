import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/data/task_repository.dart';

/// Task detail bottom sheet — glass tier 2, full DESIGN.md spec
class TaskDetailSheet extends StatefulWidget {
  const TaskDetailSheet({super.key, required this.task});
  final Task task;

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late Task _task;
  final _repo = TaskRepository();

  @override
  void initState() {
    super.initState();
    _task = widget.task;
  }

  Future<void> _toggleDone() async {
    final updated = Task(
      id: _task.id,
      title: _task.title,
      status: _task.status == 'done' ? 'todo' : 'done',
      priority: _task.priority,
      projectId: _task.projectId,
      tags: _task.tags,
      dueDate: _task.dueDate,
      dueTime: _task.dueTime,
      estimateMin: _task.estimateMin,
      recurrenceRule: _task.recurrenceRule,
      recurrenceMode: _task.recurrenceMode,
    );
    await _repo.updateTask(updated);
    setState(() => _task = updated);
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _task.status == 'done';
    final tags = (_task.tags ?? '')
        .split(',')
        .where((t) => t.trim().isNotEmpty)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) {
        return AxisCard(
          tier: GlassTier.two,
          borderRadius: 20,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AxisColors.borderSubtle,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),

                // Title row + checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AxisCheckbox(
                      checked: isDone,
                      onChanged: (_) => _toggleDone(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _task.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: AxisColors.textDim,
                          color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Metadata section
                _MetaSection(title: 'Details', children: [
                  if (_task.priority != null)
                    _MetaRow(
                      icon: Icons.flag_rounded,
                      iconColor: _priorityColor(_task.priority!),
                      label: 'Priority',
                      value: 'P${_task.priority}',
                    ),
                  if (_task.dueDate != null)
                    _MetaRow(
                      icon: Icons.calendar_today_rounded,
                      iconColor: AxisColors.secondary,
                      label: 'Due Date',
                      value: _task.dueDate!,
                    ),
                  if (_task.dueTime != null)
                    _MetaRow(
                      icon: Icons.access_time_rounded,
                      iconColor: AxisColors.primarySoft,
                      label: 'Time',
                      value: _task.dueTime!,
                    ),
                  if (_task.estimateMin != null)
                    _MetaRow(
                      icon: Icons.timer_outlined,
                      iconColor: AxisColors.secondary,
                      label: 'Estimate',
                      value: _formatEstimate(_task.estimateMin!),
                    ),
                  if (_task.recurrenceRule != null)
                    _MetaRow(
                      icon: Icons.repeat_rounded,
                      iconColor: AxisColors.success,
                      label: 'Recurrence',
                      value: _task.recurrenceRule!
                          .replaceAll('RRULE:FREQ=', '').toLowerCase(),
                    ),
                ]),

                // Tags
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _MetaSection(title: 'Tags', children: [
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: tags.map((t) => AxisChip(
                        label: '@$t',
                        backgroundColor: AxisColors.primary.withOpacity(0.08),
                        textColor: AxisColors.primarySoft,
                      )).toList(),
                    ),
                  ]),
                ],

                const SizedBox(height: 24),

                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _repo.deleteTask(_task.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AxisColors.error, size: 18),
                    label: Text('Delete Task',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AxisColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AxisColors.error.withOpacity(0.3), width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _priorityColor(int p) {
    return switch (p) {
      1 => AxisColors.warning,
      2 => AxisColors.primary,
      _ => AxisColors.textMuted,
    };
  }

  String _formatEstimate(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    return '${minutes}m';
  }
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 8),
        AxisCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Text(label,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AxisColors.textMuted)),
          const Spacer(),
          Text(value,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: AxisColors.textHigh)),
        ],
      ),
    );
  }
}
