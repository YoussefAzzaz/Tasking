import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Outcome of attempting to refresh or silently recover a cloud session.
enum SessionRefreshResult {
  /// Active, unexpired Supabase session is ready for cloud sync.
  valid,

  /// Device is offline or encountered a transient network/server error.
  /// Local offline session remains completely valid; NEVER show session-expired.
  offlineOrTransient,

  /// Supabase explicitly rejected the refresh token / credentials as invalid or revoked.
  expired,

  /// No cloud account session exists (unauthenticated or local guest).
  unauthenticated,
}

/// Classifies Supabase Auth exceptions cleanly so transient offline failures
/// never lock out local accounts while server-revoked tokens trigger re-auth.
class AuthErrorClassifier {
  AuthErrorClassifier._();

  static const Set<String> _permanentCodes = {
    'invalid_grant',
    'refresh_token_not_found',
    'refresh_token_already_used',
    'invalid_credentials',
    'user_not_found',
    'user_banned',
    'session_not_found',
    'session_expired',
    'bad_jwt',
  };

  static bool isNetworkOrRetryableError(Object error) {
    if (error is AuthRetryableFetchException) return true;
    if (error is SocketException ||
        error is TimeoutException ||
        error is HandshakeException ||
        error is HttpException ||
        error is TlsException) {
      return true;
    }
    if (error is AuthException) {
      final code = error.statusCode;
      if (code == '500' ||
          code == '502' ||
          code == '503' ||
          code == '504' ||
          code == '408' ||
          code == '429' ||
          code == '0') {
        return true;
      }
    }
    final lower = error.toString().toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('connection closed') ||
        lower.contains('connection terminated') ||
        lower.contains('software caused connection abort') ||
        lower.contains('timed out') ||
        lower.contains('timeoutexception') ||
        lower.contains('clientexception') ||
        lower.contains('handshakeexception') ||
        lower.contains('no address associated with hostname') ||
        lower.contains('authretryablefetchexception') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('failed to fetch');
  }

  static bool isPermanentAuthError(Object error) {
    if (isNetworkOrRetryableError(error)) return false;
    if (error is AuthSessionMissingException) return true;

    if (error is AuthApiException) {
      if (error.code != null && _permanentCodes.contains(error.code!.toLowerCase())) {
        return true;
      }
      if (error.statusCode == '400' ||
          error.statusCode == '401' ||
          error.statusCode == '403') {
        return true;
      }
    }

    if (error is AuthException) {
      if (error.code != null && _permanentCodes.contains(error.code!.toLowerCase())) {
        return true;
      }
      if (error.statusCode == '400' ||
          error.statusCode == '401' ||
          error.statusCode == '403') {
        return true;
      }
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid refresh token') ||
          msg.contains('refresh token not found') ||
          msg.contains('already used') ||
          msg.contains('invalid_grant') ||
          msg.contains('invalid login credentials') ||
          msg.contains('session_not_found') ||
          msg.contains('session not found') ||
          msg.contains('user not found') ||
          msg.contains('user_banned') ||
          msg.contains('bad_jwt')) {
        return true;
      }
    }

    return false;
  }
}
