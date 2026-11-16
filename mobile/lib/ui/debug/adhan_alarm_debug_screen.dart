import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/prayers/adhan_sound_service.dart';
import 'package:axis/ui/prayers/adhan_full_screen_alarm.dart';

/// Hidden diagnostic and test screen for the full-screen Adhan alarm system.
///
/// Allows QA engineers and developers to test:
/// - Immediate full-screen alarm overlays for all 5 prayers
/// - Background / Lock-screen alarms scheduled in 5s, 10s, or 30s
/// - Audio stream routing (Alarm stream vs Media stream)
/// - Exact alarm and full-screen intent permission statuses
/// - Cognitive Fajr wake-up dialog verification
class AdhanAlarmDebugScreen extends StatefulWidget {
  const AdhanAlarmDebugScreen({super.key});

  @override
  State<AdhanAlarmDebugScreen> createState() => _AdhanAlarmDebugScreenState();
}

class _AdhanAlarmDebugScreenState extends State<AdhanAlarmDebugScreen> with WidgetsBindingObserver {
  final _alarmService = AdhanAlarmService();
  final _soundService = AdhanSoundService();

  bool _isCheckingPermissions = false;
  bool _notificationAllowed = false;
  bool _exactAlarmAllowed = false;
  bool _fullScreenIntentAllowed = false;
  bool _criticalAlertAllowed = false;
  bool _overrideDndAllowed = false;
  bool _batteryUnrestricted = false;
  bool _overlayAllowed = false;
  bool _keepAliveActive = false;

  Timer? _countdownTimer;
  int _countdownSeconds = 0;
  int _selectedDelay = 5;

  static const _testNotificationId = 8888;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAllPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAllPermissions();
    }
  }

  Future<void> _checkAllPermissions() async {
    setState(() => _isCheckingPermissions = true);

    try {
      final status = await _alarmService.checkDetailedPermissions();
      final keepAlive = await _alarmService.isKeepAliveRunning();

      if (mounted) {
        setState(() {
          _notificationAllowed = status['notifications'] ?? false;
          _exactAlarmAllowed = status['exact_alarms'] ?? false;
          _fullScreenIntentAllowed = status['full_screen'] ?? false;
          _criticalAlertAllowed = status['critical_alerts'] ?? false;
          _overrideDndAllowed = status['override_dnd'] ?? false;
          _batteryUnrestricted = status['battery_unrestricted'] ?? true;
          _overlayAllowed = status['display_over_apps'] ?? true;
          _keepAliveActive = keepAlive;
          _isCheckingPermissions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingPermissions = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    HapticFeedback.lightImpact();
    setState(() => _isCheckingPermissions = true);

    // 1. If basic notifications are missing, request them first without queue blocking
    if (!_notificationAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications(
        channelKey: 'prayer_adhan_channel',
        permissions: const [
          NotificationPermission.Alert,
          NotificationPermission.Sound,
          NotificationPermission.Badge,
          NotificationPermission.Vibration,
          NotificationPermission.Light,
          NotificationPermission.FullScreenIntent,
          NotificationPermission.CriticalAlert,
        ],
      );
      await _checkAllPermissions();

      if (!_notificationAllowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening Notification settings. Please allow Axis.'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 3),
            ),
          );
        }
        await _alarmService.openNotificationSettings();
        return;
      }
    }

    // 2. If exact alarms missing, route to alarm page
    if (!_exactAlarmAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening Exact Alarms settings. Please allow Axis.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
      await _alarmService.openExactAlarmSettings();
      return;
    }

    // 3. If Override DnD is missing, route directly to system DND access page
    if (!_overrideDndAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF0F172A),
            content: Row(
              children: [
                Icon(Icons.do_not_disturb_off_rounded, color: Color(0xFFEF4444), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Opening Do Not Disturb access. Find "Axis" and switch it ON to allow Adhan.',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
      await _alarmService.openDndSettings();
      return;
    }

    // 4. Unrestricted background battery
    if (!_batteryUnrestricted) {
      await _alarmService.requestIgnoreBatteryOptimizations();
      return;
    }

    // 5. Display over other apps
    if (!_overlayAllowed) {
      await _alarmService.openOverlaySettings();
      return;
    }

    // 6. Re-check permissions and show feedback
    await _checkAllPermissions();
    if (mounted) {
      final allGranted = _notificationAllowed &&
          _exactAlarmAllowed &&
          _fullScreenIntentAllowed &&
          _overrideDndAllowed &&
          _batteryUnrestricted;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: allGranted ? const Color(0xFF065F46) : AxisColors.surfaceLow,
          content: Text(
            allGranted
                ? 'All Adhan alarm permissions are fully granted!'
                : 'Permissions refreshed.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Triggers full-screen adhan overlay immediately in foreground
  void _testImmediateAdhan({
    required String prayerName,
    required String prayerNameAr,
    required String prayerTime,
    String? prayerId,
  }) {
    HapticFeedback.heavyImpact();
    AdhanFullScreenAlarm.show(
      context,
      prayerName: prayerName,
      prayerNameAr: prayerNameAr,
      prayerTime: prayerTime,
      prayerId: prayerId,
    );
  }

  /// Schedules a test alarm notification with fullScreenIntent in N seconds
  Future<void> _scheduleTestAlarm(int seconds) async {
    HapticFeedback.selectionClick();
    final triggerTime = DateTime.now().add(Duration(seconds: seconds));

    try {
      await AwesomeNotifications().cancel(_testNotificationId);

      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: _testNotificationId,
          channelKey: 'prayer_adhan_channel',
          title: 'Adhan Test: Maghrib (المغرب)',
          body: 'Test Alarm: It is now time for Maghrib. Full screen intent triggered.',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Alarm,
          wakeUpScreen: true,
          fullScreenIntent: true,
          autoDismissible: false,
          locked: true,
          payload: {
            'type': 'adhan',
            'prayer_id': 'test_maghrib',
            'prayer_name': 'Maghrib',
            'prayer_name_ar': 'المغرب',
            'prayer_time': '06:15 PM',
          },
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'DISMISS_ADHAN',
            label: 'Dismiss',
            actionType: ActionType.Default,
          ),
          NotificationActionButton(
            key: 'MARK_DONE',
            label: 'Mark as Prayed',
            actionType: ActionType.Default,
          ),
        ],
        schedule: NotificationCalendar(
          year: triggerTime.year,
          month: triggerTime.month,
          day: triggerTime.day,
          hour: triggerTime.hour,
          minute: triggerTime.minute,
          second: triggerTime.second,
          millisecond: 0,
          repeats: false,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );

      await _alarmService.scheduleNativeAlarmForTime(
        requestCode: _testNotificationId,
        triggerTime: triggerTime,
        prayerName: 'Maghrib',
        prayerId: 'test_maghrib',
        prayerTime: '06:15 PM',
      );

      // Start countdown UI
      setState(() => _countdownSeconds = seconds);
      _countdownTimer?.cancel();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_countdownSeconds <= 1) {
          timer.cancel();
          if (mounted) setState(() => _countdownSeconds = 0);
        } else {
          if (mounted) setState(() => _countdownSeconds--);
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            content: Row(
              children: [
                const Icon(Icons.timer_rounded, color: AxisColors.secondary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Alarm scheduled in $seconds seconds! Lock screen or press Home now to test.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: seconds),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AxisColors.warning,
            content: Text('Error scheduling alarm: $e'),
          ),
        );
      }
    }
  }

  Future<void> _cancelTestAlarm() async {
    HapticFeedback.lightImpact();
    _countdownTimer?.cancel();
    setState(() => _countdownSeconds = 0);
    await AwesomeNotifications().cancel(_testNotificationId);
    await _alarmService.cancelNativeAlarm(_testNotificationId);
    await _alarmService.stopAlarmSound();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test alarm cancelled & sound stopped.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSound = _soundService.currentSound;

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      appBar: AppBar(
        backgroundColor: AxisColors.surfaceLowest,
        elevation: 0,
        title: Text(
          'ADHAN ALARM DEBUG COCKPIT',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: AxisColors.textHigh,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh Permissions',
            onPressed: _checkAllPermissions,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: Live Status Header
          _buildLiveStatusCard(activeSound),
          const SizedBox(height: 16),

          // Section 2: Permissions Diagnostics
          _buildPermissionsCard(),
          const SizedBox(height: 16),

          // Section 3: Scheduled Lock-Screen Test (App in Background / Screen Off)
          _buildScheduledTestCard(),
          const SizedBox(height: 16),

          // Section 4: Immediate Full-Screen Test (All 5 Prayers)
          _buildImmediateTestsCard(),
          const SizedBox(height: 16),

          // Section 5: Audio Stream Diagnostics
          _buildAudioDiagnosticsCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildLiveStatusCard(AdhanSoundOption activeSound) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AxisColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monitor_heart_rounded, color: AxisColors.secondary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'LIVE SYSTEM TELEMETRY',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AxisColors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatusRow('Active Sound:', activeSound.name),
          _buildStatusRow('Sound Source:', activeSound.isBundled ? 'Bundled Asset' : (activeSound.isCustom ? 'Custom File' : 'Downloaded')),
          _buildStatusRow('Audio Stream:', 'AndroidUsageType.alarm (Alarm Volume)'),
          _buildStatusRow('Alarm Ringing:', _alarmService.isAlarmRinging ? 'YES (Ringing)' : 'Idle', isPositive: _alarmService.isAlarmRinging),
          _buildStatusRow('Overlay Showing:', _alarmService.isFullScreenAlarmShowing ? 'YES (Visible)' : 'No', isPositive: _alarmService.isFullScreenAlarmShowing),
          _buildStatusRow('Background Service:', _keepAliveActive ? 'ACTIVE (Persistent)' : 'Stopped', isPositive: _keepAliveActive),
        ],
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PERMISSIONS AUDIT',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: AxisColors.textHigh,
                    ),
                  ),
                ],
              ),
              if (_isCheckingPermissions)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPermissionPill(
            'Notifications (POST_NOTIFICATIONS)',
            _notificationAllowed,
            onTap: _notificationAllowed ? null : () async {
              await _alarmService.openNotificationSettings();
            },
          ),
          _buildPermissionPill(
            'Exact Alarms (USE_EXACT_ALARM)',
            _exactAlarmAllowed,
            onTap: _exactAlarmAllowed ? null : () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening Exact Alarm settings. Please toggle Axis ON.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              await _alarmService.openExactAlarmSettings();
            },
          ),
          _buildPermissionPill(
            'Full-Screen Intent (USE_FULL_SCREEN_INTENT)',
            _fullScreenIntentAllowed,
            onTap: _fullScreenIntentAllowed ? null : () async {
              await AwesomeNotifications().requestPermissionToSendNotifications(
                channelKey: 'prayer_adhan_channel',
                permissions: const [NotificationPermission.FullScreenIntent],
              );
              await _checkAllPermissions();
            },
          ),
          _buildPermissionPill(
            'Critical Alerts (DND Bypass)',
            _criticalAlertAllowed,
            onTap: _criticalAlertAllowed ? null : () async {
              await AwesomeNotifications().requestPermissionToSendNotifications(
                channelKey: 'prayer_adhan_channel',
                permissions: const [NotificationPermission.CriticalAlert],
              );
              await _checkAllPermissions();
            },
          ),
          _buildPermissionPill(
            'Override Do-Not-Disturb',
            _overrideDndAllowed,
            onTap: _overrideDndAllowed ? null : () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: Color(0xFF0F172A),
                  content: Row(
                    children: [
                      Icon(Icons.do_not_disturb_off_rounded, color: Color(0xFFEF4444), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Opening Do Not Disturb access. Find "Axis" and switch it ON to allow Adhan.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 4),
                ),
              );
              await _alarmService.openDndSettings();
            },
          ),
          _buildPermissionPill(
            'Unrestricted Battery (Background)',
            _batteryUnrestricted,
            onTap: _batteryUnrestricted ? null : () async {
              await _alarmService.requestIgnoreBatteryOptimizations();
            },
          ),
          _buildPermissionPill(
            'Display Over Other Apps',
            _overlayAllowed,
            onTap: _overlayAllowed ? null : () async {
              await _alarmService.openOverlaySettings();
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _requestPermissions,
              icon: const Icon(Icons.verified_user_rounded, size: 16),
              label: const Text('Request / Grant All Alarm Permissions'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
                side: const BorderSide(color: Color(0xFF10B981)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledTestCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.alarm_add_rounded, color: Color(0xFFF59E0B), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TEST BACKGROUND / LOCK SCREEN ALARM',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tests phone wake-up & lock screen overlay when app is closed',
                      style: TextStyle(fontSize: 11, color: AxisColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Delay selection chips
          Row(
            children: [5, 10, 30, 60].map((sec) {
              final isSelected = _selectedDelay == sec;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('${sec}s'),
                  selected: isSelected,
                  selectedColor: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  onSelected: (val) {
                    if (val) setState(() => _selectedDelay = sec);
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Countdown banner if active
          if (_countdownSeconds > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_rounded, color: Color(0xFFF59E0B), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Alarm firing in $_countdownSeconds s! Lock screen NOW.',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _scheduleTestAlarm(_selectedDelay),
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                  label: Text('Trigger in ${_selectedDelay}s'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: _cancelTestAlarm,
                icon: const Icon(Icons.cancel_rounded, size: 16),
                label: const Text('Cancel / Stop'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImmediateTestsCard() {
    final testPrayers = [
      {'name': 'Fajr', 'nameAr': 'الفجر', 'time': '05:15 AM', 'id': 'habit_prayer_fajr', 'color': AxisColors.secondary, 'icon': Icons.wb_twilight_rounded},
      {'name': 'Dhuhr', 'nameAr': 'الظهر', 'time': '12:30 PM', 'id': 'habit_prayer_dhuhr', 'color': AxisColors.warningBright, 'icon': Icons.wb_sunny_rounded},
      {'name': 'Asr', 'nameAr': 'العصر', 'time': '03:45 PM', 'id': 'habit_prayer_asr', 'color': const Color(0xFFF97316), 'icon': Icons.sunny_snowing},
      {'name': 'Maghrib', 'nameAr': 'المغرب', 'time': '06:10 PM', 'id': 'habit_prayer_maghrib', 'color': const Color(0xFFEF4444), 'icon': Icons.nights_stay_rounded},
      {'name': 'Isha', 'nameAr': 'العشاء', 'time': '07:40 PM', 'id': 'habit_prayer_isha', 'color': const Color(0xFF8B5CF6), 'icon': Icons.dark_mode_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AxisColors.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.fullscreen_rounded, color: AxisColors.secondary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'TEST FULL-SCREEN OVERLAYS (FOREGROUND)',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AxisColors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Tap any prayer to test its full-screen alarm screen, theme, Arabic typography, and dismiss flow:',
            style: TextStyle(fontSize: 11.5, color: AxisColors.textMuted),
          ),
          const SizedBox(height: 12),

          // Grid of 5 prayers
          ...testPrayers.map((p) {
            final color = p['color'] as Color;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _testImmediateAdhan(
                  prayerName: p['name'] as String,
                  prayerNameAr: p['nameAr'] as String,
                  prayerTime: p['time'] as String,
                  prayerId: p['id'] as String?,
                ),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(p['icon'] as IconData, color: color, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        p['name'] as String,
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${p['nameAr']})',
                        style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        p['time'] as String,
                        style: const TextStyle(color: AxisColors.textHigh, fontSize: 12, fontFamily: 'monospace'),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AxisColors.textDim),
                    ],
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),
          // Fajr Wake-Up cognitive dialog test
          OutlinedButton.icon(
            onPressed: () => _alarmService.triggerFajrWakeUpModal(context: context),
            icon: const Icon(Icons.psychology_rounded, size: 16, color: Color(0xFFEF4444)),
            label: const Text('Test Fajr Wake-Up Math Challenge Modal'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
              side: const BorderSide(color: Color(0xFFEF4444)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioDiagnosticsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.volume_up_rounded, color: Color(0xFF8B5CF6), size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'AUDIO STREAM ROUTING DIAGNOSTICS',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: AxisColors.textHigh,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Verifies that playback routes through AndroidUsageType.alarm so sound plays at full alarm volume even when the phone is on silent mode or Do Not Disturb is enabled.',
            style: TextStyle(fontSize: 11.5, color: AxisColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _alarmService.startAlarmSound(),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Start Alarm Sound'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _alarmService.stopAlarmSound(),
                  icon: const Icon(Icons.stop_rounded, size: 18),
                  label: const Text('Stop Sound'),
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
    );
  }

  Widget _buildStatusRow(String label, String value, {bool? isPositive}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AxisColors.textDim)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isPositive == null
                  ? AxisColors.textHigh
                  : (isPositive ? AxisColors.success : AxisColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPill(String title, bool isGranted, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Icon(
                  isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  size: 16,
                  color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isGranted ? AxisColors.textHigh : AxisColors.textMuted,
                    ),
                  ),
                ),
                if (!isGranted && onTap != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'FIX',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(Icons.chevron_right_rounded, size: 12, color: Color(0xFFEF4444)),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isGranted
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isGranted ? 'GRANTED' : 'MISSING',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
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
