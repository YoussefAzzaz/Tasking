import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/ui/prayers/adhan_full_screen_alarm.dart';
import 'package:axis/ui/shell/axis_header.dart';
import 'package:axis/ui/shell/axis_bottom_bar.dart';
import 'package:axis/ui/shell/session_expired_banner.dart';
import 'package:axis/ui/common/updates/update_notice_banner.dart';
import 'package:axis/ui/desktop/desktop_command_center.dart';

/// App shell with header + 5-tab bottom nav using IndexedStack:
/// Tasks(0) | Habits(1) | TODAY(2) | Notes(3) | Friends(4)
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _onTabTap(BuildContext context, int branchIdx) {
    navigationShell.goBranch(
      branchIdx,
      initialLocation: branchIdx == navigationShell.currentIndex,
    );
  }

  void _openMe(BuildContext context) {
    context.push('/me');
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

    // Branch 2 is the center /today tab
    final isTodayTab = navigationShell.currentIndex == 2;

    final adhan = AdhanAlarmService().activeAdhanInfo;
    if (adhan != null && !AdhanAlarmService().isFullScreenAlarmShowing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!AdhanAlarmService().isFullScreenAlarmShowing) {
          final ctx = rootNavigatorKey.currentContext ?? context;
          AdhanFullScreenAlarm.show(
            ctx,
            prayerName: adhan['prayerName'] ?? 'Prayer',
            prayerNameAr: adhan['prayerNameAr'] ?? 'الصلاة',
            prayerTime: adhan['prayerTime'] ?? '',
            prayerId: adhan['prayerId'],
          );
        }
      });
    }

    return PopScope(
      canPop: isTodayTab,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          // If on any other tab, return to /today before exiting app
          navigationShell.goBranch(2);
        }
      },
      child: Scaffold(
        backgroundColor: AxisColors.canvasBase,
        body: Column(
          children: [
            // App Header
            AxisHeader(
              onAvatarTap: () => _openMe(context),
              isMeSelected: false,
            ),
            // Floating Focus Session Bar under the top header
            const FloatingFocusSessionBar(),
            // Update Notice Banner if new release available
            const UpdateNoticeBanner(),
            // Session Expired Banner if token expired
            const SessionExpiredBanner(),
            // Content is the IndexedStack keeping all branch states alive
            Expanded(child: navigationShell),
          ],
        ),
        bottomNavigationBar: AxisBottomBar(
          selected: navigationShell.currentIndex,
          onTap: (branchIdx) => _onTabTap(context, branchIdx),
        ),
      ),
    );
  }
}
