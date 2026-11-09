import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/widgets.dart';
import 'package:axis/ui/common/axis_markdown_viewer.dart';
import 'package:axis/ui/common/markdown_list_text_input_formatter.dart';
import 'package:axis/ui/notes/widgets/note_format_toolbar.dart';

/// Markdown editor for note and journal content with formatting toolbar,
/// expandable height, template insertion, and live preview mode.
class NoteBodyEditor extends StatelessWidget {
  const NoteBodyEditor({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isJournal,
    required this.isExpanded,
    required this.previewMode,
    required this.onToggleExpanded,
    required this.onTogglePreview,
    required this.onInsertTemplate,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isJournal;
  final bool isExpanded;
  final bool previewMode;
  final VoidCallback onToggleExpanded;
  final VoidCallback onTogglePreview;
  final VoidCallback onInsertTemplate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                isArabic ? 'المحتوى (ماركداون وقوائم)' : 'CONTENT (MARKDOWN & LISTS)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AxisColors.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: isArabic ? 0.0 : 1.1,
                    ),
              ),
            ),
            Row(
              children: [
                if (isJournal)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6, bottom: 8),
                    child: InkWell(
                      onTap: onInsertTemplate,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AxisColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color:
                                AxisColors.secondary.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.playlist_add_rounded,
                                size: 13, color: AxisColors.secondary),
                            const SizedBox(width: 4),
                            Text(
                              isArabic ? 'قالب' : 'Template',
                              style: const TextStyle(
                                color: AxisColors.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        key: const ValueKey('note_expand_toggle'),
                        onTap: onToggleExpanded,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isExpanded
                                ? AxisColors.secondary.withValues(alpha: 0.25)
                                : AxisColors.surfaceHigh.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isExpanded
                                  ? AxisColors.secondary
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
                                    ? AxisColors.secondary
                                    : AxisColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isExpanded
                                    ? (isArabic ? 'تصغير' : 'Compact')
                                    : (isArabic ? 'توسيع' : 'Expand'),
                                style: TextStyle(
                                  color: isExpanded
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
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onTogglePreview,
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
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
                                    ? (isArabic ? 'تعديل' : 'Edit')
                                    : (isArabic ? 'معاينة' : 'Preview'),
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
              minLines: isExpanded ? 10 : 4,
              maxLines: isExpanded ? 26 : 7,
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
                    height: 1.4,
                  ),
              cursorColor: AxisColors.secondary,
              decoration: InputDecoration(
                hintText: isJournal
                    ? (isArabic
                        ? 'سجّل الأحداث (مثال: **14:00** - حدث)، ما تم إنجازه، العقبات...'
                        : 'Log events (e.g. **14:00** - Event), what happened, accomplishments, blockers...')
                    : (isArabic
                        ? 'اكتب الملاحظات، قوائم مرقمة (1. )، نقطية (- )، أو مهام (- [ ] )...'
                        : 'Write notes, ordered lists (1. ), bullet points (- ), or checklists (- [ ] )...'),
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
                      color: AxisColors.secondary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: isExpanded ? 240 : 140,
            ),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AxisColors.surfaceHigh.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AxisColors.secondary.withValues(alpha: 0.4),
              ),
            ),
            child: AxisMarkdownViewer(
              markdown: controller.text,
              onMarkdownChanged: (updatedBody) {
                controller.text = updatedBody;
                onChanged();
              },
            ),
          ),
        ],
      ],
    );
  }
}

