import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gamification Status Banner & XP HUD
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(16),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Glow ambiance (simulated via positioned blurred containers)
                  Positioned(
                    top: -40, right: -40,
                    child: Container(
                      width: 140, height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AxisColors.primary.withOpacity(0.2),
                        boxShadow: [
                          BoxShadow(color: AxisColors.primary.withOpacity(0.2), blurRadius: 40, spreadRadius: 20)
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30, left: -30,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AxisColors.secondary.withOpacity(0.15),
                        boxShadow: [
                          BoxShadow(color: AxisColors.secondary.withOpacity(0.15), blurRadius: 40, spreadRadius: 20)
                        ],
                      ),
                    ),
                  ),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                  color: AxisColors.surfaceLow,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AxisColors.borderSubtle),
                                ),
                                child: const Icon(Icons.terminal_rounded, color: AxisColors.primary),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Lv 14', style: Theme.of(context).textTheme.displaySmall),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AxisColors.secondary.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('CYBER KINETIC', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.secondarySoft)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text('+60 XP ', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.success)),
                                      Text('earned today', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AxisColors.textMuted)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const StreakBadge(days: 18, isActive: true),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bolt_rounded, color: AxisColors.primary, size: 14),
                              const SizedBox(width: 4),
                              Text('2,840 / 3,500 XP', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.textMuted)),
                            ],
                          ),
                          Text('81% to Lv 15', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.secondary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const XpBar(progress: 0.81, height: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Local-First Status Indicator Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          color: AxisColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: AxisColors.success.withOpacity(0.6), blurRadius: 6)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('OFFLINE READY • 0MS LATENCY', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, color: AxisColors.secondary, size: 16),
                      const SizedBox(width: 4),
                      Text('Instant Sync', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.secondary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Smart 15-Min Auto-Scheduler Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: AxisColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Text('15M MICRO SLOTS', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AxisColors.textHigh)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AxisColors.secondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_fix_high_rounded, color: AxisColors.secondary, size: 14),
                      const SizedBox(width: 4),
                      Text('RESCHEDULE GAPS', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.secondary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // AI Insight Banner
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: AxisColors.secondary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.psychology_rounded, color: AxisColors.secondary, size: 18),
                            ),
                            const SizedBox(width: 8),
                            RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AxisColors.textHigh),
                                children: [
                                  const TextSpan(text: 'Auto-Scheduler slotted '),
                                  TextSpan(text: '3 micro-tasks', style: TextStyle(color: AxisColors.secondary, fontWeight: FontWeight.bold)),
                                  const TextSpan(text: ' into idle gaps.'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AxisColors.success.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('OPTIMIZED', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.successBright, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Slots
                  _TimeSlotRow(time: '09:30 - 09:45 AM', type: 'fitted', title: 'Review PRs', isDone: true),
                  const SizedBox(height: 8),
                  _TimeSlotRow(time: '09:45 - 10:00 AM', type: 'focus', title: 'Deep Work Session', isDone: false, isCurrent: true),
                  const SizedBox(height: 8),
                  _TimeSlotRow(time: '10:00 - 10:15 AM', type: 'fitted', title: 'Emails', isDone: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSlotRow extends StatelessWidget {
  const _TimeSlotRow({required this.time, required this.type, required this.title, required this.isDone, this.isCurrent = false});
  final String time;
  final String type;
  final String title;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCurrent ? AxisColors.surfaceHigh : AxisColors.surfaceHigh.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: isCurrent ? Border.all(color: AxisColors.primary.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          AxisCheckbox(checked: isDone, onChanged: (v) {}),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(time, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textMuted)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: type == 'fitted' ? AxisColors.secondary.withOpacity(0.2) : AxisColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(type == 'fitted' ? 'FITTED 15M' : 'FOCUS BLOCK', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: type == 'fitted' ? AxisColors.secondary : AxisColors.primarySoft)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isDone ? AxisColors.textDim : AxisColors.textHigh,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                )),
              ],
            ),
          ),
          if (isCurrent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AxisColors.primary,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: AxisColors.primary.withOpacity(0.4), blurRadius: 8)],
              ),
              child: Text('NOW', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
