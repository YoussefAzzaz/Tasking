import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/core/security/secure_credential_vault.dart';
import 'package:axis/core/storage/axis_storage.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/ui/auth/auth_screen.dart';
import 'package:axis/ui/shell/session_expired_banner.dart';
import 'package:axis/ui/shell/axis_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Token Expiration & Secure Credential Vault Integration Tests', () {
    final auth = AuthService();
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('axis_auth_test_');
      AxisStorage.resetForTesting();
      AxisStorage.debugOverrideRootPath = tempDir.path;
      auth.sessionExpiredNotifier.value = false;
      auth.sessionExpiredDismissedNotifier.value = false;
      NetworkService().isOnlineNotifier.value = true;
    });

    tearDown(() async {
      await auth.clearSavedCredentials(forgetAccount: true);
      await auth.clearLocalSession();
      AxisStorage.resetForTesting();
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } catch (_) {}
    });

    test('SecureCredentialVault hashes with salt and encrypts password safely', () {
      const rawPassword = 'SuperSecretPassword123!';
      final hash = SecureCredentialVault.hashPassword(rawPassword);
      final encrypted = SecureCredentialVault.encryptPassword(rawPassword);

      expect(hash, isNotEmpty);
      expect(encrypted, isNotEmpty);
      expect(encrypted, isNot(contains(rawPassword)));
      expect(hash, isNot(contains(rawPassword)));

      // Hashing integrity check
      expect(SecureCredentialVault.verifyPassword(rawPassword, hash), isTrue);
      expect(SecureCredentialVault.verifyPassword('WrongPassword', hash), isFalse);

      // Decryption integrity check
      final decrypted = SecureCredentialVault.decryptPassword(encrypted);
      expect(decrypted, equals(rawPassword));
    });

    test('Error classifier separates offline/network errors from permanent auth rejections', () {
      // Network / transient errors must NEVER be classified as permanent auth errors
      expect(
        AuthService.isNetworkOrRetryableError(const SocketException('Failed host lookup')),
        isTrue,
      );
      expect(
        AuthService.isPermanentAuthError(const SocketException('Failed host lookup')),
        isFalse,
      );
      expect(
        AuthService.isNetworkOrRetryableError(TimeoutException('timed out')),
        isTrue,
      );
      expect(
        AuthService.isPermanentAuthError(TimeoutException('timed out')),
        isFalse,
      );
      expect(
        AuthService.isNetworkOrRetryableError(AuthRetryableFetchException(message: 'Network error')),
        isTrue,
      );
      expect(
        AuthService.isPermanentAuthError(AuthRetryableFetchException(message: 'Network error')),
        isFalse,
      );
      expect(
        AuthService.isPermanentAuthError(
          const AuthException('Bad Gateway', statusCode: '502'),
        ),
        isFalse,
      );

      // Permanent server rejections MUST be classified as permanent auth errors
      expect(
        AuthService.isPermanentAuthError(
          const AuthApiException(
            'Invalid Refresh Token: Refresh Token Not Found',
            statusCode: '400',
            code: 'refresh_token_not_found',
          ),
        ),
        isTrue,
      );
      expect(
        AuthService.isPermanentAuthError(
          const AuthException('Unauthorized', statusCode: '401'),
        ),
        isTrue,
      );
    });

    test('handleSessionExpired is suppressed offline and preserves local session online', () async {
      await auth.saveLocalSession(
        userId: 'usr_offline_safe',
        email: 'offline@tasking.local',
        displayName: 'Offline User',
        plainPassword: 'Password123!',
      );

      // While OFFLINE, handleSessionExpired must NEVER trigger session expired
      NetworkService().isOnlineNotifier.value = false;
      await auth.handleSessionExpired(reason: 'Simulated offline error');
      expect(auth.isSessionExpired, isFalse);
      expect(auth.currentUserId, equals('usr_offline_safe'));

      // Stale epoch must be ignored even online
      NetworkService().isOnlineNotifier.value = true;
      await auth.handleSessionExpired(
        reason: 'Stale background task',
        expectedEpoch: auth.authEpoch - 1,
      );
      expect(auth.isSessionExpired, isFalse);

      // Valid online expiry sets sessionExpiredNotifier while preserving local offline identity
      await auth.handleSessionExpired(
        reason: 'Confirmed server rejection',
        expectedEpoch: auth.authEpoch,
      );
      expect(auth.isSessionExpired, isTrue);
      expect(auth.currentUserId, equals('usr_offline_safe'));
      expect(auth.savedEmail, equals('offline@tasking.local'));
    });

    test('AuthService saves encrypted password and password hash into session cache', () async {
      await auth.saveLocalSession(
        userId: 'usr_test_123',
        email: 'operative@tasking.local',
        displayName: 'Test Operative',
        plainPassword: 'SecretAccessKey456',
      );

      expect(auth.hasSavedCredentials, isTrue);
      expect(auth.savedEmail, equals('operative@tasking.local'));
      expect(auth.storedPasswordHash, isNotNull);
      expect(auth.storedPasswordHash, isNot(contains('SecretAccessKey456')));

      // Password should be retrievable decrypted only by the authorized vault
      final decrypted = auth.getDecryptedPassword();
      expect(decrypted, equals('SecretAccessKey456'));

      // Raw password must never be exposed directly in plain session map
      final sessionMap = auth.lastSavedSession;
      expect(sessionMap?['password'], isNull);
      expect(sessionMap?['plain_password'], isNull);
      expect(sessionMap?['encrypted_password'], isNotNull);
      expect(sessionMap?['password_hash'], isNotNull);
    });

    test('signOut preserves persistent credentials and email across sign-out and reloads from disk', () async {
      await auth.saveLocalSession(
        userId: 'usr_persist_1',
        email: 'persist@tasking.local',
        displayName: 'Persist Operative',
        plainPassword: 'MyPassword99!',
      );

      await auth.signOut();

      // Active session is cleared, but persistent credentials remain ready for login screen
      expect(auth.hasActiveSession, isFalse);
      expect(auth.isSessionExpired, isFalse);
      expect(auth.savedEmail, equals('persist@tasking.local'));
      expect(auth.hasSavedCredentials, isTrue);
      expect(auth.getDecryptedPassword(), equals('MyPassword99!'));

      // Force reload from disk confirms file was flushed before signOut
      final loaded = await auth.loadPersistentCredentials(forceReload: true);
      expect(loaded?['email'], equals('persist@tasking.local'));
      expect(auth.getDecryptedPassword(), equals('MyPassword99!'));

      // Guest session must NEVER overwrite saved real credentials
      await auth.saveLocalSession(
        userId: 'local_guest',
        email: 'guest@tasking.local',
        displayName: 'Guest Operative',
      );
      expect(auth.savedEmail, equals('persist@tasking.local'));
    });

    test('signOut preserves email even when password was never saved', () async {
      await auth.saveLocalSession(
        userId: 'usr_email_only',
        email: 'emailonly@tasking.local',
        displayName: 'Email Only',
      );

      await auth.signOut();
      expect(auth.savedEmail, equals('emailonly@tasking.local'));
      expect(auth.hasSavedCredentials, isFalse);

      final loaded = await auth.loadPersistentCredentials(forceReload: true);
      expect(loaded?['email'], equals('emailonly@tasking.local'));
    });

    test('sessionExpiredNotifier switches state correctly', () {
      expect(auth.isSessionExpired, isFalse);
      auth.sessionExpiredNotifier.value = true;
      expect(auth.isSessionExpired, isTrue);
      auth.sessionExpiredNotifier.value = false;
      expect(auth.isSessionExpired, isFalse);
    });

    testWidgets('SessionExpiredBanner renders online, hides offline, and can be dismissed',
        (WidgetTester tester) async {
      auth.sessionExpiredNotifier.value = false;
      NetworkService().isOnlineNotifier.value = true;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SessionExpiredBanner(),
          ),
        ),
      );

      // Should be hidden initially
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.text('SESSION EXPIRED'), findsNothing);

      // Trigger session expiration while online
      auth.sessionExpiredNotifier.value = true;
      await tester.pump();

      // Banner should now be visible with clear call to action, logout, and dismiss
      expect(find.text('SESSION EXPIRED'), findsOneWidget);
      expect(find.text('Work is saved locally. Log in to resume cloud sync.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byKey(const ValueKey('session_expired_logout_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('session_expired_dismiss_button')), findsOneWidget);

      // Going offline hides the banner automatically
      NetworkService().isOnlineNotifier.value = false;
      await tester.pump();
      expect(find.text('SESSION EXPIRED'), findsNothing);

      // Coming back online shows it again until dismissed
      NetworkService().isOnlineNotifier.value = true;
      await tester.pump();
      expect(find.text('SESSION EXPIRED'), findsOneWidget);

      // Tapping dismiss hides the banner cleanly
      await tester.tap(find.byKey(const ValueKey('session_expired_dismiss_button')));
      await tester.pump();
      expect(find.text('SESSION EXPIRED'), findsNothing);
      expect(auth.isSessionExpiredBannerDismissed, isTrue);

      // Reset
      auth.sessionExpiredNotifier.value = false;
      await tester.pump();
      expect(find.text('SESSION EXPIRED'), findsNothing);
    });

    testWidgets('SessionExpiredBanner logout button signs out and navigates to /auth',
        (WidgetTester tester) async {
      await tester.runAsync(() async {
        await auth.saveLocalSession(
          userId: 'usr_banner_logout',
          email: 'banner@tasking.local',
          displayName: 'Banner User',
          plainPassword: 'BannerPassword1!',
        );
      });
      auth.sessionExpiredNotifier.value = true;
      NetworkService().isOnlineNotifier.value = true;

      final testRouter = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(
              body: SessionExpiredBanner(),
            ),
          ),
          GoRoute(
            path: '/auth',
            builder: (context, state) => const Scaffold(
              body: Text('AUTH_ROUTE_REACHED'),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
      await tester.pumpAndSettle();

      expect(find.text('SESSION EXPIRED'), findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const ValueKey('session_expired_logout_button')));
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      expect(find.text('AUTH_ROUTE_REACHED'), findsOneWidget);
      expect(auth.hasActiveSession, isFalse);
      expect(auth.isSessionExpired, isFalse);
      // Saved credentials remain available for immediate re-login
      expect(auth.savedEmail, equals('banner@tasking.local'));
      expect(auth.getDecryptedPassword(), equals('BannerPassword1!'));
    });

    testWidgets('AuthScreen pre-fills saved email and password after signOut',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.runAsync(() async {
        await auth.saveLocalSession(
          userId: 'usr_prefill',
          email: 'prefill@tasking.local',
          displayName: 'Prefill User',
          plainPassword: 'PrefillPass123!',
        );
        await auth.signOut();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AuthScreen(),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
      await tester.pumpAndSettle();

      expect(find.text('prefill@tasking.local'), findsWidgets);
      expect(find.text('QUICK LOGIN'), findsOneWidget);
    });

    testWidgets('AxisHeader displays EXPIRED online and OFFLINE when offline',
        (WidgetTester tester) async {
      auth.sessionExpiredNotifier.value = false;
      NetworkService().isOnlineNotifier.value = true;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AxisHeader(
              onAvatarTap: () {},
            ),
          ),
        ),
      );

      await tester.pump();

      // When token deprecates / expires while online:
      auth.sessionExpiredNotifier.value = true;
      await tester.pump();

      // Must NEVER display SYNCED when session is expired!
      expect(find.text('SYNCED'), findsNothing);
      expect(find.text('EXPIRED'), findsOneWidget);

      // When offline, displays OFFLINE instead of EXPIRED
      NetworkService().isOnlineNotifier.value = false;
      await tester.pump();
      expect(find.text('OFFLINE'), findsOneWidget);
      expect(find.text('EXPIRED'), findsNothing);
    });
  });
}
