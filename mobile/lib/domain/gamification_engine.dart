import 'dart:math';

class GamificationEngine {
  static const int dailyTaskCap = 25;
  static const int dailyFocusEventCap = 120;

  static int calculateLevel(int xp) {
    if (xp < 0) return 1;
    double n = (50.0 + sqrt(2500.0 + 200.0 * xp)) / 100.0;
    return n.floor();
  }

  static int xpToReachLevel(int level) {
    if (level < 1) return 0;
    return 50 * level * (level - 1);
  }

  static int applyDailyTaskCap(int count) {
    return min(count, dailyTaskCap);
  }

  static int applyDailyFocusCap(int count) {
    return min(count, dailyFocusEventCap);
  }
}
