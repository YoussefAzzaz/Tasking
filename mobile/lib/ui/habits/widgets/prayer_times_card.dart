import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/axis_snackbar.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/prayer_time_service.dart';
import 'prayer/habit_prayer_tile.dart';
import 'prayer/prayer_quick_actions_bar.dart';

export 'prayer/habit_prayer_tile.dart';
export 'prayer/prayer_quick_actions_bar.dart';

/// DEDICATED PRAYER TIMES CARD
/// Displays the strictly 5 daily Islamic prayers from the dedicated `prayers` database table.
/// Includes live Adan times, checkoff with XP award, Qibla compass, Adhan alerts,
/// and a non-destructive "Reset Prayers" action (resets only task completion state to undone,
/// preserving EXP and progress, and creating NO duplicate records).
class PrayerTimesCard extends StatefulWidget {
  const PrayerTimesCard({
    super.key,
    required this.prayers,
    required this.onTogglePrayer,
    required this.onResetPrayers,
    required this.onRefreshLocation,
  });

  final List<Prayer> prayers;
  final void Function(Prayer prayer, bool done) onTogglePrayer;
  final Future<void> Function() onResetPrayers;
  final Future<void> Function() onRefreshLocation;

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  bool _expanded = true;
  bool _isResetting = false;

  Future<void> _handleConfirmReset() async {
    final confirmed = await showConfirmResetPrayersDialog(context);

    if (confirmed == true) {
      setState(() => _isResetting = true);
      await widget.onResetPrayers();
      if (mounted) {
        setState(() => _isResetting = false);
        AxisSnackBar.show(
          context,
          message: context.isArabic
              ? 'تمت إعادة تعيين صلوات اليوم'
              : "Today's prayers have been reset to undone",
          icon: Icons.refresh_rounded,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;
    final done = widget.prayers.where((p) => p.isDone).length;
    final total = widget.prayers.length;
    final percent = total > 0 ? ((done / total) * 100).toInt() : 0;
    final progress = total > 0 ? (done / total) : 0.0;
    final isComplete = total > 0 && done == total;

    const prayerColor = AxisColors.success;

    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: prayerColor.withValues(alpha: isComplete ? 0.6 : 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: prayerColor.withValues(alpha: isComplete ? 0.15 : 0.05),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon, Title, Progress, Reset & Expand
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: prayerColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: prayerColor.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.mosque_rounded,
                                color: prayerColor,
                                size: 20,
                              ),
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
                                          isArabic
                                              ? 'الصلوات المفروضة'
                                              : 'Prayers',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AxisColors.textHigh,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isArabic
                                        ? 'تمت $done من أصل $total صلوات'
                                        : '$done of $total prayers completed',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AxisColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isComplete)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    AxisColors.success.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AxisColors.success
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                isArabic ? 'مكتمل' : 'DONE',
                                style: const TextStyle(
                                  color: AxisColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          else
                            Text(
                              '$percent%',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: prayerColor,
                              ),
                            ),
                          const SizedBox(width: 6),
                          // Reset Prayers Action Button
                          IconButton(
                            icon: _isResetting
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AxisColors.textDim,
                                    ),
                                  )
                                : const Icon(Icons.restart_alt_rounded,
                                    size: 18, color: AxisColors.textDim),
                            tooltip: isArabic
                                ? "إعادة ضبط صلوات اليوم"
                                : "Reset Today's Prayers",
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 26, minHeight: 26),
                            onPressed:
                                _isResetting ? null : _handleConfirmReset,
                          ),
                          // Refresh location & times button
                          IconButton(
                            icon: const Icon(Icons.sync_rounded,
                                size: 18, color: AxisColors.textDim),
                            tooltip: isArabic
                                ? 'تحديث أوقات الصلاة والموقع'
                                : 'Refresh Prayer Times & Location',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 26, minHeight: 26),
                            onPressed: () async {
                              await widget.onRefreshLocation();
                              if (context.mounted) {
                                AxisSnackBar.show(
                                  context,
                                  message: isArabic
                                      ? 'تم تحديث أوقات الصلاة لمدينة ${PrayerTimeService().currentCity}'
                                      : 'Prayer times refreshed for ${PrayerTimeService().currentCity}',
                                  icon: Icons.location_on_outlined,
                                );
                              }
                            },
                          ),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOutCubic,
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AxisColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar track
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHighest,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 6,
                            width: constraints.maxWidth * progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isComplete
                                    ? [
                                        AxisColors.success,
                                        const Color(0xFF34D399),
                                      ]
                                    : [
                                        prayerColor,
                                        prayerColor.withValues(alpha: 0.8),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              boxShadow: [
                                BoxShadow(
                                  color: (isComplete
                                          ? AxisColors.success
                                          : prayerColor)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Prayer Breakdown & Actions (animated expand & shrink)
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: ExcludeSemantics(
                excluding: !_expanded,
                child: _expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(
                              color: AxisColors.borderSubtle, height: 1),

                          // Qibla Direction Button
                          PrayerQiblaActionButton(
                            prayerColor: prayerColor,
                            isArabic: isArabic,
                          ),

                          // Adhan Alerts & Fajr Alarm Button
                          PrayerAdhanAlertsActionButton(
                            isArabic: isArabic,
                          ),

                          // List of the 5 prayers
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            itemCount: widget.prayers.length,
                            separatorBuilder: (_, _) => const Divider(
                                color: AxisColors.borderGlass2, height: 1),
                            itemBuilder: (context, i) {
                              final prayer = widget.prayers[i];
                              return HabitPrayerTile(
                                key: ValueKey('habit_prayer_${prayer.id}'),
                                prayer: prayer,
                                prayerColor: prayerColor,
                                isArabic: isArabic,
                                onToggle: (checked) =>
                                    widget.onTogglePrayer(prayer, checked),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
