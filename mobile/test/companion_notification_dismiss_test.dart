import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/desktop/widgets/desktop_companions_sidebar_tabs.dart';

Widget _buildTestHost({
  required Widget child,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: AxisTheme.dark,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Companion Notification Dismissal & Standings Removal Tests', () {
    final activityRepo = FriendActivityRepository();
    final friendRepo = FriendRepository();

    setUp(() {
      activityRepo.resetDismissedForTesting();
    });

    tearDown(() {
      activityRepo.resetDismissedForTesting();
    });

    test('dismissNotification records dismissed log ID into dismissed set', () async {
      expect(activityRepo.dismissedLogIdsForTesting.contains('log_123'), isFalse);

      await friendRepo.dismissNotification('log_123');

      expect(activityRepo.dismissedLogIdsForTesting.contains('log_123'), isTrue);

      await friendRepo.dismissNotification('log_456');
      expect(activityRepo.dismissedLogIdsForTesting.contains('log_456'), isTrue);
      expect(activityRepo.dismissedLogIdsForTesting.length, equals(2));
    });

    test('clearSessionState resets in-memory dismissed logs on sign out', () async {
      await friendRepo.dismissNotification('log_789');
      expect(activityRepo.dismissedLogIdsForTesting.contains('log_789'), isTrue);

      activityRepo.clearSessionState();
      expect(activityRepo.dismissedLogIdsForTesting.isEmpty, isTrue);
    });

    testWidgets('DesktopCompanionsSidebarTabs renders only Circle and Activity tabs (no Standings tab)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestHost(
          child: SizedBox(
            width: 320,
            height: 600,
            child: DesktopCompanionsSidebarTabs(onAddCompanion: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Circle and Activity tab buttons exist
      expect(find.text('Circle'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);

      // Verify Standings tab button does NOT exist
      expect(find.text('Standings'), findsNothing);
      expect(find.text('الترتيب'), findsNothing);

      // Tap on Activity tab
      await tester.tap(find.text('Activity'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show empty state or activity list
      expect(find.text('Circle'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Standings'), findsNothing);
    });

    testWidgets('DesktopCompanionsSidebarTabs in Arabic renders only 2 tabs without Standings', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildTestHost(
          locale: const Locale('ar'),
          child: SizedBox(
            width: 320,
            height: 600,
            child: DesktopCompanionsSidebarTabs(onAddCompanion: () {}),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('الدائرة'), findsOneWidget);
      expect(find.text('التنبيهات'), findsOneWidget);
      expect(find.text('الترتيب'), findsNothing);
      expect(find.text('Standings'), findsNothing);
    });
  });
}
