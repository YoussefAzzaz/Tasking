import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // User Profile Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AxisColors.primary.withOpacity(0.2),
                      border: Border.all(color: AxisColors.primary, width: 2),
                    ),
                    child: const Icon(Icons.person_rounded, color: AxisColors.primary, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CYBER KINETIC', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AxisColors.textHigh, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: AxisColors.secondary, size: 16),
                            const SizedBox(width: 4),
                            Text('Level 14', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.secondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('MASTERY BADGES', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _Badge(icon: Icons.local_fire_department_rounded, color: AxisColors.tertiary, label: 'Streak'),
                _Badge(icon: Icons.edit_note_rounded, color: AxisColors.primary, label: 'Writer'),
                _Badge(icon: Icons.task_alt_rounded, color: AxisColors.success, label: 'Closer'),
                _Badge(icon: Icons.access_time_filled_rounded, color: AxisColors.secondary, label: 'Focus'),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('SYSTEM STATUS', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AxisColors.textMuted, fontWeight: FontWeight.bold)),
          ),
          
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AxisCard(
              tier: GlassTier.two,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync_rounded, color: AxisColors.secondary),
                      const SizedBox(width: 12),
                      Text('PowerSync', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AxisColors.textHigh)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: AxisColors.secondary, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('OFFLINE (SYNCING)', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.textHigh)),
                      ],
                    ),
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

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AxisColors.textMuted)),
        ],
      ),
    );
  }
}
