import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';

/// Tag selector section of the filter studio, including chips wrap,
/// searchable text input, and drop-down menu.
class FilterStudioTagSelector extends StatelessWidget {
  const FilterStudioTagSelector({
    super.key,
    required this.selectedTags,
    required this.controller,
    required this.focusNode,
    required this.showDropdown,
    required this.dropdownItems,
    required this.onToggleDropdown,
    required this.onTapField,
    required this.onSubmit,
    required this.onChanged,
    required this.onRemoveTag,
    required this.onAddTag,
  });

  final Set<String> selectedTags;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showDropdown;
  final List<Widget> dropdownItems;
  final VoidCallback onToggleDropdown;
  final VoidCallback onTapField;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onRemoveTag;
  final VoidCallback onAddTag;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.isArabic ? 'الوسم' : 'TAG',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AxisColors.textMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
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
                      color: AxisColors.primary.withValues(alpha: 0.4)),
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
                      onTap: () => onRemoveTag(tag),
                      child: const Icon(Icons.close_rounded,
                          size: 14, color: AxisColors.textDim),
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
              color: showDropdown
                  ? AxisColors.primary
                  : AxisColors.borderSubtle,
              width: showDropdown ? 1.5 : 1.0,
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
              hintText: context.isArabic ? 'اختر أو اكتب اسم الوسم...' : 'Select or write tag name...',
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
                      onPressed: onAddTag,
                    ),
                  IconButton(
                    icon: Icon(
                      showDropdown
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AxisColors.textDim,
                      size: 20,
                    ),
                    onPressed: onToggleDropdown,
                  ),
                ],
              ),
            ),
            onTap: onTapField,
            onSubmitted: onSubmit,
            onChanged: onChanged,
          ),
        ),
        if (showDropdown) ...[
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
                children: dropdownItems,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

