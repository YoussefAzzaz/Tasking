import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/debug/adhan_alarm_debug_screen.dart';

void main() {
  group('AdhanAlarmDebugScreen Widget Tests', () {
    testWidgets('renders telemetry, permissions audit, scheduled tests and 5 prayer buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: AdhanAlarmDebugScreen(),
        ),
      );

      // Verify header title
      expect(find.text('ADHAN ALARM DEBUG COCKPIT'), findsOneWidget);

      // Verify Section titles
      expect(find.text('LIVE SYSTEM TELEMETRY'), findsOneWidget);
      expect(find.text('PERMISSIONS AUDIT'), findsOneWidget);
      expect(find.text('TEST BACKGROUND / LOCK SCREEN ALARM'), findsOneWidget);
      expect(find.text('TEST FULL-SCREEN OVERLAYS (FOREGROUND)'), findsOneWidget);
      expect(find.text('AUDIO STREAM ROUTING DIAGNOSTICS'), findsOneWidget);

      // Verify all 5 prayers are listed
      expect(find.text('Fajr'), findsOneWidget);
      expect(find.text('Dhuhr'), findsOneWidget);
      expect(find.text('Asr'), findsOneWidget);
      expect(find.text('Maghrib'), findsOneWidget);
      expect(find.text('Isha'), findsOneWidget);

      // Verify delay chips (5s, 10s, 30s, 60s)
      expect(find.text('5s'), findsOneWidget);
      expect(find.text('10s'), findsOneWidget);
      expect(find.text('30s'), findsOneWidget);
      expect(find.text('60s'), findsOneWidget);

      // Verify Action buttons
      expect(find.text('Request / Grant All Alarm Permissions'), findsOneWidget);
      expect(find.text('Start Alarm Sound'), findsOneWidget);
      expect(find.text('Stop Sound'), findsOneWidget);
    });
  });
}
