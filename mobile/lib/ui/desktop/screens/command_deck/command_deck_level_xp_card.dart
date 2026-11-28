import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/user_profile_repository.dart';
import '../../../../domain/gamification_engine.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/progress_gauge.dart';

/// Card showing current operator gamification level and XP progress.
class CommandDeckLevelXpCard extends StatelessWidget {
  const CommandDeckLevelXpCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final isArabic = AppLocalizations.of(context).isArabic;
        final level = profile.level > 0 ? profile.level : 1;
        final xp = profile.totalXp;
        final currentLevelBase = GamificationEngine.xpToReachLevel(level);
        final nextLevelTarget = GamificationEngine.xpToReachLevel(level + 1);
        final progress = nextLevelTarget > currentLevelBase
            ? ((xp - currentLevelBase) / (nextLevelTarget - currentLevelBase)).clamp(0.0, 1.0)
            : 0.0;

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      isArabic ? 'مشغل مستوى $level' : 'LEVEL $level OPERATOR',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AxisColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? '$xp / $nextLevelTarget نقطة خبرة' : '$xp / $nextLevelTarget XP',
                    style: AxisFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ProgressGauge(
                value: progress,
                gradient: const LinearGradient(
                  colors: [AxisColors.secondary, AxisColors.primary],
                ),
                height: 6.0,
              ),
            ],
          ),
        );
      },
    );
  }
}
