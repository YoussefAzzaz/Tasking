import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/focus_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/data/adhan_alarm_service.dart';
import 'package:axis/data/habit_repository.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';
import 'package:axis/core/router.dart';
import 'package:axis/data/habit_notification_service.dart';

import 'package:axis/data/powersync_db.dart' show isDatabaseInitialized;

class NotificationController {
  static ReceivePort? _receivePort;

  static void initializeIsolateReceivePort() {
    if (_receivePort != null) return;

    _receivePort = ReceivePort('notification_action_port');
    _receivePort!.listen((data) {
      if (data is Map) {
        final key = data['key'] as String? ?? '';
        final payload = (data['payload'] as Map?)?.cast<String, String?>();
        final channelKey = data['channelKey'] as String?;
        _handleAction(key, payload: payload, channelKey: channelKey);
      } else if (data is String) {
        _handleAction(data);
      }
    });

    IsolateNameServer.removePortNameMapping('notification_action_port');
    IsolateNameServer.registerPortWithName(
      _receivePort!.sendPort,
      'notification_action_port',
    );
  }

  static void _handleAction(String key, {Map<String, String?>? payload, String? channelKey}) {
    if (key == 'ACTION_PAUSE') {
      FocusSessionService().pauseTimer();
    } else if (key == 'ACTION_RESUME') {
      FocusSessionService().startTimer();
    } else if (key == 'ACTION_STOP') {
      FocusSessionService().resetTimer();
    } else if (key == 'DISMISS_FAJR_ALARM' || channelKey == 'fajr_alarm_channel') {
      AdhanAlarmService().handleFajrAlarmAction();
    } else if (key == 'MARK_DONE') {
      final prayerId = payload?['prayer_id'];
      if (prayerId != null) {
        HabitRepository().toggleHabit(prayerId, true);
      }
      final habitId = payload?['habit_id'];
      if (habitId != null) {
        HabitRepository().toggleHabit(habitId, true);
        HabitNotificationService().onHabitCompletedToday(habitId);
      }
    } else if (key == 'OPEN_HABITS' || channelKey == 'habit_reminder_channel') {
      try {
        router.go('/habits');
      } catch (_) {}
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    final key = receivedAction.buttonKeyPressed;
    final channelKey = receivedAction.channelKey;
    final payload = receivedAction.payload;

    final actionData = {
      'key': key,
      'channelKey': channelKey,
      'payload': payload,
    };

    final sendPort =
        IsolateNameServer.lookupPortByName('notification_action_port');
    if (sendPort != null) {
      sendPort.send(actionData);
    } else {
      // Running in headless background isolate without main thread port
      try {
        if (key == 'DISMISS_FAJR_ALARM' || channelKey == 'fajr_alarm_channel') {
          AdhanAlarmService().stopAlarmSound();
        } else if (key == 'MARK_DONE' && payload != null) {
          final targetId = payload['habit_id'] ?? payload['prayer_id'];
          if (targetId != null) {
            if (isDatabaseInitialized) {
              await HabitRepository().toggleHabit(targetId, true);
            } else {
              debugPrint('[NotificationController] Background isolate skipped direct DB write: DB not initialized in isolate');
            }
          }
        }
      } catch (e) {
        debugPrint('[NotificationController] Background isolate notification action error: $e');
      }
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {}

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    if (receivedNotification.channelKey == 'habit_reminder_channel') {
      final habitId = receivedNotification.payload?['habit_id'];
      if (habitId != null) {
        final isDone =
            await HabitNotificationService().isHabitCompletedToday(habitId);
        if (isDone && receivedNotification.id != null) {
          await AwesomeNotifications().dismiss(receivedNotification.id!);
        }
      }
    }
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {}
}

class FocusSessionService with WidgetsBindingObserver {
  static final FocusSessionService _instance = FocusSessionService._internal();
  factory FocusSessionService() => _instance;

  FocusSessionService._internal() {
    NotificationController.initializeIsolateReceivePort();
    _initNotifications();
    WidgetsBinding.instance.addObserver(this);
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

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  DateTime? _targetEndTime;
  DateTime? get targetEndTime => _targetEndTime;

  Timer? _ticker;
  bool _notificationsInitialized = false;

  final ValueNotifier<int> remainingSecondsNotifier =
      ValueNotifier<int>(25 * 60);
  final ValueNotifier<bool> isRunningNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Task?> attachedTaskNotifier = ValueNotifier<Task?>(null);
  final ValueNotifier<String> soundscapeNotifier =
      ValueNotifier<String>('Gentle Rain');
  final ValueNotifier<FocusSessionConfig> configNotifier =
      ValueNotifier<FocusSessionConfig>(const FocusSessionConfig());

  final StreamController<int> _completionStreamController =
      StreamController<int>.broadcast();
  Stream<int> get onSessionCompleted => _completionStreamController.stream;

  Future<void> init() async {
    NotificationController.initializeIsolateReceivePort();
    await _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (_notificationsInitialized) return;
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
      _totalSeconds = _config.focusMinutes * 60;
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
      _totalSeconds = _config.focusMinutes * 60;
      _remainingSeconds = _totalSeconds;
      remainingSecondsNotifier.value = _remainingSeconds;
    }

    _isRunning = true;
    isRunningNotifier.value = true;
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
    _showPinnedNotification(isPaused: true);
  }

  void addSeconds(int seconds) {
    _remainingSeconds += seconds;
    _totalSeconds += seconds;
    if (_isRunning && _targetEndTime != null) {
      _targetEndTime = _targetEndTime!.add(Duration(seconds: seconds));
    }
    remainingSecondsNotifier.value = _remainingSeconds;
    if (_isRunning) {
      _showPinnedNotification();
    }
  }

  void resetTimer({int? minutes}) {
    _isRunning = false;
    isRunningNotifier.value = false;
    _ticker?.cancel();
    _targetEndTime = null;
    _soundService.stop();
    _totalSeconds = (minutes ?? _config.focusMinutes) * 60;
    _remainingSeconds = _totalSeconds;
    remainingSecondsNotifier.value = _remainingSeconds;
    _cancelNotification();
  }

  /// Immediately terminates any active focus session, audio, notifications, and timer.
  void terminateSession() {
    _isRunning = false;
    isRunningNotifier.value = false;
    _ticker?.cancel();
    _targetEndTime = null;
    _soundService.stop();
    _attachedTask = null;
    attachedTaskNotifier.value = null;
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

    const xp = 113;
    await _focusRepo.logFocusSession(
      taskId: _attachedTask?.id,
      durationMin: _totalSeconds ~/ 60,
      xpEarned: xp,
    );

    _completionStreamController.add(xp);
    _showCompletedNotification(xp);
  }

  Future<void> _showPinnedNotification({bool isPaused = false}) async {
    if (!_notificationsInitialized) return;
    if (!_isRunning && !isPaused) return;

    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    final taskTitle = _attachedTask?.title ?? 'Deep Focus Cycle';
    final progress = _totalSeconds > 0
        ? ((_totalSeconds - _remainingSeconds) / _totalSeconds * 100)
            .clamp(0.0, 100.0)
        : 0.0;

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1001,
          channelKey: 'focus_session_channel',
          title: isPaused
              ? 'Focus Paused • $timeStr'
              : 'Deep Focus • $timeStr',
          body: isPaused
              ? '$taskTitle is paused'
              : '$taskTitle ($_selectedSoundscape)',
          notificationLayout: NotificationLayout.ProgressBar,
          progress: progress.toDouble(),
          category: NotificationCategory.Progress,
          color: isPaused ? const Color(0xFFF59E0B) : const Color(0xFF00E5FF),
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

  Future<void> _showCompletedNotification(int xp) async {
    if (!_notificationsInitialized) return;

    final taskTitle = _attachedTask?.title ?? 'Focus Session';

    try {
      await AwesomeNotifications().cancel(1001);
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: 1002,
          channelKey: 'focus_completed_channel',
          title: 'Focus Session Complete',
          body:
              'Optimal continuity achieved. You earned +$xp XP for $taskTitle.',
          category: NotificationCategory.Status,
          color: const Color(0xFF10B981),
          autoDismissible: true,
          locked: false,
        ),
      );
    } catch (e) {
      debugPrint('Failed to display completed focus notification: $e');
    }
  }

  Future<void> _cancelNotification() async {
    try {
      await AwesomeNotifications().cancel(1001);
    } catch (_) {}
  }
}
