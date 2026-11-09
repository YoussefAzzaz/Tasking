import 'package:flutter/foundation.dart';

/// Centralized application configuration.
/// Values can be supplied at build/run time using:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=POWERSYNC_URL=...
/// When omitted, default cloud backend credentials are used seamlessly in both debug and release builds.
abstract final class AppConfig {
  static const String _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _envPowerSyncUrl = String.fromEnvironment('POWERSYNC_URL');

  // Default credentials for cloud backend & offline preview
  static const String _defaultSupabaseUrl = 'https://hzyvdkgdkxbxooatrzwy.supabase.co';
  static const String _defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6eXZka2dka3hieG9vYXRyend5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0NDkyOTAsImV4cCI6MjEwODAyNTI5MH0.qZRq2nz-vdipPqdmtIZZXstlub7q4HTUZmgIxsSUWlA';
  static const String _defaultPowerSyncUrl =
      'https://6ad7e4283b1803753bd362b7.powersync.journeyapps.com';

  static String get supabaseUrl {
    if (_envSupabaseUrl.isNotEmpty) return _envSupabaseUrl;
    if (kReleaseMode) {
      debugPrint('[AppConfig] Notice: SUPABASE_URL not supplied via --dart-define; using default cloud endpoint.');
    }
    return _defaultSupabaseUrl;
  }

  static String get supabaseAnonKey {
    if (_envSupabaseAnonKey.isNotEmpty) return _envSupabaseAnonKey;
    if (kReleaseMode) {
      debugPrint('[AppConfig] Notice: SUPABASE_ANON_KEY not supplied via --dart-define; using default anon key.');
    }
    return _defaultSupabaseAnonKey;
  }

  static String get powerSyncUrl {
    if (_envPowerSyncUrl.isNotEmpty) return _envPowerSyncUrl;
    if (kReleaseMode) {
      debugPrint('[AppConfig] Notice: POWERSYNC_URL not supplied via --dart-define; using default endpoint.');
    }
    return _defaultPowerSyncUrl;
  }

  static const bool useDevicePreview = bool.fromEnvironment(
    'DEVICE_PREVIEW',
    defaultValue: false,
  );
}
