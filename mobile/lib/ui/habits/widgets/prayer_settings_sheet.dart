import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/prayer_time_service.dart';

/// Modal bottom sheet allowing users to configure daily Adhan notifications,
/// the persistent anti-snooze Fajr wake-up alarm (+1 min), and test alarm verification.
class PrayerSettingsSheet extends StatefulWidget {
  const PrayerSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PrayerSettingsSheet(),
    );
  }

  @override
  State<PrayerSettingsSheet> createState() => _PrayerSettingsSheetState();
}

class _PrayerSettingsSheetState extends State<PrayerSettingsSheet> {
  final _alarmService = AdhanAlarmService();
  final _prayerService = PrayerTimeService();

  late bool _adhanEnabled;
  late bool _fajrAlarmEnabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _adhanEnabled = _alarmService.adhanNotificationsEnabled;
    _fajrAlarmEnabled = _alarmService.fajrAlarmEnabled;
  }

  Future<void> _toggleAdhan(bool value) async {
    HapticFeedback.selectionClick();
    setState(() {
      _adhanEnabled = value;
      _isSaving = true;
    });
    await _alarmService.setAdhanNotificationsEnabled(value);
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _toggleFajrAlarm(bool value) async {
    HapticFeedback.selectionClick();
    setState(() {
      _fajrAlarmEnabled = value;
      _isSaving = true;
    });
    await _alarmService.setFajrAlarmEnabled(value);
    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  void _testFajrAlarm() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    Future.delayed(const Duration(milliseconds: 300), () {
      _alarmService.triggerFajrWakeUpModal();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      decoration: BoxDecoration(
        color: const Color(0xF50D1524),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AxisColors.borderPrimary,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 30,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AxisColors.borderGlass2,
                borderRadius: BorderRadius.circular(9999),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PRAYER & ADHAN ALERTS',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.textHigh,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily reminders & cognitive wake-up alarm',
                      style: TextStyle(
                        fontSize: 12,
                        color: AxisColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSaving)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AxisColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Toggle 1: Daily Adhan Notifications
          _buildSettingCard(
            icon: Icons.notifications_active_rounded,
            iconColor: const Color(0xFF38BDF8),
            title: 'Daily Adhan Notifications',
            subtitle:
                'Receive high-priority notifications at exact prayer times (Fajr, Dhuhr, Asr, Maghrib, Isha).',
            value: _adhanEnabled,
            onChanged: _toggleAdhan,
          ),
          const SizedBox(height: 12),

          // Toggle 2: Fajr Anti-Snooze Wake-Up Alarm
          _buildSettingCard(
            icon: Icons.access_alarms_rounded,
            iconColor: const Color(0xFFEF4444),
            title: 'Fajr Anti-Snooze Wake-Up Alarm',
            subtitle:
                'Rings exactly 1 minute after Fajr Adhan with an unskippable arithmetic puzzle to ensure you wake up.',
            value: _fajrAlarmEnabled,
            onChanged: _toggleFajrAlarm,
            badgeText: '+1 MIN FAJR',
            badgeColor: const Color(0xFFEF4444),
          ),
          const SizedBox(height: 16),

          // Test Fajr Alarm Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _testFajrAlarm,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: Color(0xFFEF4444),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Test Fajr Wake-Up Alarm Now',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Auto-sync Location & Timezone info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.satellite_alt_rounded,
                  size: 16,
                  color: AxisColors.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Synced to ${_prayerService.currentCity}${_prayerService.currentCountry.isNotEmpty ? ', ${_prayerService.currentCountry}' : ''}. Prayer times auto-recalculate based on your local timezone.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AxisColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? iconColor.withValues(alpha: 0.4)
              : AxisColors.borderSubtle,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: iconColor),
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
                        title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.textHigh,
                        ),
                      ),
                    ),
                    if (badgeText != null && badgeColor != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AxisColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch(
            value: value,
            activeThumbColor: iconColor,
            activeTrackColor: iconColor.withValues(alpha: 0.35),
            inactiveThumbColor: AxisColors.textDim,
            inactiveTrackColor: AxisColors.surfaceHigh,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
