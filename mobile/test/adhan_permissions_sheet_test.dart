import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/ui/prayers/adhan_permissions_sheet.dart';

void main() {
  group('AdhanPermissionsSheet Widget Tests', () {
    testWidgets('renders all 4 permissions and action buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdhanPermissionsSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Adhan & Prayer Alarm Permissions'), findsOneWidget);

      // Verify 4 key permission items
      expect(find.text('Prayer Notifications'), findsOneWidget);
      expect(find.text('Exact Alarms (Sub-Second)'), findsOneWidget);
      expect(find.text('Full-Screen Lock Screen Intent'), findsOneWidget);
      expect(find.text('Override Do Not Disturb'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Grant All Permissions'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });
  });
}

