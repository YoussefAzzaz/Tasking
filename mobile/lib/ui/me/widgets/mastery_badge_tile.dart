import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/mastery_badge_repository.dart';

/// Single interactive mastery badge tile in the Me screen grid or carousel.
class MasteryBadgeTile extends StatelessWidget {
  const MasteryBadgeTile({
    super.key,
    required this.badge,
    required this.onTap,
  });

  final MasteryBadgeData badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final unlocked = badge.isUnlocked;
    final activeColor = unlocked ? badge.color : AxisColors.textDim;
    final currentTier = badge.currentTier;
    final badgeTitle = badge.localizedTitle(isArabic);
    final tierName = currentTier?.localizedName(isArabic, badgeId: badge.id) ?? (isArabic ? 'مفتوح' : 'Unlocked');
    final tierLabel = unlocked
        ? (isArabic
            ? 'م${currentTier?.tierNumber ?? 1} • $tierName'
            : 'T${currentTier?.tierNumber ?? 1} • $tierName')
        : (isArabic ? 'مقفل' : 'Locked');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: badge.color.withValues(alpha: 0.2),
        highlightColor: badge.color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: unlocked
                ? AxisColors.surfaceHigh.withValues(alpha: 0.55)
                : AxisColors.surfaceLowest.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unlocked
                  ? badge.color.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: badge.color.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge Icon with glowing background if unlocked
              Stack(
                alignment: Alignment.center,
                children: [
                  if (unlocked)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badge.color.withValues(alpha: 0.15),
                      ),
                    ),
                  Icon(
                    badge.icon,
                    color: activeColor,
                    size: 24,
                  ),
                ],
              ),

              // Title and Tier Label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    badgeTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          unlocked ? AxisColors.textHigh : AxisColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tierLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unlocked
                          ? badge.color.withValues(alpha: 0.9)
                          : AxisColors.textDim,
                      fontWeight: FontWeight.w500,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),

              // Mini Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 3,
                  width: double.infinity,
                  color: AxisColors.surfaceLowest,
                  child: FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: badge.progress.clamp(0.05, 1.0),
                    child: Container(
                      color: unlocked
                          ? badge.color
                          : AxisColors.textDim.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

