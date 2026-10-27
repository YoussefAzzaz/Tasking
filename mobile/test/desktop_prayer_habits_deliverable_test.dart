import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/desktop/core/task_checklist_mixin.dart';

class _TestChecklistController with TaskChecklistMixin {}

void main() {
  group('Desktop Prayer & Habits - Daily Habits Filter', () {
    test('Daily habits filter excludes weekly and non-daily habits', () {
      final habits = [
        Habit(id: '1', name: 'Read Quran', scheduleType: 'daily', isDoneToday: true),
        Habit(id: '2', name: 'Morning Walk', scheduleType: 'daily', isDoneToday: false),
        Habit(id: '3', name: 'Jumuah Khutbah', scheduleType: 'weekly', isDoneToday: true),
        Habit(id: '4', name: 'Deep Clean', scheduleType: 'weekly', isDoneToday: false),
        Habit(id: '5', name: 'Default Habit', scheduleType: '', isDoneToday: true),
      ];

      final dailyHabits = habits.where((h) {
        final schedule = h.scheduleType.toLowerCase().trim();
        return schedule == 'daily' || schedule.isEmpty;
      }).toList();

      final doneDailyHabits = dailyHabits.where((h) => h.isDoneToday).length;

      // Only habits 1, 2, and 5 are daily
      expect(dailyHabits.length, equals(3));
      expect(dailyHabits.map((h) => h.id).toList(), equals(['1', '2', '5']));

      // Only habits 1 and 5 are daily and done
      expect(doneDailyHabits, equals(2));
      // Weekly habit 3 (which is done) must NOT be counted in doneDailyHabits
      expect(dailyHabits.any((h) => h.id == '3'), isFalse);
    });
  });

  group('Desktop Projects & Tasks - Deliverable Checklist', () {
    final controller = _TestChecklistController();

    test('parseTaskChecklist correctly parses checked and unchecked subtasks', () {
      const notes = '''
Architecture discussion
- [ ] Implement database migration
- [x] Write integration unit tests
- [X] Setup CI/CD build matrix
Additional contextual documentation
''';

      final items = controller.parseTaskChecklist(notes);

      expect(items.length, equals(3));
      expect(items[0].text, equals('Implement database migration'));
      expect(items[0].isDone, isFalse);
      expect(items[1].text, equals('Write integration unit tests'));
      expect(items[1].isDone, isTrue);
      expect(items[2].text, equals('Setup CI/CD build matrix'));
      expect(items[2].isDone, isTrue);
    });

    test('stripChecklistFromNotes leaves clean markdown context without checkboxes', () {
      const notes = '''
### Core Features
- [ ] Subtask 1
- [x] Subtask 2

This is context documentation.
''';

      final stripped = controller.stripChecklistFromNotes(notes);
      expect(stripped.contains('- [ ] Subtask 1'), isFalse);
      expect(stripped.contains('- [x] Subtask 2'), isFalse);
      expect(stripped.contains('### Core Features'), isTrue);
      expect(stripped.contains('This is context documentation.'), isTrue);
    });

    test('toggling subtask line updates note markdown correctly', () {
      final task = Task(
        id: 'task-1',
        title: 'Sprint Deliverable',
        notes: '- [ ] Subtask 1\n- [x] Subtask 2',
      );

      final lines = (task.notes ?? '').split('\n');
      expect(lines[0], equals('- [ ] Subtask 1'));

      // Toggling line 0 from [ ] to [x]
      lines[0] = lines[0].replaceFirst('- [ ]', '- [x]');
      expect(lines[0], equals('- [x] Subtask 1'));

      // Toggling line 1 from [x] to [ ]
      lines[1] = lines[1].replaceFirst(RegExp(r'- \[[xX]\]'), '- [ ]');
      expect(lines[1], equals('- [ ] Subtask 2'));

      final updated = task.copyWith(notes: lines.join('\n'));
      final parsed = controller.parseTaskChecklist(updated.notes);
      expect(parsed[0].isDone, isTrue);
      expect(parsed[1].isDone, isFalse);
    });
  });
}
