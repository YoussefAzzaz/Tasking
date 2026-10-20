import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

/// Single mastery badge icon and label
class MasteryBadge extends StatelessWidget {
  const MasteryBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AxisColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Mastery badges 4-column grid section
class MasteryBadgesSection extends StatelessWidget {
  const MasteryBadgesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'MASTERY BADGES',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AxisColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: const [
            MasteryBadge(
              icon: Icons.local_fire_department_rounded,
              color: AxisColors.success,
              label: 'Streak',
            ),
            MasteryBadge(
              icon: Icons.edit_note_rounded,
              color: AxisColors.primary,
              label: 'Writer',
            ),
            MasteryBadge(
              icon: Icons.task_alt_rounded,
              color: AxisColors.success,
              label: 'Closer',
            ),
            MasteryBadge(
              icon: Icons.access_time_filled_rounded,
              color: AxisColors.secondary,
              label: 'Focus',
            ),
          ],
        ),
      ],
    );
  }
}

/// Data management card providing full wipe / reset data action with confirmation dialog
class DataManagementSection extends StatelessWidget {
  const DataManagementSection({super.key, required this.onResetData});

  final VoidCallback onResetData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'DATA MANAGEMENT',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AxisColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onResetData,
          child: AxisCard(
            tier: GlassTier.two,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AxisColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_sweep_rounded,
                    color: AxisColors.error,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset App to Clean State',
                        style: TextStyle(
                          color: AxisColors.textHigh,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Wipe all local tasks, projects, habits & XP',
                        style: TextStyle(
                          color: AxisColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AxisColors.textDim,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// About Axis OS Branding card
class AxisBrandingCard extends StatelessWidget {
  const AxisBrandingCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AxisCard(
      tier: GlassTier.two,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AxisColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'AXIS OS',
                      style: TextStyle(
                        color: AxisColors.textHigh,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AxisColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: AxisColors.primary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'v1.0.0',
                        style: TextStyle(
                          color: AxisColors.primarySoft,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'The Kinetic Productivity & Flow OS',
                  style: TextStyle(color: AxisColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
