import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/focus_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/domain/models/focus_session_config.dart';
import 'package:axis/data/notification_controller.dart';
import 'package:axis/data/focus/focus_notification_manager.dart';
import 'package:axis/data/focus/focus_session_persistence.dart';

export 'package:axis/data/notification_controller.dart';
export 'package:axis/domain/models/focus_session_config.dart';
export 'package:axis/data/focus/focus_notification_manager.dart';
export 'package:axis/data/focus/focus_session_persistence.dart' show FocusYieldBreakdown;

class FocusSessionService with WidgetsBindingObserver {
  static final FocusSessionService _instance = FocusSessionService._internal();
  factory FocusSessionService() => _instance;

  static bool get isSupportedPlatform =>
      FocusNotificationManager.isSupportedPlatform;

  FocusSessionService._internal() {
    try {
      if (isSupportedPlatform) {
        NotificationController.initializeIsolateReceivePort();
        _notificationManager.initNotifications();
      }
    } catch (_) {}
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  final FocusRepository _focusRepo = FocusRepository();
  final NeuralSoundService _soundService = NeuralSoundService();
  final FocusNotificationManager _notificationManager =
      FocusNotificationManager();

  FocusSessionConfig _config = const FocusSessionConfig();
  FocusSessionConfig get config => _config;
  Task? _attachedTask;
  Task? get attachedTask => _attachedTask;
  String _selectedSoundscape = 'Gentle Rain';
  String get selectedSoundscape => _selectedSoundscape;
  int _totalSeconds = 25 * 60;
  int get totalSeconds => _totalSeconds;
  int _remainingSeconds = 25 * 60;
  int get remainingSeconds => _remainingSeconds;
  bool _isBreak = false;
  bool get isBreak => _isBreak;
  int _completedCycles = 0;
  int get completedCycles => _completedCycles;
  bool _isRunning = false;
  bool get isRunning => _isRunning;
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;
  DateTime? _targetEndTime;
  DateTime? get targetEndTime => _targetEndTime;

  Timer? _ticker;

  final remainingSecondsNotifier = ValueNotifier<int>(25 * 60);
  final isRunningNotifier = ValueNotifier<bool>(false);
  final isSessionActiveNotifier = ValueNotifier<bool>(false);
  final isBreakNotifier = ValueNotifier<bool>(false);
  final completedCyclesNotifier = ValueNotifier<int>(0);
  final attachedTaskNotifier = ValueNotifier<Task?>(null);
  final soundscapeNotifier = ValueNotifier<String>('Gentle Rain');
  final configNotifier = ValueNotifier<FocusSessionConfig>(const FocusSessionConfig());

  final _completionStreamController = StreamController<int>.broadcast();
  Stream<int> get onSessionCompleted => _completionStreamController.stream;

  void _applyRestoredValues(FocusRestoredState resolved) {
    _isBreak = resolved.isBreak;
    isBreakNotifier.value = _isBreak;
    _completedCycles = resolved.completedCycles;
    completedCyclesNotifier.value = _completedCycles;
    _totalSeconds = resolved.totalSeconds;
    _selectedSoundscape = resolved.selectedSoundscape;
    soundscapeNotifier.value = _selectedSoundscape;
    _remainingSeconds = resolved.remainingSeconds;
    remainingSecondsNotifier.value = _remainingSeconds;
    _isSessionActive = resolved.isSessionActive;
    isSessionActiveNotifier.value = _isSessionActive;
    _isRunning = resolved.isRunning;
    isRunningNotifier.value = _isRunning;
    _targetEndTime = resolved.targetEndTime;
  }

  Future<void> init() async {
    await restorePersistedState();
    if (!isSupportedPlatform) return;
    NotificationController.initializeIsolateReceivePort();
    await _notificationManager.initNotifications();
  }

  /// Restores active/paused countdown state persisted before an OS process kill.
  @visibleForTesting
  Future<void> restorePersistedState() async {
    final snapshot = await FocusSessionPersistence.load();
    if (snapshot == null) return;
    final resolved = FocusSessionPersistence.resolveSnapshot(snapshot);
    if (!resolved.shouldRestore) return;
    _applyRestoredValues(resolved);
    if (resolved.expiredWhileKilled) {
      await _onComplete();
    } else if (_isRunning) {
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    }
  }

  void _persistSnapshot() {
    if (!_isSessionActive) {
      unawaited(FocusSessionPersistence.clear());
      return;
    }
    unawaited(FocusSessionPersistence.save(FocusSessionSnapshot(
      isRunning: _isRunning,
      isBreak: _isBreak,
      isSessionActive: _isSessionActive,
      completedCycles: _completedCycles,
      totalSeconds: _totalSeconds,
      remainingSeconds: _remainingSeconds,
      targetEndTimeUtc: _targetEndTime,
      selectedSoundscape: _selectedSoundscape,
    )));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncClock();
      if (_isRunning) {
        _showPinnedNotification();
      }
    }
  }

  void _syncClock() {
    if (_isRunning && _targetEndTime != null) {
      final diff = _targetEndTime!.difference(DateTime.now()).inSeconds;
      if (diff <= 0) {
        _remainingSeconds = 0;
        remainingSecondsNotifier.value = 0;
        _onComplete();
      } else {
        _remainingSeconds = diff;
        remainingSecondsNotifier.value = _remainingSeconds;
      }
    }
  }

  void updateConfig(FocusSessionConfig newConfig) {
    _config = newConfig;
    configNotifier.value = newConfig;
    if (!_isRunning) {
      _totalSeconds =
          (_isBreak ? _config.shortBreakMinutes : _config.focusMinutes) * 60;
      _remainingSeconds = _totalSeconds;
      remainingSecondsNotifier.value = _remainingSeconds;
    }
  }

  void setAttachedTask(Task? task) {
    _attachedTask = task;
    attachedTaskNotifier.value = task;
    if (_isRunning) {
      _showPinnedNotification();
    }
  }

  void setSoundscape(String soundscape) {
    _selectedSoundscape = soundscape;
    soundscapeNotifier.value = soundscape;
    if (_isRunning) {
      _soundService.play(soundscape);
      _showPinnedNotification();
    }
  }

  void toggleTimer() {
    if (_isRunning) {
      pauseTimer();
    } else {
      startTimer();
    }
  }

  void _haltRunningTicker() {
    _isRunning = false;
    isRunningNotifier.value = false;
    _ticker?.cancel();
    _ticker = null;
    _targetEndTime = null;
    _soundService.stop();
  }

  void _stageSeconds(int seconds) {
    _totalSeconds = seconds;
    _remainingSeconds = seconds;
    remainingSecondsNotifier.value = seconds;
  }

  void startTimer() {
    if (_remainingSeconds <= 0) {
      _stageSeconds((_isBreak ? _config.shortBreakMinutes : _config.focusMinutes) * 60);
    }

    _isRunning = true;
    isRunningNotifier.value = true;
    _isSessionActive = true;
    isSessionActiveNotifier.value = true;
    _targetEndTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    if (_config.soundscapeAutoPlay) _soundService.play(_selectedSoundscape);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    _persistSnapshot();
    _showPinnedNotification();
    if (_targetEndTime != null) {
      _notificationManager.scheduleCompletionNotification(
        endTime: _targetEndTime!,
        isBreak: _isBreak,
        attachedTask: _attachedTask,
      );
    }
  }

  void _tick() {
    if (!_isRunning) return;

    if (_targetEndTime != null) {
      final diff = _targetEndTime!.difference(DateTime.now()).inSeconds;
      if (diff <= 0) {
        _remainingSeconds = 0;
        remainingSecondsNotifier.value = 0;
        _ticker?.cancel();
        _onComplete();
        return;
      }
      _remainingSeconds = diff;
      remainingSecondsNotifier.value = diff;
    } else if (_remainingSeconds > 0) {
      _remainingSeconds--;
      remainingSecondsNotifier.value = _remainingSeconds;
    } else {
      _ticker?.cancel();
      _onComplete();
      return;
    }

    if (_remainingSeconds % 30 == 0 || _remainingSeconds <= 10) _showPinnedNotification();
  }

  void pauseTimer() {
    _haltRunningTicker();
    _notificationManager.cancelScheduledCompletion();
    _persistSnapshot();
    _showPinnedNotification(isPaused: true);
  }

  void addSeconds(int seconds) {
    _remainingSeconds += seconds;
    _totalSeconds += seconds;
    if (_isRunning && _targetEndTime != null) {
      _targetEndTime = _targetEndTime!.add(Duration(seconds: seconds));
      _notificationManager.scheduleCompletionNotification(
        endTime: _targetEndTime!,
        isBreak: _isBreak,
        attachedTask: _attachedTask,
      );
    }
    remainingSecondsNotifier.value = _remainingSeconds;
    _persistSnapshot();
    if (_isRunning) _showPinnedNotification();
  }

  void resetTimer({int? minutes, bool isBreak = false}) {
    _haltRunningTicker();
    _isSessionActive = false;
    isSessionActiveNotifier.value = false;
    _isBreak = isBreak;
    isBreakNotifier.value = isBreak;
    _stageSeconds((minutes ?? (_isBreak ? _config.shortBreakMinutes : _config.focusMinutes)) * 60);
    _persistSnapshot();
    _notificationManager.cancelNotification();
  }

  /// Sets up and starts or prepares a reboot break cycle.
  void startBreak({int? minutes, bool? isLong, bool autoStart = false}) {
    final bool useLong = isLong ??
        (_config.cyclesBeforeLongBreak > 0 &&
            _completedCycles > 0 &&
            (_completedCycles % _config.cyclesBeforeLongBreak == 0));
    final breakMin = minutes ?? (useLong ? _config.longBreakMinutes : _config.shortBreakMinutes);
    resetTimer(minutes: breakMin, isBreak: true);
    if (autoStart) startTimer();
  }

  /// Sets up and starts or prepares a normal deep focus cycle.
  void startFocus({int? minutes, bool autoStart = false}) {
    resetTimer(minutes: minutes ?? _config.focusMinutes, isBreak: false);
    if (autoStart) startTimer();
  }

  /// Explicitly completes the current session cycle (for testing or manual completion triggers).
  Future<void> completeSession() => _onComplete();

  /// Immediately terminates any active focus session, audio, notifications, and timer.
  void terminateSession() {
    _haltRunningTicker();
    _isSessionActive = false;
    isSessionActiveNotifier.value = false;
    _attachedTask = null;
    attachedTaskNotifier.value = null;
    _isBreak = false;
    isBreakNotifier.value = false;
    _completedCycles = 0;
    completedCyclesNotifier.value = 0;
    _stageSeconds(_config.focusMinutes * 60);
    _persistSnapshot();
    _notificationManager.cancelNotification();
  }

  Future<void> _onComplete() async {
    _haltRunningTicker();
    final bool wasBreak = _isBreak;

    if (!wasBreak) {
      _completedCycles++;
      completedCyclesNotifier.value = _completedCycles;

      final completedFocusMin = _totalSeconds ~/ 60;
      final xp = FocusYieldBreakdown.fromMinutes(
        completedFocusMin > 0 ? completedFocusMin : _config.focusMinutes,
      ).totalXp;

      final bool nextIsLongBreak = _config.cyclesBeforeLongBreak > 0 &&
          (_completedCycles % _config.cyclesBeforeLongBreak == 0);
      final breakMin = nextIsLongBreak ? _config.longBreakMinutes : _config.shortBreakMinutes;

      _isBreak = true;
      isBreakNotifier.value = true;
      _stageSeconds(breakMin * 60);
      _persistSnapshot();

      _completionStreamController.add(xp);
      _notificationManager.showCompletedNotification(xp: xp, isBreak: false, attachedTask: _attachedTask);

      try {
        await _focusRepo.logFocusSession(
          taskId: _attachedTask?.id,
          durationMin: completedFocusMin > 0 ? completedFocusMin : _config.focusMinutes,
          xpEarned: xp,
        );
      } catch (e) {
        debugPrint('[FocusSessionService] Error logging session: $e');
      }

      if (_config.autoStartBreaks) startTimer();
    } else {
      _isBreak = false;
      isBreakNotifier.value = false;
      _stageSeconds(_config.focusMinutes * 60);
      _persistSnapshot();

      _completionStreamController.add(-1);
      _notificationManager.showCompletedNotification(xp: 0, isBreak: true, attachedTask: _attachedTask);
    }
  }

  /// Stops active tickers and sound playback without closing singleton broadcast notifiers.
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _soundService.stop();
  }

  Future<void> _showPinnedNotification({bool isPaused = false}) async {
    await _notificationManager.showPinnedNotification(
      remainingSeconds: _remainingSeconds,
      totalSeconds: _totalSeconds,
      isBreak: _isBreak,
      isRunning: _isRunning,
      isPaused: isPaused,
      attachedTask: _attachedTask,
      selectedSoundscape: _selectedSoundscape,
    );
  }
}
