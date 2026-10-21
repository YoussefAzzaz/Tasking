import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayer_time_service.dart';

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
      final createdStr = '2026-10-10T14:20:00Z'; // Created on Oct 10
      
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
  });
}
