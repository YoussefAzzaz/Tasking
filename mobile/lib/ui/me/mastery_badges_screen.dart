import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/mastery_badge_repository.dart';
import 'package:axis/ui/me/widgets/me_sections.dart';

/// Full-screen dedicated Mastery Badges showroom & trophy room.
/// Presents all 50 badges with live search, category filtering, unlocked toggle,
/// and detailed tier roadmaps.
class MasteryBadgesScreen extends StatefulWidget {
  const MasteryBadgesScreen({super.key});

  @override
  State<MasteryBadgesScreen> createState() => _MasteryBadgesScreenState();
}

class _MasteryBadgesScreenState extends State<MasteryBadgesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<MasteryBadgeData> _allBadges = [];
  BadgeCategory _selectedCategory = BadgeCategory.all;
  bool _unlockedOnly = false;
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
    _searchCtrl.addListener(() {
      setState(() {
        _searchQuery = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    final list = await MasteryBadgeRepository().getMasteryBadges();
    if (mounted) {
      setState(() {
        _allBadges = list;
        _loading = false;
      });
    }
  }

  void _showBadgeDetail(MasteryBadgeData badge) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BadgeDetailSheet(badge: badge),
    );
  }

  List<MasteryBadgeData> get _filteredBadges {
    return _allBadges.where((badge) {
      // 1. Category filter
      if (_selectedCategory != BadgeCategory.all &&
          badge.categoryEnum != _selectedCategory) {
        return false;
      }
      // 2. Unlocked filter
      if (_unlockedOnly && !badge.isUnlocked) {
        return false;
      }
      // 3. Search filter (supports both English and Arabic search)
      if (_searchQuery.isNotEmpty) {
        final titleMatches = badge.title.toLowerCase().contains(_searchQuery) ||
            badge.localizedTitle(true).toLowerCase().contains(_searchQuery);
        final subtitleMatches =
            badge.subtitle.toLowerCase().contains(_searchQuery) ||
            badge.localizedSubtitle(true).toLowerCase().contains(_searchQuery);
        final catMatches = badge.category.toLowerCase().contains(_searchQuery) ||
            badge.categoryEnum.localizedLabel(true).toLowerCase().contains(_searchQuery);
        if (!titleMatches && !subtitleMatches && !catMatches) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocalizations.of(context).isArabic;
    final unlockedCount = _allBadges.where((b) => b.isUnlocked).length;
    final totalBadges = _allBadges.length;
    final overallProgress =
        totalBadges > 0 ? (unlockedCount / totalBadges) : 0.0;
    final filtered = _filteredBadges;

    return Scaffold(
      backgroundColor: AxisColors.canvasBase,
      appBar: AppBar(
        backgroundColor: AxisColors.canvasBase.withValues(alpha: 0.90),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            isArabic
                ? Icons.arrow_forward_ios_rounded
                : Icons.arrow_back_ios_new_rounded,
            color: AxisColors.textHigh,
            size: 18,
          ),
          tooltip: isArabic ? 'رجوع' : 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isArabic ? 'شارات الإتقان' : 'Mastery Badges',
          style: const TextStyle(
            color: AxisColors.textHigh,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          // Filter by Unlocked Only toggle button
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _unlockedOnly = !_unlockedOnly;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _unlockedOnly
                      ? AxisColors.primary.withValues(alpha: 0.2)
                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _unlockedOnly
                        ? AxisColors.primarySoft
                        : AxisColors.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _unlockedOnly
                          ? Icons.lock_open_rounded
                          : Icons.lock_outline_rounded,
                      size: 13,
                      color: _unlockedOnly
                          ? AxisColors.primarySoft
                          : AxisColors.textDim,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _unlockedOnly
                          ? (isArabic ? 'المفتوحة' : 'Unlocked')
                          : (isArabic ? 'كل الحالات' : 'All State'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _unlockedOnly
                            ? AxisColors.primarySoft
                            : AxisColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AxisColors.borderSubtle, height: 1),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AxisColors.primary,
                strokeWidth: 2,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Mastery Overview Cockpit Card
                  AxisCard(
                    tier: GlassTier.two,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'معرض الجوائز' : 'TROPHY SHOWROOM',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AxisColors.textMuted,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '$unlockedCount',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AxisColors.textHigh,
                                        ),
                                      ),
                                      Flexible(
                                        child: Text(
                                          isArabic ? ' / $totalBadges مفتوحة' : ' / $totalBadges Unlocked',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: AxisColors.textDim,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AxisColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AxisColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                isArabic ? '${(overallProgress * 100).toInt()}% مكتمل' : '${(overallProgress * 100).toInt()}% Done',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AxisColors.primarySoft,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: overallProgress,
                            minHeight: 6,
                            backgroundColor: AxisColors.surfaceLowest,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AxisColors.primarySoft),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. Search Input Field
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AxisColors.borderSubtle),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: AxisColors.textHigh, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: isArabic
                            ? 'البحث في 50 شارة بالاسم أو التصنيف...'
                            : 'Search 50 badges by name or category...',
                        hintStyle: const TextStyle(
                            color: AxisColors.textDim, fontSize: 12.5),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 18, color: AxisColors.textDim),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded,
                                    size: 16, color: AxisColors.textDim),
                                onPressed: () => _searchCtrl.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. Category Filter Pills
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: BadgeCategory.values.map((category) {
                        final isSelected = _selectedCategory == category;
                        final count = category == BadgeCategory.all
                            ? _allBadges.length
                            : _allBadges
                                .where((b) => b.categoryEnum == category)
                                .length;

                        return Padding(
                          padding: const EdgeInsetsDirectional.only(end: 6),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedCategory = category;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? category.color.withValues(alpha: 0.20)
                                    : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? category.color.withValues(alpha: 0.55)
                                      : Colors.white.withValues(alpha: 0.05),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    category.icon,
                                    size: 13,
                                    color: isSelected
                                        ? category.color
                                        : AxisColors.textDim,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${category.localizedLabel(isArabic)} ($count)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AxisColors.textHigh
                                          : AxisColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. Badges Grid
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceHigh.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AxisColors.borderSubtle),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_rounded,
                              size: 40, color: AxisColors.textDim),
                          const SizedBox(height: 12),
                          Text(
                            isArabic ? 'لم يتم العثور على شارات مطابقة' : 'No matching badges found',
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _unlockedOnly
                                ? (isArabic
                                    ? 'لا توجد شارات مفتوحة تطابق هذا البحث. جرب عرض كافة الشارات.'
                                    : 'No unlocked badges match this filter. Try viewing all badges.')
                                : (isArabic
                                    ? 'جرب البحث بكلمة مفتاحية أو تصنيف مختلف.'
                                    : 'Try searching with a different keyword or category.'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AxisColors.textDim,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final badge = filtered[index];
                        return MasteryBadgeTile(
                          badge: badge,
                          onTap: () => _showBadgeDetail(badge),
                        );
                      },
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}
