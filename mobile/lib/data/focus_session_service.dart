import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/focus_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/domain/models/focus_session_config.dart';
import 'package:axis/data/notification_controller.dart';
import 'package:axis/data/focus/focus_notification_manager.dart';

export 'package:axis/data/notification_controller.dart';
export 'package:axis/domain/models/focus_session_config.dart';
export 'package:axis/data/focus/focus_notification_manager.dart';

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

  final ValueNotifier<int> remainingSecondsNotifier =
      ValueNotifier<int>(25 * 60);
  final ValueNotifier<bool> isRunningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isSessionActiveNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isBreakNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> completedCyclesNotifier = ValueNotifier<int>(0);
  final ValueNotifier<Task?> attachedTaskNotifier = ValueNotifier<Task?>(null);
  final ValueNotifier<String> soundscapeNotifier =
      ValueNotifier<String>('Gentle Rain');
  final ValueNotifier<FocusSessionConfig> configNotifier =
      ValueNotifier<FocusSessionConfig>(const FocusSessionConfig());

  final StreamController<int> _completionStreamController =
      StreamController<int>.broadcast();
  Stream<int> get onSessionCompleted => _completionStreamController.stream;

  Future<void> init() async {
    if (!isSupportedPlatform) return;
    NotificationController.initializeIsolateReceivePort();
    await _notificationManager.initNotifications();
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

  void startTimer() {
    if (_remainingSeconds <= 0) {
      _totalSeconds =
          (_isBreak ? _config.shortBreakMinutes : _config.focusMinutes) * 60;
      _remainingSeconds = _totalSeconds;
      remainingSecondsNotifier.value = _remainingSeconds;
    }

    _isRunning = true;
    isRunningNotifier.value = true;
    _isSessionActive = true;
    isSessionActiveNotifier.value = true;
    _targetEndTime = DateTime.now().add(Duration(seconds: _remainingSeconds));

    if (_config.soundscapeAutoPlay) {
      _soundService.play(_selectedSoundscape);
    }

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      _tick();
    });

    // Update notification immediately on start
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
      } else {
        _remainingSeconds = diff;
        remainingSecondsNotifier.value = _remainingSeconds;
      }
    } else {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        remainingSecondsNotifier.value = _remainingSeconds;
      } else {
        _ticker?.cancel();
        _onComplete();
        return;
      }
    }

    // Throttle notification updates to prevent battery drain and IPC saturation.
    // Full countdown is still updated every second in-app via remainingSecondsNotifier.
    if (_remainingSeconds % 30 == 0 || _remainingSeconds <= 10) {
      _showPinnedNotification();
    }
  }

  void pauseTimer() {
    _isRunning = false;
    isRunningNotifier.value = false;
    _ticker?.cancel();
    _targetEndTime = null;
    _soundService.stop();
    _notificationManager.cancelScheduledCompletion();
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
    if (_isRunning) {
      _showPinnedNotification();
    }
  }

  void resetTimer({int? minutes, bool isBreak = false}) {
    _isRunning = false;
    isRunningNotifier.value = false;
    _isSessionActive = false;
    isSessionActiveNotifier.value = false;
    _ticker?.cancel();
    _targetEndTime = null;
    _soundService.stop();
    _isBreak = isBreak;
    isBreakNotifier.value = isBreak;
    _totalSeconds =
        (minutes ?? (_isBreak ? _config.shortBreakMinutes : _config.focusMinutes)) *
            60;
    _remainingSeconds = _totalSeconds;
    remainingSecondsNotifier.value = _remainingSeconds;
    _notificationManager.cancelNotification();
  }

  /// Sets up and starts or prepares a reboot break cycle.
  void startBreak({int? minutes, bool? isLong, bool autoStart = false}) {
    final bool useLong = isLong ??
        (_config.cyclesBeforeLongBreak > 0 &&
            _completedCycles > 0 &&
            (_completedCycles % _config.cyclesBeforeLongBreak == 0));
    final breakMin = minutes ??
        (useLong ? _config.longBreakMinutes : _config.shortBreakMinutes);
    resetTimer(minutes: breakMin, isBreak: true);
    if (autoStart) {
      startTimer();
    }
  }

  /// Sets up and starts or prepares a normal deep focus cycle.
  void startFocus({int? minutes, bool autoStart = false}) {
    resetTimer(minutes: minutes ?? _config.focusMinutes, isBreak: false);
    if (autoStart) {
      startTimer();
    }
  }

  /// Explicitly completes the current session cycle (for testing or manual completion triggers).
  Future<void> completeSession() => _onComplete();

  /// Immediately terminates any active focus session, audio, notifications, and timer.
  void terminateSession() {
    _isRunning = false;
    isRunningNotifier.value = false;
    _isSessionActive = false;
    isSessionActiveNotifier.value = false;
    _ticker?.cancel();
    _targetEndTime = null;
    _soundService.stop();
    _attachedTask = null;
    attachedTaskNotifier.value = null;
    _isBreak = false;
    isBreakNotifier.value = false;
    _completedCycles = 0;
    completedCyclesNotifier.value = 0;
    _totalSeconds = _config.focusMinutes * 60;
    _remainingSeconds = _totalSeconds;
    remainingSecondsNotifier.value = _remainingSeconds;
    _notificationManager.cancelNotification();
  }

  Future<void> _onComplete() async {
    _isRunning = false;
    isRunningNotifier.value = false;
    _targetEndTime = null;
    _soundService.stop();

    final bool wasBreak = _isBreak;

    if (!wasBreak) {
      _completedCycles++;
      completedCyclesNotifier.value = _completedCycles;

      final completedFocusMin = _totalSeconds ~/ 60;
      const xp = 113;

      // Determine next break duration
      final bool nextIsLongBreak = _config.cyclesBeforeLongBreak > 0 &&
          (_completedCycles % _config.cyclesBeforeLongBreak == 0);
      final breakMin = nextIsLongBreak
          ? _config.longBreakMinutes
          : _config.shortBreakMinutes;

      // Stage break session
      _isBreak = true;
      isBreakNotifier.value = true;
      _totalSeconds = breakMin * 60;
      _remainingSeconds = _totalSeconds;
      remainingSecondsNotifier.value = _remainingSeconds;

      // Broadcast XP earned to listeners (positive value indicates focus session completed)
      _completionStreamController.add(xp);
      _notificationManager.showCompletedNotification(
        xp: xp,
        isBreak: false,
        attachedTask: _attachedTask,
      );

      try {
        await _focusRepo.logFocusSession(
          taskId: _attachedTask?.id,
          durationMin:
              completedFocusMin > 0 ? completedFocusMin : _config.focusMinutes,
          xpEarned: xp,
        );
      } catch (e) {
        debugPrint('[FocusSessionService] Error logging session: $e');
      }

      if (_config.autoStartBreaks) {
        startTimer();
      }
    } else {
      // Break cycle completed — stage next normal deep focus session
      _isBreak = false;
      isBreakNotifier.value = false;
      _totalSeconds = _config.focusMinutes * 60;
      _remainingSeconds = _totalSeconds;
      remainingSecondsNotifier.value = _remainingSeconds;

      // Broadcast -1 to indicate break completed (no XP)
      _completionStreamController.add(-1);
      _notificationManager.showCompletedNotification(
        xp: 0,
        isBreak: true,
        attachedTask: _attachedTask,
      );
    }
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
