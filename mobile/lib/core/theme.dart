import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Obsidian Kinetic design system — sourced directly from DESIGN.md
class AxisColors {
  AxisColors._();

  // Surfaces
  static const Color canvasBase        = Color(0xFF0B0F19);
  static const Color surfaceLow        = Color(0xFF0D1C2D);
  static const Color surface           = Color(0xFF122131);
  static const Color surfaceHigh       = Color(0xFF1E293B);
  static const Color surfaceHighest    = Color(0xFF273647);

  // Glass tier backgrounds (use withOpacity in BackdropFilter context)
  static const Color glassTier1        = Color(0xFF131A2A); // 0.65 alpha
  static const Color glassTier2        = Color(0xFF192236); // 0.82 alpha

  // Accents
  static const Color primary           = Color(0xFF6366F1); // Electric Violet
  static const Color primarySoft       = Color(0xFFC0C1FF);
  static const Color secondary         = Color(0xFF38BDF8); // Cyan
  static const Color secondarySoft     = Color(0xFF7BD0FF);
  static const Color success           = Color(0xFF10B981); // Emerald
  static const Color successBright     = Color(0xFF34D399);
  static const Color warning           = Color(0xFFF59E0B); // Amber
  static const Color warningBright     = Color(0xFFFBBF24);
  static const Color error             = Color(0xFFFFB4AB);

  // Text
  static const Color textHigh          = Color(0xFFF8FAFC);
  static const Color textMuted         = Color(0xFF94A3B8);
  static const Color textDim           = Color(0xFF475569);

  // Borders
  static const Color borderSubtle      = Color(0x14FFFFFF); // 8% white
  static const Color borderActive      = Color(0x40C0C1FF); // primary-tinted
  static const Color borderPrimary     = Color(0x406366F1); // 25% indigo
}

class AxisTheme {
  AxisTheme._();

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // headline-xl → displayLarge
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: 40, fontWeight: FontWeight.w700,
        height: 48 / 40, letterSpacing: -0.03 * 40,
        color: AxisColors.textHigh,
      ),
      // headline-lg → displayMedium
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: 28, fontWeight: FontWeight.w600,
        height: 36 / 28, letterSpacing: -0.02 * 28,
        color: AxisColors.textHigh,
      ),
      // headline-md → displaySmall
      displaySmall: GoogleFonts.spaceGrotesk(
        fontSize: 22, fontWeight: FontWeight.w600,
        height: 30 / 22, letterSpacing: -0.015 * 22,
        color: AxisColors.textHigh,
      ),
      // title-lg → titleLarge
      titleLarge: GoogleFonts.getFont('Geist',
        fontSize: 18, fontWeight: FontWeight.w600,
        height: 24 / 18, letterSpacing: -0.01 * 18,
        color: AxisColors.textHigh,
      ),
      // title-md → titleMedium
      titleMedium: GoogleFonts.getFont('Geist',
        fontSize: 16, fontWeight: FontWeight.w600,
        height: 22 / 16, letterSpacing: -0.01 * 16,
        color: AxisColors.textHigh,
      ),
      // body-lg → bodyLarge
      bodyLarge: GoogleFonts.getFont('Geist',
        fontSize: 16, fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: AxisColors.textHigh,
      ),
      // body-md → bodyMedium
      bodyMedium: GoogleFonts.getFont('Geist',
        fontSize: 14, fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AxisColors.textMuted,
      ),
      // body-sm → bodySmall
      bodySmall: GoogleFonts.getFont('Geist',
        fontSize: 12, fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AxisColors.textDim,
      ),
      // label-lg → labelLarge
      labelLarge: GoogleFonts.spaceMono(
        fontSize: 13, fontWeight: FontWeight.w700,
        height: 16 / 13, letterSpacing: 0.04 * 13,
        color: AxisColors.textMuted,
      ),
      // label-md → labelMedium
      labelMedium: GoogleFonts.spaceMono(
        fontSize: 11, fontWeight: FontWeight.w600,
        height: 14 / 11, letterSpacing: 0.06 * 11,
        color: AxisColors.textMuted,
      ),
      // label-sm → labelSmall
      labelSmall: GoogleFonts.spaceMono(
        fontSize: 10, fontWeight: FontWeight.w500,
        height: 12 / 10, letterSpacing: 0.08 * 10,
        color: AxisColors.textDim,
      ),
    );
  }

  static ThemeData get dark {
    final textTheme = _buildTextTheme();

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AxisColors.canvasBase,
      colorScheme: const ColorScheme.dark(
        surface: AxisColors.surface,
        primary: AxisColors.primary,
        secondary: AxisColors.secondary,
        tertiary: AxisColors.success,
        error: AxisColors.error,
        onSurface: AxisColors.textHigh,
        onPrimary: AxisColors.textHigh,
        onSecondary: AxisColors.canvasBase,
        outline: AxisColors.borderSubtle,
      ),
      textTheme: textTheme,
      useMaterial3: true,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AxisColors.glassTier1.withOpacity(0.95),
        indicatorColor: AxisColors.primary.withOpacity(0.18),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.spaceMono(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: AxisColors.primarySoft, letterSpacing: 0.6,
            );
          }
          return GoogleFonts.spaceMono(
            fontSize: 10, fontWeight: FontWeight.w500,
            color: AxisColors.textDim, letterSpacing: 0.6,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AxisColors.primarySoft, size: 22);
          }
          return const IconThemeData(color: AxisColors.textDim, size: 22);
        }),
      ),
      cardTheme: CardThemeData(
        color: AxisColors.glassTier1.withOpacity(0.65),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AxisColors.borderSubtle, thickness: 1,
      ),
    );
  }
}
