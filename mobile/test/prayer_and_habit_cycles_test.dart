import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/domain/streak_engine.dart';

void main() {
  group('Habit & Prayer Reset Cycles Tests', () {
    test('Daily habits reset every day at 00:00', () {
      final now1 = DateTime(2026, 10, 21, 14, 30);
      final cycle1 = HabitRepository.calculateCycleStartDate(
        scheduleType: 'daily',
        now: now1,
      );
      expect(cycle1, '2026-10-21');

      // Past midnight
      final now2 = DateTime(2026, 10, 22, 0, 5);
      final cycle2 = HabitRepository.calculateCycleStartDate(
        scheduleType: 'daily',
        now: now2,
      );
      expect(cycle2, '2026-10-22');
      expect(cycle2 != cycle1, true); // new cycle starts at 00:00
    });

    test('Weekly habits reset on Friday at 00:00', () {
      // Friday 2026-10-16
      final friday = DateTime(2026, 10, 16, 12, 0);
      expect(friday.weekday, DateTime.friday);

      final cycleFriday = HabitRepository.calculateCycleStartDate(
        scheduleType: 'weekly',
        now: friday,
      );
      expect(cycleFriday, '2026-10-16');

      // Saturday of same week
      final saturday = DateTime(2026, 10, 17, 10, 0);
      final cycleSaturday = HabitRepository.calculateCycleStartDate(
        scheduleType: 'weekly',
        now: saturday,
      );
      expect(cycleSaturday, '2026-10-16'); // Same weekly cycle!

      // Thursday before next Friday
      final thursday = DateTime(2026, 10, 22, 23, 59);
      final cycleThursday = HabitRepository.calculateCycleStartDate(
        scheduleType: 'weekly',
        now: thursday,
      );
      expect(cycleThursday, '2026-10-16'); // Still same weekly cycle!

      // Next Friday arrives at 00:00
      final nextFriday = DateTime(2026, 10, 23, 0, 1);
      final cycleNextFriday = HabitRepository.calculateCycleStartDate(
        scheduleType: 'weekly',
        now: nextFriday,
      );
      expect(cycleNextFriday, '2026-10-23'); // Reset! New weekly cycle begins
    });

    test('Every 3 days habits reset every 3 days from creation date at 00:00', () {
      const createdStr = '2026-10-10T14:20:00Z'; // Created on Oct 10
      
      // Day 0 (Oct 10): cycle start is 2026-10-10
      final day0 = DateTime(2026, 10, 10, 18, 0);
      expect(
        HabitRepository.calculateCycleStartDate(
          scheduleType: 'every_3_days',
          now: day0,
          createdAtStr: createdStr,
        ),
        '2026-10-10',
      );

      // Day 1 (Oct 11): cycle start is still 2026-10-10
      final day1 = DateTime(2026, 10, 11, 10, 0);
      expect(
        HabitRepository.calculateCycleStartDate(
          scheduleType: 'every_3_days',
          now: day1,
          createdAtStr: createdStr,
        ),
        '2026-10-10',
      );

      // Day 2 (Oct 12): cycle start is still 2026-10-10
      final day2 = DateTime(2026, 10, 12, 23, 59);
      expect(
        HabitRepository.calculateCycleStartDate(
          scheduleType: 'every_3_days',
          now: day2,
          createdAtStr: createdStr,
        ),
        '2026-10-10',
      );

      // Day 3 (Oct 13 at 00:00): Exactly 3 days pass -> Reset to new 3-day cycle!
      final day3 = DateTime(2026, 10, 13, 0, 5);
      expect(
        HabitRepository.calculateCycleStartDate(
          scheduleType: 'every_3_days',
          now: day3,
          createdAtStr: createdStr,
        ),
        '2026-10-13',
      );

      // Day 6 (Oct 16 at 00:00): Next 3-day reset!
      final day6 = DateTime(2026, 10, 16, 0, 1);
      expect(
        HabitRepository.calculateCycleStartDate(
          scheduleType: 'every_3_days',
          now: day6,
          createdAtStr: createdStr,
        ),
        '2026-10-16',
      );
    });

    test('Prayer ID format matches Supabase seed trigger', () {
      const uid = 'bb192339-77e9-473a-8eec-8269604334ae';
      expect(PrayerTimeService.prayerIdForCode('fajr', uid), 'prayer_bb192339-77e9-473a-8eec-8269604334ae_fajr');
      expect(PrayerTimeService.prayerIdForCode('dhuhr', uid), 'prayer_bb192339-77e9-473a-8eec-8269604334ae_dhuhr');
      expect(PrayerTimeService.prayerIdForCode('asr', uid), 'prayer_bb192339-77e9-473a-8eec-8269604334ae_asr');
      expect(PrayerTimeService.prayerIdForCode('maghrib', uid), 'prayer_bb192339-77e9-473a-8eec-8269604334ae_maghrib');
      expect(PrayerTimeService.prayerIdForCode('isha', uid), 'prayer_bb192339-77e9-473a-8eec-8269604334ae_isha');
    });

    test('Prayer.fromRow sanitizes rogue names and auto-resets completion across day boundaries', () {
      // Row with rogue UUID name from prior bug
      final corruptedRow = {
        'id': 'prayer_bb192339-77e9-473a-8eec-8269604334ae_fajr',
        'user_id': 'bb192339-77e9-473a-8eec-8269604334ae',
        'prayer_code': 'fajr',
        'name': 'BB192339-77E9-473A-8EEC-8269604334AE', // rogue name
        'icon': 'fajr',
        'time': '05:30 AM',
        'sort_order': 1,
        'is_done': 1,
        'created_at': '2026-10-20T05:00:00Z',
        'updated_at': '2026-10-20T06:00:00Z', // Yesterday
      };

      final prayer = Prayer.fromRow(corruptedRow);
      // Name is cleaned back to Fajr
      expect(prayer.name, 'Fajr');
      // isDone is automatically false for today because updated_at was yesterday
      expect(prayer.isDone, false);
      expect(prayer.prayerCode, 'fajr');
    });

    test('Prayer.fromRow preserves isDone when completed today or synced via habit_logs', () {
      final now = DateTime.now();
      final todayIso = now.toUtc().toIso8601String();

      // Checked today directly on prayers table
      final todayRow = {
        'id': 'prayer_user1_fajr',
        'user_id': 'user1',
        'prayer_code': 'fajr',
        'name': 'Fajr',
        'icon': 'fajr',
        'time': '05:30 AM',
        'sort_order': 1,
        'is_done': 1,
        'created_at': todayIso,
        'updated_at': todayIso,
      };
      final prayerToday = Prayer.fromRow(todayRow);
      expect(prayerToday.isDone, true);

      // Synced from second device via habit_logs today_log_status
      final syncedRow = {
        'id': 'prayer_user1_fajr',
        'user_id': 'user1',
        'prayer_code': 'fajr',
        'name': 'Fajr',
        'icon': 'fajr',
        'time': '05:30 AM',
        'sort_order': 1,
        'is_done': 0, // Even if local prayer row hasn't updated yet
        'created_at': '2026-10-20T05:00:00Z',
        'updated_at': '2026-10-20T05:00:00Z',
        'today_log_status': 'done', // Synced today log
      };
      final prayerSynced = Prayer.fromRow(syncedRow);
      expect(prayerSynced.isDone, true);
    });

    test('computeDailyStreakLogs requires ALL scheduled habits done before day counts', () {
      final habits = [
        {'id': 'h1', 'schedule_type': 'daily', 'created_at': '2026-10-01T00:00:00Z'},
        {'id': 'h2', 'schedule_type': 'daily', 'created_at': '2026-10-01T00:00:00Z'},
        {'id': 'h3', 'schedule_type': 'daily', 'created_at': '2026-10-01T00:00:00Z'},
      ];

      // Day 1: Only 1 habit done -> NOT done
      final logsOnlyOne = [
        {'habit_id': 'h1', 'log_date': '2026-10-22', 'status': 'done'},
      ];
      final resultOne = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: logsOnlyOne,
      );
      expect(resultOne, isEmpty);

      // Day 1: 2 habits done out of 3 -> NOT done
      final logsTwo = [
        {'habit_id': 'h1', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'h2', 'log_date': '2026-10-22', 'status': 'done'},
      ];
      final resultTwo = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: logsTwo,
      );
      expect(resultTwo, isEmpty);

      // Day 1: All 3 habits done -> DONE!
      final logsAll = [
        {'habit_id': 'h1', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'h2', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'h3', 'log_date': '2026-10-22', 'status': 'done'},
      ];
      final resultAll = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: logsAll,
      );
      expect(resultAll.length, 1);
      expect(resultAll.first.date, '2026-10-22');
      expect(resultAll.first.status, 'done');
    });

    test('Prayer logs do not pollute habit tracker streak', () {
      final habits = [
        {'id': 'h1', 'schedule_type': 'daily', 'created_at': '2026-10-01T00:00:00Z'},
      ];

      // User checked Fajr prayer at 6 AM, but did not do h1 yet
      final logsWithPrayerOnly = [
        {'habit_id': 'prayer_user1_fajr', 'log_date': '2026-10-22', 'status': 'done'},
      ];
      final result = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: logsWithPrayerOnly,
      );
      // Streak logs must remain empty because user habit h1 was not done!
      expect(result, isEmpty);
    });

    test('Completing at least 10 daily habits (prayers included) qualifies date as done and increments streak', () {
      // User has 15 total habits scheduled
      final habits = List.generate(
        15,
        (i) => {
          'id': 'habit_$i',
          'schedule_type': 'daily',
          'created_at': '2026-10-01T00:00:00Z',
        },
      );

      // Scenario A: 5 prayers + 5 habits done on 2026-10-22 (Total: 10 habits) -> QUALIFIED!
      final logs10 = [
        {'habit_id': 'prayer_user1_fajr', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_dhuhr', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_asr', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_maghrib', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_isha', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_0', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_1', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_2', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_3', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_4', 'log_date': '2026-10-22', 'status': 'done'},
      ];

      final result10 = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: logs10,
      );
      expect(result10.length, 1);
      expect(result10.first.date, '2026-10-22');
      expect(result10.first.status, 'done');

      // StreakEngine calculates streak = 1 on that day
      final streakDay1 = StreakEngine.calculateStreak('daily', result10, '2026-10-22');
      expect(streakDay1, 1);

      // Scenario B: 5 prayers + 4 habits (Total: 9 habits < 10) -> NOT QUALIFIED
      final logs9 = [
        {'habit_id': 'prayer_user1_fajr', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_dhuhr', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_asr', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_maghrib', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'prayer_user1_isha', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_0', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_1', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_2', 'log_date': '2026-10-22', 'status': 'done'},
        {'habit_id': 'habit_3', 'log_date': '2026-10-22', 'status': 'done'},
      ];

      final result9 = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: logs9,
      );
      expect(result9, isEmpty);

      // Scenario C: Consecutive days with at least 10 habits each increments monthly streak by one per day
      final logsTwoDays = [
        ...logs10, // 10 on Oct 22
        // 10 on Oct 23: 4 prayers + 6 regular habits
        {'habit_id': 'prayer_user1_fajr', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'prayer_user1_dhuhr', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'prayer_user1_asr', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'prayer_user1_maghrib', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'habit_0', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'habit_1', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'habit_2', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'habit_3', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'habit_4', 'log_date': '2026-10-23', 'status': 'done'},
        {'habit_id': 'habit_5', 'log_date': '2026-10-23', 'status': 'done'},
      ];

      final resultTwoDays = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: logsTwoDays,
      );
      expect(resultTwoDays.length, 2);
      expect(resultTwoDays.map((l) => l.date).toSet(), {'2026-10-22', '2026-10-23'});

      final streakDay2 = StreakEngine.calculateStreak('daily', resultTwoDays, '2026-10-23');
      expect(streakDay2, 2); // Incremented by one!
    });

    test('Incorporates today prayers from dedicated prayers table when computing streak', () {
      final habits = List.generate(
        15,
        (i) => {'id': 'h_$i', 'schedule_type': 'daily', 'created_at': '2026-10-01T00:00:00Z'},
      );

      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final nowUtcIso = DateTime.now().toUtc().toIso8601String();

      // 5 regular habits in habit_logs
      final habitLogs = [
        {'habit_id': 'h_0', 'log_date': todayStr, 'status': 'done'},
        {'habit_id': 'h_1', 'log_date': todayStr, 'status': 'done'},
        {'habit_id': 'h_2', 'log_date': todayStr, 'status': 'done'},
        {'habit_id': 'h_3', 'log_date': todayStr, 'status': 'done'},
        {'habit_id': 'h_4', 'log_date': todayStr, 'status': 'done'},
      ];

      // 5 prayers marked done in dedicated prayers table
      final prayerRows = [
        {'id': 'p1', 'prayer_code': 'fajr', 'is_done': 1, 'updated_at': nowUtcIso},
        {'id': 'p2', 'prayer_code': 'dhuhr', 'is_done': 1, 'updated_at': nowUtcIso},
        {'id': 'p3', 'prayer_code': 'asr', 'is_done': 1, 'updated_at': nowUtcIso},
        {'id': 'p4', 'prayer_code': 'maghrib', 'is_done': 1, 'updated_at': nowUtcIso},
        {'id': 'p5', 'prayer_code': 'isha', 'is_done': 1, 'updated_at': nowUtcIso},
      ];

      final logs = HabitRepository.computeDailyStreakLogs(
        habits: habits,
        habitLogs: habitLogs,
        prayers: prayerRows,
      );

      expect(logs.length, 1);
      expect(logs.first.date, todayStr);
      expect(logs.first.status, 'done');

      final streak = StreakEngine.calculateStreak('daily', logs, todayStr);
      expect(streak, 1);
    });
  });
}
