import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/l10n/locale_service.dart';
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
}

