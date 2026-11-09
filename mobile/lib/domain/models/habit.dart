import 'package:axis/data/habits/habit_state_manager.dart';

/// Domain model representing a user habit.
class Habit {
  final String id;
  final String name;
  final String category;
  final String icon;
  final String color;
  final String scheduleType;
  final String? remindTime;
  final int targetValue; // XP reward
  final bool isDoneToday;
  final int streakDays;
  final int sortOrder;
  final bool isEnabled;
  final String? createdAt;

  Habit({
    required this.id,
    required this.name,
    this.category = '',
    this.icon = 'fitness',
    this.color = '#10B981',
    this.scheduleType = 'daily',
    this.remindTime,
    this.targetValue = 20,
    this.isDoneToday = false,
    this.streakDays = 0,
    this.sortOrder = 999,
    this.isEnabled = true,
    this.createdAt,
  });

  Habit copyWith({
    String? id,
    String? name,
    String? category,
    String? icon,
    String? color,
    String? scheduleType,
    String? remindTime,
    int? targetValue,
    bool? isDoneToday,
    int? streakDays,
    int? sortOrder,
    bool? isEnabled,
    String? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      scheduleType: scheduleType ?? this.scheduleType,
      remindTime: remindTime ?? this.remindTime,
      targetValue: targetValue ?? this.targetValue,
      isDoneToday: isDoneToday ?? this.isDoneToday,
      streakDays: streakDays ?? this.streakDays,
      sortOrder: sortOrder ?? this.sortOrder,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Habit.fromRow(
    Map<String, dynamic> row, {
    bool isDone = false,
    int streak = 0,
  }) {
    String cat = (row['kind'] as String?)?.trim() ?? '';
    if (cat.toLowerCase() == 'boolean' || cat.toLowerCase() == 'numeric') {
      cat = '';
    }
    if (cat.isEmpty) {
      final icon = (row['icon'] as String?) ?? '';
      if (icon == 'mosque' ||
          icon == 'prayer' ||
          icon == 'fajr' ||
          icon == 'dhuhr' ||
          icon == 'asr' ||
          icon == 'maghrib' ||
          icon == 'isha') {
        cat = 'Prayers';
      }
    }

    final id = row['id'] as String;
    final bool isEnabled;
    if (HabitStateManager.isHabitPaused(id)) {
      isEnabled = false;
    } else {
      final rawEnabled = row['is_enabled'];
      isEnabled = rawEnabled == null ||
          rawEnabled == 1 ||
          rawEnabled == true ||
          rawEnabled == '1' ||
          rawEnabled == 'true';
    }

    return Habit(
      id: id,
      name: row['name'] as String,
      category: cat,
      icon: (row['icon'] as String?) ?? 'fitness',
      color: (row['color'] as String?) ?? '#10B981',
      scheduleType: (row['schedule_type'] as String?) ?? 'daily',
      remindTime: row['remind_time'] as String?,
      targetValue: (row['target_value'] as num?)?.toInt() ?? 20,
      isDoneToday: isDone,
      streakDays: streak,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 999,
      isEnabled: isEnabled,
      createdAt: row['created_at'] as String?,
    );
  }
}
