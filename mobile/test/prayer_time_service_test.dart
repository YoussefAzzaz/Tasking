import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_dart/adhan_dart.dart';
import 'package:intl/intl.dart';
import 'package:axis/data/habit_repository.dart';

void main() {
  group('Islamic Prayer Times & Habits Service Tests', () {
    test('adhan_dart accurately calculates 5 daily prayers for coordinates', () {
      // Testing with coordinates for Algiers/Oran (Lat: 35.7065, Lng: -0.6292)
      const coordinates = Coordinates(35.7065, -0.6292);
      final testDate = DateTime(2026, 10, 20);
      final params = CalculationMethodParameters.tunisia();

      final prayerTimes = PrayerTimes(
        coordinates: coordinates,
        date: testDate,
        calculationParameters: params,
        precision: false,
      );

      expect(prayerTimes.fajr, isNotNull);
      expect(prayerTimes.dhuhr, isNotNull);
      expect(prayerTimes.asr, isNotNull);
      expect(prayerTimes.maghrib, isNotNull);
      expect(prayerTimes.isha, isNotNull);

      // Verify strict chronological sequence
      expect(prayerTimes.fajr.isBefore(prayerTimes.dhuhr), isTrue);
      expect(prayerTimes.dhuhr.isBefore(prayerTimes.asr), isTrue);
      expect(prayerTimes.asr.isBefore(prayerTimes.maghrib), isTrue);

      final qiblaDirection = Qibla.qibla(coordinates);
      expect(qiblaDirection, isNotNull);
      expect(qiblaDirection, greaterThan(90));
      expect(qiblaDirection, lessThan(120)); // From Oran/Algiers, Mecca is roughly ESE (~105-110 deg)
      expect(prayerTimes.maghrib.isBefore(prayerTimes.isha), isTrue);

      String formatAdan(DateTime dt) => DateFormat('hh:mm a').format(dt.toLocal());
      expect(formatAdan(prayerTimes.fajr), isNotEmpty);
      expect(formatAdan(prayerTimes.dhuhr), isNotEmpty);
      expect(formatAdan(prayerTimes.asr), isNotEmpty);
      expect(formatAdan(prayerTimes.maghrib), isNotEmpty);
      expect(formatAdan(prayerTimes.isha), isNotEmpty);
    });

    test('Habit model correctly parses prayer habits and sets Prayers category', () {
      final prayerRow = {
        'id': 'habit_prayer_fajr',
        'name': 'Fajr Prayer',
        'kind': 'Prayers',
        'icon': 'fajr',
        'color': '#10B981',
        'schedule_type': 'daily',
        'remind_time': '05:32 AM',
        'target_value': 25,
        'sort_order': 1,
      };

      final habit = Habit.fromRow(prayerRow);
      expect(habit.id, 'habit_prayer_fajr');
      expect(habit.name, 'Fajr Prayer');
      expect(habit.category, 'Prayers');
      expect(habit.icon, 'fajr');
      expect(habit.remindTime, '05:32 AM');
      expect(habit.targetValue, 25);
      expect(habit.sortOrder, 1);
    });

    test('Habit model falls back to Prayers category when kind is missing but prayer icon is present', () {
      final prayerIcons = ['mosque', 'prayer', 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

      for (final icon in prayerIcons) {
        final row = {
          'id': 'prayer_$icon',
          'name': 'Prayer $icon',
          'kind': '',
          'icon': icon,
        };
        final habit = Habit.fromRow(row);
        expect(habit.category, 'Prayers', reason: 'Icon $icon should map to Prayers category');
      }
    });

    test('5 prayer habits sort sequentially from Fajr (1) to Isha (5)', () {
      final prayers = [
        Habit(id: '3', name: 'Asr Prayer', category: 'Prayers', sortOrder: 3),
        Habit(id: '5', name: 'Isha Prayer', category: 'Prayers', sortOrder: 5),
        Habit(id: '1', name: 'Fajr Prayer', category: 'Prayers', sortOrder: 1),
        Habit(id: '4', name: 'Maghrib Prayer', category: 'Prayers', sortOrder: 4),
        Habit(id: '2', name: 'Dhuhr Prayer', category: 'Prayers', sortOrder: 2),
      ];

      prayers.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      expect(prayers.map((p) => p.name).toList(), [
        'Fajr Prayer',
        'Dhuhr Prayer',
        'Asr Prayer',
        'Maghrib Prayer',
        'Isha Prayer',
      ]);
    });
  });
}
