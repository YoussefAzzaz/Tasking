import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/locale_service.dart';
import 'package:axis/core/bloc/locale/locale_cubit.dart';

/// Compact, glowing language switch pill for login and register screens.
class AuthLanguageSwitcher extends StatelessWidget {
  const AuthLanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: LocaleService().localeNotifier,
      builder: (context, currentLocale, _) {
        final isAr = currentLocale.languageCode == 'ar';
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.toggleLanguage(),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AxisColors.borderGlass2,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.language_rounded,
                    size: 15,
                    color: AxisColors.primarySoft,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isAr ? 'English' : 'العربية',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AxisColors.textHigh,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

