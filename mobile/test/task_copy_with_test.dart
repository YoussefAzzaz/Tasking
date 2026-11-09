import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/task_repository.dart';

void main() {
  group('Task copyWith Clear Nullable Fields Tests', () {
    test('copyWith preserves values when clear flags are false', () {
      final task = Task(
        id: 't1',
        title: 'Initial Title',
        notes: 'Initial notes',
        dueDate: '2026-11-10',
        dueTime: '14:00',
        estimateMin: 45,
        projectId: 'p1',
        tags: 'work,urgent',
        priority: 1,
        recurrenceRule: 'RRULE:FREQ=DAILY',
        recurrenceMode: 'fixed',
      );

      final updated = task.copyWith(title: 'Updated Title');
      expect(updated.title, 'Updated Title');
      expect(updated.notes, 'Initial notes');
      expect(updated.dueDate, '2026-11-10');
      expect(updated.dueTime, '14:00');
      expect(updated.estimateMin, 45);
      expect(updated.projectId, 'p1');
      expect(updated.tags, 'work,urgent');
      expect(updated.priority, 1);
      expect(updated.recurrenceRule, 'RRULE:FREQ=DAILY');
      expect(updated.recurrenceMode, 'fixed');
    });

    test('copyWith clears nullable fields when explicit clear flags are true', () {
      final task = Task(
        id: 't2',
        title: 'Task with fields',
        notes: 'Some notes',
        dueDate: '2026-11-10',
        dueTime: '14:00',
        estimateMin: 45,
        projectId: 'p1',
        tags: 'work,urgent',
        priority: 1,
        recurrenceRule: 'RRULE:FREQ=DAILY',
        recurrenceMode: 'fixed',
      );

      final cleared = task.copyWith(
        clearDueDate: true,
        clearDueTime: true,
        clearNotes: true,
        clearProjectId: true,
        clearTags: true,
        clearEstimateMin: true,
        clearRecurrenceRule: true,
        clearRecurrenceMode: true,
        clearPriority: true,
      );

      expect(cleared.id, 't2');
      expect(cleared.title, 'Task with fields');
      expect(cleared.dueDate, isNull);
      expect(cleared.dueTime, isNull);
      expect(cleared.notes, isNull);
      expect(cleared.projectId, isNull);
      expect(cleared.tags, isNull);
      expect(cleared.estimateMin, isNull);
      expect(cleared.recurrenceRule, isNull);
      expect(cleared.recurrenceMode, isNull);
      expect(cleared.priority, isNull);
    });
  });
}

