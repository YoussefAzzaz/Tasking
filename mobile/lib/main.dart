import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

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

  // Initialize Focus session background service & notification channel
  await FocusSessionService().init();

  // Initialize Adhan notification & Fajr wake-up alarm service
  await AdhanAlarmService().init();

  // Initialize Islamic prayer times & daily prayer habits
  await PrayerTimeService().init();

  // Sync on-screen Android home widgets and start real-time reactive sync
  AppWidgetSyncService().syncAll();
  AppWidgetSyncService().startAutoSync();

  runApp(const AxisApp());
}

class AxisApp extends StatelessWidget {
  const AxisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Axis',
      debugShowCheckedModeBanner: false,
      theme: AxisTheme.dark,
      darkTheme: AxisTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
