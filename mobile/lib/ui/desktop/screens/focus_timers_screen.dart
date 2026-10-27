import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme.dart';
import '../../../data/focus_repository.dart';
import '../../../data/focus_session_service.dart';
import '../../../data/neural_sound_service.dart';
import '../../../data/note_repository.dart';
import '../../../data/task_repository.dart';
import '../../../domain/id_generator.dart';
import '../../common/axis_markdown_viewer.dart';
import '../core/desktop_layout.dart';
import '../widgets/accent_button.dart';
import '../widgets/desktop_card.dart';
import '../widgets/desktop_checkbox.dart';
import '../widgets/desktop_horizontal_scroll.dart';
import '../widgets/ghost_button.dart';
import '../widgets/priority_badge.dart';
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

  @override
  void initState() {
    super.initState();
  }

  List<({String text, bool isDone, int lineIndex})> _parseTaskChecklist(String? notes) {
    if (notes == null || notes.isEmpty) return [];
    final lines = notes.split('\n');
    final list = <({String text, bool isDone, int lineIndex})>[];
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('- [ ]') || line.startsWith('- [x]') || line.startsWith('- [X]')) {
        final isDone = line.startsWith('- [x]') || line.startsWith('- [X]');
        final text = line.substring(5).trim();
        list.add((text: text, isDone: isDone, lineIndex: i));
      }
    }
    return list;
  }

  String _stripChecklistFromNotes(String? notes) {
    if (notes == null || notes.trim().isEmpty) return '';
    final lines = notes.split('\n');
    final nonChecklistLines = lines.where((line) {
      final trimmed = line.trim();
      return !trimmed.startsWith('- [ ]') &&
             !trimmed.startsWith('- [x]') &&
             !trimmed.startsWith('- [X]');
    }).toList();
    return nonChecklistLines.join('\n').trim();
  }

  Future<void> _toggleTaskChecklist(Task task, int lineIndex) async {
    final lines = (task.notes ?? '').split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    final line = lines[lineIndex];
    if (line.contains('- [ ]')) {
      lines[lineIndex] = line.replaceFirst('- [ ]', '- [x]');
    } else if (line.contains('- [x]') || line.contains('- [X]')) {
      lines[lineIndex] = line.replaceFirst(RegExp(r'- \[[xX]\]'), '- [ ]');
    }
    final updated = task.copyWith(notes: lines.join('\n'));
    await TaskRepository().updateTask(updated);
    FocusSessionService().setAttachedTask(updated);
  }

  void _showTaskSelectionDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Material(
          color: AxisColors.canvasBase,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AxisColors.borderGlass2, width: 1),
          ),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(20),
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
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                              hoverColor: AxisColors.surfaceHigh.withValues(alpha: 0.3),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: GhostButton(
                    label: 'Close',
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFocusSettingsDialog() {
    final focusService = FocusSessionService();
    final initial = focusService.config;
    int focusMin = initial.focusMinutes;
    int shortBreakMin = initial.shortBreakMinutes;
    int longBreakMin = initial.longBreakMinutes;
    int cycles = initial.cyclesBeforeLongBreak;
    bool autoStartBreaks = initial.autoStartBreaks;
    bool soundscapeAutoPlay = initial.soundscapeAutoPlay;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 480,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AxisColors.canvasBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AxisColors.borderGlass2, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 18, color: AxisColors.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'Focus Sprint Protocol',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AxisColors.textHigh,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AxisColors.textDim),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Focus Sprint duration options
                  Text('FOCUS SPRINT DURATION', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textDim)),
                  const SizedBox(height: 6),
                  Row(
                    children: [15, 25, 45, 60].map((min) {
                      final isSel = focusMin == min;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => focusMin = min),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? AxisColors.primary.withValues(alpha: 0.25) : AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSel ? AxisColors.primary : AxisColors.borderSubtle),
                            ),
                            child: Center(
                              child: Text(
                                '${min}m',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? AxisColors.textHigh : AxisColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Short Break duration options
                  Text('SHORT REBOOT BREAK', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textDim)),
                  const SizedBox(height: 6),
                  Row(
                    children: [3, 5, 10, 15].map((min) {
                      final isSel = shortBreakMin == min;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => shortBreakMin = min),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? AxisColors.warning.withValues(alpha: 0.2) : AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSel ? AxisColors.warning : AxisColors.borderSubtle),
                            ),
                            child: Center(
                              child: Text(
                                '${min}m',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? AxisColors.warning : AxisColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Cycles before long break
                  Text('CYCLES BEFORE LONG RESET', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: AxisColors.textDim)),
                  const SizedBox(height: 6),
                  Row(
                    children: [2, 3, 4, 6].map((c) {
                      final isSel = cycles == c;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => cycles = c),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: isSel ? AxisColors.secondary.withValues(alpha: 0.2) : AxisColors.surfaceLowest,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isSel ? AxisColors.secondary : AxisColors.borderSubtle),
                            ),
                            child: Center(
                              child: Text(
                                '$c Cycles',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 11,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? AxisColors.secondary : AxisColors.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Auto start breaks switch
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Auto-start reboot breaks', style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textHigh)),
                        Switch(
                          value: autoStartBreaks,
                          activeThumbColor: AxisColors.secondary,
                          onChanged: (val) => setDialogState(() => autoStartBreaks = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: Text('Cancel', style: GoogleFonts.getFont('Geist', color: AxisColors.textMuted)),
                      ),
                      const SizedBox(width: 8),
                      AccentButton(
                        label: 'Save Protocol',
                        onPressed: () {
                          final newConfig = initial.copyWith(
                            focusMinutes: focusMin,
                            shortBreakMinutes: shortBreakMin,
                            longBreakMinutes: longBreakMin,
                            cyclesBeforeLongBreak: cycles,
                            autoStartBreaks: autoStartBreaks,
                            soundscapeAutoPlay: soundscapeAutoPlay,
                          );
                          focusService.updateConfig(newConfig);
                          Navigator.of(dialogCtx).pop();
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
      category: 'General',
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

          // Main Layout: Pomodoro widget takes full page width and length, and rest of widgets are organized under it
          _buildTimerCard(isExpanded: true),
          const SizedBox(height: DesktopLayout.sectionSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildSessionGoalCard(),
                    const SizedBox(height: DesktopLayout.sectionSpacing),
                    _buildDistractionsCard(),
                  ],
                ),
              ),
              const SizedBox(width: DesktopLayout.sectionSpacing),
              Expanded(
                child: Column(
                  children: [
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
                        const SizedBox(width: 8),
                        GhostButton(
                          label: 'Settings',
                          icon: Icons.tune_rounded,
                          height: 28,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          onPressed: _showFocusSettingsDialog,
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

  Widget _buildTimerCard({bool isExpanded = false}) {
    final dialSize = isExpanded ? 310.0 : 240.0;
    final timerFontSize = isExpanded ? 56.0 : 44.0;
    final strokeWidth = isExpanded ? 10.0 : 8.0;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Dynamic Session Stepper
          ValueListenableBuilder<int>(
            valueListenable: FocusSessionService().completedCyclesNotifier,
            builder: (context, cycles, _) {
              final activeIndex = cycles % 4;
              return DesktopHorizontalScrollView(
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

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      width: dialSize,
                      height: dialSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(dialSize, dialSize),
                            painter: _TimerDialPainter(
                              progress: progress,
                              isBreak: isBreak,
                              strokeWidth: strokeWidth,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TIME REMAINING',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: isExpanded ? 11 : 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AxisColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timeDisplay,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: timerFontSize,
                                  fontWeight: FontWeight.w800,
                                  color: AxisColors.textHigh,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${(progress * 100).toInt()}% completed',
                                style: GoogleFonts.getFont('Geist', fontSize: isExpanded ? 13 : 11, color: AxisColors.secondary),
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
                  return DesktopHorizontalScrollView(
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
                          label: isRunning ? 'Pause' : (isBreak ? 'Start Break' : 'Start Session'),
                          icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          onPressed: () => FocusSessionService().toggleTimer(),
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: '5m',
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
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: _distractionNoteController,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textHigh),
              decoration: InputDecoration(
                hintText: 'Capture a quick idea, task or thought to review later...',
                hintStyle: GoogleFonts.getFont('Geist', fontSize: 13, color: AxisColors.textDim),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onSubmitted: (_) => _handleSaveDistractionNote(),
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
        final checklist = _parseTaskChecklist(task?.notes);
        final cleanNotes = _stripChecklistFromNotes(task?.notes);

        return DesktopCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionHeader(
                title: 'CURRENT SESSION GOAL',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GhostButton(
                      label: task != null ? 'Switch Task' : 'Attach Task',
                      icon: task != null ? Icons.swap_horiz_rounded : Icons.link_rounded,
                      height: 28,
                      onPressed: _showTaskSelectionDialog,
                    ),
                    if (task != null) ...[
                      const SizedBox(width: 8),
                      GhostButton(
                        label: 'Detach Task',
                        icon: Icons.link_off_rounded,
                        height: 28,
                        color: AxisColors.priorityHigh,
                        borderColor: AxisColors.priorityHigh.withValues(alpha: 0.3),
                        onPressed: () => FocusSessionService().setAttachedTask(null),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AxisColors.borderSubtle, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task != null) ...[
                      // Task Title & Priority Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PriorityBadge(priority: task.priority),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Metadata Telemetry Chips Row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (task.dueDate != null && task.dueDate!.isNotEmpty)
                            TelemetryChip(
                              label: task.dueDate!,
                              color: AxisColors.secondary,
                              icon: Icons.calendar_today_rounded,
                            ),
                          if (task.estimateMin != null)
                            TelemetryChip(
                              label: '${task.estimateMin}m Estimate',
                              color: AxisColors.primary,
                              icon: Icons.timer_outlined,
                            ),
                          TelemetryChip(
                            label: task.isCompleted ? 'COMPLETED' : 'IN PROGRESS',
                            color: task.isCompleted ? AxisColors.tertiary : AxisColors.warning,
                          ),
                          if (checklist.isNotEmpty)
                            TelemetryChip(
                              label: 'SUBTASKS (${checklist.where((c) => c.isDone).length}/${checklist.length})',
                              color: AxisColors.secondary,
                              icon: Icons.checklist_rounded,
                            ),
                        ],
                      ),

                      // Formatted Markdown Notes (checklists stripped out so no raw markdown)
                      if (cleanNotes.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AxisColors.borderSubtle, height: 1),
                        const SizedBox(height: 10),
                        AxisMarkdownViewer(
                          markdown: cleanNotes,
                          selectable: true,
                          baseStyle: GoogleFonts.getFont('Geist', fontSize: 13, height: 1.45, color: AxisColors.textHigh),
                        ),
                      ],

                      // Subtask Checklist items with clean interactive checkboxes
                      if (checklist.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: AxisColors.borderSubtle, height: 1),
                        const SizedBox(height: 10),
                        ...checklist.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                DesktopCheckbox(
                                  value: item.isDone,
                                  size: 18,
                                  color: AxisColors.secondary,
                                  onChanged: (_) => _toggleTaskChecklist(task, item.lineIndex),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.text,
                                    style: GoogleFonts.getFont(
                                      'Geist',
                                      fontSize: 13,
                                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                                      color: item.isDone ? AxisColors.textDim : AxisColors.textHigh,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],

                      // Fallback when task has no notes and no checklist
                      if (cleanNotes.isEmpty && checklist.isEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Eliminate interruptions and maintain uninterrupted concentration on this deliverable.',
                          style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                        ),
                      ],
                    ] else ...[
                      // Standby state (no task attached)
                      Text(
                        'Deep Cognitive Focus & Flow',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AxisColors.textHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Eliminate interruptions and maintain uninterrupted concentration.',
                        style: GoogleFonts.getFont('Geist', fontSize: 12, color: AxisColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
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


  Widget _buildTodayScheduleCard() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: FocusRepository().watchTodayFocusSessions(),
      builder: (context, sessionSnap) {
        final sessions = sessionSnap.data ?? [];

        return ValueListenableBuilder<bool>(
          valueListenable: FocusSessionService().isRunningNotifier,
          builder: (context, isRunning, _) {
            final activeTask = FocusSessionService().attachedTask;
            final remainingSec = FocusSessionService().remainingSecondsNotifier.value;
            final remainingMin = (remainingSec / 60).ceil();

            return DesktopCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: "TODAY'S SCHEDULE & SPRINTS",
                    trailing: TelemetryChip(
                      label: '${sessions.length} logged today',
                      color: sessions.isNotEmpty ? AxisColors.tertiary : AxisColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // If active session is running, show it at the top
                  if (isRunning) ...[
                    _buildScheduleRow(
                      activeTask?.title ?? 'Active Focus Sprint',
                      'Now · $remainingMin min remaining',
                      'Active Sprint',
                      AxisColors.secondary,
                    ),
                  ],

                  // Completed sessions from database
                  ...sessions.map((s) {
                    final rawStart = s['started_at'] as String?;
                    final startDt = rawStart != null ? DateTime.tryParse(rawStart) : null;
                    final timeLabel = startDt != null
                        ? DateFormat('HH:mm').format(startDt.toLocal())
                        : 'Sprint';
                    final actualMin = (s['actual_min'] as num?)?.toInt() ?? 25;
                    final taskTitle = (s['task_title'] as String?)?.trim();
                    final title = (taskTitle != null && taskTitle.isNotEmpty)
                        ? taskTitle
                        : 'Deep Focus Sprint';

                    return _buildScheduleRow(
                      title,
                      '$timeLabel · ${actualMin}m',
                      'Completed',
                      AxisColors.tertiary,
                    );
                  }),

                  // If no active session and no completed sessions, show scheduled tasks or prompt
                  if (!isRunning && sessions.isEmpty) ...[
                    StreamBuilder<List<Task>>(
                      stream: TaskRepository().watchTasks(),
                      builder: (context, taskSnap) {
                        final tasks = taskSnap.data ?? [];
                        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                        final todayTasks = tasks
                            .where((t) => !t.isCompleted && (t.dueDate == todayStr || t.dueTime != null))
                            .take(3)
                            .toList();

                        if (todayTasks.isNotEmpty) {
                          return Column(
                            children: todayTasks.map((t) {
                              return _buildScheduleRow(
                                t.title,
                                t.dueTime ?? 'Today',
                                'Scheduled',
                                AxisColors.textDim,
                              );
                            }).toList(),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(
                            child: Text(
                              'No focus sprints recorded yet today. Launch a session to begin deep work.',
                              style: GoogleFonts.getFont('Geist', fontSize: 11, color: AxisColors.textDim),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
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
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AxisColors.textHigh),
                  ),
                ),
                if (timeRange.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    timeRange,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: AxisColors.textDim),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
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
  _TimerDialPainter({
    required this.progress,
    this.isBreak = false,
    this.strokeWidth = 8.0,
  });

  final double progress;
  final bool isBreak;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - (strokeWidth + 4);

    // Track circle
    final trackPaint = Paint()
      ..color = AxisColors.surfaceHighest.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

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
      ..strokeWidth = strokeWidth;

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
      oldDelegate.progress != progress ||
      oldDelegate.isBreak != isBreak ||
      oldDelegate.strokeWidth != strokeWidth;
}
