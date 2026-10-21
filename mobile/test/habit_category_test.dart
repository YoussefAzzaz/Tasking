import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/habit_category_repository.dart';

void main() {
  group('Habit Category & Grouping', () {
    test('Habit model defaults category to empty string and retains custom category', () {
      final defaultHabit = Habit(id: 'h1', name: 'Pushups');
      expect(defaultHabit.category, '');

      final customHabit = Habit(
        id: 'h2',
        name: 'Study Algorithms',
        category: 'Code',
        icon: 'code',
      );
      expect(customHabit.category, 'Code');
    });

    test('Habit.fromRow extracts kind as category without ghost fallbacks', () {
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

      // Without kind, does not invent ghost category
      final rowNoKind = {
        'id': 'h2',
        'name': 'Read Clean Code',
        'kind': '',
        'icon': 'book',
        'color': '#38BDF8',
      };
      final h2 = Habit.fromRow(rowNoKind);
      expect(h2.category, '');

      // Islamic prayer icon correctly routes to Prayers
      final rowPrayer = {
        'id': 'h3',
        'name': 'Fajr',
        'kind': '',
        'icon': 'mosque',
      };
      final h3 = Habit.fromRow(rowPrayer);
      expect(h3.category, 'Prayers');
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

    test('Deleted category leaves habits unassigned without morphing to Workout', () {
      final unlinkedHabitRow = {
        'id': 'h_orphan',
        'name': 'Morning Jog',
        'kind': null,
        'icon': 'fitness',
      };
      final habit = Habit.fromRow(unlinkedHabitRow);
      expect(habit.category, '');
      expect(habit.category.toLowerCase(), isNot('workout'));

      // In habit grouping, habits with empty or unassigned category go into unassignedHabits
      final allCategories = [
        const HabitCategory(id: 'cat_med', name: 'Meditation'),
      ];
      final unassignedHabits = <Habit>[];
      final Map<String, List<Habit>> habitsByCategory = {};

      final habits = [habit];
      for (final h in habits) {
        final catTrimmed = h.category.trim();
        final matchedCat = catTrimmed.isNotEmpty
            ? allCategories.firstWhere(
                (c) => c.name.toLowerCase() == catTrimmed.toLowerCase(),
                orElse: () => const HabitCategory(id: '', name: ''),
              )
            : const HabitCategory(id: '', name: '');

        if (matchedCat.name.isNotEmpty) {
          habitsByCategory.putIfAbsent(matchedCat.name, () => []).add(h);
        } else {
          unassignedHabits.add(h);
        }
      }

      expect(unassignedHabits.length, 1);
      expect(unassignedHabits.first.name, 'Morning Jog');
      expect(habitsByCategory.containsKey('Workout'), false);
    });
  });
}
