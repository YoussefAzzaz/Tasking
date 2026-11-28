import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/mastery_badge_repository.dart';

/// Desktop-tailored mastery badge card with glowing icon plate, tier indicator,
/// milestone description, and progress indicator.
class DesktopBadgeCard extends StatefulWidget {
  const DesktopBadgeCard({
    super.key,
    required this.badge,
    required this.onTap,
  });

  final MasteryBadgeData badge;
  final VoidCallback onTap;

  @override
  State<DesktopBadgeCard> createState() => _DesktopBadgeCardState();
}

class _DesktopBadgeCardState extends State<DesktopBadgeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final badge = widget.badge;
    final unlocked = badge.isUnlocked;
    final activeColor = unlocked ? badge.color : AxisColors.textDim;
    final currentTier = badge.currentTier;
    final nextTier = badge.nextTier;
    final badgeTitle = badge.localizedTitle(isArabic);
    final badgeSubtitle = badge.localizedSubtitle(isArabic);
    final tierName = currentTier?.localizedName(isArabic, badgeId: badge.id) ?? (isArabic ? 'مفتوح' : 'Unlocked');
    final tierLabel = unlocked
        ? (isArabic
            ? 'م${currentTier?.tierNumber ?? 1} • $tierName'
            : 'T${currentTier?.tierNumber ?? 1} • $tierName')
        : (isArabic ? 'مقفل' : 'Locked');

    final progressFraction = badge.progress.clamp(0.0, 1.0);
    final String progressText;
    if (unlocked) {
      if (nextTier != null) {
        progressText = '${badge.currentValue}/${nextTier.targetValue}';
      } else {
        progressText = isArabic ? 'الحد الأقصى' : 'MAX';
      }
    } else {
      final firstTarget = badge.tiers.isNotEmpty ? badge.tiers.first.targetValue : 1;
      progressText = '${badge.currentValue}/$firstTarget';
    }

    final borderColor = _isHovered
        ? badge.color.withValues(alpha: 0.55)
        : (unlocked
            ? badge.color.withValues(alpha: 0.30)
            : AxisColors.borderSubtle);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          splashColor: badge.color.withValues(alpha: 0.15),
          highlightColor: badge.color.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: unlocked
                  ? AxisColors.surfaceLowest
                  : AxisColors.surfaceLowest.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: (unlocked && _isHovered)
                  ? [
                      BoxShadow(
                        color: badge.color.withValues(alpha: 0.20),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                // 1. Badge Icon Plate with Aura
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: unlocked
                        ? badge.color.withValues(alpha: 0.14)
                        : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: unlocked
                          ? badge.color.withValues(alpha: 0.40)
                          : AxisColors.borderSubtle,
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        badge.icon,
                        size: 22,
                        color: activeColor,
                      ),
                      if (!unlocked)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Icon(
                            Icons.lock_rounded,
                            size: 10,
                            color: AxisColors.textDim.withValues(alpha: 0.8),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 2. Badge Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title + Tier Tag Row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              badgeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: unlocked
                                    ? AxisColors.textHigh
                                    : AxisColors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: unlocked
                                  ? badge.color.withValues(alpha: 0.16)
                                  : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: unlocked
                                    ? badge.color.withValues(alpha: 0.35)
                                    : AxisColors.borderSubtle,
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              tierLabel,
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: unlocked ? badge.color : AxisColors.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Subtitle / Milestone requirement
                      Text(
                        badgeSubtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AxisFonts.getFont(
                          'Geist',
                          fontSize: 10.5,
                          color: AxisColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Progress Row
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progressFraction,
                                minHeight: 3.5,
                                backgroundColor: AxisColors.surfaceHigh,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  unlocked ? badge.color : AxisColors.primarySoft,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 50),
                            child: Text(
                              progressText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modal dialog presenting badge progression roadmap and tier milestones on desktop.
abstract final class DesktopBadgeDetailDialog {
  static void show(BuildContext context, {required MasteryBadgeData badge}) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final unlocked = badge.isUnlocked;
    final currentTier = badge.currentTier;
    final nextTier = badge.nextTier;
    final badgeTitle = badge.localizedTitle(isArabic);
    final badgeSubtitle = badge.localizedSubtitle(isArabic);
    final categoryName = badge.localizedCategory(isArabic);

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
        child: Container(
          width: 520,
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AxisColors.borderGlass2, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 28,
                spreadRadius: 6,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AxisColors.borderSubtle)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(badge.categoryEnum.icon, color: badge.color, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          categoryName.toUpperCase(),
                          style: AxisFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AxisColors.textHigh,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                      tooltip: isArabic ? 'إغلاق' : 'Close',
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Badge Shield Aura
                      Center(
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: badge.color.withValues(alpha: unlocked ? 0.18 : 0.08),
                            border: Border.all(
                              color: badge.color.withValues(alpha: unlocked ? 0.45 : 0.2),
                              width: 1.5,
                            ),
                            boxShadow: unlocked
                                ? [
                                    BoxShadow(
                                      color: badge.color.withValues(alpha: 0.25),
                                      blurRadius: 20,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            badge.icon,
                            color: unlocked ? badge.color : AxisColors.textDim,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Title & Subtitle
                      Center(
                        child: Column(
                          children: [
                            Text(
                              badgeTitle,
                              textAlign: TextAlign.center,
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textHigh,
                              ),
                            ),
                            if (badgeSubtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                badgeSubtitle,
                                textAlign: TextAlign.center,
                                style: AxisFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Status & Progress Bar
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  unlocked
                                      ? (nextTier != null
                                          ? (isArabic
                                              ? 'المستوى الحالي: ${currentTier?.localizedName(isArabic, badgeId: badge.id) ?? "مفتوح"}'
                                              : 'Current: ${currentTier?.name ?? "Unlocked"}')
                                          : (isArabic ? 'أعلى مستوى تم تحقيقه!' : 'Max Tier Achieved!'))
                                      : (isArabic ? 'الهدف لفتح الشارة' : 'Target to Unlock'),
                                  style: AxisFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: unlocked ? badge.color : AxisColors.textMuted,
                                  ),
                                ),
                                Text(
                                  nextTier != null
                                      ? '${badge.currentValue} / ${nextTier.targetValue} ${nextTier.localizedUnit(isArabic, badgeId: badge.id)}'
                                      : (isArabic ? 'مكتمل' : 'Completed'),
                                  style: AxisFonts.spaceGrotesk(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.textHigh,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: badge.progress.clamp(0.0, 1.0),
                                minHeight: 6,
                                backgroundColor: AxisColors.surfaceHigh,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  unlocked ? badge.color : AxisColors.primarySoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tiers Roadmap
                      Text(
                        isArabic ? 'مسار مستويات الإتقان' : 'MASTERY TIER ROADMAP',
                        style: AxisFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AxisColors.textDim,
                        ),
                      ),
                      const SizedBox(height: 10),

                      for (final tier in badge.tiers) ...[
                        Builder(
                          builder: (context) {
                            final achieved = badge.currentValue >= tier.targetValue;
                            final isCurrent = currentTier?.tierNumber == tier.tierNumber;
                            final tierName = tier.localizedName(isArabic, badgeId: badge.id);
                            final tierDesc = tier.localizedDescription(isArabic, badgeId: badge.id);
                            final tierUnit = tier.localizedUnit(isArabic, badgeId: badge.id);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: achieved
                                    ? badge.color.withValues(alpha: 0.10)
                                    : AxisColors.surfaceLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: achieved
                                      ? badge.color.withValues(alpha: 0.35)
                                      : AxisColors.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    achieved
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_outline_rounded,
                                    size: 18,
                                    color: achieved ? badge.color : AxisColors.textDim,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '${isArabic ? "مستوى" : "Tier"} ${tier.tierNumber} • $tierName',
                                              style: AxisFonts.spaceGrotesk(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: achieved ? AxisColors.textHigh : AxisColors.textMuted,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            if (isCurrent)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: badge.color.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isArabic ? 'الحالي' : 'ACTIVE',
                                                  style: AxisFonts.spaceGrotesk(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: badge.color,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tierDesc,
                                          style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '${tier.targetValue} $tierUnit',
                                    style: AxisFonts.spaceGrotesk(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: achieved ? badge.color : AxisColors.textDim,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
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
