import 'package:intl/intl.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/domain/filter_engine.dart';

/// Immutable model representing active filter criteria for task agendas
class TaskFilterCriteria {
  final int? priority;
  final String? dueDateOption;
  final DateTime? customDate;
  final Set<String> tags;

  const TaskFilterCriteria({
    this.priority,
    this.dueDateOption,
    this.customDate,
    this.tags = const {},
  });

  bool get isActive =>
      priority != null ||
      dueDateOption != null ||
      customDate != null ||
      tags.isNotEmpty;

  int get activeCount {
    int count = 0;
    if (priority != null) count++;
    if (dueDateOption != null || customDate != null) count++;
    if (tags.isNotEmpty) count += tags.length;
    return count;
  }

  bool matches(Task t) {
    // 1. Domain FilterEngine evaluation
    final filterTask = FilterTask(
      t.id,
      t.priority,
      t.tags
          ?.split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      t.dueDate,
    );
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final isOverdue = dueDateOption == 'overdue';

    if (!FilterEngine.matches(
      filterTask,
      FilterQuery(
        priority != null ? [priority!] : null,
        null,
        isOverdue ? todayStr : null,
      ),
    )) {
      return false;
    }

    // 2. Due Date filter
    if (dueDateOption != null) {
      if (t.dueDate == null) return false;
      final tomorrowStr =
          DateFormat('yyyy-MM-dd').format(now.add(const Duration(days: 1)));

      switch (dueDateOption) {
        case 'today':
          if (t.dueDate != todayStr) return false;
          break;
        case 'tomorrow':
          if (t.dueDate != tomorrowStr) return false;
          break;
        case 'overdue':
          if (t.dueDate!.compareTo(todayStr) >= 0) return false;
          break;
        case 'upcoming':
          if (t.dueDate!.compareTo(todayStr) <= 0) return false;
          break;
        case 'custom':
          if (customDate != null) {
            final customStr = DateFormat('yyyy-MM-dd').format(customDate!);
            if (t.dueDate != customStr) return false;
          }
          break;
      }
    }

    // 3. Tag filter: every selected tag must be in task's tags
    if (tags.isNotEmpty) {
      if (t.tags == null || t.tags!.isEmpty) return false;
      final taskTags = t.tags!
          .toLowerCase()
          .split(',')
          .map((e) => e.trim().replaceAll('@', ''))
          .where((e) => e.isNotEmpty)
          .toSet();
      for (final requiredTag in tags) {
        if (!taskTags.contains(requiredTag.toLowerCase().replaceAll('@', ''))) {
          return false;
        }
      }
    }

    return true;
  }
}

