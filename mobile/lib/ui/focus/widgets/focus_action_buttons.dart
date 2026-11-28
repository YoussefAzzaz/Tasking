import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/focus_session_service.dart';

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
                  const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      timeDisplay != null
                          ? (isArabic ? 'العودة لملء الشاشة ($timeDisplay)' : 'RETURN TO FULLSCREEN ($timeDisplay)')
                          : (isArabic ? 'العودة لملء الشاشة' : 'RETURN TO FULLSCREEN'),
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
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AxisColors.warning,
              side: BorderSide(color: AxisColors.warning.withValues(alpha: 0.6), width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(double.infinity, 44),
            ),
            onPressed: onToggleTimer,
            icon: const Icon(Icons.pause_rounded, size: 18),
            label: Text(
              isArabic ? 'إيقاف مؤقت للجلسة' : 'PAUSE SESSION',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.1),
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
                  const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
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
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AxisColors.textHigh,
                  side: const BorderSide(color: AxisColors.borderSubtle),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      ? (isArabic ? '${config.focusMinutes} د تركيز عادي' : '${config.focusMinutes}m Normal Focus')
                      : (isArabic ? '${config.shortBreakMinutes} د استراحة' : '${config.shortBreakMinutes}m Reboot Break'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
