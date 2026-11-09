import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_notification_service.dart';

void main() {
  group('Habit Notification Reminder Calculation Unit Tests', () {
    test('calculateReminderTimes accurately computes 10m and 5m before habit time', () {
      final times = HabitNotificationService.calculateReminderTimes('08:00');
      expect(times, isNotNull);
      expect(times!.habitMinutes, 480);
      expect(times.hour10, 7);
      expect(times.minute10, 50);
      expect(times.hour5, 7);
      expect(times.minute5, 55);
    });

    test('generateNotificationId generates distinct IDs for offsets and weekdays', () {
      final id10Daily = HabitNotificationService.generateNotificationId('habit_1', 10, 0);
      final id5Daily = HabitNotificationService.generateNotificationId('habit_1', 5, 0);
      final id10Mon = HabitNotificationService.generateNotificationId('habit_1', 10, 1);

      expect(id10Daily, isNot(equals(id5Daily)));
      expect(id10Daily, isNot(equals(id10Mon)));
      expect(id10Daily, greaterThan(0));
    });

    test('cancelAllHabitReminders executes cleanly without throwing', () async {
      await expectLater(
        HabitNotificationService().cancelAllHabitReminders(),
        completes,
      );
    });

    test('onHabitCompletedToday executes cleanly without throwing', () async {
      await expectLater(
        HabitNotificationService().onHabitCompletedToday('habit_test_123'),
        completes,
      );
    });
  });
}

