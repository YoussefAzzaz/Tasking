import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/ui/tasks/tasks_screen.dart';
import 'package:axis/ui/today/today_screen.dart';
import 'package:axis/ui/habits/habits_screen.dart';
import 'package:axis/ui/notes/notes_screen.dart';
import 'package:axis/ui/me/me_screen.dart';
import 'package:axis/ui/focus/focus_screen.dart';
import 'package:axis/ui/friends/friends_screen.dart';
import 'package:axis/ui/common/splash_screen.dart';
import 'package:axis/ui/auth/auth_screen.dart';
import 'package:axis/ui/calendar/calendar_screen.dart';
import 'package:axis/ui/debug/adhan_alarm_debug_screen.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/core/widget_navigation_service.dart';
import 'package:axis/ui/shell/app_shell.dart';

export 'package:axis/ui/shell/app_shell.dart';
export 'package:axis/ui/shell/floating_focus_session_bar.dart';

/// Global navigator key for presenting system-wide dialogs and alarms
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration with IndexedStack state persistence
final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  refreshListenable: AuthService().authStateNotifier,
  redirect: (context, state) {
    final auth = AuthService();
    final isAuthenticated = auth.isAuthenticated;
    final hasSession = auth.hasActiveSession;
    final isAuthRoute = state.matchedLocation == '/auth';
    final isSplashRoute = state.matchedLocation == '/splash';

    if (isSplashRoute) return null;

    if (!hasSession && !isAuthRoute) {
      return '/auth';
    }
    // Only redirect away from /auth if the user has an actual authenticated cloud account.
    // Local guests MUST be allowed to open /auth to sign in or register!
    if (isAuthenticated && isAuthRoute) {
      return WidgetNavigationService().resolveInitialAuthenticatedRoute();
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/habits',
              builder: (context, state) => const HabitsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/today',
              builder: (context, state) => const TodayScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/notes',
              builder: (context, state) => const NotesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/friends',
              builder: (context, state) => const FriendsScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/calendar',
      builder: (context, state) => const CalendarScreen(),
    ),
    GoRoute(
      path: '/me',
      builder: (context, state) => const MeScreen(),
    ),
    GoRoute(
      path: '/focus',
      builder: (context, state) => const FocusScreen(),
    ),
    GoRoute(
      path: '/badges',
      builder: (context, state) => const MasteryBadgesScreen(),
    ),
    GoRoute(
      path: '/debug/adhan-alarm',
      builder: (context, state) => const AdhanAlarmDebugScreen(),
    ),
  ],
);
