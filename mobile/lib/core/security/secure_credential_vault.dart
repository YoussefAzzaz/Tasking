import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/export.dart';
import 'package:axis/core/storage/axis_storage.dart';

/// Credential vault protecting cached user credentials with per-installation
/// 256-bit cryptographic material backed by Android Keystore (on Android) or
/// private owner-only storage (on desktop), with legacy v1 migration read support.
class SecureCredentialVault {
  static const MethodChannel _vaultChannel = MethodChannel('com.axis.axis/vault');
  static const String _legacyAppSalt = 'AXIS_OBSIDIAN_VAULT_2026_KINETIC_SALT';

  static Uint8List? _masterKey;
  static Uint8List? _deviceSalt;
  static bool _initialized = false;

  @visibleForTesting
  static void resetForTesting() {
    _masterKey = null;
    _deviceSalt = null;
    _initialized = false;
  }

  static Uint8List _randomBytes(int length) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
  }

  static void _ensureEphemeralKeys() {
    _masterKey ??= _randomBytes(32);
    _deviceSalt ??= _randomBytes(32);
  }

  /// Initializes or loads the installation-unique 256-bit AES key and HMAC salt.
  /// Call once during app startup before AuthService restores persisted sessions.
  static Future<void> init() async {
    if (_initialized && _masterKey != null && _deviceSalt != null) return;

    // 1. On Android, delegate key storage to hardware-backed Android Keystore AES/GCM.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final secrets = await _vaultChannel.invokeMapMethod<String, String>(
          'getOrCreateMasterSecrets',
        );
        final keyB64 = secrets?['encKeyB64'];
        final saltB64 = secrets?['hashSaltB64'];
        if (keyB64 != null && saltB64 != null) {
          final keyBytes = Uint8List.fromList(base64Decode(keyB64));
          final saltBytes = Uint8List.fromList(base64Decode(saltB64));
          if (keyBytes.length == 32 && saltBytes.length == 32) {
            _masterKey = keyBytes;
            _deviceSalt = saltBytes;
            _initialized = true;
            return;
          }
        }
      } catch (e) {
        debugPrint('[SecureCredentialVault] Android Keystore unavailable, using private keyfile: $e');
      }
    }

    // 2. Desktop / local storage keyfile (owner read/write only on POSIX).
    try {
      final file = await AxisStorage.getVaultKeyFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final map = jsonDecode(raw) as Map<String, dynamic>;
        final keyB64 = map['encKeyB64'] as String?;
        final saltB64 = map['hashSaltB64'] as String?;
        if (keyB64 != null && saltB64 != null) {
          final keyBytes = Uint8List.fromList(base64Decode(keyB64));
          final saltBytes = Uint8List.fromList(base64Decode(saltB64));
          if (keyBytes.length == 32 && saltBytes.length == 32) {
            _masterKey = keyBytes;
            _deviceSalt = saltBytes;
            _initialized = true;
            return;
          }
        }
      }

      final freshKey = _randomBytes(32);
      final freshSalt = _randomBytes(32);
      await file.writeAsString(jsonEncode({
        'encKeyB64': base64Encode(freshKey),
        'hashSaltB64': base64Encode(freshSalt),
      }));
      if (Platform.isLinux || Platform.isMacOS || Platform.isAndroid) {
        try {
          await Process.run('chmod', ['600', file.path]);
        } catch (e) {
          debugPrint('[SecureCredentialVault] chmod notice: $e');
        }
      }
      _masterKey = freshKey;
      _deviceSalt = freshSalt;
      _initialized = true;
      return;
    } catch (e) {
      debugPrint('[SecureCredentialVault] Keyfile notice (ephemeral mode): $e');
    }

    _ensureEphemeralKeys();
    _initialized = true;
  }

  /// Generates a 64-character hex HMAC-SHA256 digest using the per-install device salt.
  static String hashPassword(String password) {
    _ensureEphemeralKeys();
    final hmac = Hmac(sha256, _deviceSalt!);
    return hmac.convert(utf8.encode(password)).toString();
  }

  static String _legacyHashPassword(String password) {
    final saltedBytes = utf8.encode('$password:$_legacyAppSalt');
    return sha256.convert(saltedBytes).toString();
  }

  /// Constant-time comparison verifying current per-install HMAC or legacy hash on upgrade.
  static bool verifyPassword(String password, String storedHash) {
    if (storedHash.isEmpty || password.isEmpty) return false;
    return _constantTimeEquals(hashPassword(password), storedHash) ||
        _constantTimeEquals(_legacyHashPassword(password), storedHash);
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  static Uint8List _deriveLegacyKey() {
    final keyBytes = sha256.convert(utf8.encode('AXIS_ENCRYPTION_KEY_SEED:$_legacyAppSalt')).bytes;
    return Uint8List.fromList(keyBytes);
  }

  /// Encrypts [password] with AES-256-CBC (random 16-byte IV + per-install key).
  /// Output format: `v2:<iv_base64>:<ciphertext_base64>`
  static String encryptPassword(String password) {
    if (password.isEmpty) return '';
    _ensureEphemeralKeys();

    final iv = _randomBytes(16);
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    cipher.init(true, PaddedBlockCipherParameters(ParametersWithIV(KeyParameter(_masterKey!), iv), null));
    final encryptedBytes = cipher.process(Uint8List.fromList(utf8.encode(password)));
    return 'v2:${base64Encode(iv)}:${base64Encode(encryptedBytes)}';
  }

  /// Decrypts `v2:` payloads with the per-install key or legacy 2-part ciphertexts on upgrade.
  static String? decryptPassword(String encryptedData) {
    if (encryptedData.isEmpty) return null;
    try {
      final parts = encryptedData.split(':');
      if (parts.length == 3 && parts[0] == 'v2') {
        _ensureEphemeralKeys();
        return _decryptWithKey(base64Decode(parts[1]), base64Decode(parts[2]), _masterKey!);
      }
      if (parts.length == 2) {
        return _decryptWithKey(base64Decode(parts[0]), base64Decode(parts[1]), _deriveLegacyKey());
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _decryptWithKey(List<int> iv, List<int> cipherText, Uint8List key) {
    final cipher = PaddedBlockCipher('AES/CBC/PKCS7');
    cipher.init(
      false,
      PaddedBlockCipherParameters(
        ParametersWithIV(KeyParameter(key), Uint8List.fromList(iv)),
        null,
      ),
    );
    final decryptedBytes = cipher.process(Uint8List.fromList(cipherText));
    return utf8.decode(decryptedBytes);
  }
}
