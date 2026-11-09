import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';

void main() {
  group('Habit isEnabled Toggle and Active Filtering Tests', () {
    test('Habit fromRow defaults isEnabled to true and parses 0 as false', () {
      final defaultHabit = Habit.fromRow({
        'id': 'h1',
        'name': 'Read Quran',
        'category': 'Spiritual',
        'icon': 'book',
        'color': '#10B981',
        'schedule_type': 'daily',
        'target_value': 10,
        'is_done': 0,
        'streak_days': 5,
        'sort_order': 0,
      });
      expect(defaultHabit.isEnabled, isTrue);

      final disabledHabit = Habit.fromRow({
        'id': 'h2',
        'name': 'Gym Workout',
        'category': 'Fitness',
        'icon': 'fitness',
        'color': '#38BDF8',
        'schedule_type': 'daily',
        'target_value': 15,
        'is_done': 1,
        'streak_days': 3,
        'sort_order': 1,
        'is_enabled': 0,
      });
      expect(disabledHabit.isEnabled, isFalse);

      final enabledHabit = disabledHabit.copyWith(isEnabled: true);
      expect(enabledHabit.isEnabled, isTrue);
    });

    test('Toggled off habits are excluded when calculating active habit counts', () {
      final habits = [
        Habit(id: '1', name: 'Habit 1', category: 'General', icon: 'check', color: '#FFF', scheduleType: 'daily', isEnabled: true, isDoneToday: true),
        Habit(id: '2', name: 'Habit 2', category: 'General', icon: 'check', color: '#FFF', scheduleType: 'daily', isEnabled: false, isDoneToday: true),
        Habit(id: '3', name: 'Habit 3', category: 'General', icon: 'check', color: '#FFF', scheduleType: 'daily', isEnabled: true, isDoneToday: false),
      ];

      final activeHabits = habits.where((h) => h.isEnabled).toList();
      final totalActive = activeHabits.length;
      final doneActive = activeHabits.where((h) => h.isDoneToday).length;

      expect(totalActive, 2);
      expect(doneActive, 1);
    });
  });
}

