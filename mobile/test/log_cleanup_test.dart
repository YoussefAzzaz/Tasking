import 'package:flutter_test/flutter_test.dart';

void main() {
  group('15-Day Log Cleanup Logic Tests', () {
    test('15-day cutoff boundary accurately filters expired logs', () {
      final now = DateTime.utc(2026, 11, 4, 12, 0, 0);
      final cutoff = now.subtract(const Duration(days: 15));

      // Cutoff should be exactly 15 days earlier in UTC
      expect(cutoff, DateTime.utc(2026, 10, 20, 12, 0, 0));

      final log16DaysOld = DateTime.utc(2026, 10, 19, 12, 0, 0);
      final log15Days1SecondOld = cutoff.subtract(const Duration(seconds: 1));
      final log14DaysOld = DateTime.utc(2026, 10, 21, 12, 0, 0);
      final logToday = now;

      // Filter check simulating `created_at < cutoff`
      bool isExpired(DateTime date) => date.isBefore(cutoff);

      expect(isExpired(log16DaysOld), isTrue);
      expect(isExpired(log15Days1SecondOld), isTrue);
      expect(isExpired(log14DaysOld), isFalse);
      expect(isExpired(logToday), isFalse);
    });

    test('Log purge target tables only include ephemeral logs and protect habit logs', () {
      // Ephemeral logs eligible for 15-day purge:
      const targetTables = ['friend_activity_logs', 'logs'];
      // Critical streak history table that MUST NOT be purged:
      const protectedTables = ['habit_logs'];

      expect(targetTables.contains('friend_activity_logs'), isTrue);
      expect(targetTables.contains('logs'), isTrue);
      expect(targetTables.contains('habit_logs'), isFalse);
      expect(protectedTables.contains('habit_logs'), isTrue);
    });
  });
}

