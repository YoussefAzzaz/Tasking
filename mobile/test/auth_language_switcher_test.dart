import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/l10n/locale_service.dart';
import 'package:axis/ui/auth/auth_screen.dart';
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

      expect(LocaleService().isArabic, isFalse);
      expect(find.text('العربية'), findsOneWidget);

      await tester.tap(find.byType(AuthLanguageSwitcher));
      await tester.pumpAndSettle();

      expect(LocaleService().isArabic, isTrue);
      expect(find.text('English'), findsOneWidget);

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
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocaleService().setLocale(const Locale('ar'));

      await tester.pumpWidget(buildTestApp(const AuthScreen(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('AXIS'), findsOneWidget);
      expect(find.text('OFFLINE-FIRST CLOUD SYNC & AUTH'), findsOneWidget);
      expect(find.text('آكسس'), findsNothing);

      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(buildTestApp(const AuthScreen(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      expect(find.text('AXIS COMMAND STATION'), findsOneWidget);
      expect(find.text('OFFLINE-FIRST CLOUD SYNC & AUTHENTICATION'), findsOneWidget);
      expect(find.text('محطة قيادة آكسس'), findsNothing);
    });
  });
}

