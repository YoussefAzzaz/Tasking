import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/badges/badge_models.dart';
import 'package:axis/data/badges/badge_localization.dart';

/// Next Milestones in Reach spotlight card for Today screen.
/// Displays up to 2 badges closest to unlocking with live progress bars,
/// percentages, and interactive tap to view the tier roadmap modal.
class NextMilestonesCard extends StatelessWidget {
  const NextMilestonesCard({
    super.key,
    required this.spotlightBadges,
    required this.onTapBadge,
  });

  final List<MasteryBadgeData> spotlightBadges;
  final ValueChanged<MasteryBadgeData> onTapBadge;

  @override
  Widget build(BuildContext context) {
    if (spotlightBadges.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AxisColors.secondary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AxisColors.secondary.withValues(alpha: 0.06),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AxisColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: AxisColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.isArabic ? 'المعالم القادمة قيد التحقيق' : 'NEXT MILESTONES IN REACH',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.secondary,
                          letterSpacing: 0.9,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.isArabic ? 'خارطة الطريق' : 'ROADMAP',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textDim,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    context.isArabic ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                    size: 9,
                    color: AxisColors.textDim,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...spotlightBadges.take(2).map((badge) {
            final pct = (badge.progress * 100).toInt();

            return InkWell(
              onTap: () => onTapBadge(badge),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badge.color.withValues(alpha: 0.15),
                        border: Border.all(
                          color: badge.color.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: Icon(badge.icon, size: 16, color: badge.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  badge.localizedTitle(context.isArabic),
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AxisColors.textHigh,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: badge.color,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: badge.progress,
                              minHeight: 4,
                              backgroundColor: AxisColors.surfaceLowest,
                              valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                            ),
                          ),
                          if (badge.progressLabel.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              badge.localizedProgressLabel(context.isArabic),
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AxisColors.textDim,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      context.isArabic ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                      size: 16,
                      color: AxisColors.textDim,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
