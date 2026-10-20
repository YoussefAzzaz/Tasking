import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';

void main() {
  group('Habit Category & Grouping', () {
    test('Habit model defaults category to Workout and retains custom category', () {
      final defaultHabit = Habit(id: 'h1', name: 'Pushups');
      expect(defaultHabit.category, 'Workout');

      final customHabit = Habit(
        id: 'h2',
        name: 'Study Algorithms',
        category: 'Code',
        icon: 'code',
      );
      expect(customHabit.category, 'Code');
    });

    test('Habit.fromRow extracts kind as category with fallback heuristics', () {
      // With explicit kind
      final rowWithKind = {
        'id': 'h1',
        'name': 'Drink 2L Water',
        'kind': 'Hydrate',
        'icon': 'water',
        'color': '#06B6D4',
      };
      final h1 = Habit.fromRow(rowWithKind);
      expect(h1.category, 'Hydrate');

      // Without kind, falls back based on icon
      final rowNoKind = {
        'id': 'h2',
        'name': 'Read Clean Code',
        'kind': '',
        'icon': 'book',
        'color': '#38BDF8',
      };
      final h2 = Habit.fromRow(rowNoKind);
      expect(h2.category, 'Reading');
    });

    test('Habits group correctly by category with completion calculations', () {
      final habits = [
        Habit(id: '1', name: 'Pushups', category: 'Workout', isDoneToday: true),
        Habit(id: '2', name: 'Pullups', category: 'Workout', isDoneToday: false),
        Habit(id: '3', name: 'Clean Architecture', category: 'Reading', isDoneToday: true),
      ];

      final Map<String, List<Habit>> habitsByCategory = {};
      for (final h in habits) {
        habitsByCategory.putIfAbsent(h.category, () => []).add(h);
      }

      expect(habitsByCategory['Workout']!.length, 2);
      expect(habitsByCategory['Reading']!.length, 1);

      // Workout progress: 1 of 2 finished (50%)
      final workoutHabits = habitsByCategory['Workout']!;
      final workoutDone = workoutHabits.where((h) => h.isDoneToday).length;
      final workoutTotal = workoutHabits.length;
      final workoutProgress = workoutDone / workoutTotal;
      expect(workoutProgress, 0.5);

      // Reading progress: 1 of 1 finished (100% -> DONE)
      final readingHabits = habitsByCategory['Reading']!;
      final readingDone = readingHabits.where((h) => h.isDoneToday).length;
      final readingTotal = readingHabits.length;
      expect(readingDone == readingTotal, true);
    });
  });
}
