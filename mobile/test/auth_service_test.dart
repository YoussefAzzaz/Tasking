import 'package:flutter_test/flutter_test.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/project_repository.dart';

void main() {
  group('AuthService & Multi-User Integration Tests', () {
    test('AuthService returns singleton instance', () {
      final a1 = AuthService();
      final a2 = AuthService();
      expect(identical(a1, a2), isTrue);
    });

    test('displayName resolves clean fallback when user is unauthenticated', () {
      final auth = AuthService();
      expect(auth.displayName, isNotEmpty);
      expect(auth.displayName, equals('Operative'));
    });

    test('Task model incorporates userId and toRow includes user_id', () {
      final task = Task(
        id: 'task_test_123',
        userId: 'usr_7f8a9b',
        title: 'Complete Supabase Integration',
        priority: 1,
      );

      expect(task.userId, equals('usr_7f8a9b'));
      final row = task.toRow();
      expect(row['id'], equals('task_test_123'));
      expect(row['user_id'], equals('usr_7f8a9b'));
      expect(row['title'], equals('Complete Supabase Integration'));
    });

    test('Project model incorporates userId and toRow includes user_id', () {
      final project = Project(
        id: 'proj_test_456',
        userId: 'usr_7f8a9b',
        name: 'Work Project',
        color: '#6366F1',
      );

      expect(project.userId, equals('usr_7f8a9b'));
      final row = project.toRow();
      expect(row['id'], equals('proj_test_456'));
      expect(row['user_id'], equals('usr_7f8a9b'));
      expect(row['name'], equals('Work Project'));
    });

    test('Task model defaults user_id to currentUserId when null', () {
      setCachedUserId('usr_active_cached');
      final task = Task(
        id: 'task_null_user',
        title: 'Task without explicit user',
      );
      final row = task.toRow();
      expect(row['user_id'], equals('usr_active_cached'));
    });

    test('Project model defaults user_id to currentUserId when null', () {
      setCachedUserId('usr_active_cached');
      final proj = Project(
        id: 'proj_null_user',
        name: 'Project without explicit user',
      );
      final row = proj.toRow();
      expect(row['user_id'], equals('usr_active_cached'));
    });

    test('signOut completes cleanly without throwing even when unauthenticated or offline', () async {
      final auth = AuthService();
      await expectLater(auth.signOut(), completes);
    });

    test('saveLocalSession persists offline session and clearLocalSession removes it', () async {
      final auth = AuthService();
      await auth.saveLocalSession(
        userId: 'test_user_offline_uuid',
        email: 'operative@tasking.local',
        displayName: 'Offline Operative',
      );

      expect(auth.hasActiveSession, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.isGuest, isFalse);
      expect(auth.currentUserId, equals('test_user_offline_uuid'));
      expect(auth.userEmail, equals('operative@tasking.local'));
      expect(auth.displayName, equals('Offline Operative'));

      await auth.clearLocalSession();
      expect(auth.hasActiveSession, isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.isGuest, isFalse);
    });

    test('Guest session properly isolates isGuest and isAuthenticated', () async {
      final auth = AuthService();
      await auth.saveLocalSession(
        userId: 'local_guest',
        email: 'guest@tasking.local',
        displayName: 'Guest Operative',
      );

      expect(auth.hasActiveSession, isTrue);
      expect(auth.isGuest, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.currentUserId, equals('local_guest'));

      await auth.clearLocalSession();
      expect(auth.hasActiveSession, isFalse);
      expect(auth.isGuest, isFalse);
      expect(auth.isAuthenticated, isFalse);
    });
  });
}
