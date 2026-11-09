import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';

/// Autocomplete/searchable Tag selector field with chip preview and dynamic dropdown
class TagSelectorField extends StatelessWidget {
  const TagSelectorField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.selectedTags,
    required this.existingTags,
    required this.isOpen,
    required this.onOpenChanged,
    required this.onToggleTag,
    required this.onAddCurrentTag,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Set<String> selectedTags;
  final List<String> existingTags;
  final bool isOpen;
  final ValueChanged<bool> onOpenChanged;
  final ValueChanged<String> onToggleTag;
  final VoidCallback onAddCurrentTag;

  List<Widget> _buildDropdownItems(BuildContext context) {
    final query =
        controller.text.trim().toLowerCase().replaceAll('@', '');
    final List<Widget> items = [];

    final filtered = existingTags.where((tag) {
      if (query.isEmpty) return true;
      return tag.toLowerCase().contains(query);
    }).toList();

    if (filtered.isEmpty && query.isEmpty) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            context.isArabic ? 'اكتب لإنشاء وسم جديد...' : 'Type to create a new tag...',
            style: const TextStyle(color: AxisColors.textDim, fontSize: 12),
          ),
        ),
      );
    }

    for (final tag in filtered) {
      final isSelected = selectedTags.contains(tag);
      items.add(
        DropdownOption(
          icon: Icons.label_outline_rounded,
          iconColor: AxisColors.primary,
          title: '@$tag',
          isSelected: isSelected,
          onTap: () {
            onToggleTag(tag);
            controller.clear();
            onOpenChanged(false);
            focusNode.unfocus();
          },
        ),
      );
    }

    // If typed tag doesn't match an existing tag, offer quick-add
    final exactMatch = existingTags.any(
      (t) => t.toLowerCase() == query,
    );
    if (query.isNotEmpty && !exactMatch) {
      final rawTyped = controller.text.trim().replaceAll('@', '');
      items.add(
        DropdownOption(
          icon: Icons.add_rounded,
          iconColor: AxisColors.primary,
          title: context.isArabic ? 'إضافة وسم "@$rawTyped"' : 'Add tag "@$rawTyped"',
          isAction: true,
          onTap: () {
            onAddCurrentTag();
            onOpenChanged(false);
            focusNode.unfocus();
          },
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
        FieldLabel(label: context.isArabic ? 'الوسوم' : 'TAGS'),
        if (selectedTags.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selectedTags.map((tag) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AxisColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AxisColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@$tag',
                      style: const TextStyle(
                        color: AxisColors.primarySoft,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => onToggleTag(tag),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: AxisColors.textDim,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          decoration: BoxDecoration(
            color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOpen ? AxisColors.primary : AxisColors.borderSubtle,
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
            cursorColor: AxisColors.primary,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).isArabic ? 'اختر أو اكتب اسم الوسم...' : 'Select or write tag name...',
              hintStyle:
                  const TextStyle(color: AxisColors.textDim, fontSize: 13),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              prefixIcon: const Icon(Icons.label_outline_rounded,
                  size: 18, color: AxisColors.primary),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (controller.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.add_rounded,
                          size: 20, color: AxisColors.primary),
                      tooltip: context.isArabic ? 'إضافة وسم' : 'Add tag',
                      onPressed: onAddCurrentTag,
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
            onSubmitted: (_) => onAddCurrentTag(),
            onChanged: (_) {
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
                color: AxisColors.primary.withValues(alpha: 0.35),
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
