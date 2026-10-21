import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';

class HabitCategory {
  final String id;
  final String name;
  final String icon;
  final String color;

  const HabitCategory({
    required this.id,
    required this.name,
    this.icon = 'fitness',
    this.color = '#10B981',
  });
}

/// Category autocomplete / dropdown selector field for habit routines
class CategorySelectorField extends StatelessWidget {
  const CategorySelectorField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.categories,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onSelectCategory,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<HabitCategory> categories;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final void Function(String name, String icon, String color) onSelectCategory;
  final VoidCallback onClear;

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.success;
    }
  }

  List<Widget> _buildDropdownItems() {
    final rawText = controller.text.trim();
    final query = rawText.toLowerCase();
    final items = <Widget>[];

    final availableCategories = categories.where((c) {
      final idLower = c.id.toLowerCase();
      return idLower != 'cat_workout' &&
          idLower != 'cat_reading' &&
          idLower != 'cat_mindful' &&
          idLower != 'cat_hydrate' &&
          idLower != 'cat_code' &&
          idLower != 'cat_rest' &&
          idLower != 'cat_prayers' &&
          c.name.toLowerCase() != 'prayers';
    }).toList();

    final exactMatch = availableCategories.any(
      (c) => c.name.toLowerCase() == query,
    );
    final isGeneral = query == 'general routines';

    // Show all available categories if no filter is typed, or if current text is already a selected category/general,
    // so the user can easily see their categories and pick one when opening the dropdown.
    // Filter by query substring only when actively searching.
    final filtered = (query.isEmpty || exactMatch || isGeneral)
        ? availableCategories
        : availableCategories
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();

    if (filtered.isEmpty && query.isEmpty) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            'No custom categories yet. Type above to create one.',
            style: TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    for (final cat in filtered) {
      final isSel = query == cat.name.toLowerCase();
      final color = _parseHex(cat.color);

      items.add(
        InkWell(
          onTap: () {
            onSelectCategory(cat.name, cat.icon, cat.color);
            onOpenChanged(false);
            focusNode.unfocus();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSel
                  ? AxisColors.surfaceHigh.withValues(alpha: 0.6)
                  : Colors.transparent,
              border: const Border(
                bottom: BorderSide(color: AxisColors.borderSubtle, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat.name,
                    style: TextStyle(
                      color: isSel ? AxisColors.textHigh : AxisColors.textMuted,
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSel)
                  const Icon(Icons.check_rounded,
                      size: 16, color: AxisColors.success),
              ],
            ),
          ),
        ),
      );
    }

    if (query.isNotEmpty && !exactMatch && !isGeneral) {
      items.add(
        InkWell(
          onTap: () {
            onSelectCategory(rawText, 'fitness', '#10B981');
            onOpenChanged(false);
            focusNode.unfocus();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.add_rounded,
                    size: 16, color: AxisColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Create category "$rawText"',
                    style: const TextStyle(
                      color: AxisColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen ? AxisColors.success : AxisColors.borderSubtle,
              width: isOpen ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AxisColors.textHigh,
                ),
            cursorColor: AxisColors.success,
            decoration: InputDecoration(
              hintText: 'Select or write category name...',
              hintStyle:
                  const TextStyle(color: AxisColors.textDim, fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.category_rounded,
                  size: 18, color: AxisColors.success),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 16, color: AxisColors.textDim),
                      onPressed: onClear,
                    ),
                  IconButton(
                    icon: Icon(
                      isOpen
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AxisColors.textDim,
                      size: 20,
                    ),
                    onPressed: () => onOpenChanged(!isOpen),
                  ),
                ],
              ),
            ),
            onTap: () => onOpenChanged(true),
            onChanged: (text) {
              if (!isOpen) onOpenChanged(true);
            },
          ),
        ),
        if (isOpen) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 180),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AxisColors.success.withValues(alpha: 0.35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: _buildDropdownItems(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Color Accent circular dot selector row
class ColorAccentSelector extends StatelessWidget {
  const ColorAccentSelector({
    super.key,
    required this.selectedColor,
    required this.onSelectColor,
  });

  final String selectedColor;
  final ValueChanged<String> onSelectColor;

  static const colors = [
    {'hex': '#10B981', 'color': AxisColors.success, 'label': 'Emerald'},
    {'hex': '#38BDF8', 'color': AxisColors.secondary, 'label': 'Cyan'},
    {'hex': '#6366F1', 'color': AxisColors.primary, 'label': 'Indigo'},
    {'hex': '#F59E0B', 'color': AxisColors.warning, 'label': 'Amber'},
    {'hex': '#EC4899', 'color': Color(0xFFEC4899), 'label': 'Rose'},
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: colors.map((c) {
        final isSel = selectedColor == c['hex'];
        final col = c['color'] as Color;
        return InkWell(
          onTap: () => onSelectColor(c['hex'] as String),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: col,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? Colors.white : Colors.transparent,
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: col.withValues(alpha: 0.4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: isSel
                ? const Icon(Icons.check_rounded,
                    size: 18, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

/// XP Reward tier selector buttons [10, 20, 30, 50]
class XpRewardSelector extends StatelessWidget {
  const XpRewardSelector({
    super.key,
    required this.targetXp,
    required this.onSelectXp,
  });

  final int targetXp;
  final ValueChanged<int> onSelectXp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [10, 20, 30, 50].map((xp) {
        final isSel = targetXp == xp;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onSelectXp(xp),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSel
                      ? AxisColors.success.withValues(alpha: 0.22)
                      : AxisColors.surfaceHigh.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? AxisColors.success : AxisColors.borderSubtle,
                    width: isSel ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$xp XP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSel ? AxisColors.success : AxisColors.textDim,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
