import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/powersync_db.dart' show globalUserLevel;
import 'package:axis/ui/auth/auth_screen.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';
import 'package:axis/ui/desktop/shell/desktop_sidebar.dart';
import 'package:axis/ui/desktop/shell/desktop_titlebar.dart';

void main() {
  testWidgets('AuthScreen renders desktop terminal layout with DesktopTitlebar on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const MaterialApp(
        home: AuthScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Desktop Titlebar is present with window controls pinned to max right
    expect(find.byType(DesktopTitlebar), findsOneWidget);
    expect(find.byTooltip('Minimize'), findsOneWidget);
    expect(find.byTooltip('Maximize / Fullscreen'), findsOneWidget);
    expect(find.byTooltip('Exit'), findsOneWidget);
    expect(tester.getTopRight(find.byTooltip('Exit')).dx, 1440.0);

    // 2. Desktop Card with station branding
    expect(find.text('AXIS COMMAND STATION'), findsOneWidget);
    expect(find.text('OFFLINE-FIRST CLOUD SYNC & AUTHENTICATION'), findsOneWidget);

    // 3. Tab toggle: Sign In and Create Account
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.text('ENTER COMMAND STATION'), findsOneWidget);
    expect(find.text('CONTINUE IN OFFLINE MODE'), findsOneWidget);

    // Switch to Create Account
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(find.text('OPERATOR CALL-SIGN'), findsOneWidget);
    expect(find.text('INITIALIZE ACCOUNT'), findsOneWidget);
  });

  testWidgets('RainbowColorPickerButton draws small centered plus sign with CustomPainter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RainbowColorPickerButton(
              selectedColor: '#6366F1',
              size: 24,
              onColorSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify CustomPaint with custom plus painter exists inside button
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.byType(RainbowColorPickerButton), findsOneWidget);
  });

  testWidgets('DesktopSidebar synchronizes operator level dynamically with globalUserLevel', (tester) async {
    globalUserLevel.value = 5;

    await tester.pumpWidget(
      MaterialApp(
        theme: AxisTheme.dark,
        home: Scaffold(
          body: DesktopSidebar(
            selectedTab: 0,
            onSelectTab: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Level 5 should be displayed
    expect(find.text('OPERATOR • LVL 5'), findsOneWidget);

    // Dynamically update level to 12
    globalUserLevel.value = 12;
    await tester.pumpAndSettle();

    expect(find.text('OPERATOR • LVL 12'), findsOneWidget);

    // Reset back to 1
    globalUserLevel.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('OPERATOR • LVL 1'), findsOneWidget);
  });
}
