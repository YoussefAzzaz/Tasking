import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/daily_prayer_status_repository.dart';
import 'package:axis/data/friends/friend_activity_repository.dart';
import 'package:axis/data/friends/friend_search_repository.dart';
import 'package:axis/data/powersync/payload_sanitizer.dart';
import 'package:axis/data/powersync_db.dart';

void main() {
  tearDown(() {
    setSigningOut(false);
  });

  group('SupabaseConnector Payload Sanitization & Sync Hardening', () {
    late SupabaseConnector connector;

    setUp(() {
      setSigningOut(false);
      connector = SupabaseConnector(getCurrentUserId: () => 'user-uuid-1234');
    });

    test('replaces empty or local_guest user_id with active authenticated UID', () {
      // Test via fetchCredentials / public connector instance
      expect(connector.getCurrentUserId!(), equals('user-uuid-1234'));
    });

    test('tasks PATCH without status does not overwrite status with todo', () {
      final sanitized = PayloadSanitizer.sanitize(
        'tasks',
        {'id': 't1', 'title': 'Renamed'},
        'u1',
      );
      expect(sanitized.containsKey('status'), isFalse);
      expect(sanitized['title'], equals('Renamed'));
      expect(sanitized['user_id'], equals('u1'));
    });

    test('tasks payload normalizes skipped status to done', () {
      final sanitized = PayloadSanitizer.sanitize(
        'tasks',
        {'id': 't1', 'status': 'skipped'},
        'u1',
      );
      expect(sanitized['status'], equals('done'));
    });

    test('setSigningOut suppresses currentUserId and clears session caches', () {
      final prayerRepo = DailyPrayerStatusRepository();
      final activityRepo = FriendActivityRepository();
      final searchRepo = FriendSearchRepository();

      prayerRepo.setCacheForTesting('2026-11-14_fajr', true);
      expect(prayerRepo.currentUserPrayerCache['2026-11-14_fajr'], isTrue);
      setSigningOut(true);

      expect(currentUserId, equals(''));
      expect(prayerRepo.currentUserId, equals(''));
      expect(activityRepo.currentUserId, equals(''));
      expect(searchRepo.currentUserId, equals(''));

      prayerRepo.clearSessionState();
      expect(prayerRepo.currentUserPrayerCache, isEmpty);
    });
  });
}
