import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:axis/ui/me/mastery_badges_screen.dart';
import 'badge_detail_sheet.dart';
import 'mastery_badge_tile.dart';

export 'badge_detail_sheet.dart';
export 'mastery_badge_tile.dart';

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
    final inProgress =
        _allBadges.where((b) => !b.isUnlocked && b.progress > 0).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));
    final locked =
        _allBadges.where((b) => !b.isUnlocked && b.progress == 0).toList();

    final result = <MasteryBadgeData>[...unlocked, ...inProgress];
    if (result.length < 8) {
      result.addAll(locked.take(8 - result.length));
    }
    return result.take(12).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
                      isArabic ? 'أوسمة الإتقان' : 'MASTERY BADGES',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AxisColors.textMuted,
                            fontWeight: FontWeight.bold,
                            letterSpacing: isArabic ? 0.0 : 1.0,
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
            Material(
              color: Colors.transparent,
              child: InkWell(
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isArabic ? 'عرض الكل (50)' : 'See All (50)',
                        style: const TextStyle(
                          color: AxisColors.primarySoft,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        isArabic
                            ? Icons.arrow_back_ios_rounded
                            : Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: AxisColors.primarySoft,
                      ),
                    ],
                  ),
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
                    margin: const EdgeInsetsDirectional.only(end: 10),
                    child: MasteryBadgeTile(
                      badge: badge,
                      onTap: () => _showBadgeDetail(badge),
                    ),
                  );
                }),

                // "View All 50 Badges" Card at end of scroll
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _openBadgesScreen,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 105,
                      height: 122,
                      margin: const EdgeInsetsDirectional.only(end: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AxisColors.primary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.grid_view_rounded,
                            color: AxisColors.primarySoft,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isArabic ? 'عرض الكل' : 'View All',
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isArabic ? '← 50 شارة' : '50 Badges →',
                            style: const TextStyle(
                              color: AxisColors.primarySoft,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
