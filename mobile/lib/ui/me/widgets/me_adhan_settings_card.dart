import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/prayers/adhan_sound_service.dart';
import 'package:axis/ui/prayers/explore_adhan_sounds_sheet.dart';

/// Configuration card in the Me profile screen for managing Adhan notification sounds,
/// Fajr wake-up alarms, previewing audio, and uploading custom device sounds.
class MeAdhanSettingsCard extends StatefulWidget {
  const MeAdhanSettingsCard({super.key});

  @override
  State<MeAdhanSettingsCard> createState() => _MeAdhanSettingsCardState();
}

class _MeAdhanSettingsCardState extends State<MeAdhanSettingsCard> {
  final _alarmService = AdhanAlarmService();
  final _soundService = AdhanSoundService();

  bool _adhanNotifications = true;
  bool _fajrAlarm = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _adhanNotifications = _alarmService.adhanNotificationsEnabled;
    _fajrAlarm = _alarmService.fajrAlarmEnabled;
  }

  Future<void> _toggleAdhanNotifications(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _adhanNotifications = value);
    await _alarmService.setAdhanNotificationsEnabled(value);
  }

  Future<void> _toggleFajrAlarm(bool value) async {
    HapticFeedback.lightImpact();
    setState(() => _fajrAlarm = value);
    await _alarmService.setFajrAlarmEnabled(value);
  }

  Future<void> _handleCustomUpload() async {
    HapticFeedback.lightImpact();
    setState(() => _isUploading = true);
    final customSound = await _soundService.pickAndSetCustomSound();
    if (mounted) {
      setState(() => _isUploading = false);
      if (customSound != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AxisColors.surfaceLow,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AxisColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selected custom sound: ${customSound.name}',
                    style: const TextStyle(color: AxisColors.textHigh, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = l10n.isArabic;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mosque_rounded,
                    color: Color(0xFF38BDF8),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'أصوات وتنبيهات الأذان' : 'ADHAN & PRAYER NOTIFICATIONS',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: isArabic ? 0.0 : 1.2,
                          color: AxisColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isArabic
                            ? 'تخصيص التكبيرات الأولى، تنبيهات الأوقات ومنبه الفجر'
                            : 'Configure short Takbeerat calls & Fajr alarm',
                        style: GoogleFonts.getFont(
                          'Geist',
                          fontSize: 11.5,
                          color: AxisColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AxisColors.borderSubtle, height: 1),
            const SizedBox(height: 14),

            // Toggle 1: Adhan Notifications
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: const Icon(Icons.volume_up_rounded, size: 18, color: AxisColors.primarySoft),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'إشعارات الأذان (التكبيرات)' : 'Adhan Notifications',
                        style: const TextStyle(
                          color: AxisColors.textHigh,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isArabic
                            ? 'تشغيل تكبيرات الأذان الأولى عند حلول وقت كل صلاة'
                            : 'Play the first Takbeerat at every prayer time',
                        style: const TextStyle(
                          color: AxisColors.textDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _adhanNotifications,
                  onChanged: _toggleAdhanNotifications,
                  activeThumbColor: AxisColors.primary,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Toggle 2: Fajr Wake-Up Alarm
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: const Icon(Icons.alarm_rounded, size: 18, color: Color(0xFFF59E0B)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'منبه الاستيقاظ لصلاة الفجر' : 'Fajr Wake-Up Alarm',
                        style: const TextStyle(
                          color: AxisColors.textHigh,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        isArabic
                            ? 'منبه ذكي بعد دقيقة من أذان الفجر مع تحديات إيقاظ'
                            : 'Smart cognitive alarm 1 min after Fajr',
                        style: const TextStyle(
                          color: AxisColors.textDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _fajrAlarm,
                  onChanged: _toggleFajrAlarm,
                  activeThumbColor: const Color(0xFFF59E0B),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(color: AxisColors.borderSubtle, height: 1),
            const SizedBox(height: 14),

            // Active Sound Card Header
            Text(
              isArabic ? 'صوت الأذان الحالي (التكبيرات):' : 'ACTIVE ADHAN SOUND (TAKBEERAT):',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AxisColors.textDim,
              ),
            ),
            const SizedBox(height: 8),

            // Current Sound Card with Preview Player
            ValueListenableBuilder<AdhanSoundOption>(
              valueListenable: _soundService.selectedSoundNotifier,
              builder: (context, activeSound, _) {
                return ValueListenableBuilder<String?>(
                  valueListenable: _soundService.previewingNotifier,
                  builder: (context, previewingId, _) {
                    final isPlaying = previewingId == activeSound.id;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPlaying
                              ? AxisColors.primary.withValues(alpha: 0.6)
                              : AxisColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Play / Stop Preview Button
                          InkWell(
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await _soundService.togglePreview(activeSound);
                            },
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPlaying
                                    ? AxisColors.warning.withValues(alpha: 0.2)
                                    : AxisColors.primary.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: isPlaying ? AxisColors.warning : AxisColors.primarySoft,
                                ),
                              ),
                              child: Icon(
                                isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                size: 20,
                                color: isPlaying ? AxisColors.warning : AxisColors.primarySoft,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Active Sound Information
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        isArabic ? activeSound.nameAr : activeSound.name,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AxisColors.textHigh,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: activeSound.isBundled
                                            ? const Color(0xFF10B981).withValues(alpha: 0.16)
                                            : AxisColors.primary.withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        activeSound.isBundled
                                            ? (isArabic ? 'مضمن' : 'OFFLINE')
                                            : (activeSound.isCustom
                                                ? (isArabic ? 'مخصص' : 'CUSTOM')
                                                : (isArabic ? 'مكتبة' : 'ONLINE')),
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          color: activeSound.isBundled
                                              ? const Color(0xFF10B981)
                                              : AxisColors.primarySoft,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isArabic ? activeSound.muadhinAr : activeSound.muadhin,
                                  style: GoogleFonts.getFont(
                                    'Geist',
                                    fontSize: 11,
                                    color: AxisColors.secondarySoft,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Open Explorer Modal
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AxisColors.textDim),
                            tooltip: isArabic ? 'تغيير صوت الأذان' : 'Change Sound',
                            onPressed: () => ExploreAdhanSoundsSheet.show(context),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            // Action Buttons: Explore Sounds & Upload Custom
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ExploreAdhanSoundsSheet.show(context),
                    icon: const Icon(Icons.library_music_rounded, size: 16, color: AxisColors.primarySoft),
                    label: Text(
                      isArabic ? 'استكشاف الأذانات' : 'Explore Sounds',
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.primarySoft,
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploading ? null : _handleCustomUpload,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AxisColors.textMuted),
                          )
                        : const Icon(Icons.upload_file_rounded, size: 16, color: AxisColors.textMuted),
                    label: Text(
                      isArabic ? 'رفع صوت من هاتفك' : 'Upload Audio',
                      style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.textHigh,
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
