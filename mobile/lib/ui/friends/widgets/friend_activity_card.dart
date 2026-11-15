import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/user_profile_repository.dart';

/// Card showing the current user's companion friend code with 1-tap copy to clipboard.
class FriendCodeShareCard extends StatelessWidget {
  const FriendCodeShareCard({
    super.key,
    required this.profileRepo,
  });

  final UserProfileRepository profileRepo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<UserProfile>(
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
                child: const Icon(Icons.share_rounded,
                    color: AxisColors.primarySoft, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.yourFriendCode.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AxisColors.textDim),
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
                label: Text(l10n.copy,
                    style: GoogleFonts.getFont('Geist',
                        fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AxisColors.primary.withValues(alpha: 0.22),
                  foregroundColor: AxisColors.primarySoft,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                        color: AxisColors.primary.withValues(alpha: 0.45)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Section showing recent friend activity updates and notifications.
class FriendActivityNotificationsSection extends StatelessWidget {
  const FriendActivityNotificationsSection({
    super.key,
    required this.friendRepo,
  });

  final FriendRepository friendRepo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<FriendActivityLog>>(
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
                  child: const Icon(Icons.notifications_active_rounded,
                      size: 15, color: AxisColors.tertiaryBright),
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
                    child: Text(l10n.clearNotifications,
                        style: GoogleFonts.getFont('Geist',
                            fontSize: 11, color: AxisColors.textDim)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AxisColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_none_rounded,
                        size: 16, color: AxisColors.textDim),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.noNotificationsYet,
                        style: GoogleFonts.getFont('Geist',
                            fontSize: 11.5, color: AxisColors.textDim),
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
                } else if (log.isRequestDeclined ||
                    log.isSharedItemDeclined ||
                    log.isCollaborativeTaskDeleted) {
                  iconData = log.isCollaborativeTaskDeleted
                      ? Icons.delete_sweep_outlined
                      : Icons.cancel_outlined;
                  iconColor = AxisColors.error;
                } else if (log.isPrayerReminder) {
                  iconData = Icons.mosque_rounded;
                  iconColor = AxisColors.tertiaryBright;
                } else if (log.isSharedItem) {
                  iconData = log.eventType == 'collaborative_task_completed'
                      ? Icons.handshake_rounded
                      : Icons.ios_share_rounded;
                  iconColor = AxisColors.secondary;
                }

                return Container(
                  key: ValueKey('log_${log.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          style: GoogleFonts.getFont('Geist',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AxisColors.textHigh),
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
    );
  }
}

