import 'package:flutter_test/flutter_test.dart';
import 'package:adhan_dart/adhan_dart.dart' hide Prayer;
import 'package:axis/data/prayers/prayer_model.dart';
import 'package:axis/data/prayers/prayer_calculator.dart';

void main() {
  group('PrayerCalculator Domain Unit Tests', () {
    const calculator = PrayerCalculator();

    test('getOptimalParameters selects correct parameter set for countries', () {
      final tunisia = calculator.getOptimalParameters('Tunisia');
      expect(tunisia.fajrAngle, equals(18.0));

      final egypt = calculator.getOptimalParameters('Egypt');
      expect(egypt.fajrAngle, equals(19.5));

      final mecca = calculator.getOptimalParameters('Saudi Arabia');
      expect(mecca.fajrAngle, equals(18.5));

      final fallbackOffset1 = calculator.getOptimalParameters('Unknown', 1);
      expect(fallbackOffset1.fajrAngle, equals(18.0));
    });

    test('calculatePrayers generates exactly 5 distinct chronological prayers', () {
      final coords = Coordinates(35.7065, -0.6292); // Oran
      final testDate = DateTime(2026, 11, 4, 10, 0, 0);

      final prayers = calculator.calculatePrayers(
        coordinates: coords,
        date: testDate,
        country: 'Algeria',
      );

      expect(prayers.length, equals(5));
      expect(prayers.map((p) => p.id).toList(), equals(['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']));

      // Assert chronological sequence
      for (int i = 0; i < prayers.length - 1; i++) {
        expect(prayers[i].time.isBefore(prayers[i + 1].time), isTrue,
            reason: '${prayers[i].name} should be before ${prayers[i + 1].name}');
      }
    });

    test('computeNextPrayer accurately identifies DUE NOW when current time is within 20m of Adan', () {
      final now = DateTime(2026, 11, 4, 12, 35); // 5 minutes after 12:30 PM Dhuhr
      final prayers = [
        const Prayer(
          id: 'p_fajr',
          userId: 'u1',
          prayerCode: 'fajr',
          name: 'Fajr',
          icon: 'fajr',
          time: '05:30 AM',
          sortOrder: 1,
          isDone: true,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_dhuhr',
          userId: 'u1',
          prayerCode: 'dhuhr',
          name: 'Dhuhr',
          icon: 'dhuhr',
          time: '12:30 PM',
          sortOrder: 2,
          isDone: false,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_asr',
          userId: 'u1',
          prayerCode: 'asr',
          name: 'Asr',
          icon: 'asr',
          time: '03:30 PM',
          sortOrder: 3,
          isDone: false,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_maghrib',
          userId: 'u1',
          prayerCode: 'maghrib',
          name: 'Maghrib',
          icon: 'maghrib',
          time: '05:45 PM',
          sortOrder: 4,
          isDone: false,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_isha',
          userId: 'u1',
          prayerCode: 'isha',
          name: 'Isha',
          icon: 'isha',
          time: '07:15 PM',
          sortOrder: 5,
          isDone: false,
          createdAt: '',
          updatedAt: '',
        ),
      ];

      final telemetry = calculator.computeNextPrayer(prayers, now);
      expect(telemetry.nextPrayer.prayerCode, equals('dhuhr'));
      expect(telemetry.isDueNow, isTrue);
      expect(telemetry.countdownText, equals('DUE NOW'));
    });

    test('computeNextPrayer advances to upcoming prayer when outside DUE NOW window', () {
      final now = DateTime(2026, 11, 4, 14, 0); // 2:00 PM, 1.5h before Asr at 3:30 PM
      final prayers = [
        const Prayer(
          id: 'p_fajr',
          userId: 'u1',
          prayerCode: 'fajr',
          name: 'Fajr',
          icon: 'fajr',
          time: '05:30 AM',
          sortOrder: 1,
          isDone: true,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_dhuhr',
          userId: 'u1',
          prayerCode: 'dhuhr',
          name: 'Dhuhr',
          icon: 'dhuhr',
          time: '12:30 PM',
          sortOrder: 2,
          isDone: true,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_asr',
          userId: 'u1',
          prayerCode: 'asr',
          name: 'Asr',
          icon: 'asr',
          time: '03:30 PM',
          sortOrder: 3,
          isDone: false,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_maghrib',
          userId: 'u1',
          prayerCode: 'maghrib',
          name: 'Maghrib',
          icon: 'maghrib',
          time: '05:45 PM',
          sortOrder: 4,
          isDone: false,
          createdAt: '',
          updatedAt: '',
        ),
        const Prayer(
          id: 'p_isha',
          userId: 'u1',
          prayerCode: 'isha',
          name: 'Isha',
          icon: 'isha',
          time: '07:15 PM',
          sortOrder: 5,
          isDone: false,
          createdAt: '',
          updatedAt: '',
        ),
      ];

      final telemetry = calculator.computeNextPrayer(prayers, now);
      expect(telemetry.nextPrayer.prayerCode, equals('asr'));
      expect(telemetry.isDueNow, isFalse);
      expect(telemetry.countdownText, contains('1h 30m'));
    });

    test('formatPrayerTime24 converts 12h format to 24h format', () {
      expect(calculator.formatPrayerTime24('05:30 AM'), equals('05:30'));
      expect(calculator.formatPrayerTime24('12:45 PM'), equals('12:45'));
      expect(calculator.formatPrayerTime24('08:15 PM'), equals('20:15'));
    });

    test('Prayer model arabicNameForCode returns authentic Arabic names', () {
      expect(Prayer.arabicNameForCode('fajr'), equals('الفجر'));
      expect(Prayer.arabicNameForCode('dhuhr'), equals('الظهر'));
      expect(Prayer.arabicNameForCode('asr'), equals('العصر'));
      expect(Prayer.arabicNameForCode('maghrib'), equals('المغرب'));
      expect(Prayer.arabicNameForCode('isha'), equals('العشاء'));
    });
  });
}

