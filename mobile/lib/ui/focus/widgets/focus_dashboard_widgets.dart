import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/task_repository.dart';
import 'package:axis/data/focus_session_service.dart';

export 'focus_action_buttons.dart';

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
    // Root cause: yield labels were hardcoded (+75 Base / +38 Boost / 113 XP) regardless
    // of the configured focus duration. Compute live from FocusSessionService config.
    return ValueListenableBuilder<FocusSessionConfig>(
      valueListenable: FocusSessionService().configNotifier,
      builder: (context, config, _) {
        final breakdown = FocusYieldBreakdown.fromMinutes(config.focusMinutes);
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
                    isArabic ? '+${breakdown.baseXp} أساسي' : '+${breakdown.baseXp} Base',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AxisColors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isArabic ? '+${breakdown.boostXp} تعزيز' : '+${breakdown.boostXp} Boost',
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
                      isArabic ? '${breakdown.totalXp} نقطة' : '${breakdown.totalXp} XP',
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
      },
    );
  }
}

