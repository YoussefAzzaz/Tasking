import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/focus_session_service.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/desktop_horizontal_scroll.dart';
import '../../widgets/ghost_button.dart';

/// Hero Pomodoro radial timer dial, session stepper, and flow control triggers.
class DesktopTimerHeroCard extends StatelessWidget {
  final bool isExpanded;

  const DesktopTimerHeroCard({
    super.key,
    this.isExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;
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
                    _StepItem(isAr ? 'الجلسة 1' : 'Session 1', isDone: cycles > 0, isActive: activeIndex == 0),
                    const _StepDivider(),
                    _StepItem(isAr ? 'الجلسة 2' : 'Session 2', isDone: cycles > 1, isActive: activeIndex == 1),
                    const _StepDivider(),
                    _StepItem(isAr ? 'الجلسة 3' : 'Session 3', isDone: cycles > 2, isActive: activeIndex == 2),
                    const _StepDivider(),
                    _StepItem(isAr ? 'الجلسة 4' : 'Session 4', isDone: cycles > 3, isActive: activeIndex == 3),
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
                                isAr ? 'الوقت المتبقي' : 'TIME REMAINING',
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
                                isAr
                                    ? 'اكتمل ${(progress * 100).toInt()}%'
                                    : '${(progress * 100).toInt()}% completed',
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
                            padding: const EdgeInsetsDirectional.only(end: 8.0),
                            child: GhostButton(
                              label: isAr ? 'تخطي الاستراحة' : 'Skip Break',
                              icon: Icons.skip_next_rounded,
                              height: 42,
                              color: AxisColors.warning,
                              borderColor: AxisColors.warning.withValues(alpha: 0.3),
                              onPressed: () => FocusSessionService().startFocus(),
                            ),
                          ),
                        AccentButton(
                          label: isRunning
                              ? (isAr ? 'إيقاف مؤقت' : 'Pause')
                              : (isBreak
                                  ? (isAr ? 'بدء الاستراحة' : 'Start Break')
                                  : (isAr ? 'بدء الجلسة' : 'Start Session')),
                          icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          height: 42,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          onPressed: () => FocusSessionService().toggleTimer(),
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: isAr ? '5 د' : '5m',
                          icon: Icons.add_rounded,
                          height: 42,
                          onPressed: () => FocusSessionService().addSeconds(300),
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: isAr ? 'إعادة تعيين' : 'Reset',
                          icon: Icons.replay_rounded,
                          height: 42,
                          onPressed: () => FocusSessionService().resetTimer(),
                        ),
                        const SizedBox(width: 8),
                        GhostButton(
                          label: isAr ? 'إنهاء' : 'Stop',
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
}

class _StepItem extends StatelessWidget {
  final String title;
  final bool isDone;
  final bool isActive;

  const _StepItem(this.title, {required this.isDone, required this.isActive});

  @override
  Widget build(BuildContext context) {
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
}

class _StepDivider extends StatelessWidget {
  const _StepDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: AxisColors.borderSubtle,
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

