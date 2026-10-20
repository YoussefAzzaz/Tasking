import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/task_repository.dart';

void main() {
  group('Task Sorting & Filtering', () {
    test('compareTasksByDueDate sorts earliest due date first', () {
      final t1 = Task(id: '1', title: 'Task 1', dueDate: '2026-10-25');
      final t2 = Task(id: '2', title: 'Task 2', dueDate: '2026-10-20');
      final t3 = Task(id: '3', title: 'Task 3', dueDate: null);
      final t4 = Task(id: '4', title: 'Task 4', dueDate: '2026-10-20', dueTime: '09:00');
      final t5 = Task(id: '5', title: 'Task 5', dueDate: '2026-10-20', dueTime: '15:00');

      final list = [t1, t2, t3, t5, t4]..sort(compareTasksByDueDate);

      // t4 (10-20 09:00) -> t5 (10-20 15:00) -> t2 (10-20 no time) -> t1 (10-25) -> t3 (no date)
      expect(list[0].id, '4');
      expect(list[1].id, '5');
      expect(list[2].id, '2');
      expect(list[3].id, '1');
      expect(list[4].id, '3');
    });

    test('compareTasksByPriority sorts P1 before P2 before P3', () {
      final p3 = Task(id: '3', title: 'P3 Task', priority: 3);
      final p1 = Task(id: '1', title: 'P1 Task', priority: 1);
      final p2 = Task(id: '2', title: 'P2 Task', priority: 2);
      final pNone = Task(id: '0', title: 'No Priority', priority: null);

      final list = [p3, pNone, p1, p2]..sort(compareTasksByPriority);

      expect(list[0].id, '1');
      expect(list[1].id, '2');
      expect(list[2].id, '3');
      expect(list[3].id, '0');
    });

    test('completed tasks are placed at the end in both comparators', () {
      final done = Task(id: 'done', title: 'Done Task', status: 'done', dueDate: '2026-10-10', priority: 1);
      final todo = Task(id: 'todo', title: 'Todo Task', status: 'todo', dueDate: '2026-10-30', priority: 3);

      final listDue = [done, todo]..sort(compareTasksByDueDate);
      expect(listDue[0].id, 'todo');
      expect(listDue[1].id, 'done');

      final listPri = [done, todo]..sort(compareTasksByPriority);
      expect(listPri[0].id, 'todo');
      expect(listPri[1].id, 'done');
    });
  });
}
