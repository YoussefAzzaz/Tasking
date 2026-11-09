import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/reading_preferences_service.dart';

/// Cyber-minimalist font size control widget for viewing task descriptions, notes, and journals.
/// Provides [A-] and [A+] stepping with a tap-to-reset percentage indicator.
class ReadingFontSizeControl extends StatelessWidget {
  const ReadingFontSizeControl({super.key});

  @override
  Widget build(BuildContext context) {
    final service = ReadingPreferencesService();
    final isArabic = AppLocalizations.of(context).isArabic;

    return ValueListenableBuilder<double>(
      valueListenable: service.fontScaleNotifier,
      builder: (context, fontScale, _) {
        final canDecrease = service.canDecrease;
        final canIncrease = service.canIncrease;
        final isDefault = (fontScale - 1.0).abs() < 0.01;
        final percentage = service.formattedPercentage;

        return Container(
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDefault
                  ? AxisColors.borderSubtle
                  : AxisColors.secondary.withValues(alpha: 0.4),
              width: 0.9,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decrease button (A-)
              Tooltip(
                message: isArabic ? 'تصغير حجم الخط' : 'Decrease font size',
                child: InkWell(
                  onTap: canDecrease
                      ? () {
                          HapticFeedback.selectionClick();
                          service.decreaseScale();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3.5),
                    child: Text(
                      'A-',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: canDecrease
                            ? AxisColors.textHigh
                            : AxisColors.textDim.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),

              // Percentage indicator (tap to reset to 100%)
              Tooltip(
                message: isDefault
                    ? (isArabic ? 'حجم الخط الافتراضي (100%)' : 'Default font size (100%)')
                    : (isArabic ? 'انقر لإعادة التعيين إلى 100%' : 'Tap to reset to 100%'),
                child: InkWell(
                  onTap: isDefault
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          service.resetScale();
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          percentage,
                          style: TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: isDefault
                                ? AxisColors.textDim
                                : AxisColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Increase button (A+)
              Tooltip(
                message: isArabic ? 'تكبير حجم الخط' : 'Increase font size',
                child: InkWell(
                  onTap: canIncrease
                      ? () {
                          HapticFeedback.selectionClick();
                          service.increaseScale();
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3.5),
                    child: Text(
                      'A+',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: canIncrease
                            ? AxisColors.secondary
                            : AxisColors.textDim.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
