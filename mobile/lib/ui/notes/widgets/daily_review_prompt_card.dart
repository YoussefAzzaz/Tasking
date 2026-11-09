import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Inspiring daily review card encouraging mindful reflections & journaling
class DailyReviewPromptCard extends StatelessWidget {
  const DailyReviewPromptCard({super.key, required this.onTapRecord});
  final VoidCallback onTapRecord;

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.wb_sunny_rounded,
                        color: AxisColors.warning, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isAr ? 'سؤال المراجعة اليومية' : 'DAILY REVIEW PROMPT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AxisColors.warning,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                context.formatDate(DateTime.now(), 'd MMM'),
                style: const TextStyle(
                  fontSize: 11,
                  color: AxisColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isAr
                ? '"ما هو الإنجاز الوحيد الذي سيجعل اليوم يبدو كانتصار حقيقي؟"'
                : '"What single accomplishment will make today feel like a victory?"',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: AxisColors.textHigh,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onTapRecord,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isAr
                          ? 'انقر لتسجيل طاقتك وأفكارك...'
                          : 'Tap to record your energy & thoughts...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isAr ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                    size: 14,
                    color: AxisColors.secondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
