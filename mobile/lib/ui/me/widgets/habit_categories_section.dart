import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';

/// Section managing custom habit categories with add and delete capabilities
class HabitCategoriesSection extends StatelessWidget {
  const HabitCategoriesSection({
    super.key,
    required this.categories,
    required this.onAddCategory,
    required this.onDeleteCategory,
  });

  final List<Map<String, dynamic>> categories;
  final void Function(String name, String color) onAddCategory;
  final void Function(String id, String name) onDeleteCategory;

  Color _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return AxisColors.primary;
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.primary;
    }
  }

  void _showAddCategoryDialog(BuildContext context) {
    final catCtrl = TextEditingController();
    String selectedColor = '#10B981';

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
            'New Habit Category',
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
                    hintText: 'e.g. Fitness, Meditation, Study',
                    hintStyle: const TextStyle(color: AxisColors.textDim),
                    filled: true,
                    fillColor: AxisColors.surfaceHigh,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AxisColors.borderSubtle),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    '#10B981',
                    '#38BDF8',
                    '#6366F1',
                    '#F59E0B',
                    '#EC4899',
                  ].map((hex) {
                    final col = _parseHex(hex);
                    final isSel = selectedColor == hex;
                    return InkWell(
                      onTap: () => setDlgState(() => selectedColor = hex),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSel ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: isSel
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AxisColors.textDim)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AxisColors.success,
              ),
              onPressed: () {
                final catName = catCtrl.text.trim();
                Navigator.pop(ctx);
                if (catName.isNotEmpty) {
                  onAddCategory(catName, selectedColor);
                }
              },
              child: const Text('Create Category',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
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
                'HABIT CATEGORIES',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AxisColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showAddCategoryDialog(context),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AxisColors.success.withValues(alpha: 0.35),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 14, color: AxisColors.success),
                    SizedBox(width: 4),
                    Text(
                      'New Category',
                      style: TextStyle(
                        fontSize: 11,
                        color: AxisColors.success,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (categories.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AxisColors.surfaceHigh.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AxisColors.borderSubtle),
            ),
            child: const Center(
              child: Text(
                'No custom categories created yet',
                style: TextStyle(color: AxisColors.textDim, fontSize: 12),
              ),
            ),
          )
        else
          AxisCard(
            tier: GlassTier.two,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < categories.length; i++) ...[
                  if (i > 0)
                    const Divider(color: AxisColors.borderSubtle, height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _parseHex(categories[i]['color'] as String?),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _parseHex(categories[i]['color'] as String?)
                                    .withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (categories[i]['name'] as String?) ?? 'Category',
                            style: const TextStyle(
                              color: AxisColors.textHigh,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18, color: AxisColors.textDim),
                          tooltip: 'Delete Category',
                          onPressed: () => onDeleteCategory(
                            (categories[i]['id'] as String?) ?? '',
                            (categories[i]['name'] as String?) ?? 'Category',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
