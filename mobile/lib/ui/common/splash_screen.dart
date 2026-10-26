import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:axis/core/theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:axis/data/auth_service.dart';

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
    HapticFeedback.lightImpact();

    try {
      if (AuthService().hasActiveSession) {
        context.go('/today');
        unawaited(AuthService().tryAutoLoginOrSync());
      } else {
        context.go('/auth');
      }
    } catch (_) {
      // Running in test environment without GoRouter in hierarchy
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

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: Stack(
        children: [
          // 1. Ambient Background Layer with Technical Coordinate Grid
          Positioned.fill(
            child: CustomPaint(
              painter: _TechnicalGridPainter(),
            ),
          ),

          // 2. Atmospheric Chromatic Fog Radials
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                    blurRadius: 110,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.32,
            left: MediaQuery.of(context).size.width * 0.5 - 140,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.16),
                    blurRadius: 120,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.10),
                    blurRadius: 90,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 3. Main Content Architecture
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
                      _buildKineticNexus(),

                      const SizedBox(height: 24),

                      // Typographic Identity Anchor
                      _buildIdentityLockup(),

                      const Spacer(flex: 3),

                      // Vault Synchronization Telemetry Card
                      _buildVaultSyncCard(),

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
                  color: Color(0xFF38BDF8),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF38BDF8),
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
            color: const Color(0xFF8ED5FF),
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
            color: Color(0xFF38BDF8),
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
            dotColor: const Color(0xFF38BDF8),
            textColor: AxisColors.textHigh,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMicroPill(
            label: 'LOCAL-FIRST',
            dotColor: const Color(0xFF818CF8),
            textColor: AxisColors.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildMicroPill(
            label: 'MESH // 64',
            dotColor: const Color(0xFFC084FC),
            textColor: const Color(0xFF8ED5FF),
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

  // MARK: - Hero Kinetic Orbital Core
  Widget _buildKineticNexus() {
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
          alignment: Alignment.center,
          children: [
            // Technical Corner Reticles
            Positioned(
              top: 0,
              left: 0,
              child: Text(
                '⎡',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF3E484F),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Text(
                '⎤',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF3E484F),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: Text(
                '⎣',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF3E484F),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Text(
                '⎦',
                style: GoogleFonts.jetBrainsMono(
                  color: const Color(0xFF3E484F),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),

            // Outer Dashed Orbital Ring (Rotating Clockwise)
            RotationTransition(
              turns: _orbitalCtrl,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.16),
                    width: 1.2,
                  ),
                ),
              ),
            ),

            // Inner Gradient Orbit Arc (Counter-Rotating)
            AnimatedBuilder(
              animation: _orbitalCtrl,
              builder: (context, child) {
                return Transform.rotate(
                  angle: -_orbitalCtrl.value * 2 * math.pi * 1.5,
                  child: CustomPaint(
                    size: const Size(168, 168),
                    painter: _OrbitArcPainter(),
                  ),
                );
              },
            ),

            // Outer Glass Diamond Housing (Rotated 45 degrees)
            Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 114,
                height: 114,
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.18),
                      blurRadius: 24,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
            ),

            // Nested Diamond Layer with Reverse Tilt (Rotated 12 degrees)
            Transform.rotate(
              angle: math.pi / 15,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF818CF8).withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
              ),
            ),

            // Central Glowing Nexus with Axis Infinity Emblem
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF273647),
                    Color(0xFF122131),
                  ],
                ),
                border: Border.all(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF8ED5FF), Color(0xFF38BDF8)],
                  ).createShader(bounds),
                  child: const Icon(
                    Icons.all_inclusive_rounded,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Micro Coordinates Badge
            Positioned(
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
                child: Text(
                  'AX // 00.98',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
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
                  color: Color(0xFF38BDF8),
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
                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
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

  // MARK: - Vault Synchronization Telemetry Card
  Widget _buildVaultSyncCard() {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, child) {
        final pct = (_progressAnim.value * 100).toInt();
        return Semantics(
          label: 'Vault synchronization progress: $pct percent',
          value: '$pct%',
          child: Container(
            padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AxisColors.surfaceLow.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header Row with robust flexible text
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.lock_clock_outlined,
                          size: 14,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'SYNCHRONIZING SECURE OFFLINE VAULT',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.6,
                              color: AxisColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pct >= 100 ? '100% READY' : '$pct%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: const Color(0xFF8ED5FF),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Luminous Progress Bar
              Container(
                height: 4.5,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: constraints.maxWidth * _progressAnim.value,
                        height: 4.5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFF38BDF8),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF38BDF8),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // Telemetry Grid: 3 columns
              Container(
                padding: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTelemetryColumn(
                      label: 'LATENCY',
                      value: '0.8ms',
                      valueColor: AxisColors.textHigh,
                      align: CrossAxisAlignment.start,
                    ),
                    _buildTelemetryColumn(
                      label: 'STATE',
                      value: 'ENCRYPTED',
                      valueColor: const Color(0xFF38BDF8),
                      align: CrossAxisAlignment.center,
                    ),
                    _buildTelemetryColumn(
                      label: 'NODES',
                      value: '64 ACTIVE',
                      valueColor: const Color(0xFF818CF8),
                      align: CrossAxisAlignment.end,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
      },
    );
  }

  Widget _buildTelemetryColumn({
    required String label,
    required String value,
    required Color valueColor,
    required CrossAxisAlignment align,
  }) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: AxisColors.textDim,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: valueColor,
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
        splashColor: const Color(0xFF38BDF8).withValues(alpha: 0.2),
        highlightColor: const Color(0xFF38BDF8).withValues(alpha: 0.1),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.50),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
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
                    color: Color(0xFF38BDF8),
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
                color: Color(0xFF38BDF8),
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

/// Custom painter for subtle 24px technical coordinate grid
class _TechnicalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.035)
      ..strokeWidth = 1.0;

    const step = 28.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for animated orbital gradient arc
class _OrbitArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          Color(0xFF6366F1),
          Color(0xFF38BDF8),
          Colors.transparent,
        ],
        stops: [0.0, 0.45, 0.85, 1.0],
      ).createShader(rect);

    canvas.drawArc(rect, 0, math.pi * 1.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
