import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Celebration dialog shown upon completing a focus block or reboot break.
class FocusCompletionDialog extends StatelessWidget {
  final int xp;
  final VoidCallback onLaunchFocus;
  final VoidCallback onTakeBreak;

  const FocusCompletionDialog({
    super.key,
    required this.xp,
    required this.onLaunchFocus,
    required this.onTakeBreak,
  });

  static void show({
    required BuildContext context,
    required int xp,
    required VoidCallback onLaunchFocus,
    required VoidCallback onTakeBreak,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => FocusCompletionDialog(
        xp: xp,
        onLaunchFocus: onLaunchFocus,
        onTakeBreak: onTakeBreak,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool wasBreak = xp < 0;
    final isArabic = context.isArabic;

    return AlertDialog(
      backgroundColor: AxisColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(
            wasBreak ? Icons.alarm_on_rounded : Icons.stars_rounded,
            color: wasBreak ? AxisColors.secondary : AxisColors.tertiary,
            size: 28,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              wasBreak
                  ? (isArabic ? 'اكتملت الاستراحة!' : 'Reboot Break Complete!')
                  : (isArabic ? 'اكتملت جلسة التركيز العميق!' : 'Deep Session Complete!'),
              style: const TextStyle(color: AxisColors.textHigh, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            wasBreak
                ? (isArabic
                    ? 'تمت استعادة طاقتك وتجديد نشاطك الذهني. هل أنت مستعد لبدء جولة تركيز جديدة؟'
                    : 'Energy restored and cognitive reserves replenished. Ready to initiate next focus sprint?')
                : (isArabic
                    ? 'انتهت دورة التركيز بنجاح واستمرارية مثالية.'
                    : 'Quantum focus cycle finished with optimal continuity.'),
            style: const TextStyle(color: AxisColors.textMuted),
          ),
          if (!wasBreak) ...[
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
                  Expanded(
                    child: Text(
                      isArabic
                          ? '+$xp نقطة خبرة أُضيفت إلى رصيدك'
                          : '+$xp XP Added to Cockpit',
                      style: const TextStyle(
                        color: AxisColors.tertiary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            isArabic ? 'إغلاق' : 'Dismiss',
            style: const TextStyle(color: AxisColors.secondary),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                wasBreak ? AxisColors.secondary : AxisColors.tertiary,
            foregroundColor: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
            if (wasBreak) {
              onLaunchFocus();
            } else {
              onTakeBreak();
            }
          },
          child: Text(
            wasBreak
                ? (isArabic ? 'بدء جلسة تركيز' : 'Launch Focus Session')
                : (isArabic ? 'أخذ استراحة' : 'Take Reboot Break'),
          ),
        ),
      ],
    );
  }
}

