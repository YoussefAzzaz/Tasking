import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/friends/friends_screen.dart';
import 'package:axis/core/l10n/app_localizations.dart';

void main() {
  testWidgets('FriendsScreen scroll and tab navigation test in English', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ar')],
        locale: Locale('en'),
        home: FriendsScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scroll Tab 0 down
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on Today's Board (Tab 1)
    await tester.tap(find.text("Today's Board"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Now tap back on Circle (Tab 0) - tests the user reported crash
    await tester.tap(find.text("Circle"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on Circle again while already on Circle
    await tester.tap(find.text("Circle"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on Weekly Standings (Tab 2)
    await tester.tap(find.text("Weekly Standings"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on Today's Board (Tab 1)
    await tester.tap(find.text("Today's Board"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap on Circle (Tab 0)
    await tester.tap(find.text("Circle"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('FriendsScreen tab navigation test in Arabic', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [Locale('en'), Locale('ar')],
        locale: Locale('ar'),
        home: FriendsScreen(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify all 3 tabs rendered
    final tabs = find.byType(Tab);
    expect(tabs, findsNWidgets(3));

    // Tap Tab 1 (Today's Prayers)
    await tester.tap(tabs.at(1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Tab 0 (Circle)
    await tester.tap(tabs.at(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Re-tap Tab 0 (Circle)
    await tester.tap(tabs.at(0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Tap Tab 2 (Weekly Standings)
    await tester.tap(tabs.at(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Re-tap Tab 2
    await tester.tap(tabs.at(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
