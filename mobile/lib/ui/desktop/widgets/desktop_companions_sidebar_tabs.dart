import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'package:axis/ui/tasks/widgets/share_task_sheet.dart';
import '../../friends/widgets/companion_profile_modal.dart';
import '../../friends/widgets/pending_shares_section.dart';
import '../widgets/desktop_card.dart';

/// Desktop panel with tabs for Circle management and notifications.
class DesktopCompanionsSidebarTabs extends StatefulWidget {
  final VoidCallback onAddCompanion;

  const DesktopCompanionsSidebarTabs({
    super.key,
    required this.onAddCompanion,
  });

  @override
  State<DesktopCompanionsSidebarTabs> createState() => _DesktopCompanionsSidebarTabsState();
}

class _DesktopCompanionsSidebarTabsState extends State<DesktopCompanionsSidebarTabs> {
  final _friendRepo = FriendRepository();
  int _selectedTab = 0; // 0: Circle & Requests, 1: Activity

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _buildTabBtn(0, isArabic ? 'الدائرة' : 'Circle', Icons.group_rounded),
              const SizedBox(width: 4),
              _buildTabBtn(1, isArabic ? 'التنبيهات' : 'Activity', Icons.notifications_active_rounded),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _selectedTab == 0
                ? _buildCircleTab(isArabic, l10n)
                : _buildActivityTab(isArabic, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBtn(int index, String label, IconData icon) {
    final active = _selectedTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = index);
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AxisColors.primary.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: active ? AxisColors.primary.withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: active ? AxisColors.primarySoft : AxisColors.textDim),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: AxisFonts.spaceGrotesk(fontSize: 11, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? AxisColors.primarySoft : AxisColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleTab(bool isArabic, AppLocalizations l10n) {
    return ListView(
      children: [
        const PendingSharesSection(),
        StreamBuilder<List<FriendUser>>(
          stream: _friendRepo.watchPendingRequests(),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? [];
            if (requests.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.pendingRequests.toUpperCase(), style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: AxisColors.warning)),
                const SizedBox(height: 6),
                ...requests.map((r) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AxisColors.surfaceLowest, borderRadius: BorderRadius.circular(8), border: Border.all(color: AxisColors.warning.withValues(alpha: 0.4))),
                      child: Row(
                        children: [
                          AvatarWidget(name: r.name, avatarColor: r.avatarColor, avatarUrl: r.avatarUrl, size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(r.name, style: AxisFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: AxisColors.textHigh)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check_rounded, color: AxisColors.success, size: 18),
                            onPressed: () => _friendRepo.acceptFriendRequest(r.friendshipId, r.userId),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AxisColors.error, size: 18),
                            onPressed: () => _friendRepo.declineFriendRequest(r.friendshipId, r.userId),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
              ],
            );
          },
        ),

        StreamBuilder<List<FriendUser>>(
          stream: _friendRepo.watchAcceptedFriends(),
          builder: (context, snapshot) {
            final friends = snapshot.data ?? [];
            if (friends.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.group_add_outlined, size: 32, color: AxisColors.textDim),
                      const SizedBox(height: 6),
                      Text(l10n.noCompanionsYet, style: AxisFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: AxisColors.textHigh)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: widget.onAddCompanion,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: Text(l10n.addCompanion, style: const TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(l10n.connectedCompanions.toUpperCase(), style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: AxisColors.textDim)),
                    const Spacer(),
                    Text('${friends.length}', style: AxisFonts.spaceGrotesk(fontSize: 10, color: AxisColors.textDim)),
                  ],
                ),
                const SizedBox(height: 8),
                ...friends.map((f) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(color: AxisColors.surfaceLowest, borderRadius: BorderRadius.circular(8), border: Border.all(color: AxisColors.borderSubtle)),
                      child: InkWell(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          final status = await _friendRepo.getStatusForCompanion(f);
                          if (context.mounted) {
                            CompanionProfileModal.showCompanionDialog(context, status, f);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              AvatarWidget(name: f.name, avatarColor: f.avatarColor, avatarUrl: f.avatarUrl, size: 30),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(f.name, style: AxisFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.bold, color: AxisColors.textHigh), overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AxisColors.textDim),
                                      ],
                                    ),
                                    Text('Lv. ${f.level} · ${f.friendCode ?? ""}', style: AxisFonts.getFont('Geist', fontSize: 10, color: AxisColors.textDim)),
                                  ],
                                ),
                              ),
                              IconButton(
                                key: ValueKey('desktop_companion_share_${f.userId}'),
                                tooltip: isArabic
                                    ? 'مشاركة مهمة أو عادة أو ملاحظة'
                                    : 'Share Task, Habit, or Note',
                                icon: const Icon(Icons.ios_share_rounded,
                                    size: 16, color: AxisColors.secondary),
                                onPressed: () => ShareWithCompanionSheet.show(
                                  context,
                                  companionUserId: f.userId,
                                  companionName: f.name,
                                  companionAvatarColor: f.avatarColor,
                                  companionAvatarUrl: f.avatarUrl,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AxisColors.textDim),
                                onPressed: () => _friendRepo.removeFriendship(f.friendshipId),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityTab(bool isArabic, AppLocalizations l10n) {
    return StreamBuilder<List<FriendActivityLog>>(
      stream: _friendRepo.watchFriendActivityLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Text(l10n.noNotificationsYet, style: AxisFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textDim)),
          );
        }

        return ListView(
          children: [
            Row(
              children: [
                Text(l10n.friendNotifications.toUpperCase(), style: AxisFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: AxisColors.textDim)),
                const Spacer(),
                TextButton(
                  onPressed: () => _friendRepo.clearFriendNotifications(),
                  child: Text(l10n.clearNotifications, style: const TextStyle(fontSize: 10, color: AxisColors.textDim)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...logs.map((log) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _friendRepo.dismissNotification(log.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            log.isCollaborativeTaskDeleted
                                ? Icons.delete_sweep_outlined
                                : (log.isSharedItemDeclined
                                    ? Icons.cancel_outlined
                                    : (log.isSharedItem
                                        ? (log.eventType ==
                                                'collaborative_task_completed'
                                            ? Icons.handshake_rounded
                                            : Icons.ios_share_rounded)
                                        : Icons.notifications_active_rounded)),
                            size: 16,
                            color: (log.isSharedItemDeclined ||
                                    log.isCollaborativeTaskDeleted)
                                ? AxisColors.error
                                : (log.isSharedItem
                                    ? AxisColors.secondary
                                    : AxisColors.primarySoft),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(log.title, style: AxisFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textHigh)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 14, color: AxisColors.textDim),
                            onPressed: () => _friendRepo.dismissNotification(log.id),
                            tooltip: l10n.isArabic ? 'إخفاء' : 'Dismiss',
                            constraints: const BoxConstraints(),
                            padding: const EdgeInsets.all(4),
                          ),
                        ],
                      ),
                    ),
                  ),
                )),
          ],
        );
      },
    );
  }
}

