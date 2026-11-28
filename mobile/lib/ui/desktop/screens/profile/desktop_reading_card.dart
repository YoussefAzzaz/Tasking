import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/reading_preferences_service.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/ghost_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Reading font size preference controls and preview sample card.
class DesktopReadingCard extends StatelessWidget {
  const DesktopReadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = l10n.isArabic;
    final readingPref = ReadingPreferencesService();

    return ValueListenableBuilder<double>(
      valueListenable: readingPref.fontScaleNotifier,
      builder: (context, scale, _) {
        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: isAr ? 'تفضيلات القراءة' : 'READING PREFERENCES',
                subtitle: isAr
                    ? 'تغيير حجم خط القراءة لسياق المهام والملاحظات واليوميات'
                    : 'Scale reading text for task context, notes, and journals',
                trailing: TelemetryChip(
                  label: readingPref.formattedPercentage,
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GhostButton(
                        label: 'A-',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: readingPref.canDecrease ? readingPref.decreaseScale : null,
                      ),
                      const SizedBox(width: 6),
                      GhostButton(
                        label: isAr ? 'إعادة تعيين' : 'Reset',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        onPressed: readingPref.resetScale,
                      ),
                      const SizedBox(width: 6),
                      GhostButton(
                        label: 'A+',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        onPressed: readingPref.canIncrease ? readingPref.increaseScale : null,
                      ),
                    ],
                  ),
                  Text(
                    isAr
                        ? 'المستوى ${readingPref.currentStepIndex + 1} من ${ReadingPreferencesService.scaleSteps.length}'
                        : 'Step ${readingPref.currentStepIndex + 1} of ${ReadingPreferencesService.scaleSteps.length}',
                    style: AxisFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live preview sample
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'نموذج المعاينة' : 'PREVIEW SAMPLE',
                      style: AxisFonts.spaceGrotesk(fontSize: 9, fontWeight: FontWeight.w700, color: AxisColors.textDim),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAr
                          ? 'التركيز العميق والوضوح في البناء ينبعان من التنفيذ المستمر دون انقطاع.'
                          : 'Deep focus and architecture clarity come from uninterrupted execution.',
                      style: AxisFonts.getFont(
                        'Geist',
                        fontSize: 13 * scale,
                        height: 1.5,
                        color: AxisColors.textHigh,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

