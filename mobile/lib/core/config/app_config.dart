/// Centralized application configuration.
/// Values should be supplied at build/run time using:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=POWERSYNC_URL=...
abstract final class AppConfig {
  static const String _envSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envSupabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _envPowerSyncUrl = String.fromEnvironment('POWERSYNC_URL');

  // Development sandbox credentials for local offline preview
  static const String _devSupabaseUrl = 'https://hzyvdkgdkxbxooatrzwy.supabase.co';
  static const String _devSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh6eXZka2dka3hieG9vYXRyend5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0NDkyOTAsImV4cCI6MjEwODAyNTI5MH0.qZRq2nz-vdipPqdmtIZZXstlub7q4HTUZmgIxsSUWlA';
  static const String _devPowerSyncUrl =
      'https://6ad7e4283b1803753bd362b7.powersync.journeyapps.com';

  static String get supabaseUrl {
    if (_envSupabaseUrl.isNotEmpty) return _envSupabaseUrl;
    return _devSupabaseUrl;
  }

  static String get supabaseAnonKey {
    if (_envSupabaseAnonKey.isNotEmpty) return _envSupabaseAnonKey;
    return _devSupabaseAnonKey;
  }

  static String get powerSyncUrl {
    if (_envPowerSyncUrl.isNotEmpty) return _envPowerSyncUrl;
    return _devPowerSyncUrl;
  }

  static const bool useDevicePreview = bool.fromEnvironment(
    'DEVICE_PREVIEW',
    defaultValue: false,
  );
}
