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
      if (!query.tags!.any((t) => task.tags!.contains(t))) {
        return false;
      }
    }

    if (query.dueBefore != null && query.dueBefore!.trim().isNotEmpty) {
      if (task.dueDate == null || task.dueDate!.trim().isEmpty) return false;
      if (task.dueDate!.compareTo(query.dueBefore!) >= 0) {
        return false;
      }
    }

    return true;
  }
}

