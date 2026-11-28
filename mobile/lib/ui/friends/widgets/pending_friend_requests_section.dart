import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/typography.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// Section showing pending incoming companion requests with accept/decline action buttons.
class PendingFriendRequestsSection extends StatelessWidget {
  const PendingFriendRequestsSection({
    super.key,
    required this.friendRepo,
  });

  final FriendRepository friendRepo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<FriendUser>>(
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
                  child: const Icon(Icons.mark_email_unread_rounded,
                      size: 15, color: AxisColors.primarySoft),
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.pendingRequests.toUpperCase()} (${requests.length})',
                  style: AxisFonts.spaceGrotesk(
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
                  key: ValueKey('req_${r.id}'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AxisColors.primary.withValues(alpha: 0.45),
                        width: 1.2),
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
                              style: AxisFonts.spaceGrotesk(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh),
                            ),
                            const SizedBox(height: 2),
                            // Root cause: avoided showing fake 'AX-7842' when friendCode is unset.
                            Text(
                              '${l10n.isArabic ? "المستوى" : "Lv."} ${r.level}  ·  ${(r.friendCode != null && r.friendCode!.trim().isNotEmpty) ? r.friendCode!.trim() : "---"}',
                              style: AxisFonts.getFont('Geist',
                                  fontSize: 11, color: AxisColors.textDim),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await friendRepo.acceptFriendRequest(
                              r.friendshipId, r.userId);
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
                        label: Text(l10n.accept,
                            style: AxisFonts.spaceGrotesk(
                                fontSize: 11.5, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AxisColors.success.withValues(alpha: 0.22),
                          foregroundColor: AxisColors.success,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: AxisColors.success.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: AxisColors.error, size: 20),
                        tooltip: l10n.refuse,
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await friendRepo.declineFriendRequest(
                              r.friendshipId, r.userId);
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
    );
  }
}

