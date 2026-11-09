import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../data/mastery_badge_repository.dart';

/// Detailed bottom modal sheet presenting badge progression, current tier, and roadmap.
class BadgeDetailSheet extends StatelessWidget {
  const BadgeDetailSheet({super.key, required this.badge});

  final MasteryBadgeData badge;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final unlocked = badge.isUnlocked;
    final currentTier = badge.currentTier;
    final nextTier = badge.nextTier;
    final badgeTitle = badge.localizedTitle(isArabic);
    final badgeSubtitle = badge.localizedSubtitle(isArabic);
    final badgeCategory = badge.localizedCategory(isArabic);

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AxisColors.textDim.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Central Badge Shield Aura
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badge.color.withValues(alpha: unlocked ? 0.18 : 0.08),
                    border: Border.all(
                      color:
                          badge.color.withValues(alpha: unlocked ? 0.45 : 0.2),
                      width: 1.5,
                    ),
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: badge.color.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    badge.icon,
                    color: unlocked ? badge.color : AxisColors.textDim,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title & Category
              Center(
                child: Column(
                  children: [
                    Text(
                      badgeTitle,
                      style: const TextStyle(
                        color: AxisColors.textHigh,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (badgeSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        badgeSubtitle,
                        style: const TextStyle(
                          color: AxisColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeCategory.toUpperCase(),
                        style: TextStyle(
                          color: badge.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Current Rank & Progress Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AxisColors.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            unlocked
                                ? (isArabic
                                    ? 'الرتبة الحالية: ${currentTier?.localizedName(isArabic, badgeId: badge.id)} (المستوى ${currentTier?.tierNumber})'
                                    : 'Current Rank: ${currentTier?.name} (Tier ${currentTier?.tierNumber})')
                                : (isArabic
                                    ? 'الحالة: مقفل (لم يتم تحقيق أي مستوى)'
                                    : 'Status: Locked (No Tier Achieved)'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unlocked
                                  ? AxisColors.textHigh
                                  : AxisColors.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(badge.progress * 100).toInt()}%',
                          style: TextStyle(
                            color: badge.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: badge.progress,
                        minHeight: 6,
                        backgroundColor: AxisColors.surfaceHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextTier != null
                          ? (isArabic
                              ? 'التقدم: ${badge.currentValue} / ${nextTier.targetValue} ${nextTier.localizedUnit(isArabic, badgeId: badge.id)} للوصول للمستوى ${nextTier.tierNumber} (${nextTier.localizedName(isArabic, badgeId: badge.id)})'
                              : 'Progress: ${badge.currentValue} / ${nextTier.targetValue} ${nextTier.unit} to reach Tier ${nextTier.tierNumber} (${nextTier.name})')
                          : (isArabic
                              ? 'اكتملت جميع المستويات! لقد بلغت أقصى درجات الإتقان.'
                              : 'All tiers completed! You have reached maximum mastery.'),
                      style: const TextStyle(
                        color: AxisColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Tiers Roadmap
              Text(
                isArabic ? 'خارطة المستويات' : 'TIER ROADMAP',
                style: const TextStyle(
                  color: AxisColors.textDim,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              ...badge.tiers.map((tier) {
                final isAchieved = badge.currentValue >= tier.targetValue;
                final isCurrent = currentTier?.tierNumber == tier.tierNumber;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? badge.color.withValues(alpha: 0.10)
                          : AxisColors.surface.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? badge.color.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAchieved
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isAchieved ? badge.color : AxisColors.textDim,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    isArabic
                                        ? 'المستوى ${tier.tierNumber} — ${tier.localizedName(isArabic, badgeId: badge.id)}'
                                        : 'Tier ${tier.tierNumber} — ${tier.name}',
                                    style: TextStyle(
                                      color: isAchieved
                                          ? AxisColors.textHigh
                                          : AxisColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${tier.targetValue} ${tier.localizedUnit(isArabic, badgeId: badge.id)})',
                                    style: const TextStyle(
                                      color: AxisColors.textDim,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier.localizedDescription(isArabic, badgeId: badge.id),
                                style: const TextStyle(
                                  color: AxisColors.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

