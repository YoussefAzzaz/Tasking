import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/l10n/locale_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await LocaleService().setLocale(const Locale('ar'));
  });

  group('LocaleService Tests', () {
    test('default locale is Arabic (ar)', () {
      final service = LocaleService();
      expect(service.currentLocale.languageCode, equals('ar'));
      expect(service.isArabic, isTrue);
    });

    test('setting English locale updates isArabic and currentLocale', () async {
      final service = LocaleService();
      await service.setLocale(const Locale('en'));

      expect(service.currentLocale.languageCode, equals('en'));
      expect(service.isArabic, isFalse);
    });

    test('toggleLanguage alternates between ar and en', () async {
      final service = LocaleService();
      expect(service.isArabic, isTrue);

      await service.toggleLanguage();
      expect(service.isArabic, isFalse);
      expect(service.currentLocale.languageCode, equals('en'));

      await service.toggleLanguage();
      expect(service.isArabic, isTrue);
      expect(service.currentLocale.languageCode, equals('ar'));
    });
  });

  group('AppLocalizations Dictionary & Translation Tests', () {
    test('English dictionary matches expected terms', () {
      final en = AppLocalizations(const Locale('en'));

      expect(en.today, equals('Today'));
      expect(en.tasks, equals('Tasks'));
      expect(en.habits, equals('Habits'));
      expect(en.notes, equals('Notes'));
      expect(en.me, equals('Me'));
      expect(en.companions, equals('Companions'));
      expect(en.friends, equals('Friends'));
      expect(en.language, equals('Language'));
      expect(en.textDirection, equals(TextDirection.ltr));

      expect(en.fajr, equals('Fajr'));
      expect(en.dhuhr, equals('Dhuhr'));
      expect(en.asr, equals('Asr'));
      expect(en.maghrib, equals('Maghrib'));
      expect(en.isha, equals('Isha'));
      expect(en.prayerName('fajr'), equals('Fajr'));
      expect(en.translate('New Task'), equals('New Task'));
    });

    test('Arabic dictionary matches expected translations & RTL direction', () {
      final ar = AppLocalizations(const Locale('ar'));

      expect(ar.today, equals('اليوم'));
      expect(ar.tasks, equals('المهام'));
      expect(ar.habits, equals('العادات'));
      expect(ar.notes, equals('الملاحظات'));
      expect(ar.me, equals('حسابي'));
      expect(ar.companions, equals('الرفاق'));
      expect(ar.friends, equals('الأصدقاء'));
      expect(ar.language, equals('اللغة'));
      expect(ar.textDirection, equals(TextDirection.rtl));

      expect(ar.fajr, equals('الفجر'));
      expect(ar.dhuhr, equals('الظهر'));
      expect(ar.asr, equals('العصر'));
      expect(ar.maghrib, equals('المغرب'));
      expect(ar.isha, equals('العشاء'));
      expect(ar.prayerName('asr'), equals('العصر'));
      expect(ar.translate('New Task'), equals('مهمة جديدة'));
      expect(ar.translate('Search'), equals('بحث'));
      expect(ar.translate('Save'), equals('حفظ'));
    });
  });

  group('AppLocalizations Widget Context Tests', () {
    testWidgets('MaterialApp with AppLocalizations resolves correctly in widget tree', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Scaffold(
                body: Column(
                  children: [
                    Text(l10n.today),
                    Text(l10n.tasks),
                    Text(l10n.prayerName('fajr')),
                    Text('New Task'.tr(context)),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('اليوم'), findsOneWidget);
      expect(find.text('المهام'), findsOneWidget);
      expect(find.text('الفجر'), findsOneWidget);
      expect(find.text('مهمة جديدة'), findsOneWidget);
    });

    testWidgets('Directionality is RTL when Arabic locale is mounted', (tester) async {
      late TextDirection observedDirection;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              observedDirection = Directionality.of(context);
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(observedDirection, equals(TextDirection.rtl));
    });
  });
}
