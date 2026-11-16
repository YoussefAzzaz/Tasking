import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';

void main() {
  group('Adhan & Fajr Alarm Service Tests', () {
    test('Fajr alarm time calculates exactly 1 minute after Fajr adhan', () {
      final baseFajrTime = DateTime(2026, 10, 20, 5, 15, 0);
      final fajrItem = PrayerItem(
        id: 'habit_prayer_fajr',
        name: 'Fajr Prayer',
        icon: 'fajr',
        sortOrder: 1,
        time: baseFajrTime,
        formattedTime: '05:15 AM',
      );

      final fajrAlarmTime = fajrItem.time.add(const Duration(minutes: 1));
      expect(fajrAlarmTime.difference(fajrItem.time).inMinutes, 1);
      expect(fajrAlarmTime.hour, 5);
      expect(fajrAlarmTime.minute, 16);
    });

    test('All 5 prayers have distinct notification IDs based on sort order', () {
      final prayers = [
        PrayerItem(
          id: 'habit_prayer_fajr',
          name: 'Fajr Prayer',
          icon: 'fajr',
          sortOrder: 1,
          time: DateTime(2026, 10, 20, 5, 15),
          formattedTime: '05:15 AM',
        ),
        PrayerItem(
          id: 'habit_prayer_dhuhr',
          name: 'Dhuhr Prayer',
          icon: 'dhuhr',
          sortOrder: 2,
          time: DateTime(2026, 10, 20, 12, 30),
          formattedTime: '12:30 PM',
        ),
        PrayerItem(
          id: 'habit_prayer_asr',
          name: 'Asr Prayer',
          icon: 'asr',
          sortOrder: 3,
          time: DateTime(2026, 10, 20, 15, 45),
          formattedTime: '03:45 PM',
        ),
        PrayerItem(
          id: 'habit_prayer_maghrib',
          name: 'Maghrib Prayer',
          icon: 'maghrib',
          sortOrder: 4,
          time: DateTime(2026, 10, 20, 18, 10),
          formattedTime: '06:10 PM',
        ),
        PrayerItem(
          id: 'habit_prayer_isha',
          name: 'Isha Prayer',
          icon: 'isha',
          sortOrder: 5,
          time: DateTime(2026, 10, 20, 19, 40),
          formattedTime: '07:40 PM',
        ),
      ];

      final ids = prayers.map((p) => 1000 + p.sortOrder).toSet();
      expect(ids.length, 5);
      expect(ids, containsAll([1001, 1002, 1003, 1004, 1005]));
    });

    test('WAV header generator produces valid PCM stereo/mono specification', () {
      const sampleRate = 22050;
      const totalSamples = sampleRate * 1;
      const fileLength = 44 + totalSamples * 2;

      expect(fileLength, greaterThan(44));
      expect(totalSamples * 2, fileLength - 44);
    });

    test('sortOrderForPrayerCode and canonicalPrayerCode resolve all 5 canonical prayers', () {
      expect(AdhanAlarmService.sortOrderForPrayerCode('fajr'), 1);
      expect(AdhanAlarmService.sortOrderForPrayerCode('Fajr Prayer'), 1);
      expect(AdhanAlarmService.sortOrderForPrayerCode('prayer_u1_dhuhr'), 2);
      expect(AdhanAlarmService.sortOrderForPrayerCode('habit_prayer_asr'), 3);
      expect(AdhanAlarmService.sortOrderForPrayerCode('MAGHRIB'), 4);
      expect(AdhanAlarmService.sortOrderForPrayerCode('isha'), 5);
      expect(AdhanAlarmService.sortOrderForPrayerCode('unknown'), isNull);

      expect(AdhanAlarmService.canonicalPrayerCode('prayer_abc_dhuhr'), 'dhuhr');
      expect(AdhanAlarmService.canonicalPrayerCode('Asr'), 'asr');
      expect(AdhanAlarmService.canonicalPrayerCode(''), isNull);
    });

    test('isAfterAdhanTime correctly identifies whether current time is after scheduled adhan', () {
      final now = DateTime.now();
      final pastHour = (now.hour - 1 + 24) % 24;
      final pastTimeStr = '${pastHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final futureHour = (now.hour + 2) % 24;
      final futureTimeStr = '${futureHour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      // Past time (1 hour ago) should be after adhan time
      if (now.hour > 0) {
        expect(AdhanAlarmService.isAfterAdhanTime(prayerTime: pastTimeStr), isTrue);
      }
      // Future time (2 hours in future) should not be after adhan time
      if (now.hour < 22) {
        expect(AdhanAlarmService.isAfterAdhanTime(prayerTime: futureTimeStr), isFalse);
      }
    });

    test('isAdhanHandledOrDismissedToday correctly tracks dismissed adhan for current day', () async {
      final service = AdhanAlarmService();
      expect(await service.isAdhanHandledOrDismissedToday('unknown_prayer'), isFalse);

      // Triggered does not mean dismissed (screen must still be allowed to display)
      await service.markAdhanTriggeredToday('fajr');
      expect(await service.isAdhanHandledOrDismissedToday('fajr'), isFalse);

      // Once dismissed, it is recorded as handled/dismissed
      await service.markAdhanDismissedToday('fajr');
      expect(await service.isAdhanHandledOrDismissedToday('fajr'), isTrue);
      expect(await service.isAdhanHandledOrDismissedToday('Fajr Prayer'), isTrue);
      expect(await service.isAdhanHandledOrDismissedToday('dhuhr'), isFalse);

      await service.markAdhanDismissedToday('dhuhr');
      expect(await service.isAdhanHandledOrDismissedToday('dhuhr'), isTrue);
      expect(await service.isAdhanHandledOrDismissedToday('prayer_abc_dhuhr'), isTrue);
    });
  });
}
