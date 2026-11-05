import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'companion_profile_modal.dart';

/// Tab presenting connected companions, pending requests, and friend code sharing.
class FriendsCircleTab extends StatelessWidget {
  final ScrollController? scrollController;
  final VoidCallback onAddCompanion;

  const FriendsCircleTab({
    super.key,
    this.scrollController,
    required this.onAddCompanion,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final friendRepo = FriendRepository();
    final profileRepo = UserProfileRepository();

    return RefreshIndicator(
      onRefresh: () async {
        await friendRepo.syncAllFriendData();
      },
      color: AxisColors.primary,
      backgroundColor: AxisColors.surfaceLow,
      child: ListView(
        controller: scrollController,
        primary: false,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          ValueListenableBuilder<UserProfile>(
            valueListenable: profileRepo.profileNotifier,
            builder: (context, profile, _) {
              final myCode = profile.friendCode ?? 'AX-7842';
              return Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AxisColors.surfaceLowest, AxisColors.surfaceLow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AxisColors.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share_rounded, color: AxisColors.primarySoft, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.yourFriendCode.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w800, color: AxisColors.textDim),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            myCode,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              color: AxisColors.primarySoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Clipboard.setData(ClipboardData(text: myCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.copyCodeSuccess),
                            backgroundColor: AxisColors.surfaceLow,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(l10n.copy, style: GoogleFonts.getFont('Geist', fontSize: 12, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AxisColors.primary.withValues(alpha: 0.22),
                        foregroundColor: AxisColors.primarySoft,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: AxisColors.primary.withValues(alpha: 0.45)),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          StreamBuilder<List<FriendUser>>(
            stream: friendRepo.watchPendingRequests(),
            builder: (context, snapshot) {
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.mark_email_unread_rounded, size: 15, color: AxisColors.primarySoft),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${l10n.pendingRequests.toUpperCase()} (${requests.length})',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.primarySoft,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...requests.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AxisColors.primary.withValues(alpha: 0.45), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: AxisColors.primary.withValues(alpha: 0.08),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            AvatarWidget(
                              name: r.name,
                              avatarColor: r.avatarColor,
                              avatarUrl: r.avatarUrl,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.name,
                                    style: GoogleFonts.spaceGrotesk(fontSize: 14.5, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lv. ${r.level}  ·  ${r.friendCode ?? "AX-7842"}',
                                    style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await friendRepo.acceptFriendRequest(r.friendshipId, r.userId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.requestAccepted),
                                      backgroundColor: AxisColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.check_rounded, size: 15),
                              label: Text(l10n.accept, style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AxisColors.success.withValues(alpha: 0.22),
                                foregroundColor: AxisColors.success,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(color: AxisColors.success.withValues(alpha: 0.5)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: AxisColors.error, size: 20),
                              tooltip: l10n.refuse,
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                await friendRepo.declineFriendRequest(r.friendshipId, r.userId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.requestDeclined),
                                      backgroundColor: AxisColors.surfaceLow,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      )),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),

          StreamBuilder<List<FriendActivityLog>>(
            stream: friendRepo.watchFriendActivityLogs(),
            builder: (context, snapshot) {
              final logs = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AxisColors.tertiary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, size: 15, color: AxisColors.tertiaryBright),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.friendNotifications.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.tertiaryBright,
                        ),
                      ),
                      const Spacer(),
                      if (logs.isNotEmpty)
                        TextButton(
                          onPressed: () => friendRepo.clearFriendNotifications(),
                          child: Text(l10n.clearNotifications, style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (logs.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_none_rounded, size: 16, color: AxisColors.textDim),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.noNotificationsYet,
                              style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textDim),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...logs.take(5).map((log) {
                      IconData iconData = Icons.notifications_rounded;
                      Color iconColor = AxisColors.tertiary;

                      if (log.isFriendRequest) {
                        iconData = Icons.person_add_rounded;
                        iconColor = AxisColors.primarySoft;
                      } else if (log.isRequestAccepted) {
                        iconData = Icons.celebration_rounded;
                        iconColor = AxisColors.success;
                      } else if (log.isRequestDeclined) {
                        iconData = Icons.cancel_outlined;
                        iconColor = AxisColors.error;
                      } else if (log.isPrayerReminder) {
                        iconData = Icons.mosque_rounded;
                        iconColor = AxisColors.tertiaryBright;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(iconData, size: 15, color: iconColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                log.title,
                                style: GoogleFonts.getFont('Geist', fontSize: 12, fontWeight: FontWeight.w500, color: AxisColors.textHigh),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 18),
                ],
              );
            },
          ),

          StreamBuilder<List<FriendUser>>(
            stream: friendRepo.watchAcceptedFriends(),
            builder: (context, snapshot) {
              final friends = snapshot.data ?? [];
              final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 16, color: AxisColors.textDim),
                      const SizedBox(width: 6),
                      Text(
                        '${l10n.connectedCompanions.toUpperCase()} (${friends.length})',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AxisColors.textDim,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onAddCompanion();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 15, color: AxisColors.primarySoft),
                              const SizedBox(width: 3),
                              Text(
                                l10n.addCompanion,
                                style: GoogleFonts.spaceGrotesk(fontSize: 11.5, fontWeight: FontWeight.bold, color: AxisColors.primarySoft),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
                        ),
                      ),
                    )
                  else if (friends.isEmpty)
                    _buildEmptyState(
                      icon: Icons.group_add_outlined,
                      title: l10n.noCompanionsYet,
                      subtitle: l10n.noCompanionsDesc,
                      actionLabel: l10n.addCompanion,
                      onAction: onAddCompanion,
                    )
                  else
                    ...friends.map((f) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final status = await friendRepo.getStatusForCompanion(f);
                              if (context.mounted) {
                                CompanionProfileModal.showSheet(context, status, f);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  AvatarWidget(
                                    name: f.name,
                                    avatarColor: f.avatarColor,
                                    avatarUrl: f.avatarUrl,
                                    size: 38,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                f.name,
                                                style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AxisColors.textDim),
                                          ],
                                        ),
                                        Text(
                                          '${l10n.friendCode}: ${f.friendCode ?? "AX-7842"}  ·  Lv. ${f.level}',
                                          style: GoogleFonts.getFont('Geist', fontSize: 10.5, color: AxisColors.textDim),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AxisColors.textDim),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AxisColors.surfaceLow,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          title: Text(l10n.removeCompanion, style: GoogleFonts.spaceGrotesk(color: AxisColors.textHigh, fontWeight: FontWeight.w700)),
                                          content: Text(l10n.removeCompanionConfirm, style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted)),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(false),
                                              child: Text(l10n.cancel, style: const TextStyle(color: AxisColors.textDim)),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(true),
                                              child: Text(l10n.remove, style: const TextStyle(color: AxisColors.error)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await friendRepo.removeFriendship(f.friendshipId);
                                      }
                                    },
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
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AxisColors.textDim),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: AxisColors.textHigh), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle, style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.person_add_rounded, size: 15),
            label: Text(actionLabel, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

