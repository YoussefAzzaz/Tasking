import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/router.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/prayer_time_service.dart';

/// Full-screen Adhan alarm overlay that fills the entire screen
/// when a prayer time arrives — even over the lock screen.
///
/// Plays the selected Adhan sound via the alarm audio channel,
/// shows the prayer name and time, and stays open until dismissed.
class AdhanFullScreenAlarm extends StatefulWidget {
  final String prayerName;
  final String prayerNameAr;
  final String prayerTime;
  final String? prayerId;

  const AdhanFullScreenAlarm({
    super.key,
    required this.prayerName,
    required this.prayerNameAr,
    required this.prayerTime,
    this.prayerId,
  });

  /// Shows the full-screen adhan alarm as a route overlay on top of everything.
  static void show(
    BuildContext context, {
    required String prayerName,
    required String prayerNameAr,
    required String prayerTime,
    String? prayerId,
  }) {
    // Prevent duplicate overlays
    if (AdhanAlarmService().isFullScreenAlarmShowing) return;
    AdhanAlarmService().isFullScreenAlarmShowing = true;

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return AdhanFullScreenAlarm(
            prayerName: prayerName,
            prayerNameAr: prayerNameAr,
            prayerTime: prayerTime,
            prayerId: prayerId,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  /// Closes any currently displaying full-screen Adhan overlay
  static void dismissCurrent([BuildContext? context]) {
    AdhanAlarmService().stopAlarmSound();
    AdhanAlarmService().isFullScreenAlarmShowing = false;
    final ctx = context ?? rootNavigatorKey.currentContext;
    if (ctx != null) {
      try {
        final rootNav = Navigator.of(ctx, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
          return;
        }
      } catch (_) {}
      try {
        if (Navigator.of(ctx).canPop()) {
          Navigator.of(ctx).pop();
          return;
        }
      } catch (_) {}
      try {
        ctx.go('/today');
      } catch (_) {}
    }
  }

  @override
  State<AdhanFullScreenAlarm> createState() => _AdhanFullScreenAlarmState();
}

class _AdhanFullScreenAlarmState extends State<AdhanFullScreenAlarm>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _waveController;

  static const _prayerIcons = <String, IconData>{
    'Fajr': Icons.wb_twilight_rounded,
    'Dhuhr': Icons.wb_sunny_rounded,
    'Asr': Icons.sunny_snowing,
    'Maghrib': Icons.nights_stay_rounded,
    'Isha': Icons.dark_mode_rounded,
  };

  static const _prayerColors = <String, Color>{
    'Fajr': Color(0xFF38BDF8),
    'Dhuhr': Color(0xFFFBBF24),
    'Asr': Color(0xFFF97316),
    'Maghrib': Color(0xFFEF4444),
    'Isha': Color(0xFF8B5CF6),
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Start adhan sound immediately via alarm channel
    AdhanAlarmService().startAlarmSound();

    // Make system UI transparent for truly immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    AdhanAlarmService().isFullScreenAlarmShowing = false;
    _pulseController.dispose();
    _waveController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _dismiss() async {
    HapticFeedback.lightImpact();
    AdhanAlarmService().isFullScreenAlarmShowing = false;
    unawaited(AdhanAlarmService().stopAlarmSound());

    if (mounted) {
      try {
        final rootNav = Navigator.of(context, rootNavigator: true);
        if (rootNav.canPop()) {
          rootNav.pop();
          return;
        }
      } catch (_) {}

      try {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }
      } catch (_) {}

      try {
        context.go('/today');
        return;
      } catch (_) {}

      try {
        rootNavigatorKey.currentContext?.go('/today');
      } catch (_) {}
    }
  }

  Future<void> _dismissAndMarkDone() async {
    HapticFeedback.mediumImpact();
    if (widget.prayerId != null) {
      await PrayerTimeService().togglePrayer(widget.prayerId!, true);
    }
    await _dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final prayerColor =
        _prayerColors[widget.prayerName] ?? const Color(0xFF38BDF8);
    final prayerIcon =
        _prayerIcons[widget.prayerName] ?? Icons.mosque_rounded;
    final displayName = isArabic ? widget.prayerNameAr : widget.prayerName;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          AdhanAlarmService().stopAlarmSound();
          AdhanAlarmService().isFullScreenAlarmShowing = false;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF020810),
        body: Stack(
          children: [
            // Animated radial gradient background
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final opacity = 0.15 + (_pulseController.value * 0.1);
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        prayerColor.withValues(alpha: opacity),
                        const Color(0xFF020810),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Main content
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Mosque icon with pulse animation
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) {
                          final scale =
                              1.0 + (_pulseController.value * 0.08);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: prayerColor.withValues(alpha: 0.15),
                                border: Border.all(
                                  color: prayerColor.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: prayerColor.withValues(alpha: 0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Icon(
                                prayerIcon,
                                size: 44,
                                color: prayerColor,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // "Adhan" label
                      Text(
                        isArabic ? 'حان وقت الصلاة' : 'PRAYER TIME',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: isArabic ? 0 : 3,
                          color: prayerColor.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Prayer name
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: isArabic ? 0 : 2,
                          shadows: [
                            Shadow(
                              color: prayerColor.withValues(alpha: 0.5),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Prayer time
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: prayerColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: prayerColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          widget.prayerTime,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: prayerColor,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Hadith / Islamic reminder
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          isArabic
                              ? 'حَافِظُوا عَلَى الصَّلَوَاتِ وَالصَّلَاةِ الْوُسْطَىٰ'
                              : 'Guard strictly your prayers,\nespecially the middle prayer.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withValues(alpha: 0.5),
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isArabic ? '— سورة البقرة ٢٣٨' : '— Al-Baqarah 2:238',
                        style: TextStyle(
                          fontSize: 10,
                          color: prayerColor.withValues(alpha: 0.5),
                        ),
                      ),

                      const Spacer(flex: 3),

                      // Dismiss button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _dismiss,
                          icon: const Icon(Icons.close_rounded, size: 22),
                          label: Text(
                            isArabic ? 'إغلاق الأذان' : 'Dismiss Adhan',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: prayerColor.withValues(alpha: 0.2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: prayerColor.withValues(alpha: 0.5),
                              ),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Mark as done + dismiss
                      TextButton.icon(
                        onPressed: _dismissAndMarkDone,
                        icon: Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AxisColors.success.withValues(alpha: 0.8),
                        ),
                        label: Text(
                          isArabic
                              ? 'تم — تمت الصلاة ✓'
                              : 'Mark as Prayed ✓',
                          style: TextStyle(
                            fontSize: 13,
                            color: AxisColors.success.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
