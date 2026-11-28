import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';

/// Obsidian Kinetic design system — sourced directly from DESIGN.md
class AxisColors {
  AxisColors._();

  // Surfaces — exact values from DESIGN.md YAML
  static const Color canvasBase        = Color(0xFF051424); // #051424 deep void obsidian
  static const Color surfaceLowest     = Color(0xFF010F1F); // surface-container-lowest
  static const Color surfaceLow        = Color(0xFF0D1C2D); // surface-container-low
  static const Color surface           = Color(0xFF122131); // surface-container
  static const Color surfaceHigh       = Color(0xFF1C2B3C); // surface-container-high
  static const Color surfaceHighest    = Color(0xFF273647); // surface-container-highest
  static const Color surfaceBright     = Color(0xFF2C3A4C); // surface-bright

  // Glass tier backgrounds (use with opacity in BackdropFilter context)
  static const Color glassTier1        = Color(0xFF131A2A); // 0.65 alpha
  static const Color glassTier2        = Color(0xFF192236); // 0.82 alpha

  // Primary accents — from DESIGN.md narrative & Logo System
  static const Color primary           = Color(0xFF6366F1); // Electric Violet / Indigo (Logo left inner facet)
  static const Color primarySoft       = Color(0xFFC0C1FF); // primary on dark = text/icon use
  static const Color primarySofter     = Color(0xFF818CF8); // Soft Indigo (Logo left outer facet)
  static const Color secondary         = Color(0xFF0EA5E9); // Deep Cyan (Logo right inner facet)
  static const Color secondarySoft     = Color(0xFF7DD3FC); // Light Cyan (Logo right outer facet)
  static const Color secondaryBright   = Color(0xFF7DD3FC); // Light Cyan alias
  static const Color tertiary          = Color(0xFF4EDEA3); // Radiant Emerald (design tertiary)
  static const Color tertiaryBright    = Color(0xFF6FFBBE); // tertiary-fixed
  static const Color success           = Color(0xFF10B981); // gamification emerald
  static const Color warning           = Color(0xFFF59E0B); // Auric Amber (Logo peak shade)
  static const Color warningBright     = Color(0xFFFCD34D); // Bright Amber (Logo peak light)
  static const Color peakBright        = Color(0xFFFCD34D); // Bright Amber peak alias
  static const Color error             = Color(0xFFFFB4AB); // error red
  static const Color danger            = Color(0xFFEF4444); // P1 Crimson / danger alert

  // Priority Tokens
  static const Color priorityHigh      = Color(0xFFEF4444); // P1 Crimson
  static const Color priorityMed       = Color(0xFFF59E0B); // P2 Amber
  static const Color priorityLow       = Color(0xFF0EA5E9); // P3 Logo Deep Cyan

  // User-selectable presets across the app
  static const List<String> presetHexes = [
    '#6366F1', // Indigo (Logo primary)
    '#0EA5E9', // Sky / Cyan (Logo secondary)
    '#10B981', // Emerald
    '#F59E0B', // Amber (Logo peak)
    '#EC4899', // Pink / Rose
    '#8B5CF6', // Purple
  ];

  // Text
  static const Color textHigh          = Color(0xFFF8FAFC); // Primary headings, active
  static const Color textMuted         = Color(0xFF94A3B8); // Secondary metrics, timestamps
  static const Color textDim           = Color(0xFF8292A6); // Disabled & subtle labels (WCAG AA 4.8:1)

  // Borders
  static const Color borderSubtle      = Color(0x1FFFFFFF); // 12% white (improved contrast for sunlight/glare)
  static const Color borderGlass2      = Color(0x28FFFFFF); // 16% white (glass tier 2)
  static const Color borderActive      = Color(0x40C0C1FF); // primary-tinted
  static const Color borderPrimary     = Color(0x406366F1); // 25% indigo (action sheets)
  static const Color borderEmerald     = Color(0x6610B981); // 40% emerald streak rim
}

class AxisTheme {
  AxisTheme._();

  static const List<String> _sansFallbacks = ['Roboto', 'Segoe UI', 'Arial', 'sans-serif'];
  static const List<String> _monoFallbacks = ['Courier New', 'monospace'];

  // Root cause: AxisTheme.light reused the dark TextTheme with near-white textHigh/textMuted
  // colors on pale light backgrounds; parameterize foreground tones for light surfaces.
  static TextTheme _buildTextTheme({bool isLight = false}) {
    final primaryText = isLight ? const Color(0xFF0F172A) : AxisColors.textHigh;
    final secondaryText = isLight ? const Color(0xFF475569) : AxisColors.textMuted;
    final subtleText = isLight ? const Color(0xFF64748B) : AxisColors.textDim;

    return TextTheme(
      // headline-xl → displayLarge
      displayLarge: AxisFonts.spaceGrotesk(
        fontSize: 40, fontWeight: FontWeight.w700,
        height: 48 / 40, letterSpacing: -1.2,
        color: primaryText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // headline-lg → displayMedium
      displayMedium: AxisFonts.spaceGrotesk(
        fontSize: 28, fontWeight: FontWeight.w600,
        height: 36 / 28, letterSpacing: -0.56,
        color: primaryText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // headline-md → displaySmall
      displaySmall: AxisFonts.spaceGrotesk(
        fontSize: 22, fontWeight: FontWeight.w600,
        height: 30 / 22, letterSpacing: -0.33,
        color: primaryText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // title-lg → titleLarge
      titleLarge: AxisFonts.getFont('Geist',
        fontSize: 18, fontWeight: FontWeight.w600,
        height: 24 / 18, letterSpacing: -0.18,
        color: primaryText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // title-md → titleMedium
      titleMedium: AxisFonts.getFont('Geist',
        fontSize: 16, fontWeight: FontWeight.w600,
        height: 22 / 16, letterSpacing: -0.16,
        color: primaryText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // body-lg → bodyLarge
      bodyLarge: AxisFonts.getFont('Geist',
        fontSize: 16, fontWeight: FontWeight.w400,
        height: 24 / 16,
        color: primaryText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // body-md → bodyMedium
      bodyMedium: AxisFonts.getFont('Geist',
        fontSize: 14, fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: secondaryText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // body-sm → bodySmall
      bodySmall: AxisFonts.getFont('Geist',
        fontSize: 12, fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: subtleText,
      ).copyWith(fontFamilyFallback: _sansFallbacks),
      // label-lg → labelLarge
      labelLarge: AxisFonts.spaceMono(
        fontSize: 13, fontWeight: FontWeight.w700,
        height: 16 / 13, letterSpacing: 0.52,
        color: secondaryText,
      ).copyWith(fontFamilyFallback: _monoFallbacks),
      // label-md → labelMedium
      labelMedium: AxisFonts.spaceMono(
        fontSize: 11, fontWeight: FontWeight.w600,
        height: 14 / 11, letterSpacing: 0.66,
        color: secondaryText,
      ).copyWith(fontFamilyFallback: _monoFallbacks),
      // label-sm → labelSmall
      labelSmall: AxisFonts.spaceMono(
        fontSize: 10, fontWeight: FontWeight.w500,
        height: 12 / 10, letterSpacing: 0.8,
        color: subtleText,
      ).copyWith(fontFamilyFallback: _monoFallbacks),
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
        tertiary: AxisColors.tertiary,
        error: AxisColors.error,
        onSurface: AxisColors.textHigh,
        onPrimary: AxisColors.textHigh,
        onSecondary: AxisColors.canvasBase,
        onTertiary: AxisColors.canvasBase,
        outline: AxisColors.borderSubtle,
        inverseSurface: AxisColors.surfaceHigh,
        onInverseSurface: AxisColors.textHigh,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AxisColors.surfaceHigh,
        contentTextStyle: AxisFonts.getFont(
          'Geist',
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AxisColors.textHigh,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AxisColors.borderGlass2, width: 1.2),
        ),
        elevation: 8,
        actionTextColor: AxisColors.primarySoft,
        disabledActionTextColor: AxisColors.textDim,
        closeIconColor: AxisColors.textMuted,
      ),
      textTheme: textTheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: AxisColors.glassTier1,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AxisColors.borderSubtle, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AxisColors.borderSubtle, thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x331C2B3C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AxisColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AxisColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AxisColors.primary, width: 1.5),
        ),
        hintStyle: AxisFonts.getFont('Geist',
          fontSize: 16, color: AxisColors.textDim),
      ),
    );
  }

  /// High-contrast dark theme for optimal readability in outdoor and bright light conditions
  static ThemeData get highContrastDark {
    final base = dark;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        outline: const Color(0x4DFFFFFF), // 30% white
        inverseSurface: AxisColors.surfaceLowest,
        onInverseSurface: Colors.white,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: AxisColors.surfaceLowest,
        contentTextStyle: AxisFonts.getFont(
          'Geist',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x4DFFFFFF), width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0x4DFFFFFF),
        thickness: 1.2,
      ),
    );
  }

  /// Clean light theme alternative
  static ThemeData get light {
    final textTheme = _buildTextTheme(isLight: true);
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      colorScheme: const ColorScheme.light(
        surface: Color(0xFFFFFFFF),
        primary: AxisColors.primary,
        secondary: Color(0xFF0284C7),
        tertiary: Color(0xFF059669),
        error: Color(0xFFDC2626),
        onSurface: Color(0xFF0F172A),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onTertiary: Colors.white,
        outline: Color(0xFFCBD5E1),
        inverseSurface: Color(0xFF0F172A),
        onInverseSurface: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        contentTextStyle: AxisFonts.getFont(
          'Geist',
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155), width: 1.2),
        ),
        elevation: 8,
        actionTextColor: AxisColors.primary,
        disabledActionTextColor: const Color(0xFF94A3B8),
        closeIconColor: Colors.white70,
      ),
      textTheme: textTheme,
      useMaterial3: true,
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AxisColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
