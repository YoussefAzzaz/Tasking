import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:axis/core/storage/axis_storage.dart';

/// Immutable XP yield breakdown computed from a focus sprint's planned minutes.
class FocusYieldBreakdown {
  final int baseXp;
  final int boostXp;
  int get totalXp => baseXp + boostXp;

  const FocusYieldBreakdown({
    required this.baseXp,
    required this.boostXp,
  });

  /// Computes deterministic base + focus streak boost XP from [focusMinutes].
  /// Keeps a standard 25m sprint equal to +75 Base and +38 Boost (113 XP).
  factory FocusYieldBreakdown.fromMinutes(int focusMinutes) {
    final safeMinutes = focusMinutes.clamp(1, 240);
    final base = safeMinutes * 3;
    final boost = (base / 2).round();
    return FocusYieldBreakdown(baseXp: base, boostXp: boost);
  }
}

/// Resolved timer state computed from a persisted snapshot on startup.
class FocusRestoredState {
  final bool shouldRestore;
  final bool expiredWhileKilled;
  final bool isRunning;
  final bool isBreak;
  final bool isSessionActive;
  final int completedCycles;
  final int totalSeconds;
  final int remainingSeconds;
  final DateTime? targetEndTime;
  final String selectedSoundscape;

  const FocusRestoredState({
    required this.shouldRestore,
    required this.expiredWhileKilled,
    required this.isRunning,
    required this.isBreak,
    required this.isSessionActive,
    required this.completedCycles,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.targetEndTime,
    required this.selectedSoundscape,
  });
}

/// Serializable snapshot of an in-progress or paused focus session.
class FocusSessionSnapshot {
  final bool isRunning;
  final bool isBreak;
  final bool isSessionActive;
  final int completedCycles;
  final int totalSeconds;
  final int remainingSeconds;
  final DateTime? targetEndTimeUtc;
  final String selectedSoundscape;

  const FocusSessionSnapshot({
    required this.isRunning,
    required this.isBreak,
    required this.isSessionActive,
    required this.completedCycles,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.targetEndTimeUtc,
    required this.selectedSoundscape,
  });

  Map<String, dynamic> toJson() => {
        'isRunning': isRunning,
        'isBreak': isBreak,
        'isSessionActive': isSessionActive,
        'completedCycles': completedCycles,
        'totalSeconds': totalSeconds,
        'remainingSeconds': remainingSeconds,
        'targetEndTimeUtc': targetEndTimeUtc?.toUtc().toIso8601String(),
        'selectedSoundscape': selectedSoundscape,
      };

  static FocusSessionSnapshot? fromJson(Map<String, dynamic> json) {
    final total = (json['totalSeconds'] as num?)?.toInt();
    final remaining = (json['remainingSeconds'] as num?)?.toInt();
    if (total == null || total <= 0 || remaining == null || remaining < 0) {
      return null;
    }
    final rawEnd = json['targetEndTimeUtc'] as String?;
    return FocusSessionSnapshot(
      isRunning: json['isRunning'] == true,
      isBreak: json['isBreak'] == true,
      isSessionActive: json['isSessionActive'] == true,
      completedCycles: (json['completedCycles'] as num?)?.toInt() ?? 0,
      totalSeconds: total,
      remainingSeconds: remaining,
      targetEndTimeUtc:
          rawEnd != null ? DateTime.tryParse(rawEnd)?.toLocal() : null,
      selectedSoundscape:
          (json['selectedSoundscape'] as String?) ?? 'Gentle Rain',
    );
  }
}

/// Persists active focus countdown state to local storage so process kills do
/// not lose an ongoing focus or break session.
class FocusSessionPersistence {
  FocusSessionPersistence._();

  /// Resolves what state to restore at [now] without duplicating clock math in service code.
  static FocusRestoredState resolveSnapshot(
    FocusSessionSnapshot snapshot, {
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    if (!snapshot.isSessionActive) {
      return FocusRestoredState(
        shouldRestore: false,
        expiredWhileKilled: false,
        isRunning: false,
        isBreak: snapshot.isBreak,
        isSessionActive: false,
        completedCycles: snapshot.completedCycles,
        totalSeconds: snapshot.totalSeconds,
        remainingSeconds: snapshot.remainingSeconds,
        targetEndTime: null,
        selectedSoundscape: snapshot.selectedSoundscape,
      );
    }

    if (snapshot.isRunning && snapshot.targetEndTimeUtc != null) {
      final remaining = snapshot.targetEndTimeUtc!.difference(referenceNow).inSeconds;
      if (remaining <= 0) {
        return FocusRestoredState(
          shouldRestore: true,
          expiredWhileKilled: true,
          isRunning: false,
          isBreak: snapshot.isBreak,
          isSessionActive: true,
          completedCycles: snapshot.completedCycles,
          totalSeconds: snapshot.totalSeconds,
          remainingSeconds: 0,
          targetEndTime: null,
          selectedSoundscape: snapshot.selectedSoundscape,
        );
      }
      return FocusRestoredState(
        shouldRestore: true,
        expiredWhileKilled: false,
        isRunning: true,
        isBreak: snapshot.isBreak,
        isSessionActive: true,
        completedCycles: snapshot.completedCycles,
        totalSeconds: snapshot.totalSeconds,
        remainingSeconds: remaining,
        targetEndTime: snapshot.targetEndTimeUtc,
        selectedSoundscape: snapshot.selectedSoundscape,
      );
    }

    final clampedRemaining = snapshot.remainingSeconds.clamp(0, snapshot.totalSeconds);
    return FocusRestoredState(
      shouldRestore: clampedRemaining > 0,
      expiredWhileKilled: false,
      isRunning: false,
      isBreak: snapshot.isBreak,
      isSessionActive: clampedRemaining > 0,
      completedCycles: snapshot.completedCycles,
      totalSeconds: snapshot.totalSeconds,
      remainingSeconds: clampedRemaining,
      targetEndTime: null,
      selectedSoundscape: snapshot.selectedSoundscape,
    );
  }

  static Future<FocusSessionSnapshot?> load() async {
    try {
      final file = await AxisStorage.getFocusSessionStateFile();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return FocusSessionSnapshot.fromJson(decoded);
    } catch (e) {
      debugPrint('[FocusSessionPersistence] Load notice: $e');
      return null;
    }
  }

  static Future<void> save(FocusSessionSnapshot snapshot) async {
    try {
      final file = await AxisStorage.getFocusSessionStateFile();
      await file.writeAsString(jsonEncode(snapshot.toJson()));
    } catch (e) {
      debugPrint('[FocusSessionPersistence] Save notice: $e');
    }
  }

  static Future<void> clear() async {
    try {
      final file = await AxisStorage.getFocusSessionStateFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('[FocusSessionPersistence] Clear notice: $e');
    }
  }
}
