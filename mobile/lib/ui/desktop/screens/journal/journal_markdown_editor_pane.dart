import 'package:flutter/material.dart';
import 'package:axis/core/typography.dart';
import '../../../../core/theme.dart';
import '../../../../core/l10n/app_localizations.dart';
import '../../../../data/note_category_repository.dart';
import '../../../../data/note_repository.dart';
import '../../../notes/widgets/note_format_toolbar.dart';
import '../../widgets/accent_button.dart';
import '../../widgets/desktop_card.dart';
import '../../widgets/telemetry_chip.dart';

/// Middle pane with Title, Category, formatting toolbar, and raw markdown editor.
class JournalMarkdownEditorPane extends StatelessWidget {
  final Note? selectedNote;
  final bool isCreating;
  final String activeTab;
  final String creatingCategory;
  final TextEditingController titleController;
  final TextEditingController editorController;
  final FocusNode editorFocusNode;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onEditorChanged;
  final VoidCallback onSaveEditor;
  final ValueChanged<String> onUpdateCategory;
  final ValueChanged<String> onCreatingCategoryChanged;

  const JournalMarkdownEditorPane({
    super.key,
    required this.selectedNote,
    required this.isCreating,
    required this.activeTab,
    required this.creatingCategory,
    required this.titleController,
    required this.editorController,
    required this.editorFocusNode,
    required this.onTitleChanged,
    required this.onEditorChanged,
    required this.onSaveEditor,
    required this.onUpdateCategory,
    required this.onCreatingCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = AppLocalizations.of(context).isArabic;

    return DesktopCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isAr ? 'محرر ماركداون' : 'MARKDOWN EDITOR',
                  overflow: TextOverflow.ellipsis,
                  style: AxisFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AxisColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (selectedNote != null && !isCreating) ...[
                TelemetryChip(
                  label: isAr ? 'حفظ تلقائي' : 'AUTO-SAVED',
                  color: AxisColors.tertiary,
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                ),
                const SizedBox(width: 8),
              ],
              AccentButton(
                label: isAr
                    ? (activeTab == 'journal' ? 'حفظ اليومية' : 'حفظ الملاحظة')
                    : (activeTab == 'journal' ? 'Save Journal' : 'Save Note'),
                icon: Icons.save_rounded,
                onPressed: onSaveEditor,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Editable Title input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AxisColors.surfaceLowest,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AxisColors.borderSubtle, width: 1),
            ),
            child: TextField(
              controller: titleController,
              onChanged: onTitleChanged,
              style: AxisFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AxisColors.textHigh,
              ),
              decoration: InputDecoration(
                hintText: activeTab == 'journal'
                    ? (isAr ? 'عنوان يومية التأمل...' : 'Daily Reflection Title...')
                    : (isAr ? 'عنوان الملاحظة...' : 'Note Title...'),
                hintStyle: AxisFonts.spaceGrotesk(fontSize: 14, color: AxisColors.textDim),
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Note Category Selector (when in notes tab)
          if (activeTab == 'notes') ...[
            Row(
              children: [
                Text(
                  isAr ? 'التصنيف: ' : 'CATEGORY: ',
                  style: AxisFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w700, color: AxisColors.textDim),
                ),
                StreamBuilder<List<NoteCategory>>(
                  stream: NoteCategoryRepository().watchCategories(),
                  builder: (context, snapshot) {
                    final cats = snapshot.data ?? [];
                    final seen = <String>{'general'};
                    final catNames = <String>['General'];
                    for (final c in cats) {
                      final name = c.name.trim();
                      if (name.isNotEmpty && seen.add(name.toLowerCase())) {
                        catNames.add(name);
                      }
                    }
                    final currentCat = (selectedNote != null && !isCreating)
                        ? (selectedNote!.category.isEmpty ? 'General' : selectedNote!.category)
                        : creatingCategory;
                    final effectiveValue = catNames.firstWhere(
                      (c) => c.toLowerCase() == currentCat.toLowerCase(),
                      orElse: () => catNames.first,
                    );
                    return Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AxisColors.surfaceLowest,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AxisColors.borderSubtle, width: 1),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: effectiveValue,
                          dropdownColor: AxisColors.surfaceLow,
                          icon: const Icon(Icons.arrow_drop_down, size: 16, color: AxisColors.textDim),
                          style: AxisFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: AxisColors.textHigh),
                          items: catNames.map((name) {
                            final label = isAr && name.toLowerCase() == 'general' ? 'عام' : name;
                            return DropdownMenuItem<String>(
                              value: name,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              if (selectedNote != null && !isCreating) {
                                onUpdateCategory(val);
                              } else {
                                onCreatingCategoryChanged(val);
                              }
                            }
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Format Toolbar with full Markdown suite
          NoteFormatToolbar(
            controller: editorController,
            focusNode: editorFocusNode,
            onChanged: () => onEditorChanged(editorController.text),
          ),
          const SizedBox(height: 10),

          // Editor text area
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AxisColors.borderSubtle, width: 1),
              ),
              child: TextField(
                controller: editorController,
                focusNode: editorFocusNode,
                onChanged: onEditorChanged,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: AxisFonts.firaCode(
                  fontSize: 13,
                  height: 1.5,
                  color: AxisColors.textHigh,
                ),
                decoration: InputDecoration(
                  hintText: isAr
                      ? '# العنوان\n\nابدأ بكتابة مسودة الهيكلية المعمارية أو سجل اليوميات...'
                      : '# Title\n\nBegin drafting your architectural breakdown or journal log...',
                  hintStyle: AxisFonts.firaCode(fontSize: 13, color: AxisColors.textDim),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

