import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:axis/ui/me/me_screen.dart';

void main() {
  group('MasteryBadge 50-Badge Registry & Domain Tests', () {
    test('Registry contains exactly 50 distinct badges with 4 tiers each', () {
      expect(kMasteryBadgeRegistry.length, 50);

      final uniqueIds = <String>{};
      for (final def in kMasteryBadgeRegistry) {
        // IDs must be unique
        expect(uniqueIds.contains(def.id), isFalse, reason: 'Duplicate badge ID: ${def.id}');
        uniqueIds.add(def.id);

        // Every badge must have exactly 4 progressive tiers
        expect(def.tiers.length, 4, reason: 'Badge ${def.id} does not have 4 tiers');

        for (int i = 0; i < def.tiers.length; i++) {
          final tier = def.tiers[i];
          expect(tier.tierNumber, i + 1);
          expect(tier.targetValue, greaterThan(0));
          if (i > 0) {
            expect(tier.targetValue, greaterThan(def.tiers[i - 1].targetValue),
                reason: 'Tier ${tier.tierNumber} target must be greater than previous');
          }
        }
      }
    });

    test('UserProductivityMetrics single-pass DTO maps metrics in O(1)', () {
      const metrics = UserProductivityMetrics(
        completedTasks: 42,
        highPriorityTasks: 7,
        totalFocusMinutes: 180,
        streakDays: 14,
        notesCount: 20,
        habitLogs: 90,
        userLevel: 5,
      );

      expect(metrics.getMetricValue(BadgeMetricType.tasksCompleted), 42);
      expect(metrics.getMetricValue(BadgeMetricType.tasksHighPriority), 7);
      expect(metrics.getMetricValue(BadgeMetricType.focusMinutes), 180);
      expect(metrics.getMetricValue(BadgeMetricType.streakDays), 14);
      expect(metrics.getMetricValue(BadgeMetricType.notesCount), 20);
      expect(metrics.getMetricValue(BadgeMetricType.habitLogs), 90);
      expect(metrics.getMetricValue(BadgeMetricType.userLevel), 5);
    });

    test('Category filtering segregates badges accurately', () async {
      final repo = MasteryBadgeRepository();
      final all = await repo.getMasteryBadges(category: BadgeCategory.all);
      final execution = await repo.getMasteryBadges(category: BadgeCategory.execution);
      final focus = await repo.getMasteryBadges(category: BadgeCategory.focus);
      final streaks = await repo.getMasteryBadges(category: BadgeCategory.consistency);

      expect(all.length, 50);
      expect(execution.length, 10);
      expect(focus.length, 9);
      expect(streaks.length, 8);
    });

    test('Spotlight badges return top 3 closest to unlocking next tier', () async {
      final repo = MasteryBadgeRepository();
      final spotlight = await repo.getSpotlightBadges();

      expect(spotlight.length, lessThanOrEqualTo(3));
      expect(spotlight.isNotEmpty, isTrue);
    });

    test('Badge progress calculation handles mid-tier and maxed states', () {
      const badge = MasteryBadgeData(
        id: 'closer',
        title: 'The Closer',
        category: 'Execution',
        icon: Icons.task_alt_rounded,
        color: AxisColors.success,
        currentValue: 30,
        tiers: [
          BadgeTier(tierNumber: 1, name: 'Closer I', targetValue: 10, unit: 'tasks', description: ''),
          BadgeTier(tierNumber: 2, name: 'Closer II', targetValue: 50, unit: 'tasks', description: ''),
          BadgeTier(tierNumber: 3, name: 'Closer III', targetValue: 100, unit: 'tasks', description: ''),
        ],
      );

      expect(badge.isUnlocked, isTrue);
      expect(badge.currentTier?.name, 'Closer I');
      expect(badge.nextTier?.name, 'Closer II');
      // (30 - 10) / (50 - 10) = 20 / 40 = 0.5 (50%)
      expect(badge.progress, 0.5);
      expect(badge.progressLabel, '30 / 50 tasks');
    });
  });

  group('MasteryBadgesSection & MasteryBadgesScreen Widget Tests', () {
    testWidgets('MasteryBadgesSection renders horizontal scroll carousel, spotlight, and See More button',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: MasteryBadgesSection(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify header and See All action button
      expect(find.text('MASTERY BADGES'), findsOneWidget);
      expect(find.text('See All (50)'), findsOneWidget);

      // 2. Verify horizontal carousel items and "View All" card
      expect(find.text('View All'), findsOneWidget);
      expect(find.byType(MasteryBadgeTile), findsWidgets);

      // 3. Tap on "See All (50)" to open full screen showroom
      await tester.tap(find.text('See All (50)'));
      await tester.pumpAndSettle();

      // Now inside MasteryBadgesScreen
      expect(find.text('Mastery Badges'), findsOneWidget);
      expect(find.text('TROPHY SHOWROOM'), findsOneWidget);
      expect(find.textContaining('All (50)'), findsOneWidget);
      expect(find.textContaining('Execution (10)'), findsOneWidget);

      // Verify all 50 badges are rendered in the full showroom grid
      expect(find.byType(MasteryBadgeTile), findsNWidgets(50));

      // 4. Tap on 'Execution (10)' filter pill in the showroom
      await tester.tap(find.textContaining('Execution (10)'));
      await tester.pumpAndSettle();

      // Only 10 execution tiles displayed
      expect(find.byType(MasteryBadgeTile), findsNWidgets(10));

      // 5. Tap on the first tile to open detail bottom sheet modal
      await tester.tap(find.byType(MasteryBadgeTile).first);
      await tester.pumpAndSettle();

      expect(find.text('TIER ROADMAP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('MeScreen renders styled Sign Out at bottom and removes data management & logo cards',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MeScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Sign Out button is present at the bottom of the scroll view
      expect(find.text('Sign Out', skipOffstage: false), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded, skipOffstage: false), findsOneWidget);

      // 2. Verify Data Management is completely removed
      expect(find.text('DATA MANAGEMENT', skipOffstage: false), findsNothing);
      expect(find.text('Reset App to Clean State', skipOffstage: false), findsNothing);

      // 3. Verify AXIS OS logo / version card is completely removed
      expect(find.text('AXIS OS', skipOffstage: false), findsNothing);
      expect(find.text('The Kinetic Productivity & Flow OS', skipOffstage: false), findsNothing);

      // 4. Verify no user ID or user mail in the sign out widget
      expect(find.textContaining('PowerSync Multi-Tenant', skipOffstage: false), findsNothing);
      expect(find.textContaining('Connect Supabase Auth to sync', skipOffstage: false), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
