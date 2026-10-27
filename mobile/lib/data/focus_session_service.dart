import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/focus_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';
import 'package:axis/data/habit_notification_service.dart';

import 'package:axis/data/notification_controller.dart';
export 'package:axis/data/notification_controller.dart';


class FocusSessionService with WidgetsBindingObserver {
  static final FocusSessionService _instance = FocusSessionService._internal();
  factory FocusSessionService() => _instance;

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  FocusSessionService._internal() {
    try {
      if (isSupportedPlatform) {
        NotificationController.initializeIsolateReceivePort();
        _initNotifications();
      }
    } catch (_) {}
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}
  }

  final FocusRepository _focusRepo = FocusRepository();
  final NeuralSoundService _soundService = NeuralSoundService();

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
  bool _notificationsInitialized = false;

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
    await _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (!isSupportedPlatform || _notificationsInitialized) return;
    try {
      await AwesomeNotifications().initialize(
        null,
        [
          NotificationChannel(
            channelKey: 'focus_session_channel',
            channelName: 'Focus Session',
            channelDescription:
                'Active focus countdown with interactive pause/resume actions',
            defaultColor: const Color(0xFF00E5FF),
            importance: NotificationImportance.Low,
            channelShowBadge: false,
            onlyAlertOnce: true,
            playSound: false,
            enableVibration: false,
          ),
          NotificationChannel(
            channelKey: 'focus_completed_channel',
            channelName: 'Focus Completed',
            channelDescription: 'Focus session completion alerts and rewards',
            defaultColor: const Color(0xFF10B981),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
          NotificationChannel(
            channelKey: 'prayer_adhan_channel',
            channelName: 'Prayer Adhan & Times',
            channelDescription: 'Daily Islamic prayer notifications and Adhan reminder',
            defaultColor: const Color(0xFF38BDF8),
            importance: NotificationImportance.Max,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
            criticalAlerts: true,
          ),
          NotificationChannel(
            channelKey: 'fajr_alarm_channel',
            channelName: 'Fajr Wake-Up Alarm',
            channelDescription: 'High-priority cognitive Fajr wake-up verification alarm',
            defaultColor: const Color(0xFFEF4444),
            importance: NotificationImportance.Max,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
            criticalAlerts: true,
          ),
          NotificationChannel(
            channelKey: HabitNotificationService.channelKey,
            channelName: 'Habit Reminders',
            channelDescription:
                'Notifications for upcoming habits (10m and 5m before scheduled time)',
            defaultColor: const Color(0xFF10B981),
            importance: NotificationImportance.High,
            channelShowBadge: true,
            playSound: true,
            enableVibration: true,
          ),
        ],
        debug: false,
      );

      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: NotificationController.onActionReceivedMethod,
        onNotificationCreatedMethod:
            NotificationController.onNotificationCreatedMethod,
        onNotificationDisplayedMethod:
            NotificationController.onNotificationDisplayedMethod,
        onDismissActionReceivedMethod:
            NotificationController.onDismissActionReceivedMethod,
      );

      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      _notificationsInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize awesome notifications: $e');
    }
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
      _scheduleCompletionNotification(_targetEndTime!);
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
    _cancelScheduledCompletion();
    _showPinnedNotification(isPaused: true);
  }

  void addSeconds(int seconds) {
    _remainingSeconds += seconds;
    _totalSeconds += seconds;
    if (_isRunning && _targetEndTime != null) {
      _targetEndTime = _targetEndTime!.add(Duration(seconds: seconds));
      _scheduleCompletionNotification(_targetEndTime!);
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
    _cancelNotification();
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
    _cancelNotification();
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
      _showCompletedNotification(xp: xp, isBreak: false);

      try {
        await _focusRepo.logFocusSession(
          taskId: _attachedTask?.id,
          durationMin: _totalSeconds ~/ 60,
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
      _showCompletedNotification(xp: 0, isBreak: true);
    }
  }

  Future<void> _showPinnedNotification({bool isPaused = false}) async {
    if (!_notificationsInitialized) return;
    if (!_isRunning && !isPaused) return;

    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final taskTitle = _isBreak
        ? 'Reboot Break'
        : (_attachedTask?.title ?? 'Deep Focus Cycle');
    final progress = _totalSeconds > 0
        ? ((_totalSeconds - _remainingSeconds) / _totalSeconds * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    final String title = _isBreak
        ? (isPaused ? 'Break Paused • $timeStr' : 'Reboot Break • $timeStr')
        : (isPaused ? 'Focus Paused • $timeStr' : 'Deep Focus • $timeStr');

    final String body = _isBreak
        ? (isPaused
            ? 'Reboot break is paused'
            : 'Rest and recharge your cognitive buffer')
        : (isPaused
            ? '$taskTitle is paused'
            : '$taskTitle ($_selectedSoundscape)');

    final Color color = isPaused
        ? const Color(0xFFF59E0B)
        : (_isBreak ? const Color(0xFF10B981) : const Color(0xFF00E5FF));

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1001,
          channelKey: 'focus_session_channel',
          title: title,
          body: body,
          notificationLayout: NotificationLayout.ProgressBar,
          progress: progress.toDouble(),
          category: NotificationCategory.Progress,
          color: color,
          locked: true,
          autoDismissible: false,
        ),
        actionButtons: [
          if (isPaused)
            NotificationActionButton(
              key: 'ACTION_RESUME',
              label: 'Resume',
              actionType: ActionType.SilentBackgroundAction,
              autoDismissible: false,
            )
          else
            NotificationActionButton(
              key: 'ACTION_PAUSE',
              label: 'Pause',
              actionType: ActionType.SilentBackgroundAction,
              autoDismissible: false,
            ),
          NotificationActionButton(
            key: 'ACTION_STOP',
            label: 'Stop',
            actionType: ActionType.SilentBackgroundAction,
            autoDismissible: true,
          ),
        ],
      );
    } catch (e) {
      debugPrint('Failed to display awesome notification: $e');
    }
  }

  Future<void> _showCompletedNotification({
    required int xp,
    required bool isBreak,
  }) async {
    if (!_notificationsInitialized) return;

    final taskTitle = _attachedTask?.title ?? 'Focus Session';

    try {
      await AwesomeNotifications().cancel(1001);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1002,
          channelKey: 'focus_completed_channel',
          title: isBreak ? 'Reboot Break Complete' : 'Focus Session Complete',
          body: isBreak
              ? 'Break cycle finished. Energy restored. Ready for the next sprint!'
              : 'Optimal continuity achieved. You earned +$xp XP for $taskTitle.',
          category: NotificationCategory.Status,
          color: isBreak ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
          autoDismissible: true,
          locked: false,
        ),
      );
    } catch (e) {
      debugPrint('Failed to display completed focus notification: $e');
    }
  }

  Future<void> _scheduleCompletionNotification(DateTime endTime) async {
    if (!_notificationsInitialized) return;
    final taskTitle = _isBreak
        ? 'Reboot Break'
        : (_attachedTask?.title ?? 'Deep Focus Cycle');
    final title =
        _isBreak ? 'Reboot Break Complete' : 'Focus Session Complete';
    final body = _isBreak
        ? 'Break cycle finished. Energy restored. Return to launch focus!'
        : 'Optimal continuity achieved for $taskTitle. Return to claim your XP.';
    try {
      await AwesomeNotifications().cancel(1002);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1002,
          channelKey: 'focus_completed_channel',
          title: title,
          body: body,
          category: NotificationCategory.Alarm,
          color: _isBreak ? const Color(0xFF00E5FF) : const Color(0xFF10B981),
          wakeUpScreen: true,
          autoDismissible: true,
          locked: false,
        ),
        schedule: NotificationCalendar(
          year: endTime.year,
          month: endTime.month,
          day: endTime.day,
          hour: endTime.hour,
          minute: endTime.minute,
          second: endTime.second,
          millisecond: 0,
          repeats: false,
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
      );
    } catch (e) {
      debugPrint('[FocusSessionService] Error scheduling completion notification: $e');
    }
  }

  Future<void> _cancelScheduledCompletion() async {
    try {
      await AwesomeNotifications().cancel(1002);
    } catch (_) {}
  }

  Future<void> _cancelNotification() async {
    try {
      await AwesomeNotifications().cancel(1001);
      await AwesomeNotifications().cancel(1002);
    } catch (_) {}
  }
}
