import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/domain/filter_engine.dart';
import 'package:axis/domain/streak_engine.dart';
import 'package:axis/domain/gamification_engine.dart';

void main() {
  test('FilterEngine matches contract vectors', () {
    final file = File('../contract/filters.json');
    final data = jsonDecode(file.readAsStringSync());
    final vectors = data['vectors'] as List<dynamic>;

    for (var vector in vectors) {
      var t = vector['task'];
      var task = FilterTask(
        t['id'], 
        t['priority'], 
        t['tags'] != null ? List<String>.from(t['tags']) : null, 
        t['due_date']
      );

      var q = vector['query'];
      var query = FilterQuery(
        q['priority'] != null ? List<int>.from(q['priority']) : null,
        q['tags'] != null ? List<String>.from(q['tags']) : null,
        q['due_before']
      );

      var match = FilterEngine.matches(task, query);
      expect(match, vector['expected_match']);
    }
  });

  test('StreakEngine matches contract vectors', () {
    final file = File('../contract/streaks.json');
    final data = jsonDecode(file.readAsStringSync());
    final vectors = data['vectors'] as List<dynamic>;

    for (var vector in vectors) {
      var logs = (vector['logs'] as List).map((l) => StreakLog(l['date'], l['status'])).toList();
      var streak = StreakEngine.calculateStreak(
        vector['schedule_type'],
        logs,
        vector['current_date']
      );

      expect(streak, vector['expected_streak']);
    }
  });

  test('GamificationEngine matches contract vectors', () {
    final file = File('../contract/xp.json');
    final data = jsonDecode(file.readAsStringSync());
    final vectors = data['vectors'] as List<dynamic>;

    for (var vector in vectors) {
      if (vector['current_xp'] != null) {
        expect(GamificationEngine.calculateLevel(vector['current_xp']), vector['expected_level']);
      }

      if (vector['daily_tasks_done'] != null) {
        expect(GamificationEngine.applyDailyTaskCap(vector['daily_tasks_done']), vector['expected_tasks_counted']);
      }

      if (vector['daily_focus_sessions'] != null) {
        expect(GamificationEngine.applyDailyFocusCap(vector['daily_focus_sessions']), vector['expected_focus_counted']);
      }
    }
  });

  test('StreakEngine returns 0 when logs are reset/empty', () {
    final streak = StreakEngine.calculateStreak('daily', [], '2026-10-20');
    expect(streak, 0);
  });
}
