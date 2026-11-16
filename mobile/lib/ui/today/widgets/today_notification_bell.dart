import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// In-app notification bell with real-time pending friend request & activity count,
/// opening a draggable notification center bottom sheet.
class TodayNotificationBell extends StatelessWidget {
  final FriendRepository friendRepo;

  const TodayNotificationBell({
    super.key,
    required this.friendRepo,
  });

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final l10n = AppLocalizations.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollCtrl) {
            return Container(
              decoration: BoxDecoration(
                color: AxisColors.canvasBase,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: AxisColors.borderGlass2, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: AxisColors.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AxisColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.notifications_rounded,
                              size: 18, color: AxisColors.primarySoft),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.friendNotifications,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await friendRepo.clearFriendNotifications();
                          },
                          child: Text(
                            l10n.clearNotifications,
                            style: GoogleFonts.getFont('Geist',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textDim),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 20, color: AxisColors.textDim),
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AxisColors.borderSubtle, height: 1),

                  // List Content
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      children: [
                        // 1. Pending Friend Requests Section
                        StreamBuilder<List<FriendUser>>(
                          stream: friendRepo.watchPendingRequests(),
                          builder: (context, pendingSnap) {
                            final requests = pendingSnap.data ?? [];
                            if (requests.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_add_rounded,
                                        size: 14, color: AxisColors.primarySoft),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.pendingRequests.toUpperCase(),
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: l10n.isArabic ? 0.0 : 0.8,
                                        color: AxisColors.textDim,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AxisColors.primary,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        '${requests.length}',
                                        style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ...requests.map((r) => Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AxisColors.surfaceLowest,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: AxisColors.primary
                                                .withValues(alpha: 0.35)),
                                      ),
                                      child: Row(
                                        children: [
                                          AvatarWidget(
                                            name: r.name,
                                            avatarColor: r.avatarColor,
                                            avatarUrl: r.avatarUrl,
                                            size: 42,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.name,
                                                  style: GoogleFonts.spaceGrotesk(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AxisColors.textHigh,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${l10n.isArabic ? "المستوى" : "Lv."} ${r.level} · ${r.friendCode ?? ''}',
                                                  style: GoogleFonts.getFont('Geist',
                                                      fontSize: 11,
                                                      color: AxisColors.textDim),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          OutlinedButton(
                                            onPressed: () async {
                                              HapticFeedback.lightImpact();
                                              await friendRepo.declineFriendRequest(
                                                  r.friendshipId, r.userId);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AxisColors.error,
                                              side: BorderSide(
                                                  color: AxisColors.error
                                                      .withValues(alpha: 0.5)),
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 10, vertical: 6),
                                              minimumSize: const Size(54, 32),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            child: Text(
                                              l10n.refuse,
                                              style: GoogleFonts.getFont('Geist',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton(
                                            onPressed: () async {
                                              HapticFeedback.lightImpact();
                                              await friendRepo.acceptFriendRequest(
                                                  r.friendshipId, r.userId);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AxisColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6),
                                              minimumSize: const Size(60, 32),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                            child: Text(
                                              l10n.accept,
                                              style: GoogleFonts.getFont('Geist',
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 14),
                              ],
                            );
                          },
                        ),

                        // 2. Activity Logs & Reminders Section
                        StreamBuilder<List<FriendActivityLog>>(
                          stream: friendRepo.watchFriendActivityLogs(),
                          builder: (context, logSnap) {
                            final logs = logSnap.data ?? [];

                            return StreamBuilder<List<FriendUser>>(
                              stream: friendRepo.watchPendingRequests(),
                              builder: (context, pendingSnap) {
                                final requests = pendingSnap.data ?? [];
                                if (logs.isEmpty && requests.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 40.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.notifications_none_rounded,
                                              size: 40,
                                              color: AxisColors.textDim),
                                          const SizedBox(height: 12),
                                          Text(
                                            l10n.noNotificationsYet,
                                            style: GoogleFonts.getFont('Geist',
                                                fontSize: 13,
                                                color: AxisColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                if (logs.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.history_rounded,
                                            size: 14, color: AxisColors.textDim),
                                        const SizedBox(width: 6),
                                        Text(
                                          l10n.friendNotifications.toUpperCase(),
                                          style: GoogleFonts.spaceGrotesk(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: l10n.isArabic ? 0.0 : 0.8,
                                            color: AxisColors.textDim,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    ...logs.map((log) {
                                      final icon = log.isPrayerReminder
                                          ? Icons.notifications_active_rounded
                                          : (log.isRequestAccepted
                                              ? Icons.check_circle_outline_rounded
                                              : (log.isRequestDeclined
                                                  ? Icons.cancel_outlined
                                                  : Icons.info_outline_rounded));
                                      final iconColor = log.isPrayerReminder
                                          ? AxisColors.primarySoft
                                          : (log.isRequestAccepted
                                              ? AxisColors.success
                                              : (log.isRequestDeclined
                                                  ? AxisColors.error
                                                  : AxisColors.warning));

                                      String dateStr = '';
                                      try {
                                        final dt =
                                            DateTime.parse(log.createdAt).toLocal();
                                        dateStr = l10n.formatDate(dt, 'h:mm a');
                                      } catch (_) {}

                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => friendRepo.dismissNotification(log.id),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: AxisColors.surfaceLowest,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: AxisColors.borderSubtle),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: iconColor.withValues(
                                                        alpha: 0.14),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(icon,
                                                      size: 16, color: iconColor),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        log.title,
                                                        style: GoogleFonts.getFont(
                                                            'Geist',
                                                            fontSize: 12.5,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                            color:
                                                                AxisColors.textHigh),
                                                      ),
                                                      if (dateStr.isNotEmpty)
                                                        Text(
                                                          dateStr,
                                                          style: GoogleFonts
                                                              .spaceGrotesk(
                                                                  fontSize: 10.5,
                                                                  color: AxisColors
                                                                      .textDim),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.close_rounded,
                                                      size: 16, color: AxisColors.textDim),
                                                  onPressed: () =>
                                                      friendRepo.dismissNotification(log.id),
                                                  tooltip: l10n.isArabic ? 'إخفاء' : 'Dismiss',
                                                  constraints: const BoxConstraints(),
                                                  padding: const EdgeInsets.all(6),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FriendUser>>(
      stream: friendRepo.watchPendingRequests(),
      builder: (context, pendingSnap) {
        final pendingCount = pendingSnap.data?.length ?? 0;
        return StreamBuilder<List<FriendActivityLog>>(
          stream: friendRepo.watchFriendActivityLogs(),
          builder: (context, logSnap) {
            final logs = logSnap.data ?? [];
            final totalBadge = pendingCount + logs.length;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showNotificationsSheet(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: totalBadge > 0
                          ? AxisColors.primary.withValues(alpha: 0.6)
                          : AxisColors.borderSubtle,
                      width: 1,
                    ),
                    boxShadow: totalBadge > 0
                        ? [
                            BoxShadow(
                              color: AxisColors.primary.withValues(alpha: 0.22),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        totalBadge > 0
                            ? Icons.notifications_active_rounded
                            : Icons.notifications_none_rounded,
                        size: 19,
                        color: totalBadge > 0
                            ? AxisColors.primarySoft
                            : AxisColors.textDim,
                      ),
                      if (totalBadge > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AxisColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$totalBadge',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
