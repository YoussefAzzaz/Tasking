import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/me/me_screen.dart';

void main() {
  group('MeScreen Architecture & Design Flow Tests', () {
    testWidgets('MeScreen provides Scaffold, AppBar with back button and does not crash on Material assertions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: MeScreen(),
        ),
      );

      // Pump to let streams and async loaders settle
      await tester.pumpAndSettle();

      // 1. Verify Scaffold exists and has the deep canvasBase obsidian background
      final scaffoldFinder = find.byType(Scaffold);
      expect(scaffoldFinder, findsAtLeastNWidgets(1));
      final scaffold = tester.widget<Scaffold>(scaffoldFinder.first);
      expect(scaffold.backgroundColor, equals(AxisColors.canvasBase));

      // 2. Verify AppBar with Back Button, Title, and Sign Out action in top bar (replacing cloud icon)
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
      expect(find.text('ME'), findsOneWidget);
      expect(find.byKey(const ValueKey('me_top_sign_out_button')), findsOneWidget);

      // 3. Verify UserProfileCard rendered above Connected Cloud Account card
      expect(find.byType(UserProfileCard), findsOneWidget);
      expect(find.byType(MeCloudAccountCard), findsOneWidget);
      final profileDy = tester.getTopLeft(find.byType(UserProfileCard)).dy;
      final cloudDy = tester.getTopLeft(find.byType(MeCloudAccountCard)).dy;
      expect(cloudDy, greaterThan(profileDy));

      // 4. Verify Mastery Badges Section rendered
      expect(find.byType(MasteryBadgesSection), findsOneWidget);

      // 5. Verify Taxonomy Sections rendered
      expect(find.byType(HabitCategoriesSection), findsOneWidget);
      expect(find.byType(NoteCategoriesSection), findsOneWidget);
      expect(find.byType(TaskTagsSection), findsOneWidget);

      // 6. Verify Adhan Settings Card rendered
      expect(find.byType(MeAdhanSettingsCard), findsOneWidget);

      // 7. Verify Language Selector exists
      expect(find.text('English'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);

      // 8. Verify login icon is absent when authenticated/default
      expect(find.byIcon(Icons.login_rounded), findsNothing);
    });

    testWidgets('UserProfileCard displays friend code and calculates level progress', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserProfileCard(
              userName: 'Neo Cortex',
              userTitle: 'Lead Architect',
              level: 3,
              totalXp: 350,
              friendCode: 'AX-9942',
              onSaveProfile: (name, title, [color]) {},
            ),
          ),
        ),
      );

      expect(find.text('Neo Cortex'), findsOneWidget);
      expect(find.text('Lead Architect'), findsOneWidget);
      expect(find.text('CODE: AX-9942'), findsOneWidget);
      expect(find.text('Level 3 • 350 XP'), findsOneWidget);
    });

    testWidgets('HabitCategoriesSection delete shows confirmation dialog before deletion', (tester) async {
      var deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HabitCategoriesSection(
              categories: const [
                {'id': 'cat_1', 'name': 'Morning Flow', 'color': '#10B981'},
              ],
              onAddCategory: (name, color) {},
              onDeleteCategory: (id, name) => deleted = true,
            ),
          ),
        ),
      );

      expect(find.text('Morning Flow'), findsOneWidget);

      // Tap delete icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Confirmation dialog should be visible
      expect(find.text('Delete "Morning Flow"?'), findsOneWidget);
      expect(deleted, isFalse);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);

      // Tap delete again and confirm
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deleted, isTrue);
    });

    testWidgets('TaskTagsSection delete shows confirmation dialog before deletion', (tester) async {
      var deletedTag = '';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskTagsSection(
              taskTags: const ['urgent', 'backend'],
              onAddTag: (tag) {},
              onDeleteTag: (tag) => deletedTag = tag,
            ),
          ),
        ),
      );

      expect(find.text('@urgent'), findsOneWidget);

      // Tap close on @urgent
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Delete tag "@urgent"?'), findsOneWidget);
      expect(deletedTag, isEmpty);

      // Confirm deletion
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(deletedTag, equals('urgent'));
    });

    testWidgets('MeAdhanSettingsCard renders switches, current sound and action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MeAdhanSettingsCard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('ADHAN & PRAYER NOTIFICATIONS'), findsOneWidget);

      // Notification & Alarm switches
      expect(find.text('Adhan Notifications'), findsOneWidget);
      expect(find.text('Fajr Wake-Up Alarm'), findsOneWidget);
      expect(find.byType(Switch), findsNWidgets(2));

      // Active sound preview card
      expect(find.text('ACTIVE ADHAN SOUND (TAKBEERAT):'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Actions
      expect(find.text('Explore Sounds'), findsOneWidget);
      expect(find.text('Upload Audio'), findsOneWidget);
    });
  });
}
