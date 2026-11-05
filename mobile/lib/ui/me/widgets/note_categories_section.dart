import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';
import 'package:axis/ui/common/category_filter_slider.dart';

/// Section managing custom note categories with add and delete capabilities.
class NoteCategoriesSection extends StatelessWidget {
  const NoteCategoriesSection({
    super.key,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  final List<Map<String, dynamic>> categories;
  final void Function(String name, String color, String icon) onAddCategory;
  final void Function(String id, String name) onDeleteCategory;

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.secondary;
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.secondary;
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final catCtrl = TextEditingController();
    String selectedColor = '#38BDF8';
    String selectedIcon = 'article';

    final icons = [
      {'name': 'article', 'icon': Icons.article_rounded, 'label': 'Article'},
      {'name': 'work', 'icon': Icons.work_rounded, 'label': 'Work'},
      {'name': 'idea', 'icon': Icons.lightbulb_rounded, 'label': 'Idea'},
      {'name': 'study', 'icon': Icons.school_rounded, 'label': 'Study'},
      {'name': 'star', 'icon': Icons.star_rounded, 'label': 'Star'},
      {'name': 'bookmark', 'icon': Icons.bookmark_rounded, 'label': 'Bookmark'},
      {'name': 'code', 'icon': Icons.terminal_rounded, 'label': 'Code'},
      {'name': 'fitness', 'icon': Icons.fitness_center_rounded, 'label': 'Fitness'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AxisColors.surfaceLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AxisColors.borderPrimary),
          ),
          title: const Text(
            'New Note Category',
            style: TextStyle(
              color: AxisColors.textHigh,
              fontWeight: FontWeight.bold,
            ),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CATEGORY NAME',
                  style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: catCtrl,
                  autofocus: false,
                  style: const TextStyle(color: AxisColors.textHigh),
                  decoration: InputDecoration(
                    hintText: 'e.g. Work, Ideas, Architecture, Personal',
                    hintStyle: const TextStyle(color: AxisColors.textDim),
                    filled: true,
                    fillColor: AxisColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'ICON',
                  style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: icons.map((item) {
                    final name = item['name'] as String;
                    final icon = item['icon'] as IconData;
                    final isSel = selectedIcon == name;
                    return InkWell(
                      onTap: () => setDlgState(() => selectedIcon = name),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AxisColors.secondary.withValues(alpha: 0.25)
                              : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? AxisColors.secondary : AxisColors.borderSubtle,
                          ),
                        ),
                        child: Icon(icon, size: 18, color: isSel ? AxisColors.secondary : AxisColors.textDim),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text(
                  'COLOR ACCENT',
                  style: TextStyle(
                    color: AxisColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    const presetList = [
                      '#38BDF8',
                      '#10B981',
                      '#6366F1',
                      '#F59E0B',
                      '#EC4899',
                      '#A855F7',
                    ];
                    return Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...presetList.map((hex) {
                          final isSel = selectedColor.toUpperCase() == hex.toUpperCase();
                          final col = _parseHex(hex);
                          return InkWell(
                            onTap: () => setDlgState(() => selectedColor = hex),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSel ? Colors.white : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: isSel
                                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                                  : null,
                            ),
                          );
                        }),
                        RainbowColorPickerButton(
                          selectedColor: selectedColor,
                          size: 32,
                          borderWidth: 2,
                          onColorSelected: (col) => setDlgState(() => selectedColor = col),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AxisColors.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AxisColors.secondary,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final name = catCtrl.text.trim();
                if (name.isNotEmpty) {
                  onAddCategory(name, selectedColor, selectedIcon);
                }
                Navigator.pop(ctx);
              },
              child: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCategory(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AxisColors.surfaceLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AxisColors.borderPrimary),
        ),
        title: Text(
          'Delete "$name"?',
          style: const TextStyle(color: AxisColors.textHigh),
        ),
        content: Text(
          'Are you sure you want to delete the "$name" note category? Notes in this category will remain safe in General Notes.',
          style: const TextStyle(color: AxisColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: AxisColors.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AxisColors.error),
            onPressed: () {
              Navigator.pop(dialogCtx);
              onDeleteCategory(id, name);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'NOTE CATEGORIES',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showAddCategoryDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AxisColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AxisColors.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: AxisColors.secondary),
                      SizedBox(width: 4),
                      Text(
                        'New Category',
                        style: TextStyle(
                          fontSize: 11,
                          color: AxisColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No custom note categories yet. Tap "New Category" to create one.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AxisColors.textDim),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories.map((cat) {
              final id = cat['id'] as String;
              final name = cat['name'] as String;
              final icon = cat['icon'] as String? ?? 'article';
              final color = _parseHex(cat['color'] as String?);
              final iconData = CategorySliderItem.resolveIcon(icon, Icons.article_rounded);

              return Container(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                decoration: BoxDecoration(
                  color: AxisColors.surfaceHigh.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(iconData, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AxisColors.textHigh,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _confirmDeleteCategory(context, id, name),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded, size: 14, color: AxisColors.textDim),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
