import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/auth_service.dart';

/// Handles cold-start and warm-resume deep-link routing when the user taps an
/// Android/iOS home screen widget (e.g., opening `/habits` from Habit Streak widget).
class WidgetNavigationService {
  static final WidgetNavigationService _instance = WidgetNavigationService._();
  factory WidgetNavigationService() => _instance;
  WidgetNavigationService._();

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  String? _pendingRoute;
  bool _launchedFromWidget = false;
  StreamSubscription<Uri?>? _clickSub;
  bool _initialized = false;

  String? get pendingRoute => _pendingRoute;
  bool get launchedFromWidget => _launchedFromWidget;

  /// Resolves an app route from a home-screen widget launch [Uri].
  static String? routeFromUri(Uri? uri) {
    if (uri == null) return null;
    final raw = uri.toString().trim().toLowerCase();
    if (raw.isEmpty) return null;

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    if (path.contains('habits') ||
        (host == 'widget' && path.startsWith('/habits')) ||
        host == 'habits' ||
        raw.contains('widget/habits')) {
      return '/habits';
    }
    if (path.contains('today') ||
        path.contains('prayers') ||
        (host == 'widget' && (path.startsWith('/today') || path.startsWith('/prayers'))) ||
        raw.contains('widget/today') ||
        raw.contains('widget/prayers')) {
      return '/today';
    }
    return null;
  }

  /// Stores a pending route for unit testing or deferred redirect handling.
  @visibleForTesting
  void setPendingRouteForTesting(String? route, {bool launchedFromWidget = false}) {
    _pendingRoute = route;
    _launchedFromWidget = launchedFromWidget;
  }

  /// Initializes cold-start check and listens to warm widget tap events.
  Future<void> init() async {
    if (_initialized || !isSupportedPlatform) return;
    _initialized = true;

    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      final route = routeFromUri(initialUri);
      if (route != null) {
        _pendingRoute = route;
        _launchedFromWidget = true;
      }
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('[WidgetNavigationService] initial launch check error: $e');
      }
    }

    try {
      await _clickSub?.cancel();
      _clickSub = HomeWidget.widgetClicked.listen((uri) {
        final route = routeFromUri(uri);
        if (route == null) return;
        _launchedFromWidget = true;
        _pendingRoute = route;
        _navigateImmediatelyIfReady();
      });
    } catch (e) {
      if (e is! MissingPluginException) {
        debugPrint('[WidgetNavigationService] click stream error: $e');
      }
    }
  }

  void _navigateImmediatelyIfReady() {
    if (!AuthService().hasActiveSession) return;
    try {
      final location = router.routerDelegate.currentConfiguration.uri.path;
      final target = consumePendingRoute();
      if (target != null && location != target) {
        router.go(target);
      }
    } catch (e) {
      debugPrint('[WidgetNavigationService] immediate navigation notice: $e');
    }
  }

  /// Returns and clears any pending deep-link route from a widget tap.
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Returns the target route for an authenticated user (pending widget route or `/today`).
  String resolveInitialAuthenticatedRoute() {
    _launchedFromWidget = false;
    return consumePendingRoute() ?? '/today';
  }

  Future<void> dispose() async {
    await _clickSub?.cancel();
    _clickSub = null;
    _initialized = false;
    _launchedFromWidget = false;
  }
}
