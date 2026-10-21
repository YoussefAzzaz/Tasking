import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/core/config/app_config.dart';

/// Network Connectivity Service using direct TCP socket handshakes to Supabase.
///
/// Sends a TCP packet (SYN) to the Supabase host on port 443.
/// If a response (SYN-ACK) is received, the device is verified ONLINE.
/// If no response is received (timeout, socket exception, host unreachable), the device is verified OFFLINE.
class NetworkService with WidgetsBindingObserver {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);
  bool get isOnline => isOnlineNotifier.value;

  Timer? _monitorTimer;
  bool _isChecking = false;
  bool _observerRegistered = false;

  /// Sends a TCP packet to Supabase port 443 and awaits a response.
  /// Returns true if a response was received (Online), false otherwise (Offline).
  Future<bool> checkSupabaseConnectivity({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_isChecking) return isOnline;
    _isChecking = true;

    Socket? socket;
    bool connected = false;

    try {
      final url = AppConfig.supabaseUrl;
      final uri = Uri.parse(url);
      final host = uri.host.isNotEmpty ? uri.host : 'hzyvdkgdkxbxooatrzwy.supabase.co';
      final port = (uri.hasPort && uri.port != 0) ? uri.port : 443;

      // TCP Handshake: sends SYN and awaits SYN-ACK response
      try {
        socket = await Socket.connect(host, port, timeout: timeout);
        connected = true;
      } catch (socketError) {
        // Fallback: If raw TCP socket is blocked by network carrier/proxy, try HTTPS request
        try {
          final client = HttpClient()..connectionTimeout = timeout;
          final request = await client.getUrl(Uri.parse('$url/rest/v1/'));
          final response = await request.close().timeout(timeout);
          client.close(force: true);
          connected = response.statusCode > 0;
        } catch (_) {
          connected = false;
        }
      }
    } catch (_) {
      connected = false;
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
      _isChecking = false;
    }

    final previousState = isOnlineNotifier.value;
    isOnlineNotifier.value = connected;

    // Handle state transitions
    if (previousState != connected) {
      if (connected) {
        debugPrint('[NetworkService] TCP response received from Supabase -> ONLINE. Reconnecting PowerSync sync.');
        _handleBackOnline();
      } else {
        debugPrint('[NetworkService] No response from Supabase -> OFFLINE. Operating with local SQLite.');
        _handleWentOffline();
      }
    }

    return connected;
  }

  void _handleBackOnline() {
    if (!isDatabaseInitialized) return;
    try {
      if (AuthService().hasActiveSession) {
        AuthService().tryAutoLoginOrSync();
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

  /// Starts periodic TCP connectivity heartbeat to monitor network status
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
