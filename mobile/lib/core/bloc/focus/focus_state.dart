import 'package:equatable/equatable.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';

class FocusSessionState extends Equatable {
  final int remainingSeconds;
  final int totalSeconds;
  final bool isRunning;
  final bool isPaused;
  final bool isBreak;
  final Task? attachedTask;
  final String selectedSoundscape;
  final FocusSessionConfig config;

  const FocusSessionState({
    this.remainingSeconds = 25 * 60,
    this.totalSeconds = 25 * 60,
    this.isRunning = false,
    this.isPaused = false,
    this.isBreak = false,
    this.attachedTask,
    this.selectedSoundscape = 'Gentle Rain',
    this.config = const FocusSessionConfig(),
  });

  double get progress => totalSeconds > 0
      ? ((totalSeconds - remainingSeconds) / totalSeconds).clamp(0.0, 1.0)
      : 0.0;

  String get timeFormatted {
    final clamped = remainingSeconds < 0 ? 0 : remainingSeconds;
    final mins = clamped ~/ 60;
    final secs = clamped % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  FocusSessionState copyWith({
    int? remainingSeconds,
    int? totalSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? isBreak,
    Task? attachedTask,
    bool clearAttachedTask = false,
    String? selectedSoundscape,
    FocusSessionConfig? config,
  }) {
    return FocusSessionState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isBreak: isBreak ?? this.isBreak,
      attachedTask:
          clearAttachedTask ? null : (attachedTask ?? this.attachedTask),
      selectedSoundscape: selectedSoundscape ?? this.selectedSoundscape,
      config: config ?? this.config,
    );
  }

  @override
  List<Object?> get props => [
        remainingSeconds,
        totalSeconds,
        isRunning,
        isPaused,
        isBreak,
        attachedTask,
        selectedSoundscape,
        config,
      ];
}
