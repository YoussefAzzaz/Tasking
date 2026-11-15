import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/core/config/app_config.dart';

/// Network Connectivity Service using resilient multi-tier connectivity detection.
///
/// Combines DNS lookup, HTTPS REST heartbeat to Supabase, and fallback probes to verify connectivity.
class NetworkService with WidgetsBindingObserver {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool get isOnline => isOnlineNotifier.value;

  Timer? _monitorTimer;
  bool _isChecking = false;
  bool _observerRegistered = false;
  int _consecutiveFailures = 0;

  /// Checks reachability to Supabase and general internet.
  /// Returns true if verified online, false otherwise.
  Future<bool> checkSupabaseConnectivity({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    if (_isChecking) return isOnline;
    _isChecking = true;

    bool connected = false;

    try {
      final url = AppConfig.supabaseUrl;
      final uri = Uri.parse(url);
      final host = uri.host.isNotEmpty ? uri.host : 'hzyvdkgdkxbxooatrzwy.supabase.co';
      final port = (uri.hasPort && uri.port != 0) ? uri.port : 443;

      // 1. Primary: DNS address resolution to the Supabase backend host
      try {
        final addresses = await InternetAddress.lookup(host).timeout(timeout);
        if (addresses.isNotEmpty && addresses.first.rawAddress.isNotEmpty) {
          connected = true;
        }
      } catch (_) {}

      // 2. Secondary: Active HTTPS REST heartbeat to Supabase with anon key
      if (!connected) {
        try {
          final client = HttpClient()..connectionTimeout = timeout;
          final request = await client.getUrl(Uri.parse('$url/rest/v1/user_profiles?select=id&limit=1'));
          request.headers.add('apikey', AppConfig.supabaseAnonKey);
          final response = await request.close().timeout(timeout);
          client.close(force: true);
          connected = response.statusCode > 0;
        } catch (_) {}
      }

      // 3. Tertiary: Fallback raw socket connect
      if (!connected) {
        Socket? socket;
        try {
          socket = await Socket.connect(host, port, timeout: timeout);
          connected = true;
        } catch (_) {
        } finally {
          try {
            socket?.destroy();
          } catch (_) {}
        }
      }

      // 4. Quaternary: General internet fallback (e.g. if Supabase DNS is slow)
      if (!connected) {
        try {
          final fallbackLookup = await InternetAddress.lookup('google.com').timeout(timeout);
          if (fallbackLookup.isNotEmpty && fallbackLookup.first.rawAddress.isNotEmpty) {
            connected = true;
          }
        } catch (_) {}
      }
    } catch (_) {
      connected = false;
    } finally {
      _isChecking = false;
    }

    final previousState = isOnlineNotifier.value;

    if (connected) {
      _consecutiveFailures = 0;
      isOnlineNotifier.value = true;
      if (!previousState) {
        debugPrint('[NetworkService] Reconnected to cloud backend -> ONLINE. Reconnecting sync.');
        _handleBackOnline();
      }
    } else {
      _consecutiveFailures++;
      // Require 2 consecutive failed attempts before transitioning to OFFLINE to ignore transient jitter
      if (_consecutiveFailures >= 2) {
        isOnlineNotifier.value = false;
        if (previousState) {
          debugPrint('[NetworkService] Backend unreachable -> OFFLINE. Operating with local SQLite.');
          _handleWentOffline();
        }
      }
    }

    return connected;
  }

  void _handleBackOnline() {
    if (!isDatabaseInitialized) return;
    try {
      if (AuthService().hasActiveSession) {
        unawaited(AuthService().tryAutoLoginOrSync());
        unawaited(FriendRepository().syncAllFriendData());
      }
      if (!isPowerSyncConnectedOrConnecting) {
        unawaited(connectPowerSyncSafely());
      }
    } catch (e) {
      debugPrint('[NetworkService] Error reconnecting sync: $e');
    }
  }

  void _handleWentOffline() {
    // PowerSync is an offline-first SQLite database that manages local mutations
    // seamlessly. We must NOT call db.disconnect() here because doing so interrupts
    // local write queues and causes mid-operation edits/deletions to be dropped.
    debugPrint('[NetworkService] Switched to offline mode. Continuing with local SQLite.');
  }

  /// Starts periodic connectivity heartbeat to monitor network status
  void startMonitoring({Duration interval = const Duration(seconds: 15)}) {
    _monitorTimer?.cancel();
    try {
      if (!_observerRegistered) {
        WidgetsBinding.instance.addObserver(this);
        _observerRegistered = true;
      }
    } catch (_) {}

    // Run initial check immediately
    checkSupabaseConnectivity();
    _monitorTimer = Timer.periodic(interval, (_) {
      checkSupabaseConnectivity();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkSupabaseConnectivity();
      if (AuthService().hasActiveSession) {
        unawaited(ensurePowerSyncConnected());
      }
    }
  }

  /// Stops periodic monitoring
  void stopMonitoring() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    if (_observerRegistered) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _observerRegistered = false;
    }
  }
}
