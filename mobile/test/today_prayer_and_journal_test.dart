import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/ui/today/widgets/today_prayer_times_card.dart';
import 'package:axis/ui/notes/widgets/daily_journal_card.dart';

void main() {
  group('TodayPrayerTimesCard & Journal Tests', () {
    final testPrayers = [
      const Prayer(
        id: 'prayer_fajr',
        userId: 'u1',
        prayerCode: 'fajr',
        name: 'Fajr',
        icon: 'fajr',
        time: '05:12 AM',
        sortOrder: 1,
        isDone: true,
        createdAt: '',
        updatedAt: '',
      ),
      const Prayer(
        id: 'prayer_dhuhr',
        userId: 'u1',
        prayerCode: 'dhuhr',
        name: 'Dhuhr',
        icon: 'dhuhr',
        time: '12:48 PM',
        sortOrder: 2,
        isDone: true,
        createdAt: '',
        updatedAt: '',
      ),
      const Prayer(
        id: 'prayer_asr',
        userId: 'u1',
        prayerCode: 'asr',
        name: 'Asr',
        icon: 'asr',
        time: '03:46 PM',
        sortOrder: 3,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      const Prayer(
        id: 'prayer_maghrib',
        userId: 'u1',
        prayerCode: 'maghrib',
        name: 'Maghrib',
        icon: 'maghrib',
        time: '06:22 PM',
        sortOrder: 4,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
      const Prayer(
        id: 'prayer_isha',
        userId: 'u1',
        prayerCode: 'isha',
        name: 'Isha',
        icon: 'isha',
        time: '07:48 PM',
        sortOrder: 5,
        isDone: false,
        createdAt: '',
        updatedAt: '',
      ),
    ];

    testWidgets('TodayPrayerTimesCard renders header, next prayer, capsules, and NO azan toggle', (tester) async {
      Prayer? toggledPrayer;
      bool? toggledState;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: TodayPrayerTimesCard(
                prayers: testPrayers,
                onTogglePrayer: (prayer, done) {
                  toggledPrayer = prayer;
                  toggledState = done;
                },
              ),
            ),
          ),
        ),
      );

      // Verify Header
      expect(find.text('PRAYER TELEMETRY'), findsOneWidget);
      expect(find.textContaining('QIBLA'), findsOneWidget);

      // Verify Next Prayer label & 24h format
      expect(find.textContaining('Next Prayer:'), findsOneWidget);

      // CRITICAL REQUIREMENT: NO azan on button in the widget
      expect(find.text('Azan On'), findsNothing);
      expect(find.text('Azan Off'), findsNothing);

      // Verify all 5 prayer names in horizontal capsules
      expect(find.text('Fajr'), findsWidgets);
      expect(find.text('Dhuhr'), findsWidgets);
      expect(find.text('Asr'), findsWidgets);
      expect(find.text('Maghrib'), findsWidgets);
      expect(find.text('Isha'), findsWidgets);

      // Verify 24h times matching user reference
      expect(find.text('05:12'), findsWidgets);
      expect(find.text('12:48'), findsWidgets);
      expect(find.text('15:46'), findsWidgets);
      expect(find.text('18:22'), findsWidgets);
      expect(find.text('19:48'), findsWidgets);

      // Verify obligations status: 2/5 (40%)
      expect(find.text('OBLIGATIONS: 2/5 (40%)'), findsOneWidget);

      // Tap on Asr capsule to toggle it
      await tester.tap(find.text('Asr').first);
      await tester.pump();

      expect(toggledPrayer?.prayerCode, equals('asr'));
      expect(toggledState, isTrue);
    });

    testWidgets('TodayPrayerTimesCard fits perfectly on small mobile (320px) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TodayPrayerTimesCard(
                prayers: testPrayers,
                onTogglePrayer: (_, _) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Assert no overflow occurred
      expect(tester.takeException(), isNull);
      expect(find.text('PRAYER TELEMETRY'), findsOneWidget);
      expect(find.text('OBLIGATIONS: 2/5 (40%)'), findsOneWidget);
    });

    testWidgets('DailyJournalCard renders properly on small mobile (320px) with start entry button', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool startTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DailyJournalCard(
                todayJournal: null,
                onOpenTodayJournal: (_) {},
                onStartNewJournal: () => startTriggered = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('DAILY JOURNAL'), findsOneWidget);
      expect(find.text('Start Today\'s Journal Entry'), findsOneWidget);

      await tester.tap(find.text('Start Today\'s Journal Entry'));
      await tester.pump();
      expect(startTriggered, isTrue);
    });
  });
}
