import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets.dart';
import '../../../../data/prayer_time_service.dart';

IconData prayerIconForName(String icon) {
  switch (icon.toLowerCase()) {
    case 'fajr':
      return Icons.wb_twilight_rounded;
    case 'dhuhr':
      return Icons.wb_sunny_rounded;
    case 'asr':
      return Icons.brightness_medium_rounded;
    case 'maghrib':
      return Icons.wb_twilight_rounded;
    case 'isha':
      return Icons.dark_mode_rounded;
    default:
      return Icons.mosque_rounded;
  }
}

/// Interactive list tile representing a single daily prayer in the habits card.
class HabitPrayerTile extends StatelessWidget {
  const HabitPrayerTile({
    super.key,
    required this.prayer,
    required this.prayerColor,
    required this.isArabic,
    required this.onToggle,
  });

  final Prayer prayer;
  final Color prayerColor;
  final bool isArabic;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDone = prayer.isDone;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AxisCheckbox(
            checked: isDone,
            onChanged: (checked) {
              HapticFeedback.lightImpact();
              onToggle(checked);
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        prayerIconForName(prayer.icon),
                        size: 14,
                        color: isDone ? AxisColors.textDim : prayerColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.prayerName(prayer.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              isDone ? AxisColors.textDim : AxisColors.textHigh,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 27),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time_filled_rounded,
                          size: 11, color: AxisColors.success),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          isArabic
                              ? 'الأذان ${prayer.time}'
                              : 'Adan ${prayer.time}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AxisColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDone
                  ? AxisColors.surfaceLow
                  : AxisColors.success.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isDone
                    ? AxisColors.borderSubtle
                    : AxisColors.success.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDone) ...[
                  const Icon(Icons.check_rounded,
                      size: 11, color: AxisColors.success),
                  const SizedBox(width: 3),
                ],
                Text(
                  isDone
                      ? (isArabic ? 'تمت' : 'DONE')
                      : (isArabic ? '+25 نقطة' : '+25 XP'),
                  style: TextStyle(
                    color: isDone ? AxisColors.textDim : AxisColors.success,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

