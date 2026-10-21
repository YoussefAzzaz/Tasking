import 'dart:async';
import 'package:axis/data/badges/badge_models.dart';
import 'package:axis/data/badges/badge_registry.dart';
import 'package:axis/data/badges/user_metrics_service.dart';

export 'package:axis/data/badges/badge_models.dart';
export 'package:axis/data/badges/badge_registry.dart';
export 'package:axis/data/badges/user_metrics_service.dart';

/// Clean orchestrator repository providing dynamic mastery badges evaluated against
/// optimized SQLite metrics.
class MasteryBadgeRepository {
  static final MasteryBadgeRepository _instance = MasteryBadgeRepository._internal();
  factory MasteryBadgeRepository() => _instance;
  MasteryBadgeRepository._internal();

  final UserMetricsService _metricsService = UserMetricsService();

  /// Returns all evaluated badges, optionally filtered by category
  Future<List<MasteryBadgeData>> getMasteryBadges({
    bool forceRefresh = false,
    BadgeCategory category = BadgeCategory.all,
  }) async {
    // 1. Ensure covering indexes exist for optimum query speed
    await _metricsService.ensureCoveringIndexes();

    // 2. Fetch single-pass consolidated metrics snapshot (cached for 60s)
    final metrics = await _metricsService.getMetrics(forceRefresh: forceRefresh);

    // 3. Evaluate all 50 declarative badge definitions in memory (O(1) per badge)
    final allBadges = kMasteryBadgeRegistry.map((def) {
      final value = metrics.getMetricValue(def.metricType);
      return def.evaluate(value);
    }).toList();

    // 4. Filter by category if requested
    if (category == BadgeCategory.all) {
      return allBadges;
    }
    return allBadges.where((b) => b.categoryEnum == category).toList();
  }

  /// Returns up to 3 badges that the user is closest to unlocking / advancing to next tier
  Future<List<MasteryBadgeData>> getSpotlightBadges() async {
    final all = await getMasteryBadges();

    // Badges that have not maxed out yet, sorted descending by progress fraction
    final inProgress = all.where((b) => b.nextTier != null).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));

    if (inProgress.length >= 3) {
      return inProgress.take(3).toList();
    }

    return all.take(3).toList();
  }

  /// Invalidates metric cache (call when user completes tasks, habits, or sessions)
  void invalidateCache() {
    _metricsService.invalidateCache();
  }
}
