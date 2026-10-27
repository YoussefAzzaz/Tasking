import '../../../data/task_repository.dart';

/// Shared mixin for desktop screens that render and toggle markdown-style
/// task checklists embedded in a [Task.notes] field.
///
/// Checklist syntax: `- [ ] item text` / `- [x] item text`
mixin TaskChecklistMixin {
  /// Parses all `- [ ]` / `- [x]` lines from [notes] into a typed list.
  List<({String text, bool isDone, int lineIndex})> parseTaskChecklist(
    String? notes,
  ) {
    if (notes == null || notes.isEmpty) return [];
    final lines = notes.split('\n');
    final list = <({String text, bool isDone, int lineIndex})>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('- [ ]') ||
          line.startsWith('- [x]') ||
          line.startsWith('- [X]')) {
        final isDone =
            line.startsWith('- [x]') || line.startsWith('- [X]');
        final text = line.substring(5).trim();
        list.add((text: text, isDone: isDone, lineIndex: i));
      }
    }
    return list;
  }

  /// Returns [notes] with all checklist lines removed (so they are not
  /// rendered twice when checklists are shown separately).
  String stripChecklistFromNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return '';
    final lines = notes.split('\n');
    return lines
        .where((line) {
          final trimmed = line.trim();
          return !trimmed.startsWith('- [ ]') &&
              !trimmed.startsWith('- [x]') &&
              !trimmed.startsWith('- [X]');
        })
        .join('\n')
        .trim();
  }

  /// Toggles a single checklist item at [lineIndex] within [task.notes],
  /// persists the change via [TaskRepository], and returns the updated [Task].
  Future<Task> toggleTaskChecklist(Task task, int lineIndex) async {
    final lines = (task.notes ?? '').split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return task;
    final line = lines[lineIndex];
    if (line.contains('- [ ]')) {
      lines[lineIndex] = line.replaceFirst('- [ ]', '- [x]');
    } else if (line.contains('- [x]') || line.contains('- [X]')) {
      lines[lineIndex] =
          line.replaceFirst(RegExp(r'- \[[xX]\]'), '- [ ]');
    }
    final updated = task.copyWith(notes: lines.join('\n'));
    await TaskRepository().updateTask(updated);
    return updated;
  }
}
