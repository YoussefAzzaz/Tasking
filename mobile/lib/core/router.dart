import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/tasks/tasks_screen.dart';
import 'package:axis/ui/tasks/quick_add_sheet.dart';

import 'package:axis/ui/today/today_screen.dart';
import 'package:axis/ui/habits/habits_screen.dart';
import 'package:axis/ui/notes/notes_screen.dart';
import 'package:axis/ui/me/me_screen.dart';

// Shell destinations
final _destinations = [
  const _NavDest(icon: Icons.today_rounded, label: 'Today', path: '/today'),
  const _NavDest(icon: Icons.check_box_outlined, label: 'Tasks', path: '/tasks'),
  const _NavDest(icon: Icons.loop_rounded, label: 'Habits', path: '/habits'),
  const _NavDest(icon: Icons.edit_note_rounded, label: 'Notes', path: '/notes'),
  const _NavDest(icon: Icons.person_outline_rounded, label: 'Me', path: '/me'),
];

class _NavDest {
  final IconData icon;
  final String label;
  final String path;
  const _NavDest({required this.icon, required this.label, required this.path});
}

/// App shell with custom bottom nav — Quick-Add orb centered
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selected = 1; // Tasks tab default

  int _indexFromPath(String path) {
    final i = _destinations.indexWhere((d) => path.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  void _onNavTap(int idx) {
    if (idx == 2) {
      // Quick-Add orb (center)
      _showQuickAdd();
      return;
    }
    setState(() => _selected = idx > 2 ? idx - 1 : idx);
    context.go(_destinations[idx > 2 ? idx - 1 : idx].path);
  }

  void _showQuickAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickAddButton(onTaskAdded: () {
        setState(() {});
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: SafeArea(child: widget.child),
      bottomNavigationBar: _AxisBottomBar(
        selected: _selected,
        onTap: _onNavTap,
      ),
    );
  }
}

class _AxisBottomBar extends StatelessWidget {
  const _AxisBottomBar({required this.selected, required this.onTap});
  final int selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // 5-slot bar: Today | Tasks | [+] | Habits | Notes (Me omitted to fit 5 per UX guidelines)
    final items = [
      _destinations[0], // Today
      _destinations[1], // Tasks
      null,             // Quick-Add orb
      _destinations[2], // Habits
      _destinations[3], // Notes
    ];

    return Container(
      height: 72 + MediaQuery.of(context).padding.bottom,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AxisColors.glassTier1.withOpacity(0.95),
        border: const Border(
          top: BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final dest = items[i];
          if (dest == null) {
            // Quick-Add orb
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                child: Center(
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AxisColors.primary, AxisColors.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.primary.withOpacity(0.4),
                          blurRadius: 18, spreadRadius: -4,
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

          // Map visual tab index to selected state
          final tabIdx = i > 2 ? i - 1 : i;
          final isSelected = tabIdx == selected;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AxisColors.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      dest.icon,
                      size: 22,
                      color: isSelected
                          ? AxisColors.primarySoft
                          : AxisColors.textDim,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dest.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? AxisColors.primarySoft
                          : AxisColors.textDim,
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

/// GoRouter configuration
final router = GoRouter(
  initialLocation: '/tasks',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
        GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
        GoRoute(path: '/habits', builder: (_, __) => const HabitsScreen()),
        GoRoute(path: '/notes', builder: (_, __) => const NotesScreen()),
        GoRoute(path: '/me', builder: (_, __) => const MeScreen()),
      ],
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.construction_rounded,
              size: 48, color: AxisColors.textDim),
          const SizedBox(height: 12),
          Text(label, style: Theme.of(context).textTheme.displaySmall
              ?.copyWith(color: AxisColors.textMuted)),
          const SizedBox(height: 4),
          Text('Sprint coming soon',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
