import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_notification_service.dart';

void main() {
  group('HabitNotificationService - Time Calculation Tests', () {
    test('Calculates 10-min and 5-min reminders accurately for morning time (07:30 AM)', () {
      final times = HabitNotificationService.calculateReminderTimes('07:30 AM');
      expect(times, isNotNull);
      expect(times!.habitMinutes, 450);
      expect(times.tenMinBefore, 440);
      expect(times.hour10, 7);
      expect(times.minute10, 20);
      expect(times.fiveMinBefore, 445);
      expect(times.hour5, 7);
      expect(times.minute5, 25);
    });

    test('Calculates 10-min and 5-min reminders accurately for afternoon time (02:15 PM)', () {
      final times = HabitNotificationService.calculateReminderTimes('02:15 PM');
      expect(times, isNotNull);
      expect(times!.habitMinutes, 855);
      expect(times.tenMinBefore, 845);
      expect(times.hour10, 14);
      expect(times.minute10, 5);
      expect(times.fiveMinBefore, 850);
      expect(times.hour5, 14);
      expect(times.minute5, 10);
    });

    test('Calculates 10-min and 5-min reminders accurately for 24h format (18:00)', () {
      final times = HabitNotificationService.calculateReminderTimes('18:00');
      expect(times, isNotNull);
      expect(times!.habitMinutes, 1080);
      expect(times.tenMinBefore, 1070);
      expect(times.hour10, 17);
      expect(times.minute10, 50);
      expect(times.fiveMinBefore, 1075);
      expect(times.hour5, 17);
      expect(times.minute5, 55);
    });

    test('Midnight edge case: 12:05 AM wraps around midnight for 10-min reminder', () {
      final times = HabitNotificationService.calculateReminderTimes('12:05 AM');
      expect(times, isNotNull);
      expect(times!.habitMinutes, 5);
      // 5 - 10 = -5 -> wraps to 23:55 (1435 min)
      expect(times.tenMinBefore, 1435);
      expect(times.hour10, 23);
      expect(times.minute10, 55);
      // 5 - 5 = 0 -> 00:00 midnight
      expect(times.fiveMinBefore, 0);
      expect(times.hour5, 0);
      expect(times.minute5, 0);
    });

    test('Midnight edge case: 12:00 AM wraps around midnight for both 10-min and 5-min reminders', () {
      final times = HabitNotificationService.calculateReminderTimes('12:00 AM');
      expect(times, isNotNull);
      expect(times!.habitMinutes, 0);
      expect(times.tenMinBefore, 1430);
      expect(times.hour10, 23);
      expect(times.minute10, 50);
      expect(times.fiveMinBefore, 1435);
      expect(times.hour5, 23);
      expect(times.minute5, 55);
    });

    test('Returns null for null, empty, or unparseable time strings', () {
      expect(HabitNotificationService.calculateReminderTimes(null), isNull);
      expect(HabitNotificationService.calculateReminderTimes(''), isNull);
      expect(HabitNotificationService.calculateReminderTimes('   '), isNull);
      expect(HabitNotificationService.calculateReminderTimes('invalid_time'), isNull);
    });
  });

  group('HabitNotificationService - Notification ID Tests', () {
    test('10-minute and 5-minute reminders have distinct IDs for the same habit', () {
      const habitId = 'habit_workout_daily_101';
      final id10 = HabitNotificationService.generateNotificationId(habitId, 10);
      final id5 = HabitNotificationService.generateNotificationId(habitId, 5);

      expect(id10, isNot(equals(id5)));
      expect(id10, greaterThanOrEqualTo(100000000));
      expect(id10, lessThan(200000000));
      expect(id5, greaterThanOrEqualTo(200000000));
      expect(id5, lessThan(300000000));
    });

    test('Different habits generate distinct notification IDs', () {
      const habitA = 'habit_alpha_1';
      const habitB = 'habit_beta_2';

      final idA10 = HabitNotificationService.generateNotificationId(habitA, 10);
      final idB10 = HabitNotificationService.generateNotificationId(habitB, 10);

      expect(idA10, isNot(equals(idB10)));
    });

    test('Weekday variants generate non-overlapping notification IDs', () {
      const habitId = 'habit_weekday_read';
      final ids = <int>{};

      for (int w = 1; w <= 5; w++) {
        final id10 = HabitNotificationService.generateNotificationId(habitId, 10, w);
        final id5 = HabitNotificationService.generateNotificationId(habitId, 5, w);
        ids.add(id10);
        ids.add(id5);
      }

      // All 10 IDs across the 5 weekdays should be completely unique
      expect(ids.length, equals(10));
    });

    test('Notification IDs never collide with Prayer times (1001-1005) or Fajr alarm (9991)', () {
      const testHabit = 'habit_code_study';
      final id10 = HabitNotificationService.generateNotificationId(testHabit, 10);
      final id5 = HabitNotificationService.generateNotificationId(testHabit, 5);

      expect(id10, greaterThan(100000));
      expect(id5, greaterThan(100000));
      expect([1001, 1002, 1003, 1004, 1005, 9991], isNot(contains(id10)));
      expect([1001, 1002, 1003, 1004, 1005, 9991], isNot(contains(id5)));
    });

    test('Generated IDs are positive 32-bit signed integers', () {
      const habitIds = [
        'habit_1',
        'habit_very_long_uuid_9999999999999999',
        'random_xyz_!@#',
        'habit_fajr_custom',
      ];

      for (final id in habitIds) {
        for (final offset in [10, 5]) {
          for (int w = 0; w <= 7; w++) {
            final notifId = HabitNotificationService.generateNotificationId(id, offset, w);
            expect(notifId, greaterThan(0));
            expect(notifId, lessThan(2147483647));
          }
        }
      }
    });
  });

  group('HabitNotificationService - Configuration & Utility Tests', () {
    test('Channel key matches habit_reminder_channel', () {
      expect(HabitNotificationService.channelKey, 'habit_reminder_channel');
    });

    test('parseHex handles valid and invalid hex formats safely', () {
      expect(HabitNotificationService.parseHex('#10B981'), const Color(0xFF10B981));
      expect(HabitNotificationService.parseHex('10B981'), const Color(0xFF10B981));
      expect(HabitNotificationService.parseHex('#FF10B981'), const Color(0xFF10B981));
      expect(HabitNotificationService.parseHex(null), const Color(0xFF10B981));
      expect(HabitNotificationService.parseHex('invalid'), const Color(0xFF10B981));
    });
  });
}
