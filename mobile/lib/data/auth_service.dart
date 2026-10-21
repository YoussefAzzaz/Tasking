import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/focus_session_service.dart';

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

  Map<String, dynamic>? get lastSavedSession => _lastSavedSession;

  /// Current authenticated Supabase user
  User? get currentUser => _client?.auth.currentUser;

  /// Current session with access token
  Session? get currentSession => _client?.auth.currentSession;

  /// Whether a user is actively authenticated or has a valid offline session saved locally
  bool get isAuthenticated => hasActiveSession;

  /// True if there is an active Supabase session OR an existing saved local offline session
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

  /// Initialize and load saved local auth session from SQLite
  Future<void> init() async {
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
          'cached_password': null,
          'last_login_at': DateTime.now().toUtc().toIso8601String(),
        };
        await db.execute('''
          INSERT OR REPLACE INTO local_auth_session (
            id, user_id, email, display_name, cached_password, last_login_at
          ) VALUES (?, ?, ?, ?, ?, ?)
        ''', [
          'active_session',
          uid,
          email,
          name,
          null,
          DateTime.now().toUtc().toIso8601String(),
        ]);
      }
      await purgeForeignUserData();
    } catch (e) {
      debugPrint('[AuthService] Error reading local auth session: $e');
    }
  }

  /// Persist session and login credentials locally in SQLite for offline access and auto-login
  Future<void> saveLocalSession({
    required String userId,
    required String email,
    required String password,
    String? displayName,
  }) async {
    setCachedUserId(userId);
    _lastSavedSession = {
      'id': 'active_session',
      'user_id': userId,
      'email': email,
      'display_name': displayName,
      'cached_password': password,
      'last_login_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (isDatabaseInitialized) {
      try {
        await db.execute('''
          INSERT OR REPLACE INTO local_auth_session (
            id, user_id, email, display_name, cached_password, last_login_at
          ) VALUES (?, ?, ?, ?, ?, ?)
        ''', [
          'active_session',
          userId,
          email,
          displayName,
          password,
          DateTime.now().toUtc().toIso8601String(),
        ]);
        await purgeForeignUserData();
      } catch (e) {
        debugPrint('[AuthService] Error persisting local auth session: $e');
      }
    }
  }

  /// Clear the local auth session from memory and SQLite
  Future<void> clearLocalSession() async {
    _lastSavedSession = null;
    setCachedUserId('');
    if (isDatabaseInitialized) {
      try {
        await db.execute('DELETE FROM local_auth_session WHERE id = ?', ['active_session']);
      } catch (e) {
        debugPrint('[AuthService] Error clearing local auth session: $e');
      }
    }
  }

  /// Silently restores Supabase session in the background and connects PowerSync if online
  Future<void> tryAutoLoginOrSync() async {
    if (_isAutoLoggingIn) return;
    _isAutoLoggingIn = true;
    try {
      final client = _client;
      if (client == null) return;

      // 1. If Supabase session is already alive, connect PowerSync if not connected
      if (client.auth.currentSession != null) {
        if (isDatabaseInitialized && !db.connected) {
          db.connect(connector: SupabaseConnector());
        }
        return;
      }

      // 2. If no active session, attempt silent login using saved credentials
      final email = _lastSavedSession?['email'] as String?;
      final password = _lastSavedSession?['cached_password'] as String?;

      if (email != null &&
          password != null &&
          email.isNotEmpty &&
          password.isNotEmpty) {
        try {
          final res = await client.auth.signInWithPassword(
            email: email.trim(),
            password: password,
          );
          if (res.session != null && isDatabaseInitialized) {
            db.connect(connector: SupabaseConnector());
          }
        } catch (e) {
          debugPrint('[AuthService] Background auto-login skipped (offline/network): $e');
        }
      }
    } catch (e) {
      debugPrint('[AuthService] tryAutoLoginOrSync error: $e');
    } finally {
      _isAutoLoggingIn = false;
    }
  }

  /// Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not initialized');

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final uid = response.user?.id ?? '';
      final name = (response.user?.userMetadata?['display_name'] as String?) ??
          email.split('@').first;

      await saveLocalSession(
        userId: uid,
        email: email.trim(),
        password: password,
        displayName: name,
      );

      // Connect PowerSync with new user credentials
      if (response.session != null && isDatabaseInitialized) {
        db.connect(connector: SupabaseConnector());
      }

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
        password: password,
        displayName: cleanName,
      );

      // Auto-connect if session is immediately active
      if (response.session != null && isDatabaseInitialized) {
        db.connect(connector: SupabaseConnector());
      }

      return response;
    } catch (e) {
      debugPrint('[AuthService] Sign-up error: $e');
      rethrow;
    }
  }

  /// Secure sign out: terminates any active sessions, disconnects PowerSync, clears local SQLite user data and terminates remote session
  Future<void> signOut() async {
    try {
      // 1. Immediately terminate any active focus session / audio / timer
      try {
        FocusSessionService().terminateSession();
      } catch (e) {
        debugPrint('[AuthService] Terminate focus session error: $e');
      }

      // 2. Clear local SQLite database & session
      if (isDatabaseInitialized) {
        try {
          await db.disconnect();
        } catch (e) {
          debugPrint('[AuthService] PowerSync disconnect error: $e');
        }
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
      }

      // 3. Terminate active remote session on Supabase
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
    } catch (e) {
      debugPrint('[AuthService] Sign-out error: $e');
    }
  }
}
