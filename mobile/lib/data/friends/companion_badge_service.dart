import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'friend_models.dart';

/// Dedicated service to evaluate unlocked badges and achievements for companions.
class CompanionBadgeService {
  static final CompanionBadgeService _instance = CompanionBadgeService._();
  factory CompanionBadgeService() => _instance;
  CompanionBadgeService._();

  /// Evaluates completed mastery badges for a companion based on their level, total XP,
  /// prayer streak, and historical completed prayers.
  Future<List<MasteryBadgeData>> getBadgesForCompanion(
    String companionUserId, {
    int level = 1,
    int totalXp = 0,
    int streakDays = 0,
  }) async {
    int prayersCount = 0;
    const int habitLogsCount = 0;

    if (isDatabaseInitialized && companionUserId.isNotEmpty) {
      try {
        final prayerRow = await db.getOptional(
          '''SELECT 
              SUM(fajr + dhuhr + asr + maghrib + isha) AS total_prayers
             FROM daily_prayer_status
             WHERE user_id = ?''',
          [companionUserId],
        );
        prayersCount = parseToInt(prayerRow?['total_prayers']);
      } catch (_) {}
    }

    if (prayersCount == 0 && companionUserId.isNotEmpty) {
      try {
        final client = Supabase.instance.client;
        final res = await client
            .from('daily_prayer_status')
            .select('fajr, dhuhr, asr, maghrib, isha')
            .eq('user_id', companionUserId);
        int sum = 0;
        for (final r in res) {
          if (parseToBool(r['fajr'])) sum++;
          if (parseToBool(r['dhuhr'])) sum++;
          if (parseToBool(r['asr'])) sum++;
          if (parseToBool(r['maghrib'])) sum++;
          if (parseToBool(r['isha'])) sum++;
        }
        if (sum > 0) prayersCount = sum;
      } catch (_) {}
    }

    final metrics = UserProductivityMetrics(
      streakDays: streakDays,
      bestStreakDays: streakDays,
      userLevel: level,
      totalXp: totalXp,
      prayersCompleted: prayersCount,
      habitLogs: habitLogsCount,
      activityLogsCount: prayersCount,
    );

    final allBadges = kMasteryBadgeRegistry.map((def) {
      final value = metrics.getMetricValue(def.metricType);
      return def.evaluate(value);
    }).toList();

    return allBadges.where((b) => b.isUnlocked).toList();
  }
}
