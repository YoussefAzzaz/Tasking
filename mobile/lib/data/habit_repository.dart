import 'package:intl/intl.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/domain/id_generator.dart';
import 'package:axis/data/app_widget_sync_service.dart';

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

  Habit({
    required this.id,
    required this.name,
    this.category = 'Workout',
    this.icon = 'fitness',
    this.color = '#10B981',
    this.scheduleType = 'daily',
    this.remindTime,
    this.targetValue = 20,
    this.isDoneToday = false,
    this.streakDays = 0,
    this.sortOrder = 999,
  });

  factory Habit.fromRow(Map<String, dynamic> row, {bool isDone = false, int streak = 0}) {
    String cat = (row['kind'] as String?)?.trim() ?? '';
    if (cat.isEmpty) {
      final icon = (row['icon'] as String?) ?? '';
      if (icon == 'book') {
        cat = 'Reading';
      } else if (icon == 'meditation') {
        cat = 'Mindful';
      } else if (icon == 'water') {
        cat = 'Hydrate';
      } else if (icon == 'code') {
        cat = 'Code';
      } else if (icon == 'sleep') {
        cat = 'Rest';
      } else if (icon == 'mosque' ||
          icon == 'prayer' ||
          icon == 'fajr' ||
          icon == 'dhuhr' ||
          icon == 'asr' ||
          icon == 'maghrib' ||
          icon == 'isha') {
        cat = 'Prayers';
      } else {
        cat = 'Workout';
      }
    }

    return Habit(
      id: row['id'] as String,
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
    );
  }
}

class HabitRepository {
  String _todayStr() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Stream<List<Habit>> watchHabits() {
    final today = _todayStr();

    return db
        .watch(
          'SELECT habits.*, habit_logs.status AS today_status '
          'FROM habits '
          'LEFT JOIN habit_logs ON habits.id = habit_logs.habit_id AND habit_logs.log_date = ? '
          'ORDER BY COALESCE(habits.sort_order, 999) ASC, habits.created_at ASC',
          parameters: [today],
        )
        .asyncMap((habitRows) async {
      final doneSet = <String>{};
      for (final row in habitRows) {
        if (row['today_status'] == 'done') {
          doneSet.add(row['id'] as String);
        }
      }

      final allDoneLogs = await db.getAll(
        'SELECT habit_id, COUNT(*) as streak FROM habit_logs WHERE status = ? GROUP BY habit_id',
        ['done'],
      );
      final streakMap = <String, int>{};
      for (final row in allDoneLogs) {
        streakMap[row['habit_id'] as String] =
            (row['streak'] as num?)?.toInt() ?? 0;
      }

      return habitRows.map((row) {
        final id = row['id'] as String;
        return Habit.fromRow(
          row,
          isDone: doneSet.contains(id),
          streak: streakMap[id] ?? 0,
        );
      }).toList();
    });
  }

  Future<void> resetAllStreaks() async {
    await db.execute('DELETE FROM habit_logs');
    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> addHabit(Habit habit) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.execute('''
      INSERT INTO habits (
        id, name, kind, icon, color, schedule_type, remind_time, target_value, sort_order, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      habit.id,
      habit.name,
      habit.category,
      habit.icon,
      habit.color,
      habit.scheduleType,
      habit.remindTime,
      habit.targetValue,
      habit.sortOrder,
      now,
      now,
    ]);
    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> updateHabit(Habit habit) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.execute('''
      UPDATE habits SET
        name = ?, kind = ?, icon = ?, color = ?, schedule_type = ?, remind_time = ?, target_value = ?, sort_order = ?, updated_at = ?
      WHERE id = ?
    ''', [
      habit.name,
      habit.category,
      habit.icon,
      habit.color,
      habit.scheduleType,
      habit.remindTime,
      habit.targetValue,
      habit.sortOrder,
      now,
      habit.id,
    ]);
    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> toggleHabit(String habitId, bool done) async {
    final today = _todayStr();
    final now = DateTime.now().toUtc().toIso8601String();
    final logEventId = IdGenerator.generateDeterministicId('xpevent_${habitId}_$today');

    if (done) {
      final logId = IdGenerator.generateDeterministicId('habitlog_${habitId}_$today');
      await db.execute('''
        INSERT OR REPLACE INTO habit_logs (
          id, habit_id, log_date, status, value, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [logId, habitId, today, 'done', 1, now, now]);

      // Award XP
      try {
        await db.execute('''
          INSERT OR REPLACE INTO logs (
            id, task_id, event_type, xp_earned, timestamp
          ) VALUES (?, ?, ?, ?, ?)
        ''', [logEventId, habitId, 'habit_completed', 20, now]);
      } catch (_) {}
    } else {
      await db.execute('''
        DELETE FROM habit_logs WHERE habit_id = ? AND log_date = ?
      ''', [habitId, today]);

      // Remove XP log when habit is unchecked
      try {
        await db.execute('''
          DELETE FROM logs WHERE id = ? OR (task_id = ? AND event_type = 'habit_completed' AND timestamp LIKE ?)
        ''', [logEventId, habitId, '$today%']);
      } catch (_) {}
    }

    try {
      await syncGlobalUserLevel();
    } catch (_) {}

    AppWidgetSyncService().syncHabitStreak();
  }

  Future<void> deleteHabit(String habitId) async {
    await db.execute('DELETE FROM habit_logs WHERE habit_id = ?', [habitId]);
    await db.execute('DELETE FROM habits WHERE id = ?', [habitId]);
    AppWidgetSyncService().syncHabitStreak();
  }
}
