import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/friend_repository.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/me/widgets/avatar_widget.dart';

/// Interactive checklist card for the active user's today prayers and habit progress.
class MyPersonalChecklistCard extends StatelessWidget {
  final DailyPrayerStatus status;
  final PrayerTimeService prayerService;

  const MyPersonalChecklistCard({
    super.key,
    required this.status,
    required this.prayerService,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prayers = [
      {'code': 'fajr', 'name': l10n.prayerName('fajr'), 'done': status.fajr},
      {'code': 'dhuhr', 'name': l10n.prayerName('dhuhr'), 'done': status.dhuhr},
      {'code': 'asr', 'name': l10n.prayerName('asr'), 'done': status.asr},
      {'code': 'maghrib', 'name': l10n.prayerName('maghrib'), 'done': status.maghrib},
      {'code': 'isha', 'name': l10n.prayerName('isha'), 'done': status.isha},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AxisColors.primary.withValues(alpha: 0.55), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AxisColors.primary.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                name: status.userName,
                avatarColor: status.userAvatarColor,
                avatarUrl: status.userAvatarUrl,
                size: 40,
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
                            status.userName.isNotEmpty && status.userName != 'You' ? status.userName : l10n.youLabel,
                            style: GoogleFonts.spaceGrotesk(fontSize: 15, fontWeight: FontWeight.w700, color: AxisColors.textHigh),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AxisColors.primary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            l10n.youLabel,
                            style: GoogleFonts.spaceGrotesk(fontSize: 9.5, fontWeight: FontWeight.w800, color: AxisColors.primarySoft),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${status.completedCount}/5 ${l10n.prayersDoneCount}',
                      style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: AxisColors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department_rounded, size: 14, color: AxisColors.warning),
                    const SizedBox(width: 3),
                    Text(
                      '${status.streakDays} ${l10n.day}',
                      style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800, color: AxisColors.warning),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: prayers.map((p) {
              final isDone = p['done'] as bool;
              final name = p['name'] as String;

              return Expanded(
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    final prayerCode = p['code'] as String;
                    await prayerService.togglePrayer(prayerCode, !isDone);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isDone ? AxisColors.tertiary.withValues(alpha: 0.18) : AxisColors.surfaceHigh.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDone ? AxisColors.tertiary.withValues(alpha: 0.85) : AxisColors.borderSubtle.withValues(alpha: 0.6),
                        width: isDone ? 1.2 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 15,
                          color: isDone ? AxisColors.tertiary : AxisColors.textDim,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: isDone ? FontWeight.w700 : FontWeight.w500, color: isDone ? AxisColors.textHigh : AxisColors.textDim),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (status.habitsTotal > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: AxisColors.surfaceLowest, borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.repeat_rounded, size: 13, color: AxisColors.textDim),
                  const SizedBox(width: 6),
                  Text(
                    '${l10n.dailyHabitsCount}: ${status.habitsDone}/${status.habitsTotal}',
                    style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted),
                  ),
                  const Spacer(),
                  if (status.habitsDone == status.habitsTotal)
                    Text(
                      l10n.allCompletedBadge,
                      style: GoogleFonts.spaceGrotesk(fontSize: 10.5, fontWeight: FontWeight.w700, color: AxisColors.tertiary),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

