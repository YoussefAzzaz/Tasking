import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';

void main() {
  group('Habit time parsing and sorting tests', () {
    test('parseTimeToMinutes handles 12h AM/PM and 24h correctly', () {
      expect(HabitRepository.parseTimeToMinutes('12:00 AM'), equals(0));
      expect(HabitRepository.parseTimeToMinutes('06:30 AM'), equals(390));
      expect(HabitRepository.parseTimeToMinutes('12:00 PM'), equals(720));
      expect(HabitRepository.parseTimeToMinutes('01:15 PM'), equals(795));
      expect(HabitRepository.parseTimeToMinutes('11:59 PM'), equals(1439));
      expect(HabitRepository.parseTimeToMinutes('14:30'), equals(870));
      expect(HabitRepository.parseTimeToMinutes(null), greaterThan(1440));
      expect(HabitRepository.parseTimeToMinutes(''), greaterThan(1440));
    });

    test('compareByTime sorts habits chronologically by time of day', () {
      final h1 = Habit(id: '1', name: 'Morning Run', category: 'Health', remindTime: '06:00 AM');
      final h2 = Habit(id: '2', name: 'Lunch Walk', category: 'Health', remindTime: '12:30 PM');
      final h3 = Habit(id: '3', name: 'Evening Read', category: 'Health', remindTime: '08:00 PM');
      final h4 = Habit(id: '4', name: 'Anytime Pushups', category: 'Health', remindTime: null, sortOrder: 1);
      final h5 = Habit(id: '5', name: 'Anytime Water', category: 'Health', remindTime: null, sortOrder: 2);

      final list = [h4, h3, h1, h5, h2];
      list.sort(HabitRepository.compareByTime);

      expect(list.map((h) => h.id).toList(), equals(['1', '2', '3', '4', '5']));
    });
  });
}
