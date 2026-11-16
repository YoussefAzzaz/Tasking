import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/security/secure_credential_vault.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/ui/shell/session_expired_banner.dart';
import 'package:axis/ui/shell/axis_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Token Expiration & Secure Credential Vault Integration Tests', () {
    final auth = AuthService();

    setUp(() {
      auth.sessionExpiredNotifier.value = false;
      NetworkService().isOnlineNotifier.value = true;
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

    test('sessionExpiredNotifier switches state correctly', () {
      expect(auth.isSessionExpired, isFalse);
      auth.sessionExpiredNotifier.value = true;
      expect(auth.isSessionExpired, isTrue);
      auth.sessionExpiredNotifier.value = false;
      expect(auth.isSessionExpired, isFalse);
    });

    testWidgets('SessionExpiredBanner renders when session is expired and hides when not',
        (WidgetTester tester) async {
      auth.sessionExpiredNotifier.value = false;

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

      // Trigger session expiration
      auth.sessionExpiredNotifier.value = true;
      await tester.pump();

      // Banner should now be visible with clear call to action
      expect(find.text('SESSION EXPIRED'), findsOneWidget);
      expect(find.text('Work is saved locally. Log in to resume cloud sync.'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);

      // Reset
      auth.sessionExpiredNotifier.value = false;
      await tester.pump();
      expect(find.text('SESSION EXPIRED'), findsNothing);
    });

    testWidgets('AxisHeader displays EXPIRED instead of SYNCED when token deprecated',
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

      // When token deprecates / expires:
      auth.sessionExpiredNotifier.value = true;
      await tester.pump();

      // Must NEVER display SYNCED when session is expired!
      expect(find.text('SYNCED'), findsNothing);
      expect(find.text('EXPIRED'), findsOneWidget);
    });
  });
}
