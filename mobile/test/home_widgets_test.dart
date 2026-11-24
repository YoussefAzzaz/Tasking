import 'package:adhan_dart/adhan_dart.dart' hide Prayer;
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/widget_navigation_service.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/domain/hijri_date.dart';

void main() {
  group('HijriDate Conversion & Formatting Tests', () {
    test('Converts well-known Gregorian dates accurately', () {
      final ramadan1445 = HijriDate.fromGregorian(DateTime(2024, 3, 11));
      expect(ramadan1445.year, 1445);
      expect(ramadan1445.month, 9);
      expect(ramadan1445.day, 1);
      expect(ramadan1445.arabicMonthName, 'رمضان');

      final sample = HijriDate.fromGregorian(DateTime(2026, 11, 24));
      expect(sample.year, 1448);
      expect(sample.month, 6);
      expect(sample.day, 13);
      expect(sample.formatArabic(), '13 جمادى الآخرة 1448');
      expect(sample.formatEnglish(), '13 Jum II');
    });
  });

  group('PrayerCalculator Sunrise & Current Prayer Tests', () {
    const calculator = PrayerCalculator();
    const coords = Coordinates(35.7065, -0.6292); // Oran

    test('calculateSunrise returns sunrise strictly between Fajr and Dhuhr', () {
      final date = DateTime(2026, 11, 24, 12, 0);
      final prayers = calculator.calculatePrayers(
        coordinates: coords,
        date: date,
        country: 'Algeria',
      );
      final sunrise = calculator.calculateSunrise(
        coordinates: coords,
        date: date,
        country: 'Algeria',
      );

      expect(sunrise.isAfter(prayers[0].time), isTrue); // After Fajr
      expect(sunrise.isBefore(prayers[1].time), isTrue); // Before Dhuhr
    });

    test('determineCurrentPrayerCode identifies every prayer window cleanly', () {
      final date = DateTime(2026, 11, 24, 12, 0);
      final prayers = calculator.calculatePrayers(
        coordinates: coords,
        date: date,
        country: 'Algeria',
      );
      final sunrise = calculator.calculateSunrise(
        coordinates: coords,
        date: date,
        country: 'Algeria',
      );

      expect(
        calculator.determineCurrentPrayerCode(
          prayers,
          sunrise,
          prayers[0].time.subtract(const Duration(minutes: 10)),
        ),
        'isha',
      );
      expect(
        calculator.determineCurrentPrayerCode(
          prayers,
          sunrise,
          prayers[0].time.add(const Duration(minutes: 10)),
        ),
        'fajr',
      );
      expect(
        calculator.determineCurrentPrayerCode(
          prayers,
          sunrise,
          sunrise.add(const Duration(minutes: 10)),
        ),
        'sunrise',
      );
      expect(
        calculator.determineCurrentPrayerCode(
          prayers,
          sunrise,
          prayers[1].time.add(const Duration(minutes: 10)),
        ),
        'dhuhr',
      );
      expect(
        calculator.determineCurrentPrayerCode(
          prayers,
          sunrise,
          prayers[2].time.add(const Duration(minutes: 10)),
        ),
        'asr',
      );
      expect(
        calculator.determineCurrentPrayerCode(
          prayers,
          sunrise,
          prayers[3].time.add(const Duration(minutes: 10)),
        ),
        'maghrib',
      );
      expect(
        calculator.determineCurrentPrayerCode(
          prayers,
          sunrise,
          prayers[4].time.add(const Duration(minutes: 10)),
        ),
        'isha',
      );
    });
  });

  group('Habit Widget Filtering Tests', () {
    tearDown(() {
      HabitStateManager.setHabitPausedInMemory('h_paused', false);
    });

    test('Excludes toggled-off, locally paused, deleted, non-daily, and prayer habits', () {
      HabitStateManager.setHabitPausedInMemory('h_paused', true);

      final rawRows = [
        {
          'id': 'h_active',
          'name': 'Morning Walk',
          'color': '#10B981',
          'schedule_type': 'daily',
          'kind': 'Wellness',
          'is_enabled': 1,
          'deleted_at': '',
        },
        {
          'id': 'h_toggled_off',
          'name': 'Off Habit',
          'color': '#EF4444',
          'schedule_type': 'daily',
          'kind': 'Wellness',
          'is_enabled': 0,
          'deleted_at': null,
        },
        {
          'id': 'h_paused',
          'name': 'Locally Paused Habit',
          'color': '#F59E0B',
          'schedule_type': 'daily',
          'kind': 'Wellness',
          'is_enabled': 1,
          'deleted_at': null,
        },
        {
          'id': 'h_local_disabled',
          'name': 'Local Table Disabled',
          'color': '#6366F1',
          'schedule_type': 'daily',
          'kind': 'Wellness',
          'is_enabled': 1,
          'deleted_at': null,
        },
        {
          'id': 'h_deleted',
          'name': 'Deleted Habit',
          'color': '#0EA5E9',
          'schedule_type': 'daily',
          'kind': 'Wellness',
          'is_enabled': 1,
          'deleted_at': '2026-11-20T00:00:00Z',
        },
        {
          'id': 'h_weekly',
          'name': 'Weekly Review',
          'color': '#8B5CF6',
          'schedule_type': 'weekly',
          'kind': 'Work',
          'is_enabled': 1,
          'deleted_at': null,
        },
        {
          'id': 'habit_prayer_fajr',
          'name': 'Fajr',
          'color': '#06B6D4',
          'schedule_type': 'daily',
          'kind': 'Prayers',
          'is_enabled': 1,
          'deleted_at': null,
        },
      ];

      final filtered = AppWidgetSyncService.filterActiveDailyHabitRows(
        rawRows,
        pausedOrDisabledIds: {'h_local_disabled'},
      );

      expect(filtered.length, 1);
      expect(filtered.first['id'], 'h_active');
    });
  });

  group('Today Tasks Widget Priority & Overdue Formatting Tests', () {
    test('Detects past-day and same-day past-time overdue tasks and prioritizes pending items', () {
      final now = DateTime(2026, 11, 24, 15, 0);
      final pastOverdueRows = [
        {
          'id': 'old_1',
          'title': 'Yesterday backlog',
          'status': 'todo',
          'priority': 2,
          'due_date': '2026-11-23',
          'due_time': null,
        },
      ];
      final todayRows = [
        {
          'id': 't_done',
          'title': 'Finished early',
          'status': 'done',
          'priority': 1,
          'due_date': '2026-11-24',
          'due_time': '08:00',
        },
        {
          'id': 't_overdue_today',
          'title': 'Missed morning call',
          'status': 'todo',
          'priority': 2,
          'due_date': '2026-11-24',
          'due_time': '10:30',
        },
        {
          'id': 't_upcoming',
          'title': 'Evening ship',
          'status': 'todo',
          'priority': 1,
          'due_date': '2026-11-24',
          'due_time': '18:00',
        },
      ];

      final items = AppWidgetSyncService.buildTodayTaskItems(
        todayRows: todayRows,
        pastOverdueRows: pastOverdueRows,
        now: now,
      );

      expect(items.length, 4);
      expect(items[0]['title'], 'Yesterday backlog');
      expect(items[0]['overdue'], isTrue);
      expect(items[0]['time'], '⚠ OVERDUE');

      expect(items[1]['title'], 'Missed morning call');
      expect(items[1]['overdue'], isTrue);
      expect(items[1]['time'], '⚠ 10:30');

      expect(items[2]['title'], 'Evening ship');
      expect(items[2]['overdue'], isFalse);
      expect(items[2]['priority'], 1);
      expect(items[2]['time'], '18:00');

      expect(items[3]['title'], 'Finished early');
      expect(items[3]['done'], isTrue);
    });
  });

  group('WidgetNavigationService Deep-Link URI Resolution Tests', () {
    test('Routes Habits widget URI directly to /habits and others to /today', () {
      expect(
        WidgetNavigationService.routeFromUri(Uri.parse('axis://widget/habits')),
        '/habits',
      );
      expect(
        WidgetNavigationService.routeFromUri(Uri.parse('axis://widget/today')),
        '/today',
      );
      expect(
        WidgetNavigationService.routeFromUri(Uri.parse('axis://widget/prayers')),
        '/today',
      );
      expect(WidgetNavigationService.routeFromUri(null), isNull);
    });

    test('Pending widget route is consumed once and resets launchedFromWidget flag', () {
      final svc = WidgetNavigationService();
      svc.setPendingRouteForTesting('/habits', launchedFromWidget: true);
      expect(svc.launchedFromWidget, isTrue);
      expect(svc.resolveInitialAuthenticatedRoute(), '/habits');
      expect(svc.launchedFromWidget, isFalse);
      expect(svc.resolveInitialAuthenticatedRoute(), '/today');
    });
  });
}
