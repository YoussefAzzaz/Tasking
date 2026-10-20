import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

/// Weekly Day Pill showing completed, current day, missed, or upcoming state
class DayPill extends StatelessWidget {
  const DayPill({super.key, required this.day, required this.state});
  final String day;
  final String state; // done, today, missed, upcoming

  @override
  Widget build(BuildContext context) {
    Color labelColor = AxisColors.textMuted;
    Color boxColor = AxisColors.canvasBase;
    Widget child = const SizedBox();

    if (state == 'done') {
      labelColor = AxisColors.success;
      boxColor = AxisColors.success.withValues(alpha: 0.15);
      child =
          const Icon(Icons.check_rounded, color: AxisColors.success, size: 14);
    } else if (state == 'today') {
      labelColor = AxisColors.primary;
      boxColor = AxisColors.primary.withValues(alpha: 0.12);
      child = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: AxisColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AxisColors.primary.withValues(alpha: 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      );
    } else if (state == 'missed') {
      labelColor = AxisColors.textDim;
      boxColor = AxisColors.surfaceLow.withValues(alpha: 0.3);
      child = const Icon(Icons.remove_rounded,
          color: AxisColors.textDim, size: 12);
    } else if (state == 'upcoming') {
      labelColor = AxisColors.textDim;
      boxColor = AxisColors.canvasBase;
      child = Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: AxisColors.borderSubtle,
          shape: BoxShape.circle,
        ),
      );
    }

    return Column(
      children: [
        Text(
          day,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: labelColor,
                fontWeight: state == 'today' || state == 'done'
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: state == 'done'
                  ? AxisColors.success.withValues(alpha: 0.4)
                  : (state == 'today'
                      ? AxisColors.primary.withValues(alpha: 0.5)
                      : AxisColors.borderSubtle.withValues(alpha: 0.4)),
            ),
            boxShadow: state == 'done'
                ? [
                    BoxShadow(
                      color: AxisColors.success.withValues(alpha: 0.3),
                      blurRadius: 8,
                    )
                  ]
                : (state == 'today'
                    ? [
                        BoxShadow(
                          color: AxisColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                        )
                      ]
                    : null),
          ),
          child: Center(child: child),
        ),
      ],
    );
  }
}

/// Streak & Continuity Pulse Hero displaying multiplier, completion rate, current unbroken run, and week matrix
class HabitContinuityCard extends StatelessWidget {
  const HabitContinuityCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
    required this.multiplierStr,
    required this.monthlyRate,
    required this.weekDayWidgets,
    required this.onResetStreak,
  });

  final int currentStreak;
  final int bestStreak;
  final String multiplierStr;
  final int monthlyRate;
  final List<Widget> weekDayWidgets;
  final VoidCallback onResetStreak;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Streak Status Summary Pill Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: AxisColors.surfaceLow, blurRadius: 4)
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AxisColors.success, size: 16),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'MULTIPLIER $multiplierStr',
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AxisColors.success,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: AxisColors.surfaceLow, blurRadius: 4)
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AxisColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '$monthlyRate% MONTHLY RATE',
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AxisColors.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // STREAK HERO COCKPIT CARD
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AxisCard(
            tier: GlassTier.two,
            padding: const EdgeInsets.all(16),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: -40,
                  right: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AxisColors.success.withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                          color: AxisColors.success.withValues(alpha: 0.1),
                          blurRadius: 40,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CONTINUITY PULSE',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AxisColors.textMuted),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$currentStreak',
                                      style: Theme.of(context)
                                          .textTheme
                                          .displayMedium
                                          ?.copyWith(
                                            color: AxisColors.textHigh,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      currentStreak == 1 ? 'Day' : 'Days',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: AxisColors.success,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      color: currentStreak > 0
                                          ? AxisColors.success
                                          : AxisColors.textDim,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                currentStreak == 0
                                    ? 'Start your streak today 🔥'
                                    : 'Current Best: $bestStreak ${bestStreak == 1 ? 'Day' : 'Days'} Unbroken 🔥',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AxisColors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Reset Streak Action Button
                        InkWell(
                          onTap: onResetStreak,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AxisColors.surfaceLow,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: AxisColors.borderSubtle),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.restart_alt_rounded,
                                    color: AxisColors.warning, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AxisColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Weekly Streak Matrix
                    Row(
                      children: weekDayWidgets,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
