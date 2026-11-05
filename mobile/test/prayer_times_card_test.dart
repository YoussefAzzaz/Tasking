import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/habits/widgets/prayer_times_card.dart';

void main() {
  testWidgets('PrayerTimesCard renders exactly 5 prayers without overflow and supports reset',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final prayers = [
      const Prayer(
        id: 'prayer_test_fajr',
        userId: 'user_1',
        prayerCode: 'fajr',
        name: 'Fajr',
        icon: 'fajr',
        time: '05:32 AM',
        sortOrder: 1,
        isDone: false,
        createdAt: '2026-10-21T00:00:00Z',
        updatedAt: '2026-10-21T00:00:00Z',
      ),
      const Prayer(
        id: 'prayer_test_dhuhr',
        userId: 'user_1',
        prayerCode: 'dhuhr',
        name: 'Dhuhr',
        icon: 'dhuhr',
        time: '12:45 PM',
        sortOrder: 2,
        isDone: true,
        createdAt: '2026-10-21T00:00:00Z',
        updatedAt: '2026-10-21T00:00:00Z',
      ),
      const Prayer(
        id: 'prayer_test_asr',
        userId: 'user_1',
        prayerCode: 'asr',
        name: 'Asr',
        icon: 'asr',
        time: '04:05 PM',
        sortOrder: 3,
        isDone: false,
        createdAt: '2026-10-21T00:00:00Z',
        updatedAt: '2026-10-21T00:00:00Z',
      ),
      const Prayer(
        id: 'prayer_test_maghrib',
        userId: 'user_1',
        prayerCode: 'maghrib',
        name: 'Maghrib',
        icon: 'maghrib',
        time: '06:50 PM',
        sortOrder: 4,
        isDone: false,
        createdAt: '2026-10-21T00:00:00Z',
        updatedAt: '2026-10-21T00:00:00Z',
      ),
      const Prayer(
        id: 'prayer_test_isha',
        userId: 'user_1',
        prayerCode: 'isha',
        name: 'Isha',
        icon: 'isha',
        time: '08:15 PM',
        sortOrder: 5,
        isDone: false,
        createdAt: '2026-10-21T00:00:00Z',
        updatedAt: '2026-10-21T00:00:00Z',
      ),
    ];

    bool resetCalled = false;
    Prayer? toggledPrayer;
    bool? toggledDone;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AxisTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PrayerTimesCard(
                prayers: prayers,
                onTogglePrayer: (p, d) {
                  toggledPrayer = p;
                  toggledDone = d;
                },
                onResetPrayers: () async {
                  resetCalled = true;
                },
                onRefreshLocation: () async {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify key prayer widgets rendered
    expect(find.text('Prayers'), findsOneWidget);
    expect(find.text('Qibla Direction (Live GPS & Compass)'), findsOneWidget);
    expect(find.text('Adhan Alerts & Fajr Alarm'), findsOneWidget);
    expect(find.text('+1 MIN'), findsOneWidget);
    expect(find.text('Fajr'), findsOneWidget);
    expect(find.text('Dhuhr'), findsOneWidget);
    expect(find.text('Asr'), findsOneWidget);
    expect(find.text('Maghrib'), findsOneWidget);
    expect(find.text('Isha'), findsOneWidget);
    expect(find.text('Adan 05:32 AM'), findsOneWidget);

    // Verify there are NO add habit or add extra prayer buttons
    expect(find.textContaining('Add Extra Prayer'), findsNothing);
    expect(find.textContaining('Add Habit to Prayers'), findsNothing);

    // Test reset prayer action button with confirmation
    final resetBtn = find.byTooltip("Reset Today's Prayers");
    expect(resetBtn, findsOneWidget);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    // Confirm dialog is shown
    expect(find.text("Reset Today's Prayers?"), findsOneWidget);
    final confirmBtn = find.text('Reset to Undone');
    expect(confirmBtn, findsOneWidget);
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    expect(resetCalled, isTrue);

    // Verify toggling a prayer
    final fajrCheckbox = find.byType(AxisCheckbox).first;
    await tester.tap(fajrCheckbox);
    await tester.pumpAndSettle();
    expect(toggledPrayer?.name, 'Fajr');
    expect(toggledDone, isTrue);

    // No overflow exception was thrown
    expect(tester.takeException(), isNull);
  });
}
