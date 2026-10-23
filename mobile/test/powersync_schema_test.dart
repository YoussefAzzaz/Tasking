import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/powersync/app_schema.dart';

void main() {
  group('PowerSync appSchema and Table Indexes Verification', () {
    test('appSchema defines all core tables with proper indexes', () {
      final tableMap = {for (final t in appSchema.tables) t.name: t};

      // Verify essential tables exist
      expect(tableMap.containsKey('tasks'), isTrue);
      expect(tableMap.containsKey('projects'), isTrue);
      expect(tableMap.containsKey('tags'), isTrue);
      expect(tableMap.containsKey('logs'), isTrue);
      expect(tableMap.containsKey('habits'), isTrue);
      expect(tableMap.containsKey('habit_logs'), isTrue);
      expect(tableMap.containsKey('notes'), isTrue);
      expect(tableMap.containsKey('focus_sessions'), isTrue);
      expect(tableMap.containsKey('habit_categories'), isTrue);
      expect(tableMap.containsKey('prayers'), isTrue);
      expect(tableMap.containsKey('user_profiles'), isTrue);

      // Verify tasks table indexes
      final taskTable = tableMap['tasks']!;
      final taskIndexNames = taskTable.indexes.map((idx) => idx.name).toSet();
      expect(taskIndexNames.contains('user_id'), isTrue);
      expect(taskIndexNames.contains('due_date'), isTrue);
      expect(taskIndexNames.contains('status_due'), isTrue);
      expect(taskIndexNames.contains('project'), isTrue);
      expect(taskIndexNames.contains('user_status'), isTrue);
      expect(taskIndexNames.contains('user_status_priority'), isTrue);

      // Verify prayers table indexes
      final prayersTable = tableMap['prayers']!;
      final prayerIndexNames = prayersTable.indexes.map((idx) => idx.name).toSet();
      expect(prayerIndexNames.contains('user_id'), isTrue);
      expect(prayerIndexNames.contains('user_sort'), isTrue);
      expect(prayerIndexNames.contains('user_done'), isTrue);

      // Verify habit_logs table indexes
      final habitLogsTable = tableMap['habit_logs']!;
      final habitLogsIndexNames = habitLogsTable.indexes.map((idx) => idx.name).toSet();
      expect(habitLogsIndexNames.contains('user_id'), isTrue);
      expect(habitLogsIndexNames.contains('habit_date'), isTrue);
      expect(habitLogsIndexNames.contains('date_status'), isTrue);
    });
  });
}
