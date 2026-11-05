import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/mastery_badge_repository.dart';

/// Renders the completed mastery badges list for a companion in Obsidian Cyberpunk styling.
class CompanionBadgesList extends StatelessWidget {
  final List<MasteryBadgeData> badges;
  final bool isLoading;

  const CompanionBadgesList({
    super.key,
    required this.badges,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, size: 16, color: AxisColors.warning),
            const SizedBox(width: 7),
            Text(
              l10n.completedBadges.toUpperCase(),
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: AxisColors.textHigh,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: AxisColors.warning.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AxisColors.warning.withValues(alpha: 0.4)),
              ),
              child: Text(
                '${badges.length}',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AxisColors.warning,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (isLoading) ...[
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.primarySoft),
              ),
            ),
          ),
        ] else if (badges.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(Icons.military_tech_outlined, size: 28, color: AxisColors.textDim),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.noBadgesYet,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.isArabic
                            ? 'المواظبة على العادات والصلوات تفتح شارات التميز.'
                            : 'Completing daily habits, prayers, and streaks unlocks mastery badges.',
                        style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            primary: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badges.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final b = badges[index];
              final tierName = b.currentTier?.name ?? 'Initiate';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: b.color.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: b.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: b.color.withValues(alpha: 0.5)),
                      ),
                      child: Icon(b.icon, size: 18, color: b.color),
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
                                  b.title,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: AxisColors.textHigh,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: b.color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tierName,
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: b.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b.subtitle,
                            style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle_rounded, size: 16, color: AxisColors.tertiary),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

