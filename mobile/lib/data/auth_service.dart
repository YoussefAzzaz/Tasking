import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/core/storage/axis_storage.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/habit_notification_service.dart';
import 'package:axis/data/daily_prayer_status_repository.dart';
import 'package:axis/data/friends/friend_search_repository.dart';
import 'package:axis/data/friends/friend_activity_repository.dart';
import 'package:axis/core/security/secure_credential_vault.dart';

/// Full-stack Authentication Service bridging Supabase Auth & PowerSync multi-tenant isolation.
/// Provides offline session persistence, background auto-login, and seamless reconnect sync.
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _lastSavedSession;
  bool _isAutoLoggingIn = false;
  bool _isReAuthenticating = false;

  /// Reactive notifier for GoRouter refreshListenable & auth state observers
  final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(false);

  /// Reactive notifier when the cloud token is expired / deprecated and needs re-login
  final ValueNotifier<bool> sessionExpiredNotifier = ValueNotifier<bool>(false);

  /// Whether the current session has an expired / deprecated token
  bool get isSessionExpired => sessionExpiredNotifier.value;

  Map<String, dynamic>? get lastSavedSession => _lastSavedSession;

  /// Current authenticated Supabase user
  User? get currentUser => _client?.auth.currentUser;

  /// Current session with access token
  Session? get currentSession => _client?.auth.currentSession;

  /// Whether the user is operating in unauthenticated local guest mode
  bool get isGuest {
    if (currentSession != null) return false;
    final uid = currentUserId;
    return uid == 'local_guest';
  }

  /// Whether a user has an authenticated Supabase cloud session (live or persisted offline)
  bool get isAuthenticated {
    if (currentSession != null) return true;
    final savedUid = _lastSavedSession?['user_id'] as String?;
    return savedUid != null && savedUid.isNotEmpty && savedUid != 'local_guest';
  }

  /// True if there is an active Supabase session OR an existing saved local offline session (including guest)
  bool get hasActiveSession {
    if (currentSession != null) return true;
    final savedUid = _lastSavedSession?['user_id'] as String?;
    return savedUid != null && savedUid.isNotEmpty;
  }

  /// Authenticated user unique UUID (falls back to saved local user_id for 100% offline access)
  String? get currentUserId =>
      currentUser?.id ?? (_lastSavedSession?['user_id'] as String?);

  /// Authenticated user email (falls back to saved local email)
  String? get userEmail =>
      currentUser?.email ?? (_lastSavedSession?['email'] as String?);

  /// User display name from metadata, saved session, or email fallback
  String get displayName {
    final meta = currentUser?.userMetadata;
    if (meta != null &&
        meta['display_name'] != null &&
        (meta['display_name'] as String).trim().isNotEmpty) {
      return (meta['display_name'] as String).trim();
    }
    final savedName = _lastSavedSession?['display_name'] as String?;
    if (savedName != null && savedName.trim().isNotEmpty) {
      return savedName.trim();
    }
    if (userEmail != null && userEmail!.contains('@')) {
      return userEmail!.split('@').first;
    }
    return 'Operative';
  }

  /// Reactive stream of authentication changes
  Stream<AuthState> get authStateChanges =>
      _client?.auth.onAuthStateChange ?? const Stream.empty();

  Map<String, String>? _cachedPersistentCredentials;

  /// Loads cached credentials from the persistent axis storage directory
  Future<Map<String, String>?> loadPersistentCredentials() async {
    if (_cachedPersistentCredentials != null) return _cachedPersistentCredentials;
    try {
      final file = await AxisStorage.getLastSavedCredentialsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          final email = data['email'] as String? ?? '';
          final enc = data['encrypted_password'] as String? ?? '';
          final displayName = data['display_name'] as String? ?? '';
          if (email.isNotEmpty && enc.isNotEmpty) {
            _cachedPersistentCredentials = {
              'email': email,
              'encrypted_password': enc,
              'display_name': displayName,
            };
            return _cachedPersistentCredentials;
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Error reading persistent credentials: $e');
    }
    return null;
  }

  /// Persists credentials to axis storage for quick login across sessions
  Future<void> savePersistentCredentials({
    required String email,
    required String plainPassword,
    String? displayName,
  }) async {
    try {
      final enc = SecureCredentialVault.encryptPassword(plainPassword);
      final data = {
        'email': email.trim(),
        'encrypted_password': enc,
        'display_name': displayName ?? '',
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      };
      _cachedPersistentCredentials = {
        'email': email.trim(),
        'encrypted_password': enc,
        'display_name': displayName ?? '',
      };
      final file = await AxisStorage.getLastSavedCredentialsFile();
      await file.writeAsString(jsonEncode(data), flush: true);
    } catch (e) {
      debugPrint('[AuthService] Error persisting credentials: $e');
    }
  }

  /// Initialize and load saved local auth session from SQLite
  Future<void> init() async {
    await loadPersistentCredentials();
    if (!isDatabaseInitialized) return;
    try {
      final row = await db.getOptional(
        'SELECT * FROM local_auth_session WHERE id = ?',
        ['active_session'],
      );
      if (row != null) {
        _lastSavedSession = Map<String, dynamic>.from(row);
        final uid = (row['user_id'] as String?) ?? '';
        if (uid.isNotEmpty) {
          setCachedUserId(uid);
        }
      } else if (currentUser != null) {
        // Save existing active session if table was previously empty
        final uid = currentUser!.id;
        final email = currentUser!.email ?? '';
        final name = displayName;
        setCachedUserId(uid);
        _lastSavedSession = {
          'id': 'active_session',
          'user_id': uid,
          'email': email,
          'display_name': name,
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
        };
        await db.execute('''
          INSERT INTO local_auth_session (
            id, user_id, email, display_name, last_login_at
          ) VALUES (?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            user_id = excluded.user_id,
            email = excluded.email,
            display_name = excluded.display_name,
            last_login_at = excluded.last_login_at
        ''', [
          'active_session',
          uid,
          email,
          name,
          DateTime.now().toUtc().toIso8601String(),
        ]);
      }
      unawaited(purgeForeignUserData());
      authStateNotifier.value = hasActiveSession;
    } catch (e) {
      debugPrint('[AuthService] Error reading local auth session: $e');
    }
  }

  /// Whether encrypted credentials exist in local cache for re-authentication
  bool get hasSavedCredentials {
    final enc = (_lastSavedSession?['encrypted_password'] as String?) ??
        _cachedPersistentCredentials?['encrypted_password'];
    final email = (_lastSavedSession?['email'] as String?) ??
        _cachedPersistentCredentials?['email'];
    return enc != null && enc.isNotEmpty && email != null && email.isNotEmpty;
  }

  /// Returns the cached email if any
  String? get savedEmail =>
      (_lastSavedSession?['email'] as String?) ??
      _cachedPersistentCredentials?['email'];

  /// Attempts to recover the decrypted plain password from the secure vault
  String? getDecryptedPassword() {
    final enc = (_lastSavedSession?['encrypted_password'] as String?) ??
        _cachedPersistentCredentials?['encrypted_password'];
    if (enc == null || enc.isEmpty) return null;
    return SecureCredentialVault.decryptPassword(enc);
  }

  /// Returns the stored password hash (for verification without decryption)
  String? get storedPasswordHash => _lastSavedSession?['password_hash'] as String?;

  /// Persist session metadata locally in SQLite for offline access
  Future<void> saveLocalSession({
    required String userId,
    required String email,
    String? displayName,
    String? avatarUrl,
    String? plainPassword,
  }) async {
    setCachedUserId(userId);

    String? encryptedPassword = _lastSavedSession?['encrypted_password'] as String?;
    String? passwordHash = _lastSavedSession?['password_hash'] as String?;

    if (plainPassword != null && plainPassword.isNotEmpty) {
      encryptedPassword = SecureCredentialVault.encryptPassword(plainPassword);
      passwordHash = SecureCredentialVault.hashPassword(plainPassword);
      unawaited(savePersistentCredentials(
        email: email,
        plainPassword: plainPassword,
        displayName: displayName,
      ));
    }

    _lastSavedSession = {
      'id': 'active_session',
      'user_id': userId,
      'email': email,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'encrypted_password': encryptedPassword,
      'password_hash': passwordHash,
      'last_login_at': DateTime.now().toUtc().toIso8601String(),
    };
    sessionExpiredNotifier.value = false;
    authStateNotifier.value = true;

    if (isDatabaseInitialized) {
      try {
        await db.execute('''
          INSERT INTO local_auth_session (
            id, user_id, email, display_name, avatar_url, encrypted_password, password_hash, last_login_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ON CONFLICT(id) DO UPDATE SET
            user_id = excluded.user_id,
            email = excluded.email,
            display_name = excluded.display_name,
            avatar_url = COALESCE(excluded.avatar_url, local_auth_session.avatar_url),
            encrypted_password = COALESCE(excluded.encrypted_password, local_auth_session.encrypted_password),
            password_hash = COALESCE(excluded.password_hash, local_auth_session.password_hash),
            last_login_at = excluded.last_login_at
        ''', [
          'active_session',
          userId,
          email,
          displayName,
          avatarUrl,
          encryptedPassword,
          passwordHash,
          DateTime.now().toUtc().toIso8601String(),
        ]);
        await purgeForeignUserData();
      } catch (e) {
        debugPrint('[AuthService] Error persisting local auth session: $e');
      }
    }
  }

  /// Clear the local auth session from memory and SQLite (preserves persistent quick login credentials)
  Future<void> clearLocalSession() async {
    _lastSavedSession = null;
    setCachedUserId('');
    sessionExpiredNotifier.value = false;
    authStateNotifier.value = false;
    if (isDatabaseInitialized) {
      try {
        await db.execute('DELETE FROM local_auth_session WHERE id = ?', ['active_session']);
      } catch (e) {
        debugPrint('[AuthService] Error clearing local auth session: $e');
      }
    }
  }

  /// Clears saved credentials from local storage and memory while keeping user session
  Future<void> clearSavedCredentials({bool forgetAccount = false}) async {
    if (_lastSavedSession != null) {
      _lastSavedSession!['encrypted_password'] = null;
      _lastSavedSession!['password_hash'] = null;
    }
    if (forgetAccount) {
      _cachedPersistentCredentials = null;
      try {
        final file = await AxisStorage.getLastSavedCredentialsFile();
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('[AuthService] Error deleting persistent credentials file: $e');
      }
    }
    if (isDatabaseInitialized) {
      try {
        await db.execute(
          'UPDATE local_auth_session SET encrypted_password = NULL, password_hash = NULL WHERE id = ?',
          ['active_session'],
        );
      } catch (e) {
        debugPrint('[AuthService] Error clearing saved credentials: $e');
      }
    }
  }

  /// Handles expired or deprecated sync token: clears active cloud session,
  /// disconnects PowerSync, preserves persistent credentials for quick login,
  /// triggers GoRouter redirect to /auth, and notifies UI.
  Future<void> handleSessionExpired({String? reason}) async {
    debugPrint('[AuthService] Handling expired / deprecated session: $reason');
    sessionExpiredNotifier.value = true;
    authStateNotifier.value = false;
    _lastSavedSession = null;
    setCachedUserId('');

    if (isDatabaseInitialized) {
      try {
        await db.disconnect();
      } catch (_) {}
      try {
        await db.execute('DELETE FROM local_auth_session WHERE id = ?', ['active_session']);
      } catch (e) {
        debugPrint('[AuthService] Error clearing local auth session on expiration: $e');
      }
    }
  }

  /// Attempts silent re-authentication with Supabase using cached encrypted credentials
  Future<bool> trySilentReAuthWithSavedCredentials() async {
    if (_isReAuthenticating) return false;
    final client = _client;
    if (client == null) return false;
    final email = savedEmail;
    final password = getDecryptedPassword();
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return false;
    }

    _isReAuthenticating = true;
    try {
      debugPrint('[AuthService] Attempting silent re-authentication with secure cached credentials for $email...');
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session != null && !response.session!.isExpired) {
        final uid = response.user?.id ?? '';
        if (uid.isNotEmpty) {
          setCachedUserId(uid);
        }
        sessionExpiredNotifier.value = false;
        authStateNotifier.value = true;
        if (isDatabaseInitialized) {
          unawaited(connectPowerSyncSafely());
        }
        debugPrint('[AuthService] Silent re-authentication successful! Session restored.');
        return true;
      }
    } catch (e) {
      debugPrint('[AuthService] Silent re-authentication failed: $e');
    } finally {
      _isReAuthenticating = false;
    }
    return false;
  }

  /// Silently restores Supabase session in the background and connects PowerSync if online
  Future<void> tryAutoLoginOrSync() async {
    if (_isAutoLoggingIn) return;
    final savedUid = _lastSavedSession?['user_id'] as String?;
    if (savedUid == null || savedUid.isEmpty || savedUid == 'local_guest') return;
    _isAutoLoggingIn = true;
    try {
      final client = _client;
      if (client == null) return;

      var session = client.auth.currentSession;
      if (session != null && session.isExpired && session.refreshToken != null && session.refreshToken!.isNotEmpty) {
        try {
          final res = await client.auth.refreshSession();
          session = res.session;
        } catch (e) {
          debugPrint('[AuthService] Auto-refresh session error: $e');
        }
      }

      if (session == null || session.isExpired) {
        final reAuthOk = await trySilentReAuthWithSavedCredentials();
        if (reAuthOk) {
          session = client.auth.currentSession;
        }
      }

      if (session != null && !session.isExpired) {
        setCachedUserId(session.user.id);
        sessionExpiredNotifier.value = false;
        if (isDatabaseInitialized) {
          unawaited(connectPowerSyncSafely());
        }
        return;
      } else {
        sessionExpiredNotifier.value = true;
      }
    } catch (e) {
      debugPrint('[AuthService] tryAutoLoginOrSync error: $e');
    } finally {
      _isAutoLoggingIn = false;
    }
  }

  /// Ensures an active, unexpired authenticated Supabase cloud session exists.
  /// Automatically refreshes expired JWT tokens or restores saved session from disk.
  Future<bool> ensureAuthenticatedSession() async {
    final client = _client;
    if (client == null) return false;

    var session = client.auth.currentSession;
    if (session == null) {
      final savedUid = currentUserId;
      if (savedUid == null || savedUid.isEmpty || savedUid == 'local_guest') {
        return false;
      }
      await tryAutoLoginOrSync();
      session = client.auth.currentSession;
    }

    if (session != null && session.isExpired && session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      try {
        final res = await client.auth.refreshSession();
        session = res.session;
      } catch (e) {
        debugPrint('[AuthService] ensureAuthenticatedSession refresh notice: $e');
      }
    }

    if (session == null || session.isExpired) {
      final reAuthOk = await trySilentReAuthWithSavedCredentials();
      if (reAuthOk) {
        session = client.auth.currentSession;
      }
    }

    final isValid = session != null && !session.isExpired && session.user.id.isNotEmpty && session.user.id != 'local_guest';
    final savedUid = currentUserId;
    if (!isValid && savedUid != null && savedUid.isNotEmpty && savedUid != 'local_guest') {
      sessionExpiredNotifier.value = true;
    } else if (isValid) {
      sessionExpiredNotifier.value = false;
    }
    return isValid;
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not initialized');

    try {
      final currentAuthUid = currentUserId;
      final previousUid = (currentAuthUid != null && currentAuthUid.isNotEmpty)
          ? currentAuthUid
          : ((_lastSavedSession?['user_id'] as String?) ?? '');

      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final uid = response.user?.id ?? '';
      final name = (response.user?.userMetadata?['display_name'] as String?) ??
          email.split('@').first;

      // Guarantee prior user's local PowerSync tables are purged before activating the new account
      if (uid.isNotEmpty &&
          previousUid.isNotEmpty &&
          previousUid != 'local_guest' &&
          previousUid != uid &&
          isDatabaseInitialized) {
        try {
          DailyPrayerStatusRepository().clearSessionState();
          FriendSearchRepository().inMemoryProfileCache.clear();
          FriendActivityRepository().clearSessionState();
          await db.disconnectAndClear();
        } catch (e) {
          debugPrint('[AuthService] User switch disconnectAndClear notice: $e');
        }
      }

      await saveLocalSession(
        userId: uid,
        email: email.trim(),
        displayName: name,
        plainPassword: rememberMe ? password : null,
      );

      if (!rememberMe) {
        await clearSavedCredentials();
      }

      // Connect PowerSync with new user credentials if not already connected
      if (response.session != null && isDatabaseInitialized) {
        unawaited(connectPowerSyncSafely());
        unawaited(PrayerTimeService().syncPrayers());
      }

      // Purge any foreign user habit notifications and reschedule for active user
      try {
        await HabitNotificationService().cancelAllHabitReminders();
        unawaited(HabitNotificationService().rescheduleAllHabits());
      } catch (_) {}

      return response;
    } catch (e) {
      debugPrint('[AuthService] Sign-in error: $e');
      rethrow;
    }
  }

  /// Sign up / Register new account with email, password, and display name
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not initialized');

    try {
      final cleanName =
          displayName.trim().isEmpty ? 'Operative' : displayName.trim();
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name': cleanName,
        },
      );

      final uid = response.user?.id ?? '';
      await saveLocalSession(
        userId: uid,
        email: email.trim(),
        displayName: cleanName,
        plainPassword: password,
      );

      // Auto-connect if session is immediately active and not already connected
      if (response.session != null && isDatabaseInitialized) {
        unawaited(connectPowerSyncSafely());
        unawaited(PrayerTimeService().syncPrayers());
      }

      // Purge any foreign user habit notifications and reschedule for active user
      try {
        await HabitNotificationService().cancelAllHabitReminders();
        unawaited(HabitNotificationService().rescheduleAllHabits());
      } catch (_) {}

      return response;
    } catch (e) {
      debugPrint('[AuthService] Sign-up error: $e');
      rethrow;
    }
  }

  /// Secure sign out: terminates any active sessions, disconnects PowerSync, clears local SQLite user data and terminates remote session
  Future<void> signOut() async {
    setSigningOut(true);
    try {
      // 0. Clear in-memory identity & caches immediately so active db.watch listeners
      // abort cleanly and cannot rewrite User A rows while signing out.
      _lastSavedSession = null;
      setCachedUserId('');
      authStateNotifier.value = false;
      try {
        DailyPrayerStatusRepository().clearSessionState();
      } catch (_) {}
      try {
        FriendSearchRepository().inMemoryProfileCache.clear();
      } catch (_) {}
      try {
        FriendActivityRepository().clearSessionState();
      } catch (_) {}

      // 1. Cancel and dismiss all habit notifications to prevent cross-account leaks
      try {
        await HabitNotificationService().cancelAllHabitReminders();
      } catch (e) {
        debugPrint('[AuthService] Clear habit notifications error: $e');
      }

      // 2. Immediately terminate any active focus session / audio / timer
      try {
        FocusSessionService().terminateSession();
      } catch (e) {
        debugPrint('[AuthService] Terminate focus session error: $e');
      }

      // 3. Disconnect PowerSync sync transport first so no retries or frames arrive during teardown
      if (isDatabaseInitialized) {
        try {
          await db.disconnect();
        } catch (e) {
          debugPrint('[AuthService] PowerSync disconnect error: $e');
        }
      }

      // 4. Terminate active remote & local session on Supabase BEFORE clearing SQLite tables
      final client = _client;
      if (client != null) {
        try {
          await client.auth.signOut(scope: SignOutScope.global);
        } catch (e) {
          debugPrint('[AuthService] Global remote sign-out error (offline fallback): $e');
          try {
            await client.auth.signOut(scope: SignOutScope.local);
          } catch (_) {}
        }
      }

      // 5. Clear local SQLite database & auth session
      if (isDatabaseInitialized) {
        try {
          await clearUserDataOnSignOut();
        } catch (e) {
          debugPrint('[AuthService] Clear user data error: $e');
        }
        try {
          await clearLocalSession();
        } catch (e) {
          debugPrint('[AuthService] Clear local session error: $e');
        }
        // Final purge pass guarantees zero leftover frames or CRUD ops before next login
        try {
          await db.disconnectAndClear();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[AuthService] Sign-out error: $e');
    } finally {
      setSigningOut(false);
    }
  }
}
