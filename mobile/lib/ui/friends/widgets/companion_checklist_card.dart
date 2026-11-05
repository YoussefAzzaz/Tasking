import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';
import 'companion_profile_modal.dart';

/// Clean card displaying a companion's avatar, name, level, and link to profile.
class CompanionChecklistCard extends StatelessWidget {
  final DailyPrayerStatus status;
  final FriendRepository friendRepo;

  const CompanionChecklistCard({
    super.key,
    required this.status,
    required this.friendRepo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            CompanionProfileModal.showSheet(context, status);
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                AvatarWidget(
                  name: status.userName,
                  avatarColor: status.userAvatarColor,
                  avatarUrl: status.userAvatarUrl,
                  size: 42,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              status.userName,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AxisColors.textHigh,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AxisColors.primary.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AxisColors.primarySoft.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'LVL ${status.level}',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AxisColors.primarySoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isArabic ? 'المستوى ${status.level}' : 'Level ${status.level}',
                        style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AxisColors.textDim),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
