import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/habits/widgets/qibla_compass_sheet.dart';
import 'prayer/next_prayer_banner.dart';
import 'prayer/today_prayer_capsule.dart';

export 'prayer/next_prayer_banner.dart';
export 'prayer/today_prayer_capsule.dart';

/// HORIZONTAL PRAYER TIMES WIDGET
/// Displays prayer times telemetry on the Today page directly under the date header.
/// Features:
///   - Next Prayer status with countdown badge ("in Xh Ym" or "DUE NOW") & glowing indicator
///   - Sleek cyan progress bar tracking time to the next prayer (isolated rebuilds)
///   - Responsive horizontal row of 5 prayer capsules (WCAG 48dp touch targets)
///   - Haptic feedback and instant checkoff feedback
///   - Qibla telemetry pill opening the Qibla Compass sheet
///   - Expandable detailed telemetry list matching cyber design
class TodayPrayerTimesCard extends StatefulWidget {
  const TodayPrayerTimesCard({
    super.key,
    required this.prayers,
    required this.onTogglePrayer,
  });

  final List<Prayer> prayers;
  final void Function(Prayer prayer, bool done) onTogglePrayer;

  @override
  State<TodayPrayerTimesCard> createState() => _TodayPrayerTimesCardState();
}

class _TodayPrayerTimesCardState extends State<TodayPrayerTimesCard> {
  bool _expanded = false;
  static const _calculator = PrayerCalculator();

  void _openQibla(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QiblaCompassSheet(),
    );
  }

  void _handleToggle(Prayer prayer, bool isDone) {
    HapticFeedback.lightImpact();
    widget.onTogglePrayer(prayer, isDone);
  }

  @override
  Widget build(BuildContext context) {
    final prayers = widget.prayers.isNotEmpty
        ? widget.prayers
        : PrayerTimeService.defaultPrayers();

    final nextTelemetry = _calculator.computeNextPrayer(prayers);
    final nextCode = nextTelemetry.nextPrayer.prayerCode.toLowerCase();
    final doneCount = prayers.where((p) => p.isDone).length;
    final totalCount = prayers.length;
    final percent =
        totalCount > 0 ? ((doneCount / totalCount) * 100).toInt() : 0;
    final qiblaBearing = PrayerTimeService().qiblaBearing;

    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AxisColors.primary.withValues(alpha: 0.28),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AxisColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header: PRAYER TELEMETRY & QIBLA Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.explore_outlined,
                          size: 13,
                          color: AxisColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          context.isArabic ? 'قياسات الصلوات' : 'PRAYER TELEMETRY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AxisColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _openQibla(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: AxisColors.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.navigation_rounded,
                          size: 10,
                          color: AxisColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.isArabic ? 'القبلة ${qiblaBearing.toInt()}°' : 'QIBLA ${qiblaBearing.toInt()}°',
                          style: const TextStyle(
                            color: AxisColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Isolated Next Prayer Banner with self-contained 10-second ticker
            NextPrayerBanner(
              prayers: prayers,
              calculator: _calculator,
            ),

            const SizedBox(height: 10),

            // Horizontal Prayer Capsules (5 prayers across in an expanded responsive row)
            Row(
              children: List.generate(prayers.length, (index) {
                final prayer = prayers[index];
                final isDone = prayer.isDone;
                final isNext = prayer.prayerCode.toLowerCase() == nextCode;
                final timeStr = _calculator.formatPrayerTime24(prayer.time);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: index < prayers.length - 1 ? 5 : 0,
                    ),
                    child: TodayPrayerCapsule(
                      key: ValueKey('capsule_${prayer.id}'),
                      prayer: prayer,
                      isDone: isDone,
                      isNext: isNext,
                      timeStr: timeStr,
                      onToggle: (checked) => _handleToggle(prayer, checked),
                    ),
                  ),
                );
              }),
            ),

            // Expandable detailed list matching screenshot layout
            if (_expanded) ...[
              const SizedBox(height: 10),
              const Divider(color: AxisColors.borderGlass2, height: 1),
              const SizedBox(height: 8),
              ...prayers.map((prayer) {
                final isDone = prayer.isDone;
                final isNext = prayer.prayerCode.toLowerCase() == nextCode;
                final timeStr = _calculator.formatPrayerTime24(prayer.time);
                return TodayDetailedPrayerRow(
                  key: ValueKey('row_${prayer.id}'),
                  prayer: prayer,
                  isDone: isDone,
                  isNext: isNext,
                  timeStr: timeStr,
                  onToggle: (checked) => _handleToggle(prayer, checked),
                );
              }),
            ],

            const SizedBox(height: 10),

            // Footer: OBLIGATIONS & mini progress bar + expand toggle
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.isArabic
                            ? 'الفرائض: $doneCount/$totalCount ($percent%)'
                            : 'OBLIGATIONS: $doneCount/$totalCount ($percent%)',
                        style: const TextStyle(
                          color: AxisColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Container(
                      width: 64,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 4,
                          width: 64 *
                              (totalCount > 0 ? (doneCount / totalCount) : 0.0),
                          decoration: BoxDecoration(
                            color: AxisColors.primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AxisColors.primary.withValues(alpha: 0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AxisColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
