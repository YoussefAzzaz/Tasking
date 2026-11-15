import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/task_repository.dart';
import '../task_card.dart';
import '../task_detail_sheet.dart';

/// Section rendering a list of tasks (outdated or finished) with optional date grouping.
class OutdatedSection extends StatelessWidget {
  const OutdatedSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.tasks,
    required this.repo,
    this.groupByDate = false,
  });

  final String title;
  final String subtitle;
  final Color color;
  final List<Task> tasks;
  final TaskRepository repo;
  final bool groupByDate;

  Map<String, List<Task>> _groupTasksByDate(List<Task> tasks) {
    final Map<String, List<Task>> map = {};
    for (final t in tasks) {
      final key = (t.dueDate != null && t.dueDate!.trim().isNotEmpty)
          ? t.dueDate!.trim()
          : 'no_date';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  String _formatDateHeader(String dateStr, bool isArabic) {
    if (dateStr == 'no_date') return isArabic ? 'بدون تاريخ استحقاق' : 'NO DUE DATE';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return dateStr.toUpperCase();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(target).inDays;

    String dateFormatted;
    if (isArabic) {
      try {
        dateFormatted = DateFormat('EEE, MMM d', 'ar').format(dt);
      } catch (_) {
        dateFormatted = DateFormat('EEE, MMM d').format(dt);
      }
    } else {
      dateFormatted = DateFormat('EEE, MMM d').format(dt);
    }

    if (diffDays == 1) {
      return isArabic ? 'أمس • $dateFormatted' : 'YESTERDAY • $dateFormatted';
    } else if (diffDays > 1) {
      return isArabic ? 'متأخرة بـ $diffDays أيام • $dateFormatted' : '$diffDays DAYS OVERDUE • $dateFormatted';
    } else if (diffDays == 0) {
      return isArabic ? 'اليوم • $dateFormatted' : 'TODAY • $dateFormatted';
    } else {
      return dateFormatted.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${tasks.length})',
                    style:
                        const TextStyle(fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AxisColors.textDim,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (groupByDate) ...[
          for (final entry in _groupTasksByDate(tasks).entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.22),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off_rounded,
                            size: 13, color: color),
                        const SizedBox(width: 6),
                        Text(
                          _formatDateHeader(entry.key, context.isArabic),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: color,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.length}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ...entry.value.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TaskCard(
                  key: ValueKey(task.id),
                  task: task,
                  onToggle: (checked) async {
                    final updated = task.copyWith(
                      status: checked ? 'done' : 'todo',
                    );
                    await repo.updateTask(updated);
                  },
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TaskDetailSheet(task: task),
                  ),
                ),
              ),
            ),
          ],
        ] else ...[
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TaskCard(
                key: ValueKey(task.id),
                task: task,
                onToggle: (checked) async {
                  final updated = task.copyWith(
                    status: checked ? 'done' : 'todo',
                  );
                  await repo.updateTask(updated);
                },
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => TaskDetailSheet(task: task),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

