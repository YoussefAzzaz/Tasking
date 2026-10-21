import 'package:flutter/material.dart';

/// Productivity categories for badge classification and filtering
enum BadgeCategory {
  all('All', Icons.grid_view_rounded, Color(0xFF6366F1)),
  execution('Execution', Icons.task_alt_rounded, Color(0xFF10B981)),
  focus('Deep Work', Icons.timer_outlined, Color(0xFF38BDF8)),
  consistency('Streaks', Icons.local_fire_department_rounded, Color(0xFFF59E0B)),
  habits('Habits', Icons.repeat_rounded, Color(0xFFEC4899)),
  knowledge('Knowledge', Icons.auto_stories_rounded, Color(0xFFA855F7)),
  systems('Systems', Icons.folder_special_rounded, Color(0xFF06B6D4)),
  evolution('Evolution', Icons.bolt_rounded, Color(0xFFEAB308)),
  mindfulness('Mindfulness', Icons.spa_rounded, Color(0xFF14B8A6));

  final String label;
  final IconData icon;
  final Color color;

  const BadgeCategory(this.label, this.icon, this.color);
}

/// Enumeration of all discrete productivity metrics tracked across SQLite
enum BadgeMetricType {
  // Tasks
  tasksCompleted,
  tasksHighPriority,
  tasksEstimated,
  tasksRecurring,
  tasksScheduled,

  // Focus
  focusMinutes,
  focusSessions,
  focusPomodoro,
  focusMarathon,

  // Streaks
  streakDays,
  bestStreakDays,

  // Habits
  habitLogs,
  habitsCreated,
  habitCategoriesCreated,

  // Notes & Knowledge
  notesCount,
  notesPinned,

  // Organization
  projectsCreated,
  tagsCreated,

  // Player Progression
  userLevel,
  totalXp,

  // Spiritual / Mindfulness & System
  prayersCompleted,
  activityLogsCount,
}

/// A single progressive tier step for an achievement badge (e.g. Tier 1 = Bronze / Initiate)
class BadgeTier {
  final int tierNumber;
  final String name;
  final int targetValue;
  final String unit;
  final String description;

  const BadgeTier({
    required this.tierNumber,
    required this.name,
    required this.targetValue,
    required this.unit,
    required this.description,
  });
}

/// Declarative blueprint defining a badge rule and its milestones.
/// Anyone can add a new badge in one line without modifying SQL or database tables.
class BadgeDefinition {
  final String id;
  final String title;
  final String subtitle;
  final BadgeCategory category;
  final IconData icon;
  final Color color;
  final BadgeMetricType metricType;
  final List<BadgeTier> tiers;

  const BadgeDefinition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.icon,
    required this.color,
    required this.metricType,
    required this.tiers,
  });

  /// Evaluates this definition against a live metrics snapshot to produce a dynamic MasteryBadgeData
  MasteryBadgeData evaluate(int currentValue) {
    return MasteryBadgeData(
      id: id,
      title: title,
      category: category.label,
      categoryEnum: category,
      icon: icon,
      color: color,
      tiers: tiers,
      currentValue: currentValue,
      metricType: metricType,
      subtitle: subtitle,
    );
  }
}

/// Evaluated dynamic badge reflecting the user's live progress, achieved tier, and next milestone.
class MasteryBadgeData {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final BadgeCategory categoryEnum;
  final IconData icon;
  final Color color;
  final List<BadgeTier> tiers;
  final int currentValue;
  final BadgeMetricType metricType;

  const MasteryBadgeData({
    required this.id,
    required this.title,
    required this.category,
    this.categoryEnum = BadgeCategory.all,
    required this.icon,
    required this.color,
    required this.tiers,
    required this.currentValue,
    this.metricType = BadgeMetricType.tasksCompleted,
    this.subtitle = '',
  });

  /// True if the user has achieved at least Tier 1
  bool get isUnlocked => tiers.isNotEmpty && currentValue >= tiers.first.targetValue;

  /// The highest tier currently achieved by the user, or null if not yet unlocked
  BadgeTier? get currentTier {
    BadgeTier? achieved;
    for (final tier in tiers) {
      if (currentValue >= tier.targetValue) {
        achieved = tier;
      }
    }
    return achieved;
  }

  /// The next tier the user is working towards, or null if all tiers achieved
  BadgeTier? get nextTier {
    for (final tier in tiers) {
      if (currentValue < tier.targetValue) {
        return tier;
      }
    }
    return null;
  }

  /// Progress fraction (0.0 to 1.0) towards the next tier, or 1.0 if maxed
  double get progress {
    if (tiers.isEmpty) return 0.0;
    final next = nextTier;
    if (next == null) return 1.0;

    final prevTarget = currentTier?.targetValue ?? 0;
    final range = next.targetValue - prevTarget;
    if (range <= 0) return 1.0;

    final progressInRange = (currentValue - prevTarget).clamp(0, range);
    return progressInRange / range;
  }

  /// Concise status label e.g. "7 / 30 days" or "Max Tier"
  String get progressLabel {
    final next = nextTier;
    if (next == null) return 'Maxed (${tiers.last.name})';
    return '$currentValue / ${next.targetValue} ${next.unit}';
  }
}

/// Immutable DTO containing all user productivity metrics gathered in a single optimized pass
class UserProductivityMetrics {
  final int completedTasks;
  final int highPriorityTasks;
  final int estimatedTasks;
  final int recurringTasks;
  final int scheduledTasks;

  final int totalFocusMinutes;
  final int totalFocusSessions;
  final int pomodoroSessions;
  final int marathonSessions;

  final int streakDays;
  final int bestStreakDays;

  final int habitLogs;
  final int habitsCreated;
  final int habitCategoriesCreated;

  final int notesCount;
  final int notesPinned;

  final int projectsCreated;
  final int tagsCreated;

  final int userLevel;
  final int totalXp;

  final int prayersCompleted;
  final int activityLogsCount;

  const UserProductivityMetrics({
    this.completedTasks = 0,
    this.highPriorityTasks = 0,
    this.estimatedTasks = 0,
    this.recurringTasks = 0,
    this.scheduledTasks = 0,
    this.totalFocusMinutes = 0,
    this.totalFocusSessions = 0,
    this.pomodoroSessions = 0,
    this.marathonSessions = 0,
    this.streakDays = 0,
    this.bestStreakDays = 0,
    this.habitLogs = 0,
    this.habitsCreated = 0,
    this.habitCategoriesCreated = 0,
    this.notesCount = 0,
    this.notesPinned = 0,
    this.projectsCreated = 0,
    this.tagsCreated = 0,
    this.userLevel = 1,
    this.totalXp = 0,
    this.prayersCompleted = 0,
    this.activityLogsCount = 0,
  });

  /// Extracts the metric value corresponding to a given metric type in O(1) time
  int getMetricValue(BadgeMetricType type) {
    switch (type) {
      case BadgeMetricType.tasksCompleted:
        return completedTasks;
      case BadgeMetricType.tasksHighPriority:
        return highPriorityTasks;
      case BadgeMetricType.tasksEstimated:
        return estimatedTasks;
      case BadgeMetricType.tasksRecurring:
        return recurringTasks;
      case BadgeMetricType.tasksScheduled:
        return scheduledTasks;
      case BadgeMetricType.focusMinutes:
        return totalFocusMinutes;
      case BadgeMetricType.focusSessions:
        return totalFocusSessions;
      case BadgeMetricType.focusPomodoro:
        return pomodoroSessions;
      case BadgeMetricType.focusMarathon:
        return marathonSessions;
      case BadgeMetricType.streakDays:
        return streakDays;
      case BadgeMetricType.bestStreakDays:
        return bestStreakDays;
      case BadgeMetricType.habitLogs:
        return habitLogs;
      case BadgeMetricType.habitsCreated:
        return habitsCreated;
      case BadgeMetricType.habitCategoriesCreated:
        return habitCategoriesCreated;
      case BadgeMetricType.notesCount:
        return notesCount;
      case BadgeMetricType.notesPinned:
        return notesPinned;
      case BadgeMetricType.projectsCreated:
        return projectsCreated;
      case BadgeMetricType.tagsCreated:
        return tagsCreated;
      case BadgeMetricType.userLevel:
        return userLevel;
      case BadgeMetricType.totalXp:
        return totalXp;
      case BadgeMetricType.prayersCompleted:
        return prayersCompleted;
      case BadgeMetricType.activityLogsCount:
        return activityLogsCount;
    }
  }
}
