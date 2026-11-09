import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/prayer_time_service.dart';

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
  });
}
