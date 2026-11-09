import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Top XP Cockpit card featuring user level, rank, daily progress, and glow decoration
class XpCockpitCard extends StatelessWidget {
  const XpCockpitCard({
    super.key,
    required this.level,
    required this.rank,
    required this.todayXp,
    required this.totalXp,
    required this.nextLevelXp,
    required this.progress,
  });

  final int level;
  final String rank;
  final int todayXp;
  final int totalXp;
  final int nextLevelXp;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.primary.withValues(alpha: 0.06),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.primary.withValues(alpha: 0.15),
                    blurRadius: 60,
                    spreadRadius: 20,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.secondary.withValues(alpha: 0.04),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.secondary.withValues(alpha: 0.12),
                    blurRadius: 50,
                    spreadRadius: 15,
                  )
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: const Icon(
                          Icons.terminal_rounded,
                          color: AxisColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  context.isArabic ? 'مستوى $level' : 'Lv $level',
                                  style:
                                      Theme.of(context).textTheme.displaySmall,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AxisColors.secondary
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      rank,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AxisColors.secondarySoft,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '+$todayXp ${context.isArabic ? "نقطة" : "XP"}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: AxisColors.tertiary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    context.isArabic ? 'مكتسبة اليوم' : 'earned today',
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AxisColors.secondary,
                                ),
                          ),
                          Text(
                            context.isArabic ? 'إلى مستوى ${level + 1}' : 'to Lv ${level + 1}',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AxisColors.textMuted,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: AxisColors.primary,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '$totalXp / $nextLevelXp ${context.isArabic ? "نقطة" : "XP"}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AxisColors.textMuted,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      XpBar(progress: progress, height: 7),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
