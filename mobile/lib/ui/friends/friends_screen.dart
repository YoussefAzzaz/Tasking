import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/user_profile_repository.dart';

import 'widgets/friends_circle_tab.dart';
import 'widgets/friends_today_prayers_tab.dart';
import 'widgets/friends_standings_tab.dart';
import 'widgets/add_companion_sheet.dart';

/// Main mobile screen for Companions, Mutual Prayer Accountability, and Circle Standings.
class FriendsScreen extends StatefulWidget {
  final int initialTabIndex;

  const FriendsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _friendRepo = FriendRepository();
  final _profileRepo = UserProfileRepository();
  bool _isManualSyncing = false;

  final _circleScrollController = ScrollController();
  final _todayScrollController = ScrollController();
  final _standingsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );

    _friendRepo.syncAllFriendData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _circleScrollController.dispose();
    _todayScrollController.dispose();
    _standingsScrollController.dispose();
    super.dispose();
  }

  Future<void> _handleManualSync() async {
    if (_isManualSyncing) return;
    setState(() => _isManualSyncing = true);
    HapticFeedback.lightImpact();

    try {
      await _friendRepo.syncAllFriendData();
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        AxisSnackBar.show(
          context,
          message: l10n.isArabic ? 'تم تحديث بيانات الصحبة من السحابة بنجاح' : 'Companions updated from cloud',
          icon: Icons.cloud_done_rounded,
        );
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isManualSyncing = false);
      }
    }
  }

  void _openAddCompanionSheet() {
    final code = _profileRepo.profileNotifier.value.friendCode ?? 'AX-7842';
    AddCompanionSheet.show(context, code);
  }

  void _showNotificationsSheet() {
    final l10n = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        decoration: const BoxDecoration(
          color: AxisColors.canvasBase,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: AxisColors.borderGlass2, width: 1.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AxisColors.textDim.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: AxisColors.tertiaryBright, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.friendNotifications,
                  style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _friendRepo.clearFriendNotifications();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(l10n.clearNotifications, style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<FriendActivityLog>>(
                stream: _friendRepo.watchFriendActivityLogs(),
                builder: (context, snapshot) {
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return Center(
                      child: Text(l10n.noNotificationsYet, style: GoogleFonts.getFont('Geist', color: AxisColors.textDim)),
                    );
                  }
                  return ListView.separated(
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Text(log.title, style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      appBar: AppBar(
        backgroundColor: AxisColors.canvasBase,
        elevation: 0,
        centerTitle: false,
        title: Text(
          l10n.companions,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AxisColors.textHigh,
          ),
        ),
        actions: [
          StreamBuilder<List<FriendActivityLog>>(
            stream: _friendRepo.watchFriendActivityLogs(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded, color: AxisColors.textHigh),
                    onPressed: _showNotificationsSheet,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: AxisColors.primary, shape: BoxShape.circle),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: _isManualSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft))
                : const Icon(Icons.refresh_rounded, color: AxisColors.textHigh),
            onPressed: _handleManualSync,
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              indicator: BoxDecoration(
                color: AxisColors.primary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AxisColors.primary.withValues(alpha: 0.5)),
              ),
              labelColor: AxisColors.primarySoft,
              unselectedLabelColor: AxisColors.textDim,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              tabs: [
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_outline_rounded, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          l10n.circle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          l10n.todaysBoard,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.military_tech_outlined, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          l10n.weeklyStandings,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _KeepAliveWrapper(
            child: FriendsCircleTab(
              scrollController: _circleScrollController,
              onAddCompanion: _openAddCompanionSheet,
            ),
          ),
          _KeepAliveWrapper(
            child: FriendsTodayPrayersTab(
              scrollController: _todayScrollController,
              onAddCompanion: _openAddCompanionSheet,
            ),
          ),
          _KeepAliveWrapper(
            child: FriendsStandingsTab(
              scrollController: _standingsScrollController,
              onAddCompanion: _openAddCompanionSheet,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
