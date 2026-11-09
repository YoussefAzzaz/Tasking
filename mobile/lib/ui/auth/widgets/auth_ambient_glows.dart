import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

/// Ambient glowing cyber orbs rendered in the background of authentication screens.
class AuthAmbientGlows extends StatelessWidget {
  final bool isDesktop;

  const AuthAmbientGlows({
    super.key,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return Stack(
        children: [
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.primary.withValues(alpha: 0.10),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.primary.withValues(alpha: 0.20),
                    blurRadius: 140,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AxisColors.secondary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.secondary.withValues(alpha: 0.16),
                    blurRadius: 150,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -60,
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AxisColors.primary.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.primary.withValues(alpha: 0.25),
                  blurRadius: 90,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          left: -80,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AxisColors.secondary.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.secondary.withValues(alpha: 0.2),
                  blurRadius: 100,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

