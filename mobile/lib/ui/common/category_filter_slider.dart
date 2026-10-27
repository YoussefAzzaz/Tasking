import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axis/core/theme.dart';
import '../desktop/widgets/desktop_horizontal_scroll.dart';

/// Representation of an individual item in the horizontal category filter slider
class CategorySliderItem {
  final String id;
  final String label;
  final String? icon;
  final IconData? iconData;
  final Color color;
  final int count;

  const CategorySliderItem({
    required this.id,
    required this.label,
    this.icon,
    this.iconData,
    this.color = AxisColors.primary,
    this.count = 0,
  });

  static IconData resolveIcon(String? iconName, [IconData defaultIcon = Icons.category_rounded]) {
    if (iconName == null || iconName.isEmpty) return defaultIcon;
    switch (iconName.toLowerCase()) {
      case 'book':
      case 'reading':
        return Icons.menu_book_rounded;
      case 'meditation':
      case 'mindful':
        return Icons.self_improvement_rounded;
      case 'water':
      case 'hydrate':
        return Icons.water_drop_rounded;
      case 'code':
      case 'programming':
        return Icons.terminal_rounded;
      case 'sleep':
      case 'rest':
        return Icons.bedtime_rounded;
      case 'finance':
      case 'money':
        return Icons.account_balance_wallet_rounded;
      case 'health':
        return Icons.favorite_rounded;
      case 'project':
      case 'folder':
        return Icons.folder_rounded;
      case 'hub':
        return Icons.hub_rounded;
      case 'fitness':
      case 'workout':
        return Icons.fitness_center_rounded;
      case 'note':
      case 'article':
        return Icons.article_rounded;
      case 'work':
      case 'job':
        return Icons.work_rounded;
      case 'idea':
      case 'bulb':
        return Icons.lightbulb_rounded;
      case 'study':
      case 'school':
        return Icons.school_rounded;
      case 'journal':
      case 'diary':
        return Icons.auto_stories_rounded;
      case 'personal':
      case 'user':
        return Icons.person_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'bookmark':
        return Icons.bookmark_rounded;
      case 'checklist':
        return Icons.checklist_rounded;
      default:
        return defaultIcon;
    }
  }
}

/// Horizontal slider bar with cyber-minimalist category/project filter pills.
/// Allows instant filtering and quick navigation through categories and projects without endless scrolling.
class CategoryFilterSlider extends StatelessWidget {
  const CategoryFilterSlider({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<CategorySliderItem> items;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return DesktopHorizontalScrollView(
      physics: const BouncingScrollPhysics(),
      padding: padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: items.map((item) {
          final isSelected = item.id.toLowerCase() == selectedId.toLowerCase();
          final effectiveColor = item.color;
          final iconData = item.iconData ??
              (item.icon != null ? CategorySliderItem.resolveIcon(item.icon) : null);

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(item.id);
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? effectiveColor.withValues(alpha: 0.18)
                        : AxisColors.surfaceHigh.withValues(alpha: 0.40),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? effectiveColor.withValues(alpha: 0.65)
                          : AxisColors.borderSubtle,
                      width: isSelected ? 1.4 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: effectiveColor.withValues(alpha: 0.20),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (iconData != null) ...[
                        Icon(
                          iconData,
                          size: 14,
                          color: isSelected ? effectiveColor : AxisColors.textDim,
                        ),
                        const SizedBox(width: 6),
                      ] else ...[
                        // Sleek glowing indicator dot
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: effectiveColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: effectiveColor.withValues(alpha: 0.4),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected ? AxisColors.textHigh : AxisColors.textMuted,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (item.count > 0 || isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? effectiveColor.withValues(alpha: 0.25)
                                : AxisColors.surfaceHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${item.count}',
                            style: TextStyle(
                              color: isSelected ? effectiveColor : AxisColors.textDim,
                              fontWeight: FontWeight.bold,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
