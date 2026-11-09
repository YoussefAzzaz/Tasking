import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/user_profile_repository.dart';
import '../../widgets/desktop_live_clock.dart';
import '../../widgets/telemetry_chip.dart';

/// Top welcome header for the command deck showing operator status and real-time clock.
class CommandDeckWelcomeHeader extends StatelessWidget {
  const CommandDeckWelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserProfile>(
      valueListenable: UserProfileRepository().profileNotifier,
      builder: (context, profile, _) {
        final isArabic = AppLocalizations.of(context).isArabic;
        final name = profile.name.trim().isEmpty
            ? (isArabic ? 'القائد' : 'Commander')
            : profile.name;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AxisColors.tertiary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          isArabic ? 'النظام نشط • العقدة المحلية' : 'SYSTEM ACTIVE • LOCAL NODE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: AxisColors.tertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isArabic ? 'مرحباً بعودتك، $name' : 'Welcome Back, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AxisColors.textHigh,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DesktopLiveClock(
                  builder: (context, now) {
                    final timeStr = DateFormat('HH:mm:ss').format(now);
                    final dateStr = DateFormat('EEE, MMM d').format(now);
                    return Text(
                      '$timeStr  ·  $dateStr',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AxisColors.textMuted,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                TelemetryChip(
                  label: isArabic ? 'جميع الأنظمة متصلة' : 'All Systems Online',
                  dotColor: AxisColors.tertiary,
                  color: AxisColors.tertiary,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
