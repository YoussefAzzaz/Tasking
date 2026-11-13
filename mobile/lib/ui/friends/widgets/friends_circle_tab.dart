import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/user_profile_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'companion_profile_modal.dart';
import 'friend_activity_card.dart';
import 'pending_friend_requests_section.dart';
import 'pending_shares_section.dart';

export 'friend_activity_card.dart';
export 'pending_friend_requests_section.dart';
export 'pending_shares_section.dart';

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
        physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Friend Code Share
          FriendCodeShareCard(profileRepo: profileRepo),

          // Pending Requests
          PendingFriendRequestsSection(friendRepo: friendRepo),

          // Pending Companion Shares (Tasks, Habits, etc.)
          const PendingSharesSection(),

          // Friend Activity / Notifications
          FriendActivityNotificationsSection(friendRepo: friendRepo),

          // Connected Companions List
          StreamBuilder<List<FriendUser>>(
            stream: friendRepo.watchAcceptedFriends(),
            builder: (context, snapshot) {
              final friends = snapshot.data ?? [];
              final isLoading = snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people_alt_rounded,
                          size: 16, color: AxisColors.textDim),
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded,
                                  size: 15, color: AxisColors.primarySoft),
                              const SizedBox(width: 3),
                              Text(
                                l10n.addCompanion,
                                style: GoogleFonts.spaceGrotesk(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.primarySoft),
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
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AxisColors.primarySoft),
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
                          key: ValueKey('friend_${f.id}'),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceLowest,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              final status =
                                  await friendRepo.getStatusForCompanion(f);
                              if (context.mounted) {
                                CompanionProfileModal.showSheet(
                                    context, status, f);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                f.name,
                                                style: GoogleFonts.spaceGrotesk(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color:
                                                        AxisColors.textHigh),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(
                                                l10n.isArabic
                                                    ? Icons.arrow_back_ios_rounded
                                                    : Icons.arrow_forward_ios_rounded,
                                                size: 10,
                                                color: AxisColors.textDim),
                                          ],
                                        ),
                                        Text(
                                          '${l10n.friendCode}: ${f.friendCode ?? "AX-7842"}  ·  ${l10n.isArabic ? "المستوى" : "Lv."} ${f.level}',
                                          style: GoogleFonts.getFont('Geist',
                                              fontSize: 10.5,
                                              color: AxisColors.textDim),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: AxisColors.textDim),
                                    onPressed: () async {
                                      final confirm = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor:
                                              AxisColors.surfaceLow,
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                          title: Text(l10n.removeCompanion,
                                              style: GoogleFonts.spaceGrotesk(
                                                  color: AxisColors.textHigh,
                                                  fontWeight:
                                                      FontWeight.w700)),
                                          content: Text(
                                              l10n.removeCompanionConfirm,
                                              style: GoogleFonts.getFont(
                                                  'Geist',
                                                  color: AxisColors.textMuted)),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: Text(l10n.cancel,
                                                  style: const TextStyle(
                                                      color:
                                                          AxisColors.textDim)),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: Text(l10n.remove,
                                                  style: const TextStyle(
                                                      color: AxisColors.error)),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm == true) {
                                        await friendRepo
                                            .removeFriendship(f.friendshipId);
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
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(subtitle,
              style: GoogleFonts.getFont('Geist',
                  fontSize: 12, color: AxisColors.textMuted),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.person_add_rounded, size: 15),
            label: Text(actionLabel,
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, fontSize: 12.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
