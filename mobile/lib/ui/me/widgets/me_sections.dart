import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:axis/ui/me/mastery_badges_screen.dart';

/// Single interactive mastery badge tile in the Me screen grid
class MasteryBadgeTile extends StatelessWidget {
  const MasteryBadgeTile({
    super.key,
    required this.badge,
    required this.onTap,
  });

  final MasteryBadgeData badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unlocked = badge.isUnlocked;
    final activeColor = unlocked ? badge.color : AxisColors.textDim;
    final currentTier = badge.currentTier;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: badge.color.withValues(alpha: 0.2),
        highlightColor: badge.color.withValues(alpha: 0.1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: unlocked
                ? AxisColors.surfaceHigh.withValues(alpha: 0.55)
                : AxisColors.surfaceLowest.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: unlocked
                  ? badge.color.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.05),
              width: 1,
            ),
            boxShadow: unlocked
                ? [
                    BoxShadow(
                      color: badge.color.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge Icon with glowing background if unlocked
              Stack(
                alignment: Alignment.center,
                children: [
                  if (unlocked)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: badge.color.withValues(alpha: 0.15),
                      ),
                    ),
                  Icon(
                    badge.icon,
                    color: activeColor,
                    size: 24,
                  ),
                ],
              ),

              // Title and Tier Label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    badge.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unlocked ? AxisColors.textHigh : AxisColors.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    unlocked
                        ? 'T${currentTier?.tierNumber ?? 1} • ${currentTier?.name ?? "Unlocked"}'
                        : 'Locked',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unlocked
                          ? badge.color.withValues(alpha: 0.9)
                          : AxisColors.textDim,
                      fontWeight: FontWeight.w500,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),

              // Mini Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 3,
                  width: double.infinity,
                  color: AxisColors.surfaceLowest,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: badge.progress.clamp(0.05, 1.0),
                    child: Container(
                      color: unlocked
                          ? badge.color
                          : AxisColors.textDim.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic Mastery Badges Section with live metrics and interactive bottom sheet details
class MasteryBadgesSection extends StatefulWidget {
  const MasteryBadgesSection({super.key});

  @override
  State<MasteryBadgesSection> createState() => _MasteryBadgesSectionState();
}

class _MasteryBadgesSectionState extends State<MasteryBadgesSection> {
  List<MasteryBadgeData> _allBadges = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final repo = MasteryBadgeRepository();
    final list = await repo.getMasteryBadges();
    if (mounted) {
      setState(() {
        _allBadges = list;
        _loading = false;
      });
    }
  }

  void _showBadgeDetail(MasteryBadgeData badge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BadgeDetailSheet(badge: badge),
    );
  }

  void _openBadgesScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MasteryBadgesScreen(),
      ),
    );
  }

  /// Curates the badges shown in the Me screen horizontal carousel:
  /// Prioritizes unlocked badges, then active in-progress badges, filling up to 8-10 cards.
  List<MasteryBadgeData> get _carouselBadges {
    final unlocked = _allBadges.where((b) => b.isUnlocked).toList();
    final inProgress = _allBadges.where((b) => !b.isUnlocked && b.progress > 0).toList()
      ..sort((a, b) => b.progress.compareTo(a.progress));
    final locked = _allBadges.where((b) => !b.isUnlocked && b.progress == 0).toList();

    final result = <MasteryBadgeData>[...unlocked, ...inProgress];
    if (result.length < 8) {
      result.addAll(locked.take(8 - result.length));
    }
    return result.take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = _allBadges.where((b) => b.isUnlocked).length;
    final carouselItems = _carouselBadges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header with Unlocked Counter & "See More" Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      'MASTERY BADGES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AxisColors.textMuted,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _loading
                          ? '...'
                          : '$unlockedCount / ${_allBadges.length}',
                      style: const TextStyle(
                        color: AxisColors.primarySoft,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _openBadgesScreen,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AxisColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See All (50)',
                      style: TextStyle(
                        color: AxisColors.primarySoft,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: AxisColors.primarySoft,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (_loading)
          const SizedBox(
            height: 125,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AxisColors.primary,
              ),
            ),
          )
        else ...[
          // Horizontal Scroll Carousel of Curated / Top Badges
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                ...carouselItems.map((badge) {
                  return Container(
                    width: 105,
                    height: 122,
                    margin: const EdgeInsets.only(right: 10),
                    child: MasteryBadgeTile(
                      badge: badge,
                      onTap: () => _showBadgeDetail(badge),
                    ),
                  );
                }),

                // "View All 50 Badges" Card at end of scroll
                InkWell(
                  onTap: _openBadgesScreen,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 105,
                    height: 122,
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AxisColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.grid_view_rounded,
                          color: AxisColors.primarySoft,
                          size: 24,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'View All',
                          style: TextStyle(
                            color: AxisColors.textHigh,
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '50 Badges →',
                          style: TextStyle(
                            color: AxisColors.primarySoft,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Detailed bottom modal sheet presenting badge progression and milestones
class BadgeDetailSheet extends StatelessWidget {
  const BadgeDetailSheet({super.key, required this.badge});

  final MasteryBadgeData badge;

  @override
  Widget build(BuildContext context) {
    final unlocked = badge.isUnlocked;
    final currentTier = badge.currentTier;
    final nextTier = badge.nextTier;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AxisColors.surfaceLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AxisColors.borderSubtle),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AxisColors.textDim.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Central Badge Shield Aura
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: badge.color.withValues(alpha: unlocked ? 0.18 : 0.08),
                    border: Border.all(
                      color: badge.color.withValues(alpha: unlocked ? 0.45 : 0.2),
                      width: 1.5,
                    ),
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: badge.color.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    badge.icon,
                    color: unlocked ? badge.color : AxisColors.textDim,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title & Category
              Center(
                child: Column(
                  children: [
                    Text(
                      badge.title,
                      style: const TextStyle(
                        color: AxisColors.textHigh,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (badge.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        badge.subtitle,
                        style: const TextStyle(
                          color: AxisColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge.category.toUpperCase(),
                        style: TextStyle(
                          color: badge.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Current Rank & Progress Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AxisColors.surface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            unlocked
                                ? 'Current Rank: ${currentTier?.name} (Tier ${currentTier?.tierNumber})'
                                : 'Status: Locked (No Tier Achieved)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unlocked ? AxisColors.textHigh : AxisColors.textMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(badge.progress * 100).toInt()}%',
                          style: TextStyle(
                            color: badge.color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: badge.progress,
                        minHeight: 6,
                        backgroundColor: AxisColors.surfaceHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(badge.color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextTier != null
                          ? 'Progress: ${badge.currentValue} / ${nextTier.targetValue} ${nextTier.unit} to reach Tier ${nextTier.tierNumber} (${nextTier.name})'
                          : 'All tiers completed! You have reached maximum mastery.',
                      style: const TextStyle(
                        color: AxisColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Tiers Roadmap
              const Text(
                'TIER ROADMAP',
                style: TextStyle(
                  color: AxisColors.textDim,
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 8),

              ...badge.tiers.map((tier) {
                final isAchieved = badge.currentValue >= tier.targetValue;
                final isCurrent = currentTier?.tierNumber == tier.tierNumber;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? badge.color.withValues(alpha: 0.10)
                          : AxisColors.surface.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent
                            ? badge.color.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAchieved
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 16,
                          color: isAchieved ? badge.color : AxisColors.textDim,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    'Tier ${tier.tierNumber} — ${tier.name}',
                                    style: TextStyle(
                                      color: isAchieved
                                          ? AxisColors.textHigh
                                          : AxisColors.textMuted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(${tier.targetValue} ${tier.unit})',
                                    style: const TextStyle(
                                      color: AxisColors.textDim,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tier.description,
                                style: const TextStyle(
                                  color: AxisColors.textMuted,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
