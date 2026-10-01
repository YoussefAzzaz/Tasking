import 'package:uuid/uuid.dart';

class IdGenerator {
  static const Uuid _uuid = Uuid();
  static const String axisNamespace = '3f2b8c1e-6d4a-4e7b-9a52-1c8d0f7e4b11';

  static String generateDeterministicId(String name) {
    return _uuid.v5(axisNamespace, name);
  }

  static String getUserSettingsId(String userId) => generateDeterministicId('settings_$userId');
  static String getDailyPlanId(String date) => generateDeterministicId('plan_$date');
  static String getJournalEntryId(String date) => generateDeterministicId('journal_$date');
  static String getHabitLogId(String habitId, String date) => generateDeterministicId('habitlog_${habitId}_$date');
  static String getXpEventId(String eventId) => generateDeterministicId('xp_$eventId');
  static String getBadgeUnlockId(String badgeId, String userId) => generateDeterministicId('badge_${badgeId}_$userId');
  static String getRecurringTaskInstanceId(String taskId, String date) => generateDeterministicId('task_${taskId}_$date');
}
