import 'package:flutter/material.dart';
import 'package:axis/core/theme.dart';
import 'package:axis/core/l10n/app_localizations.dart';
import 'package:axis/data/note_repository.dart';
import 'package:axis/data/note_category_repository.dart';
import 'package:axis/ui/common/category_filter_slider.dart';
import 'package:axis/ui/common/cyber_search_bar.dart';
import 'note_category_card.dart';

/// Notes tab view containing CyberSearchBar, CategoryFilterSlider, empty states,
/// and expandable NoteCategoryCards.
class NotesTabView extends StatelessWidget {
  final List<NoteCategory> allCategories;
  final Map<String, List<Note>> notesByCategory;
  final List<Note> unassignedNotes;
  final TextEditingController searchController;
  final String searchQuery;
  final String selectedCategoryId;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<Note> onTapNote;
  final void Function(String category) onAddNoteToCategory;
  final ValueChanged<NoteCategory> onDeleteCategory;
  final Color Function(String? hex) parseHex;
  final VoidCallback onOpenCreateFirstNote;

  const NotesTabView({
    super.key,
    required this.allCategories,
    required this.notesByCategory,
    required this.unassignedNotes,
    required this.searchController,
    required this.searchQuery,
    required this.selectedCategoryId,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onCategorySelected,
    required this.onTapNote,
    required this.onAddNoteToCategory,
    required this.onDeleteCategory,
    required this.parseHex,
    required this.onOpenCreateFirstNote,
  });

  Widget _buildEmptySearchState({
    required BuildContext context,
    required String query,
    required VoidCallback onClear,
  }) {
    final isArabic = context.isArabic;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
        decoration: BoxDecoration(
          color: AxisColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AxisColors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AxisColors.secondary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  size: 32, color: AxisColors.secondary),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic
                  ? 'لم يتم العثور على ملاحظات لـ "$query"'
                  : 'No notes found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textHigh,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isArabic
                  ? 'تأكد من صحة الكلمات أو ابحث بكلمة مفتاحية أخرى.'
                  : 'Try checking your spelling or search with a different keyword.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AxisColors.textDim,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AxisColors.secondary.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: const Icon(Icons.close_rounded,
                  size: 14, color: AxisColors.secondary),
              label: Text(
                isArabic ? 'مسح البحث' : 'Clear Search',
                style: const TextStyle(
                  color: AxisColors.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalRegularNotes = unassignedNotes.length;
    for (final list in notesByCategory.values) {
      totalRegularNotes += list.length;
    }

    final isSearching = searchQuery.isNotEmpty;

    final sliderItems = <CategorySliderItem>[
      CategorySliderItem(
        id: 'all',
        label: context.isArabic ? 'كل الملاحظات' : 'All Notes',
        iconData: Icons.apps_rounded,
        color: AxisColors.secondary,
        count: totalRegularNotes,
      ),
      ...allCategories.map((category) {
        final notes = notesByCategory[category.name] ?? [];
        return CategorySliderItem(
          id: category.id,
          label: context.l10n.localizedNoteCategory(category.name),
          icon: category.icon,
          color: parseHex(category.color),
          count: notes.length,
        );
      }),
      if (unassignedNotes.isNotEmpty)
        CategorySliderItem(
          id: 'general_notes',
          label: context.isArabic ? 'ملاحظات عامة' : 'General Notes',
          iconData: Icons.article_rounded,
          color: const Color(0xFF64748B),
          count: unassignedNotes.length,
        ),
    ];

    final displayedCategories = allCategories.where((category) {
      if (selectedCategoryId != 'all') {
        final matches = category.id.toLowerCase() ==
                selectedCategoryId.toLowerCase() ||
            category.name.toLowerCase() ==
                selectedCategoryId.toLowerCase();
        if (!matches) return false;
      }

      if (searchQuery.isNotEmpty) {
        final notes = notesByCategory[category.name] ?? [];
        final hasMatchingNote = notes.any((n) =>
            n.title.toLowerCase().contains(searchQuery) ||
            n.bodyMd.toLowerCase().contains(searchQuery));
        final matchesCategory =
            category.name.toLowerCase().contains(searchQuery);
        return hasMatchingNote || matchesCategory;
      }

      return true;
    }).toList();

    final showUnassignedCategory = (selectedCategoryId == 'all' ||
            selectedCategoryId.toLowerCase() == 'general_notes') &&
        unassignedNotes.isNotEmpty;

    final displayedUnassignedNotes = showUnassignedCategory
        ? (searchQuery.isEmpty
            ? unassignedNotes
            : unassignedNotes
                .where((n) =>
                    n.title.toLowerCase().contains(searchQuery) ||
                    n.bodyMd.toLowerCase().contains(searchQuery))
                .toList())
        : <Note>[];

    int totalMatchingNotes = displayedUnassignedNotes.length;
    for (final cat in displayedCategories) {
      final raw = notesByCategory[cat.name] ?? [];
      final filtered = searchQuery.isEmpty
          ? raw
          : raw
              .where((n) =>
                  n.title.toLowerCase().contains(searchQuery) ||
                  n.bodyMd.toLowerCase().contains(searchQuery) ||
                  cat.name.toLowerCase().contains(searchQuery))
              .toList();
      totalMatchingNotes += filtered.length;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CyberSearchBar(
            controller: searchController,
            hintText: context.isArabic
                ? 'البحث في الملاحظات أو الفئات...'
                : 'Search notes or categories...',
            accentColor: AxisColors.secondary,
            onChanged: onSearchChanged,
            onClear: onSearchCleared,
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal category filter slider
        if (sliderItems.length > 1) ...[
          CategoryFilterSlider(
            items: sliderItems,
            selectedId: selectedCategoryId,
            onSelected: onCategorySelected,
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 14),
        ],

        // Empty search results state
        if (isSearching && totalMatchingNotes == 0)
          _buildEmptySearchState(
            context: context,
            query: searchController.text.trim(),
            onClear: onSearchCleared,
          )
        // No note categories created state
        else if (!isSearching &&
            allCategories.isEmpty &&
            unassignedNotes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AxisColors.surfaceLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AxisColors.borderSubtle),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open_rounded,
                      size: 38, color: AxisColors.textDim),
                  const SizedBox(height: 12),
                  Text(
                    context.isArabic
                        ? 'لا توجد ملاحظات أو تصنيفات بعد'
                        : 'No Notes or Categories Yet',
                    style: const TextStyle(
                      color: AxisColors.textHigh,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.isArabic
                        ? 'اضغط "ملاحظة جديدة" أعلاه لترتيب أفكارك ومعارفك.'
                        : 'Tap "New Note" above to organize your thoughts and knowledge.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AxisColors.textDim,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: onOpenCreateFirstNote,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      context.isArabic
                          ? 'إنشاء أول ملاحظة'
                          : 'Create First Note',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AxisColors.secondary,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          )
        // Render separated categories
        else ...[
          // Custom categories
          ...displayedCategories.map((category) {
            final rawNotes = notesByCategory[category.name] ?? [];
            final notes = (!isSearching ||
                    category.name.toLowerCase().contains(searchQuery))
                ? rawNotes
                : rawNotes
                    .where((n) =>
                        n.title.toLowerCase().contains(searchQuery) ||
                        n.bodyMd.toLowerCase().contains(searchQuery))
                    .toList();
            final color = parseHex(category.color);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NoteCategoryCard(
                key: ValueKey('note_cat_${category.id}'),
                category: category,
                color: color,
                notes: notes,
                forceExpand: isSearching,
                onTapNote: onTapNote,
                onAddNote: () => onAddNoteToCategory(category.name),
                onDeleteCategory: () => onDeleteCategory(category),
              ),
            );
          }),

          // General Notes Category Card
          if (displayedUnassignedNotes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: NoteCategoryCard(
                key: const ValueKey('note_cat_general'),
                category: NoteCategory(
                  id: 'general_notes',
                  name: context.isArabic ? 'ملاحظات عامة' : 'General Notes',
                  icon: 'article',
                  color: '#64748B',
                ),
                color: const Color(0xFF64748B),
                notes: displayedUnassignedNotes,
                forceExpand: isSearching,
                onTapNote: onTapNote,
                onAddNote: () => onAddNoteToCategory('General'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

