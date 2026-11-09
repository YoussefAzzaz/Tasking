import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/focus_session_service.dart';

/// Target task capsule display widget for the setup view.
class FocusTargetCapsule extends StatelessWidget {
  final Task? attachedTask;
  final VoidCallback onTap;
  final VoidCallback onPickTask;

  const FocusTargetCapsule({
    super.key,
    required this.attachedTask,
    required this.onTap,
    required this.onPickTask,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: attachedTask != null
                ? AxisColors.secondary.withValues(alpha: 0.4)
                : AxisColors.borderPrimary,
          ),
        ),
        child: Row(
          children: [
            Icon(
              attachedTask != null
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
                      Text(
                        isArabic ? 'الهدف المحدد' : 'TARGET OBJECTIVE',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AxisColors.textMuted,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (attachedTask != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          isArabic ? '• اضغط للوصف' : '• Tap for description',
                          style: const TextStyle(
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
                    attachedTask?.title ??
                        (isArabic
                            ? 'اضغط لربط مهمة...'
                            : 'Tap to attach a task...'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: attachedTask != null
                          ? AxisColors.textHigh
                          : AxisColors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (attachedTask != null)
              IconButton(
                tooltip: isArabic ? 'تغيير المهمة المستهدفة' : 'Change Target Task',
                icon: const Icon(Icons.swap_horiz_rounded, size: 18, color: AxisColors.textDim),
                onPressed: onPickTask,
              )
            else
              const Icon(Icons.unfold_more_rounded, size: 18, color: AxisColors.textDim),
          ],
        ),
      ),
    );
  }
}

/// Strip predicting XP yield for the active focus session.
class FocusYieldStrip extends StatelessWidget {
  const FocusYieldStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.card_giftcard_rounded, size: 15, color: AxisColors.tertiary),
              const SizedBox(width: 4),
              Text(
                isArabic ? 'العائد:' : 'Yield:',
                style: const TextStyle(fontSize: 11, color: AxisColors.textMuted),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isArabic ? '+75 أساسي' : '+75 Base',
                style: const TextStyle(
                  fontSize: 10,
                  color: AxisColors.tertiary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                isArabic ? '+38 تعزيز' : '+38 Boost',
                style: const TextStyle(
                  fontSize: 10,
                  color: AxisColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isArabic ? '113 نقطة' : '113 XP',
                  style: const TextStyle(
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
}

/// Primary engage button and auxiliary action buttons for the focus dashboard.
class FocusActionButtons extends StatelessWidget {
  final bool isRunning;
  final bool isBreak;
  final FocusSessionConfig config;
  final String? timeDisplay;
  final VoidCallback onReturnToFullscreen;
  final VoidCallback onToggleTimer;
  final VoidCallback onResetTimer;
  final VoidCallback onToggleBreak;

  const FocusActionButtons({
    super.key,
    required this.isRunning,
    required this.isBreak,
    required this.config,
    this.timeDisplay,
    required this.onReturnToFullscreen,
    required this.onToggleTimer,
    required this.onResetTimer,
    required this.onToggleBreak,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = context.isArabic;
    return Column(
      children: [
        if (isRunning) ...[
          // Primary Action: Return directly to Zen Fullscreen Pomodoro
          InkWell(
            onTap: onReturnToFullscreen,
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
                          ? (isArabic
                              ? 'العودة لملء الشاشة ($timeDisplay)'
                              : 'RETURN TO FULLSCREEN ($timeDisplay)')
                          : (isArabic
                              ? 'العودة لملء الشاشة'
                              : 'RETURN TO FULLSCREEN'),
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
            onPressed: onToggleTimer,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: Text(
              isArabic ? 'إيقاف مؤقت للجلسة' : 'PAUSE SESSION',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ] else ...[
          InkWell(
            onTap: onToggleTimer,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AxisColors.primary, Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AxisColors.primary.withValues(alpha: 0.4),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'بدء جلسة التركيز العميق' : 'ENGAGE DEEP SESSION',
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
        ],

        const SizedBox(height: 10),

        // Auxiliary Break & Reset Buttons
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
                onPressed: onToggleBreak,
                icon: Icon(
                  isBreak ? Icons.play_arrow_rounded : Icons.coffee_rounded,
                  size: 16,
                  color: isBreak ? AxisColors.secondary : AxisColors.warning,
                ),
                label: Text(
                  isBreak
                      ? (isArabic
                          ? '${config.focusMinutes} د تركيز عادي'
                          : '${config.focusMinutes}m Normal Focus')
                      : (isArabic
                          ? '${config.shortBreakMinutes} د استراحة'
                          : '${config.shortBreakMinutes}m Reboot Break'),
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
                onPressed: onResetTimer,
                icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AxisColors.secondary),
                label: Text(
                  isBreak
                      ? (isArabic ? 'إعادة ضبط الاستراحة' : 'Reset Break')
                      : (isArabic ? 'إعادة ضبط الجلسة' : 'Reset Quantum'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

