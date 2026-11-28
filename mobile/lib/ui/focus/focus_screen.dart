import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';
import 'package:axis/ui/focus/widgets/neon_timer_dial.dart';
import 'package:axis/ui/focus/widgets/soundscape_selector_grid.dart';
import 'package:axis/ui/focus/widgets/attach_task_sheet.dart';
import 'package:axis/ui/focus/widgets/focus_task_description_sheet.dart';
import 'package:axis/ui/focus/widgets/focus_completion_dialog.dart';
import 'package:axis/ui/focus/widgets/zen_fullscreen_view.dart';
import 'package:axis/ui/focus/widgets/focus_dashboard_widgets.dart';

export 'package:axis/ui/focus/widgets/neon_timer_dial.dart';
export 'package:axis/ui/focus/widgets/soundscape_selector_grid.dart';
export 'package:axis/ui/focus/widgets/attach_task_sheet.dart';
export 'package:axis/ui/focus/widgets/focus_task_description_sheet.dart';
export 'package:axis/ui/focus/widgets/focus_completion_dialog.dart';
export 'package:axis/ui/focus/widgets/zen_fullscreen_view.dart';
export 'package:axis/ui/focus/widgets/focus_dashboard_widgets.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.initialTask});
  final Task? initialTask;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen>
    with SingleTickerProviderStateMixin {
  final _sessionService = FocusSessionService();
  final _taskRepo = TaskRepository();
  final _soundService = NeuralSoundService();
  StreamSubscription<int>? _completionSubscription;

  bool? _zenModeOverride;
  bool get _isZenMode => _zenModeOverride ?? _isRunning;

  FocusSessionConfig get _config => _sessionService.config;
  int get _totalSeconds => _sessionService.totalSeconds;
  bool get _isRunning => _sessionService.isRunning;
  Task? get _attachedTask => _sessionService.attachedTask;
  String get _selectedSoundscape => _sessionService.selectedSoundscape;

  static const _soundscapes = kRelaxingSoundscapes;

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null && _sessionService.attachedTask == null) {
      _sessionService.setAttachedTask(widget.initialTask);
    }
    _sessionService.isRunningNotifier.addListener(_onServiceUpdate);
    _sessionService.isBreakNotifier.addListener(_onServiceUpdate);
    _completionSubscription = _sessionService.onSessionCompleted.listen((xp) {
      if (mounted) {
        _showCompletionDialog(xp);
      }
    });
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _sessionService.isRunningNotifier.removeListener(_onServiceUpdate);
    _sessionService.isBreakNotifier.removeListener(_onServiceUpdate);
    _completionSubscription?.cancel();
    super.dispose();
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => FocusSettingsSheet(
        initialConfig: _config,
        onConfigSaved: (newConfig) {
          _sessionService.updateConfig(newConfig);
          setState(() {});
        },
      ),
    );
  }

  void _toggleTimer() {
    _sessionService.toggleTimer();
    // When timer starts running, automatically enter Zen Fullscreen mode
    if (_sessionService.isRunning) {
      _zenModeOverride = null;
    }
    setState(() {});
  }

  void _addFiveMinutes() {
    _sessionService.addSeconds(5 * 60);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.isArabic
              ? '+5 دقائق أُضيفت إلى جلسة التركيز'
              : '+5 Minutes Added to Focus Session',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AxisColors.surfaceHigh,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {});
  }

  void _resetTimer({int? minutes, bool autoStart = false}) {
    _sessionService.startFocus(minutes: minutes, autoStart: autoStart);
    if (autoStart) {
      _zenModeOverride = null;
    }
    setState(() {});
  }

  void _setBreak({int? minutes, bool autoStart = false}) {
    _sessionService.startBreak(minutes: minutes, autoStart: autoStart);
    if (autoStart) {
      _zenModeOverride = null;
    }
    setState(() {});
  }

  void _showCompletionDialog(int xp) {
    FocusCompletionDialog.show(
      context: context,
      xp: xp,
      onLaunchFocus: () => _resetTimer(autoStart: true),
      onTakeBreak: () => _setBreak(autoStart: true),
    );
  }

  void _pickTask() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AttachTaskSheet(
        taskRepo: _taskRepo,
        onSelectTask: (t) {
          _sessionService.setAttachedTask(t);
          setState(() {});
        },
      ),
    );
  }

  void _openSoundscapeModal() {
    SoundscapeSelectorGrid.showSoundscapeSheet(
      context: context,
      selectedSoundscape: _selectedSoundscape,
      soundService: _soundService,
      onSelectSoundscape: (soundscape) {
        _sessionService.setSoundscape(soundscape);
        setState(() {});
      },
    );
  }

  void _showTaskDescription(Task task) {
    FocusTaskDescriptionSheet.show(
      context: context,
      task: task,
      onTaskUpdated: (updatedTask) {
        if (_attachedTask?.id == updatedTask.id) {
          _sessionService.setAttachedTask(updatedTask);
          setState(() {});
        }
      },
      onSwitchTask: _pickTask,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: <Widget>[
              ...previousChildren.map((child) => ExcludeSemantics(child: child)),
              ?currentChild,
            ],
          );
        },
        child: _isZenMode
            ? ZenFullscreenView(
                isRunning: _isRunning,
                isBreak: _sessionService.isBreak,
                totalSeconds: _totalSeconds,
                attachedTask: _attachedTask,
                selectedSoundscape: _selectedSoundscape,
                soundService: _soundService,
                sessionService: _sessionService,
                onMinimize: () {
                  if (_isRunning) {
                    setState(() => _zenModeOverride = false);
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
                onOpenSetup: () => setState(() => _zenModeOverride = false),
                onTaskTap: () {
                  if (_attachedTask != null) {
                    _showTaskDescription(_attachedTask!);
                  } else {
                    _pickTask();
                  }
                },
                onToggleTimer: _toggleTimer,
                onAddFiveMinutes: _addFiveMinutes,
                onToggleBreak: () {
                  if (_sessionService.isBreak) {
                    _resetTimer();
                  } else {
                    _setBreak();
                  }
                },
                onOpenSoundscapeModal: _openSoundscapeModal,
              )
            : _buildSetupView(context),
      ),
    );
  }

  /// Setup View: Full session dashboard with target picker, settings, yield stats, and sound rack
  Widget _buildSetupView(BuildContext context) {
    return NestedScrollView(
      key: const ValueKey('setup_view'),
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AxisColors.canvasBase,
          elevation: 0,
          leading: IconButton(
            // Root cause: arrow_back_rounded auto-mirrors in RTL; ternary caused double-flip.
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AxisColors.textHigh,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AxisColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  context.isArabic ? 'عمل عميق' : 'DEEP WORK',
                  style: const TextStyle(
                    color: AxisColors.primarySoft,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: AxisColors.textHigh),
              tooltip: context.isArabic ? 'إعدادات الجلسة' : 'Session Settings',
              onPressed: _openSettings,
            ),
          ],
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Target Task Capsule
            FocusTargetCapsule(
              attachedTask: _attachedTask,
              onTap: () {
                if (_attachedTask != null) {
                  _showTaskDescription(_attachedTask!);
                } else {
                  _pickTask();
                }
              },
              onPickTask: _pickTask,
            ),
            const SizedBox(height: 28),

            // Neon Radial Glow Timer Dial
            InkWell(
              onTap: _isRunning ? () => setState(() => _zenModeOverride = true) : null,
              borderRadius: BorderRadius.circular(150),
              child: ValueListenableBuilder<int>(
                valueListenable: _sessionService.remainingSecondsNotifier,
                builder: (context, remainingSec, _) {
                  final progress = _totalSeconds > 0
                      ? (_totalSeconds - remainingSec) / _totalSeconds
                      : 0.0;
                  final minutes = remainingSec ~/ 60;
                  final seconds = remainingSec % 60;
                  final timeDisplay =
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                  return NeonTimerDial(
                    size: 250,
                    progress: progress,
                    timeDisplay: timeDisplay,
                    isBreak: _sessionService.isBreak,
                    isRunning: _isRunning,
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Yield Prediction Live Strip
            const FocusYieldStrip(),
            const SizedBox(height: 24),

            // Primary Engagement Action / Return to Fullscreen
            ValueListenableBuilder<int>(
              valueListenable: _sessionService.remainingSecondsNotifier,
              builder: (context, remainingSec, _) {
                final minutes = remainingSec ~/ 60;
                final seconds = remainingSec % 60;
                final timeDisplay =
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                return FocusActionButtons(
                  isRunning: _isRunning,
                  isBreak: _sessionService.isBreak,
                  config: _config,
                  timeDisplay: timeDisplay,
                  onReturnToFullscreen: () => setState(() => _zenModeOverride = true),
                  onToggleTimer: _toggleTimer,
                  onResetTimer: () => _sessionService.isBreak ? _setBreak() : _resetTimer(),
                  onToggleBreak: () => _sessionService.isBreak ? _resetTimer() : _setBreak(),
                );
              },
            ),
            const SizedBox(height: 28),

            // Neural Soundscapes Rack
            SoundscapeSelectorGrid(
              soundscapes: _soundscapes,
              selectedSoundscape: _selectedSoundscape,
              soundService: _soundService,
              onSelectSoundscape: (soundscape) {
                _sessionService.setSoundscape(soundscape);
                setState(() {});
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
