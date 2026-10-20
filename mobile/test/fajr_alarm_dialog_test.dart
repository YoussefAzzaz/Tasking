import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/habits/widgets/fajr_alarm_dialog.dart';

void main() {
  testWidgets('FajrAlarmDialog renders non-dismissible mental arithmetic challenge',
      (tester) async {
    bool dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FajrAlarmDialog(
            onAlarmDismissed: () {
              dismissed = true;
            },
          ),
        ),
      ),
    );

    // Initial pump and settle
    await tester.pump(const Duration(milliseconds: 100));

    // Check title and religious anti-snooze reminder
    expect(find.text('FAJR WAKE-UP MISSION'), findsOneWidget);
    expect(find.text('Prayer is better than sleep'), findsOneWidget);
    expect(find.text('Solve arithmetic problem to dismiss alarm:'), findsOneWidget);

    // Verify numpad is rendered
    expect(find.byKey(const ValueKey('numpad_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('numpad_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('numpad_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('numpad_C')), findsOneWidget);
    expect(find.byKey(const ValueKey('numpad_OK')), findsOneWidget);

    // Tap digits
    await tester.ensureVisible(find.byKey(const ValueKey('numpad_1')));
    await tester.tap(find.byKey(const ValueKey('numpad_1')));
    await tester.pump();
    expect(find.text('1'), findsWidgets);

    // Tap Clear
    await tester.ensureVisible(find.byKey(const ValueKey('numpad_C')));
    await tester.tap(find.byKey(const ValueKey('numpad_C')));
    await tester.pump();
    expect(find.text('Tap answer'), findsOneWidget);

    // Type incorrect answer '99' and tap OK
    await tester.ensureVisible(find.byKey(const ValueKey('numpad_9')));
    await tester.tap(find.byKey(const ValueKey('numpad_9')));
    await tester.tap(find.byKey(const ValueKey('numpad_9')));
    await tester.pump();

    await tester.ensureVisible(find.byKey(const ValueKey('numpad_OK')));
    await tester.tap(find.byKey(const ValueKey('numpad_OK')));
    await tester.pump();

    // Verify error message is shown and alarm is not dismissed
    expect(find.text('Incorrect answer. Calculate again to wake up!'), findsOneWidget);
    expect(dismissed, false);
  });
}
