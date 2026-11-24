import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/prayers/adhan_full_screen_alarm.dart';
import 'package:axis/data/adhan_alarm_service.dart';

void main() {
  group('AdhanFullScreenAlarm Widget Tests', () {
    testWidgets('renders prayer name, time, and dismisses on Dismiss button tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              savedContext = context;
              return const Scaffold(
                body: Center(child: Text('Underlying Screen')),
              );
            },
          ),
        ),
      );

      // Verify initial state
      expect(find.text('Underlying Screen'), findsOneWidget);
      expect(AdhanAlarmService().isFullScreenAlarmShowing, isFalse);

      // Show full-screen adhan
      AdhanFullScreenAlarm.show(
        savedContext,
        prayerName: 'Maghrib',
        prayerNameAr: 'المغرب',
        prayerTime: '06:15 PM',
        prayerId: 'test_maghrib',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify overlay is shown
      expect(find.text('Maghrib'), findsOneWidget);
      expect(find.text('06:15 PM'), findsOneWidget);
      expect(find.text('Dismiss Adhan'), findsOneWidget);
      expect(find.text('Mark as Prayed ✓'), findsOneWidget);
      expect(AdhanAlarmService().isFullScreenAlarmShowing, isTrue);

      // Tap Dismiss Adhan
      await tester.tap(find.text('Dismiss Adhan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify overlay is completely dismissed
      expect(find.text('Dismiss Adhan'), findsNothing);
      expect(find.text('Maghrib'), findsNothing);
      expect(find.text('Underlying Screen'), findsOneWidget);
      expect(AdhanAlarmService().isFullScreenAlarmShowing, isFalse);
    });

    testWidgets('dismisses on Mark as Prayed button tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              savedContext = context;
              return const Scaffold(
                body: Center(child: Text('Home Screen')),
              );
            },
          ),
        ),
      );

      AdhanFullScreenAlarm.show(
        savedContext,
        prayerName: 'Fajr',
        prayerNameAr: 'الفجر',
        prayerTime: '05:15 AM',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Mark as Prayed ✓'), findsOneWidget);

      // Tap Mark as Prayed
      await tester.tap(find.text('Mark as Prayed ✓'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // For Fajr, the anti-sleep verification dialog requires confirmation
      expect(find.text('Yes, Awake & Prayed'), findsOneWidget);
      await tester.tap(find.text('Yes, Awake & Prayed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify overlay is closed
      expect(find.text('Fajr'), findsNothing);
      expect(find.text('Home Screen'), findsOneWidget);
      expect(AdhanAlarmService().isFullScreenAlarmShowing, isFalse);
    });
  });
}
