import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../prayer_settings_sheet.dart';
import '../qibla_compass_sheet.dart';

/// Shows confirmation dialog for resetting today's prayers non-destructively.
Future<bool?> showConfirmResetPrayersDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AxisColors.surfaceLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AxisColors.borderPrimary),
      ),
      title: Text(
        context.isArabic ? "إعادة ضبط صلوات اليوم؟" : "Reset Today's Prayers?",
        style: const TextStyle(color: AxisColors.textHigh),
      ),
      content: Text(
        context.isArabic
            ? "سيؤدي هذا إلى إعادة ضبط جميع الصلوات الخمس اليومية كغير مكتملة لليوم مع الحفاظ على نقاط الخبرة والتقدم بأمان."
            : "This will reset all 5 daily prayers back to undone for today. Your accumulated EXP and streak progress will be safely preserved.",
        style: const TextStyle(color: AxisColors.textMuted),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(context.isArabic ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: AxisColors.textDim)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(context.isArabic ? 'إعادة ضبط' : 'Reset to Undone',
              style: const TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

/// Action button opening the interactive Qibla compass sheet.
class PrayerQiblaActionButton extends StatelessWidget {
  const PrayerQiblaActionButton({
    super.key,
    required this.prayerColor,
    required this.isArabic,
  });

  final Color prayerColor;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
      child: InkWell(
        onTap: () => QiblaCompassSheet.show(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: prayerColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: prayerColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.explore_rounded, size: 16, color: prayerColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isArabic
                      ? 'اتجاه القبلة (بوصلة وGPS مباشر)'
                      : 'Qibla Direction (Live GPS & Compass)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: prayerColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isArabic
                    ? Icons.arrow_back_ios_rounded
                    : Icons.arrow_forward_ios_rounded,
                size: 11,
                color: const Color(0xB310B981),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Action button opening Adhan alerts and Fajr mental alarm settings.
class PrayerAdhanAlertsActionButton extends StatelessWidget {
  const PrayerAdhanAlertsActionButton({
    super.key,
    required this.isArabic,
  });

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
      child: InkWell(
        onTap: () => PrayerSettingsSheet.show(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.alarm_on_rounded,
                  size: 16, color: Color(0xFFEF4444)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isArabic
                                ? 'تنبيهات الأذان ومنبه صلاة الفجر'
                                : 'Adhan Alerts & Fajr Alarm',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444)
                                .withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isArabic ? '+1 د' : '+1 MIN',
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isArabic
                          ? 'التحقق الذهني لمنع الغفوة مفعّل'
                          : 'Anti-snooze mental verification enabled',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AxisColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.tune_rounded,
                size: 14,
                color: Color(0xFFEF4444),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

