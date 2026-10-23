import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'package:axis/ui/habits/widgets/qibla_compass_sheet.dart';

/// Next prayer telemetry information for countdown and progress bar.
class _NextPrayerInfo {
  final Prayer nextPrayer;
  final String countdownText;
  final bool isDueNow;
  final double progress;

  const _NextPrayerInfo({
    required this.nextPrayer,
    required this.countdownText,
    required this.isDueNow,
    required this.progress,
  });
}

/// HORIZONTAL PRAYER TIMES WIDGET
/// Displays prayer times telemetry on the Today page directly under the date header.
/// Features:
///   - Next Prayer status with countdown badge ("in Xh Ym" or "DUE NOW") & glowing indicator
///   - Sleek cyan progress bar tracking time to the next prayer
///   - Responsive horizontal row of 5 prayer capsules (fits all mobile screens)
///   - Interactive checkoff to toggle completion with instant feedback
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
  Timer? _ticker;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    // Refresh countdown and progress bar every 30 seconds
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  static DateTime? _parseTimeToDateTime(String timeStr, DateTime now) {
    try {
      final clean = timeStr.trim();
      if (clean.toUpperCase().contains('AM') || clean.toUpperCase().contains('PM')) {
        final df = DateFormat('hh:mm a');
        final dt = df.parse(clean);
        return DateTime(now.year, now.month, now.day, dt.hour, dt.minute);
      }
      final parts = clean.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final min = int.parse(parts[1].trim());
        return DateTime(now.year, now.month, now.day, hour, min);
      }
    } catch (_) {}
    return null;
  }

  static String formatPrayerTime24(String raw) {
    final now = DateTime.now();
    final dt = _parseTimeToDateTime(raw, now);
    if (dt != null) {
      return DateFormat('HH:mm').format(dt);
    }
    return raw.replaceAll(' AM', '').replaceAll(' PM', '').trim();
  }

  _NextPrayerInfo _computeNextPrayer(List<Prayer> prayers) {
    final now = DateTime.now();
    if (prayers.isEmpty) {
      final fallback = PrayerTimeService.defaultPrayers().first;
      return _NextPrayerInfo(
        nextPrayer: fallback,
        countdownText: 'in 1h',
        isDueNow: false,
        progress: 0.5,
      );
    }

    final parsed = <MapEntry<Prayer, DateTime>>[];
    for (final p in prayers) {
      final dt = _parseTimeToDateTime(p.time, now) ??
          DateTime(now.year, now.month, now.day, 12, 0);
      parsed.add(MapEntry(p, dt));
    }
    parsed.sort((a, b) => a.value.compareTo(b.value));

    // Check if any prayer is "DUE NOW" (within 20 minutes of its adan)
    for (final entry in parsed) {
      final diffMin = now.difference(entry.value).inMinutes;
      if (diffMin >= 0 && diffMin <= 20) {
        return _NextPrayerInfo(
          nextPrayer: entry.key,
          countdownText: 'DUE NOW',
          isDueNow: true,
          progress: 0.95,
        );
      }
    }

    // Find next upcoming prayer today
    for (int i = 0; i < parsed.length; i++) {
      if (parsed[i].value.isAfter(now)) {
        final next = parsed[i];
        final prevDt = i > 0
            ? parsed[i - 1].value
            : parsed.last.value.subtract(const Duration(days: 1));
        final diff = next.value.difference(now);
        final countdown = diff.inHours > 0
            ? 'in ${diff.inHours}h ${diff.inMinutes % 60}m'
            : 'in ${diff.inMinutes}m';

        final span = next.value.difference(prevDt).inSeconds;
        final elapsed = now.difference(prevDt).inSeconds;
        final progress = span > 0 ? (elapsed / span).clamp(0.05, 1.0) : 0.5;

        return _NextPrayerInfo(
          nextPrayer: next.key,
          countdownText: countdown,
          isDueNow: false,
          progress: progress,
        );
      }
    }

    // All prayers passed for today; next is tomorrow's Fajr
    final fajr = parsed.first;
    final tomorrowFajr = fajr.value.add(const Duration(days: 1));
    final prevDt = parsed.last.value;
    final diff = tomorrowFajr.difference(now);
    final countdown = diff.inHours > 0
        ? 'in ${diff.inHours}h ${diff.inMinutes % 60}m'
        : 'in ${diff.inMinutes}m';
    final span = tomorrowFajr.difference(prevDt).inSeconds;
    final elapsed = now.difference(prevDt).inSeconds;
    final progress = span > 0 ? (elapsed / span).clamp(0.05, 1.0) : 0.5;

    return _NextPrayerInfo(
      nextPrayer: fajr.key,
      countdownText: countdown,
      isDueNow: false,
      progress: progress,
    );
  }

  void _openQibla(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QiblaCompassSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayers = widget.prayers.isNotEmpty
        ? widget.prayers
        : PrayerTimeService.defaultPrayers();

    final nextInfo = _computeNextPrayer(prayers);
    final nextCode = nextInfo.nextPrayer.prayerCode.toLowerCase();
    final nextTime24 = formatPrayerTime24(nextInfo.nextPrayer.time);
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

            // Next Prayer Banner (glowing cyan dot + Next Prayer + countdown pill + progress bar)
            // NO azan button per user requirement
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: nextInfo.isDueNow
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
                          'Next Prayer: ${nextInfo.nextPrayer.name} $nextTime24',
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
                          color: nextInfo.isDueNow
                              ? AxisColors.primary.withValues(alpha: 0.25)
                              : AxisColors.surfaceHigh.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: nextInfo.isDueNow
                                ? AxisColors.primary
                                : AxisColors.primary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          nextInfo.countdownText,
                          style: TextStyle(
                            color: nextInfo.isDueNow
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
                              width: constraints.maxWidth * nextInfo.progress,
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
            ),

            const SizedBox(height: 10),

            // Horizontal Prayer Capsules (5 prayers across in an expanded responsive row)
            Row(
              children: List.generate(prayers.length, (index) {
                final prayer = prayers[index];
                final isDone = prayer.isDone;
                final isNext = prayer.prayerCode.toLowerCase() == nextCode;
                final timeStr = formatPrayerTime24(prayer.time);

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index < prayers.length - 1 ? 5 : 0,
                    ),
                    child: _buildPrayerCapsule(
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
                final timeStr = formatPrayerTime24(prayer.time);
                return _buildDetailedPrayerRow(
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

    return InkWell(
      onTap: () => widget.onTogglePrayer(prayer, !isDone),
      borderRadius: BorderRadius.circular(8),
      child: Container(
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
    );
  }

  /// Full-width detailed row matching the screenshot
  Widget _buildDetailedPrayerRow({
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
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => widget.onTogglePrayer(prayer, !isDone),
        borderRadius: BorderRadius.circular(10),
        child: Container(
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
    );
  }
}
