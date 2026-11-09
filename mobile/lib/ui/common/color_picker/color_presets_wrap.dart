import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/l10n/app_localizations.dart';

/// Parses standard 6-char or 8-char hex strings with fallback.
Color parseHexColor(String hex) {
  try {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return const Color(0xFF6366F1);
}

/// Banner showing circle swatch preview and current active hex code.
class ColorPreviewBanner extends StatelessWidget {
  const ColorPreviewBanner({
    super.key,
    required this.activeColor,
    required this.currentHex,
  });

  final Color activeColor;
  final String currentHex;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: activeColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'اللون المحدد' : 'SELECTED COLOR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AxisColors.textMuted,
                    letterSpacing: isArabic ? 0.0 : 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentHex,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AxisColors.textHigh,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid/Wrap of curated popular vibrant preset color swatches.
class ColorPresetsWrap extends StatelessWidget {
  const ColorPresetsWrap({
    super.key,
    required this.presets,
    required this.currentHex,
    required this.onColorSelected,
  });

  final List<String> presets;
  final String currentHex;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isArabic ? 'ألوان شائعة' : 'POPULAR PRESETS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AxisColors.textMuted,
            letterSpacing: isArabic ? 0.0 : 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets.map((hex) {
            final col = parseHexColor(hex);
            final isSelected = currentHex.toUpperCase() == hex.toUpperCase();
            return InkWell(
              onTap: () => onColorSelected(col),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: col,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: col.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

