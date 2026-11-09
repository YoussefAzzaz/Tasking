import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/prayer_time_service.dart';

/// Dedicated, self-updating banner for the next prayer countdown and progress bar.
/// Isolates timer rebuilds from the rest of the TodayPrayerTimesCard.
class NextPrayerBanner extends StatefulWidget {
  final List<Prayer> prayers;
  final PrayerCalculator calculator;

  const NextPrayerBanner({
    super.key,
    required this.prayers,
    required this.calculator,
  });

  @override
  State<NextPrayerBanner> createState() => _NextPrayerBannerState();
}

class _NextPrayerBannerState extends State<NextPrayerBanner> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // 10-second ticker for tight countdown updates isolated strictly to this banner
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = widget.calculator.computeNextPrayer(widget.prayers);
    final nextTime24 =
        widget.calculator.formatPrayerTime24(telemetry.nextPrayer.time);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AxisColors.surfaceHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: telemetry.isDueNow
              ? AxisColors.primary.withValues(alpha: 0.6)
              : AxisColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // Cyan pulsing dot
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AxisColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.8),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.isArabic
                      ? 'الصلاة القادمة: ${AppLocalizations.of(context).prayerName(telemetry.nextPrayer.prayerCode)} $nextTime24'
                      : 'Next Prayer: ${telemetry.nextPrayer.name} $nextTime24',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AxisColors.textHigh,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Countdown Pill ("in 1h 24m" or "DUE NOW")
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: telemetry.isDueNow
                      ? AxisColors.primary.withValues(alpha: 0.25)
                      : AxisColors.surfaceHigh.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: telemetry.isDueNow
                        ? AxisColors.primary
                        : AxisColors.primary.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  telemetry.isDueNow
                      ? (context.isArabic ? 'حان الآن' : 'DUE NOW')
                      : (context.isArabic
                          ? telemetry.countdownText
                              .replaceAll('in ', 'خلال ')
                              .replaceAll('h', 'س')
                              .replaceAll('m', 'د')
                          : telemetry.countdownText),
                  style: TextStyle(
                    color: telemetry.isDueNow
                        ? AxisColors.primary
                        : AxisColors.primarySoft,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress Bar to next prayer
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: AxisColors.surfaceHighest,
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 5,
                      width: constraints.maxWidth * telemetry.progress,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AxisColors.primary,
                            Color(0xFF34D399),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AxisColors.primary.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

