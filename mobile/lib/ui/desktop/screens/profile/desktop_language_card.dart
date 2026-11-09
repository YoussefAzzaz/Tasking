import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/l10n/locale_service.dart';
import '../../../../core/bloc/locale/locale_cubit.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/telemetry_chip.dart';

/// Language switcher card for the desktop profile settings.
class DesktopLanguageCard extends StatelessWidget {
  const DesktopLanguageCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localeService = LocaleService();

    return ValueListenableBuilder<Locale>(
      valueListenable: localeService.localeNotifier,
      builder: (context, currentLocale, _) {
        final isArabic = currentLocale.languageCode == 'ar';
        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: l10n.language.toUpperCase(),
                subtitle: l10n.selectLanguage,
                trailing: TelemetryChip(
                  label: isArabic ? 'العربية (RTL)' : 'ENGLISH (LTR)',
                  color: AxisColors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.setLocale(const Locale('en')),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: !isArabic
                              ? AxisColors.primary.withValues(alpha: 0.18)
                              : AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: !isArabic ? AxisColors.primary : AxisColors.borderSubtle,
                            width: !isArabic ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!isArabic) ...[
                              const Icon(Icons.check_circle_rounded, color: AxisColors.primarySoft, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                'English (US)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 13,
                                  fontWeight: !isArabic ? FontWeight.w700 : FontWeight.w500,
                                  color: !isArabic ? AxisColors.textHigh : AxisColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => context.setLocale(const Locale('ar')),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: isArabic
                              ? AxisColors.primary.withValues(alpha: 0.18)
                              : AxisColors.surfaceLowest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isArabic ? AxisColors.primary : AxisColors.borderSubtle,
                            width: isArabic ? 1.5 : 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isArabic) ...[
                              const Icon(Icons.check_circle_rounded, color: AxisColors.primarySoft, size: 16),
                              const SizedBox(width: 6),
                            ],
                            const Flexible(
                              child: Text(
                                'العربية (Arabic)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

