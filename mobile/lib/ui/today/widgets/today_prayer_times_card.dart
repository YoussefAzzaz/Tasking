import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/habits/widgets/qibla_compass_sheet.dart';

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
    final percent = totalCount > 0 ? ((doneCount / totalCount) * 100).toInt() : 0;
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
                      const Flexible(
                        child: Text(
                          'PRAYER TELEMETRY',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          'QIBLA ${qiblaBearing.toInt()}°',
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
            _NextPrayerBanner(
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
                    padding: EdgeInsets.only(
                      right: index < prayers.length - 1 ? 5 : 0,
                    ),
                    child: _buildPrayerCapsule(
                      key: ValueKey('capsule_${prayer.id}'),
                      prayer: prayer,
                      isDone: isDone,
                      isNext: isNext,
                      timeStr: timeStr,
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
                return _buildDetailedPrayerRow(
                  key: ValueKey('row_${prayer.id}'),
                  prayer: prayer,
                  isDone: isDone,
                  isNext: isNext,
                  timeStr: timeStr,
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
                        'OBLIGATIONS: $doneCount/$totalCount ($percent%)',
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
                          width: 64 * (totalCount > 0 ? (doneCount / totalCount) : 0.0),
                          decoration: BoxDecoration(
                            color: AxisColors.primary,
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: [
                              BoxShadow(
                                color: AxisColors.primary.withValues(alpha: 0.5),
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

  /// Compact horizontal capsule for each of the 5 daily prayers
  Widget _buildPrayerCapsule({
    Key? key,
    required Prayer prayer,
    required bool isDone,
    required bool isNext,
    required String timeStr,
  }) {
    Color borderColor;
    Color bgColor;
    if (isNext) {
      borderColor = AxisColors.primary;
      bgColor = AxisColors.primary.withValues(alpha: 0.16);
    } else if (isDone) {
      borderColor = AxisColors.success.withValues(alpha: 0.6);
      bgColor = AxisColors.success.withValues(alpha: 0.12);
    } else {
      borderColor = AxisColors.borderSubtle;
      bgColor = AxisColors.surfaceHighest.withValues(alpha: 0.25);
    }

    return Semantics(
      key: key,
      button: true,
      label: '${prayer.name}, $timeStr, ${isDone ? "Completed" : "Tap to complete"}',
      child: InkWell(
        onTap: () => _handleToggle(prayer, !isDone),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor,
              width: isNext ? 1.4 : 1.0,
            ),
            boxShadow: isNext
                ? [
                    BoxShadow(
                      color: AxisColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status Icon
              if (isDone)
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AxisColors.success,
                )
              else if (isNext)
                const Icon(
                  Icons.radio_button_checked_rounded,
                  size: 15,
                  color: AxisColors.primary,
                )
              else
                const Icon(
                  Icons.access_time_rounded,
                  size: 15,
                  color: AxisColors.textDim,
                ),
              const SizedBox(height: 3),
              // Prayer Name
              Text(
                prayer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isNext
                      ? AxisColors.primary
                      : (isDone ? AxisColors.textHigh : AxisColors.textMuted),
                ),
              ),
              const SizedBox(height: 1),
              // Time in 24h format
              Text(
                timeStr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
                  color: isNext
                      ? AxisColors.primary
                      : (isDone ? AxisColors.textMuted : AxisColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Full-width detailed row matching the screenshot
  Widget _buildDetailedPrayerRow({
    Key? key,
    required Prayer prayer,
    required bool isDone,
    required bool isNext,
    required String timeStr,
  }) {
    Color containerBg;
    Color borderColor;
    if (isNext) {
      containerBg = AxisColors.primary.withValues(alpha: 0.12);
      borderColor = AxisColors.primary.withValues(alpha: 0.7);
    } else {
      containerBg = AxisColors.surfaceHighest.withValues(alpha: 0.2);
      borderColor = isDone
          ? AxisColors.success.withValues(alpha: 0.3)
          : AxisColors.borderSubtle;
    }

    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        label: '${prayer.name}, $timeStr, ${isDone ? "Done" : "Tap to complete"}',
        child: InkWell(
          onTap: () => _handleToggle(prayer, !isDone),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: isNext ? 1.2 : 0.8),
            ),
            child: Row(
              children: [
                if (isDone)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AxisColors.success,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.check_rounded, size: 14, color: Colors.black),
                  )
                else if (isNext)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AxisColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.primary.withValues(alpha: 0.8),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  )
                else
                  const Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AxisColors.textDim,
                  ),
                const SizedBox(width: 10),
                Text(
                  prayer.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isNext ? AxisColors.primary : AxisColors.textHigh,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AxisColors.textDim,
                  ),
                ),
                const Spacer(),
                if (isDone)
                  const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.success,
                    ),
                  )
                else if (isNext)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AxisColors.primary),
                    ),
                    child: const Text(
                      'DUE NOW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.primary,
                      ),
                    ),
                  )
                else
                  const Text(
                    'Upcoming',
                    style: TextStyle(
                      fontSize: 11,
                      color: AxisColors.textDim,
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

/// Dedicated, self-updating banner for the next prayer countdown and progress bar.
/// Isolates timer rebuilds from the rest of the TodayPrayerTimesCard.
class _NextPrayerBanner extends StatefulWidget {
  final List<Prayer> prayers;
  final PrayerCalculator calculator;

  const _NextPrayerBanner({
    required this.prayers,
    required this.calculator,
  });

  @override
  State<_NextPrayerBanner> createState() => _NextPrayerBannerState();
}

class _NextPrayerBannerState extends State<_NextPrayerBanner> {
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
    final nextTime24 = widget.calculator.formatPrayerTime24(telemetry.nextPrayer.time);

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
                  'Next Prayer: ${telemetry.nextPrayer.name} $nextTime24',
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
                  telemetry.countdownText,
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
