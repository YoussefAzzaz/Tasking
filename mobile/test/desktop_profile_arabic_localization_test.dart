import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:axis/ui/desktop/shell/desktop_titlebar.dart';
import 'package:axis/ui/desktop/screens/profile_settings_screen.dart';

void main() {
  group('Desktop Arabic Localization & Profile Tests', () {
    test('Badge registry has complete Arabic localizations for all 50 badges', () {
      expect(kMasteryBadgeRegistry.length, 50);

      for (final def in kMasteryBadgeRegistry) {
        final badge = def.evaluate(0);

        // Arabic translations
        final arTitle = badge.localizedTitle(true);
        final arSub = badge.localizedSubtitle(true);
        expect(arTitle, isNotEmpty, reason: 'Badge ${badge.id} missing Arabic title');
        expect(arSub, isNotEmpty, reason: 'Badge ${badge.id} missing Arabic subtitle');
        expect(badge.localizedCategory(true), isNotEmpty);

        // English translations (fallback)
        expect(badge.localizedTitle(false), equals(badge.title));
        expect(badge.localizedSubtitle(false), equals(badge.subtitle));

        // Tiers localization
        for (final tier in badge.tiers) {
          final tierNameAr = tier.localizedName(true, badgeId: badge.id);
          final tierDescAr = tier.localizedDescription(true, badgeId: badge.id);
          final tierUnitAr = tier.localizedUnit(true, badgeId: badge.id);

          expect(tierNameAr, isNotEmpty, reason: 'Tier ${tier.tierNumber} in ${badge.id} missing Arabic name');
          expect(tierDescAr, isNotEmpty, reason: 'Tier ${tier.tierNumber} in ${badge.id} missing Arabic description');
          expect(tierUnitAr, isNotEmpty, reason: 'Tier ${tier.tierNumber} in ${badge.id} missing Arabic unit');

          expect(tier.localizedName(false), equals(tier.name));
          expect(tier.localizedDescription(false), equals(tier.description));
        }
      }
    });

    testWidgets('DesktopTitlebar maintains strict LTR directionality even in Arabic context', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: DesktopTitlebar(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the Directionality widget directly wrapping the DesktopTitlebar content
      final titlebarFinder = find.byType(DesktopTitlebar);
      expect(titlebarFinder, findsOneWidget);

      final innerDirectionality = tester.widget<Directionality>(
        find.descendant(
          of: titlebarFinder,
          matching: find.byType(Directionality),
        ).first,
      );
      expect(innerDirectionality.textDirection, equals(TextDirection.ltr));
    });

    testWidgets('ProfileSettingsScreen renders all cards, components, headers, and buttons in Arabic', (tester) async {
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ProfileSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Header and Save button
      expect(find.text('الإعدادات / ملف المشغل'), findsOneWidget);
      expect(find.text('الحساب والتخصيص'), findsOneWidget);
      expect(find.text('إدارة بيانات المشغل، مزامنة قاعدة البيانات، وتصنيفات العناصر'), findsOneWidget);
      expect(find.text('حفظ التغييرات'), findsOneWidget);

      // 2. Operator Identity Card
      expect(find.text('هوية المشغل'), findsOneWidget);
      expect(find.text('مُوثَّق'), findsOneWidget);
      expect(find.text('الصورة الشخصية وصورة الهوية'), findsOneWidget);
      expect(find.text('اختيار صورة'), findsOneWidget);
      expect(find.text('أو رابط صورة الهوية (URL)'), findsOneWidget);
      expect(find.text('اسم العرض'), findsOneWidget);
      expect(find.text('رمز النداء / المعرف'), findsOneWidget);
      expect(find.text('البريد الإلكتروني الأساسي للمحطة'), findsOneWidget);

      // 3. Note Categories Card
      expect(find.text('تصنيفات الملاحظات'), findsOneWidget);
      expect(find.text('تصنيف ملاحظات جديد...'), findsOneWidget);

      // 4. Habit Categories Card
      expect(find.text('تصنيفات العادات'), findsOneWidget);
      expect(find.text('عنوان تصنيف عادات جديد...'), findsOneWidget);

      // 5. Task Tags Card
      expect(find.text('وسوم وععلامات المهام'), findsNothing); // sanity check
      expect(find.text('وسوم وعلامات المهام'), findsOneWidget);
      expect(find.text('#وسم-جديد...'), findsOneWidget);
      expect(find.text('+ إنشاء وسم'), findsOneWidget);

      // 6. Reading Preferences Card
      expect(find.text('تفضيلات القراءة'), findsOneWidget);
      expect(find.text('إعادة تعيين'), findsOneWidget);
      expect(find.text('نموذج المعاينة'), findsOneWidget);

      // 7. Mastery Badges Card
      expect(find.text('أوسمة إتقان المشغل'), findsOneWidget);
      expect(find.text('المعرض ↗'), findsOneWidget);
    });
  });
}
