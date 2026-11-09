import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/markdown_list_text_input_formatter.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';
import 'package:axis/ui/tasks/widgets/task_form_widgets.dart';

/// Form component for task notes with expandable text area, Markdown toolbar and live preview.
class TaskDescriptionEditor extends StatelessWidget {
  const TaskDescriptionEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isExpanded,
    required this.previewMode,
    required this.onToggleExpanded,
    required this.onTogglePreview,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isExpanded;
  final bool previewMode;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTogglePreview;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FieldLabel(
                label: context.isArabic
                    ? 'الوصف (ماركداون وقوائم)'
                    : 'DESCRIPTION (MARKDOWN & LISTS)',
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    key: const ValueKey('desc_expand_toggle'),
                    onTap: onToggleExpanded,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isExpanded
                            ? AxisColors.primary.withValues(alpha: 0.2)
                            : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isExpanded
                              ? AxisColors.primary.withValues(alpha: 0.6)
                              : AxisColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isExpanded
                                ? Icons.unfold_less_rounded
                                : Icons.unfold_more_rounded,
                            size: 13,
                            color: isExpanded
                                ? AxisColors.primary
                                : AxisColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isExpanded
                                ? (context.isArabic ? 'تقليص' : 'Compact')
                                : (context.isArabic ? 'توسيع' : 'Expand'),
                            style: TextStyle(
                              color: isExpanded
                                  ? AxisColors.primary
                                  : AxisColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onTogglePreview,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: previewMode
                            ? AxisColors.secondary.withValues(alpha: 0.25)
                            : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: previewMode
                              ? AxisColors.secondary
                              : AxisColors.borderSubtle,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            previewMode
                                ? Icons.edit_note_rounded
                                : Icons.visibility_outlined,
                            size: 13,
                            color: previewMode
                                ? AxisColors.secondary
                                : AxisColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            previewMode
                                ? (context.isArabic ? 'تعديل' : 'Edit')
                                : (context.isArabic ? 'معاينة' : 'Preview'),
                            style: TextStyle(
                              color: previewMode
                                  ? AxisColors.secondary
                                  : AxisColors.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (!previewMode) ...[
          NoteFormatToolbar(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
          ),
          AutoDirectionScope(
            controller: controller,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: false,
              minLines: isExpanded ? 8 : 3,
              maxLines: isExpanded ? 24 : 5,
              scrollPadding: const EdgeInsets.only(bottom: 120),
              onTap: () {
                if (!isExpanded) {
                  onToggleExpanded();
                }
              },
              inputFormatters: const [
                MarkdownListTextInputFormatter(),
              ],
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AxisColors.textHigh,
                  ),
              cursorColor: AxisColors.primary,
              decoration: InputDecoration(
                hintText: context.isArabic
                    ? 'أضف ملاحظات بصيغة ماركداون، قوائم (- أو 1.)، مربعات اختيار (- [ ])، روابط...'
                    : 'Add markdown formatted notes, lists (- or 1.), checklists (- [ ]), links...',
                hintStyle: const TextStyle(color: AxisColors.textDim),
                filled: true,
                fillColor: AxisColors.surfaceHigh.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AxisColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AxisColors.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            constraints: BoxConstraints(
              minHeight: isExpanded ? 200 : 80,
            ),
            decoration: BoxDecoration(
              color: AxisColors.surfaceHigh.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AxisColors.secondary.withValues(alpha: 0.4),
              ),
            ),
            child: controller.text.trim().isEmpty
                ? Text(
                    context.isArabic
                        ? 'لا توجد معاينة بعد. انتقل إلى التعديل لكتابة الملاحظات.'
                        : 'Nothing to preview yet. Switch to Edit to write markdown notes.',
                    style: const TextStyle(
                      color: AxisColors.textDim,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  )
                : AxisMarkdownViewer(
                    markdown: controller.text,
                    onMarkdownChanged: (updatedDesc) {
                      controller.text = updatedDesc;
                      onChanged();
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

