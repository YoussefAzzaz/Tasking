import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/domain/id_generator.dart';

void main() {
  test('IdGenerator matches contract vectors', () {
    // Read the contract file
    final file = File('../contract/ids.json');
    final jsonStr = file.readAsStringSync();
    final data = jsonDecode(jsonStr);

    expect(IdGenerator.axisNamespace, data['namespace']);

    final vectors = data['vectors'] as Map<String, dynamic>;
    
    for (var entry in vectors.entries) {
      final vector = entry.value;
      final generated = IdGenerator.generateDeterministicId(vector['name']);
      expect(generated, vector['uuidv5'], reason: 'Failed on ${entry.key}');
    }

    // Test convenience methods
    expect(IdGenerator.getUserSettingsId('user123'), vectors['user_settings']['uuidv5']);
    expect(IdGenerator.getDailyPlanId('2026-10-01'), vectors['daily_plans']['uuidv5']);
    expect(IdGenerator.getJournalEntryId('2026-10-01'), vectors['journal_entries']['uuidv5']);
    expect(IdGenerator.getHabitLogId('habit123', '2026-10-01'), vectors['habit_logs']['uuidv5']);
    expect(IdGenerator.getXpEventId('event456'), vectors['xp_events']['uuidv5']);
    expect(IdGenerator.getBadgeUnlockId('first_task', 'user123'), vectors['badge_unlocks']['uuidv5']);
    expect(IdGenerator.getRecurringTaskInstanceId('123', '2026-10-01'), vectors['recurring_task_instances']['uuidv5']);
  });
}
