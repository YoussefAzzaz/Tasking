import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/ui/prayers/adhan_full_screen_alarm.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:axis/data/auth_service.dart';
import 'package:axis/ui/common/splash/splash_technical_grid.dart';
import 'package:axis/ui/common/splash/kinetic_orbital_nexus.dart';
import 'package:axis/ui/common/splash/vault_sync_telemetry_card.dart';

export 'package:axis/ui/common/splash/splash_technical_grid.dart';
export 'package:axis/ui/common/splash/kinetic_orbital_nexus.dart';
export 'package:axis/ui/common/splash/vault_sync_telemetry_card.dart';

/// Kinetic Cyber-Minimalism Splash Screen for Axis OS
/// Generated & architected using Stitch MCP design system specification.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Staggered Entrance & Progress Controllers
  late final AnimationController _entranceCtrl;
  late final AnimationController _orbitalCtrl;
  late final AnimationController _progressCtrl;

  // Animations
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _progressAnim;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();

    // 1. Entrance animation (fade and subtle scale)
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );

    // 2. Continuous slow kinetic orbital rotation
    _orbitalCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();

    // 3. Vault synchronization progress bar
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _progressAnim = CurvedAnimation(
      parent: _progressCtrl,
      curve: Curves.easeInOutCubic,
    );

    _entranceCtrl.forward();
    _progressCtrl.forward();

    // Automatic navigation after progress completion sequence
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _proceedToApp();
      }
    });
  }

  void _proceedToApp() {
    if (!mounted || _navigated) return;
    _navigated = true;

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        HapticFeedback.lightImpact();
      }
      final adhan = AdhanAlarmService().activeAdhanInfo;
      if (AuthService().hasActiveSession) {
        context.go('/today');
        unawaited(AuthService().tryAutoLoginOrSync());
      } else {
        context.go('/auth');
      }

      if (adhan != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null && !AdhanAlarmService().isFullScreenAlarmShowing) {
            AdhanFullScreenAlarm.show(
              ctx,
              prayerName: adhan['prayerName'] ?? 'Prayer',
              prayerNameAr: adhan['prayerNameAr'] ?? 'الصلاة',
              prayerTime: adhan['prayerTime'] ?? '',
              prayerId: adhan['prayerId'],
            );
          }
        });
      }
    } catch (e) {
      debugPrint('[SplashScreen] Navigation error: $e');
    }
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _orbitalCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    return ExcludeSemantics(
      excluding: isDesktop,
      child: Scaffold(
        backgroundColor: AxisColors.canvasBase,
        body: Stack(
          children: [
            // 1. Ambient Background Layer with Technical Coordinate Grid & Fog
            const SplashTechnicalGrid(),

            // 2. Main Content Architecture
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 6),

                        // Top App Header Telemetry Bar
                        _buildTopTelemetryBar(),

                        const SizedBox(height: 10),

                        // System Diagnostics Tri-Pill Row
                        _buildDiagnosticsPills(),

                        const Spacer(flex: 2),

                        // Central Kinetic Orbital Enclosure
                        KineticOrbitalNexus(orbitalCtrl: _orbitalCtrl),

                        const SizedBox(height: 24),

                        // Typographic Identity Anchor
                        _buildIdentityLockup(),

                        const Spacer(flex: 3),

                        // Vault Synchronization Telemetry Card
                        VaultSyncTelemetryCard(progressAnim: _progressAnim),

                        const SizedBox(height: 14),

                        // Primary Cyber Action Button
                        _buildFlowStateButton(),

                        const SizedBox(height: 12),

                        // Security Micro-Footer
                        _buildSecurityFooter(),

                        SizedBox(height: bottomPadding > 0 ? 4 : 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MARK: - Top Telemetry Bar
  Widget _buildTopTelemetryBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left: SYS.ONLINE Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
          decoration: BoxDecoration(
            color: AxisColors.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AxisColors.secondary,
                  boxShadow: [
                    BoxShadow(
                      color: AxisColors.secondary,
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'SYS.ONLINE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AxisColors.textMuted,
                ),
              ),
            ],
          ),
        ),

        // Center Brand Header
        Text(
          'AXIS',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.5,
            color: AxisColors.secondarySoft,
          ),
        ),

        // Right Wireless / Sensors Glyph
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: AxisColors.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.sensors_rounded,
            size: 16,
            color: AxisColors.secondary,
          ),
        ),
      ],
    );
  }

  // MARK: - Diagnostics Tri-Pills
  Widget _buildDiagnosticsPills() {
    return Row(
      children: [
        Expanded(
          child: _buildMicroPill(
            label: 'SYS.READY',
            dotColor: AxisColors.secondary,
            textColor: AxisColors.textHigh,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMicroPill(
            label: 'LOCAL-FIRST',
            dotColor: AxisColors.primarySofter,
            textColor: AxisColors.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMicroPill(
            label: 'MESH // 64',
            dotColor: AxisColors.warning,
            textColor: AxisColors.secondarySoft,
          ),
        ),
      ],
    );
  }

  Widget _buildMicroPill({
    required String label,
    required Color dotColor,
    required Color textColor,
  }) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.7),
                  blurRadius: 4,
                  spreadRadius: 0.5,
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // MARK: - Typographic Identity Lockup
  Widget _buildIdentityLockup() {
    return Column(
      children: [
        // Subtitle Tech Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLow.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'KINETIC FLOW OS • V2.4.0',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AxisColors.textHigh,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Main Brand Title
        Text(
          'AXIS',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AxisColors.textHigh,
            shadows: [
              Shadow(
                color: AxisColors.secondary.withValues(alpha: 0.35),
                blurRadius: 18,
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Product Descriptor
        Text(
          'Obsidian workspace architecture engineered\nfor relentless flow state.',
          textAlign: TextAlign.center,
          style: GoogleFonts.getFont(
            'Geist',
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: AxisColors.textMuted,
          ),
        ),
      ],
    );
  }

  // MARK: - Flow State Cyber Action Button
  Widget _buildFlowStateButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _proceedToApp,
        borderRadius: BorderRadius.circular(10),
        splashColor: AxisColors.secondary.withValues(alpha: 0.2),
        highlightColor: AxisColors.secondary.withValues(alpha: 0.1),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AxisColors.secondary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AxisColors.secondary.withValues(alpha: 0.50),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AxisColors.secondary.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.all_inclusive_rounded,
                    size: 18,
                    color: AxisColors.secondary,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'ENTER FLOW STATE',
                    style: GoogleFonts.getFont(
                      'Geist',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AxisColors.textHigh,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AxisColors.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // MARK: - Security Footer
  Widget _buildSecurityFooter() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 12,
            color: AxisColors.textDim.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Text(
            'OBSIDIAN CORE V2.4 • BIOMETRIC & LOCAL-FIRST ENCRYPTED',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.1,
              color: AxisColors.textDim.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
