import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

/// Inspiring daily review card encouraging mindful reflections & journaling
class DailyReviewPromptCard extends StatelessWidget {
  const DailyReviewPromptCard({super.key, required this.onTapRecord});
  final VoidCallback onTapRecord;

  @override
  Widget build(BuildContext context) {
    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_rounded,
                      color: AxisColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'DAILY REVIEW PROMPT',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AxisColors.warning,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
              Text(
                DateFormat('d MMM').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 11,
                  color: AxisColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '"What single accomplishment will make today feel like a victory?"',
            style: TextStyle(
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap to record your energy & thoughts...',
                    style: TextStyle(color: AxisColors.textDim, fontSize: 12),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      size: 14, color: AxisColors.secondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
