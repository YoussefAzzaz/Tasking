import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:axis/core/theme.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:axis/data/auth_service.dart';

/// Kinetic Splash Screen for Mobile & Desktop launch
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    FlutterNativeSplash.remove();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnim = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _ctrl.forward();

    // Smooth transition to the main app after splash sequence
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        if (AuthService().hasActiveSession) {
          context.go('/today');
          unawaited(AuthService().tryAutoLoginOrSync());
        } else {
          context.go('/auth');
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: Stack(
        children: [
          // Ambient background glow
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.primary.withValues(alpha: 0.12),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.primary.withValues(alpha: 0.2),
                    blurRadius: 90,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          // Main kinetic logo and branding
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo Card with glowing aura
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: AxisColors.primary.withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: AxisColors.secondary.withValues(alpha: 0.25),
                                blurRadius: 40,
                                spreadRadius: -4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'AXIS',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: AxisColors.textHigh,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4.0,
                              ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle Tagline
                        const Text(
                          'THE KINETIC PRODUCTIVITY & FLOW OS',
                          style: TextStyle(
                            color: AxisColors.primarySoft,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Subtle loading bar track
                        SizedBox(
                          width: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9999),
                            child: const LinearProgressIndicator(
                              minHeight: 2.5,
                              backgroundColor: AxisColors.surfaceHigh,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AxisColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom version tag
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'v1.0.0 • Obsidian Kinetic Engine',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AxisColors.textDim.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
