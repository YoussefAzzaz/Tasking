import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:device_preview/device_preview.dart';

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

  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const AxisApp(),
    ),
  );

  // Launch non-critical background services asynchronously without blocking UI startup
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  try {
    await FocusSessionService().init();
    await PrayerTimeService().init();
    await AdhanAlarmService().init();
    AppWidgetSyncService().syncAll();
    AppWidgetSyncService().startAutoSync();
  } catch (e) {
    debugPrint('Background services initialization error: $e');
  }
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
