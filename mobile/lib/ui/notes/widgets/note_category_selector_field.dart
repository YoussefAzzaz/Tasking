import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/common/category_filter_slider.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Autocomplete / dropdown selector field for note categories.
class NoteCategorySelectorField extends StatelessWidget {
  const NoteCategorySelectorField({
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
  final List<NoteCategory> categories;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final void Function(String name, String icon, String color) onSelectCategory;
  final VoidCallback onClear;

  Color _parseHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '').trim();
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return AxisColors.secondary;
    }
  }

  List<Widget> _buildDropdownItems(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final l10n = AppLocalizations.of(context);
    final rawText = controller.text.trim();
    final query = rawText.toLowerCase();
    final items = <Widget>[];

    final availableCategories = categories.where((c) {
      final idLower = c.id.toLowerCase();
      final nameLower = c.name.toLowerCase();
      return idLower != 'general_notes' &&
          nameLower != 'general notes' &&
          idLower != 'all' &&
          nameLower != 'note';
    }).toList();

    final exactMatch = availableCategories.any(
      (c) => c.name.toLowerCase() == query,
    );
    final isGeneral = query == 'general notes' || query == 'note' || query.isEmpty;

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
            isArabic
                ? 'لا توجد فئات مخصصة حتى الآن. اكتب أعلاه لإنشاء فئة.'
                : 'No custom categories yet. Type above to create one.',
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    for (final cat in filtered) {
      final isSel = query == cat.name.toLowerCase();
      final color = _parseHex(cat.color);
      final iconData = CategorySliderItem.resolveIcon(cat.icon, Icons.article_rounded);
      final displayName = l10n.localizedNoteCategory(cat.name);

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
                const SizedBox(width: 8),
                Icon(iconData, size: 14, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayName,
                    style: TextStyle(
                      color: isSel ? AxisColors.textHigh : AxisColors.textMuted,
                      fontSize: 13,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isSel)
                  const Icon(Icons.check_rounded,
                      size: 16, color: AxisColors.secondary),
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
            onSelectCategory(rawText, 'article', '#38BDF8');
            onOpenChanged(false);
            focusNode.unfocus();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AxisColors.secondary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    size: 16, color: AxisColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isArabic
                        ? 'إنشاء فئة جديدة "$rawText"'
                        : 'Create new category "$rawText"',
                    style: const TextStyle(
                      color: AxisColors.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen ? AxisColors.secondary : AxisColors.borderSubtle,
              width: isOpen ? 1.5 : 1,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AxisColors.textHigh,
                ),
            cursorColor: AxisColors.secondary,
            decoration: InputDecoration(
              hintText: isArabic
                  ? 'اختر أو اكتب اسم الفئة...'
                  : 'Select or write category name...',
              hintStyle:
                  const TextStyle(color: AxisColors.textDim, fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.category_rounded,
                  size: 18, color: AxisColors.secondary),
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
                color: AxisColors.secondary.withValues(alpha: 0.35),
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
