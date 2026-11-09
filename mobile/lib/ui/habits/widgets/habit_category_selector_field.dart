import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/habit_category_repository.dart';

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
      final clean = hex.replaceAll('#', '').replaceAll('0x', '').trim();
      if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
      if (clean.length == 8) return Color(int.parse(clean, radix: 16));
      return AxisColors.success;
    } catch (_) {
      return AxisColors.success;
    }
  }

  List<Widget> _buildDropdownItems(BuildContext context) {
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
    final filtered = (query.isEmpty || exactMatch || isGeneral)
        ? availableCategories
        : availableCategories
            .where((c) => c.name.toLowerCase().contains(query))
            .toList();

    if (filtered.isEmpty && query.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            context.isArabic
                ? 'لا توجد فئات مخصصة بعد. اكتب أعلاه لإنشاء فئة.'
                : 'No custom categories yet. Type above to create one.',
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
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
                    context.l10n.localizedHabitCategory(cat.name),
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
                    context.isArabic
                        ? 'إنشاء فئة "$rawText"'
                        : 'Create category "$rawText"',
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
              hintText: AppLocalizations.of(context).isArabic ? 'اختر أو اكتب اسم التصنيف...' : 'Select or write category name...',
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
                children: _buildDropdownItems(context),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

