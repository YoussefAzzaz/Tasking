import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'companion_profile_modal.dart';

/// Tab presenting the weekly XP leaderboard and podium for companions and the current user.
class FriendsStandingsTab extends StatelessWidget {
  final ScrollController? scrollController;
  final VoidCallback onAddCompanion;

  const FriendsStandingsTab({
    super.key,
    this.scrollController,
    required this.onAddCompanion,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final friendRepo = FriendRepository();

    return RefreshIndicator(
      onRefresh: () async {
        await friendRepo.syncAllFriendData();
      },
      color: AxisColors.warning,
      backgroundColor: AxisColors.surfaceLow,
      child: StreamBuilder<List<FriendUser>>(
        stream: friendRepo.watchAllStandings(),
        builder: (context, snapshot) {
          final standings = snapshot.data ?? [];
          final isLoading = snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData;

          return ListView(
            controller: scrollController,
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AxisColors.warning.withValues(alpha: 0.16),
                      AxisColors.surfaceLowest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AxisColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AxisColors.warning.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: AxisColors.warning.withValues(alpha: 0.5)),
                      ),
                      child: const Center(
                        child: Icon(Icons.military_tech_rounded, color: AxisColors.warningBright, size: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.weeklyStandings.toUpperCase(),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AxisColors.warningBright,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            l10n.circleStandingsSub,
                            style: GoogleFonts.getFont('Geist', fontSize: 11.5, color: AxisColors.textMuted, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.warning),
                    ),
                  ),
                )
              else if (standings.isEmpty)
                _buildEmptyState(
                  icon: Icons.emoji_events_outlined,
                  title: l10n.noCompanionsYet,
                  subtitle: l10n.noCompanionsDesc,
                  actionLabel: l10n.addCompanion,
                  onAction: onAddCompanion,
                )
              else ...[
                _buildPodiumSection(context, standings, friendRepo.currentUserId, friendRepo),
                const SizedBox(height: 20),
                if (standings.length > 3)
                  ...List.generate(standings.length - 3, (index) {
                    final rank = index + 4;
                    final f = standings[rank - 1];
                    return _buildLeaderboardRow(context, f, rank, friendRepo.currentUserId, friendRepo);
                  }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildPodiumSection(BuildContext context, List<FriendUser> standings, String currentUid, FriendRepository friendRepo) {
    final top1 = standings.isNotEmpty ? standings[0] : null;
    final top2 = standings.length > 1 ? standings[1] : null;
    final top3 = standings.length > 2 ? standings[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (top2 != null)
          Expanded(child: _buildPodiumColumn(context: context, user: top2, rank: 2, height: 120, color: const Color(0xFF94A3B8), currentUid: currentUid, friendRepo: friendRepo))
        else
          const Expanded(child: SizedBox()),
        const SizedBox(width: 10),
        if (top1 != null)
          Expanded(child: _buildPodiumColumn(context: context, user: top1, rank: 1, height: 145, color: AxisColors.warning, currentUid: currentUid, friendRepo: friendRepo))
        else
          const Expanded(child: SizedBox()),
        const SizedBox(width: 10),
        if (top3 != null)
          Expanded(child: _buildPodiumColumn(context: context, user: top3, rank: 3, height: 105, color: const Color(0xFFD97706), currentUid: currentUid, friendRepo: friendRepo))
        else
          const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required BuildContext context,
    required FriendUser user,
    required int rank,
    required double height,
    required Color color,
    required String currentUid,
    required FriendRepository friendRepo,
  }) {
    final isMe = user.userId == currentUid;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (rank == 1)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Icon(Icons.workspace_premium_rounded, size: 24, color: AxisColors.warning),
          ),
        InkWell(
          onTap: () async {
            HapticFeedback.lightImpact();
            final status = await friendRepo.getStatusForCompanion(user);
            if (context.mounted) {
              CompanionProfileModal.showSheet(context, status, user);
            }
          },
          borderRadius: BorderRadius.circular(99),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: AvatarWidget(
              name: user.name,
              avatarColor: user.avatarColor,
              avatarUrl: user.avatarUrl,
              size: rank == 1 ? 48 : 42,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                user.name,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textHigh,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AxisColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppLocalizations.of(context).isArabic ? 'أنت' : 'YOU',
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
        Text(
          '${user.totalXp} XP',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: 0.25),
                color.withValues(alpha: 0.08),
                AxisColors.surfaceLowest,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardRow(BuildContext context, FriendUser f, int rank, String currentUid, FriendRepository friendRepo) {
    final isMe = f.userId == currentUid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMe ? AxisColors.surfaceLow : AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? AxisColors.primary.withValues(alpha: 0.5) : AxisColors.borderSubtle,
        ),
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
              Container(
                width: 30,
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AxisColors.textDim,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AvatarWidget(
                name: f.name,
                avatarColor: f.avatarColor,
                avatarUrl: f.avatarUrl,
                size: 36,
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
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              AppLocalizations.of(context).isArabic ? 'أنت' : 'YOU',
                              style: const TextStyle(fontSize: 8.5, color: AxisColors.primarySoft, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${AppLocalizations.of(context).isArabic ? "المستوى" : "Lv."} ${f.level}  ·  ${AppLocalizations.of(context).isArabic && f.title.toLowerCase() == "specialist" ? "أخصائي" : (AppLocalizations.of(context).isArabic && f.title.toLowerCase() == "operator" ? "مشغل" : f.title)}',
                      style: GoogleFonts.getFont('Geist', fontSize: 10.5, color: AxisColors.textDim),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AxisColors.primary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  '${f.totalXp} XP',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AxisColors.primarySoft,
                  ),
                ),
              ),
            ],
          ),
        ),
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

