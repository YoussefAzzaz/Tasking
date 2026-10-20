import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/tasks/tasks_screen.dart';
import 'package:axis/ui/tasks/quick_add_sheet.dart';
import 'package:axis/ui/today/today_screen.dart';
import 'package:axis/ui/habits/habits_screen.dart';
import 'package:axis/ui/notes/notes_screen.dart';
import 'package:axis/ui/me/me_screen.dart';
import 'package:axis/ui/focus/focus_screen.dart';
import 'package:axis/ui/common/splash_screen.dart';
import 'package:axis/data/powersync_db.dart' show globalUserLevel;

// Bottom nav slots (5 real tabs — Me is 5th)
// Bar layout: Today | Tasks | [+] | Habits | Notes
// Me is reachable via profile avatar in the app header

const _tabIcons = [
  Icons.today_rounded,
  Icons.check_box_outlined,
  Icons.loop_rounded,
  Icons.edit_note_rounded,
  Icons.person_outline_rounded,
];

const _tabLabels = ['Today', 'Tasks', 'Habits', 'Notes', 'Me'];

/// App shell with header + 5-tab bottom nav + Quick-Add orb using IndexedStack
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _onTabTap(BuildContext context, int barIdx) {
    // barIdx: 0=Today 1=Tasks 2=QA-orb 3=Habits 4=Notes
    if (barIdx == 2) {
      _showQuickAdd(context);
      return;
    }
    // map bar idx → branch idx (skip the orb at position 2)
    final branchIdx = barIdx > 2 ? barIdx - 1 : barIdx;
    navigationShell.goBranch(
      branchIdx,
      initialLocation: branchIdx == navigationShell.currentIndex,
    );
  }

  void _showQuickAdd(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddSheet(onTaskAdded: () {}),
    );
  }

  void _openMe() {
    navigationShell.goBranch(4); // branch 4 is '/me'
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: Column(
        children: [
          // App Header — matches HTML design
          _AxisHeader(onAvatarTap: _openMe),
          // Content is the IndexedStack keeping all branch states alive!
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: _AxisBottomBar(
        selected: navigationShell.currentIndex,
        onTap: (barIdx) => _onTabTap(context, barIdx),
      ),
    );
  }
}

/// Top app header — Axis brand + sync status + LVL badge + avatar
class _AxisHeader extends StatelessWidget {
  const _AxisHeader({required this.onAvatarTap});
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 10,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AxisColors.canvasBase.withValues(alpha: 0.85),
        border: const Border(
          bottom: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Brand with App Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'AXIS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          letterSpacing: 2.2,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sync dot
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: AxisColors.tertiary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AxisColors.tertiary.withValues(alpha: 0.7),
                              blurRadius: 6,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'SYNCED',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AxisColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(width: 6),
          // FOCUS button pill
          GestureDetector(
            onTap: () => context.push('/focus'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: AxisColors.primary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: AxisColors.primary.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timer_outlined, color: AxisColors.primarySoft, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    'FOCUS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AxisColors.primarySoft,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // LVL badge (dynamically synced)
          ValueListenableBuilder<int>(
            valueListenable: globalUserLevel,
            builder: (context, lvl, _) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        color: AxisColors.secondary, size: 13),
                    const SizedBox(width: 3),
                    Text(
                      'LVL $lvl',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AxisColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Avatar → opens Me
          GestureDetector(
            onTap: onAvatarTap,
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AxisColors.primary, AxisColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AxisColors.textHigh, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5-slot bottom bar: Today | Tasks | [+orb] | Habits | Notes
class _AxisBottomBar extends StatelessWidget {
  const _AxisBottomBar({required this.selected, required this.onTap});
  final int selected;   // 0-4 → tab index (excludes orb)
  final ValueChanged<int> onTap; // bar index 0-4 (2 = orb)

  @override
  Widget build(BuildContext context) {
    // Bar slots (5): Today(0) Tasks(1) [+](2) Habits(3) Notes(4)
    // tab indices:     0       1           2       3
    final barSlots = [0, 1, -1, 2, 3]; // -1 = orb

    return Container(
      height: 68 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AxisColors.glassTier1.withValues(alpha: 0.96),
        border: const Border(
          top: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(5, (barIdx) {
          final tabIdx = barSlots[barIdx];

          // Quick-Add orb
          if (tabIdx == -1) {
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(barIdx),
                child: Center(
                  child: Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AxisColors.primary, AxisColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.primary.withValues(alpha: 0.45),
                          blurRadius: 20, spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AxisColors.textHigh, size: 26),
                  ),
                ),
              ),
            );
          }

          final isSelected = tabIdx == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(barIdx),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AxisColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _tabIcons[tabIdx],
                      size: 22,
                      color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _tabLabels[tabIdx],
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected ? AxisColors.primarySoft : AxisColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Global navigator key for presenting system-wide dialogs and alarms
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration with IndexedStack state persistence
final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppShell(navigationShell: navigationShell);
      },
      branches: [
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
              path: '/notes',
              builder: (context, state) => const NotesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/me',
              builder: (context, state) => const MeScreen(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/focus',
      builder: (context, state) => const FocusScreen(),
    ),
  ],
);
