import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/core/security/secure_credential_vault.dart';
import 'package:axis/core/widget_navigation_service.dart';
import 'package:axis/core/desktop_scroll_behavior.dart';
import 'package:axis/core/config/app_config.dart';
import 'package:axis/data/powersync_db.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/app_widget_sync_service.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/habit_notification_service.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:device_preview/device_preview.dart';
import 'package:axis/data/network_service.dart';
import 'package:axis/data/reading_preferences_service.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/core/l10n/locale_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/core/bloc/blocs.dart';
import 'package:axis/data/updates/app_update_service.dart';
import 'package:axis/ui/common/updates/update_notice_modal.dart';
import 'dart:async';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

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

    // Apply window options and show window after the first frame has rendered,
    // avoiding the Linux GTK OpenGL frame timeout (have 0x0) during startup.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
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
    await SecureCredentialVault.init();
    await AuthService().init();
    await Future.wait([
      LocaleService().init(),
      WidgetNavigationService().init(),
    ]);
    unawaited(UserProfileRepository().getProfile());
  } catch (e, stack) {
    debugPrint('[Startup] Error initializing database or auth: $e\n$stack');
  }

  // Global error boundary for rendering exceptions
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return GlobalErrorWidget(details: details);
  };

  // Instant UI startup — mount widget tree immediately without network blocking
  // Only wrap with DevicePreview in debug/dev builds — do NOT include it in
  // the widget tree at all when disabled (even `enabled: false` adds overhead).
  if (AppConfig.useDevicePreview) {
    runApp(DevicePreview(
      enabled: true,
      builder: (context) => const AxisApp(),
    ));
  } else {
    runApp(const AxisApp());
  }

  // Check if app was woken up from terminated state by a notification action / fullScreenIntent
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationController.checkInitialNotificationAction();
    AdhanAlarmService().checkPendingNativeAdhanLaunch();
    AwesomeNotifications().setGlobalBadgeCounter(0).catchError((_) {});
  });

  // Launch non-critical background services asynchronously without blocking UI startup
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  // 0. Start connectivity monitoring immediately so offline launches detect offline fast
  NetworkService().startMonitoring();

  // 1. Asynchronous auto-sync without blocking cold launch
  unawaited(() async {
    try {
      if (AuthService().hasActiveSession) {
        await AuthService().tryAutoLoginOrSync();
        await ensurePowerSyncConnected();
        if (NetworkService().isOnline) {
          await FriendRepository().syncAllFriendData();
        }
      }
    } catch (e) {
      debugPrint('[Background] Startup auth & friend sync notice: $e');
    }
  }());

  // 2. Initialize notification channels and saved Adhan preferences BEFORE
  // scheduling prayers so PrayerTimeService never races AdhanSoundService.
  try {
    await FocusSessionService().init();
  } catch (e) {
    debugPrint('[Background] FocusSessionService/Notification init error: $e');
  }

  try {
    await AdhanAlarmService().init();
  } catch (e) {
    debugPrint('[Background] AdhanAlarmService init error: $e');
  }

  // 3. Parallel background service inits once notification & Adhan sound state are ready
  await Future.wait<void>([
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
    Future(
      () => FriendActivityRepository().purgeOldLogs().catchError((e) {
        debugPrint('[Background] purgeOldLogs error: $e');
      }),
    ),
  ], eagerError: false);
}

class AxisApp extends StatefulWidget {
  const AxisApp({super.key});

  @override
  State<AxisApp> createState() => _AxisAppState();
}

class _AxisAppState extends State<AxisApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && WidgetNavigationService().launchedFromWidget) {
      FlutterNativeSplash.remove();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerAutoUpdateCheck();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AwesomeNotifications().setGlobalBadgeCounter(0).catchError((_) {});
      unawaited(AppWidgetSyncService().syncAll());
      _triggerAutoUpdateCheck(fromResume: true);
    }
  }

  Future<void> _triggerAutoUpdateCheck({bool fromResume = false}) async {
    // Root-cause fix: Auto-update prompts previously ran in 3 separate widgets
    // (AxisApp, AxisHeader, DesktopCommandCenter) plus every lifecycle resume,
    // omitted `dismissedVersion` and `currentVersion`, and stacked dialogs.
    // Centralize here with cooldown, dismissal/session gating, and real version.
    final updateService = AppUpdateService();
    if (fromResume && updateService.isAutoCheckOnCooldown) return;
    if (UpdateNoticeModal.isShowing) return;

    try {
      final update = await updateService.checkForUpdate();
      if (update == null || !mounted) return;
      final currentVer = await updateService.getInstalledVersion();
      if (!mounted) return;
      if (!updateService.shouldAutoPrompt(update, currentVer)) return;
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted && !UpdateNoticeModal.isShowing) {
        updateService.markAutoPrompted(update.version);
        UpdateNoticeModal.show(
          ctx,
          updateInfo: update,
          currentVersion: currentVer.displayVersion,
          updateService: updateService,
        );
      }
    } catch (e) {
      debugPrint('[AutoUpdate] Error during auto update check: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc()..add(const AuthCheckRequested()),
        ),
        BlocProvider<FocusSessionCubit>(create: (_) => FocusSessionCubit()),
        BlocProvider<TasksBloc>(create: (_) => TasksBloc()),
      ],
      child: BlocBuilder<LocaleCubit, Locale>(
        builder: (context, activeLocale) {
          return MaterialApp.router(
            title: 'Axis',
            locale: AppConfig.useDevicePreview
                ? (DevicePreview.locale(context) ?? activeLocale)
                : activeLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              Widget appChild = child ?? const SizedBox.shrink();
              if (AppConfig.useDevicePreview) {
                appChild = DevicePreview.appBuilder(context, appChild);
              }
              return appChild;
            },
            debugShowCheckedModeBanner: false,
            theme: AxisTheme.dark,
            darkTheme: AxisTheme.dark,
            themeMode: ThemeMode.dark,
            routerConfig: router,
            scrollBehavior: const DesktopScrollBehavior(),
          );
        },
      ),
    );
  }
}

/// Global error boundary widget that safely displays exceptions without crashing
/// the application shell or showing an unstyled red screen.
class GlobalErrorWidget extends StatelessWidget {
  const GlobalErrorWidget({super.key, required this.details});
  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    return Material(
      color: AxisColors.canvasBase,
      child: Directionality(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        child: Center(
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderGlass2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AxisColors.warning.withValues(alpha: 0.15),
                    border: Border.all(color: AxisColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: AxisColors.warning, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  isAr ? 'تم اكتشاف خلل مؤقت في الواجهة' : 'WORKSPACE ANOMALY DETECTED',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AxisColors.textHigh,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  kDebugMode
                      ? details.exceptionAsString()
                      : (isAr
                          ? 'حدث خطأ مؤقت في العرض. بياناتك محفوظة بأمان محلياً.'
                          : 'A transient rendering issue occurred. Your data is safely stored in local SQLite.'),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AxisColors.textMuted),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    try {
                      router.go('/today');
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(isAr ? 'إعادة تحميل مساحة العمل' : 'Reload Workspace'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AxisColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
