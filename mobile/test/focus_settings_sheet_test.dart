import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';

void main() {
  testWidgets('FocusSettingsSheet renders on narrow screens without overflow',
      (tester) async {
    // Set a narrow screen size (320x640)
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const config = FocusSessionConfig(
      focusMinutes: 25,
      shortBreakMinutes: 5,
      longBreakMinutes: 15,
      cyclesBeforeLongBreak: 4,
      autoStartBreaks: true,
      soundscapeAutoPlay: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FocusSettingsSheet(
            initialConfig: config,
            onConfigSaved: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('SESSION CONFIGURATION'), findsOneWidget);
    expect(find.text('FOCUS WAVE DURATION'), findsOneWidget);
    expect(find.text('REBOOT BREAK (SHORT)'), findsOneWidget);
    expect(find.text('EXTENDED RECUPERATION (LONG BREAK)'), findsOneWidget);
    expect(find.text('APPLY CONFIGURATION'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
