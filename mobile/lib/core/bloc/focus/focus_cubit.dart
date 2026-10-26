import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';
import 'focus_state.dart';

export 'focus_state.dart';

class FocusSessionCubit extends Cubit<FocusSessionState> {
  final FocusSessionService _service;
  StreamSubscription? _completionSub;

  FocusSessionCubit({FocusSessionService? service})
      : _service = service ?? FocusSessionService(),
        super(FocusSessionState(
          remainingSeconds: (service ?? FocusSessionService()).remainingSeconds,
          totalSeconds: (service ?? FocusSessionService()).totalSeconds,
          isRunning: (service ?? FocusSessionService()).isRunning,
          isPaused: !(service ?? FocusSessionService()).isRunning &&
              (service ?? FocusSessionService()).remainingSeconds <
                  (service ?? FocusSessionService()).totalSeconds &&
              (service ?? FocusSessionService()).remainingSeconds > 0,
          isBreak: (service ?? FocusSessionService()).isBreak,
          attachedTask: (service ?? FocusSessionService()).attachedTask,
          selectedSoundscape:
              (service ?? FocusSessionService()).selectedSoundscape,
        )) {
    _service.remainingSecondsNotifier.addListener(_onServiceSync);
    _service.isRunningNotifier.addListener(_onServiceSync);
    _service.isBreakNotifier.addListener(_onServiceSync);
    _service.attachedTaskNotifier.addListener(_onServiceSync);
    _service.soundscapeNotifier.addListener(_onServiceSync);
    _service.configNotifier.addListener(_onServiceSync);

    _completionSub = _service.onSessionCompleted.listen((_) {
      _onServiceSync();
    });
  }

  void _onServiceSync() {
    final running = _service.isRunning;
    final remaining = _service.remainingSeconds;
    final total = _service.totalSeconds;
    final isPaused = !running && remaining < total && remaining > 0;

    emit(state.copyWith(
      remainingSeconds: remaining,
      totalSeconds: total,
      isRunning: running,
      isPaused: isPaused,
      isBreak: _service.isBreak,
      attachedTask: _service.attachedTask,
      clearAttachedTask: _service.attachedTask == null,
      selectedSoundscape: _service.selectedSoundscape,
      config: _service.config,
    ));
  }

  void toggleTimer() => _service.toggleTimer();
  void startTimer() => _service.startTimer();
  void pauseTimer() => _service.pauseTimer();
  void resetTimer({int? minutes, bool isBreak = false}) =>
      _service.resetTimer(minutes: minutes, isBreak: isBreak);
  void startBreak({int? minutes, bool autoStart = false}) =>
      _service.startBreak(minutes: minutes, autoStart: autoStart);
  void startFocus({int? minutes, bool autoStart = false}) =>
      _service.startFocus(minutes: minutes, autoStart: autoStart);
  void addSeconds(int seconds) => _service.addSeconds(seconds);
  void setAttachedTask(Task? task) => _service.setAttachedTask(task);
  void setSoundscape(String name) => _service.setSoundscape(name);
  void updateConfig(FocusSessionConfig config) => _service.updateConfig(config);

  @override
  Future<void> close() {
    _service.remainingSecondsNotifier.removeListener(_onServiceSync);
    _service.isRunningNotifier.removeListener(_onServiceSync);
    _service.isBreakNotifier.removeListener(_onServiceSync);
    _service.attachedTaskNotifier.removeListener(_onServiceSync);
    _service.soundscapeNotifier.removeListener(_onServiceSync);
    _service.configNotifier.removeListener(_onServiceSync);
    _completionSub?.cancel();
    return super.close();
  }
}
