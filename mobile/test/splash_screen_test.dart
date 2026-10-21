import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/common/splash_screen.dart';

void main() {
  testWidgets('SplashScreen renders all Stitch cyber-minimalism components without overflow',
      (WidgetTester tester) async {
    // Set typical phone dimensions (iPhone / modern Android 390x844)
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Initial frame
    await tester.pump();

    // Verify key UI text elements are rendered
    expect(find.text('SYS.ONLINE'), findsOneWidget);
    expect(find.text('SYS.READY'), findsOneWidget);
    expect(find.text('LOCAL-FIRST'), findsOneWidget);
    expect(find.text('MESH // 64'), findsOneWidget);
    expect(find.text('AXIS'), findsNWidgets(2)); // Header + Hero title
    expect(find.text('KINETIC FLOW OS • V2.4.0'), findsOneWidget);
    expect(find.text('SYNCHRONIZING SECURE OFFLINE VAULT'), findsOneWidget);
    expect(find.text('ENTER FLOW STATE'), findsOneWidget);
    expect(
      find.text('OBSIDIAN CORE V2.4 • BIOMETRIC & LOCAL-FIRST ENCRYPTED'),
      findsOneWidget,
    );

    // Advance animation forward to ensure no overflow during progress tween
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });
}
