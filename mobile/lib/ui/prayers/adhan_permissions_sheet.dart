import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/adhan_alarm_service.dart';

/// Modal bottom sheet that prompts users to grant all required Android permissions
/// for reliable full-screen, unmuted Adhan prayer alarms.
///
/// Features:
/// - First-time prompt detection via [checkAndShowFirstTime]
/// - Live telemetry checking for all 4 critical permission levels
/// - One-tap grant flow that guides users through missing permissions sequentially
/// - Real-time auto-refresh on app resume from system settings
/// - Full Arabic / English localization support
class AdhanPermissionsSheet extends StatefulWidget {
  const AdhanPermissionsSheet({
    super.key,
    this.onCompleted,
  });

  final VoidCallback? onCompleted;

  /// Shows the Adhan permissions sheet as a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onCompleted,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdhanPermissionsSheet(onCompleted: onCompleted),
    );
  }

  /// Checks if Adhan is enabled, permissions are missing, and the user has not yet
  /// been prompted for Adhan permissions. If so, presents the sheet automatically.
  static Future<void> checkAndShowFirstTime(BuildContext context) async {
    final alarmService = AdhanAlarmService();
    if (!AdhanAlarmService.isSupportedPlatform) return;
    if (!alarmService.adhanNotificationsEnabled) return;
    if (alarmService.hasPromptedPermissions) return;

    // Check if already all granted
    final allGranted = await alarmService.areAllPermissionsGranted();
    if (allGranted) {
      await alarmService.setPermissionsPrompted(true);
      return;
    }

    // Mark as prompted and display the sheet
    await alarmService.setPermissionsPrompted(true);
    if (context.mounted) {
      await show(context);
    }
  }

  @override
  State<AdhanPermissionsSheet> createState() => _AdhanPermissionsSheetState();
}

class _AdhanPermissionsSheetState extends State<AdhanPermissionsSheet>
    with WidgetsBindingObserver {
  final _alarmService = AdhanAlarmService();

  bool _notificationAllowed = false;
  bool _exactAlarmAllowed = false;
  bool _fullScreenIntentAllowed = false;
  bool _overrideDndAllowed = false;
  bool _batteryUnrestricted = false;
  bool _overlayAllowed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final status = await _alarmService.checkDetailedPermissions();
      if (mounted) {
        setState(() {
          _notificationAllowed = status['notifications'] ?? false;
          _exactAlarmAllowed = status['exact_alarms'] ?? false;
          _fullScreenIntentAllowed = status['full_screen'] ?? false;
          _overrideDndAllowed = status['override_dnd'] ?? false;
          _batteryUnrestricted = status['battery_unrestricted'] ?? true;
          _overlayAllowed = status['display_over_apps'] ?? true;
        });
      }
    } catch (_) {}
  }

  bool get _allGranted =>
      _notificationAllowed &&
      _exactAlarmAllowed &&
      _fullScreenIntentAllowed &&
      _overrideDndAllowed &&
      _batteryUnrestricted;

  Future<void> _grantAll() async {
    HapticFeedback.mediumImpact();

    // 1. Basic notifications & full-screen intent (clean prompt without blocking settings queue)
    if (!_notificationAllowed || !_fullScreenIntentAllowed) {
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
      await _checkPermissions();

      // If user permanently denied or system dialog didn't grant, route directly to notification settings
      if (!_notificationAllowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF0F172A),
              content: Row(
                children: [
                  const Icon(Icons.notifications_active_rounded, color: Color(0xFF38BDF8), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.isArabic
                          ? 'يرجى تفعيل الإشعارات لتطبيق Axis في الشاشة التالية.'
                          : 'Please enable notifications for Axis in the upcoming screen.',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        await _alarmService.openNotificationSettings();
        return;
      }
    }

    // 2. Exact alarms (sub-second OS scheduling)
    if (!_exactAlarmAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            content: Row(
              children: [
                const Icon(Icons.alarm_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.isArabic
                        ? 'يرجى تفعيل مواعيد المنبه الدقيقة لتطبيق Axis في الشاشة التالية.'
                        : 'Please enable Exact Alarms for Axis in the upcoming screen.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      await _alarmService.openExactAlarmSettings();
      return;
    }

    // 3. Override Do Not Disturb (DND policy bypass)
    if (!_overrideDndAllowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            content: Row(
              children: [
                const Icon(Icons.do_not_disturb_off_rounded, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.isArabic
                        ? 'اختر تطبيق "Axis" وفعّل خيار السماح بتجاوز عدم الإزعاج لسماع الأذان دائماً.'
                        : 'Select "Axis" and turn ON "Do Not Disturb access" to hear the Adhan.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      await _alarmService.openDndSettings();
      return;
    }

    // 4. Unrestricted background battery (prevents OS from killing keep-alive / adhan wakes)
    if (!_batteryUnrestricted) {
      await _alarmService.requestIgnoreBatteryOptimizations();
      return;
    }

    // 5. Optional Display Over Other Apps permission (ensures screen pops up while using another app)
    if (!_overlayAllowed) {
      await _alarmService.openOverlaySettings();
      return;
    }

    // If already all granted
    await _checkPermissions();
    if (_allGranted && mounted) {
      widget.onCompleted?.call();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AxisColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.alarm_on_rounded,
                  color: Color(0xFF10B981),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic
                          ? 'صلاحيات أذان ومنبه الصلاة'
                          : 'Adhan & Prayer Alarm Permissions',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isArabic
                          ? 'مطلوبة لضمان سماع الأذان وعرض الشاشة الكاملة في الوقت الشرعي'
                          : 'Required for reliable astronomical timing, full-screen alerts & DND bypass',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AxisColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Permission Items
          _buildPermissionItem(
            icon: Icons.notifications_active_rounded,
            iconColor: const Color(0xFF38BDF8),
            title: isArabic ? 'إشعارات الأذان اليومية' : 'Prayer Notifications',
            subtitle: isArabic
                ? 'إرسال إشعارات الأذان ذات الأولوية العالية عند حلول وقت الصلاة.'
                : 'Delivers high-priority prayer notifications at exact times.',
            isGranted: _notificationAllowed,
            onTap: _notificationAllowed
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await _alarmService.openNotificationSettings();
                  },
          ),
          const SizedBox(height: 10),

          _buildPermissionItem(
            icon: Icons.access_time_filled_rounded,
            iconColor: const Color(0xFFF59E0B),
            title: isArabic ? 'المواعيد الدقيقة للمنبه' : 'Exact Alarms (Sub-Second)',
            subtitle: isArabic
                ? 'يضمن تشغيل الأذان في الثانية الدقيقة للوقت الشرعي حتى أثناء سكون الجهاز.'
                : 'Ensures call to prayer fires at the exact second even during device doze.',
            isGranted: _exactAlarmAllowed,
            onTap: _exactAlarmAllowed
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await _alarmService.openExactAlarmSettings();
                  },
          ),
          const SizedBox(height: 10),

          _buildPermissionItem(
            icon: Icons.fullscreen_rounded,
            iconColor: const Color(0xFF8B5CF6),
            title: isArabic ? 'شاشة الأذان عند القفل' : 'Full-Screen Lock Screen Intent',
            subtitle: isArabic
                ? 'إيقاظ الشاشة وعرض واجهة الأذان الكاملة عندما يكون الهاتف مقفلاً.'
                : 'Wakes device screen and shows the full-screen Adhan overlay on lock screen.',
            isGranted: _fullScreenIntentAllowed,
            onTap: _fullScreenIntentAllowed
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await AwesomeNotifications().requestPermissionToSendNotifications(
                      channelKey: 'prayer_adhan_channel',
                      permissions: const [NotificationPermission.FullScreenIntent],
                    );
                    await _checkPermissions();
                  },
          ),
          const SizedBox(height: 10),

          _buildPermissionItem(
            icon: Icons.do_not_disturb_off_rounded,
            iconColor: const Color(0xFFEF4444),
            title: isArabic ? 'تجاوز وضع عدم الإزعاج' : 'Override Do Not Disturb',
            subtitle: isArabic
                ? 'يضمن سماع الأذان بحجم صوت المنبه حتى عندما يكون الهاتف صامتاً أو في وضع عدم الإزعاج.'
                : 'Plays the Adhan at full alarm volume even when your phone is in silent or DND mode.',
            isGranted: _overrideDndAllowed,
            onTap: _overrideDndAllowed
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: const Color(0xFF0F172A),
                        content: Text(
                          isArabic
                              ? 'اختر "Axis" وفعّل خيار السماح بتجاوز عدم الإزعاج.'
                              : 'Select "Axis" and enable Do Not Disturb access.',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    await _alarmService.openDndSettings();
                  },
          ),
          const SizedBox(height: 10),

          _buildPermissionItem(
            icon: Icons.battery_saver_rounded,
            iconColor: const Color(0xFF10B981),
            title: isArabic ? 'تشغيل دائم في الخلفية' : 'Unrestricted Background Activity',
            subtitle: isArabic
                ? 'يمنع النظام من إغلاق التطبيق في الخلفية لضمان فتح شاشة الأذان دائماً.'
                : 'Prevents the OS from killing Axis in the background so Adhan never misses.',
            isGranted: _batteryUnrestricted,
            onTap: _batteryUnrestricted
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await _alarmService.requestIgnoreBatteryOptimizations();
                  },
          ),
          const SizedBox(height: 10),

          _buildPermissionItem(
            icon: Icons.layers_rounded,
            iconColor: const Color(0xFF06B6D4),
            title: isArabic ? 'الظهور فوق التطبيقات الأخرى' : 'Display Over Other Apps',
            subtitle: isArabic
                ? 'يعرض شاشة الأذان فوراً فوق أي تطبيق تستخدمه عند حلول وقت الصلاة.'
                : 'Brings the Adhan screen straight to the front even if you are in another app.',
            isGranted: _overlayAllowed,
            onTap: _overlayAllowed
                ? null
                : () async {
                    HapticFeedback.lightImpact();
                    await _alarmService.openOverlaySettings();
                  },
          ),
          const SizedBox(height: 20),

          // Action Button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _allGranted
                  ? () {
                      HapticFeedback.lightImpact();
                      widget.onCompleted?.call();
                      Navigator.of(context).pop(true);
                    }
                  : _grantAll,
              icon: Icon(
                _allGranted ? Icons.check_circle_rounded : Icons.verified_user_rounded,
                size: 18,
              ),
              label: Text(
                _allGranted
                    ? (isArabic ? 'تم تفعيل كافة الصلاحيات ✓' : 'All Permissions Granted ✓')
                    : (isArabic ? 'منح كافة الصلاحيات' : 'Grant All Permissions'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _allGranted ? const Color(0xFF059669) : const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Secondary Dismiss
          if (!_allGranted)
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                Navigator.of(context).pop(false);
              },
              child: Text(
                isArabic ? 'لاحقاً' : 'Skip for now',
                style: const TextStyle(color: AxisColors.textDim, fontSize: 13),
              ),
            ),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isGranted,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isGranted
                  ? const Color(0xFF10B981).withValues(alpha: 0.25)
                  : AxisColors.borderSubtle,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AxisColors.textDim,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGranted ? Icons.check_rounded : Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGranted
                          ? (context.isArabic ? 'مفعل' : 'GRANTED')
                          : (context.isArabic ? 'منح' : 'GRANT'),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: isGranted ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
