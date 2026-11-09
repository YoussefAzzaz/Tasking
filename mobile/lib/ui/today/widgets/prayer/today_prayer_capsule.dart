import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/prayer_time_service.dart';

/// Compact horizontal capsule for each of the 5 daily prayers on the Today screen.
class TodayPrayerCapsule extends StatelessWidget {
  const TodayPrayerCapsule({
    super.key,
    required this.prayer,
    required this.isDone,
    required this.isNext,
    required this.timeStr,
    required this.onToggle,
  });

  final Prayer prayer;
  final bool isDone;
  final bool isNext;
  final String timeStr;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
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

    final l10n = AppLocalizations.of(context);
    final localizedPrayerName = l10n.prayerName(prayer.prayerCode);

    return Semantics(
      button: true,
      label:
          '$localizedPrayerName, $timeStr, ${isDone ? (context.isArabic ? "مكتملة" : "Completed") : (context.isArabic ? "انقر للإكمال" : "Tap to complete")}',
      child: InkWell(
        onTap: () => onToggle(!isDone),
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
                localizedPrayerName,
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
}

/// Full-width detailed row for prayer telemetry.
class TodayDetailedPrayerRow extends StatelessWidget {
  const TodayDetailedPrayerRow({
    super.key,
    required this.prayer,
    required this.isDone,
    required this.isNext,
    required this.timeStr,
    required this.onToggle,
  });

  final Prayer prayer;
  final bool isDone;
  final bool isNext;
  final String timeStr;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
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

    final l10n = AppLocalizations.of(context);
    final localizedPrayerName = l10n.prayerName(prayer.prayerCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        label:
            '$localizedPrayerName, $timeStr, ${isDone ? (context.isArabic ? "تم" : "Done") : (context.isArabic ? "انقر للإكمال" : "Tap to complete")}',
        child: InkWell(
          onTap: () => onToggle(!isDone),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: borderColor, width: isNext ? 1.2 : 0.8),
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
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: Colors.black),
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
                  localizedPrayerName,
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
                  Text(
                    context.isArabic ? 'تم' : 'Done',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.success,
                    ),
                  )
                else if (isNext)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AxisColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AxisColors.primary),
                    ),
                    child: Text(
                      context.isArabic ? 'حان الآن' : 'DUE NOW',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.primary,
                      ),
                    ),
                  )
                else
                  Text(
                    context.isArabic ? 'قادمة' : 'Upcoming',
                    style: const TextStyle(
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

