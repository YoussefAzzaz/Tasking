import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_notification_service.dart';
import 'package:axis/data/habit_repository.dart';

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

  group('HabitNotificationService - Legacy Notification ID Tests', () {
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

  group('HabitNotificationService - Deterministic Occurrence IDs', () {
    test('toDateKey formats DateTime to YYYYMMDD integer', () {
      final dt = DateTime(2026, 11, 9, 14, 30);
      expect(HabitNotificationService.toDateKey(dt), 20261109);

      final dtNewYear = DateTime(2027, 1, 1);
      expect(HabitNotificationService.toDateKey(dtNewYear), 20270101);
    });

    test('generateOccurrenceId produces distinct IDs for 10m primary vs 5m follow-up', () {
      const habitId = 'habit_test_001';
      const dateKey = 20261109;

      final id10 = HabitNotificationService.generateOccurrenceId(
        habitId: habitId,
        dateKey: dateKey,
        isFollowUp: false,
      );
      final id5 = HabitNotificationService.generateOccurrenceId(
        habitId: habitId,
        dateKey: dateKey,
        isFollowUp: true,
      );

      expect(id10, isNot(equals(id5)));
      expect(id10, greaterThanOrEqualTo(100000000));
      expect(id10, lessThan(200000000));
      expect(id5, greaterThanOrEqualTo(200000000));
      expect(id5, lessThan(300000000));
    });

    test('generateOccurrenceId produces distinct IDs for different dates', () {
      const habitId = 'habit_test_001';
      final idDay1 = HabitNotificationService.generateOccurrenceId(
        habitId: habitId,
        dateKey: 20261109,
        isFollowUp: false,
      );
      final idDay2 = HabitNotificationService.generateOccurrenceId(
        habitId: habitId,
        dateKey: 20261110,
        isFollowUp: false,
      );

      expect(idDay1, isNot(equals(idDay2)));
    });

    test('generateOccurrenceId produces valid positive 32-bit signed ints without colliding with prayer alarms', () {
      final testHabits = ['habit_alpha', 'habit_beta', 'uuid_1234_5678', 'h99'];
      final dateKeys = [20261109, 20261231, 20270101, 20270615];

      for (final h in testHabits) {
        for (final dk in dateKeys) {
          for (final isFollowUp in [false, true]) {
            final id = HabitNotificationService.generateOccurrenceId(
              habitId: h,
              dateKey: dk,
              isFollowUp: isFollowUp,
            );
            expect(id, greaterThan(0));
            expect(id, lessThan(2147483647));
            expect([1001, 1002, 1003, 1004, 1005, 9991], isNot(contains(id)));
          }
        }
      }
    });
  });

  group('HabitNotificationService - Sliding Window "Next-N" Queue Tests', () {
    test('buildUpcomingOccurrences caps queue at maxQueueSize (40) even with 100 daily habits', () async {
      // 100 daily habits scheduled for 09:00 AM
      final habits = List.generate(100, (i) {
        return Habit(
          id: 'habit_$i',
          name: 'Habit #$i',
          remindTime: '09:00 AM',
          scheduleType: 'daily',
          isEnabled: true,
        );
      });

      final fixedNow = DateTime(2026, 11, 9, 8, 0); // 8:00 AM, before 9:00 AM
      final occurrences = await HabitNotificationService().buildUpcomingOccurrences(
        habits,
        limit: HabitNotificationService.maxQueueSize,
        fromTime: fixedNow,
        isCompletedToday: (_) async => false,
      );

      // Top 40 only
      expect(occurrences.length, equals(40));
      expect(HabitNotificationService.maxQueueSize, equals(40));
    });

    test('buildUpcomingOccurrences sorts items chronologically', () async {
      final habitEarly = Habit(
        id: 'h_early',
        name: 'Early Morning Routine',
        remindTime: '07:00 AM',
        scheduleType: 'daily',
        isEnabled: true,
      );
      final habitLate = Habit(
        id: 'h_late',
        name: 'Late Evening Read',
        remindTime: '08:00 PM',
        scheduleType: 'daily',
        isEnabled: true,
      );

      final fixedNow = DateTime(2026, 11, 9, 6, 0);
      final occurrences = await HabitNotificationService().buildUpcomingOccurrences(
        [habitLate, habitEarly],
        limit: 10,
        fromTime: fixedNow,
        isCompletedToday: (_) async => false,
      );

      expect(occurrences.isNotEmpty, isTrue);
      for (int i = 0; i < occurrences.length - 1; i++) {
        expect(
          occurrences[i].triggerTime.isBefore(occurrences[i + 1].triggerTime) ||
          occurrences[i].triggerTime.isAtSameMomentAs(occurrences[i + 1].triggerTime),
          isTrue,
        );
      }
      // Early morning habit triggers first
      expect(occurrences.first.habit.id, equals('h_early'));
    });

    test('buildUpcomingOccurrences assigns checkpoints to every 10th item and the last item', () async {
      final habits = List.generate(30, (i) {
        final hour = 7 + (i % 12);
        final hourStr = hour < 10 ? '0$hour' : '$hour';
        return Habit(
          id: 'habit_$i',
          name: 'Habit #$i',
          remindTime: '$hourStr:00',
          scheduleType: 'daily',
          isEnabled: true,
        );
      });

      final fixedNow = DateTime(2026, 11, 9, 6, 0);
      final occurrences = await HabitNotificationService().buildUpcomingOccurrences(
        habits,
        limit: 40,
        fromTime: fixedNow,
        isCompletedToday: (_) async => false,
      );

      expect(occurrences.length, equals(40));

      // 1-based: 10th, 20th, 30th, 40th items (0-based: 9, 19, 29, 39)
      expect(occurrences[9].isCheckpoint, isTrue);
      expect(occurrences[19].isCheckpoint, isTrue);
      expect(occurrences[29].isCheckpoint, isTrue);
      expect(occurrences[39].isCheckpoint, isTrue);

      // Non-checkpoints
      expect(occurrences[0].isCheckpoint, isFalse);
      expect(occurrences[1].isCheckpoint, isFalse);
      expect(occurrences[8].isCheckpoint, isFalse);
      expect(occurrences[10].isCheckpoint, isFalse);
    });

    test('buildUpcomingOccurrences marks the last item as checkpoint when queue has fewer than 10 items', () async {
      final habits = [
        Habit(
          id: 'single_habit',
          name: 'Read Book',
          remindTime: '10:00 AM',
          scheduleType: 'daily',
          isEnabled: true,
        ),
      ];

      final fixedNow = DateTime(2026, 11, 9, 8, 0);
      final occurrences = await HabitNotificationService().buildUpcomingOccurrences(
        habits,
        limit: 3,
        fromTime: fixedNow,
        isCompletedToday: (_) async => false,
      );

      expect(occurrences.length, equals(3));
      // In 3 items: item 0: false, item 1: false, item 2 (last): true
      expect(occurrences[0].isCheckpoint, isFalse);
      expect(occurrences[1].isCheckpoint, isFalse);
      expect(occurrences[2].isCheckpoint, isTrue);
    });

    test('buildUpcomingOccurrences skips today if habit is already completed today', () async {
      final habit = Habit(
        id: 'habit_completed_today',
        name: 'Morning Run',
        remindTime: '09:00 AM',
        scheduleType: 'daily',
        isEnabled: true,
      );

      final fixedNow = DateTime(2026, 11, 9, 7, 0); // 7:00 AM on Nov 9
      final occurrences = await HabitNotificationService().buildUpcomingOccurrences(
        [habit],
        limit: 4,
        fromTime: fixedNow,
        isCompletedToday: (id) async => id == 'habit_completed_today',
      );

      expect(occurrences.isNotEmpty, isTrue);
      // All occurrences must be for tomorrow (Nov 10) or later, none for today (Nov 9)
      for (final occ in occurrences) {
        expect(occ.dateKey, greaterThan(20261109));
        expect(occ.triggerTime.day, isNot(equals(9)));
      }
    });

    test('isHabitScheduledForDate correctly handles weekdays, weekly, and every_3_days', () {
      final habitDaily = Habit(id: '1', name: 'Daily', scheduleType: 'daily');
      final habitWeekdays = Habit(id: '2', name: 'Weekdays', scheduleType: 'weekdays');
      final habitWeekly = Habit(id: '3', name: 'Weekly', scheduleType: 'weekly');
      final habit3Days = Habit(id: '4', name: '3Days', scheduleType: 'every_3_days');

      final monday = DateTime(2026, 11, 9); // Monday
      final friday = DateTime(2026, 11, 13); // Friday
      final saturday = DateTime(2026, 11, 14); // Saturday
      final sunday = DateTime(2026, 11, 15); // Sunday

      // Daily
      expect(HabitNotificationService.isHabitScheduledForDate(habitDaily, monday, monday), isTrue);
      expect(HabitNotificationService.isHabitScheduledForDate(habitDaily, saturday, monday), isTrue);

      // Weekdays
      expect(HabitNotificationService.isHabitScheduledForDate(habitWeekdays, monday, monday), isTrue);
      expect(HabitNotificationService.isHabitScheduledForDate(habitWeekdays, friday, monday), isTrue);
      expect(HabitNotificationService.isHabitScheduledForDate(habitWeekdays, saturday, monday), isFalse);
      expect(HabitNotificationService.isHabitScheduledForDate(habitWeekdays, sunday, monday), isFalse);

      // Weekly (Friday only)
      expect(HabitNotificationService.isHabitScheduledForDate(habitWeekly, monday, monday), isFalse);
      expect(HabitNotificationService.isHabitScheduledForDate(habitWeekly, friday, monday), isTrue);
      expect(HabitNotificationService.isHabitScheduledForDate(habitWeekly, saturday, monday), isFalse);

      // Every 3 days starting Monday Nov 9 (day 0)
      expect(HabitNotificationService.isHabitScheduledForDate(habit3Days, monday, monday), isTrue); // Day 0
      expect(HabitNotificationService.isHabitScheduledForDate(habit3Days, DateTime(2026, 11, 10), monday), isFalse); // Day 1
      expect(HabitNotificationService.isHabitScheduledForDate(habit3Days, DateTime(2026, 11, 11), monday), isFalse); // Day 2
      expect(HabitNotificationService.isHabitScheduledForDate(habit3Days, DateTime(2026, 11, 12), monday), isTrue); // Day 3
      expect(HabitNotificationService.isHabitScheduledForDate(habit3Days, DateTime(2026, 11, 15), monday), isTrue); // Day 6
    });

    test('Occurrence fingerprint changes when habit attributes change', () {
      final habitA = Habit(
        id: 'h1',
        name: 'Pushups',
        remindTime: '08:00 AM',
        scheduleType: 'daily',
        isEnabled: true,
        color: '#10B981',
      );
      final now = DateTime(2026, 11, 9, 7, 50);

      final occ1 = HabitOccurrence(
        id: 100000001,
        habit: habitA,
        triggerTime: now,
        minutesBefore: 10,
        dateKey: 20261109,
        isFollowUp: false,
        isCheckpoint: false,
      );

      final occ2 = occ1.copyWith(isCheckpoint: true);
      expect(occ1.fingerprint, isNot(equals(occ2.fingerprint)));

      final habitB = habitA.copyWith(remindTime: '08:30 AM');
      final occ3 = occ1.copyWith(habit: habitB);
      expect(occ1.fingerprint, isNot(equals(occ3.fingerprint)));
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
