import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Centralized service managing reading font size preferences across viewing screens
/// (Notes, Journals, and Task descriptions) on mobile.
class ReadingPreferencesService {
  static final ReadingPreferencesService _instance =
      ReadingPreferencesService._internal();
  factory ReadingPreferencesService() => _instance;
  ReadingPreferencesService._internal();

  /// Discrete, comfortable font scale steps:
  /// 0.85 = 85% (Small)
  /// 1.00 = 100% (Default)
  /// 1.15 = 115% (Medium)
  /// 1.30 = 130% (Large)
  /// 1.50 = 150% (Extra Large)
  /// 1.70 = 170% (Huge)
  static const List<double> scaleSteps = [0.85, 1.0, 1.15, 1.30, 1.50, 1.70];
  static const double defaultScale = 1.0;

  final ValueNotifier<double> fontScaleNotifier =
      ValueNotifier<double>(defaultScale);

  double get currentScale => fontScaleNotifier.value;

  int get currentStepIndex {
    final current = currentScale;
    int closest = 1; // default index
    double minDiff = double.infinity;
    for (int i = 0; i < scaleSteps.length; i++) {
      final diff = (scaleSteps[i] - current).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closest = i;
      }
    }
    return closest;
  }

  bool get canDecrease => currentStepIndex > 0;
  bool get canIncrease => currentStepIndex < scaleSteps.length - 1;

  /// Increase reading font size to next step
  void increaseScale() {
    final idx = currentStepIndex;
    if (idx < scaleSteps.length - 1) {
      setScale(scaleSteps[idx + 1]);
    }
  }

  /// Decrease reading font size to previous step
  void decreaseScale() {
    final idx = currentStepIndex;
    if (idx > 0) {
      setScale(scaleSteps[idx - 1]);
    }
  }

  /// Reset reading font size to default (100%)
  void resetScale() {
    setScale(defaultScale);
  }

  /// Sets specific scale and asynchronously persists it
  void setScale(double newScale) {
    final clamped = newScale.clamp(scaleSteps.first, scaleSteps.last);
    if ((fontScaleNotifier.value - clamped).abs() > 0.001) {
      fontScaleNotifier.value = clamped;
      _persistScale(clamped);
    }
  }

  /// Formatted percentage string (e.g. "100%", "115%")
  String get formattedPercentage => '${(currentScale * 100).round()}%';

  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/reading_preferences.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        final saved = (map['fontScale'] as num?)?.toDouble();
        if (saved != null && saved >= scaleSteps.first && saved <= scaleSteps.last) {
          fontScaleNotifier.value = saved;
        }
      }
    } catch (_) {
      // In-memory fallback if storage is unavailable or in test environment
    }
  }

  Future<void> _persistScale(double scale) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/reading_preferences.json');
      await file.writeAsString(jsonEncode({'fontScale': scale}));
    } catch (_) {
      // Fallback for mock/test environments
    }
  }
}
