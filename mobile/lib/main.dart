import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/core/config/app_config.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:device_preview/device_preview.dart';
import 'package:axis/data/network_service.dart';

import 'dart:async';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // System UI — transparent bars to let the canvas bleed edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize local SQLite + Supabase connector
  await openDatabase();
  await AuthService().init();

  // Instant UI startup — mount widget tree immediately without network blocking
  runApp(
    DevicePreview(
      enabled: AppConfig.useDevicePreview,
      builder: (context) => const AxisApp(),
    ),
  );

  // Launch non-critical background services asynchronously without blocking UI startup
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  // 1. Asynchronous network probe & auto-sync without blocking cold launch
  unawaited(() async {
    try {
      final isOnline = await NetworkService().checkSupabaseConnectivity();
      if (isOnline && AuthService().hasActiveSession) {
        await AuthService().tryAutoLoginOrSync();
      }
    } catch (e) {
      debugPrint('[Background] Connectivity probe error: $e');
    }
  }());

  // 2. Deterministic notification engine initialization first
  try {
    await FocusSessionService().init();
  } catch (e) {
    debugPrint('[Background] FocusSessionService/Notification init error: $e');
  }

  // 3. Parallel background service inits once notification channels are verified active
  await Future.wait<void>([
    Future(() => NetworkService().startMonitoring()),
    Future(() => AdhanAlarmService().init().catchError((e) {
      debugPrint('[Background] AdhanAlarmService init error: $e');
    })),
    Future(() => PrayerTimeService().init().catchError((e) {
      debugPrint('[Background] PrayerTimeService init error: $e');
    })),
    Future(() {
      AppWidgetSyncService().syncAll();
      AppWidgetSyncService().startAutoSync();
    }),
  ], eagerError: false);
}

class AxisApp extends StatelessWidget {
  const AxisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Axis',
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
      debugShowCheckedModeBanner: false,
      theme: AxisTheme.dark,
      darkTheme: AxisTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
