import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

class HabitsScreen extends StatelessWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Streak Status Summary Pill Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AxisColors.surfaceLow, blurRadius: 4)],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: AxisColors.tertiary, size: 16),
                      const SizedBox(width: 4),
                      Text('MULTIPLIER 1.8X', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.tertiary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AxisColors.surfaceHigh.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AxisColors.surfaceLow, blurRadius: 4)],
                  ),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AxisColors.secondary, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('94% MONTHLY RATE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.secondary, fontWeight: FontWeight.bold)),
                    ],
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
                    top: -40, right: -40,
                    child: Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: AxisColors.tertiary.withOpacity(0.1), boxShadow: [BoxShadow(color: AxisColors.tertiary.withOpacity(0.1), blurRadius: 40, spreadRadius: 20)]),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('CONTINUITY PULSE', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.textMuted)),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text('18', style: Theme.of(context).textTheme.displayMedium?.copyWith(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  Text('Days', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AxisColors.tertiary, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.local_fire_department_rounded, color: AxisColors.tertiary, size: 20),
                                ],
                              ),
                              Text('Current Best: 18 Days Unbroken 🔥', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AxisColors.textMuted)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: AxisColors.surfaceLow, borderRadius: BorderRadius.circular(20)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.shield_rounded, color: AxisColors.secondary, size: 14),
                                    const SizedBox(width: 4),
                                    Text('1 Active', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.secondary, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Saved streak 3d ago', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.borderSubtle)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Weekly Streak Matrix
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _DayPill(day: 'M', state: 'done'),
                          _DayPill(day: 'T', state: 'done'),
                          _DayPill(day: 'W', state: 'done'),
                          _DayPill(day: 'T', state: 'shield'),
                          _DayPill(day: 'F', state: 'done'),
                          _DayPill(day: 'S', state: 'today'),
                          _DayPill(day: 'S', state: 'upcoming'),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // HABIT LIST
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AxisColors.textMuted, size: 16),
                const SizedBox(width: 8),
                Text('DAILY ROUTINES', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textMuted, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _HabitCard(title: 'Morning Workout', time: '07:00 AM', xp: 20, isDone: true),
                const SizedBox(height: 8),
                _HabitCard(title: 'Read 20 Pages', time: '09:00 PM', xp: 15, isDone: false),
                const SizedBox(height: 8),
                _HabitCard(title: 'Meditate', time: '10:00 PM', xp: 10, isDone: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.state});
  final String day;
  final String state; // done, shield, today, upcoming

  @override
  Widget build(BuildContext context) {
    Color labelColor = AxisColors.textMuted;
    Color boxColor = AxisColors.surfaceLowest;
    Widget child = const SizedBox();

    if (state == 'done') {
      child = const Icon(Icons.check_rounded, color: AxisColors.tertiary, size: 14);
      boxColor = AxisColors.surfaceLowest;
    } else if (state == 'shield') {
      labelColor = AxisColors.secondary;
      child = const Icon(Icons.shield_rounded, color: AxisColors.secondary, size: 14);
    } else if (state == 'today') {
      labelColor = AxisColors.primary;
      boxColor = AxisColors.surfaceLow;
      child = const Icon(Icons.check_rounded, color: AxisColors.tertiary, size: 14);
    } else if (state == 'upcoming') {
      child = Container(width: 6, height: 6, decoration: BoxDecoration(color: AxisColors.borderSubtle, shape: BoxShape.circle));
    }

    return Column(
      children: [
        Text(day, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: labelColor, fontWeight: state == 'today' || state == 'done' ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(height: 4),
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: state == 'today' ? [BoxShadow(color: AxisColors.tertiary.withOpacity(0.5), blurRadius: 16)] : null,
          ),
          child: Center(child: child),
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.title, required this.time, required this.xp, required this.isDone});
  final String title;
  final String time;
  final int xp;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AxisCheckbox(checked: isDone, onChanged: (v) {}),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                )),
                const SizedBox(height: 2),
                Text(time, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AxisColors.tertiary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('+$xp XP', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.tertiary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
