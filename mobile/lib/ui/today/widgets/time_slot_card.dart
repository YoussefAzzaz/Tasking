import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Time slot row with left-accent rail for micro slots and scheduled gaps
class TimeSlotCard extends StatelessWidget {
  const TimeSlotCard({
    super.key,
    required this.time,
    required this.title,
    required this.xp,
    required this.isDone,
    required this.onToggle,
    this.onTap,
  });

  final String time;
  final String title;
  final int xp;
  final bool isDone;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const railColor = AxisColors.secondary;

    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: isDone
                    ? AxisColors.tertiary.withValues(alpha: 0.5)
                    : railColor,
                borderRadius: const BorderRadiusDirectional.only(
                  topStart: Radius.circular(8),
                  bottomStart: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                child: Row(
                  children: [
                    AxisCheckbox(
                      checked: isDone,
                      onChanged: onToggle,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  time,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AxisColors.secondary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AxisColors.secondary
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.isArabic ? 'ملائم 15 د' : 'FITTED 15M',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: AxisColors.secondary,
                                          fontSize: 9,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: isDone
                                        ? AxisColors.textDim
                                        : AxisColors.textHigh,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AxisColors.textDim,
                                    fontWeight: FontWeight.w500,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+$xp ${context.isArabic ? "نقطة" : "XP"}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AxisColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
