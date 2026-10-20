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

  FocusSessionConfig get _config => _sessionService.config;
  int get _totalSeconds => _sessionService.totalSeconds;
  int get _remainingSeconds => _sessionService.remainingSeconds;
  bool get _isRunning => _sessionService.isRunning;
  Task? get _attachedTask => _sessionService.attachedTask;
  String get _selectedSoundscape => _sessionService.selectedSoundscape;

  static const _soundscapes = [
    SoundscapeTrack(
      title: 'Deep Theta 40Hz',
      subtitle: 'Cognitive Entrainment',
      icon: Icons.waves_rounded,
      color: AxisColors.secondary,
    ),
    SoundscapeTrack(
      title: 'Neon Rain',
      subtitle: 'Spatial Ambient',
      icon: Icons.grain_rounded,
      color: AxisColors.primary,
    ),
    SoundscapeTrack(
      title: 'Quantum Void',
      subtitle: 'Sub-bass Drone',
      icon: Icons.blur_circular_rounded,
      color: AxisColors.tertiary,
    ),
    SoundscapeTrack(
      title: 'Cyber Coffee',
      subtitle: 'Binaural Lo-Fi',
      icon: Icons.coffee_rounded,
      color: AxisColors.warning,
    ),
  ];

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
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: AxisColors.canvasBase,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AxisColors.textHigh),
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
                icon: const Icon(Icons.tune_rounded,
                    color: AxisColors.textHigh),
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
              // Target Task Capsule
              InkWell(
                onTap: _pickTask,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AxisColors.borderPrimary),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radio_button_checked_rounded,
                          size: 16, color: AxisColors.secondary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Icon(Icons.unfold_more_rounded,
                          size: 18, color: AxisColors.textDim),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Neon Radial Glow Timer Dial
              NeonTimerDial(
                progress: progress,
                timeDisplay: timeDisplay,
                isBreak: _totalSeconds <= 600,
              ),
              const SizedBox(height: 24),

              // Yield Prediction Live Strip
              _buildYieldStrip(),
              const SizedBox(height: 24),

              // Primary Engagement Action
              _buildEngageButton(),
              const SizedBox(height: 10),

              // Auxiliary Actions
              _buildAuxiliaryButtons(),
              const SizedBox(height: 28),

              // Neural Soundscapes Selector
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
      ),
    );
  }

  Widget _buildYieldStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.card_giftcard_rounded,
                  size: 16, color: AxisColors.tertiary),
              SizedBox(width: 6),
              Text(
                'Yield Prediction:',
                style: TextStyle(fontSize: 12, color: AxisColors.textMuted),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                '+75 Base',
                style: TextStyle(
                  fontSize: 11,
                  color: AxisColors.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                '+38 Boost',
                style: TextStyle(
                  fontSize: 11,
                  color: AxisColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
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
                    fontSize: 11,
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

  Widget _buildEngageButton() {
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
