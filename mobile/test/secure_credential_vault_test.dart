import 'package:flutter_test/flutter_test.dart';
import 'package:axis/core/security/secure_credential_vault.dart';

void main() {
  group('SecureCredentialVault Unit Tests', () {
    const testPassword = 'SecretP@ssw0rd!2026';

    test('hashPassword produces consistent SHA-256 salted hash', () {
      final hash1 = SecureCredentialVault.hashPassword(testPassword);
      final hash2 = SecureCredentialVault.hashPassword(testPassword);
      final hashOther = SecureCredentialVault.hashPassword('OtherPassword');

      expect(hash1, isNotEmpty);
      expect(hash1.length, equals(64)); // SHA-256 hex string length
      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hashOther)));
    });

    test('verifyPassword correctly matches valid and invalid passwords', () {
      final hash = SecureCredentialVault.hashPassword(testPassword);

      expect(SecureCredentialVault.verifyPassword(testPassword, hash), isTrue);
      expect(SecureCredentialVault.verifyPassword('WrongPassword', hash), isFalse);
      expect(SecureCredentialVault.verifyPassword('', hash), isFalse);
    });

    test('encryptPassword and decryptPassword roundtrip successfully', () {
      final encrypted = SecureCredentialVault.encryptPassword(testPassword);

      expect(encrypted, isNotEmpty);
      expect(encrypted.contains(':'), isTrue);
      expect(encrypted, isNot(contains(testPassword))); // Plaintext must not be present

      final decrypted = SecureCredentialVault.decryptPassword(encrypted);
      expect(decrypted, equals(testPassword));
    });

    test('encryptPassword produces distinct ciphertexts (random IVs) for same password', () {
      final enc1 = SecureCredentialVault.encryptPassword(testPassword);
      final enc2 = SecureCredentialVault.encryptPassword(testPassword);

      expect(enc1, isNot(equals(enc2))); // Different IVs
      expect(SecureCredentialVault.decryptPassword(enc1), equals(testPassword));
      expect(SecureCredentialVault.decryptPassword(enc2), equals(testPassword));
    });

    test('decryptPassword handles corrupt or invalid ciphertext safely without crash', () {
      expect(SecureCredentialVault.decryptPassword('invalid_format'), isNull);
      expect(SecureCredentialVault.decryptPassword('bad_iv:bad_cipher'), isNull);
      expect(SecureCredentialVault.decryptPassword(''), isNull);
    });
  });
}
