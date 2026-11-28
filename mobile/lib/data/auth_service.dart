import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/core/cache/cache_service.dart';
import 'package:axis/core/storage/axis_storage.dart';
import 'package:axis/data/auth/auth_error_classifier.dart';
import 'package:axis/data/powersync_db.dart';

export 'package:axis/data/auth/auth_error_classifier.dart' show SessionRefreshResult;
import 'package:axis/data/network_service.dart';
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
  int _authEpoch = 0;
  Future<SessionRefreshResult>? _activeRefreshFuture;

  /// Monotonically increasing counter incremented on login, logout, and session restoration.
  /// Used to discard stale background refresh/expiry callbacks so they can never clobber a new login.
  int get authEpoch => _authEpoch;

  /// Reactive notifier for GoRouter refreshListenable & auth state observers
  final ValueNotifier<bool> authStateNotifier = ValueNotifier<bool>(false);

  /// Reactive notifier when the cloud token is genuinely expired / revoked and needs re-login
  final ValueNotifier<bool> sessionExpiredNotifier = ValueNotifier<bool>(false);

  /// Whether the user has dismissed the session-expired alert banner for this cycle
  final ValueNotifier<bool> sessionExpiredDismissedNotifier = ValueNotifier<bool>(false);

  /// Whether the current session has a genuinely expired / revoked token
  bool get isSessionExpired => sessionExpiredNotifier.value;

  /// Whether the user has dismissed the session-expired banner
  bool get isSessionExpiredBannerDismissed => sessionExpiredDismissedNotifier.value;

  /// Dismisses the session-expired banner without logging out or losing local data
  void dismissSessionExpiredBanner() {
    sessionExpiredDismissedNotifier.value = true;
  }

  static bool isNetworkOrRetryableError(Object error) =>
      AuthErrorClassifier.isNetworkOrRetryableError(error);

  static bool isPermanentAuthError(Object error) =>
      AuthErrorClassifier.isPermanentAuthError(error);

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

  static bool _isGuestEmail(String? email) {
    if (email == null) return true;
    final trimmed = email.trim().toLowerCase();
    return trimmed.isEmpty || trimmed == 'guest@tasking.local';
  }

  /// Loads cached credentials (and/or last known email) from the persistent axis storage directory
  Future<Map<String, String>?> loadPersistentCredentials({bool forceReload = false}) async {
    if (!forceReload && _cachedPersistentCredentials != null) {
      return _cachedPersistentCredentials;
    }
    try {
      final file = await AxisStorage.getLastSavedCredentialsFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final data = jsonDecode(content) as Map<String, dynamic>;
          final email = (data['email'] as String? ?? '').trim();
          final enc = (data['encrypted_password'] as String? ?? '').trim();
          final displayName = (data['display_name'] as String? ?? '').trim();
          if (!_isGuestEmail(email)) {
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

  /// Persists credentials (or at minimum last used email) to axis storage for quick login across sessions.
  /// When updating email without a new password, preserves any existing encrypted password for the same email.
  Future<void> savePersistentCredentials({
    required String email,
    String? plainPassword,
    String? encryptedPassword,
    String? displayName,
  }) async {
    final trimmedEmail = email.trim();
    if (_isGuestEmail(trimmedEmail)) return;
    try {
      String enc = '';
      if (plainPassword != null && plainPassword.isNotEmpty) {
        enc = SecureCredentialVault.encryptPassword(plainPassword);
      } else if (encryptedPassword != null && encryptedPassword.isNotEmpty) {
        enc = encryptedPassword;
      } else {
        final existing = _cachedPersistentCredentials ?? await loadPersistentCredentials();
        if (existing != null &&
            (existing['email'] ?? '').trim().toLowerCase() == trimmedEmail.toLowerCase()) {
          enc = existing['encrypted_password'] ?? '';
        }
      }

      final cleanDisplayName = (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : (_cachedPersistentCredentials?['display_name'] ?? '');

      final data = {
        'email': trimmedEmail,
        'encrypted_password': enc,
        'display_name': cleanDisplayName,
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      };
      _cachedPersistentCredentials = {
        'email': trimmedEmail,
        'encrypted_password': enc,
        'display_name': cleanDisplayName,
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
        // Backfill persistent credentials file for users who logged in before v1.2.7
        final rowEmail = (row['email'] as String?)?.trim() ?? '';
        final rowEnc = (row['encrypted_password'] as String?)?.trim() ?? '';
        final rowName = (row['display_name'] as String?)?.trim() ?? '';
        if (uid != 'local_guest' && !_isGuestEmail(rowEmail)) {
          final cachedEmail = _cachedPersistentCredentials?['email'] ?? '';
          final cachedEnc = _cachedPersistentCredentials?['encrypted_password'] ?? '';
          if (cachedEmail.isEmpty || (cachedEnc.isEmpty && rowEnc.isNotEmpty)) {
            await savePersistentCredentials(
              email: rowEmail,
              encryptedPassword: rowEnc.isNotEmpty ? rowEnc : null,
              displayName: rowName,
            );
          }
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
        if (!_isGuestEmail(email)) {
          await savePersistentCredentials(email: email, displayName: name);
        }
      }
      unawaited(purgeForeignUserData());
      authStateNotifier.value = hasActiveSession;
    } catch (e) {
      debugPrint('[AuthService] Error reading local auth session: $e');
    }
  }

  static String? _nonEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Whether encrypted credentials exist in local cache for re-authentication
  bool get hasSavedCredentials {
    final enc = _nonEmpty(_lastSavedSession?['encrypted_password'] as String?) ??
        _nonEmpty(_cachedPersistentCredentials?['encrypted_password']);
    final email = savedEmail;
    return enc != null && email != null;
  }

  /// Returns the cached non-guest email if any
  String? get savedEmail {
    final sessionEmail = _nonEmpty(_lastSavedSession?['email'] as String?);
    if (sessionEmail != null && !_isGuestEmail(sessionEmail)) {
      return sessionEmail;
    }
    final cachedEmail = _nonEmpty(_cachedPersistentCredentials?['email']);
    if (cachedEmail != null && !_isGuestEmail(cachedEmail)) {
      return cachedEmail;
    }
    return null;
  }

  /// Attempts to recover the decrypted plain password from the secure vault
  String? getDecryptedPassword() {
    final enc = _nonEmpty(_lastSavedSession?['encrypted_password'] as String?) ??
        _nonEmpty(_cachedPersistentCredentials?['encrypted_password']);
    if (enc == null) return null;
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

    String? encryptedPassword = _nonEmpty(_lastSavedSession?['encrypted_password'] as String?);
    String? passwordHash = _nonEmpty(_lastSavedSession?['password_hash'] as String?);

    if (plainPassword != null && plainPassword.isNotEmpty) {
      encryptedPassword = SecureCredentialVault.encryptPassword(plainPassword);
      passwordHash = SecureCredentialVault.hashPassword(plainPassword);
      if (userId != 'local_guest' && !_isGuestEmail(email)) {
        await savePersistentCredentials(
          email: email,
          plainPassword: plainPassword,
          displayName: displayName,
        );
      }
    } else if (userId != 'local_guest' && !_isGuestEmail(email)) {
      await savePersistentCredentials(
        email: email,
        encryptedPassword: encryptedPassword,
        displayName: displayName,
      );
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
    sessionExpiredDismissedNotifier.value = false;

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
        unawaited(purgeForeignUserData());
      } catch (e) {
        debugPrint('[AuthService] Error persisting local auth session: $e');
      }
    }

    // Notify router / observers AFTER SQLite local_auth_session is persisted
    authStateNotifier.value = true;
  }

  /// Clear the local auth session from memory and SQLite (preserves persistent quick login credentials)
  Future<void> clearLocalSession() async {
    _lastSavedSession = null;
    setCachedUserId('');
    sessionExpiredNotifier.value = false;
    sessionExpiredDismissedNotifier.value = false;
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
    } else if (_cachedPersistentCredentials != null) {
      // Keep email for convenience while removing password when Remember Me is unchecked
      final email = _cachedPersistentCredentials!['email'] ?? '';
      final name = _cachedPersistentCredentials!['display_name'] ?? '';
      _cachedPersistentCredentials = email.isNotEmpty
          ? {'email': email, 'encrypted_password': '', 'display_name': name}
          : null;
      try {
        if (email.isNotEmpty) {
          final file = await AxisStorage.getLastSavedCredentialsFile();
          await file.writeAsString(
            jsonEncode({
              'email': email,
              'encrypted_password': '',
              'display_name': name,
              'saved_at': DateTime.now().toUtc().toIso8601String(),
            }),
            flush: true,
          );
        }
      } catch (e) {
        debugPrint('[AuthService] Error updating persistent credentials file: $e');
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

  /// Handles genuinely expired or revoked cloud session (ONLY when confirmed online by server).
  /// Preserves local offline session and cached user_id so local SQLite data stays completely safe,
  /// disconnects PowerSync cleanly in the background, and notifies UI with a dismissible banner.
  Future<void> handleSessionExpired({String? reason, int? expectedEpoch}) async {
    if (expectedEpoch != null && expectedEpoch != _authEpoch) {
      debugPrint('[AuthService] Ignoring stale handleSessionExpired (epoch $expectedEpoch != $_authEpoch)');
      return;
    }
    if (isSigningIn || isSigningOut) {
      debugPrint('[AuthService] Ignoring handleSessionExpired while signing in/out');
      return;
    }
    if (!NetworkService().isOnline) {
      debugPrint('[AuthService] Offline: suppressing handleSessionExpired ($reason)');
      return;
    }

    debugPrint('[AuthService] Handling confirmed expired / revoked session: $reason');
    sessionExpiredDismissedNotifier.value = false;
    sessionExpiredNotifier.value = true;

    // Disconnect PowerSync asynchronously via microtask to avoid deadlocking
    // PowerSync's syncConnectMutex if called from inside fetchCredentials().
    if (isDatabaseInitialized) {
      unawaited(
        Future<void>.microtask(() async {
          try {
            await db.disconnect().timeout(const Duration(seconds: 3));
          } catch (_) {}
        }),
      );
    }
  }

  /// Internal detailed silent re-authentication distinguishing network failures from invalid credentials.
  Future<SessionRefreshResult> _trySilentReAuthDetailed({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (_isReAuthenticating) return SessionRefreshResult.offlineOrTransient;
    if (isSigningIn || isSigningOut) return SessionRefreshResult.offlineOrTransient;
    if (!NetworkService().isOnline) return SessionRefreshResult.offlineOrTransient;

    final client = _client;
    if (client == null) return SessionRefreshResult.offlineOrTransient;

    await loadPersistentCredentials();
    final email = savedEmail;
    final password = getDecryptedPassword();
    if (email == null || email.isEmpty || password == null || password.isEmpty) {
      return SessionRefreshResult.expired;
    }

    final startEpoch = _authEpoch;
    _isReAuthenticating = true;
    try {
      debugPrint('[AuthService] Attempting silent re-authentication with secure cached credentials for $email...');
      final response = await client.auth
          .signInWithPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(timeout);
      if (startEpoch != _authEpoch || isSigningOut) {
        return SessionRefreshResult.offlineOrTransient;
      }
      if (response.session != null && !response.session!.isExpired) {
        final uid = response.user?.id ?? '';
        if (uid.isNotEmpty) {
          setCachedUserId(uid);
        }
        _authEpoch++;
        sessionExpiredNotifier.value = false;
        sessionExpiredDismissedNotifier.value = false;
        authStateNotifier.value = true;
        if (isDatabaseInitialized) {
          unawaited(connectPowerSyncSafely());
        }
        debugPrint('[AuthService] Silent re-authentication successful! Session restored.');
        return SessionRefreshResult.valid;
      }
      return SessionRefreshResult.expired;
    } catch (e) {
      debugPrint('[AuthService] Silent re-authentication error: $e');
      if (isPermanentAuthError(e)) {
        return SessionRefreshResult.expired;
      }
      // Network, timeout, DNS, or server 5xx error -> offline/transient, NEVER mark expired!
      return SessionRefreshResult.offlineOrTransient;
    } finally {
      _isReAuthenticating = false;
    }
  }

  /// Attempts silent re-authentication with Supabase using cached encrypted credentials
  Future<bool> trySilentReAuthWithSavedCredentials({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final result = await _trySilentReAuthDetailed(timeout: timeout);
    return result == SessionRefreshResult.valid;
  }

  /// Centralized, deduplicated session refresh & recovery pipeline.
  /// - Coalesces concurrent calls (startup, PowerSync, network reconnect) into a single attempt.
  /// - Never marks session expired when offline or on transient network/timeout/5xx errors.
  /// - Only flags sessionExpiredNotifier when Supabase explicitly rejects the refresh token
  ///   and silent re-auth either has no saved credentials or is also permanently rejected.
  Future<SessionRefreshResult> refreshOrRecoverSession({
    Duration timeout = const Duration(seconds: 8),
  }) {
    final active = _activeRefreshFuture;
    if (active != null) return active;

    final future = _doRefreshOrRecoverSession(timeout: timeout);
    _activeRefreshFuture = future;
    future.whenComplete(() {
      if (identical(_activeRefreshFuture, future)) {
        _activeRefreshFuture = null;
      }
    });
    return future;
  }

  Future<SessionRefreshResult> _doRefreshOrRecoverSession({
    required Duration timeout,
  }) async {
    if (isSigningOut || isSigningIn) {
      return SessionRefreshResult.offlineOrTransient;
    }

    final client = _client;
    if (client == null) return SessionRefreshResult.offlineOrTransient;

    final startEpoch = _authEpoch;
    var session = client.auth.currentSession;

    // 1. Valid unexpired session
    if (session != null && !session.isExpired) {
      setCachedUserId(session.user.id);
      sessionExpiredNotifier.value = false;
      sessionExpiredDismissedNotifier.value = false;
      return SessionRefreshResult.valid;
    }

    // 2. Check if user is guest or completely unauthenticated
    final savedUid = currentUserId;
    if (session == null && (savedUid == null || savedUid.isEmpty || savedUid == 'local_guest')) {
      return SessionRefreshResult.unauthenticated;
    }

    // 3. Offline fast-path: keep local offline session valid without triggering any error or alert!
    if (!NetworkService().isOnline) {
      debugPrint('[AuthService] Offline mode: deferring token refresh until connectivity returns.');
      return SessionRefreshResult.offlineOrTransient;
    }

    // 4. Try refreshing expired access token using Supabase refresh token
    bool refreshRejectedPermanently = false;
    if (session != null && session.isExpired) {
      final refreshToken = session.refreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        try {
          final res = await client.auth.refreshSession().timeout(timeout);
          if (startEpoch != _authEpoch || isSigningOut || isSigningIn) {
            return SessionRefreshResult.offlineOrTransient;
          }
          session = res.session;
          if (session != null && !session.isExpired) {
            setCachedUserId(session.user.id);
            _authEpoch++;
            sessionExpiredNotifier.value = false;
            sessionExpiredDismissedNotifier.value = false;
            return SessionRefreshResult.valid;
          }
        } catch (e) {
          debugPrint('[AuthService] refreshSession error: $e');
          if (isPermanentAuthError(e)) {
            refreshRejectedPermanently = true;
          } else {
            // Network / DNS / Socket / Timeout / Retryable error -> stay peacefully offline!
            return SessionRefreshResult.offlineOrTransient;
          }
        }
      } else {
        refreshRejectedPermanently = true;
      }
    } else if (session == null) {
      // Saved local cloud user exists but Supabase has no persisted session at all
      refreshRejectedPermanently = true;
    }

    if (startEpoch != _authEpoch || isSigningOut || isSigningIn) {
      return SessionRefreshResult.offlineOrTransient;
    }

    // 5. Only if server permanently rejected refresh (or session missing online), attempt silent re-auth
    if (refreshRejectedPermanently) {
      final reAuthResult = await _trySilentReAuthDetailed(timeout: timeout);
      if (reAuthResult == SessionRefreshResult.valid) {
        return SessionRefreshResult.valid;
      }
      if (reAuthResult == SessionRefreshResult.offlineOrTransient) {
        return SessionRefreshResult.offlineOrTransient;
      }
      // Confirmed permanent failure while online -> mark session expired (preserving local data)
      await handleSessionExpired(
        reason: 'Supabase session refresh rejected by server',
        expectedEpoch: startEpoch,
      );
      return SessionRefreshResult.expired;
    }

    return SessionRefreshResult.offlineOrTransient;
  }

  /// Silently restores Supabase session in the background and connects PowerSync if online
  Future<void> tryAutoLoginOrSync() async {
    if (_isAutoLoggingIn || isSigningIn || isSigningOut) return;
    final savedUid = currentUserId;
    if (savedUid == null || savedUid.isEmpty || savedUid == 'local_guest') return;
    _isAutoLoggingIn = true;
    try {
      final result = await refreshOrRecoverSession();
      if (result == SessionRefreshResult.valid && isDatabaseInitialized) {
        unawaited(connectPowerSyncSafely());
      }
    } catch (e) {
      debugPrint('[AuthService] tryAutoLoginOrSync error: $e');
    } finally {
      _isAutoLoggingIn = false;
    }
  }

  /// Ensures an active, unexpired authenticated Supabase cloud session exists.
  /// Automatically refreshes expired JWT tokens when online without falsely expiring offline sessions.
  Future<bool> ensureAuthenticatedSession() async {
    final result = await refreshOrRecoverSession();
    return result == SessionRefreshResult.valid;
  }

  /// Purges prior account's in-memory caches and local synced tables whenever
  /// transitioning from a different authenticated user onto [newUid].
  Future<void> _purgePreviousAccountIfNeeded(
    String previousUid,
    String newUid,
  ) async {
    if (newUid.isEmpty ||
        previousUid.isEmpty ||
        previousUid == 'local_guest' ||
        previousUid == newUid) {
      return;
    }
    try {
      DailyPrayerStatusRepository().clearSessionState();
      FriendSearchRepository().inMemoryProfileCache.clear();
      FriendActivityRepository().clearSessionState();
      CacheService().clear();
      if (isDatabaseInitialized) {
        await db.disconnectAndClear().timeout(const Duration(seconds: 5));
      }
    } catch (e) {
      debugPrint('[AuthService] User switch disconnectAndClear notice: $e');
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not initialized');

    _authEpoch++;
    setSigningIn(true);
    try {
      final currentAuthUid = currentUserId;
      final previousUid = (currentAuthUid != null && currentAuthUid.isNotEmpty)
          ? currentAuthUid
          : ((_lastSavedSession?['user_id'] as String?) ?? '');

      final response = await client.auth
          .signInWithPassword(
            email: email.trim(),
            password: password,
          )
          .timeout(const Duration(seconds: 20));

      final uid = response.user?.id ?? '';
      final name = (response.user?.userMetadata?['display_name'] as String?) ??
          email.split('@').first;

      await _purgePreviousAccountIfNeeded(previousUid, uid);

      await saveLocalSession(
        userId: uid,
        email: email.trim(),
        displayName: name,
        plainPassword: rememberMe ? password : null,
      );

      if (!rememberMe) {
        await clearSavedCredentials();
      }

      _authEpoch++;
      setSigningIn(false);

      // Kick off post-login sync & notification tasks asynchronously so login returns immediately
      if (response.session != null && isDatabaseInitialized) {
        unawaited(connectPowerSyncSafely());
        unawaited(syncGlobalUserLevel());
        unawaited(PrayerTimeService().syncPrayers());
      }

      unawaited(() async {
        try {
          await HabitNotificationService()
              .cancelAllHabitReminders()
              .timeout(const Duration(seconds: 3));
          await HabitNotificationService().rescheduleAllHabits();
        } catch (_) {}
      }());

      return response;
    } catch (e) {
      debugPrint('[AuthService] Sign-in error: $e');
      rethrow;
    } finally {
      setSigningIn(false);
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

    _authEpoch++;
    setSigningIn(true);
    try {
      final currentAuthUid = currentUserId;
      final previousUid = (currentAuthUid != null && currentAuthUid.isNotEmpty)
          ? currentAuthUid
          : ((_lastSavedSession?['user_id'] as String?) ?? '');
      final cleanName =
          displayName.trim().isEmpty ? 'Operative' : displayName.trim();
      final response = await client.auth
          .signUp(
            email: email.trim(),
            password: password,
            data: {
              'display_name': cleanName,
            },
          )
          .timeout(const Duration(seconds: 20));

      final uid = response.user?.id ?? '';
      // Root-cause fix: also purge prior account caches and PowerSync tables on sign-up.
      await _purgePreviousAccountIfNeeded(previousUid, uid);
      await saveLocalSession(
        userId: uid,
        email: email.trim(),
        displayName: cleanName,
        plainPassword: password,
      );

      _authEpoch++;
      setSigningIn(false);

      // Auto-connect & reschedule notifications asynchronously without blocking UI
      if (response.session != null && isDatabaseInitialized) {
        unawaited(connectPowerSyncSafely());
        unawaited(syncGlobalUserLevel());
        unawaited(PrayerTimeService().syncPrayers());
      }

      unawaited(() async {
        try {
          await HabitNotificationService()
              .cancelAllHabitReminders()
              .timeout(const Duration(seconds: 3));
          await HabitNotificationService().rescheduleAllHabits();
        } catch (_) {}
      }());

      return response;
    } catch (e) {
      debugPrint('[AuthService] Sign-up error: $e');
      rethrow;
    } finally {
      setSigningIn(false);
    }
  }

  /// Fast, resilient sign out: preserves saved login credentials, terminates local & remote session
  /// with strict timeouts (never hangs offline), clears local SQLite user data once, and notifies router.
  Future<void> signOut() async {
    _authEpoch++;
    setSigningOut(true);
    try {
      // 0. Preserve non-guest email (and any existing encrypted password) BEFORE wiping local session
      final emailToPreserve = _nonEmpty(_lastSavedSession?['email'] as String?) ??
          _nonEmpty(currentUser?.email) ??
          savedEmail;
      final encToPreserve = _nonEmpty(_lastSavedSession?['encrypted_password'] as String?) ??
          _nonEmpty(_cachedPersistentCredentials?['encrypted_password']);
      final nameToPreserve = _nonEmpty(_lastSavedSession?['display_name'] as String?) ??
          _nonEmpty(currentUser?.userMetadata?['display_name'] as String?);
      if (emailToPreserve != null && !_isGuestEmail(emailToPreserve)) {
        await savePersistentCredentials(
          email: emailToPreserve,
          encryptedPassword: encToPreserve,
          displayName: nameToPreserve,
        );
      }

      // 1. Clear in-memory identity & caches immediately so active db.watch listeners
      // abort cleanly and cannot rewrite User A rows while signing out.
      _lastSavedSession = null;
      setCachedUserId('');
      sessionExpiredNotifier.value = false;
      sessionExpiredDismissedNotifier.value = false;
      try {
        DailyPrayerStatusRepository().clearSessionState();
      } catch (_) {}
      try {
        FriendSearchRepository().inMemoryProfileCache.clear();
      } catch (_) {}
      try {
        FriendActivityRepository().clearSessionState();
      } catch (_) {}
      CacheService().clear();

      // 2. Cancel habit notifications asynchronously (with timeout) so platform channels never stall logout
      unawaited(
        HabitNotificationService()
            .cancelAllHabitReminders()
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
          debugPrint('[AuthService] Clear habit notifications error: $e');
        }),
      );

      // 3. Immediately terminate any active focus session / audio / timer
      try {
        FocusSessionService().terminateSession();
      } catch (e) {
        debugPrint('[AuthService] Terminate focus session error: $e');
      }

      // 4. Terminate Supabase session FIRST with strict short timeouts so offline/slow networks
      // never stall logout. Note: GoTrue clears local session synchronously before the HTTP call.
      final client = _client;
      if (client != null) {
        final session = client.auth.currentSession;
        final canAttemptGlobalRevoke =
            NetworkService().isOnline && session != null && !session.isExpired;
        try {
          if (canAttemptGlobalRevoke) {
            await client.auth
                .signOut(scope: SignOutScope.global)
                .timeout(const Duration(seconds: 2));
          } else {
            await client.auth
                .signOut(scope: SignOutScope.local)
                .timeout(const Duration(milliseconds: 800));
          }
        } catch (e) {
          debugPrint('[AuthService] Supabase sign-out notice (local session already cleared): $e');
          // Ensure local session is cleared if global threw before clearing
          if (client.auth.currentSession != null) {
            try {
              await client.auth
                  .signOut(scope: SignOutScope.local)
                  .timeout(const Duration(milliseconds: 500));
            } catch (_) {}
          }
        }
      }

      // 5. Clear local SQLite database & auth session in a single bounded pass
      if (isDatabaseInitialized) {
        try {
          await clearUserDataOnSignOut().timeout(const Duration(seconds: 4));
        } catch (e) {
          debugPrint('[AuthService] Clear user data notice: $e');
          // Fallback: at minimum guarantee local_auth_session is removed
          try {
            await db.execute('DELETE FROM local_auth_session');
          } catch (_) {}
        }
      }

      // 6. Notify router & AuthBloc AFTER Supabase currentSession is cleared so hasActiveSession == false
      authStateNotifier.value = false;
    } catch (e) {
      debugPrint('[AuthService] Sign-out error: $e');
      authStateNotifier.value = false;
    } finally {
      _authEpoch++;
      setSigningOut(false);
    }
  }
}
