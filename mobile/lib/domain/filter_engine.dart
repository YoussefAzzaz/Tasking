class FilterTask {
  final String id;
  final int? priority;
  final List<String>? tags;
  final String? dueDate;

  FilterTask(this.id, this.priority, this.tags, this.dueDate);
}

class FilterQuery {
  final List<int>? priority;
  final List<String>? tags;
  final String? dueBefore;

  FilterQuery(this.priority, this.tags, this.dueBefore);
}

class FilterEngine {
  static bool matches(FilterTask task, FilterQuery query) {
    if (query.priority != null && query.priority!.isNotEmpty) {
      if (task.priority == null || !query.priority!.contains(task.priority)) {
        return false;
      }
    }

    if (query.tags != null && query.tags!.isNotEmpty) {
      if (task.tags == null) return false;
      final taskTagSet = task.tags!
          .map((t) => t.trim().replaceAll('@', '').toLowerCase())
          .where((t) => t.isNotEmpty)
          .toSet();
      final hasMatch = query.tags!.any((t) {
        final cleanQueryTag = t.trim().replaceAll('@', '').toLowerCase();
        return taskTagSet.contains(cleanQueryTag) || task.tags!.contains(t);
      });
      if (!hasMatch) return false;
    }

    if (query.dueBefore != null && query.dueBefore!.trim().isNotEmpty) {
      if (task.dueDate == null || task.dueDate!.trim().isEmpty) return false;
      final taskDt = DateTime.tryParse(task.dueDate!.trim());
      final beforeDt = DateTime.tryParse(query.dueBefore!.trim());
      if (taskDt != null && beforeDt != null) {
        if (!taskDt.isBefore(beforeDt)) return false;
      } else {
        if (task.dueDate!.trim().compareTo(query.dueBefore!.trim()) >= 0) {
          return false;
        }
      }
    }

    return true;
  }
}

