import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:axis/core/storage/axis_storage.dart';

/// Centralized service managing language and locale preferences across Axis
/// on mobile and desktop platforms. Defaults to Arabic ('ar') per workspace requirement.
class LocaleService {
  static final LocaleService _instance = LocaleService._internal();
  factory LocaleService() => _instance;
  LocaleService._internal();

  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('ar'));

  Locale get currentLocale => localeNotifier.value;
  bool get isArabic => currentLocale.languageCode == 'ar';

  /// Initializes the saved locale preference from local storage.
  Future<void> init() async {
    try {
      final file = await AxisStorage.getLocaleFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        final code = map['languageCode'] as String?;
        if (code == 'ar' || code == 'en') {
          localeNotifier.value = Locale(code!);
        } else {
          localeNotifier.value = const Locale('ar');
        }
      } else {
        localeNotifier.value = const Locale('ar');
      }
    } catch (_) {
      // In-memory fallback if storage is unavailable or in test environments
      localeNotifier.value = const Locale('ar');
    }
  }

  /// Sets the active locale and persists the choice asynchronously.
  Future<void> setLocale(Locale locale) async {
    if (localeNotifier.value == locale) return;
    localeNotifier.value = locale;
    await _persist(locale.languageCode);
  }

  /// Toggles between English ('en') and Arabic ('ar').
  Future<void> toggleLanguage() async {
    final next = isArabic ? const Locale('en') : const Locale('ar');
    await setLocale(next);
  }

  Future<void> _persist(String code) async {
    try {
      final file = await AxisStorage.getLocaleFile();
      await file.writeAsString(jsonEncode({'languageCode': code}));
    } catch (_) {
      // Non-blocking fallback for tests/sandboxes
    }
  }
}
