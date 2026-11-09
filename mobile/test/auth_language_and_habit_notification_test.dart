import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/l10n/locale_service.dart';
import 'package:axis/data/habit_notification_service.dart';
import 'package:axis/ui/auth/auth_screen.dart';
import 'package:axis/ui/desktop/shell/desktop_sidebar.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() {
  setUp(() {
    LocaleService().setLocale(const Locale('en'));
  });

  Widget buildTestApp(Widget child, {Locale locale = const Locale('en')}) {
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

  group('Auth Screen Language Switcher Tests', () {
    testWidgets('AuthLanguageSwitcher toggles language on tap', (tester) async {
      await tester.pumpWidget(buildTestApp(const AuthLanguageSwitcher()));
      await tester.pumpAndSettle();

      // Initially in English
      expect(LocaleService().isArabic, isFalse);
      expect(find.text('العربية'), findsOneWidget);

      // Tap to switch to Arabic
      await tester.tap(find.byType(AuthLanguageSwitcher));
      await tester.pumpAndSettle();

      expect(LocaleService().isArabic, isTrue);
      expect(find.text('English'), findsOneWidget);

      // Tap again to switch back
      await tester.tap(find.byType(AuthLanguageSwitcher));
      await tester.pumpAndSettle();

      expect(LocaleService().isArabic, isFalse);
      expect(find.text('العربية'), findsOneWidget);
    });

    testWidgets('AuthScreen renders AuthLanguageSwitcher in mobile layout', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const AuthScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AuthLanguageSwitcher), findsOneWidget);
    });

    testWidgets('AuthScreen renders AuthLanguageSwitcher in desktop layout', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestApp(const AuthScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(AuthLanguageSwitcher), findsOneWidget);
    });

    testWidgets('AuthScreen branding (app name and slogan) remains in English in both Arabic and English', (tester) async {
      // 1. Mobile layout in Arabic
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocaleService().setLocale(const Locale('ar'));

      await tester.pumpWidget(buildTestApp(const AuthScreen(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('AXIS'), findsOneWidget);
      expect(find.text('OFFLINE-FIRST CLOUD SYNC & AUTH'), findsOneWidget);
      expect(find.text('آكسس'), findsNothing);

      // 2. Desktop layout in Arabic
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(buildTestApp(const AuthScreen(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('AXIS COMMAND STATION'), findsOneWidget);
      expect(find.text('OFFLINE-FIRST CLOUD SYNC & AUTHENTICATION'), findsOneWidget);
      expect(find.text('محطة قيادة آكسس'), findsNothing);
    });
  });

  group('Desktop Sidebar Log Out Localization Tests', () {
    testWidgets('renders Log Out button in English', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocaleService().setLocale(const Locale('en'));

      await tester.pumpWidget(
        buildTestApp(
          DesktopSidebar(
            selectedTab: 0,
            onSelectTab: (_) {},
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsNothing);
    });

    testWidgets('renders Log Out button in Arabic', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocaleService().setLocale(const Locale('ar'));

      await tester.pumpWidget(
        buildTestApp(
          DesktopSidebar(
            selectedTab: 0,
            onSelectTab: (_) {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تسجيل الخروج'), findsOneWidget);
      expect(find.text('Log Out'), findsNothing);
    });
  });

  group('Habit Notification Service Unit Tests', () {
    test('calculateReminderTimes accurately computes 10m and 5m before habit time', () {
      final times = HabitNotificationService.calculateReminderTimes('08:00');
      expect(times, isNotNull);
      expect(times!.habitMinutes, 480);
      expect(times.hour10, 7);
      expect(times.minute10, 50);
      expect(times.hour5, 7);
      expect(times.minute5, 55);
    });

    test('generateNotificationId generates distinct IDs for offsets and weekdays', () {
      final id10Daily = HabitNotificationService.generateNotificationId('habit_1', 10, 0);
      final id5Daily = HabitNotificationService.generateNotificationId('habit_1', 5, 0);
      final id10Mon = HabitNotificationService.generateNotificationId('habit_1', 10, 1);

      expect(id10Daily, isNot(equals(id5Daily)));
      expect(id10Daily, isNot(equals(id10Mon)));
      expect(id10Daily, greaterThan(0));
    });

    test('cancelAllHabitReminders executes cleanly without throwing', () async {
      await expectLater(
        HabitNotificationService().cancelAllHabitReminders(),
        completes,
      );
    });

    test('onHabitCompletedToday executes cleanly without throwing', () async {
      await expectLater(
        HabitNotificationService().onHabitCompletedToday('habit_test_123'),
        completes,
      );
    });
  });
}

