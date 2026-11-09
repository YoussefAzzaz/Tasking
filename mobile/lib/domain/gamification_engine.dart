import 'dart:math';

class LevelProgress {
  final int level;
  final int currentXp;
  final int currentLevelBaseXp;
  final int nextLevelXp;
  final double progress; // 0.0 to 1.0

  const LevelProgress({
    required this.level,
    required this.currentXp,
    required this.currentLevelBaseXp,
    required this.nextLevelXp,
    required this.progress,
  });
}

class GamificationEngine {
  static const int dailyTaskCap = 25;
  static const int dailyFocusEventCap = 120;
  static const int habitCompletionXp = 20;

  /// Calculates authoritative XP for task completion based on priority and timeliness.
  static int taskCompletionXp({int? priority, bool isOnTime = false}) {
    int xp = 5;
    if (priority == 1) {
      xp = 20;
    } else if (priority == 2) {
      xp = 10;
    }
    if (isOnTime) {
      xp += 5;
    }
    return xp;
  }

  static int calculateLevel(int xp) {
    if (xp < 0) return 1;
    double n = (50.0 + sqrt(2500.0 + 200.0 * xp)) / 100.0;
    return n.floor();
  }

  static int xpToReachLevel(int level) {
    if (level < 1) return 0;
    return 50 * level * (level - 1);
  }

  static LevelProgress getLevelProgress(int xp) {
    final clampedXp = max(0, xp);
    final level = calculateLevel(clampedXp);
    final base = xpToReachLevel(level);
    final next = xpToReachLevel(level + 1);
    final span = next - base;
    final progress = span > 0 ? ((clampedXp - base) / span).clamp(0.0, 1.0) : 0.0;
    return LevelProgress(
      level: level,
      currentXp: clampedXp,
      currentLevelBaseXp: base,
      nextLevelXp: next,
      progress: progress,
    );
  }

  static int applyDailyTaskCap(int count) {
    return count.clamp(0, dailyTaskCap);
  }

  static int applyDailyFocusCap(int count) {
    return count.clamp(0, dailyFocusEventCap);
  }
}
