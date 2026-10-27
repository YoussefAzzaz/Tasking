import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui';
import 'package:window_manager/window_manager.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/core/config/app_config.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/habit_notification_service.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:device_preview/device_preview.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/data/reading_preferences_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/core/bloc/blocs.dart';

import 'dart:async';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Configure desktop window to simulate mobile phone form factor
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1440, 900),
      minimumSize: Size(1024, 700),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Axis Command Center',
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // System UI — transparent bars to let the canvas bleed edge-to-edge
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Initialize local SQLite + Supabase connector
  try {
    await openDatabase();
    await AuthService().init();
    unawaited(UserProfileRepository().getProfile());
  } catch (e, stack) {
    debugPrint('[Startup] Error initializing database or auth: $e\n$stack');
  }

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
    Future(
      () => AdhanAlarmService().init().catchError((e) {
        debugPrint('[Background] AdhanAlarmService init error: $e');
      }),
    ),
    Future(
      () => PrayerTimeService().init().catchError((e) {
        debugPrint('[Background] PrayerTimeService init error: $e');
      }),
    ),
    Future(
      () => HabitNotificationService().init().catchError((e) {
        debugPrint('[Background] HabitNotificationService init error: $e');
      }),
    ),
    Future(() {
      AppWidgetSyncService().syncAll();
      AppWidgetSyncService().startAutoSync();
    }),
    Future(
      () => ReadingPreferencesService().init().catchError((e) {
        debugPrint('[Background] ReadingPreferencesService init error: $e');
      }),
    ),
  ], eagerError: false);
}

class AxisApp extends StatelessWidget {
  const AxisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc()..add(const AuthCheckRequested()),
        ),
        BlocProvider<FocusSessionCubit>(create: (_) => FocusSessionCubit()),
        BlocProvider<TasksBloc>(create: (_) => TasksBloc()),
      ],
      child: MaterialApp.router(
        title: 'Axis',
        locale: DevicePreview.locale(context),
        builder: DevicePreview.appBuilder,
        debugShowCheckedModeBanner: false,
        theme: AxisTheme.dark,
        darkTheme: AxisTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: router,
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.mouse,
            PointerDeviceKind.touch,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
      ),
    );
  }
}
