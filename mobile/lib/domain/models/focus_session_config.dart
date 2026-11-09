/// Immutable configuration parameters for a quantum focus / Pomodoro wave.
class FocusSessionConfig {
  final int focusMinutes;
  final int shortBreakMinutes;
  final int longBreakMinutes;
  final int cyclesBeforeLongBreak;
  final bool autoStartBreaks;
  final bool soundscapeAutoPlay;

  const FocusSessionConfig({
    this.focusMinutes = 25,
    this.shortBreakMinutes = 5,
    this.longBreakMinutes = 15,
    this.cyclesBeforeLongBreak = 4,
    this.autoStartBreaks = true,
    this.soundscapeAutoPlay = true,
  });

  FocusSessionConfig copyWith({
    int? focusMinutes,
    int? shortBreakMinutes,
    int? longBreakMinutes,
    int? cyclesBeforeLongBreak,
    bool? autoStartBreaks,
    bool? soundscapeAutoPlay,
  }) {
    return FocusSessionConfig(
      focusMinutes: focusMinutes ?? this.focusMinutes,
      shortBreakMinutes: shortBreakMinutes ?? this.shortBreakMinutes,
      longBreakMinutes: longBreakMinutes ?? this.longBreakMinutes,
      cyclesBeforeLongBreak:
          cyclesBeforeLongBreak ?? this.cyclesBeforeLongBreak,
      autoStartBreaks: autoStartBreaks ?? this.autoStartBreaks,
      soundscapeAutoPlay: soundscapeAutoPlay ?? this.soundscapeAutoPlay,
    );
  }
}

