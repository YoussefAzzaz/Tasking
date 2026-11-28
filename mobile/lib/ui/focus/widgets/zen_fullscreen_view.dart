import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/neural_sound_service.dart';
import 'package:axis/data/focus_session_service.dart';
import 'package:axis/ui/focus/widgets/neon_timer_dial.dart';

/// Zen Fullscreen Pomodoro View: 100% Distraction-free, hero timer takes the screen.
class ZenFullscreenView extends StatelessWidget {
  final bool isRunning;
  final bool isBreak;
  final int totalSeconds;
  final Task? attachedTask;
  final String selectedSoundscape;
  final NeuralSoundService soundService;
  final FocusSessionService sessionService;
  final VoidCallback onMinimize;
  final VoidCallback onOpenSetup;
  final VoidCallback onTaskTap;
  final VoidCallback onToggleTimer;
  final VoidCallback onAddFiveMinutes;
  final VoidCallback onToggleBreak;
  final VoidCallback onOpenSoundscapeModal;

  const ZenFullscreenView({
    super.key,
    required this.isRunning,
    required this.isBreak,
    required this.totalSeconds,
    required this.attachedTask,
    required this.selectedSoundscape,
    required this.soundService,
    required this.sessionService,
    required this.onMinimize,
    required this.onOpenSetup,
    required this.onTaskTap,
    required this.onToggleTimer,
    required this.onAddFiveMinutes,
    required this.onToggleBreak,
    required this.onOpenSoundscapeModal,
  });

  @override
  Widget build(BuildContext context) {
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
                  tooltip: context.isArabic
                      ? 'تصغير / خروج من التركيز'
                      : 'Minimize / Exit Focus',
                  // Root cause: arrow_back_rounded auto-mirrors in RTL; ternary flipped twice.
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: AxisColors.textHigh,
                  ),
                  onPressed: onMinimize,
                ),
                // Target Objective Pill
                Flexible(
                  child: InkWell(
                    onTap: onTaskTap,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: attachedTask != null
                              ? AxisColors.secondary.withValues(alpha: 0.4)
                              : AxisColors.borderPrimary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            attachedTask != null
                                ? Icons.radio_button_checked_rounded
                                : Icons.bolt_rounded,
                            size: 14,
                            color: isBreak ? AxisColors.warning : AxisColors.secondary,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              attachedTask?.title ??
                                  (isBreak
                                      ? (context.isArabic
                                          ? 'استراحة'
                                          : 'Reboot Break')
                                      : (context.isArabic
                                          ? 'دورة تركيز عميق'
                                          : 'Deep Work Cycle')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AxisColors.textHigh,
                              ),
                            ),
                          ),
                          if (attachedTask != null) ...[
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
                  tooltip: context.isArabic
                      ? 'عرض الإعدادات والإحصائيات'
                      : 'View Setup & Stats',
                  icon: const Icon(Icons.tune_rounded, color: AxisColors.textMuted),
                  onPressed: onOpenSetup,
                ),
              ],
            ),

            const Spacer(flex: 1),

            // Hero Fullscreen Pomodoro Timer Dial (Scoped ValueListenableBuilder)
            ValueListenableBuilder<int>(
              valueListenable: sessionService.remainingSecondsNotifier,
              builder: (context, remainingSec, _) {
                final progress = totalSeconds > 0
                    ? (totalSeconds - remainingSec) / totalSeconds
                    : 0.0;
                final minutes = remainingSec ~/ 60;
                final seconds = remainingSec % 60;
                final timeDisplay =
                    '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                return NeonTimerDial(
                  size: 290,
                  progress: progress,
                  timeDisplay: timeDisplay,
                  isBreak: isBreak,
                  isRunning: isRunning,
                );
              },
            ),

            const Spacer(flex: 1),

            // Hero Pause / Engage Button
            InkWell(
              onTap: onToggleTimer,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isRunning
                        ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                        : [AxisColors.primary, const Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: (isRunning ? AxisColors.warning : AxisColors.primary)
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
                      isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning
                          ? (context.isArabic
                              ? 'إيقاف مؤقت للتركيز'
                              : 'PAUSE DEEP SESSION')
                          : (context.isArabic
                              ? 'بدء جلسة التركيز العميق'
                              : 'ENGAGE DEEP SESSION'),
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
                    onPressed: onAddFiveMinutes,
                    icon: const Icon(Icons.add_alarm_rounded,
                        size: 16, color: AxisColors.secondary),
                    label: Text(
                      context.isArabic ? '+5 دقائق تركيز' : '+5 Min Focus',
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
                    onPressed: onToggleBreak,
                    icon: Icon(
                      isBreak ? Icons.play_arrow_rounded : Icons.coffee_rounded,
                      size: 16,
                      color: AxisColors.warning,
                    ),
                    label: Text(
                      isBreak
                          ? (context.isArabic ? 'إنهاء الاستراحة' : 'End Break')
                          : (context.isArabic ? 'أخذ استراحة' : 'Take Break'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Ambient Soundscape Floating Bar
            ValueListenableBuilder<bool>(
              valueListenable: soundService.isPlayingNotifier,
              builder: (context, isPlaying, _) {
                return InkWell(
                  onTap: onOpenSoundscapeModal,
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
                              Text(
                                context.isArabic
                                    ? 'خلفية صوتية'
                                    : 'AMBIENT SOUNDSCAPE',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AxisColors.textMuted,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Text(
                                context.l10n.localizedSoundscapeTitle(selectedSoundscape),
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
                          tooltip: isPlaying
                              ? (context.isArabic ? 'كتم الصوت' : 'Mute Sound')
                              : (context.isArabic ? 'تشغيل الصوت' : 'Play Sound'),
                          icon: Icon(
                            isPlaying
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: isPlaying ? AxisColors.secondary : AxisColors.textDim,
                          ),
                          onPressed: () => soundService.toggle(selectedSoundscape),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AxisColors.surfaceHigh,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AxisColors.borderSubtle),
                          ),
                          child: Text(
                            context.isArabic ? 'تغيير' : 'CHANGE',
                            style: const TextStyle(
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
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

