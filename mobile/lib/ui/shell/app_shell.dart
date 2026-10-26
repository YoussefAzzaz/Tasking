import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/tasks/quick_add_sheet.dart';
import 'package:axis/ui/shell/axis_header.dart';
import 'package:axis/ui/shell/axis_bottom_bar.dart';
import 'package:axis/ui/shell/floating_focus_session_bar.dart';
import 'package:axis/ui/desktop/desktop_command_center.dart';

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
    final isDesktopPlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    if (isDesktopPlatform || MediaQuery.sizeOf(context).width >= 1024) {
      return const DesktopCommandCenter();
    }

    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // If on /me or any other tab, return to /today before exiting app
          navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        backgroundColor: AxisColors.canvasBase,
        body: Column(
          children: [
            // App Header
            AxisHeader(
              onAvatarTap: _openMe,
              isMeSelected: navigationShell.currentIndex == 4,
            ),
            // Floating Focus Session Bar under the top header
            const FloatingFocusSessionBar(),
            // Content is the IndexedStack keeping all branch states alive
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: AxisBottomBar(
          selected: navigationShell.currentIndex,
          onTap: (barIdx) => _onTabTap(context, barIdx),
        ),
      ),
    );
  }
}
