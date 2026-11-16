import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Secure credential vault providing AES-256-CBC encryption and salted SHA-256 hashing.
/// Protects cached user passwords at rest so credentials cannot be read if SQLite is dumped.
class SecureCredentialVault {
  static const String _appSalt = 'AXIS_OBSIDIAN_VAULT_2026_KINETIC_SALT';

  /// Generates a salted SHA-256 cryptographic hash of the plain password.
  /// Used for verification without exposing the plaintext password.
  static String hashPassword(String password) {
    final saltedBytes = utf8.encode('$password:$_appSalt');
    return sha256.convert(saltedBytes).toString();
  }

  /// Verifies a plain password against a stored SHA-256 hash.
  static bool verifyPassword(String password, String storedHash) {
    if (storedHash.isEmpty) return false;
    final computed = hashPassword(password);
    return computed == storedHash;
  }

  /// Derives a 256-bit (32 byte) AES key from the master salt and app context.
  static Uint8List _deriveKey() {
    final keyBytes = sha256.convert(utf8.encode('AXIS_ENCRYPTION_KEY_SEED:$_appSalt')).bytes;
    return Uint8List.fromList(keyBytes);
  }

  /// Encrypts a password with AES-256-CBC with PKCS7 padding.
  /// Returns a Base64-encoded string in the format: `<iv_base64>:<ciphertext_base64>`
  static String encryptPassword(String password) {
    if (password.isEmpty) return '';

    final key = _deriveKey();
    // 16-byte random IV
    final rnd = Random.secure();
    final iv = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      iv[i] = rnd.nextInt(256);
    }

    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    final params = PaddedBlockCipherParameters(
      ParametersWithIV(KeyParameter(key), iv),
      null,
    );
    cipher.init(true, params);

    final inputBytes = Uint8List.fromList(utf8.encode(password));
    final encryptedBytes = cipher.process(inputBytes);

    final ivBase64 = base64Encode(iv);
    final cipherBase64 = base64Encode(encryptedBytes);

    return '$ivBase64:$cipherBase64';
  }

  /// Decrypts a password that was encrypted with [encryptPassword].
  /// Returns the original plain password, or null if decryption fails.
  static String? decryptPassword(String encryptedData) {
    if (encryptedData.isEmpty || !encryptedData.contains(':')) return null;

    try {
      final parts = encryptedData.split(':');
      if (parts.length != 2) return null;

      final iv = base64Decode(parts[0]);
      final cipherText = base64Decode(parts[1]);
      final key = _deriveKey();

      final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
      final params = PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), iv),
        null,
      );
      cipher.init(false, params);

      final decryptedBytes = cipher.process(cipherText);
      return utf8.decode(decryptedBytes);
    } catch (_) {
      return null;
    }
  }
}
