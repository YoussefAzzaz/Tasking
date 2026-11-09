import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/core/l10n/locale_service.dart';

/// Cubit managing the application's active [Locale] state.
///
/// Dispatches language updates reactively across the widget tree and synchronizes
/// with [LocaleService] to persist the user's choice to disk across sessions.
class LocaleCubit extends Cubit<Locale> {
  final LocaleService _localeService;
  late final VoidCallback _serviceListener;

  LocaleCubit({LocaleService? localeService})
      : _localeService = localeService ?? LocaleService(),
        super(localeService?.currentLocale ?? LocaleService().currentLocale) {
    _serviceListener = () {
      if (state != _localeService.currentLocale) {
        emit(_localeService.currentLocale);
      }
    };
    _localeService.localeNotifier.addListener(_serviceListener);
  }

  /// Whether the active locale is Arabic ('ar').
  bool get isArabic => state.languageCode == 'ar';

  /// Whether the active locale is English ('en').
  bool get isEnglish => state.languageCode == 'en';

  /// Toggles between English ('en') and Arabic ('ar').
  Future<void> toggleLanguage() async {
    final next = isArabic ? const Locale('en') : const Locale('ar');
    await setLocale(next);
  }

  /// Sets the active locale, emits the new state, and persists choice asynchronously.
  Future<void> setLocale(Locale locale) async {
    if (state == locale) return;
    emit(locale);
    await _localeService.setLocale(locale);
  }

  @override
  Future<void> close() {
    _localeService.localeNotifier.removeListener(_serviceListener);
    return super.close();
  }
}

/// Reactive extensions on [BuildContext] for clean locale access and dispatch.
extension LocaleCubitContextX on BuildContext {
  /// Watches the current active [Locale] from [LocaleCubit].
  Locale get activeLocale {
    try {
      return watch<LocaleCubit>().state;
    } catch (_) {
      try {
        return Localizations.localeOf(this);
      } catch (_) {
        return LocaleService().currentLocale;
      }
    }
  }

  /// Dispatches a language toggle through [LocaleCubit] with fallback to [LocaleService].
  Future<void> toggleLanguage() async {
    try {
      await read<LocaleCubit>().toggleLanguage();
    } catch (_) {
      await LocaleService().toggleLanguage();
    }
  }

  /// Sets the locale through [LocaleCubit] with fallback to [LocaleService].
  Future<void> setLocale(Locale locale) async {
    try {
      await read<LocaleCubit>().setLocale(locale);
    } catch (_) {
      await LocaleService().setLocale(locale);
    }
  }
}
