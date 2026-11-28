import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/adhan_alarm_service.dart';
import '../../../../data/location_service.dart';
import '../../../../data/prayer_time_service.dart';
import '../../../../data/prayers/adhan_sound_service.dart';
import '../../../prayers/explore_adhan_sounds_sheet.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/telemetry_chip.dart';

/// Modal dialog for configuring Adhan notifications, Fajr alarm, and GPS calibration.
class DesktopPrayerSettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsUpdated;

  const DesktopPrayerSettingsDialog({
    super.key,
    required this.onSettingsUpdated,
  });

  static void show(BuildContext context, {required VoidCallback onSettingsUpdated}) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => DesktopPrayerSettingsDialog(
        onSettingsUpdated: onSettingsUpdated,
      ),
    );
  }

  @override
  State<DesktopPrayerSettingsDialog> createState() => _DesktopPrayerSettingsDialogState();
}

class _DesktopPrayerSettingsDialogState extends State<DesktopPrayerSettingsDialog> {
  late bool _adhanEnabled;
  late bool _fajrAlarmEnabled;
  bool _isSyncing = false;

  final _alarmService = AdhanAlarmService();
  final _prayerService = PrayerTimeService();

  @override
  void initState() {
    super.initState();
    _adhanEnabled = _alarmService.adhanNotificationsEnabled;
    _fajrAlarmEnabled = _alarmService.fajrAlarmEnabled;
  }

  String _resolveLocationLabel(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    if (_prayerService.currentCity.isNotEmpty && _prayerService.currentCity != 'Auto') {
      if (_prayerService.currentCountry.isNotEmpty) {
        return '${_prayerService.currentCity}, ${_prayerService.currentCountry}';
      }
      return _prayerService.currentCity;
    }
    final cached = LocationService().cachedLocation;
    if (cached != null && cached.city.isNotEmpty) {
      if (cached.country.isNotEmpty) {
        return '${cached.city}, ${_cachedOrEmpty(cached.country)}';
      }
      return cached.city;
    }
    return isArabic ? 'المحطة المحلية' : 'Local Station';
  }

  String _cachedOrEmpty(String c) => c;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AxisColors.canvasBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AxisColors.borderGlass2, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 18, color: AxisColors.secondary),
                    const SizedBox(width: 8),
                    Text(
                      isArabic ? 'قياسات ومنبهات الصلوات' : 'Prayer Telemetry & Alarms',
                      style: AxisFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.textHigh,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Qibla telemetry card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AxisColors.secondary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(Icons.explore_rounded, size: 18, color: AxisColors.secondary),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? 'اتجاه القبلة' : 'QIBLA BEARING',
                                style: AxisFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isArabic
                                    ? '${_prayerService.qiblaBearing.toStringAsFixed(1)}° بالنسبة للشمال'
                                    : '${_prayerService.qiblaBearing.toStringAsFixed(1)}° Relative to North',
                                style: AxisFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TelemetryChip(
                    label: isArabic ? 'مكة المكرمة' : 'MECCA',
                    color: AxisColors.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Adhan Notifications Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'إشعارات الأذان' : 'Adhan Notifications',
                          style: AxisFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic
                              ? 'إشعار يومي عند حلول وقت كل صلاة'
                              : 'Daily notification on every prayer window',
                          style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _adhanEnabled,
                    activeThumbColor: AxisColors.secondary,
                    onChanged: (val) async {
                      setState(() => _adhanEnabled = val);
                      await _alarmService.setAdhanNotificationsEnabled(val);
                      widget.onSettingsUpdated();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Adhan Sound Selector
            ValueListenableBuilder<AdhanSoundOption>(
              valueListenable: AdhanSoundService().selectedSoundNotifier,
              builder: (context, activeSound, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'صوت الأذان النشط' : 'Active Adhan Sound',
                              style: AxisFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textHigh,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${isArabic ? activeSound.nameAr : activeSound.name} • ${isArabic ? activeSound.muadhinAr : activeSound.muadhin}',
                              style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.primarySoft),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GhostButton(
                        label: isArabic ? 'تصفح الأصوات' : 'Explore Sounds',
                        icon: Icons.music_note_rounded,
                        onPressed: () {
                          ExploreAdhanSoundsSheet.showAsDialog(context);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // Smart Fajr Wake-Up Alarm Toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'منبه الفجر الذكي للاستيقاظ' : 'Fajr Smart Wake-Up Alarm',
                          style: AxisFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AxisColors.textHigh,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isArabic
                              ? 'تنبيه صوتي مستمر للاستيقاظ لصلاة الفجر'
                              : 'Persistent acoustic wake-up alert at dawn',
                          style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _fajrAlarmEnabled,
                    activeThumbColor: AxisColors.warning,
                    onChanged: (val) async {
                      setState(() => _fajrAlarmEnabled = val);
                      await _alarmService.setFajrAlarmEnabled(val);
                      widget.onSettingsUpdated();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Refresh GPS Location and times
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isArabic
                        ? 'الموقع: ${_resolveLocationLabel(context)}'
                        : 'Location: ${_resolveLocationLabel(context)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AxisFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                  ),
                ),
                const SizedBox(width: 8),
                GhostButton(
                  label: _isSyncing
                      ? (isArabic ? 'جارٍ المزامنة...' : 'Syncing...')
                      : (isArabic ? 'مزامنة الموقع GPS' : 'Sync GPS'),
                  icon: Icons.refresh_rounded,
                  onPressed: _isSyncing
                      ? null
                      : () async {
                          setState(() => _isSyncing = true);
                          await _prayerService.syncPrayers(forceLocation: true);
                          if (mounted) {
                            setState(() => _isSyncing = false);
                            widget.onSettingsUpdated();
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

