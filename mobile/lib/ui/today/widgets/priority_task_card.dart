import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Priority Matrix task card with glowing priority badge, estimate pill, and XP label
class PriorityTaskCard extends StatelessWidget {
  const PriorityTaskCard({
    super.key,
    required this.priority,
    required this.badge,
    required this.estimate,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.xp,
    required this.isDone,
    required this.onToggle,
    this.onTap,
  });

  final int priority;
  final String badge;
  final String estimate;
  final String tag;
  final String title;
  final String subtitle;
  final int xp;
  final bool isDone;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badgeColor = priority == 1
        ? AxisColors.error
        : (priority == 2 ? AxisColors.warning : AxisColors.primary);
    final badgeBg = priority == 1
        ? const Color(0x2993000A)
        : (priority == 2
            ? AxisColors.warning.withValues(alpha: 0.15)
            : AxisColors.primary.withValues(alpha: 0.14));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AxisCard(
        tier: GlassTier.one,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AxisCheckbox(
                checked: isDone,
                onChanged: onToggle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: priority == 1
                              ? [
                                  BoxShadow(
                                    color: AxisColors.error
                                        .withValues(alpha: 0.15),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          badge,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: badgeColor,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AxisColors.surfaceHighest,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          estimate,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AxisColors.secondary,
                              ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AxisColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          tag,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AxisColors.primarySoft,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                          decorationColor: AxisColors.textDim,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AxisColors.textMuted,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.primarySoft.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '+$xp ${context.isArabic ? "نقطة" : "XP"}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AxisColors.primarySoft,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
