import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/ui/focus/focus_settings_sheet.dart';

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
    {
      'title': 'Deep Theta 40Hz',
      'subtitle': 'Cognitive Entrainment',
      'icon': Icons.waves_rounded,
      'color': AxisColors.secondary,
    },
    {
      'title': 'Neon Rain',
      'subtitle': 'Spatial Ambient',
      'icon': Icons.grain_rounded,
      'color': AxisColors.primary,
    },
    {
      'title': 'Quantum Void',
      'subtitle': 'Sub-bass Drone',
      'icon': Icons.blur_circular_rounded,
      'color': AxisColors.tertiary,
    },
    {
      'title': 'Cyber Coffee',
      'subtitle': 'Binaural Lo-Fi',
      'icon': Icons.coffee_rounded,
      'color': AxisColors.warning,
    },
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null && _sessionService.attachedTask == null) {
      _sessionService.setAttachedTask(widget.initialTask);
    }
    _sessionService.remainingSecondsNotifier.addListener(_onServiceUpdate);
    _sessionService.isRunningNotifier.addListener(_onServiceUpdate);
    _completionSubscription =
        _sessionService.onSessionCompleted.listen((xp) {
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
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AxisColors.tertiary, size: 28),
            const SizedBox(width: 8),
            const Text('Deep Session Complete!',
                style: TextStyle(color: AxisColors.textHigh, fontSize: 18)),
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
                    color: AxisColors.tertiary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Yield Awarded:',
                      style: TextStyle(color: AxisColors.textHigh)),
                  Text('+$xp XP',
                      style: const TextStyle(
                          color: AxisColors.tertiary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              _resetTimer(minutes: 25);
            },
            child: const Text('Engage Next Wave'),
          ),
        ],
      ),
    );
  }

  void _pickTask() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AxisColors.borderPrimary),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AxisColors.borderGlass2,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            const Text('ATTACH TARGET TASK',
                style: TextStyle(
                    color: AxisColors.secondary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Task>>(
                stream: _taskRepo.watchTasks(),
                builder: (context, snapshot) {
                  final tasks = (snapshot.data ?? [])
                      .where((t) => t.status != 'done')
                      .toList();

                  if (tasks.isEmpty) {
                    return const Center(
                      child: Text('No active tasks found',
                          style: TextStyle(color: AxisColors.textDim)),
                    );
                  }

                  return ListView.separated(
                    itemCount: tasks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = tasks[i];
                      return ListTile(
                        tileColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        title: Text(t.title,
                            style: const TextStyle(color: AxisColors.textHigh)),
                        subtitle: t.dueDate != null
                            ? Text('Due: ${t.dueDate}',
                                style: const TextStyle(
                                    color: AxisColors.textMuted, fontSize: 12))
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: AxisColors.secondary),
                        onTap: () {
                          _sessionService.setAttachedTask(t);
                          Navigator.pop(ctx);
                          setState(() {});
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
                        color: AxisColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: const Text('DEEP WORK',
                      style: TextStyle(
                          color: AxisColors.primarySoft,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5)),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon:
                    const Icon(Icons.tune_rounded, color: AxisColors.textHigh),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          Text('TARGET OBJECTIVE',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AxisColors.textMuted,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1)),
                          Text(
                            _attachedTask?.title ?? 'Tap to attach a task...',
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
            Center(
              child: SizedBox(
                width: 250,
                height: 250,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Ambient glow shadow
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AxisColors.secondary.withValues(alpha: 0.12),
                            blurRadius: 50,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    // Ring painter
                    CustomPaint(
                      size: const Size(250, 250),
                      painter: _NeonProgressPainter(progress: progress),
                    ),
                    // Center Time Display
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'DEEP WAVE BETA',
                          style: TextStyle(
                            fontSize: 11,
                            color: AxisColors.secondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeDisplay,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: AxisColors.textHigh,
                            letterSpacing: -2,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceHigh.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: Text(
                            _totalSeconds > 600
                                ? 'QUANTUM 01/02'
                                : 'REBOOT BREAK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AxisColors.primarySoft,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Yield Prediction Live Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded,
                          size: 16, color: AxisColors.tertiary),
                      const SizedBox(width: 6),
                      Text('Yield Prediction:',
                          style: TextStyle(
                              fontSize: 12, color: AxisColors.textMuted)),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('+75 Base',
                          style: TextStyle(
                              fontSize: 11,
                              color: AxisColors.tertiary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      const Text('+38 Boost',
                          style: TextStyle(
                              fontSize: 11,
                              color: AxisColors.secondary,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('113 XP',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AxisColors.textHigh)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Primary Engagement Action
            InkWell(
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
                      color: (_isRunning
                              ? AxisColors.warning
                              : AxisColors.primary)
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
                      _isRunning
                          ? 'PAUSE DEEP SESSION'
                          : 'ENGAGE DEEP SESSION',
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
            ),
            const SizedBox(height: 10),

            // Auxiliary Actions
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.textHigh,
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _setBreak,
                    icon: const Icon(Icons.coffee_rounded,
                        size: 16, color: AxisColors.warning),
                    label: Text('${_config.shortBreakMinutes}m Reboot Break',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AxisColors.textHigh,
                      side: const BorderSide(color: AxisColors.borderSubtle),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _resetTimer(),
                    icon: const Icon(Icons.restart_alt_rounded,
                        size: 16, color: AxisColors.secondary),
                    label: const Text('Reset Quantum',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Neural Soundscapes Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.graphic_eq_rounded,
                        size: 18, color: AxisColors.secondary),
                    SizedBox(width: 8),
                    Text('Neural Soundscapes',
                        style: TextStyle(
                            color: AxisColors.textHigh,
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ],
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: _soundService.isPlayingNotifier,
                  builder: (context, playing, _) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        await _soundService.toggle(_selectedSoundscape);
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: playing
                              ? AxisColors.tertiary.withValues(alpha: 0.2)
                              : AxisColors.surfaceHigh.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: playing
                                ? AxisColors.tertiary
                                : AxisColors.borderSubtle,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              playing
                                  ? Icons.volume_up_rounded
                                  : Icons.play_arrow_rounded,
                              size: 14,
                              color: playing
                                  ? AxisColors.tertiary
                                  : AxisColors.textDim,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              playing ? 'PLAYING' : 'PREVIEW',
                              style: TextStyle(
                                fontSize: 10,
                                color: playing
                                    ? AxisColors.tertiary
                                    : AxisColors.textMuted,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _soundscapes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.5,
              ),
              itemBuilder: (context, i) {
                final track = _soundscapes[i];
                final isSel = _selectedSoundscape == track['title'];
                final color = track['color'] as Color;

                return InkWell(
                  onTap: () {
                    final newTrack = track['title'] as String;
                    _sessionService.setSoundscape(newTrack);
                    setState(() {});
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSel
                          ? AxisColors.surfaceHigh
                          : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSel ? color : AxisColors.borderSubtle,
                        width: isSel ? 1.5 : 1,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.15),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(track['icon'] as IconData,
                                  size: 16, color: color),
                            ),
                            if (isSel)
                              Row(
                                children: [
                                  Container(
                                      width: 2,
                                      height: 10,
                                      color: color,
                                      margin: const EdgeInsets.only(right: 2)),
                                  Container(
                                      width: 2,
                                      height: 14,
                                      color: color,
                                      margin: const EdgeInsets.only(right: 2)),
                                  Container(
                                      width: 2,
                                      height: 8,
                                      color: color),
                                ],
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(track['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.textHigh)),
                            Text(track['subtitle'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10, color: AxisColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
  );
}
}

class _NeonProgressPainter extends CustomPainter {
  final double progress; // 0.0 -> 1.0

  _NeonProgressPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 16;

    // Track
    final trackPaint = Paint()
      ..color = AxisColors.surfaceHigh
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    final sweepAngle = 2 * pi * progress;
    final arcPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AxisColors.primary,
          AxisColors.secondary,
          AxisColors.tertiary,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _NeonProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
