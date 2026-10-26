import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme.dart';
import '../../../data/focus_session_service.dart';
import '../../../data/neural_sound_service.dart';
import '../../../data/note_repository.dart';
import '../../../data/task_repository.dart';
import '../../../domain/id_generator.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/ghost_button.dart';
import '../widgets/section_header.dart';
import '../widgets/telemetry_chip.dart';

/// Focus Timers Screen (Tab 3) — Deep work sessions and cognitive flow control.
class FocusTimersScreen extends StatefulWidget {
  const FocusTimersScreen({super.key});

  @override
  State<FocusTimersScreen> createState() => _FocusTimersScreenState();
}

class _FocusTimersScreenState extends State<FocusTimersScreen> {
  final _distractionNoteController = TextEditingController();

  void _showTaskSelectionDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AxisColors.canvasBase,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AxisColors.borderGlass2, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ATTACH TASK TO FOCUS SESSION',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AxisColors.secondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: StreamBuilder<List<Task>>(
                  stream: TaskRepository().watchTasks(),
                  builder: (context, snapshot) {
                    final tasks = (snapshot.data ?? []).where((t) => !t.isCompleted).toList();
                    if (tasks.isEmpty) {
                      return Center(
                        child: Text(
                          'No active deliverables found.',
                          style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textDim),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: tasks.length,
                      separatorBuilder: (_, _) => const Divider(color: AxisColors.borderSubtle, height: 1),
                      itemBuilder: (context, idx) {
                        final t = tasks[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          title: Text(
                            t.title,
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, color: AxisColors.textHigh),
                          ),
                          subtitle: t.notes != null && t.notes!.isNotEmpty
                              ? Text(
                                  t.notes!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textMuted),
                                )
                              : null,
                          onTap: () {
                            FocusSessionService().setAttachedTask(t);
                            Navigator.of(dialogCtx).pop();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GhostButton(
                    label: 'Detach Task',
                    icon: Icons.link_off_rounded,
                    color: AxisColors.priorityHigh,
                    onPressed: () {
                      FocusSessionService().setAttachedTask(null);
                      Navigator.of(dialogCtx).pop();
                    },
                  ),
                  GhostButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _distractionNoteController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveDistractionNote() async {
    final text = _distractionNoteController.text.trim();
    if (text.isEmpty) return;

    final note = Note(
      id: IdGenerator.generateDeterministicId('note_${DateTime.now().microsecondsSinceEpoch}'),
      title: 'Distraction Thought',
      bodyMd: text,
      category: 'note',
    );
    await NoteRepository().addNote(note);
    _distractionNoteController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Distraction captured to Vault'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesktopLayout.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 5.2 Header
          _buildHeader(),
          const SizedBox(height: DesktopLayout.sectionSpacing),

          // Main 2-Column Split
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _buildTimerCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildDistractionsCard(),
                  ],
                ),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    _buildSessionGoalCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildSoundscapesCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildTodayScheduleCard(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ValueListenableBuilder<bool>(
      valueListenable: FocusSessionService().isRunningNotifier,
      builder: (context, isRunning, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: FocusSessionService().isBreakNotifier,
          builder: (context, isBreak, _) {
            final sprintLabel = isBreak ? 'REBOOT BREAK' : 'FOCUS SPRINT';
            final statusLabel = isBreak
                ? (isRunning ? 'BREAK IN PROGRESS' : 'BREAK STANDBY')
                : (isRunning ? 'ACTIVE SPRINT' : 'STANDBY');
            final badgeColor = isBreak ? AxisColors.warning : (isRunning ? AxisColors.tertiary : AxisColors.warning);

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            sprintLabel,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: isBreak ? AxisColors.warning : AxisColors.secondary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TelemetryChip(
                            label: statusLabel,
                            dotColor: badgeColor,
                            color: badgeColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isBreak ? 'Cognitive Reset & Hydration' : 'Deep Work Focus Session',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ValueListenableBuilder<int>(
                  valueListenable: FocusSessionService().completedCyclesNotifier,
                  builder: (context, cycles, _) {
                    final sessionNum = (cycles % 4) + 1;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TelemetryChip(
                          label: 'SESSION: $sessionNum of 4',
                          color: isBreak ? AxisColors.warning : AxisColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        TelemetryChip(
                          label: isBreak ? 'DURATION: 5m Break' : 'DURATION: 25m Sprint',
                          color: AxisColors.primarySoft,
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimerCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Session Stepper
          ValueListenableBuilder<int>(
            valueListenable: FocusSessionService().completedCyclesNotifier,
            builder: (context, cycles, _) {
              final activeIndex = cycles % 4;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepItem('Session 1', isDone: cycles > 0, isActive: activeIndex == 0),
                    _buildStepDivider(),
                    _buildStepItem('Session 2', isDone: cycles > 1, isActive: activeIndex == 1),
                    _buildStepDivider(),
                    _buildStepItem('Session 3', isDone: cycles > 2, isActive: activeIndex == 2),
                    _buildStepDivider(),
                    _buildStepItem('Session 4', isDone: cycles > 3, isActive: activeIndex == 3),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Circular Dial
          Center(
            child: ValueListenableBuilder<bool>(
              valueListenable: FocusSessionService().isBreakNotifier,
              builder: (context, isBreak, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: FocusSessionService().remainingSecondsNotifier,
                  builder: (context, remainingSec, _) {
                    final totalSec = FocusSessionService().totalSeconds > 0
                        ? FocusSessionService().totalSeconds
                        : 25 * 60;
                    final progress = 1.0 - (remainingSec / totalSec).clamp(0.0, 1.0);
                    final min = remainingSec ~/ 60;
                    final sec = remainingSec % 60;
                    final timeDisplay =
                        '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';

                    return SizedBox(
                      width: 240,
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(240, 240),
                            painter: _TimerDialPainter(progress: progress, isBreak: isBreak),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TIME REMAINING',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AxisColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timeDisplay,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 44,
                                  fontWeight: FontWeight.w800,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(progress * 100).toInt()}% completed',
                                style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.secondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
            );
          },
        ),
      ),
      const SizedBox(height: 28),

          // Control Buttons
          ValueListenableBuilder<bool>(
            valueListenable: FocusSessionService().isRunningNotifier,
            builder: (context, isRunning, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: FocusSessionService().isBreakNotifier,
                builder: (context, isBreak, _) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isBreak)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GhostButton(
                              label: 'Skip Break',
                              icon: Icons.skip_next_rounded,
                              height: 42,
                              color: AxisColors.warning,
                              borderColor: AxisColors.warning.withValues(alpha: 0.3),
                              onPressed: () => FocusSessionService().startFocus(),
                            ),
                          ),
                        AccentButton(
                          label: isRunning ? '⏸ Pause' : (isBreak ? '▶ Start Break' : '▶ Start Session'),
                          icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          onPressed: () => FocusSessionService().toggleTimer(),
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: '+5m',
                          icon: Icons.add_rounded,
                          height: 42,
                          onPressed: () => FocusSessionService().addSeconds(300),
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: 'Reset',
                          icon: Icons.replay_rounded,
                          height: 42,
                          onPressed: () => FocusSessionService().resetTimer(),
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: 'Stop',
                          icon: Icons.stop_rounded,
                          height: 42,
                          color: AxisColors.priorityHigh,
                          borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
                          onPressed: () => FocusSessionService().terminateSession(),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String title, {required bool isDone, required bool isActive}) {
    Color dotColor = AxisColors.textDim;
    if (isDone) dotColor = AxisColors.tertiary;
    if (isActive) dotColor = AxisColors.secondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: dotColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: dotColor, width: 1.5),
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 12, color: AxisColors.tertiary)
                : (isActive
                    ? Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle))
                    : null),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? AxisColors.textHigh : AxisColors.textDim,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Container(
      width: 24,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AxisColors.borderSubtle,
    );
  }

  Widget _buildDistractionsCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'QUICK NOTES & DISTRACTIONS',
            subtitle: 'Capture fleeting thoughts without breaking flow',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _distractionNoteController,
              maxLines: 2,
              style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Capture a quick idea, task or thought to review later...',
                hintStyle: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GhostButton(
              label: 'Save Note to Vault',
              icon: Icons.save_outlined,
              onPressed: _handleSaveDistractionNote,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionGoalCard() {
    return ValueListenableBuilder<Task?>(
      valueListenable: FocusSessionService().attachedTaskNotifier,
      builder: (context, task, _) {
        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'CURRENT SESSION GOAL',
                trailing: GhostButton(
                  label: task != null ? 'Switch Task' : 'Attach Task',
                  icon: Icons.link_rounded,
                  onPressed: _showTaskSelectionDialog,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task?.title ?? 'Deep Cognitive Focus & Flow',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task?.notes != null && task!.notes!.isNotEmpty
                          ? task.notes!
                          : 'Eliminate interruptions and maintain uninterrupted concentration.',
                      style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'SPRINT DELIVERABLES',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AxisColors.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              _buildDeliverableRow('Core logic refactoring', true),
              _buildDeliverableRow('Interface telemetry verification', false),
              _buildDeliverableRow('Benchmark memory allocations', false),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSoundscapesCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'AMBIENT SOUNDSCAPES',
            subtitle: 'Neural audio entrainment for deep concentration',
            trailing: ValueListenableBuilder<bool>(
              valueListenable: NeuralSoundService().isPlayingNotifier,
              builder: (context, isPlaying, _) {
                return TelemetryChip(
                  label: isPlaying ? 'AUDIO ACTIVE' : 'STANDBY',
                  color: isPlaying ? AxisColors.tertiary : AxisColors.textDim,
                  dotColor: isPlaying ? AxisColors.tertiary : AxisColors.textDim,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Volume Slider Row
          ValueListenableBuilder<double>(
            valueListenable: NeuralSoundService().volumeNotifier,
            builder: (context, volume, _) {
              return Row(
                children: [
                  Icon(
                    volume > 0.5
                        ? Icons.volume_up_rounded
                        : (volume > 0 ? Icons.volume_down_rounded : Icons.volume_mute_rounded),
                    size: 16,
                    color: AxisColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        activeTrackColor: AxisColors.secondary,
                        inactiveTrackColor: AxisColors.surfaceHighest,
                        thumbColor: AxisColors.secondary,
                      ),
                      child: Slider(
                        value: volume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) => NeuralSoundService().setVolume(val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${(volume * 100).toInt()}%',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textMuted),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // Soundscapes Chips Wrap
          ValueListenableBuilder<String?>(
            valueListenable: NeuralSoundService().currentTrackNotifier,
            builder: (context, currentTrack, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: NeuralSoundService().isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSoundChip('Gentle Rain', Icons.water_drop_rounded, currentTrack, isPlaying),
                      _buildSoundChip('Ocean Waves', Icons.waves_rounded, currentTrack, isPlaying),
                      _buildSoundChip('Campfire Glow', Icons.local_fire_department_rounded, currentTrack, isPlaying),
                      _buildSoundChip('Deep Space', Icons.dark_mode_rounded, currentTrack, isPlaying),
                      _buildSoundChip('Zen Garden', Icons.spa_rounded, currentTrack, isPlaying),
                      _buildSoundChip('White Noise', Icons.graphic_eq_rounded, currentTrack, isPlaying),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSoundChip(String name, IconData icon, String? currentTrack, bool isPlaying) {
    final isSelected = currentTrack == name && isPlaying;
    return InkWell(
      onTap: () => NeuralSoundService().toggle(name),
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AxisColors.secondary.withValues(alpha: 0.15) : AxisColors.surfaceLowest,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AxisColors.secondary : AxisColors.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.pause_circle_rounded : icon,
              size: 14,
              color: isSelected ? AxisColors.secondary : AxisColors.textDim,
            ),
            const SizedBox(width: 6),
            Text(
              name,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AxisColors.secondary : AxisColors.textHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliverableRow(String title, bool done) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 15,
            color: done ? AxisColors.tertiary : AxisColors.textDim,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.getFont(
                'Geist',
                fontSize: 12,
                color: done ? AxisColors.textDim : AxisColors.textHigh,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayScheduleCard() {
    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: "TODAY'S SCHEDULE",
            trailing: TelemetryChip(
              label: '3 of 4 planned',
              color: AxisColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          _buildScheduleRow('Session 1', '08:30 — 09:15', 'Completed', AxisColors.tertiary),
          _buildScheduleRow('Session 2', '10:00 — 10:45', 'Active Sprint', AxisColors.secondary),
          _buildScheduleRow('Session 3', '14:30 — 15:15', 'Scheduled', AxisColors.textDim),
          _buildScheduleRow('Session 4', '16:45 — 17:30', 'Scheduled', AxisColors.textDim),
        ],
      ),
    );
  }

  Widget _buildScheduleRow(String title, String timeRange, String status, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AxisColors.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AxisColors.textHigh),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              timeRange,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
            ),
          ),
          const SizedBox(width: 6),
          TelemetryChip(
            label: status,
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          ),
        ],
      ),
    );
  }
}

class _TimerDialPainter extends CustomPainter {
  _TimerDialPainter({required this.progress, this.isBreak = false});

  final double progress;
  final bool isBreak;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Track circle
    final trackPaint = Paint()
      ..color = AxisColors.surfaceHighest.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress Arc
    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: isBreak
            ? [AxisColors.warning, const Color(0xFFF59E0B)]
            : [AxisColors.secondary, AxisColors.primary],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 8;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimerDialPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isBreak != isBreak;
}
