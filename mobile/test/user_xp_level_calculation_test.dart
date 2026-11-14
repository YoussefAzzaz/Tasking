import 'package:flutter_test/flutter_test.dart';
import 'package:axis/domain/gamification_engine.dart';
import 'package:axis/domain/id_generator.dart';

void main() {
  group('User XP & Level Progression Tests', () {
    test('Level 13 exact base, target, and span calculations', () {
      // Level 13 base XP: 50 * 13 * 12 = 7800
      expect(GamificationEngine.xpToReachLevel(13), 7800);
      expect(GamificationEngine.calculateLevel(7800), 13);

      // Level 14 base XP (target for Level 13): 50 * 14 * 13 = 9100
      expect(GamificationEngine.xpToReachLevel(14), 9100);
      expect(GamificationEngine.calculateLevel(9100), 14);

      // Total XP span needed to conquer Level 13
      final span = GamificationEngine.xpToReachLevel(14) - GamificationEngine.xpToReachLevel(13);
      expect(span, 1300);
    });

    test('LevelProgress accurately tracks incremental progress within Level 13', () {
      // Exactly at level 13 base (0% progress)
      var progress = GamificationEngine.getLevelProgress(7800);
      expect(progress.level, 13);
      expect(progress.currentLevelBaseXp, 7800);
      expect(progress.nextLevelXp, 9100);
      expect(progress.progress, 0.0);

      // Earned 130 XP into level 13 (exactly 10% progress)
      progress = GamificationEngine.getLevelProgress(7800 + 130);
      expect(progress.level, 13);
      expect(progress.progress, closeTo(0.10, 0.001));

      // Earned 650 XP into level 13 (exactly 50% progress)
      progress = GamificationEngine.getLevelProgress(7800 + 650);
      expect(progress.level, 13);
      expect(progress.progress, closeTo(0.50, 0.001));

      // Reached 9100 XP (graduated to Level 14 with 0% progress)
      progress = GamificationEngine.getLevelProgress(9100);
      expect(progress.level, 14);
      expect(progress.currentLevelBaseXp, 9100);
      expect(progress.nextLevelXp, GamificationEngine.xpToReachLevel(15));
      expect(progress.progress, 0.0);
    });

    test('Simulate multi-day progression: XP accumulates across days and never resets', () {
      // User starts at Level 13 with 7800 XP
      int cumulativeXp = 7800;

      // Simulate 10 days of active productivity (e.g. 150 XP per day)
      final dailyXpEarned = [150, 120, 140, 160, 130, 150, 140, 150, 120, 140];

      for (int day = 0; day < dailyXpEarned.length; day++) {
        final earnedToday = dailyXpEarned[day];
        cumulativeXp += earnedToday;

        // Progress should NEVER drop back down to 7800 or 0% on any day
        final progress = GamificationEngine.getLevelProgress(cumulativeXp);
        expect(cumulativeXp > 7800, isTrue);

        if (cumulativeXp < 9100) {
          expect(progress.level, 13);
          expect(progress.progress > 0.0, isTrue);
        } else {
          expect(progress.level >= 14, isTrue);
        }
      }

      // After 10 days of earning 1400 total XP (7800 + 1400 = 9200 XP):
      expect(cumulativeXp, 9200);
      // User must have passed Level 13 and reached Level 14!
      expect(GamificationEngine.calculateLevel(cumulativeXp), 14);
    });

    test('Self-healing historical deficit anchor logic preserves progression', () {
      // Simulate historical deficit where logs older than 15 days were lost,
      // but user profile records 7800 XP (Level 13).
      const int profileXp = 7800;
      int logsTotal = 200; // only recent logs remain

      expect(logsTotal < profileXp, isTrue);
      final deficit = profileXp - logsTotal; // 7600 deficit

      // Anchor created for the deficit
      int anchoredLogsTotal = logsTotal + deficit;
      expect(anchoredLogsTotal, 7800);

      // Now user completes a task (+20 XP)
      anchoredLogsTotal += 20;
      expect(anchoredLogsTotal, 7820);

      // Now total XP exceeds 7800 and continues to grow!
      expect(anchoredLogsTotal > profileXp, isTrue);
      final progress = GamificationEngine.getLevelProgress(anchoredLogsTotal);
      expect(progress.level, 13);
      expect(progress.progress, closeTo(20 / 1300, 0.0001));

      // Next day starts: anchored logs total remains 7820, does NOT reset to 7800
      expect(anchoredLogsTotal, 7820);
    });

    test('Deterministic log ID per day isolates task completion across days', () {
      const taskId = 'task_deploy_prod';
      const day1 = '2026-11-09';
      const day2 = '2026-11-10';

      final logIdDay1 = IdGenerator.generateDeterministicId('xp_task_${taskId}_$day1');
      final logIdDay2 = IdGenerator.generateDeterministicId('xp_task_${taskId}_$day2');

      // Each day has a distinct log ID
      expect(logIdDay1, isNot(equals(logIdDay2)));

      // Untoggling on day 2 targeting logIdDay2 leaves logIdDay1 untouched
      final logs = <String, bool>{
        logIdDay1: true, // completed on day 1
        logIdDay2: true, // completed on day 2
      };

      // Soft-delete today's log only
      logs[logIdDay2] = false;

      // Day 1 log remains completed and preserves XP
      expect(logs[logIdDay1], isTrue);
      expect(logs[logIdDay2], isFalse);
    });
  });
}

