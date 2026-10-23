import 'dart:async';
import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';
import 'package:axis/ui/focus/widgets/neon_timer_dial.dart';
import 'package:axis/ui/focus/widgets/soundscape_selector_grid.dart';
import 'package:axis/ui/focus/widgets/attach_task_sheet.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/reading_font_size_control.dart';
import 'package:axis/data/reading_preferences_service.dart';

export 'package:axis/ui/focus/widgets/neon_timer_dial.dart';
export 'package:axis/ui/focus/widgets/soundscape_selector_grid.dart';
export 'package:axis/ui/focus/widgets/attach_task_sheet.dart';

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
  int get _remainingSeconds => _sessionService.remainingSeconds;
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
    _sessionService.remainingSecondsNotifier.addListener(_onServiceUpdate);
    _sessionService.isRunningNotifier.addListener(_onServiceUpdate);
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
    _sessionService.remainingSecondsNotifier.removeListener(_onServiceUpdate);
    _sessionService.isRunningNotifier.removeListener(_onServiceUpdate);
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
        content: const Text(
          '+5 Minutes Added to Focus Session',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AxisColors.surfaceHigh,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() {});
  }

  void _resetTimer({int? minutes}) {
    _sessionService.resetTimer(minutes: minutes);
    setState(() {});
  }

  void _setBreak() {
    _sessionService.resetTimer(minutes: _config.shortBreakMinutes);
    setState(() {});
  }

  void _showCompletionDialog(int xp) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AxisColors.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: AxisColors.tertiary, size: 28),
            SizedBox(width: 8),
            Text(
              'Deep Session Complete!',
              style: TextStyle(color: AxisColors.textHigh, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quantum focus cycle finished with optimal continuity.',
              style: TextStyle(color: AxisColors.textMuted),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AxisColors.tertiary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AxisColors.tertiary.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AxisColors.tertiary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '+$xp XP Added to Cockpit',
                    style: const TextStyle(
                      color: AxisColors.tertiary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss',
                style: TextStyle(color: AxisColors.secondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AxisColors.tertiary,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _setBreak();
            },
            child: const Text('Take Reboot Break'),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final progress = _totalSeconds > 0
        ? (_totalSeconds - _remainingSeconds) / _totalSeconds
        : 0.0;

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeDisplay =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

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
            ? _buildZenFullscreenView(context, progress, timeDisplay)
            : _buildSetupView(context, progress, timeDisplay),
      ),
    );
  }

  /// Zen Fullscreen Pomodoro View: 100% Distraction-free, hero timer takes the screen
  Widget _buildZenFullscreenView(
    BuildContext context,
    double progress,
    String timeDisplay,
  ) {
    final isBreak = _totalSeconds <= 600;

    return SafeArea(
      key: const ValueKey('zen_fullscreen_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Zen Minimal Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Minimize / Exit Focus',
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AxisColors.textHigh),
                  onPressed: () {
                    if (_isRunning) {
                      setState(() => _zenModeOverride = false);
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                ),
                // Target Objective Pill (Tap to view task description if attached, or attach task)
                Flexible(
                  child: InkWell(
                    onTap: () {
                      if (_attachedTask != null) {
                        _showTaskDescriptionSheet(_attachedTask!);
                      } else {
                        _pickTask();
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _attachedTask != null
                              ? AxisColors.secondary.withValues(alpha: 0.4)
                              : AxisColors.borderPrimary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _attachedTask != null
                                ? Icons.radio_button_checked_rounded
                                : Icons.bolt_rounded,
                            size: 14,
                            color: isBreak
                                ? AxisColors.warning
                                : AxisColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _attachedTask?.title ??
                                  (isBreak ? 'Reboot Break' : 'Deep Work Cycle'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                          if (_attachedTask != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.description_outlined,
                              size: 13,
                              color: AxisColors.secondary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Toggle back to Setup & Details
                IconButton(
                  tooltip: 'View Setup & Stats',
                  icon: const Icon(Icons.tune_rounded,
                      color: AxisColors.textMuted),
                  onPressed: () => setState(() => _zenModeOverride = false),
                ),
              ],
            ),

            const Spacer(flex: 1),

            // Hero Fullscreen Pomodoro Timer Dial
            NeonTimerDial(
              size: 290,
              progress: progress,
              timeDisplay: timeDisplay,
              isBreak: isBreak,
              isRunning: _isRunning,
            ),

            const Spacer(flex: 1),

            // Hero Pause / Engage Button
            _buildEngageButton(),
            const SizedBox(height: 12),

            // Zen Quick Auxiliary Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.textHigh,
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _addFiveMinutes,
                    icon: const Icon(Icons.add_alarm_rounded,
                        size: 16, color: AxisColors.secondary),
                    label: const Text('+5 Min Focus',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.textHigh,
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: isBreak ? () => _resetTimer() : _setBreak,
                    icon: Icon(
                      isBreak ? Icons.play_arrow_rounded : Icons.coffee_rounded,
                      size: 16,
                      color: AxisColors.warning,
                    ),
                    label: Text(
                      isBreak ? 'End Break' : 'Take Break',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ambient Soundscape Floating Bar (Tappable for Quick Sound Change)
            _buildZenSoundscapeBar(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// Compact Zen Ambient Soundscape Bar
  Widget _buildZenSoundscapeBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _soundService.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return InkWell(
          onTap: _openSoundscapeModal,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPlaying
                    ? AxisColors.secondary.withValues(alpha: 0.4)
                    : AxisColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPlaying ? Icons.music_note_rounded : Icons.music_off_rounded,
                  size: 18,
                  color: isPlaying ? AxisColors.secondary : AxisColors.textDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'AMBIENT SOUNDSCAPE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.textMuted,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        _selectedSoundscape,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AxisColors.textHigh,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  iconSize: 20,
                  tooltip: isPlaying ? 'Mute Sound' : 'Play Sound',
                  icon: Icon(
                    isPlaying
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: isPlaying ? AxisColors.secondary : AxisColors.textDim,
                  ),
                  onPressed: () => _soundService.toggle(_selectedSoundscape),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AxisColors.borderSubtle),
                  ),
                  child: const Text(
                    'CHANGE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AxisColors.primarySoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Setup View: Full session dashboard with target picker, settings, yield stats, and sound rack
  Widget _buildSetupView(
    BuildContext context,
    double progress,
    String timeDisplay,
  ) {
    return NestedScrollView(
      key: const ValueKey('setup_view'),
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: AxisColors.canvasBase,
          elevation: 0,
          leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_rounded, color: AxisColors.textHigh),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AxisColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'DEEP WORK',
                  style: TextStyle(
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
              tooltip: 'Session Settings',
              onPressed: _openSettings,
            ),
          ],
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // Target Task Capsule (Tap to view description if attached, or attach task)
            InkWell(
              onTap: () {
                if (_attachedTask != null) {
                  _showTaskDescriptionSheet(_attachedTask!);
                } else {
                  _pickTask();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _attachedTask != null
                        ? AxisColors.secondary.withValues(alpha: 0.4)
                        : AxisColors.borderPrimary,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _attachedTask != null
                          ? Icons.radio_button_checked_rounded
                          : Icons.bolt_rounded,
                      size: 16,
                      color: AxisColors.secondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'TARGET OBJECTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AxisColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              if (_attachedTask != null) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  '• Tap for description',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AxisColors.secondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _attachedTask?.title ??
                                'Tap to attach a task...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _attachedTask != null
                                  ? AxisColors.textHigh
                                  : AxisColors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_attachedTask != null)
                      IconButton(
                        tooltip: 'Change Target Task',
                        icon: const Icon(Icons.swap_horiz_rounded,
                            size: 18, color: AxisColors.textDim),
                        onPressed: _pickTask,
                      )
                    else
                      const Icon(Icons.unfold_more_rounded,
                          size: 18, color: AxisColors.textDim),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Neon Radial Glow Timer Dial (Tappable to return to fullscreen when running)
            InkWell(
              onTap: _isRunning
                  ? () => setState(() => _zenModeOverride = true)
                  : null,
              borderRadius: BorderRadius.circular(150),
              child: NeonTimerDial(
                size: 250,
                progress: progress,
                timeDisplay: timeDisplay,
                isBreak: _totalSeconds <= 600,
                isRunning: _isRunning,
              ),
            ),
            const SizedBox(height: 24),

            // Yield Prediction Live Strip
            _buildYieldStrip(),
            const SizedBox(height: 24),

            // Primary Engagement Action / Return to Fullscreen
            _buildEngageButton(timeDisplay: timeDisplay),
            const SizedBox(height: 10),

            // Auxiliary Actions
            _buildAuxiliaryButtons(),
            const SizedBox(height: 28),

            // Redesigned Neural Soundscapes Rack
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

  Widget _buildYieldStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard_rounded,
                  size: 15, color: AxisColors.tertiary),
              SizedBox(width: 4),
              Text(
                'Yield:',
                style: TextStyle(fontSize: 11, color: AxisColors.textMuted),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '+75 Base',
                style: TextStyle(
                  fontSize: 10,
                  color: AxisColors.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '+38 Boost',
                style: TextStyle(
                  fontSize: 10,
                  color: AxisColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '113 XP',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AxisColors.textHigh,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTaskDescriptionSheet(Task task) {
    Task currentTask = task;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: const Color(0xF50C1626),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AxisColors.borderPrimary, width: 1.2),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modal Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AxisColors.borderGlass2,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),

              // Header: Icon + Title + Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AxisColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AxisColors.secondary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.assignment_rounded,
                      color: AxisColors.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TARGET OBJECTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textMuted,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          currentTask.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textHigh,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close description',
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, color: AxisColors.textDim),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(color: AxisColors.borderSubtle, height: 1),
              const SizedBox(height: 14),

              // Description Body (Markdown rendered)
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'DESCRIPTION / NOTES',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.secondary,
                              letterSpacing: 1.1,
                            ),
                          ),
                          if (currentTask.notes != null &&
                              currentTask.notes!.trim().isNotEmpty)
                            const ReadingFontSizeControl(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (currentTask.notes != null &&
                          currentTask.notes!.trim().isNotEmpty)
                        ValueListenableBuilder<double>(
                          valueListenable:
                              ReadingPreferencesService().fontScaleNotifier,
                          builder: (context, fontScale, _) {
                            return AxisMarkdownViewer(
                              markdown: currentTask.notes!,
                              selectable: true,
                              fontScale: fontScale,
                              onMarkdownChanged: (updatedNotes) async {
                                final updatedTask =
                                    currentTask.copyWith(notes: updatedNotes);
                                setSheetState(() => currentTask = updatedTask);
                                if (_attachedTask?.id == task.id) {
                                  _sessionService.setAttachedTask(updatedTask);
                                  setState(() {});
                                }
                                await TaskRepository().updateTask(updatedTask);
                              },
                            );
                          },
                        )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceLow.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AxisColors.borderSubtle),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.notes_rounded,
                                size: 16, color: AxisColors.textDim),
                            SizedBox(width: 8),
                            Text(
                              'No description provided for this task.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AxisColors.textDim,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Bottom Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.textHigh,
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickTask();
                    },
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Switch Task', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AxisColors.secondary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'Back to Focus',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildEngageButton({String? timeDisplay}) {
    if (_isRunning && !_isZenMode) {
      return Column(
        children: [
          // Primary Action: Return directly to Zen Fullscreen Pomodoro
          InkWell(
            onTap: () => setState(() => _zenModeOverride = true),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AxisColors.primary, AxisColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.secondary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      timeDisplay != null
                          ? 'RETURN TO FULLSCREEN ($timeDisplay)'
                          : 'RETURN TO FULLSCREEN',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Secondary Action: Pause Session
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AxisColors.warning,
              side: BorderSide(
                color: AxisColors.warning.withValues(alpha: 0.6),
                width: 1.2,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: _toggleTimer,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: const Text(
              'PAUSE SESSION',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _toggleTimer,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isRunning
                ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                : [AxisColors.primary, const Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: (_isRunning ? AxisColors.warning : AxisColors.primary)
                  .withValues(alpha: 0.4),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              _isRunning ? 'PAUSE DEEP SESSION' : 'ENGAGE DEEP SESSION',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuxiliaryButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AxisColors.textHigh,
              side: const BorderSide(color: AxisColors.borderSubtle),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _setBreak,
            icon: const Icon(Icons.coffee_rounded,
                size: 16, color: AxisColors.warning),
            label: Text(
              '${_config.shortBreakMinutes}m Reboot Break',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AxisColors.textHigh,
              side: const BorderSide(color: AxisColors.borderSubtle),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () => _resetTimer(),
            icon: const Icon(Icons.restart_alt_rounded,
                size: 16, color: AxisColors.secondary),
            label: const Text(
              'Reset Quantum',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
