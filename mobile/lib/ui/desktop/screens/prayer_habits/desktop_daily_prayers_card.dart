import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/location_service.dart';
import '../../../../data/prayer_time_service.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_checkbox.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';
import 'weekly_consistency_grid.dart';

/// Left-hand panel showing daily prayer obligations, adhan windows, and weekly consistency grid.
class DesktopDailyPrayersCard extends StatelessWidget {
  final VoidCallback onShowSettings;

  const DesktopDailyPrayersCard({
    super.key,
    required this.onShowSettings,
  });

  String _resolveLocationLabel(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final prayerService = PrayerTimeService();
    if (prayerService.currentCity.isNotEmpty && prayerService.currentCity != 'Auto') {
      if (prayerService.currentCountry.isNotEmpty) {
        return '${prayerService.currentCity}, ${prayerService.currentCountry}';
      }
      return prayerService.currentCity;
    }
    final cached = LocationService().cachedLocation;
    if (cached != null && cached.city.isNotEmpty) {
      if (cached.country.isNotEmpty) {
        return '${cached.city}, ${cached.country}';
      }
      return cached.city;
    }
    return isArabic ? 'المحطة المحلية' : 'Local Station';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: isArabic ? 'الصلوات اليومية' : 'Daily Prayers',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TelemetryChip(
                  label: _resolveLocationLabel(context),
                  icon: Icons.location_on_rounded,
                  color: AxisColors.secondary,
                ),
                const SizedBox(width: 8),
                GhostButton(
                  label: isArabic ? 'الإعدادات' : 'Settings',
                  icon: Icons.tune_rounded,
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: onShowSettings,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: StreamBuilder<List<Prayer>>(
                stream: PrayerTimeService().watchPrayers(),
                builder: (context, snapshot) {
                  final prayers = snapshot.data ?? [];
                  return Column(
                    children: prayers.map((p) => _PrayerRow(prayer: p)).toList(),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          const WeeklyConsistencyGrid(),
        ],
      ),
    );
  }
}

class _PrayerRow extends StatelessWidget {
  final Prayer prayer;

  const _PrayerRow({required this.prayer});

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final arabicSubtitle = isArabic
        ? switch (prayer.prayerCode.toLowerCase()) {
            'fajr' => 'صلاة الفجر',
            'dhuhr' => 'صلاة الظهر',
            'asr' => 'صلاة العصر',
            'maghrib' => 'صلاة المغرب',
            'isha' => 'صلاة العشاء',
            _ => 'الصلاة',
          }
        : switch (prayer.prayerCode.toLowerCase()) {
            'fajr' => 'الفجر · Dawn',
            'dhuhr' => 'الظهر · Noon',
            'asr' => 'العصر · Afternoon',
            'maghrib' => 'المغرب · Sunset',
            'isha' => 'العشاء · Night',
            _ => 'الصلاة',
          };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: prayer.isDone ? AxisColors.surfaceLowest : AxisColors.surfaceHigh.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: prayer.isDone ? AxisColors.borderEmerald : AxisColors.borderSubtle,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          DesktopCheckbox(
            value: prayer.isDone,
            color: AxisColors.tertiary,
            onChanged: (val) {
              PrayerTimeService().togglePrayer(prayer.id, val);
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).prayerName(prayer.name),
                  style: AxisFonts.getFont(
                    'Geist',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: prayer.isDone ? AxisColors.textDim : AxisColors.textHigh,
                  ),
                ),
                Text(
                  arabicSubtitle,
                  style: AxisFonts.getFont(
                    'Geist',
                    fontSize: 11,
                    color: AxisColors.textDim,
                  ),
                ),
              ],
            ),
          ),
          Text(
            prayer.time,
            style: AxisFonts.spaceGrotesk(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AxisColors.textHigh,
            ),
          ),
          const SizedBox(width: 10),
          TelemetryChip(
            label: prayer.isDone
                ? (isArabic ? 'مكتملة' : 'Completed')
                : (isArabic ? 'مجدولة' : 'Scheduled'),
            color: prayer.isDone ? AxisColors.tertiary : AxisColors.textDim,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          ),
        ],
      ),
    );
  }
}

