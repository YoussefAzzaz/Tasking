import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/ui/common/cyber_color_picker.dart';

/// Preset icons for user-created note categories
const List<Map<String, dynamic>> kNoteCategoryIconOptions = [
  {'name': 'article', 'icon': Icons.article_rounded},
  {'name': 'work', 'icon': Icons.work_rounded},
  {'name': 'idea', 'icon': Icons.lightbulb_rounded},
  {'name': 'study', 'icon': Icons.school_rounded},
  {'name': 'star', 'icon': Icons.star_rounded},
  {'name': 'bookmark', 'icon': Icons.bookmark_rounded},
  {'name': 'code', 'icon': Icons.terminal_rounded},
  {'name': 'checklist', 'icon': Icons.checklist_rounded},
];

/// Visual customizer for new note categories: color swatches, rainbow picker, and icon chips
class NoteCategoryCustomizer extends StatelessWidget {
  const NoteCategoryCustomizer({
    super.key,
    required this.selectedColor,
    required this.selectedIcon,
    required this.onColorChanged,
    required this.onIconChanged,
  });

  final String selectedColor;
  final String selectedIcon;
  final ValueChanged<String> onColorChanged;
  final ValueChanged<String> onIconChanged;

  static const _palette = [
    '#38BDF8',
    '#10B981',
    '#6366F1',
    '#F59E0B',
    '#EC4899',
    '#A855F7',
  ];

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            isArabic ? 'لون وأيقونة الفئة الجديدة' : 'NEW CATEGORY COLOR & ICON',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AxisColors.textMuted,
                  fontWeight: FontWeight.bold,
                  letterSpacing: isArabic ? 0.0 : 1.1,
                ),
          ),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ..._palette.map((hex) {
              final isSel = selectedColor.toUpperCase() == hex.toUpperCase();
              final col =
                  Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
              return InkWell(
                onTap: () => onColorChanged(hex),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: col,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSel ? Colors.white : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: isSel
                      ? const Icon(Icons.check_rounded,
                          size: 16, color: Colors.white)
                      : null,
                ),
              );
            }),
            RainbowColorPickerButton(
              selectedColor: selectedColor,
              size: 30,
              borderWidth: 2,
              onColorSelected: onColorChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kNoteCategoryIconOptions.map((item) {
            final name = item['name'] as String;
            final icon = item['icon'] as IconData;
            final isSel = selectedIcon == name;
            return InkWell(
              onTap: () => onIconChanged(name),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSel
                      ? AxisColors.secondary.withValues(alpha: 0.25)
                      : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel
                        ? AxisColors.secondary
                        : AxisColors.borderSubtle,
                  ),
                ),
                child: Icon(icon,
                    size: 16,
                    color: isSel
                        ? AxisColors.secondary
                        : AxisColors.textDim),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

