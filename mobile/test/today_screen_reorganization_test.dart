import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/badges/badge_models.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/stats_repository.dart';
import 'package:axis/ui/me/me_screen.dart';
import 'package:axis/ui/today/today_screen.dart';

class _FakeTaskRepository extends TaskRepository {
  final _controller = StreamController<List<Task>>.broadcast();
  @override
  Stream<List<Task>> watchTasks({int? limit, int? offset}) => _controller.stream;
  void emit(List<Task> tasks) => _controller.add(tasks);
  void dispose() => _controller.close();
}

class _FakeStatsRepository implements StatsRepository {
  final _controller = StreamController<UserStats>.broadcast();
  @override
  Stream<UserStats> watchStats() => _controller.stream;
  @override
  Future<UserStats> getUserStats({bool forceRefresh = false}) async {
    return const UserStats(
      totalXp: 1250,
      todayXp: 150,
      streakDays: 5,
      level: 4,
    );
  }
  @override
  void invalidateStats() {}
  @override
  void updateOptimistic(UserStats stats) {}
  void dispose() => _controller.close();
}

void main() {
  group('TodayScreen Layout Reorganization & Milestones Tests', () {
    testWidgets('NextMilestonesCard renders milestones, badges, and progress bars', (tester) async {
      MasteryBadgeData? tappedBadge;

      final testBadges = [
        const MasteryBadgeData(
          id: 'closer',
          title: 'The Closer II',
          category: 'Execution',
          icon: Icons.task_alt_rounded,
          color: AxisColors.success,
          currentValue: 35,
          tiers: [
            BadgeTier(tierNumber: 1, name: 'Closer I', targetValue: 50, unit: 'tasks', description: ''),
          ],
        ),
        const MasteryBadgeData(
          id: 'flow',
          title: 'Flow Sentinel',
          category: 'Focus',
          icon: Icons.timelapse_rounded,
          color: AxisColors.secondary,
          currentValue: 12,
          tiers: [
            BadgeTier(tierNumber: 1, name: 'Flow I', targetValue: 20, unit: 'sessions', description: ''),
          ],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: NextMilestonesCard(
                spotlightBadges: testBadges,
                onTapBadge: (badge) => tappedBadge = badge,
              ),
            ),
          ),
        ),
      );

      // Verify title and badges
      expect(find.text('NEXT MILESTONES IN REACH'), findsOneWidget);
      expect(find.text('The Closer II'), findsOneWidget);
      expect(find.text('Flow Sentinel'), findsOneWidget);
      expect(find.text('70%'), findsOneWidget);
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('35 / 50 tasks'), findsOneWidget);
      expect(find.text('12 / 20 sessions'), findsOneWidget);

      // Tap on first milestone
      await tester.tap(find.text('The Closer II'));
      await tester.pumpAndSettle();

      expect(tappedBadge?.id, equals('closer'));
    });

    testWidgets('MeScreen no longer renders NEXT MILESTONES IN REACH', (tester) async {
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

      expect(find.text('NEXT MILESTONES IN REACH'), findsNothing);
    });

    testWidgets('TodayScreen does NOT render redundant sync status pill', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeTasks = _FakeTaskRepository();
      final fakeStats = _FakeStatsRepository();
      addTearDown(() {
        fakeTasks.dispose();
        fakeStats.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AxisTheme.dark,
          home: Scaffold(
            body: TodayScreen(
              taskRepo: fakeTasks,
              statsRepo: fakeStats,
            ),
          ),
        ),
      );

      fakeTasks.emit([]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify redundant sync status widgets are completely removed
      expect(find.text('• CLOUD SYNCED'), findsNothing);
      expect(find.text('• LOCAL SQLITE'), findsNothing);
      expect(find.text('PowerSync Active'), findsNothing);
      expect(find.text('Offline Ready'), findsNothing);

      // Verify Priority Matrix is rendered high up
      expect(find.text('PRIORITY MATRIX'), findsOneWidget);

      // Verify Next Milestones Card is present on TodayScreen
      expect(find.byType(NextMilestonesCard), findsOneWidget);
    });
  });
}
